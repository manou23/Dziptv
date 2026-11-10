import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class Store {
  static late SharedPreferences _p;
  static const FlutterSecureStorage _secure = FlutterSecureStorage();
  static final Map<String, String> _passwords = {};
  static String? _pinCache;
  // Installed by main.dart so every relevant local change queues cloud sync.
  static Future<void> Function()? cloudSyncCallback;

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
        migrated.add(Account(account.name, account.url, account.user, ''));
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

    _pinCache = await _secure.read(key: 'parental_pin');
    final legacyPin = _p.getString('pin');
    if (_pinCache == null && legacyPin != null && legacyPin.isNotEmpty) {
      await _secure.write(key: 'parental_pin', value: legacyPin);
      _pinCache = legacyPin;
    }
    await _p.remove('pin');
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
          {'name': a.name, 'url': a.url, 'user': a.user, 'pass': ''})).toList(),
    );
  }

  static Future<void> addAccount(Account account) async {
    // Save the secret first; only publish account metadata after it succeeds.
    await _secure.write(
        key: _passwordKey(account.id), value: account.pass);
    _passwords[account.id] = account.pass;
    final list = accounts();
    final index = list.indexWhere((a) => a.id == account.id);
    if (index >= 0) {
      list[index] = Account(account.name, account.url, account.user, account.pass);
    } else {
      list.add(account);
    }
    await _saveAccounts(list);
    await _p.setInt('active', index >= 0 ? index : list.length - 1);
  }

  static Future<void> setActive(int index) async {
    await _p.setInt('active', index);
  }

  static Future<void> removeAccount(int index) async {
    final list = accounts();
    if (index < 0 || index >= list.length) return;
    final removed = list.removeAt(index);
    await _secure.delete(key: _passwordKey(removed.id));
    _passwords.remove(removed.id);
    await _saveAccounts(list);
    await _p.setInt('active', 0);
  }

  static String get _pre => '${active?.id ?? 'x'}|';

  // ---------------- الإعدادات ----------------
  static String get liveFormat => _p.getString('fmt') ?? 'ts';
  static Future<void> setLiveFormat(String v) async { await _p.setString('fmt', v); await _markCloudSettingsChanged(); }

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
    await _notifyCloudChanged();
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
      )).toList();

  static int position(String key) {
    for (final entry in _histRaw()) {
      if (entry['key'] == key) return (entry['pos'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  static Future<void> saveProgress(PlayItem item, int pos, int dur) async {
    final list = _histRaw().where((e) => e['key'] != item.key).toList();
    final finished = dur > 0 && pos > dur * 0.95;
    if (!finished && pos > 3000) {
      list.insert(0, {
        'key': item.key, 'title': item.title, 'url': item.url,
        'image': item.image, 'pos': pos, 'dur': dur,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
    }
    await _p.setStringList('${_pre}hist',
        list.take(30).map((e) => jsonEncode(e)).toList());
    await _notifyCloudChanged();
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
  static String get sportsKey => _p.getString('sports_key') ?? '3';
  static Future<void> setSportsKey(String value) async {
    await _p.setString('sports_key', value.trim().isEmpty ? '3' : value.trim());
    await _markCloudSettingsChanged();
  }

  // ---------------- نسخ احتياطي آمن ----------------
  // Credentials, PIN and account records are intentionally excluded.
  static String exportAll() {
    const sensitive = {'accounts', 'url', 'user', 'pass', 'pin'};
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
      const blocked = {'accounts', 'url', 'user', 'pass', 'pin', 'active'};
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
  static Future<void> _markCloudSettingsChanged() async {
    await _p.setInt('cloud_settings_updated_at', DateTime.now().millisecondsSinceEpoch);
    await _notifyCloudChanged();
  }

  static Map<String, dynamic> cloudSnapshot() {
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
      'ts': entry['ts'],
    }).toList();
    return {
      'favorites': favorites,
      'watch_history': safeHistory,
      'settings': {
        'lang': lang,
        'fmt': liveFormat,
        'home_order': homeOrder(),
        'home_hidden': homeHidden().toList(),
        'sports_key': sportsKey,
        '_updatedAt': _p.getInt('cloud_settings_updated_at') ?? 0,
      },
    };
  }

  static Future<void> applyCloudRecords(Map<String, dynamic> records) async {
    final favoriteRecord = records['favorites'];
    if (favoriteRecord is Map) {
      for (final type in ['live', 'vod', 'series']) {
        final values = favoriteRecord[type];
        if (values is List) {
          final items = <String>[];
          for (final value in values) {
            if (value is Map) {
              final map = Map<String, dynamic>.from(value);
              map['image'] = '';
              try { items.add(jsonEncode(MediaItem.fromJson(map).toJson())); } catch (_) {}
            }
          }
          await _p.setStringList('${_pre}fav_$type', items);
        }
      }
    }
    // Restore cloud watch history while preserving local playback URLs/images.
    // Stream URLs are deliberately never uploaded to the MESUT cloud.
    final historyRecord = records['watch_history'];
    if (historyRecord is List) {
      final merged = <String, Map<String, dynamic>>{};
      for (final entry in _histRaw()) {
        final key = entry['key']?.toString();
        if (key != null && key.isNotEmpty) merged[key] = Map<String, dynamic>.from(entry);
      }
      for (final value in historyRecord) {
        if (value is! Map) continue;
        final remote = Map<String, dynamic>.from(value);
        final key = remote['key']?.toString();
        if (key == null || key.isEmpty) continue;
        final local = merged[key] ?? <String, dynamic>{};
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
      if (values['sports_key'] is String) {
        await _p.setString('sports_key', values['sports_key'] as String);
      }
      if (values['_updatedAt'] is num) {
        await _p.setInt('cloud_settings_updated_at', (values['_updatedAt'] as num).toInt());
      }
    }
  }

  static Future<void> clearHistory() async {
    await _p.remove('${_pre}hist');
    await _notifyCloudChanged();
  }
  static Future<void> clearRecent() async { await _p.remove('${_pre}recent'); }
  static Future<void> clearFavs() async {
    for (final type in ['live', 'vod', 'series']) {
      await _p.remove('${_pre}fav_$type');
    }
    await _notifyCloudChanged();
  }
}
