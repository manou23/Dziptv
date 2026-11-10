import 'dart:convert';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'app_info.dart';
import 'home_layout_screen.dart';
import 'channel_manager_screen.dart';
import 'legal_screen.dart';
import 'i18n.dart';
import 'theme.dart';
import 'store.dart';
import 'utils.dart';
import 'xtream_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'profiles_screen.dart';
import 'mesut_account_screen.dart';

class SettingsScreen extends StatefulWidget {
  final XtreamService service;
  const SettingsScreen({super.key, required this.service});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _goHome() {
    if (!mounted) return;
    final a = Store.active;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => a == null
            ? const LoginScreen()
            : HomeScreen(service: XtreamService.fromAccount(a)),
      ),
      (r) => false,
    );
  }

  Future<void> _switch(int i) async {
    await Store.setActive(i);
    _goHome();
  }

  Future<void> _remove(int i) async {
    await Store.removeAccount(i);
    _goHome();
  }

  Future<String?> _askNewPin(String title) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          obscureText: true,
          maxLength: 4,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(c, ctrl.text),
              child: const Text('حفظ')),
        ],
      ),
    );
  }

  Future<void> _setPin() async {
    if (Store.pin != null && !await askPin(context)) return;
    final p = await _askNewPin('رمز سري جديد (4 أرقام)');
    if (p == null) return;
    if (p.length != 4) {
      _toast('يجب أن يتكون الرمز من 4 أرقام');
      return;
    }
    await Store.setPin(p);
    if (mounted) setState(() {});
    _toast('تم حفظ الرمز السري');
  }

  Future<void> _toggleKidsMode(bool enabled) async {
    if (enabled) {
      if (Store.pin == null) {
        final pin = await _askNewPin('أنشئ رمزاً سرياً من 4 أرقام لتأمين وضع الأطفال');
        if (pin == null) return;
        if (pin.length != 4 || int.tryParse(pin) == null) {
          _toast('يجب أن يتكون الرمز من 4 أرقام');
          return;
        }
        await Store.setPin(pin);
      }
      await Store.setKidsMode(true);
    } else {
      if (!await askPin(context)) return;
      await Store.setKidsMode(false);
    }
    if (mounted) setState(() {});
    _toast(enabled ? 'تم تفعيل وضع الأطفال' : 'تم إيقاف وضع الأطفال');
  }

  Future<void> _removePin() async {
    if (Store.kidsMode) {
      _toast('أوقف وضع الأطفال أولاً');
      return;
    }
    if (!await askPin(context)) return;
    await Store.setPin(null);
    if (mounted) setState(() {});
    _toast('تم حذف الرمز السري');
  }

  void _legal(String kind) => Navigator.of(context)
      .push<void>(MaterialPageRoute<void>(builder: (_) => LegalScreen(kind: kind)));

  Future<void> _editSportsKey() async {
    final ctrl = TextEditingController(text: Store.sportsKey == '3' ? '' : Store.sportsKey);
    final v = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('مفتاح API للرياضة'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(hintText: tr('الافتراضي (مجاني)')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('حفظ')),
        ],
      ),
    );
    if (v == null) return;
    await Store.setSportsKey(v);
    if (mounted) setState(() {});
  }

  Future<void> _backup() async {
    await Clipboard.setData(ClipboardData(text: Store.exportAll()));
    _toast('تم نسخ النسخة الاحتياطية إلى الحافظة');
  }

  Future<void> _restore() async {
    final d = await Clipboard.getData('text/plain');
    final text = d?.text;
    final ok = text != null && await Store.importAll(text);
    if (!ok) {
      _toast('النص في الحافظة ليس نسخة صحيحة');
      return;
    }
    I18n.init();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const ProfilesScreen()),
      (r) => false,
    );
  }

  Future<String> _runSpeedTest() async {
    var latency = '-';
    try {
      final sw = Stopwatch()..start();
      await http.get(Uri.parse(widget.service.baseUrl)).timeout(const Duration(seconds: 10));
      latency = '${sw.elapsedMilliseconds} ms';
    } catch (_) {}
    var speed = '-';
    try {
      final client = http.Client();
      final req = http.Request(
          'GET', Uri.parse('https://speed.cloudflare.com/__down?bytes=10000000'));
      final sw = Stopwatch()..start();
      final resp = await client.send(req).timeout(const Duration(seconds: 15));
      var bytes = 0;
      await for (final chunk in resp.stream) {
        bytes += chunk.length;
        if (sw.elapsedMilliseconds > 8000) break;
      }
      final secs = sw.elapsedMilliseconds / 1000;
      client.close();
      if (secs > 0) speed = '${(bytes * 8 / 1e6 / secs).toStringAsFixed(1)} Mbps';
    } catch (_) {}
    return '${tr('سرعة التحميل')}: $speed\n${tr('استجابة السيرفر')}: $latency';
  }

  void _speedTest() {
    final f = _runSpeedTest();
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('اختبار السرعة'),
        content: FutureBuilder<String>(
          future: f,
          builder: (_, snap) => snap.connectionState != ConnectionState.done
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 14),
                    const Text('جارٍ الاختبار...'),
                  ],
                )
              : Text(snap.data ?? '-', textDirection: TextDirection.ltr),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('تأكيد')),
        ],
      ),
    );
  }

  Future<void> _checkUpdate() async {
    try {
      final uri = Uri.parse(
          'https://api.github.com/repos/$kUpdateRepo/releases/tags/android-latest');
      final response = await http.get(uri, headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      }).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw Exception('تعذر الوصول إلى معلومات الإصدار');
      }
      final release = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      final assets = release['assets'] is List ? release['assets'] as List : const [];
      String? apkUrl;
      for (final asset in assets) {
        if (asset is Map && asset['name'] == 'app-release.apk') {
          apkUrl = asset['browser_download_url']?.toString();
          break;
        }
      }
      final body = release['body']?.toString() ?? '';
      final match = RegExp(r'Build commit: ([0-9a-f]{40})').firstMatch(body);
      final remoteCommit = match?.group(1) ?? '';
      final isCurrent = remoteCommit.isNotEmpty &&
          kBuildCommit != 'unknown' &&
          remoteCommit == kBuildCommit;
      if (!mounted) return;
      if (isCurrent) {
        _toast('أنت تستخدم أحدث إصدار');
        return;
      }
      if (apkUrl == null || apkUrl.isEmpty) {
        _toast('وُجد إصدار جديد لكن ملف APK غير متاح حالياً');
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('يتوفر تحديث جديد'),
          content: const Text(
              'توجد نسخة أحدث من MESUT IPTV. نزّل ملف APK وثبّته فوق النسخة الحالية للاحتفاظ ببياناتك.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('لاحقاً'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final opened = await launchUrl(
                  Uri.parse(apkUrl!),
                  mode: LaunchMode.externalApplication,
                );
                if (!opened && mounted) {
                  _toast('تعذر فتح رابط التحميل');
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              icon: const Icon(Icons.download_rounded),
              label: const Text('تنزيل التحديث'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) _toast('تعذر التحقق من التحديثات حالياً');
    }
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Text(t,
            style: const TextStyle(
                color: kAccent, fontSize: 14, fontWeight: FontWeight.bold)),
      );

  Widget _box(Widget child) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
            color: Colors.white10, borderRadius: BorderRadius.circular(14)),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final accs = Store.accounts();
    final act = Store.activeIndex;

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: Container(
        decoration: kBgGradient,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _section('اللغة'),
            _box(Padding(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'ar', label: Text('العربية')),
                    ButtonSegment(value: 'fr', label: Text('Français')),
                    ButtonSegment(value: 'en', label: Text('English')),
                  ],
                  selected: {I18n.lang},
                  onSelectionChanged: (v) async {
                    await I18n.set(v.first);
                    _goHome();
                  },
                ),
              ),
            )),
            _section('الحسابات'),
            _box(ListTile(
              leading: const Icon(Icons.switch_account_rounded),
              title: const Text('تبديل الحساب'),
              onTap: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(builder: (_) => const ProfilesScreen()),
                (r) => false,
              ),
            )),
            for (var i = 0; i < accs.length; i++)
              _box(ListTile(
                leading: Icon(
                  i == act ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: i == act ? kAccent : Colors.white54,
                ),
                title: Text(accs[i].name),
                subtitle: Text(accs[i].url, textDirection: TextDirection.ltr),
                onTap: i == act ? null : () => _switch(i),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _remove(i),
                ),
              )),
            _box(ListTile(
              leading: const Icon(Icons.add_circle_outline_rounded),
              title: const Text('إضافة حساب'),
              onTap: () => Navigator.of(context)
                  .push<void>(MaterialPageRoute<void>(builder: (_) => const LoginScreen())),
            )),
            _box(ListTile(
              leading: const Icon(Icons.cloud_sync_rounded),
              title: const Text('حساب MESUT السحابي'),
              subtitle: const Text('تسجيل الدخول ومزامنة الأجهزة'),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => MesutAccountScreen(
                  onSignedOut: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(builder: (_) => const MesutAccountScreen()),
                    (route) => false,
                  ),
                )),
              ),
            )),
            _section('التشغيل'),
            _box(Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('صيغة البث المباشر'),
                  const SizedBox(height: 4),
                  const Text('جرّب m3u8 إذا كان ts لا يعمل مع سيرفرك',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 10),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'ts', label: Text('TS')),
                      ButtonSegment(value: 'm3u8', label: Text('M3U8')),
                    ],
                    selected: {Store.liveFormat},
                    onSelectionChanged: (v) async {
                      await Store.setLiveFormat(v.first);
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
            )),
            _section('الحماية'),
            _box(SwitchListTile(
              secondary: const Icon(Icons.child_care_rounded),
              title: const Text('وضع الأطفال'),
              subtitle: const Text('إخفاء التصنيفات والعناوين المصنفة للكبار'),
              value: Store.kidsMode,
              onChanged: _toggleKidsMode,
            )),
            _box(ListTile(
              leading: const Icon(Icons.lock_rounded),
              title: Text(Store.pin == null ? 'تعيين رمز سري' : 'تغيير الرمز السري'),
              subtitle: const Text('يحمي التصنيفات المخصصة للكبار',
                  style: TextStyle(fontSize: 12)),
              onTap: _setPin,
            )),
            if (Store.pin != null)
              _box(ListTile(
                leading: const Icon(Icons.lock_open_rounded),
                title: const Text('حذف الرمز السري'),
                onTap: _removePin,
              )),
            _section('إدارة القنوات'),
            _box(ListTile(
              leading: const Icon(Icons.tune_rounded),
              title: const Text('مدير القنوات الذكي'),
              subtitle: const Text('إخفاء وإظهار تصنيفات القنوات والأفلام والمسلسلات'),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => ChannelManagerScreen(service: widget.service),
                ),
              ),
            )),
            _section('الرئيسية'),
            _box(ListTile(
              leading: const Icon(Icons.dashboard_customize_rounded),
              title: const Text('أقسام الصفحة الرئيسية'),
              onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(builder: (_) => const HomeLayoutScreen())),
            )),
            _section('الرياضة'),
            _box(ListTile(
              leading: const Icon(Icons.sports_soccer_rounded),
              title: const Text('مفتاح API للرياضة'),
              subtitle: Text(Store.sportsKey == '3' ? 'الافتراضي (مجاني)' : '********',
                  style: const TextStyle(fontSize: 12)),
              onTap: _editSportsKey,
            )),
            _section('النسخ الاحتياطي'),
            _box(ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('نسخ النسخة الاحتياطية'),
              subtitle: const Text('تحذير: تحتوي على بيانات دخولك',
                  style: TextStyle(fontSize: 12)),
              onTap: _backup,
            )),
            _box(ListTile(
              leading: const Icon(Icons.restore_rounded),
              title: const Text('استعادة من الحافظة'),
              onTap: _restore,
            )),
            _section('الأداء'),
            _box(ListTile(
              leading: const Icon(Icons.speed_rounded),
              title: const Text('اختبار السرعة'),
              onTap: _speedTest,
            )),
            _box(ListTile(
              leading: const Icon(Icons.cleaning_services_rounded),
              title: const Text('مسح الذاكرة المؤقتة للصور'),
              onTap: () {
                PaintingBinding.instance.imageCache.clear();
                PaintingBinding.instance.imageCache.clearLiveImages();
                _toast('تم المسح');
              },
            )),
            _section('البيانات'),
            _box(ListTile(
              leading: const Icon(Icons.history_rounded),
              title: const Text('مسح سجل المشاهدة'),
              onTap: () async {
                await Store.clearHistory();
                _toast('تم مسح السجل');
              },
            )),
            _box(ListTile(
              leading: const Icon(Icons.star_border_rounded),
              title: const Text('مسح المفضلة'),
              onTap: () async {
                await Store.clearFavs();
                _toast('تم مسح المفضلة');
              },
            )),
            _section('حول التطبيق'),
            _box(ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('من نحن'),
              onTap: () => _legal('about'),
            )),
            _box(ListTile(
              leading: const Icon(Icons.gavel_rounded),
              title: const Text('شروط الاستخدام'),
              onTap: () => _legal('terms'),
            )),
            _box(ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('سياسة الخصوصية'),
              onTap: () => _legal('privacy'),
            )),
            _box(ListTile(
              leading: const Icon(Icons.mail_outline_rounded),
              title: const Text('اتصل بنا'),
              onTap: () => _legal('contact'),
            )),
            _box(ListTile(
              leading: const Icon(Icons.system_update_rounded),
              title: const Text('التحقق من التحديثات'),
              onTap: _checkUpdate,
            )),
            const SizedBox(height: 20),
            Center(
              child: Text('$kAppName v$kVersion - $kBrand',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
  void _legal(String kind) => Navigator.of(context)
      .push<void>(MaterialPageRoute<void>(builder: (_) => LegalScreen(kind: kind)));

  Future<void> _editSportsKey() async {
    final ctrl = TextEditingController(text: Store.sportsKey == '3' ? '' : Store.sportsKey);
    final v = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('مفتاح API للرياضة'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(hintText: tr('الافتراضي (مجاني)')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('حفظ')),
        ],
      ),
    );
    if (v == null) return;
    await Store.setSportsKey(v);
    if (mounted) setState(() {});
  }

  Future<void> _backup() async {
    await Clipboard.setData(ClipboardData(text: Store.exportAll()));
    _toast('تم نسخ النسخة الاحتياطية إلى الحافظة');
  }

  Future<void> _restore() async {
    final d = await Clipboard.getData('text/plain');
    final text = d?.text;
    final ok = text != null && await Store.importAll(text);
    if (!ok) {
      _toast('النص في الحافظة ليس نسخة صحيحة');
      return;
    }
    I18n.init();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const ProfilesScreen()),
      (r) => false,
    );
  }

  Future<String> _runSpeedTest() async {
    var latency = '-';
    try {
      final sw = Stopwatch()..start();
      await http.get(Uri.parse(widget.service.baseUrl)).timeout(const Duration(seconds: 10));
      latency = '${sw.elapsedMilliseconds} ms';
    } catch (_) {}
    var speed = '-';
    try {
      final client = http.Client();
      final req = http.Request(
          'GET', Uri.parse('https://speed.cloudflare.com/__down?bytes=10000000'));
      final sw = Stopwatch()..start();
      final resp = await client.send(req).timeout(const Duration(seconds: 15));
      var bytes = 0;
      await for (final chunk in resp.stream) {
        bytes += chunk.length;
        if (sw.elapsedMilliseconds > 8000) break;
      }
      final secs = sw.elapsedMilliseconds / 1000;
      client.close();
      if (secs > 0) speed = '${(bytes * 8 / 1e6 / secs).toStringAsFixed(1)} Mbps';
    } catch (_) {}
    return '${tr('سرعة التحميل')}: $speed\n${tr('استجابة السيرفر')}: $latency';
  }

  void _speedTest() {
    final f = _runSpeedTest();
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('اختبار السرعة'),
        content: FutureBuilder<String>(
          future: f,
          builder: (_, snap) => snap.connectionState != ConnectionState.done
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 14),
                    const Text('جارٍ الاختبار...'),
                  ],
                )
              : Text(snap.data ?? '-', textDirection: TextDirection.ltr),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('تأكيد')),
        ],
      ),
    );
  }

  Future<void> _checkUpdate() async {
    if (kUpdateRepo.isEmpty) {
      _toast('لم يتم ضبط مصدر التحديثات');
      return;
    }
    try {
      final r = await http
          .get(Uri.parse('https://api.github.com/repos/$kUpdateRepo/releases/latest'))
          .timeout(const Duration(seconds: 15));
      final tag = ((jsonDecode(r.body) as Map)['tag_name'] ?? '')
          .toString()
          .replaceFirst('v', '');
      if (tag.isNotEmpty && tag != kVersion) {
        _toast('${tr('يتوفر إصدار جديد')}: $tag');
      } else {
        _toast('أنت تستخدم أحدث إصدار');
      }
    } catch (_) {
      _toast('تعذر تحميل البيانات');
    }
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Text(t,
            style: const TextStyle(
                color: kAccent, fontSize: 14, fontWeight: FontWeight.bold)),
      );

  Widget _box(Widget child) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
            color: Colors.white10, borderRadius: BorderRadius.circular(14)),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final accs = Store.accounts();
    final act = Store.activeIndex;

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: Container(
        decoration: kBgGradient,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _section('اللغة'),
            _box(Padding(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'ar', label: Text('العربية')),
                    ButtonSegment(value: 'fr', label: Text('Français')),
                    ButtonSegment(value: 'en', label: Text('English')),
                  ],
                  selected: {I18n.lang},
                  onSelectionChanged: (v) async {
                    await I18n.set(v.first);
                    _goHome();
                  },
                ),
              ),
            )),
            _section('الحسابات'),
            _box(ListTile(
              leading: const Icon(Icons.switch_account_rounded),
              title: const Text('تبديل الحساب'),
              onTap: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(builder: (_) => const ProfilesScreen()),
                (r) => false,
              ),
            )),
            for (var i = 0; i < accs.length; i++)
              _box(ListTile(
                leading: Icon(
                  i == act ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: i == act ? kAccent : Colors.white54,
                ),
                title: Text(accs[i].name),
                subtitle: Text(accs[i].url, textDirection: TextDirection.ltr),
                onTap: i == act ? null : () => _switch(i),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _remove(i),
                ),
              )),
            _box(ListTile(
              leading: const Icon(Icons.add_circle_outline_rounded),
              title: const Text('إضافة حساب'),
              onTap: () => Navigator.of(context)
                  .push<void>(MaterialPageRoute<void>(builder: (_) => const LoginScreen())),
            )),
            _box(ListTile(
              leading: const Icon(Icons.cloud_sync_rounded),
              title: const Text('حساب MESUT السحابي'),
              subtitle: const Text('تسجيل الدخول ومزامنة الأجهزة'),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => MesutAccountScreen(
                  onSignedOut: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(builder: (_) => const MesutAccountScreen()),
                    (route) => false,
                  ),
                )),
              ),
            )),
            _section('التشغيل'),
            _box(Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('صيغة البث المباشر'),
                  const SizedBox(height: 4),
                  const Text('جرّب m3u8 إذا كان ts لا يعمل مع سيرفرك',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 10),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'ts', label: Text('TS')),
                      ButtonSegment(value: 'm3u8', label: Text('M3U8')),
                    ],
                    selected: {Store.liveFormat},
                    onSelectionChanged: (v) async {
                      await Store.setLiveFormat(v.first);
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
            )),
            _section('الحماية'),
            _box(ListTile(
              leading: const Icon(Icons.lock_rounded),
              title: Text(Store.pin == null ? 'تعيين رمز سري' : 'تغيير الرمز السري'),
              subtitle: const Text('يحمي التصنيفات المخصصة للكبار',
                  style: TextStyle(fontSize: 12)),
              onTap: _setPin,
            )),
            if (Store.pin != null)
              _box(ListTile(
                leading: const Icon(Icons.lock_open_rounded),
                title: const Text('حذف الرمز السري'),
                onTap: _removePin,
              )),
            _section('الرئيسية'),
            _box(ListTile(
              leading: const Icon(Icons.dashboard_customize_rounded),
              title: const Text('أقسام الصفحة الرئيسية'),
              onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(builder: (_) => const HomeLayoutScreen())),
            )),
            _section('الرياضة'),
            _box(ListTile(
              leading: const Icon(Icons.sports_soccer_rounded),
              title: const Text('مفتاح API للرياضة'),
              subtitle: Text(Store.sportsKey == '3' ? 'الافتراضي (مجاني)' : '********',
                  style: const TextStyle(fontSize: 12)),
              onTap: _editSportsKey,
            )),
            _section('النسخ الاحتياطي'),
            _box(ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('نسخ النسخة الاحتياطية'),
              subtitle: const Text('تحذير: تحتوي على بيانات دخولك',
                  style: TextStyle(fontSize: 12)),
              onTap: _backup,
            )),
            _box(ListTile(
              leading: const Icon(Icons.restore_rounded),
              title: const Text('استعادة من الحافظة'),
              onTap: _restore,
            )),
            _section('الأداء'),
            _box(ListTile(
              leading: const Icon(Icons.speed_rounded),
              title: const Text('اختبار السرعة'),
              onTap: _speedTest,
            )),
            _box(ListTile(
              leading: const Icon(Icons.cleaning_services_rounded),
              title: const Text('مسح الذاكرة المؤقتة للصور'),
              onTap: () {
                PaintingBinding.instance.imageCache.clear();
                PaintingBinding.instance.imageCache.clearLiveImages();
                _toast('تم المسح');
              },
            )),
            _section('البيانات'),
            _box(ListTile(
              leading: const Icon(Icons.history_rounded),
              title: const Text('مسح سجل المشاهدة'),
              onTap: () async {
                await Store.clearHistory();
                _toast('تم مسح السجل');
              },
            )),
            _box(ListTile(
              leading: const Icon(Icons.star_border_rounded),
              title: const Text('مسح المفضلة'),
              onTap: () async {
                await Store.clearFavs();
                _toast('تم مسح المفضلة');
              },
            )),
            _section('حول التطبيق'),
            _box(ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('من نحن'),
              onTap: () => _legal('about'),
            )),
            _box(ListTile(
              leading: const Icon(Icons.gavel_rounded),
              title: const Text('شروط الاستخدام'),
              onTap: () => _legal('terms'),
            )),
            _box(ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('سياسة الخصوصية'),
              onTap: () => _legal('privacy'),
            )),
            _box(ListTile(
              leading: const Icon(Icons.mail_outline_rounded),
              title: const Text('اتصل بنا'),
              onTap: () => _legal('contact'),
            )),
            _box(ListTile(
              leading: const Icon(Icons.system_update_rounded),
              title: const Text('التحقق من التحديثات'),
              onTap: _checkUpdate,
            )),
            const SizedBox(height: 20),
            Center(
              child: Text('$kAppName v$kVersion - $kBrand',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
