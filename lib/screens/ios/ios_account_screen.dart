import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/history_repository.dart';
import '../../theme/gw_theme.dart';
import '../../widgets/gw_icons.dart';
import '../../services/update_service.dart';
import '../../utils/app_preferences.dart';
import '../../widgets/gw_glass.dart';
import '../../widgets/gw_responsive.dart';

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
    final g = gwGutter(context);
    final me = FirebaseAuth.instance.currentUser;
    final name = me?.displayName?.trim().isNotEmpty == true
        ? me!.displayName!.trim()
        : (me?.email?.split('@')[0] ?? 'Agent');
    final email = me?.email ?? '';
    final photo = me?.photoURL?.isNotEmpty == true ? me!.photoURL : null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            // 640 turned this into a narrow ribbon on a monitor. The content
            // below splits into two columns when there is room, so it needs
            // width to split into.
            constraints: BoxConstraints(
              maxWidth: gwCardColumns(context) > 1 ? 1100 : 640,
            ),
            child: ListView(
          padding: EdgeInsets.fromLTRB(g, 4, g, gwPageBottom(context)),
          children: [
            Text(
              'Account',
              style: TextStyle(
                color: gw.text,
                fontSize: gwTitleSize(context),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GwIcon(GwIcons.moon, size: 20, color: gw.text),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Appearance',
                          style: TextStyle(
                            color: gw.text,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _AppearancePicker(gw: gw),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ── Performance ───────────────────────────────────────────────
            GwGlass(
              radius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  GwIcon(GwIcons.shield, size: 20, color: gw.text),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Performance mode', style: TextStyle(
                            color: gw.text, fontSize: 13.5,
                            fontWeight: FontWeight.w600)),
                        Text('Turns off blur. Smoother on older phones.',
                            style: TextStyle(color: gw.muted, fontSize: 11)),
                      ],
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: performanceModeNotifier,
                    builder: (_, on, __) => Switch.adaptive(
                      value: on,
                      activeColor: gw.green,
                      onChanged: (v) => performanceModeNotifier.value = v,
                    ),
                  ),
                ]),
              ),
            ),

            // ── Updates ───────────────────────────────────────────────────
            // Desktop only: the phone builds are updated by their stores, and
            // telling an agent to sideload an APK would be worse than silence.
            if (UpdateService.supported) ...[
              const SizedBox(height: 10),
              const _UpdateCard(),
            ],
            const SizedBox(height: 18),

            // ── Data ──────────────────────────────────────────────────────
            const GwSectionHeader(title: 'Data'),
            GwGlass(
              radius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _ActionRow(
                    icon: GwIcons.trash,
                    iconColor: gw.text,
                    label: 'Reset scan history',
                    labelColor: gw.text,
                    labelWeight: FontWeight.w600,
                    chevronColor: gw.muted,
                    onTap: _confirmResetScans,
                  ),
                  Divider(color: gw.border, height: 1, thickness: 1),
                  _ActionRow(
                    icon: GwIcons.logout,
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

            // Required for store listings, and honest regardless: the app
            // uploads photos and sends them to a third-party AI service.
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                children: [
                  _LegalLink(
                    label: 'Privacy Policy',
                    url: 'https://ihs-gwcorp.web.app/privacy.html',
                  ),
                  Text('·', style: TextStyle(color: gw.muted, fontSize: 11)),
                  _LegalLink(
                    label: 'Terms of Service',
                    url: 'https://ihs-gwcorp.web.app/terms.html',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Center(
              child: Text(
                'GWCORP Field Agent',
                style: TextStyle(color: gw.muted, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 3),
            Center(
              child: Text(
                // Read from the running build rather than hardcoded — this
                // still said v1.0.0 after the app had shipped 1.1.0.
                UpdateService.runningVersion.isEmpty
                    ? ''
                    : 'v${UpdateService.runningVersion}',
                style: TextStyle(color: gw.muted, fontSize: 10),
              ),
            ),
          ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One tappable settings row inside a glass panel.
class _ActionRow extends StatelessWidget {
  final String icon;
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
              GwIcon(icon, size: 20, color: iconColor),
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
              GwIcon(GwIcons.chevronRight, size: 18, color: chevronColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// System / Light / Dark, as a segmented control.
///
/// System is the default and stays a real choice rather than an implied one —
/// a plain dark-mode switch has no way to express "follow the device", so
/// toggling it once used to strand the app on a fixed theme forever.
class _AppearancePicker extends StatelessWidget {
  const _AppearancePicker({required this.gw});

  final GwColors gw;

  static const _options = <(String, ThemeMode)>[
    ('System', ThemeMode.system),
    ('Light', ThemeMode.light),
    ('Dark', ThemeMode.dark),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: gw.bg2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: gw.border),
        ),
        child: Row(
          children: [
            for (final (label, value) in _options)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => themeModeNotifier.value = value,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: mode == value
                          ? gw.green.withOpacity(.16)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: mode == value ? gw.green : gw.muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Automatic update toggle plus a manual check.
///
/// The manual button matters as much as the toggle: an agent who turned auto
/// off, or who is on a build older than the one that could tell them, still
/// needs a way to ask.
class _UpdateCard extends StatefulWidget {
  const _UpdateCard();

  @override
  State<_UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends State<_UpdateCard> {
  bool _checking = false;
  String? _result;

  Future<void> _check() async {
    setState(() { _checking = true; _result = null; });
    final found = await UpdateService.check();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _result = found
          ? 'Update available.'
          : (UpdateService.lastError ?? 'You are up to date.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);

    return GwGlass(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            GwIcon(GwIcons.arrowRight, size: 20, color: gw.text),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Automatic updates', style: TextStyle(
                      color: gw.text, fontSize: 13.5,
                      fontWeight: FontWeight.w600)),
                  Text('Check for a newer build when the app starts.',
                      style: TextStyle(color: gw.muted, fontSize: 11)),
                ],
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: autoUpdateNotifier,
              builder: (_, on, __) => Switch.adaptive(
                value: on,
                activeColor: gw.green,
                onChanged: (v) => autoUpdateNotifier.value = v,
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: Text(
                _result ?? 'Version ${UpdateService.runningVersion}',
                style: TextStyle(color: gw.muted, fontSize: 11.5),
              ),
            ),
            TextButton(
              onPressed: _checking ? null : _check,
              child: _checking
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: gw.green),
                    )
                  : Text('Check now', style: TextStyle(
                      color: gw.green, fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
        ],
      ),
    );
  }
}

/// Opens a legal page in the browser rather than a WebView.
///
/// These documents are the same ones a store listing points at, so they live
/// on the website and have one canonical version — an in-app copy would drift
/// from it the first time either changed.
class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: gw.muted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: gw.muted.withOpacity(.5),
        ),
      ),
    );
  }
}
