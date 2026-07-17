import 'dart:io';
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path/path.dart' as p;
import '../data/history_repository.dart';
import '../theme/gw_theme.dart';
import '../utils/app_preferences.dart';
import '../widgets/gw_nav_bar.dart';

class AccountScreen extends StatefulWidget {
  final ValueChanged<String> onNavigate;
  const AccountScreen({super.key, required this.onNavigate});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
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
    if (mode == ThemeMode.dark)  return true;
    if (mode == ThemeMode.light) return false;
    return GwTheme.of(context).isDark;
  }

  Future<void> _confirmResetScans() async {
    final gw = GwTheme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: gw.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reset Scan History?',
            style: TextStyle(color: gw.text, fontSize: 17, fontWeight: FontWeight.w700)),
        content: Text(
          'All scan sessions will be permanently deleted.\nThis cannot be undone.',
          style: TextStyle(color: gw.muted, fontSize: 13, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: gw.muted, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete All',
                style: TextStyle(color: gw.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await HistoryRepository.clearAll();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Scan history cleared'),
        backgroundColor: GwTheme.of(context).bg3,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  Future<void> _confirmUninstall() async {
    final gw = GwTheme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: gw.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Uninstall GWCORP?',
            style: TextStyle(color: gw.text, fontSize: 17, fontWeight: FontWeight.w700)),
        content: Text(
          'This will open the uninstaller. Your scan history in the cloud will not be deleted.',
          style: TextStyle(color: gw.muted, fontSize: 13, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: gw.muted, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Uninstall', style: TextStyle(color: gw.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) {
      // Uninstaller lives in _uninst/ subdirectory
      final exeDir    = p.dirname(Platform.resolvedExecutable);
      final uninstall = File(p.join(exeDir, '_uninst', 'Uninstall GWCORP Field Agent.exe'));
      if (uninstall.existsSync()) {
        await Process.start(uninstall.path, ['--uninstall'],
            mode: ProcessStartMode.detached);
        exit(0);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Uninstaller not found — was the app installed via GWCORP_Installer.exe?'),
            backgroundColor: gw.bg3,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      }
    }
  }

  Future<void> _signOut() async {
    final gw = GwTheme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: gw.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Log Out?',
            style: TextStyle(color: gw.text, fontSize: 17, fontWeight: FontWeight.w700)),
        content: Text('You will be signed out of your account.',
            style: TextStyle(color: gw.muted, fontSize: 13)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: gw.muted, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Log Out',
                style: TextStyle(color: gw.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      try { await GoogleSignIn().signOut(); } catch (_) {}
      await FirebaseAuth.instance.signOut();
      if (mounted) context.go('/signin');
    }
  }

  @override
  Widget build(BuildContext context) {
    final gw    = GwTheme.of(context);
    final me    = FirebaseAuth.instance.currentUser;
    final name  = me?.displayName?.trim().isNotEmpty == true
        ? me!.displayName!
        : (me?.email?.split('@')[0] ?? 'Agent');
    final email = me?.email ?? '';
    final photo = (me?.photoURL?.isNotEmpty == true) ? me!.photoURL : null;

    return Scaffold(
      backgroundColor: gw.bg,
      appBar: const GwNavBar(title: 'Account'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
        children: [
          // ── Profile header ──────────────────────────────
          Center(
            child: Column(children: [
              photo != null
                  ? CircleAvatar(radius: 46,
                      backgroundImage: NetworkImage(photo))
                  : Container(
                      width: 92, height: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle, color: gw.greenGlow,
                        border: Border.all(
                            color: gw.green.withOpacity(0.45), width: 2),
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(color: gw.green, fontSize: 34,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
              const SizedBox(height: 14),
              Text(name, style: TextStyle(color: gw.text, fontSize: 20,
                  fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(email, style: TextStyle(color: gw.muted, fontSize: 13)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: gw.greenGlow,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: gw.green.withOpacity(0.35)),
                ),
                child: Text('Field Agent',
                    style: TextStyle(color: gw.green, fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          const SizedBox(height: 32),

          // ── PREFERENCES ─────────────────────────────────
          _sectionLabel(gw, 'PREFERENCES'),
          const SizedBox(height: 8),
          _card(gw, [
            _switchRow(
              gw,
              Icons.dark_mode_outlined,
              'Dark Mode',
              _isDark,
              (val) => themeModeNotifier.value =
                  val ? ThemeMode.dark : ThemeMode.light,
            ),
          ]),
          const SizedBox(height: 20),

          // ── DATA ────────────────────────────────────────
          _sectionLabel(gw, 'DATA'),
          const SizedBox(height: 8),
          _card(gw, [
            _row(gw, Icons.open_in_new_rounded, 'Open Web Version',
                () => widget.onNavigate('/main/web')),
            _divider(gw),
            _row(gw, Icons.delete_sweep_outlined, 'Reset Scan History',
                _confirmResetScans, color: gw.amber),
            _divider(gw),
            _row(gw, Icons.logout_rounded, 'Log Out',
                _signOut, color: gw.red),
          ]),
          if (Platform.isWindows) ...[
            const SizedBox(height: 20),
            _sectionLabel(gw, 'SYSTEM'),
            const SizedBox(height: 8),
            _card(gw, [
              _row(gw, Icons.delete_forever_rounded, 'Uninstall GWCORP Field Agent',
                  _confirmUninstall, color: gw.red),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(GwColors gw, String t) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(t,
            style: TextStyle(color: gw.muted, fontSize: 10,
                fontWeight: FontWeight.w700, letterSpacing: 1.2)),
      );

  Widget _card(GwColors gw, List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: gw.bg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: gw.border),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(children: children),
      );

  Widget _divider(GwColors gw) =>
      Divider(color: gw.border, height: 1, indent: 48);

  Widget _row(GwColors gw, IconData icon, String label, VoidCallback onTap,
          {Color? color}) =>
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(icon, color: color ?? gw.muted, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: color ?? gw.text, fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.chevron_right, color: gw.muted, size: 18),
          ]),
        ),
      );

  Widget _switchRow(GwColors gw, IconData icon, String label, bool value,
          ValueChanged<bool> onChanged) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Icon(icon, color: gw.muted, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(color: gw.text, fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ),
          Platform.isIOS
              ? CNSwitch(value: value, onChanged: onChanged)
              : Switch.adaptive(value: value, activeColor: gw.green, onChanged: onChanged),
        ]),
      );
}
