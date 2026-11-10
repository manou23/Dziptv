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
  late final Future<List<MediaItem>> _seriesFuture;
  final PageController _featuredController = PageController();
  final ScrollController _mobileScrollController = ScrollController();
  Timer? _featuredTimer;
  int _featuredIndex = 0;
  int _featuredCount = 0;

  @override
  void initState() {
    super.initState();
    _featuredFuture = widget.service.allVod();
    _seriesFuture = widget.service.allSeries();
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
    _mobileScrollController.dispose();
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

  // ---------------- تجربة الهاتف: واجهة اكتشاف سينمائية ----------------
  Widget _mobileHeader() {
    final active = Store.active;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 14, 8),
      child: Row(children: [
        Container(
          width: 34, height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [kViolet, kAccent],
            ),
          ),
          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 27),
        ),
        const SizedBox(width: 9),
        const Expanded(child: Text('MESUT', style: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5,
        ))),
        _mobileHeaderAction(Icons.search_rounded, 'بحث', () => _push(SearchScreen(service: s))),
        const SizedBox(width: 3),
        _mobileHeaderAction(Icons.tune_rounded, 'الإعدادات', () => _push(SettingsScreen(service: s))),
        const SizedBox(width: 7),
        GestureDetector(
          onTap: () => _push(const ProfilesScreen()),
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: const kPanel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: Center(child: Text(
              (active?.name.trim().isNotEmpty == true ? active!.name.trim()[0] : 'M').toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white),
            )),
          ),
        ),
      ]),
    );
  }

  Widget _mobileHeaderAction(IconData icon, String label, VoidCallback action) =>
      IconButton(
        tooltip: tr(label),
        onPressed: action,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
        icon: Icon(icon, size: 22, color: Colors.white.withOpacity(0.9)),
      );

  Widget _mobileBrowseTabs() {
    Widget tab(String label, VoidCallback action, {bool selected = false}) =>
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 9),
          child: Material(
            color: selected ? Colors.white : const kPanel2,
            borderRadius: BorderRadius.circular(7),
            child: InkWell(
              borderRadius: BorderRadius.circular(7),
              onTap: action,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                child: Text(label, style: TextStyle(
                  color: selected ? const kBg : Colors.white,
                  fontSize: 12, fontWeight: FontWeight.w800,
                )),
              ),
            ),
          ),
        );
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        children: [
          tab('لك', () => _mobileScrollController.animateTo(0,
            duration: const Duration(milliseconds: 350), curve: Curves.easeOut), selected: true),
          tab('أفلام', _openMovies),
          tab('مسلسلات', _openSeries),
          tab('مباشر', () => _openLive()),
        ],
      ),
    );
  }

  List<MediaItem> _latestMovies(List<MediaItem> source, {int limit = 18}) {
    final filtered = source
        .where((item) => !Store.kidsMode || !isAdult(item.name))
        .toList();
    if (filtered.any((item) => item.added > 0)) {
      final indexed = filtered.asMap().entries.toList();
      indexed.sort((a, b) {
        final byDate = b.value.added.compareTo(a.value.added);
        return byDate != 0 ? byDate : a.key.compareTo(b.key);
      });
      return indexed.take(limit).map((entry) => entry.value).toList();
    }
    return filtered.take(limit).toList();
  }

  Widget _mobileHero() {
    return FutureBuilder<List<MediaItem>>(
      future: _featuredFuture,
      builder: (context, snapshot) {
        final movies = _latestMovies(snapshot.data ?? const <MediaItem>[], limit: 12);
        _featuredCount = movies.length;
        if (movies.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 18),
            child: Container(
              height: 405,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  begin: Alignment.topRight, end: Alignment.bottomLeft,
                  colors: [Color(0xFF1A2760), kPanel, kBg],
                ),
              ),
              child: Center(child: snapshot.connectionState == ConnectionState.waiting
                ? const CircularProgressIndicator(color: kViolet)
                : const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('أضف اشتراكك لعرض مكتبة الأفلام',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 15)),
                  )),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 16),
          child: SizedBox(
            height: 440,
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
                          cacheWidth: 900,
                          errorBuilder: (_, __, ___) => Container(color: const kPanel2))
                      else
                        Container(color: const kPanel2),
                      const DecoratedBox(decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [
                            Color(0x9907090D), Color(0x1107090D),
                            Color(0x2207090D), Color(0xF5090A0D),
                          ],
                          stops: [0.0, 0.28, 0.48, 1.0],
                        ),
                      )),
                      Positioned(
                        left: 22, right: 22, bottom: 26,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                              decoration: BoxDecoration(
                                color: const kViolet,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('اختيار MESUT',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6, color: Colors.white)),
                            ),
                            const SizedBox(height: 13),
                            Text(movie.name, maxLines: 2, textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 27, height: 1.12,
                                fontWeight: FontWeight.w900, color: Colors.white,
                                shadows: [Shadow(color: Colors.black54, blurRadius: 12)])),
                            const SizedBox(height: 10),
                            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Icon(Icons.auto_awesome_rounded, color: kAccent, size: 15),
                              const SizedBox(width: 5),
                              Text(movie.rating.isNotEmpty ? movie.rating : 'من مكتبتك',
                                style: const TextStyle(fontSize: 12, color: Colors.white70,
                                  fontWeight: FontWeight.w700)),
                            ]),
                            const SizedBox(height: 17),
                            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              FilledButton.icon(
                                onPressed: () => _openVod(movie),
                                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                                label: const Text('تشغيل'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: kViolet,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(126, 44),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton.icon(
                                onPressed: () => _openVod(movie),
                                icon: const Icon(Icons.info_outline_rounded, size: 19),
                                label: const Text('التفاصيل'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: kAccent),
                                  minimumSize: const Size(126, 44),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 18),
                            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              for (var i = 0; i < movies.length; i++)
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  width: i == _featuredIndex ? 19 : 5,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: i == _featuredIndex ? const kViolet : Colors.white54,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                            ]),
                          ],
                        ),
                      ),
                    ]),
                  );
                },
              ),
              Positioned(
                top: 15, left: 18, right: 18,
                child: Row(children: [
                  const Text('MESUT', style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2,
                    color: Colors.white, shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                  )),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black38,
                      borderRadius: BorderRadius.circular(4)),
                    child: const Text('مميز لك', style: TextStyle(
                      color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _mobilePosterRow(String title, List<MediaItem> items, ValueChanged<MediaItem> onOpen,
      {required String favoriteType, VoidCallback? onSeeAll}) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(17, 12, 17, 11),
        child: Row(children: [
          Expanded(child: Text(title, style: const TextStyle(
            fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white))),
          if (onSeeAll != null)
            InkWell(onTap: onSeeAll, child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4, horizontal: 3),
              child: Row(children: [
                Text('عرض الكل', style: TextStyle(fontSize: 11,
                  color: kMuted, fontWeight: FontWeight.w700)),
                Icon(Icons.chevron_right_rounded, size: 17, color: kMuted),
              ]),
            )),
        ]),
      ),
      SizedBox(
        height: 211,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 17),
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            return SizedBox(
              width: 119,
              child: GestureDetector(
                onTap: () => onOpen(item),
                onLongPress: () async {
                  await Store.toggleFav(favoriteType, item);
                  if (mounted) setState(() {});
                },
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Stack(fit: StackFit.expand, children: [
                      Container(color: const kPanel2),
                      if (item.image.isNotEmpty)
                        Image.network(item.image, fit: BoxFit.cover, cacheWidth: 300,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                      if (item.image.isEmpty)
                        const Center(child: Icon(Icons.movie_creation_outlined,
                          size: 32, color: Colors.white24)),
                      Positioned(left: 5, top: 5, child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.black54,
                          borderRadius: BorderRadius.circular(4)),
                        child: const Icon(Icons.play_arrow_rounded, size: 13, color: Colors.white),
                      )),
                    ]),
                  )),
                  const SizedBox(height: 7),
                  Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, height: 1.2,
                      color: Colors.white, fontWeight: FontWeight.w700)),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _mobileMoviesRow() {
    return FutureBuilder<List<MediaItem>>(
      future: _featuredFuture,
      builder: (context, snapshot) => _mobilePosterRow(
        'أحدث الأفلام', _latestMovies(snapshot.data ?? const <MediaItem>[], limit: 18),
        _openVod, favoriteType: 'vod', onSeeAll: _openMovies,
      ),
    );
  }

  Widget _mobileSeriesRow() {
    return FutureBuilder<List<MediaItem>>(
      future: _seriesFuture,
      builder: (context, snapshot) {
        final items = _latestMovies(snapshot.data ?? const <MediaItem>[], limit: 18);
        return _mobilePosterRow('مسلسلات قد تعجبك', items, _openSeriesItem, favoriteType: 'series', onSeeAll: _openSeries);
      },
    );
  }

  Widget _mobileBottomBar() {
    Widget item(IconData icon, String label, VoidCallback action, {bool selected = false}) =>
        Expanded(child: InkWell(
          onTap: action,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 22,
                color: selected ? Colors.white : Colors.white54),
              const SizedBox(height: 4),
              Text(label, maxLines: 1, style: TextStyle(
                fontSize: 10, fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                color: selected ? Colors.white : Colors.white54)),
            ]),
          ),
        ));
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xF20A0B0F),
          border: Border(top: BorderSide(color: Color(0xFF292B32), width: 0.8)),
        ),
        padding: const EdgeInsets.fromLTRB(5, 4, 5, 2),
        child: Row(children: [
          item(Icons.home_rounded, 'الرئيسية', () {
            if (_mobileScrollController.hasClients) {
              _mobileScrollController.animateTo(0,
                duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
            }
          }, selected: true),
          item(Icons.live_tv_rounded, 'TV', () => _openLive()),
          item(Icons.movie_filter_rounded, 'أفلام', _openMovies),
          item(Icons.video_library_rounded, 'مسلسلات', _openSeries),
        ]),
      ),
    );
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
        backgroundColor: const kBg,
        body: Container(
          color: const kBg,
          child: SafeArea(
            bottom: false,
            child: ListView(
              controller: _mobileScrollController,
              padding: const EdgeInsets.only(bottom: 22),
              children: [
                _mobileHeader(),
                _mobileBrowseTabs(),
                _mobileHero(),
                for (final id in order)
                  if (!hidden.contains(id) && id == 'continue') _section(id),
                _mobileMoviesRow(),
                _mobileSeriesRow(),
                for (final id in order)
                  if (!hidden.contains(id) && id != 'continue' && id != 'favorites') _section(id),
                if (!hidden.contains('favorites')) _section('favorites'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(17, 18, 17, 10),
                  child: FutureBuilder<Map<String, String>>(
                    future: _acc,
                    builder: (_, snap) {
                      final account = snap.data;
                      return Row(children: [
                        const Icon(Icons.verified_user_outlined, size: 15, color: Colors.white38),
                        const SizedBox(width: 7),
                        Expanded(child: Text(s.name, overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(fontSize: 10, color: Colors.white38))),
                        Text(account == null ? '...' : '${tr('ينتهي')}: ${account['exp']}',
                          style: const TextStyle(fontSize: 10, color: Colors.white38)),
                      ]);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
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
