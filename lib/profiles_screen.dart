import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'app_config.dart';
import 'i18n.dart';
import 'models.dart';
import 'theme.dart';
import 'store.dart';
import 'xtream_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'profile_pin_service.dart';

/// Netflix-style Xtream profiles with an independent optional PIN per profile.
class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({super.key});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  bool _edit = false;

  static const _palette = [
    [Color(0xFF8668FF), Color(0xFF35145F)],
    [Color(0xFF35B8FF), Color(0xFF1A2760)],
    [Color(0xFF28D59A), Color(0xFF145B62)],
    [Color(0xFF7138E8), Color(0xFF25215F)],
    [Color(0xFFC25BFF), Color(0xFF60244B)],
  ];

  Future<String?> _askPin(String title) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        var hidePin = true;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              obscureText: hidePin,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 6,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: tr('رمز PIN (4 إلى 6 أرقام)'),
                counterText: '',
                suffixIcon: IconButton(
                  tooltip: tr(hidePin ? 'إظهار PIN' : 'إخفاء PIN'),
                  icon: Icon(hidePin ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                  onPressed: () => setDialogState(() => hidePin = !hidePin),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, controller.text),
                child: Text('تأكيد'),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<bool> _unlock(Account account) async {
    if (!await ProfilePinService.hasPin(account.id)) return true;
    final pin = await _askPin('أدخل PIN لفتح ${account.name}');
    if (!mounted || pin == null) return false;
    final valid = await ProfilePinService.verify(account.id, pin);
    if (!valid && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('رمز PIN غير صحيح')),
      );
    }
    return valid;
  }

  Future<void> _configurePin(Account account) async {
    final hasPin = await ProfilePinService.hasPin(account.id);
    if (hasPin) {
      final current = await _askPin('أدخل PIN الحالي');
      if (!mounted || current == null) return;
      if (!await ProfilePinService.verify(account.id, current)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('رمز PIN غير صحيح')),
          );
        }
        return;
      }
    }

    final pin = await _askPin('رمز PIN جديد');
    if (!mounted || pin == null) return;
    if (!ProfilePinService.isValidPin(pin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يجب أن يتكون PIN من 4 إلى 6 أرقام')),
      );
      return;
    }
    final confirm = await _askPin('أعد إدخال PIN للتأكيد');
    if (!mounted || confirm == null) return;
    if (pin != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('الرمزان غير متطابقين')),
      );
      return;
    }
    await ProfilePinService.setPin(account.id, pin);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حفظ PIN لهذا البروفايل')),
      );
    }
  }

  Future<void> _removePin(Account account) async {
    final current = await _askPin('أدخل PIN الحالي لإزالته');
    if (!mounted || current == null) return;
    if (!await ProfilePinService.verify(account.id, current)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('رمز PIN غير صحيح')),
        );
      }
      return;
    }
    await ProfilePinService.remove(account.id);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تمت إزالة PIN')),
      );
    }
  }

  Future<void> _open(int i) async {
    final account = Store.accounts()[i];
    if (!await _unlock(account) || !mounted) return;
    await Store.setActive(i);
    final a = Store.active;
    if (!mounted || a == null) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => HomeScreen(service: XtreamService.fromAccount(a)),
    ));
  }

  Future<void> _add() async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute<void>(builder: (_) => const LoginScreen(returnToProfiles: true)));
    if (mounted) setState(() {});
  }

  Future<void> _delete(int i) async {
    final accounts = Store.accounts();
    if (i < 0 || i >= accounts.length) return;
    if (!await _unlock(accounts[i]) || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('حذف الحساب'),
        content: Text('هل تريد حذف هذا الحساب؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true), child: Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    await ProfilePinService.remove(accounts[i].id);
    await Store.removeAccount(i);
    if (!mounted) return;
    if (Store.accounts().isEmpty) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } else {
      setState(() => _edit = Store.accounts().isEmpty ? false : _edit);
    }
  }

  Widget _tile(int i, Account a) {
    final c = _palette[i % _palette.length];
    final name = a.name.trim().isEmpty ? '?' : a.name.trim();
    final initial = String.fromCharCode(name.runes.first).toUpperCase();
    return SizedBox(
      width: kIsTvBuild ? 160 : 116,
      child: Column(
        children: [
          SizedBox(
            width: kIsTvBuild ? 136 : 96,
            height: kIsTvBuild ? 136 : 96,
            child: TvFocus(
              radius: kIsTvBuild ? 20 : 11,
              autofocus: kIsTvBuild && i == 0,
              onTap: () => _edit ? _delete(i) : _open(i),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: c,
                      ),
                    ),
                    child: Center(
                      child: Text(initial,
                          style: const TextStyle(
                              fontSize: kIsTvBuild ? 54 : 40, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  if (_edit)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                          child: Icon(Icons.delete_outline_rounded, size: 40)),
                    ),
                  if (!_edit)
                    FutureBuilder<bool>(
                      future: ProfilePinService.hasPin(a.id),
                      builder: (_, snapshot) => snapshot.data == true
                          ? const Positioned(
                              top: 8,
                              right: 8,
                              child: Icon(Icons.lock_rounded, size: 20),
                            )
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: kIsTvBuild ? 17 : 13, fontWeight: FontWeight.w600)),
          if (!_edit)
            FutureBuilder<bool>(
              future: ProfilePinService.hasPin(a.id),
              builder: (_, snapshot) => Wrap(
                alignment: WrapAlignment.center,
                spacing: 2,
                children: [
                  TextButton.icon(
                    onPressed: () => _configurePin(a),
                    icon: Icon(
                      snapshot.data == true ? Icons.lock_reset_rounded : Icons.lock_open_rounded,
                      size: 17,
                    ),
                    label: Text(snapshot.data == true ? 'تغيير PIN' : 'تعيين PIN'),
                  ),
                  if (snapshot.data == true)
                    TextButton.icon(
                      onPressed: () => _removePin(a),
                      icon: const Icon(Icons.lock_open_rounded, size: 17),
                      label: Text('إزالة PIN'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _addTile({bool autofocus = false}) {
    return SizedBox(
      width: kIsTvBuild ? 136 : 96,
      child: Column(
        children: [
          SizedBox(
            width: kIsTvBuild ? 136 : 96,
            height: kIsTvBuild ? 136 : 96,
            child: TvFocus(
              radius: 20,
              autofocus: autofocus,
              onTap: _add,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white10,
                  border: Border.all(color: Colors.white24, width: 1.5),
                  borderRadius: BorderRadius.circular(kIsTvBuild ? 20 : 11),
                ),
                child: const Center(
                  child: Icon(Icons.add_rounded, size: kIsTvBuild ? 60 : 44, color: Colors.white70),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text('إضافة حساب',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.white70)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accs = Store.accounts();
    return Scaffold(
      backgroundColor: const Color(0xFF090A0D),
      body: Container(
        decoration: kIsTvBuild ? kBgGradient : const BoxDecoration(color: Color(0xFF090A0D)),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    if (Navigator.canPop(context))
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: Text('الخدمات'),
                      ),
                    const Spacer(),
                    if (accs.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(() => _edit = !_edit),
                        child: Text(_edit ? 'تم' : 'إدارة الحسابات'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(kIsTvBuild ? 34 : 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('من يشاهد؟',
                            style: const TextStyle(
                                fontSize: kIsTvBuild ? 34 : 26, fontWeight: FontWeight.w800)),
                        SizedBox(height: kIsTvBuild ? 42 : 26),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: kIsTvBuild ? 32 : 16,
                          runSpacing: kIsTvBuild ? 34 : 22,
                          children: [
                            for (var i = 0; i < accs.length; i++) _tile(i, accs[i]),
                            if (!_edit) _addTile(autofocus: kIsTvBuild && accs.isEmpty),
                          ],
                        ),
                      ],
                    ),
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
