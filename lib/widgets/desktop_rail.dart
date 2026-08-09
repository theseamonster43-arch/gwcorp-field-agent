import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/gw_theme.dart';
import 'desktop_chrome.dart';
import 'gw_icons.dart';

/// The web app's left icon rail.
///
/// Rendered from MaterialApp.builder alongside [DesktopTitleBar], so it stays
/// on screen while a scan, session detail or camera route is pushed over the
/// shell — the rail is chrome, not part of any one page.
class DesktopRail extends StatelessWidget {
  const DesktopRail({super.key});

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) return const SizedBox.shrink();
    final gw = GwTheme.of(context);

    // Splash and sign-in have nothing to navigate to yet, so the rail only
    // appears once there is a signed-in agent.
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snap) {
        if (snap.data == null) return const SizedBox.shrink();
        return _rail(gw);
      },
    );
  }

  Widget _rail(GwColors gw) {
    return ValueListenableBuilder<int>(
      valueListenable: desktopTab,
      builder: (context, tab, _) => Container(
        width: 74,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: gw.bg2.withOpacity(.35),
          border: Border(right: BorderSide(color: gw.border)),
        ),
        child: Column(children: [
          _RailNewButton(onTap: () => gwPush?.call('/main/batch')),
          const SizedBox(height: 20),
          _RailBtn(index: kDesktopHomeTab,  current: tab, icon: GwIcons.home,    label: 'Home'),
          _RailBtn(index: kDesktopScansTab, current: tab, icon: GwIcons.scan,    label: 'Scans'),
          _RailBtn(index: kDesktopStatsTab, current: tab, icon: GwIcons.chart,   label: 'Stats'),
          _RailBtn(index: kDesktopChatsTab, current: tab, icon: GwIcons.chat,    label: 'Chats'),
          _RailBtn(index: kDesktopAiTab,    current: tab, icon: GwIcons.sparkle, label: 'AI'),
          const Spacer(),
          Divider(color: gw.border, height: 1, indent: 14, endIndent: 14),
          const SizedBox(height: 10),
          _RailBtn(index: kDesktopAccountTab, current: tab, icon: GwIcons.user, label: 'Account'),
        ]),
      ),
    );
  }
}

class _RailBtn extends StatelessWidget {
  final int index;
  final int current;
  final String icon;
  final String label;

  const _RailBtn({
    required this.index,
    required this.current,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    final selected = current == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => gwSelectDesktopTab(index),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: selected ? 1 : 0),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutBack,
            builder: (context, t, _) {
              // easeOutBack overshoots past 1 — clamp anything colour-related.
              final c = t.clamp(0.0, 1.0);
              final tint = Color.lerp(gw.muted, gw.green, c);
              return Container(
                width: 54,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: gw.green.withOpacity(.14 * c),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(children: [
                  Transform.translate(
                    offset: Offset(0, -2 * t),
                    child: Transform.scale(
                      scale: 1 + .16 * t,
                      child: GwIcon(icon, size: 20, color: tint),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    label,
                    style: TextStyle(
                      color: tint,
                      fontSize: 10,
                      height: 1,
                      fontWeight:
                          FontWeight.lerp(FontWeight.w600, FontWeight.w800, c),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ]),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The rail's green "new batch" circle.
class _RailNewButton extends StatefulWidget {
  final VoidCallback onTap;
  const _RailNewButton({required this.onTap});
  @override
  State<_RailNewButton> createState() => _RailNewButtonState();
}

class _RailNewButtonState extends State<_RailNewButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutBack,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [const Color(0xFF4ADE80), gw.green, gw.greenDim],
              ),
              boxShadow: [
                BoxShadow(
                  color: gw.green.withOpacity(.50),
                  blurRadius: 18,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const GwIcon(GwIcons.plus, size: 22,
                color: Colors.white, strokeWidth: 2.4),
          ),
        ),
      ),
    );
  }
}
