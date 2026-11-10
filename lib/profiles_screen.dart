import 'dart:convert';
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
import 'mesut_cloud_api.dart';

/// Netflix-style Xtream profiles with an independent optional PIN per profile.
class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({super.key});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _AvatarPickerDialog extends StatelessWidget {
  final Account account;
  final List<Map<String, String>> avatars;
  final List<List<Color>> palette;
  final int columns;
  final String? selected;
  final ValueChanged<String> onSelected;
  final VoidCallback onCancel;
  final VoidCallback onReset;
  final VoidCallback onConfirm;

  const _AvatarPickerDialog({
    required this.account,
    required this.avatars,
    required this.palette,
    required this.columns,
    required this.selected,
    required this.onSelected,
    required this.onCancel,
    required this.onReset,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final active = avatars.indexWhere((item) => item['id'] == selected);
    final preview = active >= 0 ? avatars[active] : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38, height: 4,
            decoration: BoxDecoration(
              color: Colors.white30,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'صورة البروفايل',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'اختر الشخصية التي تمثلك',
            style: TextStyle(fontSize: 12, color: Colors.white60),
          ),
          const SizedBox(height: 15),
          if (preview != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 54, height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: palette[active % palette.length],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: const Color(0xFFB58CFF), width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(preview['emoji']!, style: const TextStyle(fontSize: 31)),
                ),
                const SizedBox(width: 11),
                Text(
                  preview['label']!,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(width: 7),
                const Icon(Icons.check_circle_rounded, color: Color(0xFFB58CFF), size: 18),
              ],
            ),
          const SizedBox(height: 15),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 4),
              itemCount: avatars.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 9,
                mainAxisSpacing: 9,
                childAspectRatio: .94,
              ),
              itemBuilder: (context, index) {
                final avatar = avatars[index];
                final isSelected = selected == avatar['id'];
                return Material(
                  color: isSelected ? const Color(0xFF30264C) : const Color(0xFF22252D),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onSelected(avatar['id']!),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFB58CFF) : Colors.white10,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(7),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Center(
                              child: Container(
                                width: 58, height: 58,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: palette[index % palette.length],
                                    begin: Alignment.topRight,
                                    end: Alignment.bottomLeft,
                                  ),
                                  borderRadius: BorderRadius.circular(17),
                                  boxShadow: [
                                    BoxShadow(
                                      color: palette[index % palette.length].last.withOpacity(.25),
                                      blurRadius: 12,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  avatar['emoji']!,
                                  style: const TextStyle(fontSize: 34),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            avatar['label']!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                              color: isSelected ? Colors.white : Colors.white70,
                            ),
                          ),
                          if (isSelected)
                            const Padding(
                              padding: EdgeInsets.only(top: 3),
                              child: Icon(Icons.check_circle_rounded,
                                size: 15, color: Color(0xFFB58CFF)),
                            )
                          else
                            const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (account.avatar.isNotEmpty)
                TextButton(
                  onPressed: onReset,
                  child: const Text('الافتراضية'),
                ),
              const Spacer(),
              TextButton(onPressed: onCancel, child: const Text('إلغاء')),
              const SizedBox(width: 7),
              FilledButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('حفظ'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7650D9),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  bool _edit = false;
  bool _syncingCloud = false;

  Future<void> _refreshCloudProfiles() async {
    if (_syncingCloud) return;
    setState(() => _syncingCloud = true);
    try {
      await MesutCloudApi.syncNow();
      if (!mounted) return;
      setState(() => _syncingCloud = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث البروفايلات من حساب MESUT السحابي')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _syncingCloud = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

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
    await Store.notifyCloudProfilesChanged();
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
    await Store.notifyCloudProfilesChanged();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تمت إزالة PIN')),
      );
    }
  }

  static const _profileAvatars = <Map<String, String>>[
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
  ];

  Future<void> _editProfileImage(Account account) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final width = MediaQuery.of(dialogContext).size.width;
        final columns = kIsTvBuild ? 4 : (width < 360 ? 2 : 3);
        return Dialog(
          backgroundColor: const Color(0xFF17191F),
          insetPadding: EdgeInsets.symmetric(
            horizontal: kIsTvBuild ? 70 : 18,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
            side: const BorderSide(color: Colors.white12),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: kIsTvBuild ? 650 : 460,
              maxHeight: MediaQuery.of(dialogContext).size.height * .82,
            ),
            child: StatefulBuilder(
              builder: (context, setPickerState) {
                String? chosen = account.avatar;
                return _AvatarPickerDialog(
                  account: account,
                  avatars: _profileAvatars,
                  palette: _palette,
                  columns: columns,
                  selected: chosen,
                  onSelected: (value) => setPickerState(() => chosen = value),
                  onCancel: () => Navigator.pop(dialogContext),
                  onReset: () => Navigator.pop(dialogContext, ''),
                  onConfirm: () => Navigator.pop(dialogContext, chosen),
                );
              },
            ),
          ),
        );
      },
    );
    if (!mounted || selected == null) return;
    await Store.updateAccountAvatar(account.id, selected);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(selected.isEmpty
            ? 'تمت إعادة صورة البروفايل الافتراضية'
            : 'تم حفظ صورة البروفايل')),
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

  Widget _avatarContent(Account account, String initial) {
    final fallback = Center(
      child: Text(initial, style: const TextStyle(
        fontSize: kIsTvBuild ? 54 : 40,
        fontWeight: FontWeight.bold,
      )),
    );
    if (account.avatar.isEmpty) return fallback;
    final preset = _profileAvatars.where((item) => item['id'] == account.avatar);
    if (preset.isNotEmpty) {
      return Center(
        child: Text(
          preset.first['emoji']!,
          style: TextStyle(fontSize: kIsTvBuild ? 66 : 50),
        ),
      );
    }
    // Keep showing older custom avatars already saved by previous app versions.
    try {
      return ClipRRect(
        borderRadius: BorderRadius.circular(kIsTvBuild ? 20 : 11),
        child: Image.memory(
          base64Decode(account.avatar),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
        ),
      );
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _manageProfile(Account account, int index) async {
    final hasPin = await ProfilePinService.hasPin(account.id);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF17191F),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              const SizedBox(height: 18),
              Text(account.name, style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800,
              )),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.face_retouching_natural_rounded),
                title: Text('تغيير صورة البروفايل'),
                subtitle: Text('اختر صورة من الصور المدمجة'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _editProfileImage(account);
                },
              ),
              ListTile(
                leading: Icon(hasPin ? Icons.lock_reset_rounded : Icons.lock_outline_rounded),
                title: Text(hasPin ? 'تغيير رمز PIN' : 'إضافة رمز PIN'),
                subtitle: Text(hasPin ? 'تحديث رمز الحماية الحالي' : 'حماية هذا البروفايل برمز'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _configurePin(account);
                },
              ),
              if (hasPin)
                ListTile(
                  leading: const Icon(Icons.lock_open_rounded),
                  title: Text('إزالة رمز PIN'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _removePin(account);
                  },
                ),
              const Divider(color: Colors.white12),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: Text('حذف البروفايل', style: const TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _delete(index);
                },
              ),
            ],
          ),
        ),
      ),
    );
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
              onTap: () => _edit ? _manageProfile(a, i) : _open(i),
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
                    child: _avatarContent(a, initial),
                  ),
                  if (_edit)
                    Container(
                      color: Colors.black45,
                      child: const Center(
                        child: Icon(Icons.edit_rounded, size: 34, color: Colors.white),
                      ),
                    ),
                  if (!_edit)
                    FutureBuilder<bool>(
                      future: ProfilePinService.hasPin(a.id),
                      builder: (_, snapshot) => snapshot.data == true
                          ? const Positioned(
                              top: 8,
                              right: 8,
                              child: Icon(Icons.lock_rounded, size: 19),
                            )
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: kIsTvBuild ? 17 : 13,
              fontWeight: FontWeight.w600,
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
                    IconButton(
                      tooltip: 'مزامنة البروفايلات',
                      onPressed: _syncingCloud ? null : _refreshCloudProfiles,
                      icon: _syncingCloud
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_sync_rounded),
                    ),
                    if (accs.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(() => _edit = !_edit),
                        child: Text(_edit ? 'تم' : 'إدارة البروفايلات'),
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
                        Text(_edit ? 'إدارة البروفايلات' : 'من يشاهد؟',
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
