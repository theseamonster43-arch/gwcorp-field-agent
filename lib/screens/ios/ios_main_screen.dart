import 'package:cached_network_image/cached_network_image.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/history_repository.dart';
import '../../data/models.dart';
import '../../theme/gw_theme.dart';
import '../dashboard_screen.dart';
import '../chats_screen.dart';
import '../account_screen.dart';
import '../ai_chat_screen.dart';

class IosMainScreen extends StatefulWidget {
  const IosMainScreen({super.key});
  @override
  State<IosMainScreen> createState() => _IosMainScreenState();
}

class _IosMainScreenState extends State<IosMainScreen> {
  int _tab = 0;
  bool _drawerOpen = false;
  List<ScanSession> _sessions = [];
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    FirebaseAuth.instance.authStateChanges().listen((u) {
      if (mounted) setState(() => _user = u);
    });
    HistoryRepository.sessionsStream().listen((s) {
      if (mounted) setState(() => _sessions = s);
    });
  }

  Widget _tab_(IconData icon, String? label, int index) {
    final sel = _tab == index;
    const green = Color(0xFF22C55E);
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 20, color: sel ? green : Colors.grey),
          if (label != null) ...[
            const SizedBox(height: 2),
            Text(label,
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  color: sel ? green : Colors.grey,
                )),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    return Scaffold(
      body: Stack(children: [
        IndexedStack(
          index: _tab,
          children: [
            DashboardScreen(
              onMenuClick: () => setState(() => _drawerOpen = true),
              sessionCount: _sessions.length,
              onViewChats: () => setState(() => _tab = 1),
            ),
            ChatsScreen(onNavigate: (p) => context.push(p)),
            AccountScreen(onNavigate: (p) => context.push(p)),
            AiChatScreen(onMenuClick: () => setState(() => _drawerOpen = true)),
          ],
        ),
        // Backdrop
        IgnorePointer(
          ignoring: !_drawerOpen,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 280),
            opacity: _drawerOpen ? 1.0 : 0.0,
            child: GestureDetector(
              onTap: () => setState(() => _drawerOpen = false),
              child: Container(color: Colors.black54),
            ),
          ),
        ),
        // Sliding drawer
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          left: _drawerOpen ? 0 : -292,
          top: 0, bottom: 0, width: 288,
          child: Container(
            decoration: BoxDecoration(
              color: gw.bg2,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 24, offset: const Offset(4, 0))],
            ),
            child: SafeArea(
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: gw.green, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text('SCAN HISTORY', style: TextStyle(color: gw.text, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: -0.3))),
                    GestureDetector(
                      onTap: () => setState(() => _drawerOpen = false),
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(color: gw.bg3, borderRadius: BorderRadius.circular(8), border: Border.all(color: gw.border)),
                        child: Icon(Icons.close, size: 16, color: gw.muted),
                      ),
                    ),
                  ]),
                ),
                Divider(color: gw.border, height: 1),
                if (_sessions.isEmpty)
                  Expanded(child: Center(child: Text('No scans yet', style: TextStyle(color: gw.muted, fontSize: 12))))
                else
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: _sessions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (_, i) {
                        final s = _sessions[i];
                        final accent = s.hazardCount > 0 ? gw.amber : gw.green;
                        return GestureDetector(
                          onTap: () { setState(() => _drawerOpen = false); context.push('/main/session/${s.id}'); },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: gw.bg3, borderRadius: BorderRadius.circular(10), border: Border.all(color: accent.withOpacity(0.2))),
                            child: Text(s.location, style: TextStyle(color: gw.text, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        );
                      },
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ]),
      bottomNavigationBar: Container(
        color: Colors.transparent,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8, top: 4),
            child: LiquidGlassContainer(
              config: LiquidGlassConfig(effect: CNGlassEffect.regular, cornerRadius: 20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                child: Row(children: [
                  _tab_(Icons.qr_code_scanner_outlined, 'Scans',   0),
                  _tab_(Icons.forum_outlined,           'Chats',   1),
                  _tab_(Icons.account_circle_outlined,  'Account', 2),
                  _tab_(Icons.auto_awesome_outlined,    null,      3),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
