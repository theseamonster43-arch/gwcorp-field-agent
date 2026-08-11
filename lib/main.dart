import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';
import 'firebase_options.dart';
import 'theme/gw_theme.dart';
import 'services/deep_links.dart';
import 'utils/app_preferences.dart';
import 'widgets/desktop_chrome.dart';
import 'widgets/desktop_rail.dart';
import 'screens/splash_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/ios/ios_sign_in_screen.dart';
import 'screens/ios/ios_main_screen.dart';
import 'screens/ios/ios_chats_screen.dart';
import 'screens/ios/ios_ai_chat_screen.dart';
import 'screens/desktop/desktop_shell.dart';
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
  // Before runApp, so the saved theme is in place for the first frame.
  await gwLoadPreferences();
  // Catches the cold-start case: the app launched *by* a gwcorp:// link.
  await gwInitDeepLinks();
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

/// Phones get the bottom tab bar; desktop gets the web app's top-nav layout.
/// Both drive the same tab screens under screens/ios.
final bool _isPhone = Platform.isIOS || Platform.isAndroid;

/// Routes that get bare chrome — window buttons only, no branding or rail.
const _bareChromeRoutes = {'/splash', '/signin'};

final _router = GoRouter(
  initialLocation: '/splash',
  // Never actually redirects; this is the one hook that sees every navigation,
  // and the desktop chrome sits above the router so it cannot observe routes
  // on its own. Deferred a frame because notifying listeners mid-navigation
  // would rebuild them during a build.
  redirect: (context, state) {
    final minimal = _bareChromeRoutes.contains(state.matchedLocation);
    if (gwChromeMinimal.value != minimal) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => gwChromeMinimal.value = minimal,
      );
    }
    return null;
  },
  routes: [
    GoRoute(path: '/splash',  pageBuilder: (_, s) => _fadePage(s, const SplashScreen())),
    // Desktop keeps its own sign-in: it carries DesktopTitleBar, and the
    // window has no OS title bar to drag or close without it.
    GoRoute(path: '/signin',  pageBuilder: (_, s) => _fadePage(s, _isPhone ? const IosSignInScreen() : const SignInScreen())),
    GoRoute(path: '/main',    pageBuilder: (_, s) => _fadePage(s, _isPhone ? const IosMainScreen() : const DesktopShell())),
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
    GoRoute(path: '/main/chats',   pageBuilder: (_, s) => _slidePage(s, const IosChatsList())),
    GoRoute(path: '/main/ai',      pageBuilder: (_, s) => _slidePage(s, const IosAiChatScreen())),
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
    // The desktop chrome renders above the router and has no GoRouter in its
    // context, so hand it the router's navigation methods.
    gwGo   = _router.go;
    gwPush = _router.push;
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
      child: MaterialApp.router(
        title: 'GWCORP Field Agent',
        debugShowCheckedModeBanner: false,
        theme:     buildMaterialTheme(GwColors.light),
        darkTheme: buildMaterialTheme(GwColors.dark),
        themeMode: _gw.isDark ? ThemeMode.dark : ThemeMode.light,
        routerConfig: _router,
        // The OS title bar is hidden, so ours has to sit above every route —
        // splash, sign-in, dialogs and all — or the window cannot be moved,
        // minimised or closed from those screens.
        builder: (context, child) {
          final page = child ?? const SizedBox.shrink();
          if (!isDesktop) return page;
          // The title bar and rail are chrome, not part of any route, so they
          // live here — above the Navigator. That is what keeps the rail on
          // screen while a scan or session detail is pushed over the shell.
          //
          // Nothing here may use Navigator, Overlay or GoRouter from this
          // context, and Text needs a Material ancestor or it renders with the
          // raw engine default: yellow-underlined, ignoring the theme.
          return Material(
            color: Colors.transparent,
            child: Column(children: [
              const DesktopTitleBar(),
              Expanded(
                child: Row(children: [
                  const DesktopRail(),
                  Expanded(child: page),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}
