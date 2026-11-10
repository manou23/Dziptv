import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class Store {
  static late SharedPreferences _p;

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    // ترحيل الحساب القديم (الإصدارات السابقة) إلى قائمة الحسابات
    if ((_p.getStringList('accounts') ?? []).isEmpty && _p.getString('url') != null) {
      final u = _p.getString('user') ?? '';
      await addAccount(Account(u.isEmpty ? 'حسابي' : u, _p.getString('url')!, u,
          _p.getString('pass') ?? ''));
    }
  }

  // ---------------- اللغة ----------------
  static String get lang => _p.getString('lang') ?? 'ar';
  static Future<void> setLang(String v) async {
    await _p.setString('lang', v);
  }

  // ---------------- الحسابات ----------------
  static List<Account> accounts() => (_p.getStringList('accounts') ?? [])
      .map((s) => Account.fromJson(jsonDecode(s)))
      .toList();

  static Account? get active {
    final l = accounts();
    if (l.isEmpty) return null;
    final i = (_p.getInt('active') ?? 0);
    return l[i < 0 || i >= l.length ? 0 : i];
  }

  static int get activeIndex => _p.getInt('active') ?? 0;

  static Future<void> _saveAccounts(List<Account> l) async {
    await _p.setStringList(
        'accounts', l.map((a) => jsonEncode(a.toJson())).toList());
  }

  static Future<void> addAccount(Account a) async {
    final l = accounts();
    final i = l.indexWhere((x) => x.id == a.id);
    if (i >= 0) {
      l[i] = a;
    } else {
      l.add(a);
    }
    await _saveAccounts(l);
    await _p.setInt('active', i >= 0 ? i : l.length - 1);
  }

  static Future<void> setActive(int i) async {
    await _p.setInt('active', i);
  }

  static Future<void> removeAccount(int i) async {
    final l = accounts();
    if (i < 0 || i >= l.length) return;
    l.removeAt(i);
    await _saveAccounts(l);
    await _p.setInt('active', 0);
  }

  static String get _pre => '${active?.id ?? 'x'}|';

  // ---------------- الإعدادات ----------------
  static String get liveFormat => _p.getString('fmt') ?? 'ts';
  static Future<void> setLiveFormat(String v) async {
    await _p.setString('fmt', v);
  }

  static String? get pin => _p.getString('pin');
  static Future<void> setPin(String? v) async {
    if (v == null) {
      await _p.remove('pin');
    } else {
      await _p.setString('pin', v);
    }
  }

  // ---------------- المفضلة ----------------
  static List<MediaItem> favs(String type) =>
      (_p.getStringList('${_pre}fav_$type') ?? [])
          .map((s) => MediaItem.fromJson(jsonDecode(s)))
          .toList();

  static bool isFav(String type, String id) =>
      favs(type).any((e) => e.id == id);

  /// يعيد true إذا أصبح العنصر في المفضلة
  static Future<bool> toggleFav(String type, MediaItem it) async {
    final l = favs(type);
    final i = l.indexWhere((e) => e.id == it.id);
    if (i >= 0) {
      l.removeAt(i);
    } else {
      l.add(it);
    }
    await _p.setStringList(
        '${_pre}fav_$type', l.map((e) => jsonEncode(e.toJson())).toList());
    return i < 0;
  }

  // ---------------- آخر قناة ----------------
  static MediaItem? lastLive() {
    final s = _p.getString('${_pre}last');
    if (s == null) return null;
    return MediaItem.fromJson(jsonDecode(s));
  }

  static Future<void> saveLast(MediaItem it) async {
    await _p.setString('${_pre}last', jsonEncode(it.toJson()));
  }

  // ---------------- سجل المشاهدة ----------------
  static List<Map<String, dynamic>> _histRaw() =>
      (_p.getStringList('${_pre}hist') ?? [])
          .map((s) => Map<String, dynamic>.from(jsonDecode(s)))
          .toList();

  static List<HistoryEntry> history() => _histRaw()
      .map((e) => HistoryEntry(
            PlayItem('${e['key']}', '${e['title']}', '${e['url']}',
                '${e['image']}'),
            (e['pos'] as num?)?.toInt() ?? 0,
            (e['dur'] as num?)?.toInt() ?? 0,
            (e['ts'] as num?)?.toInt() ?? 0,
          ))
      .toList();

  static int position(String key) {
    for (final e in _histRaw()) {
      if (e['key'] == key) return (e['pos'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  static Future<void> saveProgress(PlayItem it, int pos, int dur) async {
    final l = _histRaw().where((e) => e['key'] != it.key).toList();
    final finished = dur > 0 && pos > dur * 0.95;
    if (!finished && pos > 3000) {
      l.insert(0, {
        'key': it.key,
        'title': it.title,
        'url': it.url,
        'image': it.image,
        'pos': pos,
        'dur': dur,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
    }
    await _p.setStringList(
        '${_pre}hist', l.take(30).map((e) => jsonEncode(e)).toList());
  }

  // ---------------- الصفحة الرئيسية ----------------
  static const defaultHome = ['continue', 'recent', 'favorites'];

  static List<String> homeOrder() {
    final l = _p.getStringList('home_order') ?? defaultHome;
    final out = l.where(defaultHome.contains).toList();
    for (final d in defaultHome) {
      if (!out.contains(d)) out.add(d);
    }
    return out;
  }

  static Future<void> setHomeOrder(List<String> l) async {
    await _p.setStringList('home_order', l);
  }

  static Set<String> homeHidden() => (_p.getStringList('home_hidden') ?? []).toSet();

  static Future<void> setHomeHidden(Set<String> s) async {
    await _p.setStringList('home_hidden', s.toList());
  }

  // ---------------- شوهد مؤخراً ----------------
  static List<PlayItem> recent() => (_p.getStringList('${_pre}recent') ?? [])
      .map((s) => Map<String, dynamic>.from(jsonDecode(s)))
      .map((e) => PlayItem('${e['key']}', '${e['title']}', '${e['url']}', '${e['image']}'))
      .toList();

  static Future<void> addRecent(PlayItem it) async {
    final l = recent().where((e) => e.key != it.key).toList();
    l.insert(0, it);
    await _p.setStringList(
        '${_pre}recent',
        l
            .take(20)
            .map((e) => jsonEncode(
                {'key': e.key, 'title': e.title, 'url': e.url, 'image': e.image}))
            .toList());
  }

  // ---------------- الرياضة ----------------
  static String get sportsKey => _p.getString('sports_key') ?? '3';
  static Future<void> setSportsKey(String v) async {
    await _p.setString('sports_key', v.trim().isEmpty ? '3' : v.trim());
  }

  // ---------------- نسخ احتياطي ----------------
  static String exportAll() {
    final m = <String, dynamic>{};
    for (final k in _p.getKeys()) {
      m[k] = _p.get(k);
    }
    return jsonEncode({'app': 'mesut_iptv', 'v': 1, 'data': m});
  }

  static Future<bool> importAll(String text) async {
    try {
      final j = jsonDecode(text.trim());
      if (j is! Map || j['app'] != 'mesut_iptv') return false;
      final m = Map<String, dynamic>.from(j['data']);
      for (final e in m.entries) {
        final v = e.value;
        if (v is String) {
          await _p.setString(e.key, v);
        } else if (v is bool) {
          await _p.setBool(e.key, v);
        } else if (v is int) {
          await _p.setInt(e.key, v);
        } else if (v is double) {
          await _p.setDouble(e.key, v);
        } else if (v is List) {
          await _p.setStringList(e.key, v.map((x) => '$x').toList());
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> clearHistory() async {
    await _p.remove('${_pre}hist');
  }

  static Future<void> clearRecent() async {
    await _p.remove('${_pre}recent');
  }

  static Future<void> clearFavs() async {
    for (final t in ['live', 'vod', 'series']) {
      await _p.remove('${_pre}fav_$t');
    }
  }
}
