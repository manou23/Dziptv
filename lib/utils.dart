import 'package:flutter/material.dart' hide Text;
import 'i18n.dart';
import 'store.dart';

/// Conservative multilingual classifier for adult-labelled IPTV metadata.
/// It intentionally favours hiding a questionable title over exposing it.
bool isAdult(String name) {
  final n = name
      .toLowerCase()
      .replaceAll(RegExp(r'[\\u064B-\\u065F\\u0670]'), '')
      .replaceAll(RegExp(r'[_./\\-]+'), ' ')
      .replaceAll(RegExp(r'\\s+'), ' ')
      .trim();
  if (n.isEmpty) return false;

  const exactTerms = <String>[
    'xxx', 'adult', 'adults', 'porn', 'porno', 'pornography', 'erotic',
    'erotica', 'hentai', 'hardcore', 'x rated', 'x-rated', 'onlyfans',
    'playboy', 'penthouse', 'brazzers', 'redtube', 'xvideos', 'pornhub',
    'youporn', 'tube8', 'rule34', 'camgirl', 'webcam', 'stripper',
    'nudity', 'nude', 'explicit', 'uncensored',
  ];
  for (final term in exactTerms) {
    if (RegExp('(^|[^a-z0-9])' + RegExp.escape(term) + r'([^a-z0-9]|$)').hasMatch(n)) {
      return true;
    }
  }

  if (RegExp(r'(^|\\D)(18\\s*\\+|\\+\\s*18|21\\s*\\+|\\+\\s*21)(\\D|$)').hasMatch(n)) {
    return true;
  }

  const arabicTerms = <String>[
    'اباحي', 'إباحي', 'اباحية', 'إباحية', 'للكبار', 'للكبار فقط',
    'محتوى جنسي', 'افلام جنسية', 'أفلام جنسية', 'عري', 'تعري',
    'بورنو', 'بورن', 'سكس', 'جنس صريح', 'للبالغين فقط',
  ];
  return arabicTerms.any(n.contains);
}

/// إذا كان هناك رمز سري يطلبه، وإلا يسمح مباشرة.
/// Adult content is blocked before this legacy PIN prompt can be reached.
Future<bool> askPin(BuildContext context) async {
  final pin = Store.pin;
  if (pin == null) return true;
  final ctrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('أدخل الرمز السري'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        obscureText: true,
        maxLength: 4,
        keyboardType: TextInputType.number,
        textDirection: TextDirection.ltr,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
        FilledButton(
            onPressed: () => Navigator.pop(c, ctrl.text == pin),
            child: const Text('تأكيد')),
      ],
    ),
  );
  if (ok != true && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('الرمز غير صحيح')));
  }
  return ok == true;
}

String hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String mmss(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  return h > 0
      ? '$h:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}'
      : '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
}
