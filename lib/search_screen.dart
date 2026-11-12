import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart' hide Text;
import 'i18n.dart';
import 'theme.dart';
import 'models.dart';
import 'domain/repositories/media_repository.dart';
import 'core/errors/app_error_mapper.dart';
import 'store.dart';
import 'utils.dart';
import 'live_screen.dart';
import 'movie_detail_screen.dart';
import 'series_detail_screen.dart';

/// بحث ذكي في كل القنوات والأفلام والمسلسلات
class SearchScreen extends StatefulWidget {
  final MediaRepository repository;
  final String accountKey;
  const SearchScreen({super.key, required this.repository, required this.accountKey});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static final LinkedHashMap<String, List<MediaItem>> _cache = LinkedHashMap<String, List<MediaItem>>();
  static const int _maxCachedCatalogues = 6;

  String _type = 'live'; // live | vod | series
  String _q = '';
  List<MediaItem> _all = [];
  bool _loading = false;
  String? _error;
  Timer? _debounce;

  String get _key => '${widget.accountKey}|$_type';

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
    final cached = _cache.remove(_key);
    if (cached != null) _cache[_key] = cached;
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
      final list = type == 'live'
          ? await widget.repository.allLive()
          : type == 'vod'
              ? await widget.repository.allVod()
              : await widget.repository.allSeries();
      final cacheKey = '${widget.accountKey}|$type';
      _cache.remove(cacheKey);
      while (_cache.length >= _maxCachedCatalogues) {
        _cache.remove(_cache.keys.first);
      }
      _cache[cacheKey] = list;
      if (!mounted || _type != type) return;
      setState(() {
        _all = list;
        _loading = false;
      });
    } catch (error) {
      if (mounted && _type == type) {
        setState(() {
          _loading = false;
          _error = AppErrorMapper.toUserMessage(error, fallback: 'تعذر تحميل المحتوى');
        });
      }
    }
  }

  void _open(MediaItem it) {
    if (isAdult(it.name)) return;
    Widget page;
    if (_type == 'live') {
      page = LiveScreen(repository: widget.repository, initial: it);
    } else if (_type == 'vod') {
      page = MovieDetailScreen(repository: widget.repository, item: it);
    } else {
      page = SeriesDetailScreen(repository: widget.repository, item: it);
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
