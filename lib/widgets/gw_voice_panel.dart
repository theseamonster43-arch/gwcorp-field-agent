import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../services/claude_service.dart';
import '../theme/gw_theme.dart';
import 'gw_glass.dart';
import 'gw_icons.dart';

/// What the panel is currently doing, reported up so the screen can show the
/// conversation large and centred rather than cramped inside the bar.
class GwVoiceState {
  final String heard;
  final String reply;
  final bool listening;
  final bool thinking;
  final String? error;

  const GwVoiceState({
    this.heard = '',
    this.reply = '',
    this.listening = false,
    this.thinking = false,
    this.error,
  });
}

/// Hands-free assistant, shaped like a music player.
///
/// Takes the place of the route footer while open: a status line, a level
/// meter that moves with your voice, and a close button. The conversation
/// itself is drawn in the middle of the screen by the parent, where it is
/// readable at a glance.
class GwVoicePanel extends StatefulWidget {
  /// Background the assistant answers from — the site, the route, the load.
  final String context;

  final VoidCallback onClose;
  final ValueChanged<GwVoiceState> onState;

  /// Navigation is on screen, so sit dark against the map instead of glassy.
  final bool dark;

  const GwVoicePanel({
    super.key,
    required this.context,
    required this.onClose,
    required this.onState,
    this.dark = false,
  });

  @override
  State<GwVoicePanel> createState() => _GwVoicePanelState();
}

class _GwVoicePanelState extends State<GwVoicePanel>
    with SingleTickerProviderStateMixin {
  static const _opener = 'I am GWC AI, how may I help you?';

  final _speech = SpeechToText();
  final _tts = FlutterTts();

  bool _ready = false;
  bool _listening = false;
  bool _thinking = false;

  String _heard = '';
  String _reply = '';
  String? _error;

  /// 0..1 from the mic, eased so the meter glides instead of flickering.
  double _level = 0;

  Timer? _idleTimer;

  /// Drives the wave so it drifts while you speak instead of sitting still.
  late final AnimationController _phase = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _phase.dispose();
    _idleTimer?.cancel();
    _speech.cancel();
    _tts.stop();
    super.dispose();
  }

  void _publish() => widget.onState(GwVoiceState(
        heard: _heard,
        reply: _reply,
        listening: _listening,
        thinking: _thinking,
        error: _error,
      ));

  Future<void> _boot() async {
    try {
      _ready = await _speech.initialize(
        onError: (_) {
          if (!mounted) return;
          setState(() => _error = 'Could not hear you. Try again.');
          _publish();
        },
        onStatus: (s) {
          if ((s == 'done' || s == 'notListening') && mounted && _listening) {
            setState(() => _listening = false);
            _publish();
          }
        },
      );
    } catch (_) {
      _ready = false;
    }
    if (!mounted) return;

    if (!_ready) {
      setState(() => _error = 'Speech is not available on this device.');
      _publish();
      return;
    }

    // Announce, then start listening — talking over the greeting would only
    // record the greeting.
    setState(() => _reply = _opener);
    _publish();
    await _tts.setSpeechRate(0.5);
    await _tts.speak(_opener);
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (mounted) _listen();
  }

  void _listen() {
    if (!_ready || !mounted) return;
    setState(() { _listening = true; _error = null; _heard = ''; });
    _publish();
    _armIdleTimer();

    _speech.listen(
      onResult: (r) {
        if (!mounted) return;
        setState(() => _heard = r.recognizedWords);
        _publish();
        _armIdleTimer();
        if (r.finalResult && r.recognizedWords.trim().isNotEmpty) {
          _ask(r.recognizedWords);
        }
      },
      onSoundLevelChange: (l) {
        if (!mounted) return;
        // The plugin reports roughly -2..10.
        final target = ((l + 2) / 12).clamp(0.0, 1.0);
        setState(() => _level = _level + (target - _level) * 0.35);
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
      ),
      pauseFor: const Duration(seconds: 3),
      listenFor: const Duration(seconds: 30),
    );
  }

  /// Silence for long enough means the agent is done — close rather than sit
  /// there with the mic open.
  void _armIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 9), () {
      if (mounted && _heard.trim().isEmpty && !_thinking) widget.onClose();
    });
  }

  Future<void> _ask(String question) async {
    _idleTimer?.cancel();
    await _speech.stop();
    if (!mounted) return;
    setState(() { _listening = false; _thinking = true; _level = 0; _reply = ''; });
    _publish();

    final reply = await ClaudeService.chat(
      systemContext:
          'You are GWC, a waste-management assistant riding along with a field '
          'agent. Answer out loud in at most two short sentences — this is read '
          'aloud while driving. Be concrete and practical.\n\n${widget.context}',
      messages: [{'role': 'user', 'content': question}],
    );

    if (!mounted) return;
    final text = reply ?? (ClaudeService.lastError ?? 'I could not reach the assistant.');
    setState(() { _thinking = false; _reply = text; });
    _publish();
    await _tts.speak(text);
    if (mounted) _listen(); // stay in the conversation
  }

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);

    final content = Row(children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [const Color(0xFF4ADE80), gw.green, gw.greenDim],
            ),
          ),
          child: const GwIcon(GwIcons.sparkle, size: 16, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _thinking ? 'Thinking…' : _listening ? 'Listening…' : 'GWC AI',
                style: TextStyle(
                    color: widget.dark ? Colors.white : gw.text,
                    fontSize: 12.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              // Glow that swells with your voice and lies flat in silence.
              SizedBox(
                height: 22,
                child: AnimatedBuilder(
                  animation: _phase,
                  builder: (_, __) => CustomPaint(
                    painter: _VoiceWavePainter(
                      level: _listening ? _level : 0,
                      phase: _phase.value * math.pi * 2,
                      color: const Color(0xFF4ADE80),
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: widget.onClose,
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: gw.muted.withOpacity(.18),
            ),
            child: GwIcon(GwIcons.close, size: 14,
                color: widget.dark ? Colors.white : gw.text),
          ),
        ),
      ]);

    if (!widget.dark) {
      return GwGlass(
        radius: 18,
        blur: 30,
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: content,
      );
    }

    // Navigation: sit dark against the map so the green reads clearly and the
    // driving instruction above stays the brightest thing on screen.
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(.62),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(.10)),
          ),
          child: content,
        ),
      ),
    );
  }

}

/// The soft glow that swells with your voice.
///
/// Two overlapping humps rather than a row of bars: it reads as one breathing
/// light instead of an equaliser, and at rest it settles to a flat line so
/// silence is unmistakable.
class _VoiceWavePainter extends CustomPainter {
  final double level; // 0..1
  final double phase;
  final Color color;

  const _VoiceWavePainter({
    required this.level,
    required this.phase,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = size.height;

    // Resting line, so the strip never disappears entirely.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, baseline - 2.5, size.width, 2.5),
        const Radius.circular(99),
      ),
      Paint()..color = color.withOpacity(0.28),
    );

    if (level <= 0.02) return;

    // Back layer wider and dimmer, front layer tighter and brighter — that
    // separation is what makes it look like light rather than a shape.
    for (var layer = 0; layer < 2; layer++) {
      final amp = level * baseline * (layer == 0 ? 1.0 : 0.62);
      final speed = layer == 0 ? 1.0 : 1.7;
      final path = Path()..moveTo(0, baseline);

      for (double x = 0; x <= size.width; x += 3) {
        final t = x / size.width;
        // Envelope pins both ends to the baseline so it never clips the edge.
        final envelope = math.sin(math.pi * t);
        final ripple = 0.55 +
            0.45 * math.sin(t * math.pi * 2.6 + phase * speed + layer * 1.3);
        path.lineTo(x, baseline - amp * envelope * ripple);
      }

      path
        ..lineTo(size.width, baseline)
        ..close();

      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              color.withOpacity(layer == 0 ? 0.55 : 0.85),
              color.withOpacity(0.0),
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, baseline))
          ..maskFilter = MaskFilter.blur(
              BlurStyle.normal, layer == 0 ? 9 : 4),
      );
    }
  }

  @override
  bool shouldRepaint(_VoiceWavePainter old) =>
      old.level != level || old.phase != phase || old.color != color;
}
