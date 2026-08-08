import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/gw_theme.dart';
import 'gw_icons.dart';

/// Bottom bar: full width, rounded at the top corners only, with a gradient
/// "new scan" button seated in the middle. Tab indices are 0=Home, 1=Scans,
/// 2=Analytics, 3=Account — the centre button is not a tab and reports
/// through [onCenterTap].
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
  static const double fabSize = 60;
  static const double topRadius = 14;

  /// How far the centre button pokes above the bar.
  static const double _raise = 15;

  /// Slack above the centre button for its grow-on-press animation.
  static const double _pressHeadroom = 6;

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final barBox = barHeight + bottomInset;

    return SizedBox(
      // + _pressHeadroom so the centre button can scale up on press without
      // the enclosing Stack clipping its top edge.
      height: barBox + _raise + _pressHeadroom,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(topRadius)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  height: barBox,
                  padding: EdgeInsets.only(bottom: bottomInset),
                  decoration: BoxDecoration(
                    color: gw.isDark
                        ? Colors.white.withOpacity(.10)
                        : Colors.white.withOpacity(.70),
                    border: Border(
                      top: BorderSide(
                        color: gw.isDark
                            ? Colors.white.withOpacity(.16)
                            : Colors.white.withOpacity(.90),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(children: [
                    _tab(gw, 0, GwIcons.home),
                    _tab(gw, 1, GwIcons.scan),
                    const SizedBox(width: fabSize + 20),
                    _tab(gw, 2, GwIcons.chart),
                    _tab(gw, 3, GwIcons.chat),
                  ]),
                ),
              ),
            ),
          ),

          // Centre action, seated low so only a sliver clears the bar.
          Positioned(
            left: 0,
            right: 0,
            bottom: barBox - fabSize + _raise,
            child: Center(child: _CenterButton(onTap: onCenterTap, gw: gw)),
          ),
        ],
      ),
    );
  }

  Widget _tab(GwColors gw, int index, String icon) {
    final selected = currentIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: selected ? 1 : 0),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutBack,
          builder: (context, t, _) {
            // easeOutBack overshoots past 1, which is what gives the little
            // pop — clamp anything that must stay in range.
            final c = t.clamp(0.0, 1.0);
            return Center(
              child: Transform.translate(
                offset: Offset(0, -2 * t),
                child: Transform.scale(
                  scale: 1 + .18 * t,
                  child: GwIcon(
                    icon,
                    size: 23,
                    color: Color.lerp(gw.muted, gw.green, c),
                    strokeWidth: 1.9 + .35 * c,
                  ),
                ),
              ),
            );
          },
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
        scale: _down ? 1.12 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutBack,
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
                color: gw.green.withOpacity(.50),
                blurRadius: 20,
                spreadRadius: 1,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(.20),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(color: Colors.white.withOpacity(.32), width: 1.4),
          ),
          child: const GwIcon(GwIcons.plus, size: 25, color: Colors.white, strokeWidth: 2.3),
        ),
      ),
    );
  }
}
