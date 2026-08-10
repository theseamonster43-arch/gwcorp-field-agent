import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../services/claude_service.dart';
import '../theme/gw_theme.dart';
import 'gw_glass.dart';
import 'gw_icons.dart';

/// Hands-free assistant.
///
/// Opens listening, transcribes as you speak, sends the question to Claude
/// with whatever context the caller supplies, and reads the answer back. The
/// bar along the bottom rises with your voice so it is obvious the mic is
/// live — the usual complaint about voice UI is not knowing whether it heard
/// you.
///
/// Closes itself after a few seconds of silence so a driver never has to
/// find the X.
class GwVoicePanel extends StatefulWidget {
  /// Background the assistant should answer from — the site being viewed, the
  /// waste being carried, and so on.
  final String context;

  /// Spoken opener, e.g. "Hi, you're near Bee'ah Recycling".
  final String? greeting;

  final VoidCallback onClose;

  const GwVoicePanel({
    super.key,
    required this.context,
    required this.onClose,
    this.greeting,
  });

  @override
  State<GwVoicePanel> createState() => _GwVoicePanelState();
}

class _GwVoicePanelState extends State<GwVoicePanel> {
  final _speech = SpeechToText();
  final _tts = FlutterTts();

  bool _ready = false;
  bool _listening = false;
  bool _thinking = false;

  String _heard = '';
  String _reply = '';
  String? _error;

  /// 0..1, driven by the mic. Smoothed so the bar glides rather than flickers.
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

  Future<void> _boot() async {
    try {
      _ready = await _speech.initialize(
        onError: (e) {
          if (mounted) setState(() => _error = 'Could not hear you. Try again.');
        },
        onStatus: (s) {
          // 'done' or 'notListening' means the recogniser stopped on its own.
          if (s == 'done' || s == 'notListening') {
            if (mounted && _listening) setState(() => _listening = false);
          }
        },
      );
    } catch (_) {
      _ready = false;
    }
    if (!mounted) return;

    if (!_ready) {
      setState(() => _error = 'Speech is not available on this device.');
      return;
    }

    await _tts.setSpeechRate(0.5);
    if (widget.greeting != null) await _tts.speak(widget.greeting!);

    setState(() {});
    _listen();
  }

  void _listen() {
    if (!_ready) return;
    setState(() { _listening = true; _error = null; _reply = ''; _heard = ''; });
    _armIdleTimer();

    _speech.listen(
      onResult: (r) {
        if (!mounted) return;
        setState(() => _heard = r.recognizedWords);
        _armIdleTimer();
        if (r.finalResult && r.recognizedWords.trim().isNotEmpty) {
          _ask(r.recognizedWords);
        }
      },
      onSoundLevelChange: (l) {
        if (!mounted) return;
        // The plugin reports roughly -2..10; normalise and ease toward it so
        // the bar does not jitter frame to frame.
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

  /// Nothing said for a while — shut down rather than sit there listening.
  void _armIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      if (_heard.trim().isEmpty && !_thinking) widget.onClose();
    });
  }

  Future<void> _ask(String question) async {
    _idleTimer?.cancel();
    await _speech.stop();
    if (!mounted) return;
    setState(() { _listening = false; _thinking = true; _level = 0; });

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
    await _tts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);

    return GwGlass(
      radius: 22,
      blur: 30,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [const Color(0xFF4ADE80), gw.green, gw.greenDim],
              ),
            ),
            child: const GwIcon(GwIcons.sparkle, size: 15, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _thinking
                  ? 'Thinking…'
                  : _listening
                      ? 'Listening…'
                      : 'GWC',
              style: TextStyle(color: gw.text, fontSize: 14,
                  fontWeight: FontWeight.w800)),
          ),
          GestureDetector(
            onTap: widget.onClose,
            child: GwIcon(GwIcons.close, size: 16, color: gw.muted),
          ),
        ]),

        const SizedBox(height: 12),

        if (_error != null)
          Text(_error!, style: TextStyle(color: gw.amber, fontSize: 12.5, height: 1.4))
        else if (_reply.isNotEmpty)
          Text(_reply, style: TextStyle(color: gw.text, fontSize: 13.5, height: 1.5))
        else
          Text(
            _heard.isEmpty ? 'Ask me about this place, or what to do with a load.' : _heard,
            style: TextStyle(
                color: _heard.isEmpty ? gw.muted : gw.text,
                fontSize: 13.5, height: 1.45)),

        const SizedBox(height: 14),

        // Level meter — grows with your voice, so it is obvious the mic is on.
        SizedBox(
          height: 26,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(24, (i) {
              // Middle bars react most, giving a waveform rather than a block.
              final centre = 1 - ((i - 11.5).abs() / 11.5);
              final h = 3 + (_listening ? _level * 23 * (0.35 + centre * 0.65) : 0);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 90),
                    height: h.clamp(3.0, 26.0),
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
          ),
        ),

        if (!_listening && !_thinking) ...[
          const SizedBox(height: 12),
          GwGlass(
            radius: 12,
            accent: gw.green,
            onTap: _listen,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Text('Ask again', style: TextStyle(
                color: gw.green, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ]),
    );
  }
}
