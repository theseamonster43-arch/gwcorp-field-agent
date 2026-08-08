import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/history_repository.dart';
import '../../data/models.dart';
import '../../widgets/gw_glass.dart';
import '../../widgets/gw_tab_bar.dart';
import 'ios_home_screen.dart';
import 'ios_scans_screen.dart';
import 'ios_analytics_screen.dart';
import 'ios_chats_screen.dart';
import 'ios_account_screen.dart';

/// Phone shell. Tabs mirror the web app's rail — Home, Scans, Stats, Chats —
/// with the new-scan button in the middle. Account is reached from the avatar
/// on Home, exactly as the web nav does it, so there is no "more" menu.
class IosMainScreen extends StatefulWidget {
  const IosMainScreen({super.key});
  @override
  State<IosMainScreen> createState() => _IosMainScreenState();
}

class _IosMainScreenState extends State<IosMainScreen> {
  /// 0 Home · 1 Scans · 2 Stats · 3 Chats · 4 Account (no slot in the bar)
  int _tab = 0;
  List<ScanSession> _sessions = [];
  StreamSubscription<List<ScanSession>>? _sessionSub;
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      if (mounted) setState(() {});
    });
    _sessionSub = HistoryRepository.sessionsStream().listen((s) {
      if (mounted) setState(() => _sessions = s);
    });
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  void _goTab(int i) {
    if (i != _tab) setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: GwScreenBg(
        child: Stack(children: [
          Positioned.fill(
            // Built once and reused across frames — an IndexedStack keeps each
            // tab's scroll position and its Firestore listeners alive.
            child: IndexedStack(
              index: _tab,
              children: [
                IosHomeScreen(
                  sessions: _sessions,
                  onNewScan: () => context.push('/main/batch'),
                  onSeeAllScans: () => _goTab(1),
                  onOpenAnalytics: () => _goTab(2),
                  onOpenChats: () => _goTab(3),
                  onOpenAi: () => context.push('/main/ai'),
                  onOpenAccount: () => _goTab(4),
                ),
                IosScansScreen(
                  sessions: _sessions,
                  onNewScan: () => context.push('/main/batch'),
                ),
                IosAnalyticsScreen(sessions: _sessions),
                const IosChatsList(showBack: false),
                const IosAccountScreen(),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GwTabBar(
              // Account has no slot of its own; keep Home lit while it shows.
              currentIndex: _tab == 4 ? 0 : _tab,
              onTap: _goTab,
              onCenterTap: () => context.push('/main/batch'),
            ),
          ),
        ]),
      ),
    );
  }
}
