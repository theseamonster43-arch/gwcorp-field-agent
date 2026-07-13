import 'dart:io' show Platform;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/models.dart';
import '../data/history_repository.dart';
import '../theme/gw_theme.dart';
import '../widgets/desktop_chrome.dart';
import 'dashboard_screen.dart';
import 'chats_screen.dart' show ChatListPanel, ChatsScreen, CommunityChatPanel;
import 'account_screen.dart';
import 'ai_chat_screen.dart';
import 'batch_setup_screen.dart';
import 'camera_screen.dart';
import 'results_screen.dart';
import 'session_detail_screen.dart';
import 'direct_chat_detail_screen.dart';
import 'new_direct_chat_screen.dart';

const _tabScans   = 0;
const _tabChats   = 1;
const _tabAccount = 2;
const _tabAi      = 3;

enum _ScanPanel { none, batch, camera, results }

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _tab = _tabScans;
  List<ScanSession> _sessions = [];
  DirectChat? _selectedChat;
  bool _showNewChat = false;
  bool _drawerOpen  = false;
  _ScanPanel _scanPanel = _ScanPanel.none;
  String? _selectedSessionId;
  int _chatRightTab = 0;
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

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  Widget build(BuildContext context) {
    final gw     = GwTheme.of(context);
    final me     = _user;
    final isWide = MediaQuery.of(context).size.width >= 600;

    if (_isDesktop) return _desktopLayout(context, gw, me);
    if (isWide)     return _tabletLayout(context, gw, me);
    return _phoneLayout(context, gw, me);
  }

  // ── Desktop ──────────────────────────────────────────────────────────────────

  Widget _desktopLayout(BuildContext ctx, GwColors gw, User? me) => Scaffold(
        backgroundColor: gw.bg,
        body: Column(children: [
          // Custom title bar (desktop only)
          if (_isDesktop) const DesktopTitleBar(),
          // Main content row
          Expanded(
            child: Row(children: [
              // Left rail (vertical nav)
              _LeftRail(
                selected: _tab,
                photoUrl: me?.photoURL,
                onSelect: (t) => setState(() {
                  _tab = t; _selectedChat = null; _showNewChat = false;
                  _scanPanel = _ScanPanel.none; _selectedSessionId = null;
                }),
                gw: gw,
              ),
              VerticalDivider(color: gw.border, width: 1),
              // Left panel (scan history / chat list)
              SizedBox(
                width: 300,
                child: Container(
                  color: gw.bg2,
                  child: _tab == _tabChats
                      ? ChatListPanel(
                          myEmail: me?.email ?? '',
                          selectedChatId: _selectedChat?.id,
                          onSelectChat: (c) => setState(() {
                            _selectedChat = c; _showNewChat = false;
                          }),
                          onNewChat: () => setState(() {
                            _showNewChat = true; _selectedChat = null;
                          }),
                        )
                      : _DrawerContent(
                          sessions: _sessions,
                          onTapSession: (id) => setState(() {
                            _selectedSessionId = id;
                            _scanPanel = _ScanPanel.none;
                            _tab = _tabScans;
                          }),
                        ),
                ),
              ),
              VerticalDivider(color: gw.border, width: 1),
              // Right panel (main content)
              Expanded(child: _desktopRightPanel(ctx, me)),
            ]),
          ),
        ]),
      );

  Widget _desktopRightPanel(BuildContext ctx, User? me) {
    if (_tab == _tabChats) return _inlineChatPanel(ctx);
    if (_tab == _tabScans) return _inlineScanPanel();
    if (_tab == _tabAccount) return AccountScreen(onNavigate: (p) => ctx.push(p));
    return AiChatScreen(onMenuClick: () {});
  }

  Widget _inlineChatPanel(BuildContext ctx) {
    final gw = GwTheme.of(ctx);
    if (_showNewChat) {
      return NewDirectChatScreen(
        onDismiss: (_) => setState(() => _showNewChat = false),
        onChatCreated: (_, chatId, chat) =>
            setState(() { _selectedChat = chat; _showNewChat = false; }),
      );
    }
    return Column(children: [
      // Tab bar
      Container(
        color: gw.bg2,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          _chatTab(gw, 'Direct', 0),
          const SizedBox(width: 8),
          _chatTab(gw, 'Community', 1),
        ]),
      ),
      Divider(color: gw.border, height: 1),
      Expanded(
        child: _chatRightTab == 1
            ? const CommunityChatPanel()
            : _selectedChat != null
                ? DirectChatDetailScreen(chatId: _selectedChat!.id, chat: _selectedChat)
                : Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.forum_outlined, size: 48, color: gw.muted.withOpacity(0.3)),
                    const SizedBox(height: 12),
                    Text('Select a chat to show here',
                        style: TextStyle(color: gw.muted, fontSize: 14)),
                  ])),
      ),
    ]);
  }

  Widget _chatTab(GwColors gw, String label, int i) {
    final sel = _chatRightTab == i;
    return GestureDetector(
      onTap: () => setState(() { _chatRightTab = i; if (i == 1) _selectedChat = null; }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? gw.greenGlow : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: sel ? gw.green.withOpacity(0.35) : gw.border),
        ),
        child: Text(label, style: TextStyle(
          color: sel ? gw.green : gw.muted, fontSize: 12,
          fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }

  Widget _inlineScanPanel() {
    if (_selectedSessionId != null) {
      return SessionDetailScreen(
        sessionId: _selectedSessionId!,
        onBack: () => setState(() => _selectedSessionId = null),
      );
    }
    switch (_scanPanel) {
      case _ScanPanel.batch:
        return BatchSetupScreen(
          onDone: () => setState(() => _scanPanel = _ScanPanel.none),
          onContinue: () => setState(() => _scanPanel = _ScanPanel.camera),
        );
      case _ScanPanel.camera:
        return CameraScreen(
          onBack: () => setState(() => _scanPanel = _ScanPanel.batch),
          onContinue: () => setState(() => _scanPanel = _ScanPanel.results),
        );
      case _ScanPanel.results:
        return ResultsScreen(
          onBack: () => setState(() => _scanPanel = _ScanPanel.camera),
          onDone: () => setState(() => _scanPanel = _ScanPanel.none),
        );
      case _ScanPanel.none:
        return DashboardScreen(
          onMenuClick: () {}, onViewChats: () => setState(() => _tab = _tabChats),
          sessionCount: _sessions.length,
          onSettingsClick: () => setState(() => _tab = _tabAccount),
          onNewBatch: () => setState(() { _scanPanel = _ScanPanel.batch; _selectedSessionId = null; }),
        );
    }
  }

  // ── Tablet ───────────────────────────────────────────────────────────────────

  Widget _tabletLayout(BuildContext ctx, GwColors gw, User? me) => Scaffold(
        backgroundColor: gw.bg,
        body: Row(children: [
          // Left panel: scan history / chat list + pill nav
          SizedBox(
            width: 380,
            child: Container(
              color: gw.bg2,
              child: Column(children: [
                Expanded(
                  child: _tab == _tabChats
                      ? ChatListPanel(
                          myEmail: me?.email ?? '',
                          selectedChatId: _selectedChat?.id,
                          onSelectChat: (c) => setState(() {
                            _selectedChat = c; _showNewChat = false;
                          }),
                          onNewChat: () => setState(() {
                            _showNewChat = true; _selectedChat = null;
                          }),
                        )
                      : _DrawerContent(
                          sessions: _sessions,
                          onTapSession: (id) => setState(() {
                            _selectedSessionId = id;
                            _scanPanel = _ScanPanel.none;
                            _tab = _tabScans;
                          }),
                        ),
                ),
                Divider(color: gw.border, height: 1),
                _BottomNav(
                  selected: _tab,
                  photoUrl: me?.photoURL,
                  onSelect: (t) => setState(() {
                    _tab = t; _selectedChat = null; _showNewChat = false;
                    _scanPanel = _ScanPanel.none;
                  }),
                ),
              ]),
            ),
          ),
          VerticalDivider(color: gw.border, width: 1),
          // Right panel
          Expanded(child: _tabletRightPanel(ctx, me)),
        ]),
      );

  Widget _tabletRightPanel(BuildContext ctx, User? me) {
    if (_tab == _tabChats) return _inlineChatPanel(ctx);
    if (_tab == _tabScans) return _inlineScanPanel();
    if (_tab == _tabAccount) return AccountScreen(onNavigate: (p) => ctx.push(p));
    return AiChatScreen(onMenuClick: () {});
  }

  // ── Phone ────────────────────────────────────────────────────────────────────

  Widget _phoneLayout(BuildContext ctx, GwColors gw, User? me) => Scaffold(
        backgroundColor: gw.bg,
        body: Stack(children: [
          Column(children: [
            Expanded(child: _phoneBody(ctx)),
            _BottomNav(
              selected: _tab,
              photoUrl: me?.photoURL,
              onSelect: (t) => setState(() { _tab = t; _scanPanel = _ScanPanel.none; _selectedSessionId = null; }),
            ),
          ]),
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
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.18),
                      blurRadius: 24, offset: const Offset(4, 0)),
                ],
              ),
              child: _DrawerContent(
                sessions: _sessions,
                onClose: () => setState(() => _drawerOpen = false),
                onTapSession: (id) {
                  setState(() => _drawerOpen = false);
                  ctx.push('/main/session/$id');
                },
              ),
            ),
          ),
        ]),
      );

  Widget _phoneBody(BuildContext ctx) {
    switch (_tab) {
      case _tabScans:
        return DashboardScreen(
          onMenuClick:    () => setState(() => _drawerOpen = true),
          onViewChats:    () => setState(() => _tab = _tabChats),
          onSettingsClick: () => setState(() => _tab = _tabAccount),
          sessionCount:   _sessions.length,
        );
      case _tabChats:
        return ChatsScreen(onNavigate: (p) => ctx.push(p));
      case _tabAccount:
        return AccountScreen(onNavigate: (p) => ctx.push(p));
      default:
        return AiChatScreen(onMenuClick: () => setState(() => _drawerOpen = true));
    }
  }
}

// ── Desktop left rail ─────────────────────────────────────────────────────────

class _LeftRail extends StatelessWidget {
  final int selected;
  final String? photoUrl;
  final ValueChanged<int> onSelect;
  final GwColors gw;
  const _LeftRail({required this.selected, this.photoUrl,
      required this.onSelect, required this.gw});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      color: gw.bg2,
      child: Column(children: [
        const SizedBox(height: 12),
        _RailItem(icon: Icons.qr_code_scanner_outlined, label: 'Scans',
            selected: selected == _tabScans, onTap: () => onSelect(_tabScans), gw: gw),
        _RailItem(icon: Icons.forum_outlined, label: 'Chats',
            selected: selected == _tabChats, onTap: () => onSelect(_tabChats), gw: gw),
        _RailItem(icon: Icons.account_circle_outlined, label: 'Account',
            selected: selected == _tabAccount, onTap: () => onSelect(_tabAccount),
            photoUrl: photoUrl, gw: gw),
        const Spacer(),
        _RailItem(icon: Icons.auto_awesome_outlined, label: 'AI',
            selected: selected == _tabAi, onTap: () => onSelect(_tabAi), gw: gw),
        const SizedBox(height: 16),
      ]),
    );
  }
}

class _RailItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final GwColors gw;
  final String? photoUrl;
  const _RailItem({required this.icon, required this.label,
      required this.selected, required this.onTap, required this.gw, this.photoUrl});
  @override
  State<_RailItem> createState() => _RailItemState();
}

class _RailItemState extends State<_RailItem> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final color = widget.selected ? widget.gw.green : widget.gw.muted;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 64,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: _hover ? widget.gw.bg3 : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: widget.selected ? widget.gw.green : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Column(children: [
            if (widget.photoUrl != null && widget.photoUrl!.isNotEmpty && widget.label == 'Account')
              CircleAvatar(radius: 12, backgroundImage: NetworkImage(widget.photoUrl!))
            else
              Icon(widget.icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(widget.label,
                style: TextStyle(color: color, fontSize: 9,
                    fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}

// ── Bottom Nav pill ───────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int selected;
  final String? photoUrl;
  final ValueChanged<int> onSelect;

  const _BottomNav({required this.selected, this.photoUrl, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    final isAi = selected == _tabAi;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.transparent, gw.bg2.withOpacity(0.98)],
        ),
      ),
      padding: EdgeInsets.only(
        left: 10, right: 10, top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: _SlidingPill(
              selected: selected,
              photoUrl: photoUrl,
              onSelect: onSelect,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => onSelect(_tabAi),
            child: Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: gw.bg3,
                border: Border.all(
                  color: isAi ? gw.green.withOpacity(0.65) : gw.border,
                  width: isAi ? 1.5 : 1,
                ),
              ),
              child: Icon(Icons.auto_awesome_outlined,
                  size: 22, color: isAi ? gw.green : gw.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlidingPill extends StatefulWidget {
  final int selected;
  final String? photoUrl;
  final ValueChanged<int> onSelect;
  const _SlidingPill({required this.selected, this.photoUrl, required this.onSelect});
  @override
  State<_SlidingPill> createState() => _SlidingPillState();
}

class _SlidingPillState extends State<_SlidingPill> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  double _dragStart = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _anim = _ctrl.drive(CurveTween(curve: Curves.easeOutBack));
    _syncAnim(widget.selected, animate: false);
  }

  @override
  void didUpdateWidget(_SlidingPill old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) _syncAnim(widget.selected);
  }

  void _syncAnim(int tab, {bool animate = true}) {
    final target = tab == _tabScans ? 0.0 : tab == _tabChats ? 1.0 : tab == _tabAccount ? 2.0 : -1.0;
    if (target < 0) { _ctrl.value = _ctrl.value; return; }
    final tween = Tween(begin: (_anim.value * 2).clamp(0.0, 2.0), end: target);
    _anim = _ctrl.drive(tween.chain(CurveTween(curve: Curves.easeOutBack)));
    if (animate) _ctrl.forward(from: 0); else _ctrl.value = 1;
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    final showIndicator = widget.selected != _tabAi;

    return GestureDetector(
      onHorizontalDragStart: (d) => _dragStart = d.localPosition.dx,
      onHorizontalDragEnd: (d) {
        final delta = d.localPosition.dx - _dragStart;
        if (delta < -40) {
          if (widget.selected == _tabScans)   widget.onSelect(_tabChats);
          else if (widget.selected == _tabChats) widget.onSelect(_tabAccount);
        } else if (delta > 40) {
          if (widget.selected == _tabAccount) widget.onSelect(_tabChats);
          else if (widget.selected == _tabChats) widget.onSelect(_tabScans);
        }
      },
      child: AnimatedBuilder(
        animation: _anim,
        builder: (ctx, _) {
          return LayoutBuilder(builder: (ctx, constraints) {
            final third = constraints.maxWidth / 3;
            final fraction = showIndicator ? _anim.value : 0.0;
            return Container(
              decoration: BoxDecoration(
                color: gw.bg3.withOpacity(0.95),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: gw.border),
              ),
              padding: const EdgeInsets.all(3),
              child: Stack(
                children: [
                  // Sliding indicator
                  if (showIndicator)
                    Positioned(
                      left: third * fraction + third * 0.06,
                      top: 4, bottom: 4,
                      width: third * 0.88,
                      child: Container(
                        decoration: BoxDecoration(
                          color: gw.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: gw.green.withOpacity(0.2)),
                        ),
                      ),
                    ),
                  // Tabs row
                  Row(children: [
                    _PillTab(
                      icon: Icons.qr_code_scanner_outlined,
                      label: 'Scans',
                      selected: widget.selected == _tabScans,
                      onTap: () => widget.onSelect(_tabScans),
                    ),
                    _PillTab(
                      icon: Icons.forum_outlined,
                      label: 'Chats',
                      selected: widget.selected == _tabChats,
                      onTap: () => widget.onSelect(_tabChats),
                    ),
                    _PillTab(
                      icon: Icons.account_circle_outlined,
                      label: 'Account',
                      selected: widget.selected == _tabAccount,
                      photoUrl: widget.photoUrl,
                      onTap: () => widget.onSelect(_tabAccount),
                    ),
                  ]),
                ],
              ),
            );
          });
        },
      ),
    );
  }
}

class _PillTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final String? photoUrl;
  final VoidCallback onTap;
  const _PillTab({required this.icon, required this.label, required this.selected,
      this.photoUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (photoUrl != null && photoUrl!.isNotEmpty && label == 'Account')
                CircleAvatar(
                  radius: 13,
                  backgroundImage: NetworkImage(photoUrl!),
                )
              else
                Icon(icon, size: 26, color: selected ? gw.green : gw.muted),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? gw.green : gw.muted,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Drawer content (scan history) ─────────────────────────────────────────────

class _DrawerContent extends StatelessWidget {
  final List<ScanSession> sessions;
  final VoidCallback? onClose;
  final ValueChanged<String> onTapSession;
  const _DrawerContent({required this.sessions, this.onClose, required this.onTapSession});

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(children: [
            Container(width: 6, height: 6,
                decoration: BoxDecoration(color: gw.green, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text('SCAN HISTORY',
                style: TextStyle(color: gw.text, fontSize: 13,
                    fontWeight: FontWeight.w900, letterSpacing: -0.3))),
            if (sessions.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: gw.greenGlow,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: gw.border),
                ),
                child: Text('${sessions.length}',
                    style: TextStyle(color: gw.green, fontSize: 9, fontWeight: FontWeight.w700)),
              ),
            if (onClose != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: gw.bg3, borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: gw.border),
                  ),
                  child: Icon(Icons.close, size: 16, color: gw.muted),
                ),
              ),
            ],
          ]),
        ),
        Divider(color: gw.border, height: 1),
        if (sessions.isEmpty)
          Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('◇', style: TextStyle(fontSize: 28, color: gw.muted)),
            const SizedBox(height: 8),
            Text('No scans yet', style: TextStyle(color: gw.text, fontSize: 12, fontWeight: FontWeight.w600)),
          ])))
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: sessions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (_, i) {
                final s = sessions[i];
                final accent = s.hazardCount > 0 ? gw.amber : gw.green;
                final thumb = s.imageUrls.isNotEmpty ? s.imageUrls.first : null;
                return GestureDetector(
                  onTap: () => onTapSession(s.id),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: gw.bg3,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accent.withOpacity(0.2)),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(width: 5, height: 5,
                                decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(s.id, style: TextStyle(color: accent, fontSize: 9,
                                fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                          ]),
                          const SizedBox(height: 3),
                          Text(s.location, style: TextStyle(color: gw.text, fontSize: 12,
                              fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Row(children: [
                            _chip(gw, '${s.itemCount} items', gw.muted),
                            const SizedBox(width: 6),
                            if (s.hazardCount > 0) _chip(gw, '${s.hazardCount} hazards', gw.amber),
                          ]),
                        ]),
                      ),
                      if (thumb != null) ...[
                        const SizedBox(width: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: CachedNetworkImage(
                            imageUrl: thumb,
                            width: 52, height: 52,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              width: 52, height: 52, color: gw.bg2,
                              child: Icon(Icons.image_outlined, color: gw.muted, size: 20),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              width: 52, height: 52, color: gw.bg2,
                              child: Icon(Icons.image_outlined, color: gw.muted, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ]),
                  ),
                );
              },
            ),
          ),
      ]),
    );
  }

  Widget _chip(GwColors gw, String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(99),
      border: Border.all(color: c.withOpacity(0.2)),
    ),
    child: Text(t, style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w600)),
  );
}
