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

  static Future<void> syncNow() async {
    await _registerDevice();
    final snapshot = Store.cloudSnapshot();
    final headers = await _authHeaders();
    for (final key in ['favorites', 'watch_history', 'settings']) {
      final response = await http.put(
        _uri('/api/v1/sync/$key'),
        headers: headers,
        body: jsonEncode({'value': snapshot[key]}),
      ).timeout(const Duration(seconds: 20));
      await _decode(response);
    }
    final response = await http.get(
      _uri('/api/v1/sync'),
      headers: headers,
    ).timeout(const Duration(seconds: 20));
    final data = await _decode(response);
    final records = <String, dynamic>{};
    final list = data['records'];
    if (list is List) {
      for (final item in list) {
        if (item is Map && item['key'] is String) {
          records[item['key'] as String] = item['value'];
        }
      }
    }
    await Store.applyCloudRecords(records);
  }

  static Future<void> signOut() async {
    await _secure.delete(key: _tokenKey);
    await _secure.delete(key: _emailKey);
  }
}
