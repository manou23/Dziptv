import 'package:flutter/material.dart' hide Text;
import 'i18n.dart';
import 'theme.dart';
import 'utils.dart';
import 'sports_service.dart';

class SportsScreen extends StatefulWidget {
  const SportsScreen({super.key});

  @override
  State<SportsScreen> createState() => _SportsScreenState();
}

class _SportsScreenState extends State<SportsScreen> {
  int _league = 0;
  bool _upcoming = true;
  late Future<List<SportEvent>> _future = _load();

  Future<List<SportEvent>> _load() => SportsService.events(
        SportsService.leagues[_league].id,
        upcoming: _upcoming,
      );

  void _reload() => setState(() => _future = _load());

  String _day(DateTime t) =>
      '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}';

  Widget _team(String name, String badge) {
    return Expanded(
      child: Column(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: badge.isEmpty
                ? const Icon(Icons.shield_outlined, color: Colors.white38)
                : Image.network(
                    badge,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.shield_outlined, color: Colors.white38),
                  ),
          ),
          const SizedBox(height: 6),
          Text(name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5)),
        ],
      ),
    );
  }

  Widget _card(SportEvent e) {
    final hasScore = e.homeScore.isNotEmpty && e.awayScore.isNotEmpty;
    final t = e.time;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 5, 14, 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          _team(e.home, e.homeBadge),
          SizedBox(
            width: 92,
            child: Column(
              children: [
                if (hasScore)
                  Text('${e.homeScore} - ${e.awayScore}',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold, color: kAccent))
                else
                  Text(t == null ? 'VS' : hm(t),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold, color: kAccent)),
                const SizedBox(height: 4),
                if (t != null)
                  Text(_day(t),
                      style: const TextStyle(fontSize: 11.5, color: Colors.white54)),
              ],
            ),
          ),
          _team(e.away, e.awayBadge),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الرياضة'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _reload),
        ],
      ),
      body: Container(
        decoration: kBgGradient,
        child: Column(
          children: [
            SizedBox(
              height: 46,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                scrollDirection: Axis.horizontal,
                itemCount: SportsService.leagues.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ChoiceChip(
                  label: Text(SportsService.leagues[i].name),
                  selected: i == _league,
                  onSelected: (_) {
                    _league = i;
                    _reload();
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('المباريات القادمة')),
                    ButtonSegment(value: false, label: Text('النتائج')),
                  ],
                  selected: {_upcoming},
                  onSelectionChanged: (v) {
                    _upcoming = v.first;
                    _reload();
                  },
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<SportEvent>>(
                future: _future,
                builder: (_, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('تعذر تحميل البيانات',
                              style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 10),
                          FilledButton(
                              onPressed: _reload, child: const Text('إعادة المحاولة')),
                        ],
                      ),
                    );
                  }
                  final list = snap.data ?? const <SportEvent>[];
                  if (list.isEmpty) {
                    return const Center(
                        child: Text('لا توجد مباريات',
                            style: TextStyle(color: Colors.white54)));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _card(list[i]),
                  );
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('المصدر: TheSportsDB - النتائج المباشرة تتطلب مفتاحاً مدفوعاً',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.white38)),
            ),
          ],
        ),
      ),
    );
  }
}
