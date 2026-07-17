import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final double blur;
  final Color? tint;

  const GlassCard({
    super.key,
    required this.child,
    this.radius = 20,
    this.blur = 40,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final color = tint ?? (isDark
        ? Colors.white.withOpacity(0.18)
        : Colors.white.withOpacity(0.72));
    final borderColor = isDark
        ? Colors.white.withOpacity(0.28)
        : Colors.white.withOpacity(0.80);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: child,
        ),
      ),
    );
  }
}

class GlassBtn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primary;

  const GlassBtn({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    const green = Color(0xFF22C55E);
    final tint = primary
        ? green.withOpacity(0.35)
        : (isDark ? Colors.white.withOpacity(0.18) : Colors.white.withOpacity(0.65));
    final border = primary
        ? green.withOpacity(0.7)
        : (isDark ? Colors.white.withOpacity(0.35) : Colors.white.withOpacity(0.80));
    final textColor = primary
        ? (isDark ? Colors.white : Colors.black87)
        : (isDark ? Colors.white : Colors.black87);

    return SizedBox(
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: GestureDetector(
            onTap: onPressed,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border, width: 1.2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: primary ? green : textColor),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: primary ? green : textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;

  const GlassIconBtn({super.key, required this.icon, this.onPressed, this.color, this.size = 20});

  @override
  Widget build(BuildContext context) {
    if (!Platform.isIOS) {
      return IconButton(icon: Icon(icon, color: color, size: size), onPressed: onPressed);
    }
    return GestureDetector(
      onTap: onPressed,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.40), width: 1.2),
            ),
            child: Icon(icon, size: size, color: color),
          ),
        ),
      ),
    );
  }
}
