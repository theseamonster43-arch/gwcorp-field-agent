import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../data/history_repository.dart';
import '../../theme/gw_theme.dart';
import '../../utils/app_preferences.dart';

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
    if (mode == ThemeMode.dark)  return true;
    if (mode == ThemeMode.light) return false;
    return MediaQuery.of(context).platformBrightness == Brightness.dark;
  }

  Future<void> _confirmResetScans() async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Reset Scan History?'),
        content: const Text(
            'All scan sessions will be permanently deleted. This cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await HistoryRepository.clearAll();
    }
  }

  Future<void> _signOut() async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Log Out?'),
        content: const Text('You will be signed out of your account.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out'),
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
    final me    = FirebaseAuth.instance.currentUser;
    final name  = me?.displayName?.trim().isNotEmpty == true
        ? me!.displayName!
        : (me?.email?.split('@')[0] ?? 'Agent');
    final email = me?.email ?? '';
    final photo = me?.photoURL?.isNotEmpty == true ? me!.photoURL : null;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Account')),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Profile header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 8),
            child: Center(
              child: LiquidGlassContainer(
                config: LiquidGlassConfig(
                  effect: CNGlassEffect.regular,
                  shape: CNGlassEffectShape.rect,
                  cornerRadius: 24,
                  interactive: false,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    photo != null
                        ? CircleAvatar(radius: 46, backgroundImage: NetworkImage(photo))
                        : Container(
                            width: 92, height: 92,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF22C55E).withOpacity(0.15),
                              border: Border.all(
                                  color: const Color(0xFF22C55E).withOpacity(0.45), width: 2),
                            ),
                            child: Center(
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(color: Color(0xFF22C55E),
                                    fontSize: 34, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                    const SizedBox(height: 12),
                    Text(name,
                        style: TextStyle(
                            color: CupertinoColors.label.resolveFrom(context),
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(email,
                        style: TextStyle(
                            color: CupertinoColors.secondaryLabel.resolveFrom(context),
                            fontSize: 13)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.35)),
                      ),
                      child: const Text('Field Agent',
                          style: TextStyle(color: Color(0xFF22C55E),
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
              ),
            ),
          ),

          // ── PREFERENCES ─────────────────────────────────────────────────
          CupertinoListSection.insetGrouped(
            header: const Text('PREFERENCES'),
            children: [
              CupertinoListTile.notched(
                leading: const Icon(CupertinoIcons.moon_fill),
                title: const Text('Dark Mode'),
                trailing: CNSwitch(
                  value: _isDark,
                  onChanged: (val) => themeModeNotifier.value =
                      val ? ThemeMode.dark : ThemeMode.light,
                ),
              ),
            ],
          ),

          // ── DATA ─────────────────────────────────────────────────────────
          CupertinoListSection.insetGrouped(
            header: const Text('DATA'),
            children: [
              CupertinoListTile.notched(
                leading: const Icon(CupertinoIcons.delete_simple),
                title: const Text('Reset Scan History'),
                additionalInfo: const Text(''),
                trailing: const CupertinoListTileChevron(),
                onTap: _confirmResetScans,
              ),
              CupertinoListTile.notched(
                leading: const Icon(CupertinoIcons.square_arrow_right,
                    color: CupertinoColors.destructiveRed),
                title: const Text('Log Out',
                    style: TextStyle(color: CupertinoColors.destructiveRed)),
                trailing: const CupertinoListTileChevron(),
                onTap: _signOut,
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
