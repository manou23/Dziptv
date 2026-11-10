import 'package:flutter/material.dart' hide Text;
import 'i18n.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';
import 'utils.dart';
import 'xtream_service.dart';

class ChannelManagerScreen extends StatefulWidget {
  final XtreamService service;
  const ChannelManagerScreen({super.key, required this.service});

  @override
  State<ChannelManagerScreen> createState() => _ChannelManagerScreenState();
}

class _ChannelManagerScreenState extends State<ChannelManagerScreen> {
  late final Map<String, Future<List<Category>>> _futures;

  @override
  void initState() {
    super.initState();
    _futures = {
      'live': widget.service.liveCategories(),
      'vod': widget.service.vodCategories(),
      'series': widget.service.seriesCategories(),
    };
  }

  Widget _categoryList(String type) {
    return FutureBuilder<List<Category>>(
      future: _futures[type],
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('تعذر تحميل التصنيفات'),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => setState(() {
                    _futures[type] = type == 'live'
                        ? widget.service.liveCategories()
                        : type == 'vod'
                            ? widget.service.vodCategories()
                            : widget.service.seriesCategories();
                  }),
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          );
        }
        final categories = (snapshot.data ?? const <Category>[])
            .where((category) => !Store.kidsMode || !isAdult(category.name))
            .toList();
        if (categories.isEmpty) {
          return const Center(child: Text('لا توجد تصنيفات'));
        }
        final hidden = Store.hiddenCategories(type);
        return ListView.builder(
          itemCount: categories.length,
          itemBuilder: (_, index) {
            final category = categories[index];
            final visible = !hidden.contains(category.id);
            return Card(
              color: Colors.white.withOpacity(0.05),
              child: SwitchListTile(
                secondary: Icon(
                  visible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  color: visible ? kAccent : Colors.white38,
                ),
                title: Text(category.name),
                subtitle: Text(visible ? 'ظاهر في قائمة المحتوى' : 'مخفي من قائمة المحتوى'),
                value: visible,
                onChanged: (show) async {
                  await Store.setCategoryHidden(type, category.id, !show);
                  if (mounted) setState(() {});
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مدير القنوات الذكي'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'مباشر'),
              Tab(text: 'أفلام'),
              Tab(text: 'مسلسلات'),
            ],
          ),
        ),
        body: Container(
          decoration: kBgGradient,
          child: TabBarView(
            children: [
              _categoryList('live'),
              _categoryList('vod'),
              _categoryList('series'),
            ],
          ),
        ),
      ),
    );
  }
}
