import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/gw_theme.dart';
import '../widgets/gw_nav_bar.dart';
import 'batch_setup_screen.dart';

class CameraScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onContinue;
  const CameraScreen({super.key, this.onBack, this.onContinue});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final _picker = ImagePicker();

  Future<void> _pick(ImageSource src) async {
    final xf = await _picker.pickImage(source: src, imageQuality: 85);
    if (xf == null) return;
    setState(() => BatchState.images.add(xf.path));
  }

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
                File(BatchState.images[index]),
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
          Positioned(
            top: 16, left: 16,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                setState(() => BatchState.images.removeAt(index));
              },
              child: Container(
                width: 36, height: 36,
                decoration: const BoxDecoration(
                    color: Colors.redAccent, shape: BoxShape.circle),
                child: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
              ),
            ),
          ),
          if (BatchState.images.length > 1)
            Positioned(
              bottom: 16, left: 0, right: 0,
              child: Center(
                child: Text('${index + 1} / ${BatchState.images.length}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            ),
        ]),
      ),
    );
  }

  void _goAnalyse() {
    if (widget.onContinue != null) {
      widget.onContinue!();
    } else {
      context.push('/main/results');
    }
  }

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    return Scaffold(
      backgroundColor: gw.bg,
      appBar: GwNavBar(
        title: 'Capture Items',
        onBack: widget.onBack ?? () => context.pop(),
        actions: [
          if (BatchState.images.isNotEmpty)
            TextButton(
              onPressed: _goAnalyse,
              child: Text('Analyse (${BatchState.images.length})',
                  style: TextStyle(color: gw.green, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: Column(children: [
        ScanStepBar(gw: gw, current: 1),
        Expanded(
          child: BatchState.images.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.camera_alt_outlined, size: 48, color: gw.muted),
                  const SizedBox(height: 12),
                  Text('No photos yet', style: TextStyle(color: gw.text, fontSize: 15,
                      fontWeight: FontWeight.w600)),
                  Text('Use the buttons below to add waste photos',
                      style: TextStyle(color: gw.muted, fontSize: 13)),
                ]))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
                  itemCount: BatchState.images.length,
                  itemBuilder: (ctx, i) => GestureDetector(
                    onTap: () => _viewFull(ctx, i),
                    child: Stack(children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(File(BatchState.images[i]), fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(top: 4, right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => BatchState.images.removeAt(i)),
                          child: Container(
                            width: 22, height: 22,
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
        ),
        Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, bottom: MediaQuery.of(context).padding.bottom + 16, top: 12),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: gw.text,
                    side: BorderSide(color: gw.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gw.green,
                    foregroundColor: gw.isDark ? gw.bg : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
            if (BatchState.images.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton.icon(
                  onPressed: _goAnalyse,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: Text('Analyse (${BatchState.images.length} photos)',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gw.green,
                    foregroundColor: gw.isDark ? gw.bg : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}
