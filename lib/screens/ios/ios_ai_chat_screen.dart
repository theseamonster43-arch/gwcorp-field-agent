import 'package:flutter/material.dart';
import '../../services/claude_service.dart';
import '../../theme/gw_theme.dart';
import '../../widgets/gw_icons.dart';
import '../../widgets/gw_glass.dart';

class IosAiChatScreen extends StatefulWidget {
  const IosAiChatScreen({super.key});
  @override
  State<IosAiChatScreen> createState() => _IosAiChatScreenState();
}

class _IosAiChatScreenState extends State<IosAiChatScreen> {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();
  final _msgs   = <Map<String, String>>[];
  bool _loading = false;

  static const _system =
      'You are the GWCORP AI Assistant, an expert in waste management, recycling, '
      'environmental compliance, and field operations. Help field agents with waste '
      'classification, disposal protocols, safety guidance, and operational questions. '
      'Be concise and practical.';

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _loading) return;
    _ctrl.clear();
    setState(() { _msgs.add({'role': 'user', 'content': text}); _loading = true; });
    _scrollBottom();
    final reply = await ClaudeService.chat(systemContext: _system, messages: List.from(_msgs));
    if (mounted) {
      setState(() {
        if (reply != null) _msgs.add({'role': 'assistant', 'content': reply});
        _loading = false;
      });
      _scrollBottom();
    }
  }

  void _scrollBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
  });

  @override
  void dispose() { _ctrl.dispose(); _scroll.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GwScreenBg(
        child: SafeArea(
          child: Column(
            children: [
              _header(gw),
              Expanded(child: _msgs.isEmpty ? _empty(gw) : _list(gw)),
              _composer(gw),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(GwColors gw) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
      child: Row(
        children: [
          GwGlassIcon(
            icon: GwIcons.chevronLeft,
            size: 16,
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 12),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: gw.green.withOpacity(.15),
            ),
            child: GwIcon(GwIcons.sparkle, size: 17, color: gw.green),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'GWC AI',
                  style: TextStyle(
                    color: gw.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  'Waste intelligence assistant',
                  style: TextStyle(color: gw.muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(GwColors gw) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: GwGlass(
          radius: 26,
          padding: const EdgeInsets.all(28),
          accent: gw.green,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GwIcon(GwIcons.sparkle, size: 42, color: gw.green),
              const SizedBox(height: 14),
              Text(
                'GWCORP AI Assistant',
                style: TextStyle(
                  color: gw.text,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Ask about waste disposal, safety,\nor recycling protocols.',
                style: TextStyle(color: gw.muted, fontSize: 12.5, height: 1.45),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(GwColors gw) {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: _msgs.length + (_loading ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _msgs.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(gw.green),
                  ),
                ),
                const SizedBox(width: 10),
                Text('Thinking…', style: TextStyle(color: gw.muted, fontSize: 12.5)),
              ],
            ),
          );
        }
        final m = _msgs[i];
        final isUser = m['role'] == 'user';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: gw.green.withOpacity(.15),
                  ),
                  child: GwIcon(GwIcons.sparkle, size: 14, color: gw.green),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: GwGlass(
                  radius: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  accent: isUser ? gw.green : null,
                  child: SelectableText(
                    m['content'] ?? '',
                    style: TextStyle(color: gw.text, fontSize: 13.5, height: 1.5),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _composer(GwColors gw) {
    return Padding(
      // Scaffold already resizes the body for the keyboard
      // (resizeToAvoidBottomInset defaults to true), and this State's `context`
      // sits ABOVE the Scaffold, so its MediaQuery still reports the full
      // keyboard height. Adding viewInsets.bottom here would double-count it
      // and float the composer a keyboard-height above the keyboard.
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: GwGlass(
              radius: 22,
              blur: 20,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _ctrl,
                style: TextStyle(color: gw.text, fontSize: 13.5),
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  hintText: 'Ask about waste management…',
                  hintStyle: TextStyle(color: gw.muted, fontSize: 13.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Opacity(
            opacity: _loading ? 0.5 : 1,
            child: GestureDetector(
              onTap: _loading ? null : _send,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [const Color(0xFF4ADE80), gw.green, gw.greenDim],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: gw.green.withOpacity(.45),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const GwIcon(
                  GwIcons.arrowUp,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
