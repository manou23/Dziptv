import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme.dart';
import 'app_config.dart';
import 'store.dart';
import 'i18n.dart';
import 'services_home_screen.dart';
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
      // Sync on every app launch; failed attempts are retried by the cloud service.
      await MesutCloudApi.scheduleSync();
    }
    if (!mesutSignedIn) {
      start = MesutAccountScreen(
        onAuthenticated: _openAppAfterMesutLogin,
      );
    } else {
      start = const ServicesHomeScreen();
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
      builder: (_) => const ServicesHomeScreen(),
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
          colorScheme: const ColorScheme.dark(primary: kViolet, secondary: kAccent),
          appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent, elevation: 0, centerTitle: true),
          chipTheme: ChipThemeData(
            selectedColor: kViolet,
            backgroundColor: Colors.white10,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ),
        navigatorKey: _appNavigatorKey,
        home: widget.start,
      ),
    );
  }
}
