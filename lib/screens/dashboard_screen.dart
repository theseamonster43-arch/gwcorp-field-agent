import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/gw_theme.dart';
import '../widgets/gw_icon_button.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback onMenuClick;
  final VoidCallback onViewChats;
  final VoidCallback? onSettingsClick;
  final VoidCallback? onNewBatch;
  final int sessionCount;

  const DashboardScreen({
    super.key,
    required this.onMenuClick,
    required this.onViewChats,
    this.onSettingsClick,
    this.onNewBatch,
    this.sessionCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    final me = FirebaseAuth.instance.currentUser;
    final initial = (me?.displayName?.isNotEmpty == true
            ? me!.displayName![0]
            : me?.email?.isNotEmpty == true
                ? me!.email![0]
                : '?')
        .toUpperCase();

    return Scaffold(
      backgroundColor: gw.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: SafeArea(
          bottom: false,
          child: Container(
            height: 56,
            color: gw.bg,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              // Hamburger
              GwIconButton(icon: Icons.menu_rounded, color: gw.text, size: 22, onPressed: onMenuClick),
              // Status dot
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(color: gw.green, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              // Title
              Text('GWCORP',
                  style: TextStyle(
                      color: gw.text, fontSize: 15,
                      fontWeight: FontWeight.w800, letterSpacing: -0.2)),
              const Spacer(),
              // User avatar
              GestureDetector(
                onTap: onSettingsClick,
                child: (me?.photoURL != null && me!.photoURL!.isNotEmpty)
                    ? CircleAvatar(
                        radius: 16,
                        backgroundImage: NetworkImage(me.photoURL!),
                      )
                    : Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: gw.greenGlow,
                          border: Border.all(color: gw.green.withOpacity(0.5), width: 1.5),
                        ),
                        child: Center(
                          child: Text(initial,
                              style: TextStyle(color: gw.green, fontSize: 13,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              // Settings
              GwIconButton(icon: Icons.settings_outlined, color: gw.muted, size: 17, onPressed: onSettingsClick),
            ]),
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Scan icon
              Stack(alignment: Alignment.center, children: [
                Container(
                  width: 136, height: 136,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: gw.green.withOpacity(0.12), width: 12),
                  ),
                ),
                Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(
                    color: gw.greenGlow,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: gw.green.withOpacity(0.25)),
                  ),
                  child: Icon(Icons.document_scanner_outlined,
                      color: gw.green, size: 46),
                ),
              ]),
              const SizedBox(height: 28),
              Text('Ready to scan',
                  style: TextStyle(
                      color: gw.text, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'Tag a location and upload waste photos\nfor AI classification.',
                style: TextStyle(color: gw.muted, fontSize: 13, height: 1.55),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              // New Batch button
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton.icon(
                  onPressed: onNewBatch ?? () => context.push('/main/batch'),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('New Batch',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gw.green,
                    foregroundColor: gw.isDark ? gw.bg : Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Sessions synced
              SizedBox(
                width: double.infinity, height: 44,
                child: OutlinedButton.icon(
                  onPressed: onMenuClick,
                  icon: Icon(Icons.history, size: 16, color: gw.muted),
                  label: Text(
                    '$sessionCount session${sessionCount == 1 ? '' : 's'} synced',
                    style: TextStyle(color: gw.muted, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: gw.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
