import 'package:flutter/material.dart' hide Text;
import 'app_config.dart';
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
    required double width,
    required double height,
    bool autofocus = false,
  }) {
    return SizedBox(
      width: width,
      height: height,
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
          padding: EdgeInsets.all(kIsTvBuild ? 26 : 20),
          child: Stack(
            children: [
              Positioned(
                left: -12,
                top: -22,
                child: Icon(icon, size: kIsTvBuild ? 150 : 116,
                    color: Colors.white.withOpacity(0.07)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: kIsTvBuild ? 58 : 50,
                    height: kIsTvBuild ? 58 : 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(icon, size: kIsTvBuild ? 32 : 28,
                        color: Colors.white),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: TextStyle(
                                    fontSize: kIsTvBuild ? 27 : 22,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 5),
                            Text(subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: kIsTvBuild ? 15 : 13,
                                    color: Colors.white.withOpacity(0.78))),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white70, size: 22),
                    ],
                  ),
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tv = kIsTvBuild;
              final horizontal = constraints.maxWidth >= 700;
              final cardWidth = horizontal
                  ? (constraints.maxWidth * 0.40).clamp(300.0, 440.0)
                  : constraints.maxWidth - (tv ? 80 : 36);
              final cardHeight = tv ? 220.0 : (horizontal ? 190.0 : 154.0);
              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                      horizontal: tv ? 40 : 18, vertical: tv ? 28 : 20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: tv ? 76 : 64,
                          height: tv ? 76 : 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                                colors: [kViolet, kAccent]),
                            boxShadow: [
                              BoxShadow(
                                color: kViolet.withOpacity(0.28),
                                blurRadius: 28,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.play_arrow_rounded,
                              size: 42, color: Colors.white),
                        ),
                        SizedBox(height: tv ? 22 : 16),
                        Text('اختر الخدمة',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: tv ? 34 : 27,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text('اختر ما تريد استخدامه',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: tv ? 17 : 14,
                                color: Colors.white60)),
                        SizedBox(height: tv ? 38 : 26),
                        if (horizontal)
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 24,
                            runSpacing: 24,
                            children: [
                              _serviceCard(
                                context: context,
                                title: 'الرياضة',
                                subtitle: 'مواعيد المباريات والنتائج',
                                icon: Icons.emoji_events_rounded,
                                colors: const [Color(0xFF176B87), Color(0xFF10254F)],
                                onTap: () => _open(context, const SportsScreen()),
                                width: cardWidth,
                                height: cardHeight,
                                autofocus: true,
                              ),
                              _serviceCard(
                                context: context,
                                title: 'IPTV',
                                subtitle: 'قنوات وأفلام ومسلسلات باشتراكك',
                                icon: Icons.live_tv_rounded,
                                colors: const [Color(0xFF7545D8), Color(0xFF281B68)],
                                onTap: () => _open(context, const ProfilesScreen()),
                                width: cardWidth,
                                height: cardHeight,
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _serviceCard(
                                context: context,
                                title: 'الرياضة',
                                subtitle: 'مواعيد المباريات والنتائج',
                                icon: Icons.emoji_events_rounded,
                                colors: const [Color(0xFF176B87), Color(0xFF10254F)],
                                onTap: () => _open(context, const SportsScreen()),
                                width: cardWidth,
                                height: cardHeight,
                                autofocus: tv,
                              ),
                              const SizedBox(height: 14),
                              _serviceCard(
                                context: context,
                                title: 'IPTV',
                                subtitle: 'قنوات وأفلام ومسلسلات باشتراكك',
                                icon: Icons.live_tv_rounded,
                                colors: const [Color(0xFF7545D8), Color(0xFF281B68)],
                                onTap: () => _open(context, const ProfilesScreen()),
                                width: cardWidth,
                                height: cardHeight,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
