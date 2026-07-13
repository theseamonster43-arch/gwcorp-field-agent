import 'package:flutter/material.dart';
import '../services/claude_service.dart';
import '../theme/gw_theme.dart';
import '../widgets/gw_nav_bar.dart';

class AiChatScreen extends StatefulWidget {
  final VoidCallback onMenuClick;
  const AiChatScreen({super.key, required this.onMenuClick});
  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();
  final _msgs   = <Map<String, String>>[];
  bool _loading = false;

  static const _system = '''You are the GWCORP AI Assistant, an expert in waste management, recycling, environmental compliance, and field operations. Help field agents with waste classification, disposal protocols, safety guidance, and operational questions. Be concise and practical.''';

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _loading) return;
    _ctrl.clear();
    setState(() { _msgs.add({'role': 'user', 'content': text}); _loading = true; });
    _scrollToBottom();

    final reply = await ClaudeService.chat(systemContext: _system, messages: List.from(_msgs));
    if (mounted) {
      setState(() {
        if (reply != null) _msgs.add({'role': 'assistant', 'content': reply});
        _loading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
  });

  @override
  void dispose() { _ctrl.dispose(); _scroll.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    return Scaffold(
      backgroundColor: gw.bg,
      appBar: GwNavBar(
        title: 'GWC AI',
        actions: [IconButton(icon: Icon(Icons.menu, color: gw.muted), onPressed: widget.onMenuClick)],
      ),
      body: Column(children: [
        Expanded(
          child: _msgs.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.auto_awesome, size: 40, color: gw.green.withOpacity(0.5)),
                  const SizedBox(height: 12),
                  Text('GWCORP AI Assistant', style: TextStyle(color: gw.text, fontSize: 16,
                      fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('Ask about waste disposal, safety,\nor recycling protocols.',
                      style: TextStyle(color: gw.muted, fontSize: 13), textAlign: TextAlign.center),
                ]))
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  itemCount: _msgs.length + (_loading ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _msgs.length) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 4, top: 8),
                        child: Row(children: [
                          SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: gw.green)),
                          const SizedBox(width: 8),
                          Text('Thinking…', style: TextStyle(color: gw.muted, fontSize: 12)),
                        ]),
                      );
                    }
                    final m = _msgs[i];
                    final isUser = m['role'] == 'user';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          if (!isUser) ...[
                            CircleAvatar(radius: 14, backgroundColor: gw.greenGlow,
                                child: Icon(Icons.auto_awesome, size: 14, color: gw.green)),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isUser ? gw.green.withOpacity(0.1) : gw.bg2,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: isUser
                                    ? gw.green.withOpacity(0.2) : gw.border),
                              ),
                              child: Text(m['content'] ?? '',
                                  style: TextStyle(color: gw.text, fontSize: 13, height: 1.5)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        Divider(color: gw.border, height: 1),
        Padding(
          padding: EdgeInsets.only(
              left: 12, right: 12, top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom +
                  MediaQuery.of(context).padding.bottom + 8),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                style: TextStyle(color: gw.text, fontSize: 13),
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Ask about waste management…',
                  hintStyle: TextStyle(color: gw.muted, fontSize: 13),
                  filled: true, fillColor: gw.bg3,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: gw.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: gw.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: gw.green.withOpacity(0.4))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _send,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                    color: gw.green, borderRadius: BorderRadius.circular(10)),
                child: Text('→', style: TextStyle(
                    color: gw.isDark ? gw.bg : Colors.white,
                    fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
