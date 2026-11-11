import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import 'i18n.dart';
import 'theme.dart';
import 'models.dart';
import 'xtream_service.dart';
import 'store.dart';
import 'utils.dart';
import 'live_screen.dart';
import 'movie_detail_screen.dart';
import 'series_detail_screen.dart';

/// بحث ذكي في كل القنوات والأفلام والمسلسلات
class SearchScreen extends StatefulWidget {
  final XtreamService service;
  const SearchScreen({super.key, required this.service});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static final Map<String, List<MediaItem>> _cache = {};

  String _type = 'live'; // live | vod | series
  String _q = '';
  List<MediaItem> _all = [];
  bool _loading = false;
  String? _error;
  Timer? _debounce;

  String get _key => '${widget.service.baseUrl}|${widget.service.username}|$_type';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final type = _type;
    final cached = _cache[_key];
    if (cached != null) {
      setState(() {
        _all = cached;
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _all = [];
    });
    try {
      final s = widget.service;
      final list = type == 'live'
          ? await s.allLive()
          : type == 'vod'
              ? await s.allVod()
              : await s.allSeries();
      _cache['${s.baseUrl}|${s.username}|$type'] = list;
      if (!mounted || _type != type) return;
      setState(() {
        _all = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted && _type == type) {
        setState(() {
          _loading = false;
          _error = 'تعذر تحميل المحتوى';
        });
      }
    }
  }

  void _open(MediaItem it) {
    if (isAdult(it.name)) return;
    final s = widget.service;
    Widget page;
    if (_type == 'live') {
      page = LiveScreen(service: s, initial: it);
    } else if (_type == 'vod') {
      page = MovieDetailScreen(service: s, item: it);
    } else {
      page = SeriesDetailScreen(service: s, item: it);
    }
    Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final results = q.length < 2
        ? const <MediaItem>[]
        : _all.where((e) => e.name.toLowerCase().contains(q) && (!Store.kidsMode || !isAdult(e.name))).take(150).toList();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          onChanged: (v) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 250), () {
              if (mounted) setState(() => _q = v);
            });
          },
          decoration: InputDecoration(
            hintText: tr('ابحث في القنوات والأفلام والمسلسلات'),
            border: InputBorder.none,
          ),
        ),
      ),
      body: Container(
        decoration: kBgGradient,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
              child: Row(
                children: [
                  for (final t in const [
                    ['live', 'القنوات'],
                    ['vod', 'الأفلام'],
                    ['series', 'المسلسلات'],
                  ])
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChoiceChip(
                        label: Text(t[1]),
                        selected: _type == t[0],
                        onSelected: (_) {
                          _type = t[0];
                          _load();
                        },
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : q.length < 2
                          ? const Center(
                              child: Text('اكتب للبحث',
                                  style: TextStyle(color: Colors.white54)))
                          : results.isEmpty
                              ? const Center(
                                  child: Text('لا توجد نتائج',
                                      style: TextStyle(color: Colors.white54)))
                              : ListView.builder(
                                  itemExtent: 66,
                                  itemCount: results.length,
                                  itemBuilder: (_, i) {
                                    final it = results[i];
                                    return Padding(
                                      padding: const EdgeInsets.fromLTRB(14, 3, 14, 3),
                                      child: TvFocus(
                                        radius: 12,
                                        onTap: () => _open(it),
                                        child: Container(
                                          color: Colors.white10,
                                          padding: const EdgeInsets.all(8),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 44,
                                                height: 44,
                                                child: it.image.isEmpty
                                                    ? const Icon(Icons.tv_rounded,
                                                        color: Colors.white38)
                                                    : Image.network(it.image,
                                                        fit: _type == 'live'
                                                            ? BoxFit.contain
                                                            : BoxFit.cover,
                                                        cacheWidth: 96,
                                                        errorBuilder: (_, __, ___) =>
                                                            const Icon(Icons.tv_rounded,
                                                                color: Colors.white38)),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(it.name,
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
            ),
          ],
        ),
      ),
    );
  }
}
