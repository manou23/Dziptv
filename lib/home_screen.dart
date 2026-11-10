import 'package:flutter/material.dart' hide Text;
import 'app_info.dart';
import 'i18n.dart';
import 'theme.dart';
import 'models.dart';
import 'store.dart';
import 'xtream_service.dart';
import 'live_screen.dart';
import 'media_grid_screen.dart';
import 'movie_detail_screen.dart';
import 'series_detail_screen.dart';
import 'player_screen.dart';
import 'settings_screen.dart';
import 'profiles_screen.dart';
import 'sports_screen.dart';
import 'search_screen.dart';
import 'utils.dart';

class HomeScreen extends StatefulWidget {
  final XtreamService service;
  const HomeScreen({super.key, required this.service});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<Map<String, String>> _acc = widget.service.account();

  XtreamService get s => widget.service;

  Future<void> _push(Widget w) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));
    if (mounted) setState(() {});
  }

  void _openLive([MediaItem? it]) => _push(LiveScreen(service: s, initial: it));

  void _openVod(MediaItem it) => _push(MovieDetailScreen(service: s, item: it));

  void _openSeriesItem(MediaItem it) => _push(SeriesDetailScreen(service: s, item: it));

  void _openMovies() => _push(MediaGridScreen(
        title: 'Films',
        type: 'vod',
        loadCats: s.vodCategories,
        loadItems: s.vodStreams,
        onOpen: (c, it) => Navigator.of(c).push<void>(MaterialPageRoute<void>(
            builder: (_) => MovieDetailScreen(service: s, item: it))),
      ));

  void _openSeries() => _push(MediaGridScreen(
        title: 'Séries',
        type: 'series',
        loadCats: s.seriesCategories,
        loadItems: s.seriesList,
        onOpen: (c, it) => Navigator.of(c).push<void>(MaterialPageRoute<void>(
            builder: (_) => SeriesDetailScreen(service: s, item: it))),
      ));

  // ---------------- الرأس ----------------
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [kViolet, kAccent]),
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(kAppName,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text('by $kBrand',
                  style: const TextStyle(fontSize: 11, color: Colors.white54)),
            ],
          ),
          const Spacer(),
          IconButton(
            tooltip: tr('بحث'),
            icon: const Icon(Icons.search_rounded),
            onPressed: () => _push(SearchScreen(service: s)),
          ),
          IconButton(
            tooltip: tr('تبديل الحساب'),
            icon: const Icon(Icons.switch_account_rounded),
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<void>(builder: (_) => const ProfilesScreen()),
              (r) => false,
            ),
          ),
          IconButton(
            tooltip: tr('الإعدادات'),
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => _push(SettingsScreen(service: s)),
          ),
        ],
      ),
    );
  }

  // ---------------- البطل (آخر ما شاهدته) ----------------
  Widget _hero() {
    final hist = Store.history().where((entry) => !Store.kidsMode || !isAdult(entry.item.title)).toList();
    final h = hist.isNotEmpty ? hist.first : null;
    final p = (h != null && h.dur > 0) ? (h.pos / h.dur).clamp(0.0, 1.0) : 0.0;
    final bgFallback = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF3A229A), Color(0xFF12307A)],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: SizedBox(
        height: 180,
        child: TvFocus(
          radius: 22,
          onTap: h == null ? _openLive : () => _push(PlayerScreen(items: [h.item])),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (h != null && h.item.image.isNotEmpty)
                Image.network(h.item.image,
                    fit: BoxFit.cover, errorBuilder: (_, __, ___) => bgFallback)
              else
                bgFallback,
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h == null ? kAppName : h.item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(h == null ? 'ابدأ المشاهدة' : 'متابعة المشاهدة',
                        style: const TextStyle(fontSize: 13, color: kAccent)),
                    if (h != null) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: p, minHeight: 3, color: kAccent),
                    ],
                  ],
                ),
              ),
              const Positioned(
                top: 12,
                right: 12,
                child: Icon(Icons.play_circle_fill_rounded, size: 36, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- الأقسام الرئيسية ----------------
  Widget _tiles(bool wide) {
    final tiles = <Widget>[
      _Tile(
        title: 'TV Direct',
        subtitle: 'البث المباشر',
        icon: Icons.live_tv_rounded,
        colors: const [Color(0xFF7C5CFF), Color(0xFF3B2A99)],
        onTap: () => _openLive(),
      ),
      _Tile(
        title: 'Films',
        subtitle: 'الأفلام',
        icon: Icons.movie_rounded,
        colors: const [Color(0xFF2D9CFF), Color(0xFF123F7A)],
        onTap: _openMovies,
      ),
      _Tile(
        title: 'Séries',
        subtitle: 'المسلسلات',
        icon: Icons.video_library_rounded,
        colors: const [Color(0xFF1FB5A0), Color(0xFF0B5C52)],
        onTap: _openSeries,
      ),
      _Tile(
        title: 'Sports',
        subtitle: 'الرياضة',
        icon: Icons.sports_soccer_rounded,
        colors: const [Color(0xFFE5486D), Color(0xFF7A1F3A)],
        onTap: () => _push(const SportsScreen()),
      ),
    ];
    if (wide) {
      return SizedBox(height: 100, child: Row(children: tiles));
    }
    return Column(
      children: [
        SizedBox(height: 96, child: Row(children: [tiles[0], tiles[1]])),
        SizedBox(height: 96, child: Row(children: [tiles[2], tiles[3]])),
      ],
    );
  }

  // ---------------- صفوف المحتوى ----------------
  Widget _row(String title, List<Widget> cards) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 100,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => cards[i],
          ),
        ),
      ],
    );
  }

  Widget _section(String id) {
    if (id == 'continue') {
      final l = Store.history().where((entry) => !Store.kidsMode || !isAdult(entry.item.title)).toList();
      if (l.isEmpty) return const SizedBox.shrink();
      return _row('متابعة المشاهدة', [
        for (final h in l)
          _MiniCard(
            image: h.item.image,
            title: h.item.title,
            progress: h.dur > 0 ? (h.pos / h.dur).clamp(0.0, 1.0) : null,
            onTap: () => _push(PlayerScreen(items: [h.item])),
          ),
      ]);
    }
    if (id == 'recent') {
      final l = Store.recent().where((item) => !Store.kidsMode || !isAdult(item.title)).toList();
      if (l.isEmpty) return const SizedBox.shrink();
      return _row('شوهد مؤخراً', [
        for (final it in l)
          _MiniCard(
            image: it.image,
            title: it.title,
            onTap: () => _push(PlayerScreen(items: [it])),
          ),
      ]);
    }
    if (id == 'favorites') {
      final live = Store.favs('live').where((item) => !Store.kidsMode || !isAdult(item.name)).toList();
      final vod = Store.favs('vod').where((item) => !Store.kidsMode || !isAdult(item.name)).toList();
      final series = Store.favs('series').where((item) => !Store.kidsMode || !isAdult(item.name)).toList();
      if (live.isEmpty && vod.isEmpty && series.isEmpty) return const SizedBox.shrink();
      return _row('المفضلة', [
        for (final it in live)
          _MiniCard(
              image: it.image,
              title: it.name,
              contain: true,
              badge: Icons.live_tv_rounded,
              onTap: () => _openLive(it)),
        for (final it in vod)
          _MiniCard(
              image: it.image,
              title: it.name,
              badge: Icons.movie_rounded,
              onTap: () => _openVod(it)),
        for (final it in series)
          _MiniCard(
              image: it.image,
              title: it.name,
              badge: Icons.video_library_rounded,
              onTap: () => _openSeriesItem(it)),
      ]);
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final order = Store.homeOrder();
    final hidden = Store.homeHidden();
    return Scaffold(
      body: Container(
        decoration: kBgGradient,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 12),
            children: [
              _header(),
              _hero(),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: LayoutBuilder(builder: (_, box) => _tiles(box.maxWidth >= 640)),
              ),
              for (final id in order)
                if (!hidden.contains(id)) _section(id),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                child: GlassBox(
                  radius: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: FutureBuilder<Map<String, String>>(
                    future: _acc,
                    builder: (_, snap) {
                      final a = snap.data;
                      return Row(
                        children: [
                          const Icon(Icons.person_rounded, size: 20, color: kAccent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(s.name,
                                overflow: TextOverflow.ellipsis,
                                textDirection: TextDirection.ltr),
                          ),
                          const Icon(Icons.event_rounded, size: 18, color: Colors.white60),
                          const SizedBox(width: 4),
                          Text(a == null ? '...' : '${tr('ينتهي')}: ${a['exp']}',
                              style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 14),
                          const Icon(Icons.devices_rounded, size: 18, color: Colors.white60),
                          const SizedBox(width: 4),
                          Text(a == null ? '...' : '${a['conn']}',
                              style: const TextStyle(fontSize: 13)),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;
  const _Tile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: SizedBox.expand(
          child: TvFocus(
            radius: 20,
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [colors[0].withOpacity(0.6), colors[1].withOpacity(0.3)],
                ),
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Colors.white12),
                    child: Icon(icon, size: 26, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final String image, title;
  final double? progress;
  final bool contain;
  final IconData? badge;
  final VoidCallback onTap;
  const _MiniCard({
    required this.image,
    required this.title,
    required this.onTap,
    this.progress,
    this.contain = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: TvFocus(
        radius: 14,
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Colors.white10),
            if (image.isNotEmpty)
              Padding(
                padding: contain ? const EdgeInsets.all(14) : EdgeInsets.zero,
                child: Image.network(
                  image,
                  fit: contain ? BoxFit.contain : BoxFit.cover,
                  cacheWidth: 320,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
            if (badge != null)
              Positioned(
                top: 6,
                left: 6,
                child: Icon(badge, size: 16, color: Colors.white70),
              ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 10,
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            if (progress != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(value: progress, minHeight: 3, color: kAccent),
              ),
          ],
        ),
      ),
    );
  }
}
