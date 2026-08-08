import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../theme/gw_theme.dart';
import '../../widgets/gw_icons.dart';
import '../../widgets/gw_glass.dart';

class IosAnalyticsScreen extends StatelessWidget {
  const IosAnalyticsScreen({super.key, required this.sessions});

  final List<ScanSession> sessions;

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);

    final totalScans = sessions.length;

    var totalItems = 0;
    var totalRecyclable = 0;
    var totalHazard = 0;
    for (final s in sessions) {
      totalItems += s.itemCount;
      totalRecyclable += s.recyclableCount;
      totalHazard += s.hazardCount;
    }

    final recyclePct =
        totalItems == 0 ? 0 : (totalRecyclable / totalItems * 100).round();

    final locationSet = <String>{};
    for (final s in sessions) {
      final loc = s.location.trim();
      if (loc.isNotEmpty) locationSet.add(loc);
    }
    final locations = locationSet.length;

    final avgItems = totalScans == 0 ? 0.0 : totalItems / totalScans;

    final wasteCounts = <String, int>{};
    final hazardCounts = <String, int>{};
    for (final s in sessions) {
      for (final item in s.items) {
        final type = item.wasteType.trim();
        if (type.isNotEmpty) {
          wasteCounts[type] = (wasteCounts[type] ?? 0) + 1;
        }
        final level = item.hazardLevel.trim().toLowerCase();
        if (level.isNotEmpty && level != 'none') {
          hazardCounts[level] = (hazardCounts[level] ?? 0) + 1;
        }
      }
    }

    final wasteTypes = wasteCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topWaste = wasteTypes.take(5).toList();
    final maxCount = topWaste.isEmpty ? 0 : topWaste.first.value;

    final hazardBreakdown = hazardCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final last7 = sessions
        .where((s) => s.timestamp != null && s.timestamp!.isAfter(cutoff))
        .toList();

    final recent = sessions.take(5).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
          children: [
            Text(
              'Analytics',
              style: TextStyle(
                color: gw.text,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Your field impact',
              style: TextStyle(color: gw.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 18),
            GwGlass(
              radius: 24,
              padding: const EdgeInsets.all(20),
              accent: gw.green,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GwIcon(GwIcons.recycle, size: 34, color: gw.green),
                  const SizedBox(height: 10),
                  Text(
                    '$totalRecyclable',
                    style: TextStyle(
                      color: gw.text,
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.5,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'items diverted from landfill',
                    style: TextStyle(color: gw.muted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: (recyclePct / 100).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: gw.green.withOpacity(.15),
                      valueColor: AlwaysStoppedAnimation<Color>(gw.green),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$recyclePct% of everything you logged',
                    style: TextStyle(
                      color: gw.green,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const GwSectionHeader(title: 'At a glance'),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.18,
              children: [
                GwStatTile(
                  icon: GwIcons.scan,
                  label: 'Scans run',
                  value: '$totalScans',
                  accent: gw.green,
                  sub: '${last7.length} this week',
                ),
                GwStatTile(
                  icon: GwIcons.box,
                  label: 'Items logged',
                  value: '$totalItems',
                  accent: gw.green,
                  sub: '${avgItems.toStringAsFixed(1)} avg / scan',
                ),
                GwStatTile(
                  icon: GwIcons.alert,
                  iconWidget: GwHazardIcon(size: 15, color: gw.amber),
                  label: 'Hazardous',
                  value: '$totalHazard',
                  accent: gw.amber,
                  sub: totalHazard == 0 ? 'All clear' : 'Needs handling',
                ),
                GwStatTile(
                  icon: GwIcons.pin,
                  label: 'Locations',
                  value: '$locations',
                  accent: gw.green,
                  sub: locations == 1 ? '1 site covered' : '$locations sites covered',
                ),
              ],
            ),
            const SizedBox(height: 22),
            const GwSectionHeader(title: 'Waste breakdown'),
            GwGlass(
              radius: 20,
              padding: const EdgeInsets.all(16),
              child: topWaste.isEmpty
                  ? Center(
                      child: Text(
                        'No items classified yet',
                        style: TextStyle(color: gw.muted, fontSize: 12.5),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < topWaste.length; i++) ...[
                          if (i != 0) const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  topWaste[i].key,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: gw.text,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                '${topWaste[i].value}',
                                style: TextStyle(
                                  color: gw.muted,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: maxCount == 0
                                  ? 0.0
                                  : (topWaste[i].value / maxCount)
                                      .clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: gw.green.withOpacity(.12),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(gw.green),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 22),
            const GwSectionHeader(title: 'Hazard levels'),
            if (hazardBreakdown.isEmpty)
              GwGlass(
                radius: 20,
                padding: const EdgeInsets.all(18),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GwIcon(GwIcons.shield, size: 18, color: gw.green),
                    const SizedBox(width: 8),
                    Text(
                      'No hazardous material recorded',
                      style: TextStyle(
                        color: gw.text,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final entry in hazardBreakdown)
                    _hazardChip(gw, entry.key, entry.value),
                ],
              ),
            const SizedBox(height: 22),
            const GwSectionHeader(title: 'Recent activity'),
            GwGlass(
              radius: 20,
              padding: const EdgeInsets.all(16),
              child: recent.isEmpty
                  ? Center(
                      child: Text(
                        'Nothing logged yet',
                        style: TextStyle(color: gw.muted, fontSize: 12.5),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < recent.length; i++) ...[
                          if (i != 0) const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: recent[i].hazardCount > 0
                                      ? gw.amber
                                      : gw.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  recent[i].location.trim().isEmpty
                                      ? 'Unknown location'
                                      : recent[i].location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: gw.text,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${recent[i].itemCount} items',
                                style: TextStyle(
                                  color: gw.muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hazardChip(GwColors gw, String level, int count) {
    final Color levelColour;
    if (level == 'high') {
      levelColour = gw.red;
    } else if (level == 'medium') {
      levelColour = gw.amber;
    } else {
      levelColour = gw.green;
    }

    final label = level.isEmpty
        ? level
        : '${level[0].toUpperCase()}${level.substring(1)}';

    return GwGlass(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      accent: levelColour,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: levelColour,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: gw.text,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
              color: levelColour,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
