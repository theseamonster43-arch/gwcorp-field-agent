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
import 'ios_account_screen.dart';

class IosMainScreen extends StatefulWidget {
  const IosMainScreen({super.key});
  @override
  State<IosMainScreen> createState() => _IosMainScreenState();
}

class _IosMainScreenState extends State<IosMainScreen> {
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
            child: IndexedStack(
              index: _tab,
              children: [
                IosHomeScreen(
                  sessions: _sessions,
                  onNewScan: () => context.push('/main/batch'),
                  onSeeAllScans: () => _goTab(1),
                  onOpenAnalytics: () => _goTab(2),
                  onOpenChats: () => context.push('/main/chats'),
                  onOpenAi: () => context.push('/main/ai'),
                ),
                IosScansScreen(
                  sessions: _sessions,
                  onNewScan: () => context.push('/main/batch'),
                ),
                IosAnalyticsScreen(sessions: _sessions),
                const IosAccountScreen(),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GwTabBar(
              currentIndex: _tab,
              onTap: _goTab,
              onCenterTap: () => context.push('/main/batch'),
            ),
          ),
        ]),
      ),
    );
  }
}
