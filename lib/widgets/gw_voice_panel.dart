import 'dart:async';
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

  const GwVoicePanel({
    super.key,
    required this.context,
    required this.onClose,
    required this.onState,
  });

  @override
  State<GwVoicePanel> createState() => _GwVoicePanelState();
}

class _GwVoicePanelState extends State<GwVoicePanel> {
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

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
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

    return GwGlass(
      radius: 18,
      blur: 30,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(children: [
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
                style: TextStyle(color: gw.text, fontSize: 12.5,
                    fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              // Level meter — the "music player" strip.
              SizedBox(height: 16, child: _meter(gw)),
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
            child: GwIcon(GwIcons.close, size: 14, color: gw.text),
          ),
        ),
      ]),
    );
  }

  Widget _meter(GwColors gw) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(22, (i) {
          // Middle bars react most, so it reads as a waveform.
          final centre = 1 - ((i - 10.5).abs() / 10.5);
          final double h =
              3 + (_listening ? _level * 13 * (0.35 + centre * 0.65) : 0.0);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 90),
                height: h.clamp(3.0, 16.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [gw.greenDim, const Color(0xFF4ADE80)],
                  ),
                ),
              ),
            ),
          );
        }),
      );
}
