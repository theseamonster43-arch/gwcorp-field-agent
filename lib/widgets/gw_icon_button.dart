import 'dart:io';
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/material.dart';

class GwIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;

  const GwIconButton({super.key, required this.icon, this.onPressed, this.color, this.size = 22});

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return LiquidGlassContainer(
        config: LiquidGlassConfig(
          effect: CNGlassEffect.regular,
          shape: CNGlassEffectShape.capsule,
          cornerRadius: 10,
          interactive: true,
        ),
        child: GestureDetector(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: size, color: color),
          ),
        ),
      );
    }
    return IconButton(icon: Icon(icon, color: color, size: size), onPressed: onPressed);
  }
}

class GwGlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final EdgeInsets? padding;

  const GwGlassButton({super.key, required this.child, this.onTap, this.radius = 12, this.padding});

  @override
  Widget build(BuildContext context) {
    final inner = padding != null ? Padding(padding: padding!, child: child) : child;
    if (Platform.isIOS) {
      return LiquidGlassContainer(
        config: LiquidGlassConfig(
          effect: CNGlassEffect.regular,
          shape: CNGlassEffectShape.rect,
          cornerRadius: radius,
          interactive: true,
        ),
        child: GestureDetector(
          onTap: onTap,
          child: inner,
        ),
      );
    }
    return GestureDetector(onTap: onTap, child: inner);
  }
}
