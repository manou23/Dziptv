import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Device-local PIN storage for each Xtream profile.
/// Only a salted PBKDF2-HMAC-SHA256 hash is stored; the PIN is never synced.
class ProfilePinService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const int _iterations = 100000;

  static String _key(String profileId) =>
      'xtream_profile_pin_' + base64Url.encode(utf8.encode(profileId));

  static String _derive(String pin, String salt) {
    final hmac = Hmac(sha256, utf8.encode(pin));
    final saltBytes = base64Url.decode(salt);
    var u = hmac.convert(<int>[...saltBytes, 0, 0, 0, 1]).bytes;
    final result = List<int>.from(u);
    for (var round = 1; round < _iterations; round++) {
      u = hmac.convert(u).bytes;
      for (var i = 0; i < result.length; i++) {
        result[i] ^= u[i];
      }
    }
    return base64Url.encode(result);
  }

  static bool _same(String a, String b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return difference == 0;
  }

  static bool isValidPin(String pin) =>
      RegExp(r'^[0-9]{4,6}$').hasMatch(pin);

  static Future<bool> hasPin(String profileId) async =>
      (await _storage.read(key: _key(profileId))) != null;

  static Future<void> setPin(String profileId, String pin) async {
    if (!isValidPin(pin)) {
      throw ArgumentError('PIN must contain 4 to 6 digits');
    }
    final random = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
    final salt = base64Url.encode(saltBytes);
    final hash = _derive(pin, salt);
    await _storage.write(
      key: _key(profileId),
      value: 'v1:' + salt + ':' + hash,
    );
  }

  static Future<bool> verify(String profileId, String pin) async {
    if (!isValidPin(pin)) return false;
    final stored = await _storage.read(key: _key(profileId));
    if (stored == null) return true;
    final parts = stored.split(':');
    if (parts.length != 3 || parts[0] != 'v1') return false;
    return _same(_derive(pin, parts[1]), parts[2]);
  }

  static Future<void> remove(String profileId) async =>
      _storage.delete(key: _key(profileId));
}
