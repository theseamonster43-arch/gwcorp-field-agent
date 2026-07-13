import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/models.dart';
import '../data/history_repository.dart';
import '../theme/gw_theme.dart';
import '../widgets/gw_nav_bar.dart';

class SessionDetailScreen extends StatelessWidget {
  final String sessionId;
  final VoidCallback? onBack;
  const SessionDetailScreen({super.key, required this.sessionId, this.onBack});

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    return Scaffold(
      backgroundColor: gw.bg,
      appBar: GwNavBar(title: 'Session Detail', onBack: onBack ?? () => context.pop()),
      body: FutureBuilder<ScanSession?>(
        future: HistoryRepository.getSession(sessionId),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final s = snap.data;
          if (s == null) {
            return Center(child: Text('Session not found',
                style: TextStyle(color: gw.muted)));
          }
          return ListView(padding: const EdgeInsets.all(16), children: [
            // Scanned photos strip
            if (s.imageUrls.any((u) => u.isNotEmpty)) ...[
              _ImageStrip(urls: s.imageUrls.where((u) => u.isNotEmpty).toList(), gw: gw),
              const SizedBox(height: 16),
            ],
            // Header card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: gw.bg2, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: gw.border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.id, style: TextStyle(color: gw.green, fontSize: 10,
                    fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(s.location, style: TextStyle(color: gw.text, fontSize: 18,
                    fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(s.date, style: TextStyle(color: gw.muted, fontSize: 12)),
                const SizedBox(height: 12),
                Row(children: [
                  _statChip(gw, '${s.itemCount}', 'items', gw.text),
                  const SizedBox(width: 8),
                  _statChip(gw, '${s.recyclableCount}', 'recyclable', gw.green),
                  const SizedBox(width: 8),
                  if (s.hazardCount > 0)
                    _statChip(gw, '${s.hazardCount}', 'hazards', gw.amber),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            // Breakdown chart
            if (s.itemCount > 0)
              _BreakdownChart(session: s, gw: gw),
            const SizedBox(height: 16),
            Text('ITEMS', style: TextStyle(color: gw.muted, fontSize: 9,
                fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 8),
            ...s.items.map((item) {
              final isHazard = item.hazardLevel != 'None';
              final accent   = isHazard ? gw.amber : gw.green;
              final idx      = item.photoIndex;
              final rawUrl   = (idx != null && idx < s.imageUrls.length)
                  ? s.imageUrls[idx] : null;
              final photoUrl = (rawUrl != null && rawUrl.isNotEmpty) ? rawUrl : null;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: gw.bg2, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withOpacity(0.15)),
                ),
                child: Row(children: [
                  // Photo thumbnail — tap to view full-screen
                  GestureDetector(
                    onTap: photoUrl != null
                        ? () => _showPhoto(context, photoUrl)
                        : null,
                    child: Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: photoUrl != null
                              ? accent.withOpacity(0.35)
                              : gw.border),
                        color: gw.bg3,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: photoUrl != null
                            ? CachedNetworkImage(
                                imageUrl: photoUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Center(
                                  child: SizedBox(width: 14, height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5, color: gw.green))),
                                errorWidget: (_, __, ___) => Icon(
                                  isHazard ? Icons.warning_amber_outlined : Icons.recycling,
                                  color: accent, size: 20),
                              )
                            : Icon(
                                isHazard ? Icons.warning_amber_outlined : Icons.recycling,
                                color: accent, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.itemName, style: TextStyle(color: gw.text, fontSize: 13,
                        fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('${item.wasteType} · ${item.recommendedAction}',
                        style: TextStyle(color: gw.muted, fontSize: 11)),
                  ])),
                  Text('${item.confidence}%', style: TextStyle(color: gw.muted, fontSize: 10)),
                ]),
              );
            }),
          ]);
        },
      ),
    );
  }

  void _showPhoto(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(children: [
          InteractiveViewer(
            child: Center(
              child: CachedNetworkImage(
                imageUrl: url, fit: BoxFit.contain,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(color: Colors.white54)),
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.broken_image, color: Colors.white54, size: 48),
              ),
            ),
          ),
          Positioned(top: 16, right: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 36, height: 36,
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _statChip(GwColors gw, String val, String label, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(99),
      border: Border.all(color: c.withOpacity(0.2)),
    ),
    child: Text('$val $label', style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}

class _ImageStrip extends StatelessWidget {
  final List<String> urls;
  final GwColors gw;
  const _ImageStrip({required this.urls, required this.gw});

  void _viewFull(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(children: [
          InteractiveViewer(
            child: Center(
              child: CachedNetworkImage(
                imageUrl: urls[index],
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(color: Colors.white54)),
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.broken_image, color: Colors.white54, size: 48),
              ),
            ),
          ),
          Positioned(
            top: 16, right: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 36, height: 36,
                decoration: const BoxDecoration(
                  color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
          if (urls.length > 1)
            Positioned(
              bottom: 16, left: 0, right: 0,
              child: Center(
                child: Text('${index + 1} / ${urls.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('SCANNED PHOTOS',
          style: TextStyle(color: gw.muted, fontSize: 9,
              fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: gw.greenGlow, borderRadius: BorderRadius.circular(99),
            border: Border.all(color: gw.border),
          ),
          child: Text('${urls.length}',
            style: TextStyle(color: gw.green, fontSize: 9, fontWeight: FontWeight.w700)),
        ),
      ]),
      const SizedBox(height: 8),
      SizedBox(
        height: 120,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: urls.length,
          itemBuilder: (ctx, i) => GestureDetector(
            onTap: () => _viewFull(ctx, i),
            child: Container(
              margin: EdgeInsets.only(right: i < urls.length - 1 ? 8 : 0),
              width: 120, height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: gw.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: urls[i],
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: gw.bg2,
                    child: Center(
                      child: SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: gw.green)),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: gw.bg2,
                    child: Icon(Icons.image_not_supported_outlined,
                        color: gw.muted, size: 28),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

// ── Donut chart: recyclable / hazardous / other breakdown ─────────────────────

class _BreakdownChart extends StatelessWidget {
  final ScanSession session;
  final GwColors gw;
  const _BreakdownChart({required this.session, required this.gw});

  @override
  Widget build(BuildContext context) {
    final total  = session.itemCount;
    final recyc  = session.recyclableCount;
    final hazard = session.hazardCount;
    final other  = (total - recyc - hazard).clamp(0, total);

    final segments = <_Segment>[
      if (recyc  > 0) _Segment(recyc  / total, gw.green),
      if (hazard > 0) _Segment(hazard / total, gw.amber),
      if (other  > 0) _Segment(other  / total, gw.muted.withOpacity(0.45)),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: gw.bg2, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gw.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('BREAKDOWN', style: TextStyle(color: gw.muted, fontSize: 9,
            fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 16),
        Row(children: [
          SizedBox(
            width: 100, height: 100,
            child: CustomPaint(painter: _DonutPainter(segments: segments)),
          ),
          const SizedBox(width: 20),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (recyc  > 0) _legendRow(gw, gw.green, 'Recyclable', recyc,  total),
              if (hazard > 0) _legendRow(gw, gw.amber,  'Hazardous',  hazard, total),
              if (other  > 0) _legendRow(gw, gw.muted.withOpacity(0.55), 'Other', other, total),
            ],
          )),
        ]),
      ]),
    );
  }

  Widget _legendRow(GwColors gw, Color c, String label, int count, int total) {
    final pct = (count / total * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label,
            style: TextStyle(color: gw.text, fontSize: 12, fontWeight: FontWeight.w500))),
        Text('$count  ', style: TextStyle(color: gw.text, fontSize: 12,
            fontWeight: FontWeight.w700)),
        Text('$pct%', style: TextStyle(color: gw.muted, fontSize: 11)),
      ]),
    );
  }
}

class _Segment {
  final double fraction;
  final Color color;
  const _Segment(this.fraction, this.color);
}

class _DonutPainter extends CustomPainter {
  final List<_Segment> segments;
  const _DonutPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final cx    = size.width  / 2;
    final cy    = size.height / 2;
    final r     = math.min(cx, cy);
    final rect  = Rect.fromCircle(center: Offset(cx, cy), radius: r - 4);
    const gap   = 0.03; // radians between segments
    const start = -math.pi / 2;
    double angle = start;

    for (final seg in segments) {
      final sweep = seg.fraction * (math.pi * 2) - gap;
      if (sweep <= 0) continue;
      final paint = Paint()
        ..color     = seg.color
        ..style     = PaintingStyle.stroke
        ..strokeWidth = r * 0.30
        ..strokeCap  = StrokeCap.round;
      canvas.drawArc(rect, angle + gap / 2, sweep, false, paint);
      angle += seg.fraction * math.pi * 2;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.segments != segments;
}
