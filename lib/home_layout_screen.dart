import 'package:flutter/material.dart' hide Text;
import 'i18n.dart';
import 'theme.dart';
import 'store.dart';

/// إظهار/إخفاء وإعادة ترتيب أقسام الصفحة الرئيسية
class HomeLayoutScreen extends StatefulWidget {
  const HomeLayoutScreen({super.key});

  @override
  State<HomeLayoutScreen> createState() => _HomeLayoutScreenState();
}

class _HomeLayoutScreenState extends State<HomeLayoutScreen> {
  late final List<String> _order = Store.homeOrder();
  late final Set<String> _hidden = Store.homeHidden();

  static const _labels = {
    'continue': 'متابعة المشاهدة',
    'recent': 'شوهد مؤخراً',
    'favorites': 'المفضلة',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أقسام الصفحة الرئيسية')),
      body: Container(
        decoration: kBgGradient,
        child: ReorderableListView(
          padding: const EdgeInsets.all(14),
          onReorder: (o, n) {
            setState(() {
              if (n > o) n -= 1;
              final x = _order.removeAt(o);
              _order.insert(n, x);
            });
            Store.setHomeOrder(_order);
          },
          children: [
            for (final id in _order)
              Container(
                key: ValueKey(id),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                    color: Colors.white10, borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: const Icon(Icons.drag_handle_rounded),
                  title: Text(_labels[id] ?? id),
                  trailing: Switch(
                    value: !_hidden.contains(id),
                    onChanged: (v) {
                      setState(() {
                        if (v) {
                          _hidden.remove(id);
                        } else {
                          _hidden.add(id);
                        }
                      });
                      Store.setHomeHidden(_hidden);
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
