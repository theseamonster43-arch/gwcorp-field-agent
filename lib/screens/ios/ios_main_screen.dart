import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/history_repository.dart';
import '../../data/models.dart';
import '../../theme/gw_theme.dart';
import '../../widgets/gw_icons.dart';
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
    // Slot 3 is the hamburger — it opens the menu instead of swapping screens.
    if (i == 3) {
      _openMore();
      return;
    }
    if (i != _tab) setState(() => _tab = i);
  }

  Future<void> _openMore() async {
    final gw = GwTheme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(.45),
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 14,
          right: 14,
          bottom: MediaQuery.of(sheetContext).padding.bottom + 14,
        ),
        child: GwGlass(
          radius: 26,
          blur: 30,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: gw.muted.withOpacity(.5),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _moreRow(
                gw,
                icon: GwIcons.chat,
                label: 'Chat',
                detail: 'Messages and team community',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/main/chats');
                },
              ),
              const SizedBox(height: 8),
              _moreRow(
                gw,
                icon: GwIcons.sparkle,
                label: 'AI Assistant',
                detail: 'Ask about waste and safety',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/main/ai');
                },
              ),
              const SizedBox(height: 8),
              _moreRow(
                gw,
                icon: GwIcons.satellite,
                label: 'Satellite',
                detail: 'Coming soon',
                enabled: false,
                onTap: () {},
              ),
              const SizedBox(height: 8),
              _moreRow(
                gw,
                icon: GwIcons.user,
                label: 'Account',
                detail: 'Profile, preferences and data',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  setState(() => _tab = 3);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _moreRow(
    GwColors gw, {
    required String icon,
    required String label,
    required String detail,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    final row = GwGlass(
      radius: 18,
      blur: 12,
      padding: const EdgeInsets.all(13),
      onTap: enabled ? onTap : null,
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: gw.green.withOpacity(.16),
            borderRadius: BorderRadius.circular(13),
          ),
          child: GwIcon(icon, size: 20, color: gw.green),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: gw.text,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: gw.muted, fontSize: 11.5),
              ),
            ],
          ),
        ),
        GwIcon(
          enabled ? GwIcons.chevronRight : GwIcons.lock,
          size: 17,
          color: gw.muted,
        ),
      ]),
    );
    return enabled ? row : Opacity(opacity: .5, child: row);
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
