import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'store.dart';

class MesutCloudApi {
  MesutCloudApi._();
  static const _secure = FlutterSecureStorage();
  static const _configuredUrl = String.fromEnvironment('MESUT_API_BASE_URL');
  static String get baseUrl => _configuredUrl.trim().replaceFirst(RegExp(r'/+$'), '');
  static const _tokenKey = 'mesut_cloud_token';
  static const _emailKey = 'mesut_cloud_email';
  static const _deviceKey = 'mesut_cloud_device_key';
  static void Function()? onSessionExpired;

  // Automatic, debounced synchronization with bounded retry when offline.
  static Timer? _syncTimer;
  static bool _syncing = false;
  static bool _syncRequested = false;
  static int _retryAttempt = 0;

  static bool get isConfigured => baseUrl.startsWith('https://') || baseUrl.startsWith('http://');
  static Future<String?> get email => _secure.read(key: _emailKey);
  static Future<bool> get isSignedIn async => (await _secure.read(key: _tokenKey))?.isNotEmpty == true;

  static Uri _uri(String path) {
    if (!isConfigured) throw Exception('لم يتم ضبط عنوان خادم MESUT في نسخة التطبيق');
    return Uri.parse('$baseUrl$path');
  }

  static Future<Map<String, dynamic>> _decode(http.Response response, {bool authenticated = false}) async {
    Map<String, dynamic> body = {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) body = Map<String, dynamic>.from(decoded);
    } catch (_) {}
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final code = body['error']?.toString() ?? 'REQUEST_FAILED';
      if (response.statusCode == 409) throw Exception('هذا البريد مسجل مسبقاً');
      if (response.statusCode == 401) {
        if (authenticated) {
          await signOut();
          onSessionExpired?.call();
          throw Exception('انتهت جلسة حساب MESUT. سجّل الدخول مجدداً.');
        }
        throw Exception('البريد أو كلمة المرور غير صحيحة');
      }
      throw Exception('تعذر إكمال العملية ($code)');
    }
    return body;
  }

  static Future<void> authenticate(String email, String password, {required bool register}) async {
    final response = await http.post(
      _uri('/api/v1/auth/${register ? 'register' : 'login'}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim(), 'password': password}),
    ).timeout(const Duration(seconds: 60));
    final data = await _decode(response);
    final token = data['token']?.toString();
    final accountEmail = (data['user'] as Map?)?['email']?.toString();
    if (token == null || token.isEmpty || accountEmail == null) {
      throw Exception('استجابة الخادم غير مكتملة');
    }
    await _secure.write(key: _tokenKey, value: token);
    await _secure.write(key: _emailKey, value: accountEmail);
    try {
      await _registerDevice();
    } catch (_) {
      // Keep the authenticated session; device registration can retry during sync.
    }
    await scheduleSync();
  }

  static Future<String> _getDeviceKey() async {
    final existing = await _secure.read(key: _deviceKey);
    if (existing != null && existing.length >= 32) return existing;
    final random = Random.secure();
    final value = List.generate(32, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await _secure.write(key: _deviceKey, value: value);
    return value;
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await _secure.read(key: _tokenKey);
    if (token == null || token.isEmpty) throw Exception('سجّل الدخول إلى حساب MESUT أولاً');
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  static Future<String> get currentDeviceKey => _getDeviceKey();

  // Validate an existing token without blocking startup when offline.
  static Future<bool> validateSession() async {
    if (!await isSignedIn) return false;
    try {
      final response = await http.get(
        _uri('/api/v1/devices'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 8));
      await _decode(response, authenticated: true);
      return true;
    } catch (_) {
      return await isSignedIn;
    }
  }

  static Future<List<Map<String, dynamic>>> listDevices() async {
    await _registerDevice();
    final response = await http.get(
      _uri('/api/v1/devices'),
      headers: await _authHeaders(),
    ).timeout(const Duration(seconds: 20));
    final data = await _decode(response, authenticated: true);
    final list = data['devices'];
    if (list is! List) return [];
    return list.whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<void> removeDevice(String id) async {
    final response = await http.delete(
      _uri('/api/v1/devices/${Uri.encodeComponent(id)}'),
      headers: await _authHeaders(),
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode == 204) return;
    await _decode(response, authenticated: true);
  }

  static Future<void> _registerDevice() async {
    final response = await http.post(
      _uri('/api/v1/devices/register'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'deviceKey': await _getDeviceKey(),
        'name': 'MESUT Android',
        'platform': 'android',
      }),
    ).timeout(const Duration(seconds: 20));
    await _decode(response, authenticated: true);
  }

  static Future<Map<String, Map<String, dynamic>>> _fetchRecords(
      Map<String, String> headers) async {
    final response = await http.get(_uri('/api/v1/sync'), headers: headers)
        .timeout(const Duration(seconds: 20));
    final data = await _decode(response, authenticated: true);
    final output = <String, Map<String, dynamic>>{};
    final list = data['records'];
    if (list is List) {
      for (final item in list) {
        if (item is Map && item['key'] is String) {
          output[item['key'] as String] = Map<String, dynamic>.from(item);
        }
      }
    }
    return output;
  }

  static Future<void> scheduleSync() async {
    if (!await isSignedIn) return;
    _syncRequested = true;
    if (_syncing || _syncTimer != null) return;

    final exponent = (_retryAttempt - 1).clamp(0, 4).toInt();
    final delaySeconds = _retryAttempt == 0
        ? 2
        : (15 * (1 << exponent)).clamp(15, 300).toInt();
    _syncTimer = Timer(Duration(seconds: delaySeconds), () async {
      _syncTimer = null;
      await _runScheduledSync();
    });
  }

  static Future<void> _runScheduledSync() async {
    if (_syncing || !await isSignedIn) return;
    _syncing = true;
    _syncRequested = false;
    try {
      await syncNow();
      _retryAttempt = 0;
    } catch (_) {
      // Keep local data and retry automatically (15s, 30s, 60s... up to 5m).
      _retryAttempt++;
      _syncRequested = true;
    } finally {
      _syncing = false;
      if (_syncRequested && await isSignedIn) {
        await scheduleSync();
      }
    }
  }

  static Future<void> syncNow() async {
    await _registerDevice();
    final headers = await _authHeaders();
    final snapshot = Store.cloudSnapshot();
    final profileId = snapshot['profile_id'] as String;
    final remote = await _fetchRecords(headers);

    final localMeta = Map<String, dynamic>.from(snapshot['sync_meta'] as Map);
    final remoteMetaValue = remote['sync_meta']?['value'];
    final remoteMeta = remoteMetaValue is Map
        ? Map<String, dynamic>.from(remoteMetaValue)
        : <String, dynamic>{};

    Map<String, dynamic> profileValues(dynamic value) {
      if (value is Map && value['profiles'] is Map) {
        return Map<String, dynamic>.from(value['profiles'] as Map);
      }
      // Migrate records written by earlier app versions into the active profile.
      if (value is Map) return {profileId: value};
      return {};
    }

    Map<String, dynamic> profileTimes(dynamic value) {
      if (value is Map) return Map<String, dynamic>.from(value);
      if (value is num) return {profileId: value};
      return {};
    }

    final remoteFavoriteProfiles =
        profileValues(remote['favorites']?['value']);
    final localFavoriteProfiles =
        profileValues(snapshot['favorites']);
    final remoteFavoriteTimes = profileTimes(remoteMeta['favorites']);
    final localFavoriteTimes = profileTimes(localMeta['favorites']);
    final localFavoriteTime =
        (localFavoriteTimes[profileId] as num?)?.toInt() ?? 0;
    final remoteFavoriteTime =
        (remoteFavoriteTimes[profileId] as num?)?.toInt() ?? 0;
    final chosenFavorites = remoteFavoriteTime > localFavoriteTime
        ? (remoteFavoriteProfiles[profileId] ??
            {'live': [], 'vod': [], 'series': []})
        : (localFavoriteProfiles[profileId] ??
            {'live': [], 'vod': [], 'series': []});
    remoteFavoriteProfiles[profileId] = chosenFavorites;
    remoteFavoriteTimes[profileId] = remoteFavoriteTime > localFavoriteTime
        ? remoteFavoriteTime
        : localFavoriteTime > 0
            ? localFavoriteTime
            : DateTime.now().millisecondsSinceEpoch;
    snapshot['favorites'] = {'profiles': remoteFavoriteProfiles};

    final remoteHistoryProfiles =
        profileValues(remote['watch_history']?['value']);
    final localHistoryProfiles = profileValues(snapshot['watch_history']);
    final remoteHistoryTimes = profileTimes(remoteMeta['watch_history']);
    final localHistoryTimes = profileTimes(localMeta['watch_history']);
    final localHistoryTime =
        (localHistoryTimes[profileId] as num?)?.toInt() ?? 0;
    final remoteHistoryTime =
        (remoteHistoryTimes[profileId] as num?)?.toInt() ?? 0;
    final chosenHistory = remoteHistoryTime > localHistoryTime
        ? (remoteHistoryProfiles[profileId] ?? <dynamic>[])
        : (localHistoryProfiles[profileId] ?? <dynamic>[]);
    remoteHistoryProfiles[profileId] =
        (chosenHistory as List).take(30).toList();
    remoteHistoryTimes[profileId] = remoteHistoryTime > localHistoryTime
        ? remoteHistoryTime
        : localHistoryTime > 0
            ? localHistoryTime
            : DateTime.now().millisecondsSinceEpoch;
    snapshot['watch_history'] = {'profiles': remoteHistoryProfiles};
    snapshot['sync_meta'] = {
      'favorites': remoteFavoriteTimes,
      'watch_history': remoteHistoryTimes,
    };

    // Global app settings use last-change timestamps.
    final localSettings = Map<String, dynamic>.from(snapshot['settings'] as Map);
    final remoteSettingsValue = remote['settings']?['value'];
    if (remoteSettingsValue is Map) {
      final remoteSettings = Map<String, dynamic>.from(remoteSettingsValue);
      final remoteTime = remoteSettings['_updatedAt'] is num
          ? (remoteSettings['_updatedAt'] as num).toInt()
          : DateTime.tryParse(remote['settings']?['updatedAt']?.toString() ?? '')
                  ?.millisecondsSinceEpoch ?? 0;
      final localTime = (localSettings['_updatedAt'] as num?)?.toInt() ?? 0;
      if (remoteTime >= localTime) {
        remoteSettings['_updatedAt'] = remoteTime;
        snapshot['settings'] = remoteSettings;
      }
    }

    for (final key in ['favorites', 'watch_history', 'settings', 'sync_meta']) {
      final response = await http.put(
        _uri('/api/v1/sync/$key'),
        headers: headers,
        body: jsonEncode({'value': snapshot[key]}),
      ).timeout(const Duration(seconds: 20));
      await _decode(response, authenticated: true);
    }

    final updated = await _fetchRecords(headers);
    final records = <String, dynamic>{
      for (final entry in updated.entries) entry.key: entry.value['value'],
    };
    // A profile may be switched while the request is in flight. Never apply
    // the old profile's data to the newly active local profile.
    if (Store.cloudProfileId == profileId) {
      await Store.applyCloudRecords(records, profileId: profileId);
    }
  }

  static Future<void> signOut() async {
    _syncTimer?.cancel();
    _syncTimer = null;
    _syncRequested = false;
    _retryAttempt = 0;
    await _secure.delete(key: _tokenKey);
    await _secure.delete(key: _emailKey);
  }
}
