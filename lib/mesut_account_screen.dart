import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'i18n.dart';
import 'login_screen.dart';
import 'mesut_cloud_api.dart';
import 'models.dart';
import 'profile_pin_service.dart';
import 'store.dart';
import 'xtream_service.dart';

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
  bool _profileVaultReady = false;

  static const _accent = Color(0xFF9B72FF);
  static const _panel = Color(0xFF171923);
  static const _avatars = <Map<String, String>>[
    {'id': 'preset:man', 'emoji': '👨', 'label': 'رجل'},
    {'id': 'preset:glasses', 'emoji': '🤓', 'label': 'رجل بنظارة'},
    {'id': 'preset:woman', 'emoji': '👩', 'label': 'امرأة'},
    {'id': 'preset:beard', 'emoji': '🧔', 'label': 'رجل بلحية'},
    {'id': 'preset:elder', 'emoji': '👴', 'label': 'رجل كبير'},
    {'id': 'preset:elder-woman', 'emoji': '👵', 'label': 'امرأة كبيرة'},
    {'id': 'preset:boy', 'emoji': '👦', 'label': 'طفل'},
    {'id': 'preset:girl', 'emoji': '👧', 'label': 'طفلة'},
    {'id': 'preset:child', 'emoji': '🧒', 'label': 'طفل محايد'},
    {'id': 'preset:person', 'emoji': '🙂', 'label': 'بسيط'},
    {'id': 'preset:cool', 'emoji': '😎', 'label': 'مرح'},
    {'id': 'preset:family', 'emoji': '👨‍👩‍👧', 'label': 'العائلة'},
    {'id': '', 'emoji': '✦', 'label': 'افتراضي'},
  ];
  static const _palette = <List<Color>>[
    [Color(0xFF8668FF), Color(0xFF35145F)],
    [Color(0xFF35B8FF), Color(0xFF1A2760)],
    [Color(0xFF28D59A), Color(0xFF145B62)],
    [Color(0xFF7138E8), Color(0xFF25215F)],
    [Color(0xFFC25BFF), Color(0xFF60244B)],
  ];

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final signed = await MesutCloudApi.isSignedIn;
    final email = await MesutCloudApi.email;
    final vaultReady = await MesutCloudApi.hasProfileEncryptionKey;
    if (!mounted) return;
    setState(() {
      _signedIn = signed;
      _accountEmail = email;
      _profileVaultReady = vaultReady;
    });
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
    } catch (e) {
      if (mounted) setState(() {
        _loadingDevices = false;
        _message = e.toString().replaceFirst('Exception: ', '');
      });
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
    if (!MesutCloudApi.isConfigured) {
      setState(() => _message = 'تعذر الاتصال: عنوان خادم MESUT غير مضبوط في هذه النسخة.');
      return;
    }
    if (_email.text.trim().isEmpty || _password.text.length < 10) {
      setState(() => _message = 'أدخل بريداً صحيحاً وكلمة مرور من 10 أحرف على الأقل');
      return;
    }
    setState(() { _busy = true; _message = null; });
    try {
      await MesutCloudApi.authenticate(_email.text, _password.text, register: _register);
      final vaultReady = await MesutCloudApi.hasProfileEncryptionKey;
      if (!mounted) return;
      setState(() {
        _signedIn = true;
        _profileVaultReady = vaultReady;
        _accountEmail = _email.text.trim();
        _busy = false;
        _message = 'تم تسجيل الدخول بنجاح';
      });
      await _loadDevices();
      widget.onAuthenticated?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() { _busy = false; _message = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  Future<void> _syncNow() async {
    setState(() { _busy = true; _message = null; });
    try {
      await MesutCloudApi.syncNow();
      final vaultReady = await MesutCloudApi.hasProfileEncryptionKey;
      if (!mounted) return;
      setState(() {
        _busy = false;
        _profileVaultReady = vaultReady;
        _message = 'اكتملت المزامنة بنجاح';
      });
      await _loadDevices();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _signOut() async {
    await MesutCloudApi.signOut();
    if (!mounted) return;
    if (widget.onSignedOut != null) {
      widget.onSignedOut!.call();
      return;
    }
    setState(() {
      _signedIn = false;
      _accountEmail = null;
      _devices = [];
      _message = 'تم تسجيل الخروج من حساب MESUT';
    });
  }

  Future<void> _addProfile() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const LoginScreen(returnToProfiles: true),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _editProfile(Account account) async {
    final name = TextEditingController(text: account.name);
    final url = TextEditingController(text: account.url);
    final username = TextEditingController(text: account.user);
    final password = TextEditingController(text: account.pass);
    final formKey = GlobalKey<FormState>();
    final replacement = await showDialog<Account>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _panel,
        title: const Text('تعديل بيانات الاشتراك'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _dialogField(name, 'اسم البروفايل'),
              const SizedBox(height: 10),
              _dialogField(url, 'رابط خادم Xtream', ltr: true),
              const SizedBox(height: 10),
              _dialogField(username, 'اسم المستخدم', ltr: true),
              const SizedBox(height: 10),
              _dialogField(password, 'كلمة مرور الاشتراك', ltr: true, secret: true),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(dialogContext, Account(
                name.text.trim(), url.text.trim(), username.text.trim(),
                password.text, avatar: account.avatar,
              ));
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    name.dispose(); url.dispose(); username.dispose(); password.dispose();
    if (!mounted || replacement == null) return;
    setState(() { _busy = true; _message = null; });
    try {
      final service = XtreamService(replacement.url, replacement.user, replacement.pass, replacement.name);
      await service.login();
      await Store.updateAccount(account.id, Account(service.name, service.baseUrl, service.username, service.password, avatar: replacement.avatar));
      if (!mounted) return;
      setState(() { _busy = false; _message = 'تم تحديث الاشتراك ومزامنته'; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _busy = false; _message = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  Widget _dialogField(TextEditingController controller, String label,
      {bool ltr = false, bool secret = false}) {
    return TextFormField(
      controller: controller,
      obscureText: secret,
      textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white.withOpacity(.045),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
      ),
      validator: (value) => (value == null || value.trim().isEmpty) ? 'هذا الحقل مطلوب' : null,
    );
  }

  Future<void> _changeAvatar(Account account) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _panel,
        title: const Text('اختر صورة البروفايل'),
        content: SizedBox(
          width: 360,
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: _avatars.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 9, mainAxisSpacing: 9,
            ),
            itemBuilder: (context, index) {
              final avatar = _avatars[index];
              final chosen = avatar['id'] == account.avatar;
              return InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: () => Navigator.pop(dialogContext, avatar['id']),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: chosen ? const Color(0xFF30264C) : Colors.white.withOpacity(.05),
                    border: Border.all(color: chosen ? _accent : Colors.white12, width: chosen ? 2 : 1),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(avatar['emoji']!, style: const TextStyle(fontSize: 34)),
                    const SizedBox(height: 4),
                    Text(avatar['label']!, style: const TextStyle(fontSize: 11)),
                  ]),
                ),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء'))],
      ),
    );
    if (!mounted || selected == null) return;
    await Store.updateAccountAvatar(account.id, selected);
    if (mounted) setState(() => _message = 'تم حفظ صورة البروفايل');
  }

  Future<String?> _askPin(String title) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _panel,
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(labelText: 'PIN (4 إلى 6 أرقام)', counterText: ''),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const Text('تأكيد')),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _managePin(Account account, {bool remove = false}) async {
    final hasPin = await ProfilePinService.hasPin(account.id);
    if (hasPin) {
      final current = await _askPin(remove ? 'أدخل PIN الحالي لإزالته' : 'أدخل PIN الحالي');
      if (current == null || !await ProfilePinService.verify(account.id, current)) {
        if (current != null && mounted) setState(() => _message = 'رمز PIN الحالي غير صحيح');
        return;
      }
    }
    if (remove) {
      await ProfilePinService.remove(account.id);
      await Store.notifyCloudProfilesChanged();
      if (mounted) setState(() => _message = 'تمت إزالة PIN');
      return;
    }
    final pin = await _askPin('PIN الجديد');
    if (pin == null) return;
    if (!ProfilePinService.isValidPin(pin)) {
      if (!mounted) return;
      setState(() => _message = 'يجب أن يتكون PIN من 4 إلى 6 أرقام');
      return;
    }
    final confirm = await _askPin('أعد إدخال PIN للتأكيد');
    if (confirm == null) return;
    if (confirm != pin) {
      setState(() => _message = 'رمزا PIN غير متطابقين');
      return;
    }
    await ProfilePinService.setPin(account.id, pin);
    await Store.notifyCloudProfilesChanged();
    if (mounted) setState(() => _message = 'تم حفظ PIN ومزامنته');
  }

  Future<void> _deleteProfile(Account account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _panel,
        title: const Text('حذف البروفايل'),
        content: Text('هل تريد حذف «${account.name}» من هذا الجهاز وحساب MESUT؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final index = Store.accounts().indexWhere((a) => a.id == account.id);
    if (index < 0) return;
    await ProfilePinService.remove(account.id);
    await Store.removeAccount(index);
    if (mounted) setState(() => _message = 'تم حذف البروفايل ومزامنة التغيير');
  }

  Widget _avatar(Account account, int index) {
    final avatar = _avatars.where((item) => item['id'] == account.avatar && item['id']!.isNotEmpty);
    final profileName = account.name.trim();
    final emoji = avatar.isNotEmpty ? avatar.first['emoji']! : (profileName.isEmpty ? '?' : String.fromCharCode(profileName.runes.first).toUpperCase());
    final colors = _palette[index % _palette.length];
    return Container(
      width: 54, height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
    );
  }

  Widget _sectionTitle(String title, String subtitle, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white60)),
        ])),
        if (trailing != null) trailing,
      ]),
    );
  }

  Widget _panelCard({required Widget child, EdgeInsets padding = const EdgeInsets.all(15)}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: Colors.white.withOpacity(.07)),
      ),
      child: child,
    );
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
    final accounts = Store.accounts();
    return Scaffold(
      backgroundColor: const Color(0xFF0B0C12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0C12),
        title: const Text('حساب MESUT'),
        actions: [
          if (_signedIn)
            IconButton(
              tooltip: 'مزامنة الآن',
              onPressed: _busy ? null : _syncNow,
              icon: const Icon(Icons.sync_rounded),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF17122A), Color(0xFF0B0C12), Color(0xFF090A0F)],
            stops: [0, .42, 1],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
              children: [
                _panelCard(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        width: 52, height: 52,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [Color(0xFF8A5CFF), Color(0xFF35B8FF)]),
                        ),
                        child: const Icon(Icons.cloud_done_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 13),
                      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('بوابة حساب MESUT', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                        SizedBox(height: 4),
                        Text('إدارة اشتراكاتك وبروفايلاتك ومزامنتها', style: TextStyle(color: Colors.white60, fontSize: 12)),
                      ])),
                    ]),
                    const SizedBox(height: 17),
                    if (_signedIn) ...[
                      Row(children: [
                        const Icon(Icons.verified_user_rounded, color: Color(0xFF49D6A0), size: 20),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('حساب MESUT متصل', style: TextStyle(fontWeight: FontWeight.w800))),
                        TextButton(onPressed: _busy ? null : _signOut, child: const Text('تسجيل الخروج')),
                      ]),
                      Text(_accountEmail ?? '', textDirection: TextDirection.ltr,
                          style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    ] else ...[
                      SegmentedButton<bool>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: true, label: Text('إنشاء حساب')),
                          ButtonSegment(value: false, label: Text('تسجيل الدخول')),
                        ],
                        selected: {_register},
                        onSelectionChanged: _busy ? null : (v) => setState(() => _register = v.first),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        decoration: _inputDecoration('البريد الإلكتروني', Icons.mail_outline_rounded),
                      ),
                      const SizedBox(height: 11),
                      TextField(
                        controller: _password,
                        obscureText: _hidePassword,
                        textDirection: TextDirection.ltr,
                        decoration: _inputDecoration(
                          'كلمة مرور حساب MESUT (10 أحرف على الأقل)',
                          Icons.lock_outline_rounded,
                          suffix: IconButton(
                            onPressed: () => setState(() => _hidePassword = !_hidePassword),
                            icon: Icon(_hidePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity, height: 49,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF7650D9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                          ),
                          onPressed: _busy ? null : _authenticate,
                          child: _busy
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(_register ? 'إنشاء حساب MESUT' : 'تسجيل الدخول'),
                        ),
                      ),
                    ],
                    if (!configured)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text('عنوان خادم MESUT غير مضبوط في هذه النسخة.', style: TextStyle(color: Colors.orangeAccent)),
                      ),
                  ]),
                ),
                if (_signedIn) ...[
                  _sectionTitle('خزنة البروفايلات', 'إدارة اشتراكات Xtream وصورها ورموز PIN',
                    trailing: TextButton.icon(
                      onPressed: _addProfile,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('إضافة اشتراك'),
                    ),
                  ),
                  if (!_profileVaultReady)
                    _panelCard(child: const Row(children: [
                      Icon(Icons.lock_outline_rounded, color: Colors.orangeAccent),
                      SizedBox(width: 10),
                      Expanded(child: Text('هذه الجلسة لا تملك مفتاح تشفير الخزنة. سجّل الدخول مجدداً بالحساب نفسه لتفعيل نقل البروفايلات بين الأجهزة.', style: TextStyle(fontSize: 12))),
                    ])),
                  if (accounts.isEmpty)
                    _panelCard(child: Column(children: [
                      const Icon(Icons.person_add_alt_1_rounded, size: 38, color: Colors.white54),
                      const SizedBox(height: 9),
                      const Text('لا توجد اشتراكات محفوظة بعد'),
                      const SizedBox(height: 4),
                      const Text('أضف اشتراك Xtream الأول وسيظهر هنا.', style: TextStyle(color: Colors.white60, fontSize: 12)),
                      const SizedBox(height: 12),
                      FilledButton.icon(onPressed: _addProfile, icon: const Icon(Icons.add), label: const Text('إضافة اشتراك')),
                    ]))
                  else
                    for (var i = 0; i < accounts.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _panelCard(
                          child: Column(children: [
                            Row(children: [
                              _avatar(accounts[i], i),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(accounts[i].name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                                const SizedBox(height: 3),
                                Text(accounts[i].url, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    textDirection: TextDirection.ltr, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                const SizedBox(height: 3),
                                Text('المستخدم: ${accounts[i].user}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                              ])),
                              PopupMenuButton<String>(
                                onSelected: (action) {
                                  final a = accounts[i];
                                  if (action == 'edit') _editProfile(a);
                                  if (action == 'avatar') _changeAvatar(a);
                                  if (action == 'pin') _managePin(a);
                                  if (action == 'removePin') _managePin(a, remove: true);
                                  if (action == 'delete') _deleteProfile(a);
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(value: 'edit', child: Text('تعديل الاشتراك')),
                                  const PopupMenuItem(value: 'avatar', child: Text('تغيير الصورة')),
                                  PopupMenuItem(value: 'pin', child: Text('إضافة / تغيير PIN')),
                                  const PopupMenuItem(value: 'removePin', child: Text('إزالة PIN')),
                                  const PopupMenuItem(value: 'delete', child: Text('حذف البروفايل')),
                                ],
                              ),
                            ]),
                            const Divider(color: Colors.white12, height: 20),
                            Row(children: [
                              Expanded(child: OutlinedButton.icon(
                                onPressed: () async {
                                  await Store.setActive(i);
                                  if (mounted) setState(() => _message = 'تم تعيين ${accounts[i].name} كبروفايل نشط');
                                },
                                icon: const Icon(Icons.check_circle_outline_rounded, size: 17),
                                label: const Text('تعيين نشط'),
                              )),
                              const SizedBox(width: 8),
                              Expanded(child: OutlinedButton.icon(
                                onPressed: () => _changeAvatar(accounts[i]),
                                icon: const Icon(Icons.face_retouching_natural_rounded, size: 17),
                                label: const Text('الصورة'),
                              )),
                            ]),
                          ]),
                        ),
                      ),
                  _sectionTitle('حماية البيانات', 'معلومات عن تشفير ومزامنة بروفايلاتك'),
                  _panelCard(child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.shield_rounded, color: Color(0xFF49D6A0)),
                      SizedBox(width: 9),
                      Text('خزنة مشفّرة من طرف العميل', style: TextStyle(fontWeight: FontWeight.w800)),
                    ]),
                    SizedBox(height: 8),
                    Text('كلمات مرور Xtream ورموز PIN تُشفّر على الجهاز قبل المزامنة. لا يستطيع الخادم قراءة محتوى الخزنة.', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  ])),
                  _sectionTitle(tr('الأجهزة المرتبطة'), tr('الأجهزة التي تستخدم حساب MESUT نفسه') + ' (' + _devices.length.toString() + '/5)',
                    trailing: IconButton(
                      tooltip: 'تحديث الأجهزة',
                      onPressed: _loadingDevices ? null : _loadDevices,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ),
                  if (_loadingDevices)
                    const Center(child: Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator()))
                  else if (_devices.isEmpty)
                    _panelCard(child: const Text('لا توجد أجهزة مسجلة بعد', style: TextStyle(color: Colors.white60)))
                  else
                    for (final device in _devices)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _panelCard(child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(device['platform'] == 'android_tv' ? Icons.tv_rounded : Icons.devices_rounded),
                          title: Text('${device['name'] ?? 'MESUT Device'}'),
                          subtitle: Text('${device['platform'] ?? 'other'} · ${device['lastSeenAt'] ?? ''}', maxLines: 2),
                          trailing: device['deviceKey'] == _currentDeviceKey
                              ? const Text('هذا الجهاز', style: TextStyle(fontSize: 11, color: Color(0xFF49D6A0)))
                              : IconButton(
                                  tooltip: 'إزالة الجهاز',
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                  onPressed: () => _removeDevice(device),
                                ),
                        )),
                      ),
                ],
                if (_busy) const Padding(
                  padding: EdgeInsets.all(14),
                  child: Center(child: CircularProgressIndicator()),
                ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _panelCard(child: Text(_message!, textAlign: TextAlign.center)),
                  ),
                const SizedBox(height: 20),
                const Text(
                  'الخصوصية: كلمة مرور MESUT لا تُحفظ كنص صريح. بيانات اشتراك IPTV ورموز PIN لا تغادر الجهاز إلا بعد تشفيرها.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.white38),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withOpacity(.045),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
      );
}
