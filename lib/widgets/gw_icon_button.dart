import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'glass_effect.dart';

class GwIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;

  const GwIconButton({super.key, required this.icon, this.onPressed, this.color, this.size = 22});

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return GlassIconBtn(icon: icon, onPressed: onPressed, color: color, size: size);
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
      return GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: inner,
            ),
          ),
        ),
      );
    }
    return GestureDetector(onTap: onTap, child: inner);
  }
}
