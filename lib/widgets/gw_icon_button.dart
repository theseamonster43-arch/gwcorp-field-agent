import 'dart:io';
import 'package:flutter/material.dart';
import 'gw_glass.dart';

class GwIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;

  const GwIconButton({super.key, required this.icon, this.onPressed, this.color, this.size = 22});

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS || Platform.isAndroid) {
      // Takes Material IconData (the desktop screens still pass those), so it
      // wraps a plain Icon rather than going through GwGlassIcon, which now
      // expects a GwIcons path string.
      return GwGlass(
        radius: 99,
        blur: 20,
        onTap: onPressed,
        padding: const EdgeInsets.all(9),
        child: Icon(icon, size: size, color: color),
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
    if (Platform.isIOS || Platform.isAndroid) {
      return GwGlass(radius: radius, padding: padding, onTap: onTap, child: child);
    }
    final inner = padding != null ? Padding(padding: padding!, child: child) : child;
    return GestureDetector(onTap: onTap, child: inner);
  }
}
