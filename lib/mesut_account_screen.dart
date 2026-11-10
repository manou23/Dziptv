import 'package:flutter/material.dart' hide Text;
import 'mesut_cloud_api.dart';
import 'store.dart';
import 'i18n.dart';

class MesutAccountScreen extends StatefulWidget {
  final VoidCallback? onAuthenticated;
  final VoidCallback? onSignedOut;
  const MesutAccountScreen({super.key, this.onAuthenticated, this.onSignedOut});
  @override
  State<MesutAccountScreen> createState() => _MesutAccountScreenState();
}

class _MesutAccountScreenState extends State<MesutAccountScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = true, _busy = false, _signedIn = false, _hidePassword = true;
  String? _accountEmail, _message, _currentDeviceKey;
  List<Map<String, dynamic>> _devices = [];
  bool _loadingDevices = false;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final signed = await MesutCloudApi.isSignedIn;
    final email = await MesutCloudApi.email;
    if (!mounted) return;
    setState(() { _signedIn = signed; _accountEmail = email; });
    if (signed) await _loadDevices();
  }

  Future<void> _loadDevices() async {
    if (!await MesutCloudApi.isSignedIn) return;
    if (mounted) setState(() => _loadingDevices = true);
    try {
      final values = await MesutCloudApi.listDevices();
      final currentKey = await MesutCloudApi.currentDeviceKey;
      if (!mounted) return;
      setState(() {
        _devices = values;
        _currentDeviceKey = currentKey;
        _loadingDevices = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingDevices = false);
    }
  }

  Future<void> _removeDevice(Map<String, dynamic> device) async {
    final id = device['id']?.toString() ?? '';
    final key = device['deviceKey']?.toString() ?? '';
    if (id.isEmpty || key == _currentDeviceKey) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إزالة الجهاز'),
        content: Text('هل تريد إزالة ${device['name'] ?? 'هذا الجهاز'} من حسابك؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('إزالة')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await MesutCloudApi.removeDevice(id);
      await _loadDevices();
    } catch (e) {
      if (mounted) setState(() => _message = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _authenticate() async {
    if (_email.text.trim().isEmpty || _password.text.length < 10) {
      setState(() => _message = 'أدخل بريداً صحيحاً وكلمة مرور من 10 أحرف على الأقل');
      return;
    }
    setState(() { _busy = true; _message = null; });
    try {
      await MesutCloudApi.authenticate(_email.text, _password.text, register: _register);
      if (!mounted) return;
      setState(() {
        _signedIn = true;
        _accountEmail = _email.text.trim();
        _busy = false;
        _message = 'تم تسجيل الدخول بنجاح. جارٍ الانتقال لإضافة اشتراك IPTV...';
      });
      await _loadDevices();
      widget.onAuthenticated?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() { _busy = false; _message = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  Future<void> _signOut() async {
    await MesutCloudApi.signOut();
    if (!mounted) return;
    if (widget.onSignedOut != null) {
      widget.onSignedOut!.call();
      return;
    }
    setState(() { _signedIn = false; _accountEmail = null; _message = 'تم تسجيل الخروج من حساب MESUT'; });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configured = MesutCloudApi.isConfigured;
    return Scaffold(
      appBar: AppBar(title: const Text('حساب MESUT السحابي')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.cloud_sync_rounded, size: 64),
          const SizedBox(height: 12),
          const Text('مزامنة أجهزتك', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            configured
              ? 'احفظ المفضلة والإعدادات وسجل المشاهدة الوصفي في حسابك.'
              : 'الخادم لم يُضبط بعد في نسخة التطبيق. ستعمل هذه الصفحة بعد نشر API وبناء التطبيق بعنوانه.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          if (!configured)
            const Card(child: Padding(
              padding: EdgeInsets.all(14),
              child: Text('يلزم بناء التطبيق باستخدام --dart-define=MESUT_API_BASE_URL=https://عنوان-الخادم'),
            )),
          if (_signedIn) ...[
            Card(child: ListTile(
              leading: const Icon(Icons.account_circle_rounded),
              title: const Text('متصل بحساب MESUT'),
              subtitle: Text(_accountEmail ?? ''),
            )),
            const Card(
              child: ListTile(
                leading: Icon(Icons.sync_rounded),
                title: Text('المزامنة التلقائية مفعّلة'),
                subtitle: Text('تتم مزامنة المفضلة وسجل المشاهدة والإعدادات مع حسابك تلقائياً، مع إعادة المحاولة عند انقطاع الإنترنت.'),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 16, bottom: 8),
              child: Text('الأجهزة المرتبطة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ),
            if (_loadingDevices)
              const Center(child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ))
            else if (_devices.isEmpty)
              const Card(child: ListTile(
                leading: Icon(Icons.devices_other_rounded),
                title: Text('لا توجد أجهزة مسجلة بعد'),
              ))
            else
              for (final device in _devices)
                Card(
                  child: ListTile(
                    leading: Icon(device['deviceKey'] == _currentDeviceKey
                        ? Icons.phone_android_rounded
                        : Icons.devices_rounded),
                    title: Text('${device['name'] ?? 'MESUT Device'}'),
                    subtitle: Text(
                      '${device['platform'] ?? 'other'} · ${device['lastSeenAt'] ?? ''}',
                      maxLines: 2,
                    ),
                    trailing: device['deviceKey'] == _currentDeviceKey
                        ? const Text('هذا الجهاز', style: TextStyle(fontSize: 11))
                        : IconButton(
                            tooltip: 'إزالة الجهاز',
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () => _removeDevice(device),
                          ),
                  ),
                ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _loadingDevices ? null : _loadDevices,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('تحديث قائمة الأجهزة'),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _signOut,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('تسجيل الخروج'),
            ),
          ] else ...[
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('إنشاء حساب')),
                ButtonSegment(value: false, label: Text('دخول')),
              ],
              selected: {_register},
              onSelectionChanged: _busy ? null : (v) => setState(() => _register = v.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: _hidePassword,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'كلمة المرور (10 أحرف على الأقل)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _hidePassword = !_hidePassword),
                  icon: Icon(_hidePassword ? Icons.visibility : Icons.visibility_off),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy || !configured ? null : _authenticate,
              child: _busy ? const CircularProgressIndicator() : Text(_register ? 'إنشاء حساب MESUT' : 'تسجيل الدخول'),
            ),
          ],
          if (_busy) const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          ),
          if (_message != null) Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(_message!, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 18),
          const Text(
            'الخصوصية: لا تتم مزامنة كلمات مرور اشتراكات IPTV أو روابط البث. تُخزّن جلسة MESUT داخل التخزين الآمن للجهاز.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.white60),
          ),
        ],
      ),
    );
  }
}
