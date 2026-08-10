import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/history_repository.dart';
import '../../data/models.dart';
import '../../theme/gw_theme.dart';
import '../../widgets/gw_icons.dart';
import '../../widgets/gw_glass.dart';
import '../../widgets/gw_sheet.dart';
import '../../widgets/gw_tab_bar.dart';
import '../batch_setup_screen.dart';
import 'ios_ai_chat_screen.dart';
import 'ios_chats_screen.dart';
import 'ios_home_screen.dart';
import 'ios_scans_screen.dart';
import 'ios_analytics_screen.dart';
import 'ios_satellite_screen.dart';
import 'ios_account_screen.dart';

class IosMainScreen extends StatefulWidget {
  const IosMainScreen({super.key});
  @override
  State<IosMainScreen> createState() => _IosMainScreenState();
}

class _IosMainScreenState extends State<IosMainScreen>
    with SingleTickerProviderStateMixin {
  int _tab = 0;
  List<ScanSession> _sessions = [];
  StreamSubscription<List<ScanSession>>? _sessionSub;
  StreamSubscription<User?>? _authSub;

  /// Drives the same fade-and-rise the web app plays when a view is swapped
  /// (the `gwFade` keyframes in field-agent.html).
  late final AnimationController _swap;

  @override
  void initState() {
    super.initState();
    _swap = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      value: 1, // first paint is already settled
    );
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      if (mounted) setState(() {});
    });
    _sessionSub = HistoryRepository.sessionsStream().listen((s) {
      if (mounted) setState(() => _sessions = s);
    });
  }

  @override
  void dispose() {
    _swap.dispose();
    _sessionSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  void _setTab(int i) {
    if (i == _tab) return;
    setState(() => _tab = i);
    _swap.forward(from: 0);
  }

  void _goTab(int i) {
    // Slot 3 is the hamburger — it opens the menu instead of swapping screens.
    if (i == 3) {
      _openMore();
      return;
    }
    _setTab(i);
  }

  // Chats and the assistant live inside the shell (slots 4 and 5) rather than
  // over it, so the tab bar stays visible and they need no back button —
  // you leave them by tapping another tab.
  void _openChats() => _setTab(4);

  void _openAi() => _setTab(5);

  void _openSatellite() => _setTab(6);

  void _newScan() => showGwSheet(
        context,
        (sheetContext) => BatchSetupScreen(
          onDone: () => Navigator.of(sheetContext).pop(),
          // Close the sheet before the camera pushes, otherwise the rest of the
          // scan flow would run on top of an orphaned sheet route.
          onContinue: () {
            Navigator.of(sheetContext).pop();
            context.push('/main/camera');
          },
        ),
        heightFactor: 0.72,
      );

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
                  _openChats();
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
                  _openAi();
                },
              ),
              const SizedBox(height: 8),
              _moreRow(
                gw,
                icon: GwIcons.satellite,
                label: 'Satellite',
                detail: 'Nearest place to take this waste',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openSatellite();
                },
              ),
              const SizedBox(height: 8),
              _moreRow(
                gw,
                icon: GwIcons.user,
                label: 'Account',
                detail: 'Profile, preferences and data',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _setTab(3);
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
            child: AnimatedBuilder(
              animation: _swap,
              builder: (_, child) {
                final t = Curves.easeOut.transform(_swap.value);
                return Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, 6 * (1 - t)),
                    child: child,
                  ),
                );
              },
              // Built once and reused across frames — an IndexedStack keeps
              // every tab alive, so scroll positions survive the swap.
              child: IndexedStack(
                index: _tab,
                children: [
                  IosHomeScreen(
                    sessions: _sessions,
                    onNewScan: _newScan,
                    onSeeAllScans: () => _goTab(1),
                    onOpenAnalytics: () => _goTab(2),
                    onOpenChats: _openChats,
                    onOpenAi: _openAi,
                  ),
                  IosScansScreen(
                    sessions: _sessions,
                    onNewScan: _newScan,
                  ),
                  IosAnalyticsScreen(sessions: _sessions),
                  const IosAccountScreen(),
                  const IosChatsList(showBack: false),
                  const IosAiChatScreen(showBack: false),
                  IosSatelliteScreen(showBack: false, sessions: _sessions),
                ],
              ),
            ),
          ),
          // Hidden while the keyboard is up, otherwise it would sit behind it
          // and steal room from the chat composers.
          if (MediaQuery.of(context).viewInsets.bottom == 0)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GwTabBar(
              // Account, Chats and the assistant are all reached through the
              // hamburger, so slot 3 stays lit for all three.
              currentIndex: _tab >= 3 ? 3 : _tab,
              onTap: _goTab,
              onCenterTap: _newScan,
            ),
          ),
        ]),
      ),
    );
  }
}
