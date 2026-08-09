import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/history_repository.dart';
import '../../data/models.dart';
import '../../theme/gw_theme.dart';
import '../../widgets/desktop_chrome.dart';
import '../../widgets/gw_glass.dart';
import '../../widgets/gw_icons.dart';
import '../ios/ios_home_screen.dart';
import '../ios/ios_scans_screen.dart';
import '../ios/ios_analytics_screen.dart';
import '../ios/ios_chats_screen.dart';
import '../ios/ios_ai_chat_screen.dart';
import '../ios/ios_account_screen.dart';

/// Desktop layout: the web app's left icon rail and nothing else. The window
/// title bar is supplied globally from main.dart, so there is no nav strip
/// here — Account sits at the foot of the rail and carries the log-out.
class DesktopShell extends StatefulWidget {
  const DesktopShell({super.key});
  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell>
    with SingleTickerProviderStateMixin {
  static const _maxContentWidth = 1040.0;

  /// 0 Home · 1 Scans · 2 Stats · 3 Chats · 4 AI · 5 Account
  int _tab = 0;
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
    desktopTabRequest.addListener(_onTabRequest);
  }

  /// The title bar sits above the router and cannot push a route, so it raises
  /// a tab request instead — that is how its avatar opens Account.
  void _onTabRequest() {
    final want = desktopTabRequest.value;
    if (want < 0) return;
    desktopTabRequest.value = -1; // clear before switching, so it fires once
    if (mounted) _goTab(want);
  }

  @override
  void dispose() {
    desktopTabRequest.removeListener(_onTabRequest);
    _page.dispose();
    _sessionSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  void _goTab(int i) {
    if (i == _tab) return;
    setState(() => _tab = i);
    _page.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GwScreenBg(
        child: Row(children: [
          _rail(),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxContentWidth),
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
                  // Built once and reused across frames — IndexedStack keeps
                  // every tab alive, so scroll offsets and Firestore listeners
                  // survive switching.
                  child: IndexedStack(
                      index: _tab,
                      children: [
                        IosHomeScreen(
                          sessions: _sessions,
                          onNewScan: () => context.push('/main/batch'),
                          onSeeAllScans: () => _goTab(1),
                          onOpenAnalytics: () => _goTab(2),
                          onOpenChats: () => _goTab(3),
                          onOpenAi: () => _goTab(4),
                        ),
                        IosScansScreen(
                          sessions: _sessions,
                          onNewScan: () => context.push('/main/batch'),
                        ),
                        IosAnalyticsScreen(sessions: _sessions),
                        const IosChatsList(showBack: false),
                        const IosAiChatScreen(showBack: false),
                        const IosAccountScreen(),
                      ],
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Left rail — mirrors the site's .gw-rail ──────────────────────────────
  Widget _rail() {
    final gw = GwTheme.of(context);
    return Container(
      width: 74,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: gw.border)),
      ),
      child: Column(children: [
        _RailNewButton(onTap: () => context.push('/main/batch')),
        const SizedBox(height: 20),
        _railBtn(0, GwIcons.home, 'Home'),
        _railBtn(1, GwIcons.scan, 'Scans'),
        _railBtn(2, GwIcons.chart, 'Stats'),
        _railBtn(3, GwIcons.chat, 'Chats'),
        _railBtn(4, GwIcons.sparkle, 'AI'),
        const Spacer(),
        Divider(color: gw.border, height: 1, indent: 14, endIndent: 14),
        const SizedBox(height: 10),
        _railBtn(5, GwIcons.user, 'Account'),
      ]),
    );
  }

  Widget _railBtn(int index, String icon, String label) {
    final gw = GwTheme.of(context);
    final selected = _tab == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _goTab(index),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: selected ? 1 : 0),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutBack,
          builder: (context, t, _) {
            // easeOutBack overshoots past 1 — clamp anything colour-related.
            final c = t.clamp(0.0, 1.0);
            final tint = Color.lerp(gw.muted, gw.green, c);
            return Container(
              width: 54,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: gw.green.withOpacity(.14 * c),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(children: [
                Transform.translate(
                  offset: Offset(0, -2 * t),
                  child: Transform.scale(
                    scale: 1 + .16 * t,
                    child: GwIcon(icon, size: 20, color: tint),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: tint,
                    fontSize: 10,
                    height: 1,
                    fontWeight: FontWeight.lerp(
                        FontWeight.w600, FontWeight.w800, c),
                  ),
                ),
              ]),
            );
          },
        ),
      ),
    );
  }
}

/// The rail's big green "new batch" circle.
class _RailNewButton extends StatefulWidget {
  final VoidCallback onTap;
  const _RailNewButton({required this.onTap});
  @override
  State<_RailNewButton> createState() => _RailNewButtonState();
}

class _RailNewButtonState extends State<_RailNewButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutBack,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [const Color(0xFF4ADE80), gw.green, gw.greenDim],
            ),
            boxShadow: [
              BoxShadow(
                color: gw.green.withOpacity(.50),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const GwIcon(GwIcons.plus, size: 22,
              color: Colors.white, strokeWidth: 2.4),
        ),
      ),
    );
  }
}
