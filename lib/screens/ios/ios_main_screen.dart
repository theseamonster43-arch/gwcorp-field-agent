import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/history_repository.dart';
import '../../data/models.dart';
import '../../theme/gw_theme.dart';
import 'ios_dashboard_screen.dart';
import 'ios_chats_screen.dart';
import 'ios_account_screen.dart';
import 'ios_ai_chat_screen.dart';

class IosMainScreen extends StatefulWidget {
  const IosMainScreen({super.key});
  @override
  State<IosMainScreen> createState() => _IosMainScreenState();
}

class _IosMainScreenState extends State<IosMainScreen> {
  int _tab = 0;
  bool _drawerOpen = false;
  List<ScanSession> _sessions = [];

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen((_) {
      if (mounted) setState(() {});
    });
    HistoryRepository.sessionsStream().listen((s) {
      if (mounted) setState(() => _sessions = s);
    });
  }

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    return Scaffold(
      body: Stack(children: [
        IndexedStack(
          index: _tab,
          children: [
            IosDashboardScreen(
              onMenuClick: () => setState(() => _drawerOpen = true),
              sessionCount: _sessions.length,
              onViewChats: () => setState(() => _tab = 1),
            ),
            const IosChatsList(),
            const IosAccountScreen(),
            IosAiChatScreen(
              onMenuClick: () => setState(() => _drawerOpen = true),
            ),
          ],
        ),

        // Backdrop
        IgnorePointer(
          ignoring: !_drawerOpen,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 260),
            opacity: _drawerOpen ? 1.0 : 0.0,
            child: GestureDetector(
              onTap: () => setState(() => _drawerOpen = false),
              child: Container(color: Colors.black54),
            ),
          ),
        ),

        // Sliding scan history drawer
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          left: _drawerOpen ? 0 : -292,
          top: 0, bottom: 0, width: 288,
          child: Container(
            decoration: BoxDecoration(
              color: gw.bg2,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 24,
                  offset: const Offset(4, 0),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(children: [
                    Container(width: 6, height: 6,
                        decoration: BoxDecoration(color: gw.green, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('SCAN HISTORY',
                          style: TextStyle(color: gw.text, fontSize: 13,
                              fontWeight: FontWeight.w900, letterSpacing: -0.3)),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _drawerOpen = false),
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          color: gw.bg3,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: gw.border),
                        ),
                        child: Icon(Icons.close, size: 16, color: gw.muted),
                      ),
                    ),
                  ]),
                ),
                Divider(color: gw.border, height: 1),
                if (_sessions.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text('No scans yet',
                          style: TextStyle(color: gw.muted, fontSize: 12)),
                    ),
                  )
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
                          onTap: () {
                            setState(() => _drawerOpen = false);
                            context.push('/main/session/${s.id}');
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: gw.bg3,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: accent.withOpacity(0.2)),
                            ),
                            child: Text(s.location,
                                style: TextStyle(color: gw.text, fontSize: 12,
                                    fontWeight: FontWeight.w600)),
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

      bottomNavigationBar: CNTabBar(
        items: [
          CNTabBarItem(label: 'Scans',   icon: CNSymbol('qrcode.viewfinder')),
          CNTabBarItem(label: 'Chats',   icon: CNSymbol('bubble.left.and.bubble.right')),
          CNTabBarItem(label: 'Account', icon: CNSymbol('person.crop.circle')),
          CNTabBarItem(label: 'AI',      icon: CNSymbol('sparkles')),
        ],
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}
