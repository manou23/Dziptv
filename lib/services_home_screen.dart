import 'package:flutter/material.dart' hide Text;
import 'app_config.dart';
import 'i18n.dart';
import 'theme.dart';
import 'profiles_screen.dart';

/// TV keeps its familiar service launcher. Sports is temporarily hidden.
class ServicesHomeScreen extends StatelessWidget {
  const ServicesHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tv = kIsTvBuild;
    return Scaffold(
      body: Container(
        decoration: kBgGradient,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: tv ? 40 : 18, vertical: tv ? 28 : 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: tv ? 76 : 64, height: tv ? 76 : 64,
                    decoration: const BoxDecoration(shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [kViolet, kAccent])),
                    child: const Icon(Icons.play_arrow_rounded, size: 42, color: Colors.white)),
                  SizedBox(height: tv ? 22 : 16),
                  Text('اختر الخدمة', style: TextStyle(fontSize: tv ? 34 : 27, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('اختر ما تريد استخدامه', style: TextStyle(fontSize: tv ? 17 : 14, color: Colors.white60)),
                  SizedBox(height: tv ? 38 : 26),
                  SizedBox(width: tv ? 440 : double.infinity, height: tv ? 220 : 154,
                    child: TvFocus(radius: 24, autofocus: tv, onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const ProfilesScreen())),
                      child: Container(
                        decoration: const BoxDecoration(gradient: LinearGradient(
                          begin: Alignment.topRight, end: Alignment.bottomLeft,
                          colors: [Color(0xFF7545D8), Color(0xFF281B68)])),
                        padding: EdgeInsets.all(tv ? 26 : 20),
                        child: Stack(children: [
                          Positioned(left: -12, top: -22, child: Icon(Icons.live_tv_rounded,
                            size: tv ? 150 : 116, color: Colors.white.withOpacity(0.07))),
                          Column(crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Container(width: tv ? 58 : 50, height: tv ? 58 : 50,
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(18)),
                                child: Icon(Icons.live_tv_rounded, size: tv ? 32 : 28)),
                              Row(children: [
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('IPTV', style: TextStyle(fontSize: tv ? 27 : 22, fontWeight: FontWeight.w800)),
                                  Text('قنوات وأفلام ومسلسلات باشتراكك', style: TextStyle(
                                    fontSize: tv ? 15 : 13, color: Colors.white.withOpacity(0.78))),
                                ])),
                                const Icon(Icons.arrow_forward_rounded, color: Colors.white70),
                              ]),
                            ],
                          ),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
