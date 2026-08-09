import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';
import '../theme/gw_theme.dart';

bool get isDesktop =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

class DesktopTitleBar extends StatefulWidget {
  const DesktopTitleBar({super.key});
  @override
  State<DesktopTitleBar> createState() => _DesktopTitleBarState();
}

class _DesktopTitleBarState extends State<DesktopTitleBar> with WindowListener {
  bool _isMaximized = false;
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkMaximized();
    // The bar renders above the router and never rebuilds on navigation, so
    // without this the avatar would stay missing after signing in.
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _checkMaximized() async {
    final m = await windowManager.isMaximized();
    if (mounted) setState(() => _isMaximized = m);
  }

  @override
  void onWindowMaximize()   { if (mounted) setState(() => _isMaximized = true); }
  @override
  void onWindowUnmaximize() { if (mounted) setState(() => _isMaximized = false); }

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) return const SizedBox.shrink();
    final gw = GwTheme.of(context);
    final photo = FirebaseAuth.instance.currentUser?.photoURL;

    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: gw.bg2,
        border: Border(bottom: BorderSide(color: gw.border)),
      ),
      child: Row(children: [
        Expanded(
          child: DragToMoveArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(children: [
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    color: gw.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: gw.green.withOpacity(.7), blurRadius: 8),
                    ],
                  ),
                ),
                const SizedBox(width: 9),
                Text('GWCORP',
                    style: GoogleFonts.dmSans(
                        color: gw.text, fontSize: 15,
                        fontWeight: FontWeight.w800, letterSpacing: -0.2,
                        decoration: TextDecoration.none)),
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: gw.green.withOpacity(.35)),
                  ),
                  child: Text('FIELD AGENT',
                      style: GoogleFonts.dmSans(
                          color: gw.green, fontSize: 10,
                          fontWeight: FontWeight.w700, letterSpacing: 1.1,
                          decoration: TextDecoration.none)),
                ),
              ]),
            ),
          ),
        ),
        if (photo != null && photo.isNotEmpty) ...[
          CircleAvatar(radius: 13, backgroundImage: NetworkImage(photo)),
          const SizedBox(width: 14),
        ],
        _Win11Btn(
          type: _BtnType.minimize,
          onTap: () => windowManager.minimize(),
          gw: gw,
        ),
        _Win11Btn(
          type: _isMaximized ? _BtnType.restore : _BtnType.maximize,
          onTap: () {
            if (_isMaximized) windowManager.unmaximize();
            else windowManager.maximize();
          },
          gw: gw,
        ),
        _Win11Btn(
          type: _BtnType.close,
          onTap: () => windowManager.close(),
          gw: gw,
        ),
      ]),
    );
  }
}

// ── Button types ──────────────────────────────────────────────────────────────

enum _BtnType { minimize, maximize, restore, close }

class _Win11Btn extends StatefulWidget {
  final _BtnType type;
  final VoidCallback onTap;
  final GwColors gw;
  const _Win11Btn({required this.type, required this.onTap, required this.gw});
  @override
  State<_Win11Btn> createState() => _Win11BtnState();
}

class _Win11BtnState extends State<_Win11Btn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final isClose  = widget.type == _BtnType.close;
    final iconColor = _hover && isClose ? Colors.white : widget.gw.muted;
    final hoverBg   = widget.gw.isDark
        ? Colors.white.withOpacity(0.09)
        : Colors.black.withOpacity(0.07);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: 46, height: 46,
          child: Stack(alignment: Alignment.center, children: [
            // Win11-style hover background
            if (isClose)
              AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                width: 46, height: 46,
                color: _hover ? const Color(0xFFC42B1C) : Colors.transparent,
              )
            else
              AnimatedOpacity(
                duration: const Duration(milliseconds: 80),
                opacity: _hover ? 1.0 : 0.0,
                child: Container(
                  width: 34, height: 22,
                  decoration: BoxDecoration(
                    color: hoverBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            CustomPaint(
              size: const Size(10, 10),
              painter: _Win11IconPainter(type: widget.type, color: iconColor),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Icon painter ──────────────────────────────────────────────────────────────

class _Win11IconPainter extends CustomPainter {
  final _BtnType type;
  final Color color;
  const _Win11IconPainter({required this.type, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color      = color
      ..strokeWidth = 1.05
      ..strokeCap  = StrokeCap.square
      ..style      = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;

    switch (type) {
      case _BtnType.minimize:
        // Thin horizontal line, vertically centered
        canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), stroke);

      case _BtnType.maximize:
        // Square outline — thin, Win11-style (no thick border)
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0.5, 0.5, w - 1, h - 1),
            const Radius.circular(1),
          ),
          stroke,
        );

      case _BtnType.restore:
        // Two overlapping squares: back (top-right), front (bottom-left)
        // saveLayer + BlendMode.clear lets front square "erase" back square's lines
        final off = w * 0.30;
        canvas.saveLayer(Rect.fromLTWH(-1, -1, w + 2, h + 2), Paint());

        // Back square (top-right)
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(off, 0, w - off - 0.5, h - off - 0.5),
            const Radius.circular(1),
          ),
          stroke,
        );

        // Erase front-square region so back lines don't show through
        canvas.drawRect(
          Rect.fromLTWH(0, off, w - off + 0.5, h - off + 0.5),
          Paint()..blendMode = BlendMode.clear,
        );

        // Front square (bottom-left)
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0.5, off + 0.5, w - off - 1, h - off - 1),
            const Radius.circular(1),
          ),
          stroke,
        );

        canvas.restore();

      case _BtnType.close:
        // Thin X
        canvas.drawLine(Offset(0, 0),   Offset(w, h), stroke);
        canvas.drawLine(Offset(w, 0),   Offset(0, h), stroke);
    }
  }

  @override
  bool shouldRepaint(_Win11IconPainter old) =>
      old.type != type || old.color != color;
}
