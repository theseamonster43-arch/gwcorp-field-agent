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
      return GestureDetector(
        onTap: onPressed,
        child: LiquidGlassContainer(
          config: LiquidGlassConfig(effect: CNGlassEffect.regular, cornerRadius: 10),
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

// Wraps any child widget in liquid glass on iOS, plain GestureDetector otherwise
class GwGlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final EdgeInsets? padding;

  const GwGlassButton({super.key, required this.child, this.onTap, this.radius = 12, this.padding});

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return GestureDetector(
        onTap: onTap,
        child: LiquidGlassContainer(
          config: LiquidGlassConfig(effect: CNGlassEffect.regular, cornerRadius: radius),
          child: padding != null ? Padding(padding: padding!, child: child) : child,
        ),
      );
    }
    return GestureDetector(onTap: onTap, child: padding != null ? Padding(padding: padding!, child: child) : child);
  }
}
