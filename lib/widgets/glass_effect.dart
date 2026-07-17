import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Glass card container (blurs whatever Flutter renders behind it)
class GlassCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final double blur;
  final Color? tint;

  const GlassCard({
    super.key,
    required this.child,
    this.radius = 20,
    this.blur = 24,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;
    final color = tint ?? (isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.55));
    final borderColor = isDark ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.6);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

// Glass button — blurs Flutter content behind it
class GlassBtn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primary; // green tint if true

  const GlassBtn({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;
    const green = Color(0xFF22C55E);
    final tint = primary
        ? green.withOpacity(0.25)
        : (isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.5));
    final border = primary ? green.withOpacity(0.5) : Colors.white.withOpacity(0.3);

    return SizedBox(
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: GestureDetector(
            onTap: onPressed,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: primary ? green : (isDark ? Colors.white : Colors.black87)),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: primary ? green : (isDark ? Colors.white : Colors.black87),
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

// Glass icon button
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
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Icon(icon, size: size, color: color),
          ),
        ),
      ),
    );
  }
}
