import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import 'app_info.dart';
import 'app_config.dart';
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
import 'services_home_screen.dart';
import 'profiles_screen.dart';
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
  late final Future<List<MediaItem>> _featuredFuture;
  final PageController _featuredController = PageController();
  Timer? _featuredTimer;
  int _featuredIndex = 0;
  int _featuredCount = 0;

  @override
  void initState() {
    super.initState();
    _featuredFuture = widget.service.allVod();
    _featuredTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted || _featuredCount < 2) return;
      final next = (_featuredIndex + 1) % _featuredCount;
      _featuredController.animateToPage(next,
          duration: const Duration(milliseconds: 650), curve: Curves.easeInOutCubic);
    });
  }

  @override
  void dispose() {
    _featuredTimer?.cancel();
    _featuredController.dispose();
    super.dispose();
  }

  XtreamService get s => widget.service;

  Future<void> _push(Widget w) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));
    if (mounted) setState(() {});
  }

  PlayItem _resolveHistoryItem(HistoryEntry entry) {
    final item = entry.item;
    if (item.url.isNotEmpty) return item;
    if (item.key.startsWith('vod_')) {
      final id = item.key.substring(4);
      return PlayItem(item.key, item.title, s.movieUrl(id, entry.ext), item.image);
    }
    if (item.key.startsWith('ep_')) {
      final id = item.key.substring(3);
      return PlayItem(item.key, item.title, s.episodeUrl(id, entry.ext), item.image);
    }
    return item;
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
                  style: TextStyle(fontSize: kIsTvBuild ? 28 : 20, fontWeight: FontWeight.bold)),
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
              MaterialPageRoute<void>(builder: (_) => const ServicesHomeScreen()),
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

  // Mobile-first Netflix-inspired discovery header.
  Widget _mobileHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(colors: [kViolet, kAccent]),
          ),
          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 27),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Text('MESUT', style: TextStyle(
          fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: 1.4))),
        _topAction(Icons.people_alt_rounded, 'البروفايلات', () => _push(const ProfilesScreen())),
        _topAction(Icons.search_rounded, 'البحث', () => _push(SearchScreen(service: s))),
        _topAction(Icons.favorite_rounded, 'المفضلة', _openFavorites),
        _topAction(Icons.settings_rounded, 'الإعدادات', () => _push(SettingsScreen(service: s))),
      ]),
    );
  }

  Widget _topAction(IconData icon, String label, VoidCallback action) => IconButton(
    tooltip: label, onPressed: action, visualDensity: VisualDensity.compact,
    icon: Icon(icon, size: 22, color: Colors.white.withOpacity(0.88)),
  );

  Widget _mobileHero() {
    return FutureBuilder<List<MediaItem>>(
      future: _featuredFuture,
      builder: (context, snapshot) {
        final movies = (snapshot.data ?? const <MediaItem>[])
            .where((item) => !Store.kidsMode || !isAdult(item.name))
            .take(12).toList();
        _featuredCount = movies.length;
        if (movies.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Container(
              height: 270, decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(colors: [Color(0xFF30245F), Color(0xFF101C38)],
                    begin: Alignment.topRight, end: Alignment.bottomLeft),
              ),
              child: Center(child: snapshot.connectionState == ConnectionState.waiting
                  ? const CircularProgressIndicator(color: kAccent)
                  : const Text('أضف اشتراكك لعرض مكتبة الأفلام', style: TextStyle(color: Colors.white70))),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: SizedBox(
            height: 310,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(children: [
                PageView.builder(
                  controller: _featuredController,
                  itemCount: movies.length,
                  onPageChanged: (index) => setState(() => _featuredIndex = index),
                  itemBuilder: (context, index) {
                    final movie = movies[index];
                    return GestureDetector(
                      onTap: () => _openVod(movie),
                      child: Stack(fit: StackFit.expand, children: [
                        if (movie.image.isNotEmpty)
                          Image.network(movie.image, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: const Color(0xFF202A4B))),
                        if (movie.image.isEmpty) Container(color: const Color(0xFF202A4B)),
                        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [Color(0x16000000), Color(0xEE080D1B)],
                          stops: [0.12, 1.0],
                        ))),
                        Positioned(left: 18, right: 18, bottom: 22, child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(7)),
                              child: const Text('اكتشف الآن', style: TextStyle(
                                color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900)),
                            ),
                            const SizedBox(height: 10),
                            Text(movie.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.12)),
                            const SizedBox(height: 12),
                            Row(children: [
                              FilledButton.icon(
                                onPressed: () => _openVod(movie),
                                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                                label: const Text('شاهد الآن'),
                                style: FilledButton.styleFrom(backgroundColor: Colors.white,
                                  foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 17)),
                              ),
                              const SizedBox(width: 10),
                              if (movie.rating.isNotEmpty) Text('★ ${movie.rating}',
                                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                            ]),
                          ],
                        )),
                      ]),
                    );
                  },
                ),
                Positioned(top: 14, right: 16, child: Row(children: [
                  const Icon(Icons.auto_awesome_rounded, color: Colors.white70, size: 15),
                  const SizedBox(width: 5),
                  Text('مختارات من مكتبتك', style: TextStyle(
                    color: Colors.white.withOpacity(0.9), fontSize: 11, fontWeight: FontWeight.w700)),
                ])),
                Positioned(bottom: 8, right: 18, child: Row(children: [
                  for (var i = 0; i < movies.length; i++)
                    AnimatedContainer(duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.only(left: 4), width: i == _featuredIndex ? 18 : 5,
                      height: 5, decoration: BoxDecoration(
                        color: i == _featuredIndex ? kAccent : Colors.white54,
                        borderRadius: BorderRadius.circular(8))),
                ])),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _mobileMoviesRow() {
    return FutureBuilder<List<MediaItem>>(
      future: _featuredFuture,
      builder: (context, snapshot) {
        final movies = (snapshot.data ?? const <MediaItem>[])
            .where((item) => !Store.kidsMode || !isAdult(item.name)).take(18).toList();
        if (movies.isEmpty) return const SizedBox.shrink();
        return _row('أحدث الأفلام', [for (final movie in movies)
          _MiniCard(image: movie.image, title: movie.name, onTap: () => _openVod(movie))]);
      },
    );
  }

  Widget _mobileBottomBar() {
    Widget item(IconData icon, String label, VoidCallback action) => Expanded(
      child: InkWell(onTap: action, borderRadius: BorderRadius.circular(14),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 22, color: Colors.white.withOpacity(0.92)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        )),
      ),
    );
    return SafeArea(top: false, child: Container(
      decoration: BoxDecoration(color: const Color(0xF20B1228),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.10)))),
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 3),
      child: Row(children: [
        item(Icons.live_tv_rounded, 'بث مباشر', () => _openLive()),
        item(Icons.movie_filter_rounded, 'أفلام', _openMovies),
        item(Icons.video_library_rounded, 'مسلسلات', _openSeries),
      ]),
    ));
  }

  void _openFavorites() {
    final live = Store.favs('live');
    final vod = Store.favs('vod');
    final series = Store.favs('series');
    showModalBottomSheet<void>(
      context: context, isScrollControlled: true, backgroundColor: const Color(0xFF101A32),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(child: SizedBox(height: MediaQuery.of(sheetContext).size.height * 0.72,
        child: ListView(padding: const EdgeInsets.all(18), children: [
          const Text('المفضلة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          if (live.isEmpty && vod.isEmpty && series.isEmpty)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('لم تضف أي عنصر إلى المفضلة بعد'))),
          for (final item in live) ListTile(leading: const Icon(Icons.live_tv_rounded), title: Text(item.name),
            onTap: () { Navigator.pop(sheetContext); _openLive(item); }),
          for (final item in vod) ListTile(leading: const Icon(Icons.movie_rounded), title: Text(item.name),
            onTap: () { Navigator.pop(sheetContext); _openVod(item); }),
          for (final item in series) ListTile(leading: const Icon(Icons.video_library_rounded), title: Text(item.name),
            onTap: () { Navigator.pop(sheetContext); _openSeriesItem(item); }),
        ]))),
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
        height: kIsTvBuild ? 300 : 196,
        child: TvFocus(
          radius: 22,
          autofocus: kIsTvBuild,
          onTap: h == null ? _openLive : () => _push(PlayerScreen(items: [_resolveHistoryItem(h)])),
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
                        style: TextStyle(fontSize: kIsTvBuild ? 30 : 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(h == null ? 'ابدأ المشاهدة' : 'متابعة المشاهدة',
                        style: TextStyle(fontSize: kIsTvBuild ? 18 : 13, color: kAccent)),
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
    ];
    if (wide) {
      return SizedBox(height: kIsTvBuild ? 138 : 100, child: Row(children: tiles));
    }
    return Column(
      children: [
        SizedBox(height: 104, child: Row(children: [tiles[0], tiles[1]])),
        SizedBox(height: 104, child: Row(children: [tiles[2], const Expanded(child: SizedBox())])),
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
          height: kIsTvBuild ? 164 : 116,
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
            onTap: () => _push(PlayerScreen(items: [_resolveHistoryItem(h)])),
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
    if (!kIsTvBuild) {
      final order = Store.homeOrder();
      final hidden = Store.homeHidden();
      return Scaffold(
        body: Container(decoration: kBgGradient, child: SafeArea(child: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            _mobileHeader(),
            _mobileHero(),
            _mobileMoviesRow(),
            for (final id in order)
              if (!hidden.contains(id) && id != 'favorites') _section(id),
            Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: GlassBox(
              radius: 15, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: FutureBuilder<Map<String, String>>(future: _acc, builder: (_, snap) {
                final account = snap.data;
                return Row(children: [
                  const Icon(Icons.person_rounded, size: 18, color: kAccent),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s.name, overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 12))),
                  Text(account == null ? '...' : '${tr('ينتهي')}: ${account['exp']}',
                    style: const TextStyle(fontSize: 11, color: Colors.white70)),
                ]);
              }),
            )),
          ],
        ))),
        bottomNavigationBar: _mobileBottomBar(),
      );
    }
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
                          Expanded(child: Text(s.name, overflow: TextOverflow.ellipsis,
                              textDirection: TextDirection.ltr)),
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
      width: kIsTvBuild ? 240 : 164,
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
                  style: TextStyle(fontSize: kIsTvBuild ? 17 : 13, fontWeight: FontWeight.bold)),
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
