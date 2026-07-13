import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../theme/gw_theme.dart';
import '../widgets/gw_nav_bar.dart';

class BatchState {
  static String location = '';
  static String notes    = '';
  static final images    = <String>[];
  static final results   = [];

  static void reset() { location = ''; notes = ''; images.clear(); results.clear(); }
}

class BatchSetupScreen extends StatefulWidget {
  final VoidCallback? onDone;
  final VoidCallback? onContinue;
  const BatchSetupScreen({super.key, this.onDone, this.onContinue});
  @override
  State<BatchSetupScreen> createState() => _BatchSetupScreenState();
}

class _BatchSetupScreenState extends State<BatchSetupScreen> {
  final _locCtrl = TextEditingController();
  final _date    = DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void dispose() { _locCtrl.dispose(); super.dispose(); }

  void _continue() {
    if (_locCtrl.text.trim().isEmpty) return;
    BatchState.reset();
    BatchState.location = _locCtrl.text.trim();
    BatchState.notes    = _date;
    if (widget.onContinue != null) {
      widget.onContinue!();
    } else {
      context.push('/main/camera');
    }
  }

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    return Scaffold(
      backgroundColor: gw.bg,
      appBar: GwNavBar(
        title: 'New Batch',
        onBack: widget.onDone ?? () => context.pop(),
      ),
      body: Column(children: [
        // ── Step indicator ────────────────────────────────────
        ScanStepBar(gw: gw, current: 0),
        // ── Content card ──────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: gw.bg2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: gw.border),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 6, height: 6,
                      decoration: BoxDecoration(color: gw.green, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text('TAG THIS BATCH',
                      style: TextStyle(color: gw.green, fontSize: 10,
                          fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                ]),
                const SizedBox(height: 20),

                _fieldLabel(gw, 'LOCATION'),
                const SizedBox(height: 8),
                _field(gw, _locCtrl, 'e.g. Al Quoz Industrial Area'),
                const SizedBox(height: 16),

                _fieldLabel(gw, 'DATE'),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: gw.bg3,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: gw.border),
                  ),
                  child: Text(_date,
                      style: TextStyle(color: gw.text, fontSize: 13)),
                ),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: _continue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gw.green,
                      foregroundColor: gw.isDark ? gw.bg : Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Continue', style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 18),
                        SizedBox(width: 4),
                        Text('Select Photos', style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _fieldLabel(GwColors gw, String t) => Row(children: [
    Container(width: 4, height: 4,
        decoration: BoxDecoration(color: gw.muted, shape: BoxShape.circle)),
    const SizedBox(width: 6),
    Text(t, style: TextStyle(color: gw.muted, fontSize: 9,
        fontWeight: FontWeight.w700, letterSpacing: 1.1)),
  ]);

  Widget _field(GwColors gw, TextEditingController ctrl, String hint) =>
      TextField(
        controller: ctrl,
        style: TextStyle(color: gw.text, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: gw.muted, fontSize: 13),
          filled: true, fillColor: gw.bg3,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: gw.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: gw.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: gw.green.withOpacity(0.6), width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      );
}

// ── Step indicator bar (shared across scan flow screens) ──────────────────────

class ScanStepBar extends StatelessWidget {
  final GwColors gw;
  final int current; // 0=Tag, 1=Photos, 2=Analyse, 3=Results
  const ScanStepBar({super.key, required this.gw, required this.current});

  static const _steps = ['Tag', 'Photos', 'Analyse', 'Results'];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: gw.bg2,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(children: [
        Row(children: List.generate(_steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final stepIdx = i ~/ 2;
            final done = stepIdx < current;
            return Expanded(child: Container(
              height: 1.5,
              color: done ? gw.green : gw.border,
            ));
          }
          final stepIdx = i ~/ 2;
          final done    = stepIdx < current;
          final active  = stepIdx == current;
          return _StepDot(
            gw: gw, number: stepIdx + 1,
            label: _steps[stepIdx],
            done: done, active: active,
          );
        })),
      ]),
    );
  }
}

class _StepDot extends StatelessWidget {
  final GwColors gw;
  final int number;
  final String label;
  final bool done;
  final bool active;
  const _StepDot({required this.gw, required this.number, required this.label,
      required this.done, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = (done || active) ? gw.green : gw.muted;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 26, height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? gw.green : done ? gw.greenGlow : gw.bg3,
          border: Border.all(
              color: (done || active) ? gw.green : gw.border, width: 1.5),
        ),
        child: Center(
          child: done
              ? Icon(Icons.check, size: 13, color: gw.green)
              : Text('$number',
                  style: TextStyle(
                      color: active ? (gw.isDark ? gw.bg : Colors.white) : gw.muted,
                      fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
    ]);
  }
}
