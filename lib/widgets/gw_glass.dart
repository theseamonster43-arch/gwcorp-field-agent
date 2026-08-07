import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/gw_theme.dart';
import 'gw_icons.dart';

/// Gradient + blob backdrop. Glass only reads as glass when there is varied
/// colour behind it to blur, so every glass screen sits on top of this.
class GwScreenBg extends StatelessWidget {
  final Widget child;
  const GwScreenBg({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    final d = gw.isDark;
    return Stack(children: [
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: d
                  ? const [Color(0xFF071009), Color(0xFF0A1710), Color(0xFF06100B)]
                  : const [Color(0xFFEAF7EE), Color(0xFFF6FBF7), Color(0xFFE4F4E9)],
            ),
          ),
        ),
      ),
      _blob(top: -90, left: -70, size: 280, color: gw.green.withOpacity(d ? .22 : .30)),
      _blob(top: 140, right: -110, size: 260, color: gw.greenDim.withOpacity(d ? .16 : .24)),
      _blob(bottom: 40, left: -60, size: 220, color: gw.green.withOpacity(d ? .12 : .20)),
      _blob(bottom: -70, right: -40, size: 240, color: gw.greenDim.withOpacity(d ? .14 : .18)),
      Positioned.fill(child: child),
    ]);
  }

  Widget _blob({
    double? top,
    double? left,
    double? right,
    double? bottom,
    required double size,
    required Color color,
  }) =>
      Positioned(
        top: top,
        left: left,
        right: right,
        bottom: bottom,
        child: IgnorePointer(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        ),
      );
}

/// Frosted panel. Uses BackdropFilter so it renders identically on every
/// iOS version instead of depending on native effect views.
class GwGlass extends StatelessWidget {
  final Widget child;
  final double radius;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? accent;

  const GwGlass({
    super.key,
    required this.child,
    this.radius = 22,
    this.blur = 26,
    this.padding,
    this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    final d = gw.isDark;
    final fill = accent != null
        ? accent!.withOpacity(d ? .18 : .16)
        : (d ? Colors.white.withOpacity(.09) : Colors.white.withOpacity(.62));
    final line = accent != null
        ? accent!.withOpacity(d ? .40 : .38)
        : (d ? Colors.white.withOpacity(.16) : Colors.white.withOpacity(.85));

    Widget panel = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: line, width: 1),
          ),
          child: child,
        ),
      ),
    );

    if (onTap == null) return panel;
    return _Pressable(onTap: onTap!, radius: radius, child: panel);
  }
}

/// Small circular glass button — nav bar actions, close buttons, etc.
class GwGlassIcon extends StatelessWidget {
  final String icon;
  final VoidCallback? onTap;
  final double size;
  final Color? color;

  const GwGlassIcon({super.key, required this.icon, this.onTap, this.size = 20, this.color});

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    return GwGlass(
      radius: 99,
      blur: 20,
      onTap: onTap,
      padding: const EdgeInsets.all(9),
      child: GwIcon(icon, size: size, color: color ?? gw.text),
    );
  }
}

/// Scale-on-press wrapper that gives glass surfaces a physical feel.
class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double radius;
  const _Pressable({required this.child, required this.onTap, required this.radius});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Compact metric card used on Home and Analytics.
class GwStatTile extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color? accent;
  final String? sub;

  const GwStatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.accent,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    final c = accent ?? gw.green;
    return GwGlass(
      radius: 18,
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: c.withOpacity(.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: GwIcon(icon, size: 15, color: c),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: gw.text,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              height: 1.1,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: gw.muted,
              fontSize: 11.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (sub != null)
            Text(
              sub!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c,
                fontSize: 10.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

/// Section heading with an optional trailing action.
class GwSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const GwSectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: gw.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Row(children: [
              Text(
                actionLabel!,
                style: TextStyle(color: gw.green, fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              Icon(Icons.chevron_right, size: 15, color: gw.green),
            ]),
          ),
      ]),
    );
  }
}
