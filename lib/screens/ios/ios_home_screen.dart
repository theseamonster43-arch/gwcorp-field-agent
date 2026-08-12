import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/models.dart';
import '../../theme/gw_theme.dart';
import '../../widgets/gw_icons.dart';
import '../../widgets/gw_glass.dart';
import '../../widgets/gw_responsive.dart';

/// Compact number: 940 -> '940', 1200 -> '1.2k', 3000 -> '3k'.
String _compact(int n) {
  if (n < 1000) return '$n';
  final s = (n / 1000).toStringAsFixed(1);
  final trimmed = s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  return '${trimmed}k';
}

/// Relative age of a scan. Falls back to the stored date string when the
/// session has no timestamp, which yields '' for legacy rows.
String _relativeTime(ScanSession s) {
  final t = s.timestamp;
  if (t == null) return s.date;
  var diff = DateTime.now().difference(t);
  if (diff.isNegative) diff = Duration.zero;
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('d MMM').format(t);
}

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

/// Home tab — analytics summary plus the most recent scans.
class IosHomeScreen extends StatelessWidget {
  const IosHomeScreen({
    super.key,
    required this.sessions,
    required this.onNewScan,
    required this.onSeeAllScans,
    required this.onOpenAnalytics,
    required this.onOpenChats,
    required this.onOpenAi,
  });

  final List<ScanSession> sessions;
  final VoidCallback onNewScan;
  final VoidCallback onSeeAllScans;
  final VoidCallback onOpenAnalytics;
  final VoidCallback onOpenChats;
  final VoidCallback onOpenAi;

  static String _firstName(User? user) {
    final display = user?.displayName?.trim() ?? '';
    if (display.isNotEmpty) return display.split(' ').first;
    final email = user?.email ?? '';
    if (email.isNotEmpty) {
      final prefix = email.split('@').first.trim();
      if (prefix.isNotEmpty) return prefix;
    }
    return 'Agent';
  }

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    final g = gwGutter(context);
    final wide = gwIsWide(context);
    final user = FirebaseAuth.instance.currentUser;
    final name = _firstName(user);
    final photo = user?.photoURL;

    var items = 0;
    var recyclable = 0;
    var hazardous = 0;
    final locations = <String>{};
    for (final s in sessions) {
      items += s.itemCount;
      recyclable += s.recyclableCount;
      hazardous += s.hazardCount;
      final loc = s.location.trim();
      if (loc.isNotEmpty) locations.add(loc.toLowerCase());
    }
    final recyclablePct = items > 0 ? (recyclable / items * 100).round() : null;
    final recent = sessions.take(4).toList();

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(g, 0, g, gwPageBottom(context)),
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _greeting(),
                    style: TextStyle(
                      color: gw.muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: gw.text,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                ],
              ),
            ),
            // Desktop already has Chats and AI in the rail and the avatar in
            // the title bar, so these would just be duplicates there.
            if (!wide) ...[
              GwGlassIcon(icon: GwIcons.chat, onTap: onOpenChats),
              const SizedBox(width: 8),
              GwGlassIcon(icon: GwIcons.sparkle, onTap: onOpenAi),
              const SizedBox(width: 10),
              if (photo != null)
                CircleAvatar(radius: 19, backgroundImage: NetworkImage(photo))
              else
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: gw.green.withOpacity(.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: gw.green.withOpacity(.40)),
                  ),
                  child: Text(
                    name.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: gw.green,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ]),

          const SizedBox(height: 18),

          // ── Start a scan ──────────────────────────────────────────────────
          GwGlass(
            radius: 24,
            accent: gw.green,
            padding: const EdgeInsets.all(18),
            onTap: onNewScan,
            child: Row(children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: gw.green.withOpacity(.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: GwIcon(GwIcons.scan, size: 26, color: gw.green),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Start a new scan',
                      style: TextStyle(
                        color: gw.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tag a location and upload photos for AI classification',
                      style: TextStyle(color: gw.muted, fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              GwIcon(GwIcons.arrowRight, size: 18, color: gw.green),
            ]),
          ),

          const SizedBox(height: 20),

          // ── Overview ──────────────────────────────────────────────────────
          GwSectionHeader(
            title: 'Overview',
            actionLabel: 'Details',
            onAction: onOpenAnalytics,
          ),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: gwStatColumns(context),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: wide ? 1.32 : 1.18,
            children: [
              GwStatTile(
                icon: GwIcons.box,
                label: 'Items logged',
                value: _compact(items),
                accent: gw.green,
              ),
              GwStatTile(
                icon: GwIcons.recycle,
                label: 'Recyclable',
                value: _compact(recyclable),
                accent: gw.green,
                sub: recyclablePct == null ? null : '$recyclablePct% of items',
              ),
              GwStatTile(
                icon: GwIcons.alert,
                iconWidget: GwHazardIcon(size: 15, color: gw.amber),
                label: 'Hazardous',
                value: _compact(hazardous),
                accent: gw.amber,
              ),
              GwStatTile(
                icon: GwIcons.pin,
                label: 'Locations',
                value: _compact(locations.length),
                accent: gw.green,
              ),
            ],
          ),

          const SizedBox(height: 22),

          // ── Recent scans ──────────────────────────────────────────────────
          GwSectionHeader(
            title: 'Recent scans',
            actionLabel: sessions.isEmpty ? null : 'See all',
            onAction: onSeeAllScans,
          ),
          if (recent.isEmpty)
            GwGlass(
              radius: 18,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GwIcon(GwIcons.scan, size: 36, color: gw.muted),
                  const SizedBox(height: 10),
                  Text(
                    'No scans yet',
                    style: TextStyle(
                      color: gw.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap the + button to run your first scan',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: gw.muted, fontSize: 12),
                  ),
                ],
              ),
            )
          else if (gwCardColumns(context) == 1)
            for (var i = 0; i < recent.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _recentCard(context, gw, recent[i]),
            ]
          else
            // Wraps on a wide screen for the same reason the Scans list does:
            // four stacked cards under a 4-up stat row leaves the page looking
            // like a phone that was stretched.
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recent.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: gwCardColumns(context),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 92,
              ),
              itemBuilder: (_, i) => _recentCard(context, gw, recent[i]),
            ),
        ],
      ),
    );
  }

  Widget _recentCard(BuildContext context, GwColors gw, ScanSession s) {
    final flagged = s.hazardCount > 0;
    final accent = flagged ? gw.amber : gw.green;
    final location = s.location.trim().isEmpty ? 'Unknown location' : s.location;
    final when = _relativeTime(s);

    return GwGlass(
      radius: 18,
      padding: const EdgeInsets.all(14),
      onTap: () => context.push('/main/session/${s.id}'),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withOpacity(.16),
            borderRadius: BorderRadius.circular(14),
          ),
          child: flagged
              ? GwHazardIcon(size: 20, color: accent)
              : GwIcon(GwIcons.checkCircle, size: 20, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: gw.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${s.itemCount} items · ${s.recyclableCount} recyclable',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: gw.muted, fontSize: 11.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (when.isNotEmpty)
              Text(when, style: TextStyle(color: gw.muted, fontSize: 10.5)),
            const SizedBox(height: 4),
            GwIcon(GwIcons.chevronRight, size: 16, color: gw.muted),
          ],
        ),
      ]),
    );
  }
}
