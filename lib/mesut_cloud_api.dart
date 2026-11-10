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

  static Future<Map<String, dynamic>> _decode(http.Response response) async {
    Map<String, dynamic> body = {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) body = Map<String, dynamic>.from(decoded);
    } catch (_) {}
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final code = body['error']?.toString() ?? 'REQUEST_FAILED';
      if (response.statusCode == 409) throw Exception('هذا البريد مسجل مسبقاً');
      if (response.statusCode == 401) throw Exception('البريد أو كلمة المرور غير صحيحة');
      throw Exception('تعذر إكمال العملية ($code)');
    }
    return body;
  }

  static Future<void> authenticate(String email, String password, {required bool register}) async {
    final response = await http.post(
      _uri('/api/v1/auth/${register ? 'register' : 'login'}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim(), 'password': password}),
    ).timeout(const Duration(seconds: 20));
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
    await _decode(response);
  }

  static Future<Map<String, Map<String, dynamic>>> _fetchRecords(
      Map<String, String> headers) async {
    final response = await http.get(_uri('/api/v1/sync'), headers: headers)
        .timeout(const Duration(seconds: 20));
    final data = await _decode(response);
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

  static Map<String, dynamic> _mergeById(dynamic local, dynamic remote,
      String idField, {int limit = 100}) {
    final merged = <String, Map<String, dynamic>>{};
    for (final source in [local, remote]) {
      if (source is List) {
        for (final item in source) {
          if (item is Map && item[idField] != null) {
            merged[item[idField].toString()] = Map<String, dynamic>.from(item);
          }
        }
      }
    }
    final values = merged.values.toList();
    if (idField == 'key') {
      values.sort((a, b) => ((b['ts'] as num?)?.toInt() ?? 0)
          .compareTo((a['ts'] as num?)?.toInt() ?? 0));
    }
    return {'items': values.take(limit).toList()};
  }

  static Future<void> scheduleSync() async {
    if (!await isSignedIn) return;
    _syncRequested = true;
    if (_syncing || _syncTimer != null) return;

    final delaySeconds = _retryAttempt == 0
        ? 2
        : min(300, 15 * (1 << min(_retryAttempt - 1, 4)));
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
    final remote = await _fetchRecords(headers);

    // Merge favorites and watch-history metadata so a newly added device
    // cannot erase data already stored by another device.
    final localFavorites = snapshot['favorites'] as Map<String, dynamic>;
    final remoteFavorites = remote['favorites']?['value'];
    final mergedFavorites = <String, dynamic>{};
    for (final type in ['live', 'vod', 'series']) {
      final localList = localFavorites[type];
      final remoteList = remoteFavorites is Map ? remoteFavorites[type] : null;
      mergedFavorites[type] = _mergeById(localList, remoteList, 'id')['items'];
    }
    snapshot['favorites'] = mergedFavorites;
    snapshot['watch_history'] = _mergeById(
      snapshot['watch_history'],
      remote['watch_history']?['value'],
      'key',
      limit: 30,
    )['items'];

    // Settings use last-change timestamps: a fresh device inherits remote
    // settings, while a newer local edit is uploaded to the account.
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

    for (final key in ['favorites', 'watch_history', 'settings']) {
      final response = await http.put(
        _uri('/api/v1/sync/$key'),
        headers: headers,
        body: jsonEncode({'value': snapshot[key]}),
      ).timeout(const Duration(seconds: 20));
      await _decode(response);
    }

    final updated = await _fetchRecords(headers);
    final records = <String, dynamic>{
      for (final entry in updated.entries) entry.key: entry.value['value'],
    };
    await Store.applyCloudRecords(records);
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
