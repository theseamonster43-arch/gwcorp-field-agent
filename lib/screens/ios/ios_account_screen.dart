import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../data/history_repository.dart';
import '../../theme/gw_theme.dart';
import '../../utils/app_preferences.dart';
import '../../widgets/gw_glass.dart';

class IosAccountScreen extends StatefulWidget {
  const IosAccountScreen({super.key});

  @override
  State<IosAccountScreen> createState() => _IosAccountScreenState();
}

class _IosAccountScreenState extends State<IosAccountScreen> {
  @override
  void initState() {
    super.initState();
    themeModeNotifier.addListener(_rebuild);
  }

  @override
  void dispose() {
    themeModeNotifier.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  bool get _isDark {
    final mode = themeModeNotifier.value;
    if (mode == ThemeMode.dark) return true;
    if (mode == ThemeMode.light) return false;
    return MediaQuery.of(context).platformBrightness == Brightness.dark;
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String destructiveLabel,
  }) async {
    final gw = GwTheme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: gw.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: TextStyle(color: gw.text, fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: Text(
          body,
          style: TextStyle(color: gw.muted, fontSize: 13, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: gw.muted, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              destructiveLabel,
              style: TextStyle(color: gw.red, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _confirmResetScans() async {
    final ok = await _confirm(
      title: 'Reset Scan History?',
      body: 'All scan sessions will be permanently deleted. This cannot be undone.',
      destructiveLabel: 'Delete All',
    );
    if (ok && mounted) {
      await HistoryRepository.clearAll();
    }
  }

  Future<void> _signOut() async {
    final ok = await _confirm(
      title: 'Log Out?',
      body: 'You will be signed out of your account.',
      destructiveLabel: 'Log Out',
    );
    if (ok && mounted) {
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
      await FirebaseAuth.instance.signOut();
      if (mounted) context.go('/signin');
    }
  }

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    final me = FirebaseAuth.instance.currentUser;
    final name = me?.displayName?.trim().isNotEmpty == true
        ? me!.displayName!.trim()
        : (me?.email?.split('@')[0] ?? 'Agent');
    final email = me?.email ?? '';
    final photo = me?.photoURL?.isNotEmpty == true ? me!.photoURL : null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
          children: [
            Text(
              'Account',
              style: TextStyle(
                color: gw.text,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 18),

            // ── Profile ───────────────────────────────────────────────────
            GwGlass(
              radius: 24,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (photo != null)
                    CircleAvatar(radius: 42, backgroundImage: NetworkImage(photo))
                  else
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: gw.green.withOpacity(.15),
                        border: Border.all(color: gw.green.withOpacity(.45), width: 2),
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: gw.green,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: gw.text,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    email,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: gw.muted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: gw.green.withOpacity(.14),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: gw.green.withOpacity(.35), width: 1),
                    ),
                    child: Text(
                      'Field Agent',
                      style: TextStyle(
                        color: gw.green,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // ── Preferences ───────────────────────────────────────────────
            const GwSectionHeader(title: 'Preferences'),
            GwGlass(
              radius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.dark_mode_outlined, size: 20, color: gw.text),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Dark mode',
                        style: TextStyle(
                          color: gw.text,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: _isDark,
                      activeColor: gw.green,
                      onChanged: (v) => themeModeNotifier.value =
                          v ? ThemeMode.dark : ThemeMode.light,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // ── Data ──────────────────────────────────────────────────────
            const GwSectionHeader(title: 'Data'),
            GwGlass(
              radius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _ActionRow(
                    icon: Icons.delete_sweep_outlined,
                    iconColor: gw.text,
                    label: 'Reset scan history',
                    labelColor: gw.text,
                    labelWeight: FontWeight.w600,
                    chevronColor: gw.muted,
                    onTap: _confirmResetScans,
                  ),
                  Divider(color: gw.border, height: 1, thickness: 1),
                  _ActionRow(
                    icon: Icons.logout_rounded,
                    iconColor: gw.red,
                    label: 'Log out',
                    labelColor: gw.red,
                    labelWeight: FontWeight.w700,
                    chevronColor: gw.red.withOpacity(.6),
                    onTap: _signOut,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Center(
              child: Text(
                'GWCORP Field Agent',
                style: TextStyle(color: gw.muted, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 3),
            Center(
              child: Text(
                'v1.0.0',
                style: TextStyle(color: gw.muted, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One tappable settings row inside a glass panel.
class _ActionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color labelColor;
  final FontWeight labelWeight;
  final Color chevronColor;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.labelColor,
    required this.labelWeight,
    required this.chevronColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 13.5,
                    fontWeight: labelWeight,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: chevronColor),
            ],
          ),
        ),
      ),
    );
  }
}
