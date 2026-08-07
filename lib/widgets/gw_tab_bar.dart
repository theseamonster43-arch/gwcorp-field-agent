import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/gw_theme.dart';

/// Floating glass tab bar with a raised gradient "new scan" button in the
/// middle. Tab indices are 0=Home, 1=Scans, 2=Analytics, 3=Account — the
/// centre button is not a tab and reports through [onCenterTap].
class GwTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCenterTap;

  const GwTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onCenterTap,
  });

  static const double barHeight = 64;
  static const double fabSize = 62;

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      height: barHeight + bottomInset + fabSize / 2,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // Glass bar
          Positioned(
            left: 14,
            right: 14,
            bottom: bottomInset > 0 ? bottomInset - 4 : 10,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: gw.isDark
                        ? Colors.white.withOpacity(.10)
                        : Colors.white.withOpacity(.66),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: gw.isDark
                          ? Colors.white.withOpacity(.16)
                          : Colors.white.withOpacity(.88),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(gw.isDark ? .38 : .12),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(children: [
                    _tab(gw, 0, Icons.home_rounded, Icons.home_outlined, 'Home'),
                    _tab(gw, 1, Icons.qr_code_scanner_rounded,
                        Icons.qr_code_scanner_outlined, 'Scans'),
                    const SizedBox(width: fabSize + 16),
                    _tab(gw, 2, Icons.insights_rounded, Icons.insights_outlined, 'Analytics'),
                    _tab(gw, 3, Icons.account_circle_rounded,
                        Icons.account_circle_outlined, 'Account'),
                  ]),
                ),
              ),
            ),
          ),

          // Raised centre action
          Positioned(
            bottom: (bottomInset > 0 ? bottomInset - 4 : 10) + barHeight - fabSize / 2 - 6,
            child: _CenterButton(onTap: onCenterTap, gw: gw),
          ),
        ],
      ),
    );
  }

  Widget _tab(GwColors gw, int index, IconData active, IconData idle, String label) {
    final selected = currentIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Icon(
                selected ? active : idle,
                key: ValueKey(selected),
                size: 22,
                color: selected ? gw.green : gw.muted,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                height: 1,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? gw.green : gw.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterButton extends StatefulWidget {
  final VoidCallback onTap;
  final GwColors gw;
  const _CenterButton({required this.onTap, required this.gw});

  @override
  State<_CenterButton> createState() => _CenterButtonState();
}

class _CenterButtonState extends State<_CenterButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final gw = widget.gw;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: Container(
          width: GwTabBar.fabSize,
          height: GwTabBar.fabSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF4ADE80),
                gw.green,
                gw.greenDim,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: gw.green.withOpacity(.55),
                blurRadius: 22,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(.22),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(color: Colors.white.withOpacity(.32), width: 1.4),
          ),
          child: const Icon(Icons.add_rounded, size: 32, color: Colors.white),
        ),
      ),
    );
  }
}
