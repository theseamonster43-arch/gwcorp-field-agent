import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/history_repository.dart';
import '../../data/models.dart';
import '../../widgets/desktop_chrome.dart';
import '../../widgets/gw_glass.dart';
import '../ios/ios_home_screen.dart';
import '../ios/ios_scans_screen.dart';
import '../ios/ios_analytics_screen.dart';
import '../ios/ios_chats_screen.dart';
import '../ios/ios_ai_chat_screen.dart';
import '../ios/ios_satellite_screen.dart';
import '../ios/ios_account_screen.dart';

/// Desktop content area.
///
/// The title bar and the icon rail are chrome — they live in
/// MaterialApp.builder so they survive pushed routes. This widget only renders
/// whichever tab [desktopTab] currently points at.
class DesktopShell extends StatefulWidget {
  const DesktopShell({super.key});
  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell>
    with SingleTickerProviderStateMixin {
  /// Widest a tab is allowed to grow.
  ///
  /// 1040 was a phone layout with margins — on any normal monitor it left the
  /// app sitting in a narrow column with dead space either side. This is wide
  /// enough to use the screen while still stopping text lines from running so
  /// long they become hard to read on an ultrawide.
  static const _maxContentWidth = 1500.0;

  List<ScanSession> _sessions = [];
  StreamSubscription<List<ScanSession>>? _sessionSub;
  StreamSubscription<User?>? _authSub;

  /// Drives the fade-and-rise on tab swap, same as the phone shell.
  late final AnimationController _page;

  @override
  void initState() {
    super.initState();
    _page = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: 1, // first paint is already settled
    );
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      if (mounted) setState(() {});
    });
    _sessionSub = HistoryRepository.sessionsStream().listen((s) {
      if (mounted) setState(() => _sessions = s);
    });
    desktopTab.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    desktopTab.removeListener(_onTabChanged);
    _page.dispose();
    _sessionSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  void _onTabChanged() {
    if (!mounted) return;
    setState(() {});
    _page.forward(from: 0);
  }

  void _goTab(int i) => gwSelectDesktopTab(i);

  /// Holds a tab to a comfortable reading width on a wide monitor.
  Widget _boxed(Widget child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GwScreenBg(
        child: AnimatedBuilder(
          animation: _page,
          builder: (_, child) {
            final t = Curves.easeOut.transform(_page.value);
            return Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, 10 * (1 - t)),
                child: child,
              ),
            );
          },
          // Built once and reused across frames — IndexedStack keeps every
          // tab alive, so scroll offsets and Firestore listeners survive.
          child: IndexedStack(
            index: desktopTab.value,
            children: [
              _boxed(IosHomeScreen(
                sessions: _sessions,
                onNewScan: () => context.push('/main/batch'),
                onSeeAllScans: () => _goTab(kDesktopScansTab),
                onOpenAnalytics: () => _goTab(kDesktopStatsTab),
                onOpenChats: () => _goTab(kDesktopChatsTab),
                onOpenAi: () => _goTab(kDesktopAiTab),
              )),
              // Full-bleed: Scans is a list beside a detail pane now, not a
              // document. Centring it in a reading column left a dead margin
              // down both sides of the window.
              IosScansScreen(
                sessions: _sessions,
                onNewScan: () => context.push('/main/batch'),
              ),
              _boxed(IosAnalyticsScreen(sessions: _sessions)),
              // Chats and the assistant are full-height interfaces, not
              // documents: a conversation pane and a message thread should use
              // the window. Boxing them to a reading column left them floating
              // in the middle with dead space either side.
              const IosChatsList(showBack: false),
              const IosAiChatScreen(showBack: false),
              // The map is the page. Centring it in a reading-width column
              // leaves wallpaper down both sides, so satellite alone runs
              // edge to edge — stopping at the rail, which is outside this.
              IosSatelliteScreen(showBack: false, sessions: _sessions),
              _boxed(const IosAccountScreen()),
            ],
          ),
        ),
      ),
    );
  }
}
