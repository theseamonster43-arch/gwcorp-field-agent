import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../data/models.dart';
import '../data/history_repository.dart';
import '../services/claude_service.dart';
import '../services/image_upload_service.dart';
import '../theme/gw_theme.dart';
import '../widgets/gw_nav_bar.dart';
import 'batch_setup_screen.dart';

class ResultsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onDone;
  const ResultsScreen({super.key, this.onBack, this.onDone});
  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final _results = <ClassificationResult>[];
  bool   _analysing    = true;
  bool   _saving       = false;
  int    _done         = 0;
  String _saveStatus   = '';

  @override
  void initState() {
    super.initState();
    _analyse();
  }

  Future<void> _analyse() async {
    for (int i = 0; i < BatchState.images.length; i++) {
      final items = await ClaudeService.classify(File(BatchState.images[i]));
      final tagged = items.map((r) => r.withPhotoIndex(i)).toList();
      if (mounted) setState(() { _results.addAll(tagged); _done++; });
    }
    if (mounted) setState(() => _analysing = false);
  }

  Future<void> _save() async {
    setState(() { _saving = true; _saveStatus = ''; });
    final me        = FirebaseAuth.instance.currentUser;
    final now       = DateTime.now();
    final sessionId = DateFormat('yyyyMMdd-HHmmss').format(now);

    // Upload each scanned image to Cloudinary
    final imageUrls  = <String>[];
    final total      = BatchState.images.length;
    int   uploaded   = 0;
    int   failed     = 0;
    for (int i = 0; i < total; i++) {
      if (mounted) setState(() => _saveStatus = 'Uploading photo ${i + 1} / $total…');
      final url = await ImageUploadService.upload(BatchState.images[i]);
      if (url != null) {
        imageUrls.add(url);
        uploaded++;
      } else {
        // Keep slot so photoIndex still lines up — use empty string as placeholder
        imageUrls.add('');
        failed++;
      }
    }
    if (mounted && failed > 0) {
      setState(() => _saveStatus = '$failed photo(s) failed to upload — check Cloudinary preset is Unsigned');
      await Future.delayed(const Duration(seconds: 3));
    }

    final session = ScanSession(
      id:              sessionId,
      location:        BatchState.location,
      date:            DateFormat('MMM d, yyyy').format(now),
      itemCount:       _results.length,
      hazardCount:     _results.where((r) => r.hazardLevel != 'None').length,
      recyclableCount: _results.where((r) => r.recyclable).length,
      userEmail:       me?.email ?? '',
      items:           List.from(_results),
      timestamp:       now,
      imageUrls:       imageUrls,
    );
    await HistoryRepository.saveSession(session);
    if (mounted) {
      BatchState.reset();
      if (widget.onDone != null) {
        widget.onDone!();
      } else {
        context.go('/main');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    final total    = BatchState.images.length;
    final hazards  = _results.where((r) => r.hazardLevel != 'None').length;
    final recyc    = _results.where((r) => r.recyclable).length;
    final step     = _analysing ? 2 : 3;

    return Scaffold(
      backgroundColor: gw.bg,
      appBar: GwNavBar(
        title: 'Analysis Results',
        onBack: widget.onBack ?? () => context.pop(),
      ),
      body: Column(children: [
        ScanStepBar(gw: gw, current: step),

        // Scanned photos strip
        if (BatchState.images.isNotEmpty)
          _LocalPhotoStrip(paths: List.from(BatchState.images), gw: gw),

        if (_analysing) ...[
          LinearProgressIndicator(
            value: total > 0 ? _done / total : null,
            backgroundColor: gw.bg3,
            color: gw.green,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text('Analysing $_done / $total images…',
                style: TextStyle(color: gw.muted, fontSize: 13)),
          ),
        ],

        if (_results.isNotEmpty)
          Container(
            color: gw.bg2,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              _stat(gw, '${_results.length}', 'Items', gw.text),
              _stat(gw, '$recyc', 'Recyclable', gw.green),
              _stat(gw, '$hazards', 'Hazards', hazards > 0 ? gw.amber : gw.muted),
            ]),
          ),

        Expanded(
          child: _results.isEmpty && !_analysing
              ? Center(child: Text('No items detected',
                  style: TextStyle(color: gw.muted, fontSize: 14)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _results.length,
                  itemBuilder: (_, i) => _ResultCard(
                    result: _results[i],
                    localPaths: List.from(BatchState.images),
                  ),
                ),
        ),

        if (!_analysing && _results.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).padding.bottom + 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (_saveStatus.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _saveStatus,
                    style: TextStyle(
                      color: _saveStatus.contains('failed') ? gw.amber : gw.muted,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gw.green,
                    foregroundColor: gw.isDark ? gw.bg : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                          const SizedBox(width: 10),
                          Text(_saveStatus.isEmpty ? 'Saving…' : _saveStatus,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ])
                      : const Text('Save Session',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _stat(GwColors gw, String val, String label, Color c) => Expanded(
    child: Column(children: [
      Text(val, style: TextStyle(color: c, fontSize: 20, fontWeight: FontWeight.w800)),
      Text(label, style: TextStyle(color: gw.muted, fontSize: 11)),
    ]),
  );
}

class _ResultCard extends StatelessWidget {
  final ClassificationResult result;
  final List<String> localPaths;
  const _ResultCard({required this.result, required this.localPaths});

  void _viewPhoto(BuildContext context) {
    final idx = result.photoIndex;
    if (idx == null || idx >= localPaths.length) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(children: [
          InteractiveViewer(
            child: Center(
              child: Image.file(File(localPaths[idx]), fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.broken_image, color: Colors.white54, size: 48)),
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

  @override
  Widget build(BuildContext context) {
    final gw       = GwTheme.of(context);
    final isHazard = result.hazardLevel != 'None';
    final accent   = isHazard ? gw.amber : gw.green;
    final idx      = result.photoIndex;
    final hasPhoto = idx != null && idx < localPaths.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: gw.bg2, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Photo thumbnail — tap to view full-screen
        GestureDetector(
          onTap: hasPhoto ? () => _viewPhoto(context) : null,
          child: Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: hasPhoto ? accent.withOpacity(0.4) : gw.border),
              color: gw.bg3,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: hasPhoto
                  ? Image.file(File(localPaths[idx!]), fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.image_not_supported_outlined, color: gw.muted, size: 22))
                  : Icon(isHazard ? Icons.warning_amber_outlined : Icons.recycling,
                      color: accent, size: 22),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Item info
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(result.itemName,
                style: TextStyle(color: gw.text, fontSize: 14, fontWeight: FontWeight.w600))),
            Text('${result.confidence}%', style: TextStyle(color: gw.muted, fontSize: 11)),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, children: [
            _chip(gw, result.wasteType, gw.muted),
            _chip(gw, result.recommendedAction, accent),
            if (result.recyclable) _chip(gw, 'Recyclable', gw.green),
            if (isHazard) _chip(gw, '⚠ ${result.hazardLevel}', gw.amber),
          ]),
        ])),
      ]),
    );
  }

  Widget _chip(GwColors gw, String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(99),
      border: Border.all(color: c.withOpacity(0.25)),
    ),
    child: Text(t, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w600)),
  );
}

// Horizontal strip of local photos (used during active scan before upload)
class _LocalPhotoStrip extends StatelessWidget {
  final List<String> paths;
  final GwColors gw;
  const _LocalPhotoStrip({required this.paths, required this.gw});

  void _viewFull(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(children: [
          InteractiveViewer(
            child: Center(
              child: Image.file(
                File(paths[index]),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
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
          if (paths.length > 1)
            Positioned(
              bottom: 16, left: 0, right: 0,
              child: Center(
                child: Text('${index + 1} / ${paths.length}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: gw.bg2,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Row(children: [
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
              child: Text('${paths.length}',
                  style: TextStyle(color: gw.green, fontSize: 9,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        SizedBox(
          height: 88,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: paths.length,
            itemBuilder: (ctx, i) => GestureDetector(
              onTap: () => _viewFull(ctx, i),
              child: Container(
                margin: EdgeInsets.only(right: i < paths.length - 1 ? 8 : 0),
                width: 88, height: 88,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: gw.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(paths[i]),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: gw.bg3,
                      child: Icon(Icons.image_not_supported_outlined,
                          color: gw.muted, size: 28),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
