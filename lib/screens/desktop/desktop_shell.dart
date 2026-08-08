import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
import '../ios/ios_account_screen.dart';

/// Desktop layout, laid out to match the web app at
/// GWCORP_IHS/public/field-agent.html: a top nav strip, the left icon rail
/// (new-batch circle, Home, Scans, Stats, Chats) and a centred content column.
/// The screens themselves are shared with the phone build — only the chrome
/// around them differs.
class DesktopShell extends StatefulWidget {
  const DesktopShell({super.key});
  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  static const _maxContentWidth = 1040.0;

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

  Future<void> _logout() async {
    try { await GoogleSignIn().signOut(); } catch (_) {}
    await FirebaseAuth.instance.signOut();
    if (mounted) context.go('/signin');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GwScreenBg(
        child: Column(children: [
          if (isDesktop) const DesktopTitleBar(),
          _nav(),
          Expanded(
            child: Row(children: [
              _rail(),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _maxContentWidth),
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
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Top nav — mirrors the site's <nav> ───────────────────────────────────
  Widget _nav() {
    final gw = GwTheme.of(context);
    final me = FirebaseAuth.instance.currentUser;
    final name = me?.displayName?.trim().isNotEmpty == true
        ? me!.displayName!.trim()
        : (me?.email?.split('@').first ?? 'Agent');
    final photo = me?.photoURL;

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: gw.bg2.withOpacity(.72),
        border: Border(bottom: BorderSide(color: gw.border)),
      ),
      child: Row(children: [
        const _PulseDot(),
        const SizedBox(width: 9),
        Text(
          'GWCORP',
          style: TextStyle(
            color: gw.text,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: gw.green.withOpacity(.35)),
          ),
          child: Text(
            'FIELD AGENT',
            style: TextStyle(
              color: gw.green,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),
        const Spacer(),
        // Avatar opens Account, mirroring the web nav — the rail has no slot
        // for it, same as the site.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _goTab(4),
          child: photo != null && photo.isNotEmpty
              ? CircleAvatar(radius: 15, backgroundImage: NetworkImage(photo))
              : Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: gw.green.withOpacity(.15),
                    border: Border.all(color: gw.green.withOpacity(.35)),
                  ),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: gw.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 9),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: gw.text,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        _GhostButton(label: 'Log Out', onTap: _logout),
      ]),
    );
  }

  // ── Left rail — mirrors the site's .gw-rail ──────────────────────────────
  Widget _rail() {
    final gw = GwTheme.of(context);
    return Container(
      width: 74,
      padding: const EdgeInsets.only(top: 14),
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 54,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? gw.green.withOpacity(.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            GwIcon(icon, size: 20, color: selected ? gw.green : gw.muted),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: selected ? gw.green : gw.muted,
                fontSize: 10,
                height: 1,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ]),
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

/// The site's pulsing green status dot.
class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: .35).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: gw.green,
          boxShadow: [BoxShadow(color: gw.green.withOpacity(.7), blurRadius: 8)],
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GhostButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: gw.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: gw.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
