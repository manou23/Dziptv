import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show compute;
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Isolate entry point: keep the 100,000-round PBKDF2 work off the UI thread.
String _deriveProfilePinHash(List<String> input) {
  final pin = input[0];
  final salt = input[1];
  const iterations = 100000;
  final hmac = Hmac(sha256, utf8.encode(pin));
  final saltBytes = base64Url.decode(salt);
  var u = hmac.convert(<int>[...saltBytes, 0, 0, 0, 1]).bytes;
  final result = List<int>.from(u);
  for (var round = 1; round < iterations; round++) {
    u = hmac.convert(u).bytes;
    for (var i = 0; i < result.length; i++) {
      result[i] ^= u[i];
    }
  }
  return base64Url.encode(result);
}

/// PIN hashing for each Xtream profile.
/// Only a salted PBKDF2-HMAC-SHA256 hash is stored. The hash may be carried
/// inside the AES-GCM encrypted profile vault; the PIN itself is never synced.
class ProfilePinService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static String _key(String profileId) =>
      'xtream_profile_pin_' + base64Url.encode(utf8.encode(profileId));


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

  /// Export only the salted PBKDF2 hash. It is included inside the already
  /// AES-GCM encrypted MESUT profile vault, never sent as plaintext.
  static Future<String?> exportHash(String profileId) =>
      _storage.read(key: _key(profileId));

  static bool isValidStoredHash(String value) {
    final parts = value.split(':');
    if (parts.length != 3 || parts[0] != 'v1') return false;
    try {
      return base64Url.decode(parts[1]).length == 16 &&
          base64Url.decode(parts[2]).length == 32;
    } catch (_) {
      return false;
    }
  }

  /// Restore a previously generated hash from the authenticated encrypted
  /// cloud vault. Null explicitly removes the PIN.
  static Future<void> importHash(String profileId, String? value) async {
    if (value == null || value.isEmpty) {
      await remove(profileId);
      return;
    }
    if (!isValidStoredHash(value)) {
      throw const FormatException('Invalid profile PIN hash');
    }
    await _storage.write(key: _key(profileId), value: value);
  }

  static Future<void> setPin(String profileId, String pin) async {
    if (!isValidPin(pin)) {
      throw ArgumentError('PIN must contain 4 to 6 digits');
    }
    final random = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
    final salt = base64Url.encode(saltBytes);
    final hash = await compute(_deriveProfilePinHash, <String>[pin, salt]);
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
    final actual = await compute(_deriveProfilePinHash, <String>[pin, parts[1]]);
    return _same(actual, parts[2]);
  }

  static Future<void> remove(String profileId) async =>
      _storage.delete(key: _key(profileId));
}
