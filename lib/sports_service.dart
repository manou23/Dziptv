import 'dart:convert';
import 'package:http/http.dart' as http;
import 'store.dart';

class League {
  final String id, name;
  const League(this.id, this.name);
}

class SportEvent {
  final String id, league, home, away, homeBadge, awayBadge, homeScore, awayScore, status;
  final DateTime? time;
  const SportEvent(this.id, this.league, this.home, this.away, this.homeBadge,
      this.awayBadge, this.homeScore, this.awayScore, this.status, this.time);
}

class _Cached {
  final DateTime at;
  final List<SportEvent> list;
  _Cached(this.at, this.list);
}

/// مصدر البيانات: TheSportsDB (مفتاح مجاني افتراضي). يمكن تغيير المفتاح من الإعدادات.
class SportsService {
  static const leagues = [
    League('4328', 'Premier League'),
    League('4335', 'La Liga'),
    League('4332', 'Serie A'),
    League('4331', 'Bundesliga'),
    League('4334', 'Ligue 1'),
    League('4480', 'Champions League'),
  ];

  static final Map<String, _Cached> _cache = {};

  static Future<List<SportEvent>> events(String leagueId, {required bool upcoming}) async {
    final key = '${Store.sportsKey}|$leagueId|$upcoming';
    final c = _cache[key];
    if (c != null && DateTime.now().difference(c.at) < const Duration(minutes: 5)) {
      return c.list;
    }
    final path = upcoming ? 'eventsnextleague.php' : 'eventspastleague.php';
    final uri = Uri.parse(
        'https://www.thesportsdb.com/api/v1/json/${Store.sportsKey}/$path?id=$leagueId');
    final r = await http.get(uri).timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    final d = jsonDecode(utf8.decode(r.bodyBytes));
    final raw = (d is Map && d['events'] is List) ? d['events'] as List : const [];
    final list = raw.map(_parse).toList();
    list.sort((a, b) {
      final ta = a.time ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.time ?? DateTime.fromMillisecondsSinceEpoch(0);
      return upcoming ? ta.compareTo(tb) : tb.compareTo(ta);
    });
    _cache[key] = _Cached(DateTime.now(), list);
    return list;
  }

  static SportEvent _parse(dynamic e) {
    String s(String k) => (e[k] ?? '').toString();
    DateTime? t;
    final ts = s('strTimestamp');
    if (ts.isNotEmpty) {
      t = DateTime.tryParse(ts.endsWith('Z') ? ts : '${ts}Z')?.toLocal();
    }
    if (t == null && s('dateEvent').isNotEmpty) {
      final time = s('strTime').isEmpty ? '00:00:00' : s('strTime');
      t = DateTime.tryParse('${s('dateEvent')}T${time}Z')?.toLocal();
    }
    return SportEvent(
      s('idEvent'),
      s('strLeague'),
      s('strHomeTeam'),
      s('strAwayTeam'),
      s('strHomeTeamBadge'),
      s('strAwayTeamBadge'),
      s('intHomeScore'),
      s('intAwayScore'),
      s('strStatus'),
      t,
    );
  }
}
