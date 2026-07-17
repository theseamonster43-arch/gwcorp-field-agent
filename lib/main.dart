import 'dart:io' show Platform;
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'firebase_options.dart';
import 'theme/gw_theme.dart';
import 'utils/app_preferences.dart';
import 'screens/splash_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/main_screen.dart';
import 'screens/ios/ios_sign_in_screen.dart';
import 'screens/ios/ios_main_screen.dart';
import 'screens/session_detail_screen.dart';
import 'screens/new_direct_chat_screen.dart';
import 'screens/direct_chat_detail_screen.dart';
import 'screens/web_view_screen.dart';
import 'screens/batch_setup_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/results_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        titleBarStyle: TitleBarStyle.hidden,
        minimumSize: Size(900, 600),
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const GwApp());
}

Page<void> _fadePage(GoRouterState state, Widget child) => CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (_, anim, __, c) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: c,
      ),
    );

Page<void> _slidePage(GoRouterState state, Widget child) => CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 320),
      transitionsBuilder: (_, anim, __, c) => SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: anim,
              curve: const Interval(0, 0.4, curve: Curves.easeOut)),
          child: c,
        ),
      ),
    );

final _router = GoRouter(
  initialLocation: '/splash',
  observers: [CNTabBarRouteObserver()],
  routes: [
    GoRoute(path: '/splash',  pageBuilder: (_, s) => _fadePage(s, const SplashScreen())),
    GoRoute(path: '/signin',  pageBuilder: (_, s) => _fadePage(s, Platform.isIOS ? const IosSignInScreen() : const SignInScreen())),
    GoRoute(path: '/main',    pageBuilder: (_, s) => _fadePage(s, Platform.isIOS ? const IosMainScreen()    : const MainScreen())),
    GoRoute(
      path: '/main/session/:id',
      pageBuilder: (_, s) => _slidePage(s,
          SessionDetailScreen(sessionId: s.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/main/newchat',
      pageBuilder: (_, s) => _slidePage(s,
          NewDirectChatScreen(
            onDismiss:    (ctx) => ctx.pop(),
            onChatCreated: (ctx, chatId, _) => ctx.go('/main/directchat/$chatId'),
          )),
    ),
    GoRoute(
      path: '/main/directchat/:id',
      pageBuilder: (_, s) => _slidePage(s,
          DirectChatDetailScreen(
            chatId: s.pathParameters['id']!,
            onBack: (ctx) => ctx.pop(),
          )),
    ),
    GoRoute(path: '/main/web',     pageBuilder: (_, s) => _slidePage(s, const WebViewScreen())),
    GoRoute(path: '/main/batch',   pageBuilder: (_, s) => _slidePage(s, const BatchSetupScreen())),
    GoRoute(path: '/main/camera',  pageBuilder: (_, s) => _slidePage(s, const CameraScreen())),
    GoRoute(path: '/main/results', pageBuilder: (_, s) => _slidePage(s, const ResultsScreen())),
  ],
);

class GwApp extends StatefulWidget {
  const GwApp({super.key});
  @override
  State<GwApp> createState() => _GwAppState();
}

class _GwAppState extends State<GwApp> with WidgetsBindingObserver {
  late GwColors _gw;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    themeModeNotifier.addListener(_onPreferenceChange);
    _gw = _resolveColors();
    _applyStatusBar(_gw);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    themeModeNotifier.removeListener(_onPreferenceChange);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => _onPreferenceChange();

  void _onPreferenceChange() {
    final gw = _resolveColors();
    _applyStatusBar(gw);
    setState(() => _gw = gw);
  }

  GwColors _resolveColors() {
    final mode = themeModeNotifier.value;
    bool isDark;
    if (mode == ThemeMode.dark) {
      isDark = true;
    } else if (mode == ThemeMode.light) {
      isDark = false;
    } else {
      isDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    }
    return isDark ? GwColors.dark : GwColors.light;
  }

  void _applyStatusBar(GwColors gw) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor:           Colors.transparent,
      statusBarIconBrightness:  gw.isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness:      gw.isDark ? Brightness.dark  : Brightness.light,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return GwTheme(
      colors: _gw,
      child: CupertinoTheme(
        data: CupertinoThemeData(
          brightness: _gw.isDark ? Brightness.dark : Brightness.light,
          textTheme: CupertinoTextThemeData(
            navTitleTextStyle: GoogleFonts.dmSans(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: _gw.isDark ? CupertinoColors.white : CupertinoColors.black,
            ),
            navLargeTitleTextStyle: GoogleFonts.dmSans(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: _gw.isDark ? CupertinoColors.white : CupertinoColors.black,
            ),
          ),
        ),
        child: MaterialApp.router(
          title: 'GWCORP Field Agent',
          debugShowCheckedModeBanner: false,
          theme:     buildMaterialTheme(GwColors.light).copyWith(textTheme: GoogleFonts.dmSansTextTheme(buildMaterialTheme(GwColors.light).textTheme)),
          darkTheme: buildMaterialTheme(GwColors.dark).copyWith(textTheme: GoogleFonts.dmSansTextTheme(buildMaterialTheme(GwColors.dark).textTheme)),
          themeMode: _gw.isDark ? ThemeMode.dark : ThemeMode.light,
          routerConfig: _router,
        ),
      ),
    );
  }
}
