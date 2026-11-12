import 'package:flutter/material.dart' hide Text;
import 'i18n.dart';
import 'store.dart';

/// Conservative multilingual classifier for adult-labelled IPTV metadata.
/// Compile the matchers once and memoize normalized titles: this function is
/// called across large VOD/category lists and must stay cheap during rebuilds.
final RegExp _adultLabelPattern = RegExp(
  r'(^|[^a-z0-9])(xxx|adult|adults|porn|porno|pornography|erotic|'
  r'erotica|hentai|hardcore|x rated|onlyfans|playboy|penthouse|'
  r'brazzers|redtube|xvideos|pornhub|youporn|tube8|rule34|camgirl|'
  r'webcam|stripper|nudity|nude|explicit|uncensored)(?=$|[^a-z0-9])',
);
final RegExp _adultAgePattern =
    RegExp(r'(^|\D)(18\s*\+|\+\s*18|21\s*\+|\+\s*21)(\D|$)');
final RegExp _adultDiacriticsPattern = RegExp(r'[\u064B-\u065F\u0670]');
final RegExp _adultSeparatorsPattern = RegExp(r'[_./\-]+');
final RegExp _adultSpacesPattern = RegExp(r'\s+');
const List<String> _adultArabicTerms = <String>[
  'اباحي', 'إباحي', 'اباحية', 'إباحية', 'للكبار', 'للكبار فقط',
  'محتوى جنسي', 'افلام جنسية', 'أفلام جنسية', 'عري', 'تعري',
  'بورنو', 'بورن', 'سكس', 'جنس صريح', 'للبالغين فقط',
];
final Map<String, bool> _adultClassificationCache = <String, bool>{};

bool isAdult(String name) {
  final n = name
      .toLowerCase()
      .replaceAll(_adultDiacriticsPattern, '')
      .replaceAll(_adultSeparatorsPattern, ' ')
      .replaceAll(_adultSpacesPattern, ' ')
      .trim();
  if (n.isEmpty) return false;

  final cached = _adultClassificationCache[n];
  if (cached != null) return cached;

  final blocked = _adultLabelPattern.hasMatch(n) ||
      _adultAgePattern.hasMatch(n) ||
      _adultArabicTerms.any(n.contains);

  // Keep memory bounded even when a provider supplies a very large catalogue.
  if (_adultClassificationCache.length >= 12000) {
    _adultClassificationCache.clear();
  }
  _adultClassificationCache[n] = blocked;
  return blocked;
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
