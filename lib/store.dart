import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'profile_pin_service.dart';

class Store {
  static late SharedPreferences _p;
  static const FlutterSecureStorage _secure = FlutterSecureStorage();
  static final Map<String, String> _passwords = {};
  static String? _pinCache;
  // Installed by main.dart so every relevant local change queues cloud sync.
  static Future<void> Function()? cloudSyncCallback;
  static void Function()? cloudSettingsAppliedCallback;

  static Future<void> _notifyCloudChanged() async {
    final callback = cloudSyncCallback;
    if (callback != null) await callback();
  }

  static String _passwordKey(String id) =>
      'account_password_${base64Url.encode(utf8.encode(id))}';

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();

    // Migrate credentials from legacy SharedPreferences into encrypted storage.
    final rawAccounts = _p.getStringList('accounts') ?? [];
    final migrated = <Account>[];
    for (final raw in rawAccounts) {
      try {
        final account = Account.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map));
        final password = account.pass;
        if (password.isNotEmpty) {
          await _secure.write(
              key: _passwordKey(account.id), value: password);
          _passwords[account.id] = password;
        } else {
          _passwords[account.id] =
              await _secure.read(key: _passwordKey(account.id)) ?? '';
        }
        migrated.add(Account(account.name, account.url, account.user, '', avatar: account.avatar));
      } catch (_) {
        // Ignore malformed legacy entries without preventing app startup.
      }
    }

    // Migrate the single-account format used by older app versions.
    if (migrated.isEmpty && (_p.getString('url') ?? '').isNotEmpty) {
      final user = _p.getString('user') ?? '';
      final account = Account(
        user.isEmpty ? 'حسابي' : user,
        _p.getString('url')!,
        user,
        _p.getString('pass') ?? '',
      );
      if (account.pass.isNotEmpty) {
        await _secure.write(
            key: _passwordKey(account.id), value: account.pass);
        _passwords[account.id] = account.pass;
      }
      migrated.add(Account(account.name, account.url, account.user, ''));
      await _p.remove('url');
      await _p.remove('user');
      await _p.remove('pass');
    }

    if (rawAccounts.isNotEmpty || migrated.isNotEmpty) {
      await _p.setStringList(
        'accounts',
        migrated.map((a) => jsonEncode(a.toJson())).toList(),
      );
    }

    if (!_p.containsKey('cloud_profiles_updated_at')) {
      await _p.setInt('cloud_profiles_updated_at',
          migrated.isNotEmpty ? DateTime.now().millisecondsSinceEpoch : 0);
    }

    // Migrate legacy sync timestamps into the active Xtream profile namespace.
    final profileId = cloudProfileId;
    final legacyNow = DateTime.now().millisecondsSinceEpoch;
    final favoriteTimeKey = 'cloud_favorites_updated_at_$profileId';
    final historyTimeKey = 'cloud_history_updated_at_$profileId';
    if (!_p.containsKey(favoriteTimeKey)) {
      final legacyTime = _p.getInt('cloud_favorites_updated_at');
      final hasLocalFavorites = ['live', 'vod', 'series']
          .any((type) => (_p.getStringList('${_pre}fav_$type') ?? []).isNotEmpty);
      await _p.setInt(favoriteTimeKey, legacyTime ?? (hasLocalFavorites ? legacyNow : 0));
    }
    if (!_p.containsKey(historyTimeKey)) {
      final legacyTime = _p.getInt('cloud_history_updated_at');
      final hasLocalHistory = (_p.getStringList('${_pre}hist') ?? []).isNotEmpty;
      await _p.setInt(historyTimeKey, legacyTime ?? (hasLocalHistory ? legacyNow : 0));
    }

    _pinCache = await _secure.read(key: 'parental_pin');
    final legacyPin = _p.getString('pin');
    if (_pinCache == null && legacyPin != null && legacyPin.isNotEmpty) {
      await _secure.write(key: 'parental_pin', value: legacyPin);
      _pinCache = legacyPin;
    }
    await _p.remove('pin');

    // One-time migration: publish existing device-local PIN hashes into the
    // authenticated encrypted profile vault so the website can manage them.
    if (!(_p.getBool('cloud_profile_pin_hash_v1_migrated') ?? false)) {
      var hasExistingProfilePin = false;
      for (final account in accounts()) {
        if (await ProfilePinService.hasPin(account.id)) {
          hasExistingProfilePin = true;
          break;
        }
      }
      if (hasExistingProfilePin) {
        await _p.setInt('cloud_profiles_updated_at',
            DateTime.now().millisecondsSinceEpoch);
      }
      await _p.setBool('cloud_profile_pin_hash_v1_migrated', true);
    }

    // Create a one-time, device-local lock marker on first launch.
    // A secure-storage failure must never prevent the app from starting;
    // adult filtering remains fail-closed through the always-on kidsMode getter.
    try {
      await _ensureAdultContentLock();
    } catch (_) {
      // Retry marker creation on a later launch; keep content filtering enabled.
    }
    await _p.setBool('kids_mode', true);
  }

  static const String _adultContentLockId = 'mesut_global_adult_content_lock_v1';

  static Future<void> _ensureAdultContentLock() async {
    if (await ProfilePinService.hasPin(_adultContentLockId)) return;
    final pin = List<String>.generate(
      6,
      (_) => Random.secure().nextInt(10).toString(),
    ).join();
    // Store only the salted PBKDF2 hash; never expose or persist the PIN.
    await ProfilePinService.setPin(_adultContentLockId, pin);
  }

  // ---------------- اللغة ----------------
  static String get lang => _p.getString('lang') ?? 'ar';
  static Future<void> setLang(String v) async { await _p.setString('lang', v); await _markCloudSettingsChanged(); }

  // ---------------- الحسابات ----------------
  static List<Account> accounts() => (_p.getStringList('accounts') ?? [])
      .map((s) => Account.fromJson(jsonDecode(s)))
      .map((a) => Account(
            a.name,
            a.url,
            a.user,
            _passwords[a.id] ?? '',
            avatar: a.avatar,
          ))
      .toList();

  static Account? get active {
    final list = accounts();
    if (list.isEmpty) return null;
    final index = _p.getInt('active') ?? 0;
    return list[index < 0 || index >= list.length ? 0 : index];
  }

  static int get activeIndex => _p.getInt('active') ?? 0;

  static Future<void> _saveAccounts(List<Account> list) async {
    await _p.setStringList(
      'accounts',
      list.map((a) => jsonEncode(
          {'name': a.name, 'url': a.url, 'user': a.user, 'pass': '', 'avatar': a.avatar})).toList(),
    );
  }

  static Future<void> addAccount(Account account) async {
    final list = accounts();
    final index = list.indexWhere((a) => a.id == account.id);
    if (index < 0 && list.length >= 5) {
      throw Exception('يسمح حساب MESUT بخمسة بروفايلات كحد أقصى. احذف بروفايلاً غير مستخدم أولاً.');
    }
    // Save the secret first; only publish account metadata after it succeeds.
    await _secure.write(
        key: _passwordKey(account.id), value: account.pass); 
    _passwords[account.id] = account.pass;
    if (index >= 0) {
      list[index] = Account(account.name, account.url, account.user, account.pass,
          avatar: account.avatar.isNotEmpty ? account.avatar : list[index].avatar);
    } else {
      const avatarIds = <String>[
        'preset:man', 'preset:glasses', 'preset:woman', 'preset:beard',
        'preset:elder', 'preset:elder-woman', 'preset:boy', 'preset:girl',
        'preset:child', 'preset:person', 'preset:cool', 'preset:family',
      ];
      final avatar = account.avatar.isNotEmpty
          ? account.avatar
          : avatarIds[Random.secure().nextInt(avatarIds.length)];
      list.add(Account(account.name, account.url, account.user, account.pass,
          avatar: avatar));
    }
    await _saveAccounts(list);
    await _p.setInt('active', index >= 0 ? index : list.length - 1);
    await _markCloudProfilesChanged();
  }

  static Future<void> updateAccountAvatar(String accountId, String avatar) async {
    final list = accounts();
    final index = list.indexWhere((account) => account.id == accountId);
    if (index < 0) return;
    final old = list[index];
    list[index] = Account(old.name, old.url, old.user, old.pass, avatar: avatar);
    await _saveAccounts(list);
    await _markCloudProfilesChanged();
  }

  /// Replace a profile's Xtream details without losing its avatar, PIN or
  /// profile-scoped preferences. Credentials remain in secure storage.
  static Future<void> updateAccount(String oldId, Account replacement) async {
    final list = accounts();
    final index = list.indexWhere((account) => account.id == oldId);
    if (index < 0) throw Exception('البروفايل غير موجود');
    final duplicate = list.indexWhere(
        (account) => account.id == replacement.id && account.id != oldId);
    if (duplicate >= 0) throw Exception('هذا الاشتراك موجود بالفعل');

    final old = list[index];
    final previousActive = _p.getInt('active') ?? 0;
    final next = Account(
      replacement.name,
      replacement.url,
      replacement.user,
      replacement.pass,
      avatar: replacement.avatar.isNotEmpty ? replacement.avatar : old.avatar,
    );
    final pinHash = oldId == next.id
        ? null
        : await ProfilePinService.exportHash(oldId);

    await _secure.write(key: _passwordKey(next.id), value: next.pass);
    _passwords[next.id] = next.pass;
    if (oldId != next.id) {
      if (pinHash != null) {
        await ProfilePinService.importHash(next.id, pinHash);
      }
      for (final suffix in [
        'hidden_categories_live',
        'hidden_categories_vod',
        'hidden_categories_series',
      ]) {
        final value = _p.getStringList('${oldId}|$suffix');
        if (value != null) await _p.setStringList('${next.id}|$suffix', value);
        await _p.remove('${oldId}|$suffix');
      }
      await _secure.delete(key: _passwordKey(oldId));
      _passwords.remove(oldId);
      await ProfilePinService.remove(oldId);
    }
    list[index] = next;
    await _saveAccounts(list);
    await _p.setInt('active', previousActive.clamp(0, list.length - 1).toInt());
    await _markCloudProfilesChanged();
  }

  static Future<void> setActive(int index) async {
    await _p.setInt('active', index);
    await _markCloudProfilesChanged();
  }

  static Future<void> removeAccount(int index) async {
    final list = accounts();
    if (index < 0 || index >= list.length) return;
    final removed = list.removeAt(index);
    await _secure.delete(key: _passwordKey(removed.id));
    _passwords.remove(removed.id);
    await _saveAccounts(list);
    await _p.setInt('active', 0);
    await _markCloudProfilesChanged();
  }

  static String get _pre => '${active?.id ?? 'x'}|';
  // Hash the Xtream profile identity; never upload its URL or username.
  static String get cloudProfileId => sha256
      .convert(utf8.encode(active?.id ?? 'no-active-account'))
      .toString();

  // ---------------- الإعدادات ----------------
  static String get liveFormat => _p.getString('fmt') ?? 'ts';
  static Future<void> setLiveFormat(String v) async { await _p.setString('fmt', v); await _markCloudSettingsChanged(); }

  // Playback defaults are device-local so phone and TV can keep independent controls.
  static double get playbackSpeed {
    final value = _p.getDouble('playback_speed') ?? 1.0;
    return [0.75, 1.0, 1.25, 1.5, 2.0].contains(value) ? value : 1.0;
  }
  static Future<void> setPlaybackSpeed(double value) async {
    if (![0.75, 1.0, 1.25, 1.5, 2.0].contains(value)) return;
    await _p.setDouble('playback_speed', value);
  }

  static String get playbackFit {
    final value = _p.getString('playback_fit') ?? 'contain';
    return ['contain', 'cover', 'fill'].contains(value) ? value : 'contain';
  }
  static Future<void> setPlaybackFit(String value) async {
    if (!['contain', 'cover', 'fill'].contains(value)) return;
    await _p.setString('playback_fit', value);
  }

  static String? get pin => _pinCache;
  static Future<void> setPin(String? value) async {
    if (value == null || value.isEmpty) {
      await _secure.delete(key: 'parental_pin');
      _pinCache = null;
    } else {
      await _secure.write(key: 'parental_pin', value: value);
      _pinCache = value;
    }
    await _p.remove('pin');
  }

  // ---------------- المفضلة ----------------
  static List<MediaItem> favs(String type) =>
      (_p.getStringList('${_pre}fav_$type') ?? [])
          .map((s) => MediaItem.fromJson(jsonDecode(s))).toList();

  static bool isFav(String type, String id) =>
      favs(type).any((e) => e.id == id);

  static Future<bool> toggleFav(String type, MediaItem item) async {
    final list = favs(type);
    final index = list.indexWhere((e) => e.id == item.id);
    if (index >= 0) {
      list.removeAt(index);
    } else {
      list.add(item);
    }
    await _p.setStringList('${_pre}fav_$type',
        list.map((e) => jsonEncode(e.toJson())).toList());
    await _markCloudCollectionChanged('favorites');
    return index < 0;
  }

  // ---------------- آخر قناة ----------------
  static MediaItem? lastLive() {
    final value = _p.getString('${_pre}last');
    return value == null ? null : MediaItem.fromJson(jsonDecode(value));
  }
  static Future<void> saveLast(MediaItem item) async =>
      _p.setString('${_pre}last', jsonEncode(item.toJson()));

  // ---------------- سجل المشاهدة ----------------
  static List<Map<String, dynamic>> _histRaw() =>
      (_p.getStringList('${_pre}hist') ?? [])
          .map((s) => Map<String, dynamic>.from(jsonDecode(s))).toList();

  static List<HistoryEntry> history() => _histRaw().map((e) => HistoryEntry(
        PlayItem('${e['key']}', '${e['title']}', '${e['url']}', '${e['image']}'),
        (e['pos'] as num?)?.toInt() ?? 0,
        (e['dur'] as num?)?.toInt() ?? 0,
        (e['ts'] as num?)?.toInt() ?? 0,
        ext: (e['ext'] ?? 'mp4').toString(),
      )).toList();

  static int position(String key) {
    for (final entry in _histRaw()) {
      if (entry['key'] == key) return (entry['pos'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  static Future<void> saveProgress(
      PlayItem item, int pos, int dur, {bool syncCloud = false}) async {
    final list = _histRaw().where((e) => e['key'] != item.key).toList();
    final finished = dur > 0 && pos > dur * 0.95;
    if (!finished && pos > 3000) {
      final uri = Uri.tryParse(item.url);
      final path = uri != null && uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : '';
      final dot = path.lastIndexOf('.');
      final extension = dot >= 0 && dot < path.length - 1
          ? path.substring(dot + 1)
          : 'mp4';
      list.insert(0, {
        'key': item.key, 'title': item.title, 'url': item.url,
        'image': item.image, 'pos': pos, 'dur': dur, 'ext': extension,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
    }
    await _p.setStringList('${_pre}hist',
        list.take(30).map((e) => jsonEncode(e)).toList());
    // Playback position is saved locally every 10 seconds. Cloud sync is
    // requested only at meaningful boundaries (leaving/completing playback).
    if (syncCloud) await _markCloudCollectionChanged('history');
  }

  // ---------------- الصفحة الرئيسية ----------------
  static const defaultHome = ['continue', 'recent', 'favorites'];
  static List<String> homeOrder() {
    final list = _p.getStringList('home_order') ?? defaultHome;
    final output = list.where(defaultHome.contains).toList();
    for (final item in defaultHome) {
      if (!output.contains(item)) output.add(item);
    }
    return output;
  }
  static Future<void> setHomeOrder(List<String> list) async {
    await _p.setStringList('home_order', list);
    await _markCloudSettingsChanged();
  }
  static Set<String> homeHidden() =>
      (_p.getStringList('home_hidden') ?? []).toSet();
  static Future<void> setHomeHidden(Set<String> values) async {
    await _p.setStringList('home_hidden', values.toList());
    await _markCloudSettingsChanged();
  }

  // ---------------- شوهد مؤخراً ----------------
  static List<PlayItem> recent() =>
      (_p.getStringList('${_pre}recent') ?? [])
          .map((s) => Map<String, dynamic>.from(jsonDecode(s)))
          .map((e) => PlayItem('${e['key']}', '${e['title']}',
              '${e['url']}', '${e['image']}')).toList();

  static Future<void> addRecent(PlayItem item) async {
    final list = recent().where((e) => e.key != item.key).toList()
      ..insert(0, item);
    await _p.setStringList('${_pre}recent', list.take(20).map((e) =>
        jsonEncode({'key': e.key, 'title': e.title, 'url': e.url, 'image': e.image})).toList());
  }

  // ---------------- الرياضة ----------------
  // Adult-content protection is a permanent app policy for every profile.
  static bool get kidsMode => true;
  static Future<void> setKidsMode(bool value) async {
    await _p.setBool('kids_mode', true);
  }

  static Set<String> hiddenCategories(String type) =>
      (_p.getStringList('${_pre}hidden_categories_$type') ?? <String>[]).toSet();

  static Future<void> setCategoryHidden(String type, String id, bool hidden) async {
    if (!['live', 'vod', 'series'].contains(type)) return;
    final values = hiddenCategories(type);
    if (hidden) {
      values.add(id);
    } else {
      values.remove(id);
    }
    await _p.setStringList('${_pre}hidden_categories_$type', values.toList());
    await _markCloudProfilesChanged();
  }

  static String get sportsKey => _p.getString('sports_key') ?? '3';
  static Future<void> setSportsKey(String value) async {
    await _p.setString('sports_key', value.trim().isEmpty ? '3' : value.trim());
    await _markCloudSettingsChanged();
  }

  // ---------------- نسخ احتياطي آمن ----------------
  // Credentials, PIN and account records are intentionally excluded.
  static String exportAll() {
    const sensitive = {'accounts', 'url', 'user', 'pass', 'pin', 'kids_mode'};
    final data = <String, dynamic>{};
    for (final key in _p.getKeys()) {
      // Playback history/recent entries contain stream URLs with Xtream credentials.
      if (sensitive.contains(key) ||
          key.startsWith('account_password_') ||
          key.endsWith('|hist') ||
          key.endsWith('|recent')) continue;
      data[key] = _p.get(key);
    }
    return jsonEncode({'app': 'mesut_iptv', 'v': 2, 'data': data});
  }

  static Future<bool> importAll(String text) async {
    try {
      final decoded = jsonDecode(text.trim());
      if (decoded is! Map || decoded['app'] != 'mesut_iptv' ||
          decoded['data'] is! Map) return false;
      final data = Map<String, dynamic>.from(decoded['data'] as Map);
      const blocked = {'accounts', 'url', 'user', 'pass', 'pin', 'active', 'kids_mode'};
      for (final entry in data.entries) {
        if (blocked.contains(entry.key) ||
            entry.key.startsWith('account_password_') ||
            entry.key.endsWith('|hist') ||
            entry.key.endsWith('|recent')) continue;
        final value = entry.value;
        if (value is String) {
          await _p.setString(entry.key, value);
        } else if (value is bool) {
          await _p.setBool(entry.key, value);
        } else if (value is int) {
          await _p.setInt(entry.key, value);
        } else if (value is double) {
          await _p.setDouble(entry.key, value);
        } else if (value is List && value.every((e) => e is String)) {
          await _p.setStringList(entry.key, List<String>.from(value));
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }


  // ---------------- مزامنة سحابية آمنة ----------------
  // لا نرفع كلمات مرور IPTV أو روابط البث أو صوراً قد تحتوي على روابط موقعة.
  static Future<void> _markCloudCollectionChanged(String collection) async {
    final key = collection == 'favorites'
        ? 'cloud_favorites_updated_at'
        : 'cloud_history_updated_at';
    await _p.setInt('${key}_${cloudProfileId}', DateTime.now().millisecondsSinceEpoch);
    await _notifyCloudChanged();
  }

  static Future<void> _markCloudSettingsChanged() async {
    await _p.setInt('cloud_settings_updated_at', DateTime.now().millisecondsSinceEpoch);
    await _notifyCloudChanged();
  }

  static Future<void> notifyCloudProfilesChanged() => _markCloudProfilesChanged();

  static Future<void> _markCloudProfilesChanged() async {
    await _p.setInt('cloud_profiles_updated_at',
        DateTime.now().millisecondsSinceEpoch);
    await _notifyCloudChanged();
  }

  // Export every IPTV profile plus safe per-profile preferences. Credentials
  // are returned only to the caller for client-side authenticated encryption.
  static Future<Map<String, dynamic>> cloudProfilesSnapshot() async {
    final profileList = <Map<String, dynamic>>[];
    for (final account in accounts()) {
      final prefix = '${account.id}|';
      final settings = <String, dynamic>{};
      for (final suffix in [
        'hidden_categories_live',
        'hidden_categories_vod',
        'hidden_categories_series',
      ]) {
        final value = _p.get('$prefix$suffix');
        if (value is List) settings[suffix] = value.whereType<String>().toList();
      }
      profileList.add({
        'id': sha256.convert(utf8.encode(account.id)).toString(),
        'name': account.name,
        'avatar': account.avatar,
        'url': account.url,
        'username': account.user,
        'password': account.pass,
        'pinHash': await ProfilePinService.exportHash(account.id),
        'settings': settings,
      });
    }
    return {
      'updatedAt': _p.getInt('cloud_profiles_updated_at') ?? 0,
      'activeId': active == null
          ? null
          : sha256.convert(utf8.encode(active!.id)).toString(),
      'profiles': profileList,
    };
  }

  // Called only after the encrypted cloud payload has been authenticated and
  // decrypted on this device.
  static Future<void> applyCloudProfiles(Map<String, dynamic> payload) async {
    final raw = payload['profiles'];
    if (raw is! List) return;
    final restored = <Account>[];
    final settingsById = <String, Map<String, dynamic>>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final value = Map<String, dynamic>.from(item);
      final url = value['url']?.toString().trim() ?? '';
      final username = value['username']?.toString() ?? '';
      final password = value['password']?.toString() ?? '';
      if (url.isEmpty || username.isEmpty || password.isEmpty) continue;
      final account = Account(
        value['name']?.toString().trim().isNotEmpty == true
            ? value['name'].toString()
            : username,
        url,
        username,
        password,
        avatar: value['avatar']?.toString() ?? '',
      );
      if (value['id']?.toString() !=
          sha256.convert(utf8.encode(account.id)).toString()) continue;
      if (restored.any((existing) => existing.id == account.id)) continue;
      await _secure.write(key: _passwordKey(account.id), value: password);
      _passwords[account.id] = password;
      restored.add(Account(account.name, account.url, account.user, password, avatar: account.avatar));
      if (value.containsKey('pinHash')) {
        await ProfilePinService.importHash(account.id, value['pinHash']?.toString());
      }
      if (value['settings'] is Map) {
        settingsById[account.id] =
            Map<String, dynamic>.from(value['settings'] as Map);
      }
    }
    if (restored.isEmpty && raw.isNotEmpty) return;
    final restoredIds = restored.map((account) => account.id).toSet();
    for (final previous in accounts()) {
      if (!restoredIds.contains(previous.id)) {
        await _secure.delete(key: _passwordKey(previous.id));
        _passwords.remove(previous.id);
        await ProfilePinService.remove(previous.id);
      }
    }
    await _saveAccounts(restored);
    for (final account in restored) {
      final settings = settingsById[account.id] ?? {};
      for (final suffix in [
        'hidden_categories_live',
        'hidden_categories_vod',
        'hidden_categories_series',
      ]) {
        final values = settings[suffix];
        if (values is List && values.every((entry) => entry is String)) {
          await _p.setStringList(
              '${account.id}|$suffix', List<String>.from(values));
        }
      }
    }
    final activeId = payload['activeId']?.toString();
    final activeIndex = restored.indexWhere((account) =>
        sha256.convert(utf8.encode(account.id)).toString() == activeId);
    await _p.setInt('active', activeIndex >= 0 ? activeIndex : 0);
    final updatedAt = payload['updatedAt'];
    if (updatedAt is num) {
      await _p.setInt('cloud_profiles_updated_at', updatedAt.toInt());
    }
  }

  static Map<String, dynamic> cloudSnapshot() {
    final profileId = cloudProfileId;
    final favorites = <String, dynamic>{};
    for (final type in ['live', 'vod', 'series']) {
      favorites[type] = favs(type).map((item) => {
        'id': item.id,
        'name': item.name,
        'rating': item.rating,
        'extra': item.extra,
        'plot': item.plot,
      }).toList();
    }
    final safeHistory = _histRaw().map((entry) => {
      'key': entry['key'],
      'title': entry['title'],
      'pos': entry['pos'],
      'dur': entry['dur'],
      'ext': entry['ext'] ?? 'mp4',
      'ts': entry['ts'],
    }).toList();
    return {
      'profile_id': profileId,
      'favorites': {'profiles': {profileId: favorites}},
      'watch_history': {'profiles': {profileId: safeHistory}},
      'sync_meta': {
        'favorites': {
          profileId: _p.getInt('cloud_favorites_updated_at_$profileId') ?? 0,
        },
        'watch_history': {
          profileId: _p.getInt('cloud_history_updated_at_$profileId') ?? 0,
        },
      },
      'settings': {
        'lang': lang,
        'fmt': liveFormat,
        'home_order': homeOrder(),
        'home_hidden': homeHidden().toList(),
        'kids_mode': true,
        'sports_key': sportsKey,
        '_updatedAt': _p.getInt('cloud_settings_updated_at') ?? 0,
      },
    };
  }

  static Future<void> applyCloudRecords(
      Map<String, dynamic> records, {String? profileId}) async {
    final selectedProfile = profileId ?? cloudProfileId;
    final meta = records['sync_meta'];
    if (meta is Map) {
      final values = Map<String, dynamic>.from(meta);
      final favoriteMeta = values['favorites'];
      final historyMeta = values['watch_history'];
      final favoriteTime = favoriteMeta is Map
          ? favoriteMeta[selectedProfile]
          : favoriteMeta;
      final historyTime = historyMeta is Map
          ? historyMeta[selectedProfile]
          : historyMeta;
      if (favoriteTime is num) {
        await _p.setInt(
            'cloud_favorites_updated_at_$selectedProfile', favoriteTime.toInt());
      }
      if (historyTime is num) {
        await _p.setInt(
            'cloud_history_updated_at_$selectedProfile', historyTime.toInt());
      }
    }

    final rawFavorites = records['favorites'];
    dynamic favoriteRecord = rawFavorites;
    if (rawFavorites is Map && rawFavorites['profiles'] is Map) {
      favoriteRecord = (rawFavorites['profiles'] as Map)[selectedProfile];
    }
    if (favoriteRecord is Map) {
      for (final type in ['live', 'vod', 'series']) {
        final values = favoriteRecord[type];
        if (values is List) {
          final items = <String>[];
          for (final value in values) {
            if (value is Map) {
              final map = Map<String, dynamic>.from(value);
              map['image'] = '';
              try {
                items.add(jsonEncode(MediaItem.fromJson(map).toJson()));
              } catch (_) {}
            }
          }
          await _p.setStringList('${_pre}fav_$type', items);
        }
      }
    }

    // Restore only the selected Xtream profile's watch history. Stream URLs
    // and image URLs stay local; the app rebuilds playback URLs from Xtream IDs.
    final rawHistory = records['watch_history'];
    dynamic historyRecord = rawHistory;
    if (rawHistory is Map && rawHistory['profiles'] is Map) {
      historyRecord = (rawHistory['profiles'] as Map)[selectedProfile];
    }
    if (historyRecord is List) {
      final localByKey = <String, Map<String, dynamic>>{
        for (final entry in _histRaw())
          if (entry['key'] != null)
            entry['key'].toString(): Map<String, dynamic>.from(entry),
      };
      final merged = <String, Map<String, dynamic>>{};
      for (final value in historyRecord) {
        if (value is! Map) continue;
        final remote = Map<String, dynamic>.from(value);
        final key = remote['key']?.toString();
        if (key == null || key.isEmpty) continue;
        final local = localByKey[key] ?? <String, dynamic>{};
        merged[key] = {
          ...local,
          ...remote,
          'url': local['url'] ?? '',
          'image': local['image'] ?? '',
        };
      }
      final entries = merged.values.toList()
        ..sort((a, b) => ((b['ts'] as num?)?.toInt() ?? 0)
            .compareTo((a['ts'] as num?)?.toInt() ?? 0));
      await _p.setStringList(
        '${_pre}hist',
        entries.take(30).map((entry) => jsonEncode(entry)).toList(),
      );
    }

    final settings = records['settings'];
    if (settings is Map) {
      final values = Map<String, dynamic>.from(settings);
      if (values['lang'] is String && ['ar', 'fr', 'en'].contains(values['lang'])) {
        await _p.setString('lang', values['lang'] as String);
      }
      if (values['fmt'] is String && ['ts', 'm3u8'].contains(values['fmt'])) {
        await _p.setString('fmt', values['fmt'] as String);
      }
      if (values['home_order'] is List && (values['home_order'] as List).every((e) => e is String)) {
        await _p.setStringList('home_order', List<String>.from(values['home_order'] as List));
      }
      if (values['home_hidden'] is List && (values['home_hidden'] as List).every((e) => e is String)) {
        await _p.setStringList('home_hidden', List<String>.from(values['home_hidden'] as List));
      }
      // Ignore cloud attempts to disable the permanent local content lock.
      await _p.setBool('kids_mode', true);
      if (values['sports_key'] is String) {
        await _p.setString('sports_key', values['sports_key'] as String);
      }
      if (values['_updatedAt'] is num) {
        await _p.setInt('cloud_settings_updated_at', (values['_updatedAt'] as num).toInt());
      }
      cloudSettingsAppliedCallback?.call();
    }
  }

  static Future<void> clearHistory() async {
    await _p.remove('${_pre}hist');
    await _markCloudCollectionChanged('history');
  }
  static Future<void> clearRecent() async { await _p.remove('${_pre}recent'); }
  static Future<void> clearFavs() async {
    for (final type in ['live', 'vod', 'series']) {
      await _p.remove('${_pre}fav_$type');
    }
    await _markCloudCollectionChanged('favorites');
  }
}
