import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/gw_theme.dart';
import '../widgets/desktop_chrome.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _enter;
  late AnimationController _pulse;
  late Animation<double> _iconFade;
  late Animation<double> _iconScale;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _glowPulse;

  @override
  void initState() {
    super.initState();

    _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _iconFade  = CurvedAnimation(parent: _enter,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOut));
    _iconScale = Tween(begin: 0.55, end: 1.0).animate(
        CurvedAnimation(parent: _enter,
            curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack)));
    _textFade  = CurvedAnimation(parent: _enter,
        curve: const Interval(0.45, 1.0, curve: Curves.easeOut));
    _textSlide = Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(
        CurvedAnimation(parent: _enter,
            curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic)));
    _enter.forward();

    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _glowPulse = Tween(begin: 0.2, end: 1.0).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

    Future.delayed(const Duration(milliseconds: 2200), _navigate);
  }

  void _navigate() {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    context.go(user != null ? '/main' : '/signin');
  }

  @override
  void dispose() {
    _enter.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    return Scaffold(
      backgroundColor: gw.bg,
      body: Column(children: [
        const DesktopTitleBar(),
        Expanded(child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            ScaleTransition(
              scale: _iconScale,
              child: FadeTransition(
                opacity: _iconFade,
                child: AnimatedBuilder(
                  animation: _glowPulse,
                  builder: (_, __) => Container(
                    width: 92, height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: gw.greenGlow,
                      border: Border.all(color: gw.green.withOpacity(0.4), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: gw.green.withOpacity(0.35 * _glowPulse.value),
                          blurRadius: 52 * _glowPulse.value,
                          spreadRadius: 8 * _glowPulse.value,
                        ),
                      ],
                    ),
                    child: Icon(Icons.recycling, color: gw.green, size: 44),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            SlideTransition(
              position: _textSlide,
              child: FadeTransition(
                opacity: _textFade,
                child: Column(children: [
                  Text('GWCORP',
                      style: TextStyle(color: gw.text, fontSize: 30,
                          fontWeight: FontWeight.w900, letterSpacing: 3.5)),
                  const SizedBox(height: 6),
                  Text('Field Agent',
                      style: TextStyle(color: gw.muted, fontSize: 13, letterSpacing: 2)),
                ]),
              ),
            ),
            ],
          ),
        )),
      ]),
    );
  }
}
