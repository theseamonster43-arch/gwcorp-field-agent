import 'package:flutter/material.dart';

/// The same line-art icon set the web app uses (public/field-agent.html), so
/// the phone app and the site never drift apart visually.
///
/// Each entry is SVG path data on a 24x24 grid. The web version uses a mix of
/// <path>, <line>, <polyline>, <circle> and <rect>; those are flattened to pure
/// path commands here so a single small parser can draw all of them, which
/// keeps this file dependency-free.
class GwIcons {
  const GwIcons._();

  static const home =
      'M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z M9 22L9 12L15 12L15 22';
  static const scan =
      'M3 7V5a2 2 0 0 1 2-2h2 M17 3h2a2 2 0 0 1 2 2v2 M21 17v2a2 2 0 0 1-2 2h-2 '
      'M7 21H5a2 2 0 0 1-2-2v-2 M7 12L17 12';
  static const chart = 'M18 20V10 M12 20V4 M6 20v-6';
  static const chat =
      'M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9'
      'L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5'
      'a8.48 8.48 0 0 1 8 8z';
  static const box =
      'M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73'
      'l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z M3.27 6.96L12 12.01L20.73 6.96 M12 22.08V12';
  static const recycle =
      'M23 4L23 10L17 10 M1 20L1 14L7 14 '
      'M3.51 9a9 9 0 0 1 14.85-3.36L23 10 M1 14l4.64 4.36A9 9 0 0 0 20.49 15';
  static const alert =
      'M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z '
      'M12 9v4 M12 17L12.01 17';
  static const check = 'M20 6L9 17L4 12';
  static const checkCircle =
      'M22 11.08V12a10 10 0 1 1-5.93-9.14 M22 4L12 14.01L9 11.01';
  static const camera =
      'M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z '
      'M8 13a4 4 0 1 0 8 0a4 4 0 1 0-8 0';
  static const clip =
      'M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2 '
      'M9 2h6a1 1 0 0 1 1 1v2a1 1 0 0 1-1 1H9a1 1 0 0 1-1-1V3a1 1 0 0 1 1-1z';
  static const globe =
      'M2 12a10 10 0 1 0 20 0a10 10 0 1 0-20 0 M2 12H22 '
      'M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z';
  static const pin =
      'M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z M9 10a3 3 0 1 0 6 0a3 3 0 1 0-6 0';
  static const user =
      'M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2 M8 7a4 4 0 1 0 8 0a4 4 0 1 0-8 0';
  static const plus = 'M12 5v14 M5 12h14';
  static const menu = 'M3 12h18 M3 6h18 M3 18h18';
  static const sparkle = 'M12 3l1.9 5.1L19 10l-5.1 1.9L12 17l-1.9-5.1L5 10l5.1-1.9L12 3z '
      'M19 16v4 M17 18h4';
  static const satellite =
      'M4 10l6-6 3 3-6 6-3-3z M10.5 13.5L7 17 M3 19a2 2 0 1 0 4 0a2 2 0 1 0-4 0 '
      'M14 4a6 6 0 0 1 6 6 M14 8a2 2 0 0 1 2 2';
  static const chevronRight = 'M9 18l6-6-6-6';
  static const chevronLeft = 'M15 18l-6-6 6-6';
  static const arrowRight = 'M5 12h14 M12 5l7 7-7 7';
  static const arrowUp = 'M12 19V5 M5 12l7-7 7 7';
  static const search = 'M3 11a8 8 0 1 0 16 0a8 8 0 1 0-16 0 M21 21l-4.35-4.35';
  static const moon = 'M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z';
  static const trash =
      'M3 6h18 M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6 M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2';
  static const logout =
      'M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4 M16 17l5-5-5-5 M21 12H9';
  static const mail =
      'M4 4h16a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z M22 6L12 13L2 6';
  static const lock =
      'M5 11h14a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-7a2 2 0 0 1 2-2z '
      'M7 11V7a5 5 0 0 1 10 0v4';
  static const eye =
      'M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z M9 12a3 3 0 1 0 6 0a3 3 0 1 0-6 0';
  static const eyeOff =
      'M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94 '
      'M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19 '
      'M14.12 14.12a3 3 0 1 1-4.24-4.24 M1 1L23 23';
  static const shield = 'M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z M9 12l2 2 4-4';
  static const image =
      'M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z '
      'M7 8.5a1.5 1.5 0 1 0 3 0a1.5 1.5 0 1 0-3 0 M21 15L16 10L5 21';
  static const close = 'M18 6L6 18 M6 6l12 12';
}

/// Minimal SVG path-data parser. Supports M m L l H h V v C c S s Q q T t A a Z z,
/// which is everything [GwIcons] uses.
///
/// Arcs map straight onto Path.arcToPoint — SVG's sweep flag and Flutter's
/// `clockwise` mean the same thing because both use a y-down coordinate space.
class _SvgPath {
  static final Map<String, Path> _cache = {};

  static Path parse(String d) => _cache.putIfAbsent(d, () => _build(d));

  static final _token = RegExp(r'[MmLlHhVvCcSsQqTtAaZz]|-?\d*\.?\d+(?:[eE][-+]?\d+)?');

  static Path _build(String d) {
    final path = Path();
    final tokens = _token.allMatches(d).map((m) => m[0]!).toList();

    var i = 0;
    var cx = 0.0, cy = 0.0;       // current point
    var sx = 0.0, sy = 0.0;       // subpath start
    var lcx = 0.0, lcy = 0.0;     // last cubic control (for S)
    var lqx = 0.0, lqy = 0.0;     // last quad control (for T)
    var prev = '';

    double num_() => double.parse(tokens[i++]);
    bool more() => i < tokens.length && double.tryParse(tokens[i]) != null;

    while (i < tokens.length) {
      var cmd = tokens[i];
      if (double.tryParse(cmd) != null) {
        // implicit repeat: M/m continue as L/l, everything else repeats itself
        cmd = prev == 'M' ? 'L' : prev == 'm' ? 'l' : prev;
      } else {
        i++;
      }

      switch (cmd) {
        case 'M':
          cx = num_(); cy = num_(); sx = cx; sy = cy; path.moveTo(cx, cy);
          break;
        case 'm':
          cx += num_(); cy += num_(); sx = cx; sy = cy; path.moveTo(cx, cy);
          break;
        case 'L':
          cx = num_(); cy = num_(); path.lineTo(cx, cy);
          break;
        case 'l':
          cx += num_(); cy += num_(); path.lineTo(cx, cy);
          break;
        case 'H':
          cx = num_(); path.lineTo(cx, cy);
          break;
        case 'h':
          cx += num_(); path.lineTo(cx, cy);
          break;
        case 'V':
          cy = num_(); path.lineTo(cx, cy);
          break;
        case 'v':
          cy += num_(); path.lineTo(cx, cy);
          break;
        case 'C':
        case 'c':
          {
            final rel = cmd == 'c';
            final x1 = num_() + (rel ? cx : 0), y1 = num_() + (rel ? cy : 0);
            final x2 = num_() + (rel ? cx : 0), y2 = num_() + (rel ? cy : 0);
            final x = num_() + (rel ? cx : 0), y = num_() + (rel ? cy : 0);
            path.cubicTo(x1, y1, x2, y2, x, y);
            lcx = x2; lcy = y2; cx = x; cy = y;
            break;
          }
        case 'S':
        case 's':
          {
            final rel = cmd == 's';
            final smooth = prev.toUpperCase() == 'C' || prev.toUpperCase() == 'S';
            final x1 = smooth ? 2 * cx - lcx : cx;
            final y1 = smooth ? 2 * cy - lcy : cy;
            final x2 = num_() + (rel ? cx : 0), y2 = num_() + (rel ? cy : 0);
            final x = num_() + (rel ? cx : 0), y = num_() + (rel ? cy : 0);
            path.cubicTo(x1, y1, x2, y2, x, y);
            lcx = x2; lcy = y2; cx = x; cy = y;
            break;
          }
        case 'Q':
        case 'q':
          {
            final rel = cmd == 'q';
            final x1 = num_() + (rel ? cx : 0), y1 = num_() + (rel ? cy : 0);
            final x = num_() + (rel ? cx : 0), y = num_() + (rel ? cy : 0);
            path.quadraticBezierTo(x1, y1, x, y);
            lqx = x1; lqy = y1; cx = x; cy = y;
            break;
          }
        case 'T':
        case 't':
          {
            final rel = cmd == 't';
            final smooth = prev.toUpperCase() == 'Q' || prev.toUpperCase() == 'T';
            final x1 = smooth ? 2 * cx - lqx : cx;
            final y1 = smooth ? 2 * cy - lqy : cy;
            final x = num_() + (rel ? cx : 0), y = num_() + (rel ? cy : 0);
            path.quadraticBezierTo(x1, y1, x, y);
            lqx = x1; lqy = y1; cx = x; cy = y;
            break;
          }
        case 'A':
        case 'a':
          {
            final rel = cmd == 'a';
            final rx = num_(), ry = num_();
            final rot = num_();
            final largeArc = num_() != 0;
            final sweep = num_() != 0;
            final x = num_() + (rel ? cx : 0), y = num_() + (rel ? cy : 0);
            path.arcToPoint(
              Offset(x, y),
              radius: Radius.elliptical(rx, ry),
              rotation: rot,
              largeArc: largeArc,
              clockwise: sweep,
            );
            cx = x; cy = y;
            break;
          }
        case 'Z':
        case 'z':
          path.close();
          cx = sx; cy = sy;
          break;
        default:
          i++; // unknown token, skip so we can never loop forever
      }
      prev = cmd;
      if (cmd == 'Z' || cmd == 'z') continue;
      if (!more()) continue;
    }
    return path;
  }
}

class _GwIconPainter extends CustomPainter {
  final String data;
  final Color color;
  final double stroke;

  const _GwIconPainter(this.data, this.color, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale);
    canvas.drawPath(
      _SvgPath.parse(data),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = color
        // divided by scale so the on-screen width is `stroke` px at any size
        ..strokeWidth = stroke / scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GwIconPainter old) =>
      old.data != data || old.color != color || old.stroke != stroke;
}

/// Renders a [GwIcons] glyph at [size], stroked in [color].
///
/// Stroke width scales with size — a flat 2.0 reads as a blob at 14px and as a
/// hairline at 40px.
class GwIcon extends StatelessWidget {
  final String icon;
  final double size;
  final Color? color;
  final double? strokeWidth;

  const GwIcon(this.icon, {super.key, this.size = 20, this.color, this.strokeWidth});

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? const Color(0xFFFFFFFF);
    final sw = strokeWidth ?? (size <= 16 ? 2.2 : size >= 34 ? 1.6 : 2.0);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _GwIconPainter(icon, c, sw),
      ),
    );
  }
}
