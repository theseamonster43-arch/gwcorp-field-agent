import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models.dart';
import '../../theme/gw_theme.dart';
import '../../widgets/gw_icons.dart';
import '../../widgets/gw_glass.dart';

/// Scans tab — the full scan history. Replaces the old slide-out drawer.
class IosScansScreen extends StatefulWidget {
  const IosScansScreen({super.key, required this.sessions, required this.onNewScan});

  final List<ScanSession> sessions;
  final VoidCallback onNewScan;

  @override
  State<IosScansScreen> createState() => _IosScansScreenState();
}

class _IosScansScreenState extends State<IosScansScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  int _filter = 0; // 0 All, 1 Hazardous, 2 Clean

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ScanSession> get _filtered {
    var list = widget.sessions;
    if (_filter == 1) {
      list = list.where((s) => s.hazardCount > 0).toList();
    } else if (_filter == 2) {
      list = list.where((s) => s.hazardCount == 0).toList();
    }
    if (_query.isNotEmpty) {
      list = list.where((s) {
        if (s.location.toLowerCase().contains(_query)) return true;
        for (final i in s.items) {
          if (i.itemName.toLowerCase().contains(_query)) return true;
          if (i.wasteType.toLowerCase().contains(_query)) return true;
        }
        return false;
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    final filtered = _filtered;
    final active = _query.isNotEmpty || _filter != 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Text(
                      'Scans',
                      style: TextStyle(
                        color: gw.text,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${filtered.length} of ${widget.sessions.length}',
                      style: TextStyle(
                        color: gw.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  GwGlass(
                    radius: 16,
                    blur: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        hintText: 'Search location or item',
                        hintStyle: TextStyle(color: gw.muted, fontSize: 13.5),
                        icon: GwIcon(GwIcons.search, size: 18, color: gw.muted),
                      ),
                      style: TextStyle(color: gw.text, fontSize: 13.5),
                      cursorColor: gw.green,
                      onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    _chip(0, 'All'),
                    const SizedBox(width: 8),
                    _chip(1, 'Hazardous'),
                    const SizedBox(width: 8),
                    _chip(2, 'Clean'),
                  ]),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? _empty(gw, active)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _row(gw, filtered[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(int index, String label) {
    final gw = GwTheme.of(context);
    final selected = _filter == index;
    const padding = EdgeInsets.symmetric(horizontal: 14, vertical: 8);

    if (selected) {
      return GestureDetector(
        onTap: () => setState(() => _filter = index),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: gw.green.withOpacity(.18),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: gw.green, width: 1),
          ),
          child: Text(
            label,
            style: TextStyle(color: gw.green, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return GwGlass(
      radius: 99,
      blur: 20,
      padding: padding,
      onTap: () => setState(() => _filter = index),
      child: Text(
        label,
        style: TextStyle(color: gw.muted, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _row(GwColors gw, ScanSession s) {
    final hazard = s.hazardCount > 0;
    final c = hazard ? gw.amber : gw.green;
    final when = s.timestamp != null
        ? DateFormat('d MMM').format(s.timestamp!)
        : (s.date.isNotEmpty ? s.date : '');

    return GwGlass(
      radius: 18,
      padding: const EdgeInsets.all(14),
      onTap: () => context.push('/main/session/${s.id}'),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.withOpacity(.16),
            borderRadius: BorderRadius.circular(14),
          ),
          child: hazard
              ? GwHazardIcon(size: 22, color: c)
              : GwIcon(GwIcons.checkCircle, size: 22, color: c),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                s.location.isNotEmpty ? s.location : 'Unknown location',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: gw.text,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _meta('${s.itemCount} items', gw.green),
                  const SizedBox(width: 6),
                  _meta('${s.recyclableCount} recyclable', gw.green),
                  if (s.hazardCount > 0) ...[
                    const SizedBox(width: 6),
                    _meta('${s.hazardCount} hazard', gw.amber),
                  ],
                ]),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(when, style: TextStyle(color: gw.muted, fontSize: 10.5)),
            const SizedBox(height: 4),
            GwIcon(GwIcons.chevronRight, size: 16, color: gw.muted),
          ],
        ),
      ]),
    );
  }

  Widget _meta(String label, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: c.withOpacity(.14),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(color: c, fontSize: 10.5, fontWeight: FontWeight.w700),
        ),
      );

  Widget _empty(GwColors gw, bool active) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GwIcon(
              active ? GwIcons.search : GwIcons.scan,
              size: 40,
              color: gw.muted,
            ),
            const SizedBox(height: 12),
            Text(
              active ? 'No matching scans' : 'No scans yet',
              style: TextStyle(color: gw.text, fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              active ? 'Try a different search' : 'Tap the + button to run your first scan',
              textAlign: TextAlign.center,
              style: TextStyle(color: gw.muted, fontSize: 12.5),
            ),
            if (!active) ...[
              const SizedBox(height: 16),
              GwGlass(
                radius: 14,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                accent: gw.green,
                onTap: widget.onNewScan,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GwIcon(GwIcons.plus, size: 18, color: gw.green),
                    const SizedBox(width: 8),
                    Text(
                      'New scan',
                      style: TextStyle(
                        color: gw.green,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
