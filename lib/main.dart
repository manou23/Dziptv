import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme.dart';
import 'app_config.dart';
import 'store.dart';
import 'i18n.dart';
import 'services_home_screen.dart';
import 'profiles_screen.dart';
import 'mesut_account_screen.dart';
import 'mesut_cloud_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Keep the decoded image cache bounded for phones and Android TV devices.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 64 << 20;
  PaintingBinding.instance.imageCache.maximumSize = 250;

  Widget start;
  try {
    SystemChrome.setEnabledSystemUIMode(
      kIsTvBuild ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    if (kIsTvBuild) {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    }
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    await Store.init();
    // Every local favorite/history/settings change schedules automatic cloud sync.
    Store.cloudSyncCallback = MesutCloudApi.scheduleSync;
    I18n.init();
    Store.cloudSettingsAppliedCallback = I18n.init;
    // حساب MESUT إلزامي قبل السماح بإضافة حساب Xtream أو دخول التطبيق.
    MesutCloudApi.onSessionExpired = _showMesutAccount;
    final mesutSignedIn = await MesutCloudApi.validateSession();
    if (mesutSignedIn) {
      // Restore cloud profiles before building the profile picker. A background-only
      // sync can finish after the empty picker has already been rendered.
      try {
        await MesutCloudApi.syncNow();
      } catch (_) {
        await MesutCloudApi.scheduleSync();
      }
    }
    if (!mesutSignedIn) {
      start = MesutAccountScreen(
        onAuthenticated: _openAppAfterMesutLogin,
      );
    } else {
      start = kIsTvBuild ? const ServicesHomeScreen() : const ProfilesScreen();
    }
  } catch (e, s) {
    // بدل أن يغلق التطبيق: نعرض سبب الخطأ على الشاشة
    runApp(_StartupError('$e\n\n$s'));
    return;
  }

  runApp(MesutApp(start: start));
}

class _StartupError extends StatelessWidget {
  final String message;
  const _StartupError(this.message);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark),
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(message,
                style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
          ),
        ),
      ),
    );
  }
}

void _openAppAfterMesutLogin() {
  _appNavigatorKey.currentState?.pushAndRemoveUntil(
    MaterialPageRoute<void>(
      builder: (_) => kIsTvBuild ? const ServicesHomeScreen() : const ProfilesScreen(),
    ),
    (route) => false,
  );
}

void _showMesutAccount() {
  _appNavigatorKey.currentState?.pushAndRemoveUntil(
    MaterialPageRoute<void>(
      builder: (_) => MesutAccountScreen(
        onAuthenticated: _openAppAfterMesutLogin,
      ),
    ),
    (route) => false,
  );
}

final GlobalKey<NavigatorState> _appNavigatorKey = GlobalKey<NavigatorState>();

class MesutApp extends StatefulWidget {
  final Widget start;
  const MesutApp({super.key, required this.start});

  @override
  State<MesutApp> createState() => _MesutAppState();
}

class _MesutAppState extends State<MesutApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh cloud data when the user returns to the app.
      MesutCloudApi.scheduleSync();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: I18n.notifier,
      builder: (_, lang, __) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Mesut IPTV',
        locale: Locale(lang),
        supportedLocales: const [Locale('ar'), Locale('fr'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: kBg,
          colorScheme: const ColorScheme.dark(
            primary: kViolet,
            secondary: kAccent,
            surface: Color(0xFF111A30),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            scrolledUnderElevation: 0,
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white.withOpacity(0.06),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: kAccent, width: 1.7),
            ),
          ),
          chipTheme: ChipThemeData(
            selectedColor: kViolet,
            backgroundColor: Colors.white10,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        navigatorKey: _appNavigatorKey,
        home: widget.start,
      ),
    );
  }
}
