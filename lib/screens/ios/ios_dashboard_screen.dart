import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show CircleAvatar;
import 'package:go_router/go_router.dart';

class IosDashboardScreen extends StatelessWidget {
  final VoidCallback onMenuClick;
  final VoidCallback onViewChats;
  final int sessionCount;

  const IosDashboardScreen({
    super.key,
    required this.onMenuClick,
    required this.onViewChats,
    this.sessionCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;
    final initial = (me?.displayName?.isNotEmpty == true
            ? me!.displayName![0]
            : me?.email?.isNotEmpty == true
                ? me!.email![0]
                : '?')
        .toUpperCase();

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onMenuClick,
          child: const Icon(CupertinoIcons.line_horizontal_3),
        ),
        middle: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 6, height: 6,
            decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          const Text('GWCORP', style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
        trailing: me?.photoURL != null
            ? CircleAvatar(radius: 15, backgroundImage: NetworkImage(me!.photoURL!))
            : Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF22C55E).withOpacity(0.15),
                  border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.5)),
                ),
                child: Center(
                  child: Text(initial,
                      style: const TextStyle(color: Color(0xFF22C55E),
                          fontSize: 12, fontWeight: FontWeight.w800)),
                ),
              ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Scan icon — LiquidGlass card
            GestureDetector(
              onTap: () => context.push('/main/batch'),
              child: LiquidGlassContainer(
                config: LiquidGlassConfig(
                  effect: CNGlassEffect.regular,
                  shape: CNGlassEffectShape.rect,
                  cornerRadius: 36,
                  interactive: true,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(30),
                  child: Icon(CupertinoIcons.qrcode_viewfinder,
                      size: 90, color: Color(0xFF22C55E)),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text('Ready to scan',
                style: CupertinoTheme.of(context)
                    .textTheme
                    .navLargeTitleTextStyle
                    .copyWith(fontSize: 22)),
            const SizedBox(height: 8),
            Text(
              'Tag a location and upload waste photos\nfor AI classification.',
              style: TextStyle(
                fontSize: 13, height: 1.55,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            CupertinoTheme(
              data: const CupertinoThemeData(primaryColor: Color(0xFF22C55E)),
              child: SizedBox(
                width: double.infinity,
                child: CNButton(
                  label: 'New Batch',
                  icon: CNSymbol('plus'),
                  config: CNButtonConfig(style: CNButtonStyle.filled),
                  onPressed: () => context.push('/main/batch'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: CNButton(
                label: '$sessionCount session${sessionCount == 1 ? '' : 's'} synced',
                icon: CNSymbol('clock.arrow.circlepath'),
                config: CNButtonConfig(style: CNButtonStyle.glass),
                onPressed: onMenuClick,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
