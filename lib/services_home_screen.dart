import 'package:flutter/material.dart' hide Text;
import 'i18n.dart';
import 'theme.dart';
import 'sports_screen.dart';
import 'profiles_screen.dart';

/// Main services hub shown after the mandatory MESUT account sign-in.
class ServicesHomeScreen extends StatelessWidget {
  const ServicesHomeScreen({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  Widget _serviceCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
    bool autofocus = false,
  }) {
    return SizedBox(
      width: 320,
      height: 190,
      child: TvFocus(
        radius: 24,
        autofocus: autofocus,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: colors,
            ),
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 46, color: Colors.white),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 25, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.white70)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: kBgGradient,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_circle_fill_rounded,
                      size: 58, color: kAccent),
                  const SizedBox(height: 14),
                  Text('اختر الخدمة',
                      style: const TextStyle(
                          fontSize: 30, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('اختر ما تريد استخدامه',
                      style: const TextStyle(color: Colors.white60)),
                  const SizedBox(height: 34),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 22,
                    runSpacing: 22,
                    children: [
                      _serviceCard(
                        context: context,
                        title: 'الرياضة',
                        subtitle: 'مواعيد المباريات والنتائج',
                        icon: Icons.emoji_events_rounded,
                        colors: const [Color(0xFF176B87), Color(0xFF10254F)],
                        onTap: () => _open(context, const SportsScreen()),
                        autofocus: true,
                      ),
                      _serviceCard(
                        context: context,
                        title: 'IPTV',
                        subtitle: 'قنوات وأفلام ومسلسلات باشتراكك',
                        icon: Icons.live_tv_rounded,
                        colors: const [Color(0xFF7545D8), Color(0xFF281B68)],
                        onTap: () => _open(context, const ProfilesScreen()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
