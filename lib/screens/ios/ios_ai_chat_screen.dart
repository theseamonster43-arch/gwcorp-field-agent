import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import '../../services/claude_service.dart';

class IosAiChatScreen extends StatefulWidget {
  final VoidCallback onMenuClick;
  const IosAiChatScreen({super.key, required this.onMenuClick});
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
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: widget.onMenuClick,
          child: const Icon(Icons.menu),
        ),
        middle: Row(mainAxisSize: MainAxisSize.min, children: const [
          Icon(Icons.auto_awesome, size: 16, color: Color(0xFF22C55E)),
          SizedBox(width: 6),
          Text('GWC AI'),
        ]),
      ),
      child: Column(children: [
        Expanded(
          child: _msgs.isEmpty
              ? Center(
                  child: LiquidGlassContainer(
                    config: LiquidGlassConfig(
                      effect: CNGlassEffect.regular,
                      shape: CNGlassEffectShape.rect,
                      cornerRadius: 28,
                      interactive: false,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.auto_awesome,
                            size: 44, color: Color(0xFF22C55E)),
                        const SizedBox(height: 14),
                        Text('GWCORP AI Assistant',
                            style: TextStyle(
                              color: CupertinoColors.label.resolveFrom(context),
                              fontSize: 17, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text('Ask about waste disposal, safety,\nor recycling protocols.',
                            style: TextStyle(
                              color: CupertinoColors.secondaryLabel.resolveFrom(context),
                              fontSize: 13),
                            textAlign: TextAlign.center),
                      ]),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _msgs.length + (_loading ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _msgs.length) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 4, top: 8),
                        child: Row(children: [
                          const CupertinoActivityIndicator(),
                          const SizedBox(width: 10),
                          Text('Thinking…',
                              style: TextStyle(
                                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                                  fontSize: 13)),
                        ]),
                      );
                    }
                    final m = _msgs[i];
                    final isUser = m['role'] == 'user';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment:
                            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          if (!isUser) ...[
                            Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF22C55E).withOpacity(0.15),
                              ),
                              child: const Icon(Icons.auto_awesome,
                                  size: 14, color: Color(0xFF22C55E)),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? const Color(0xFF22C55E).withOpacity(0.12)
                                    : CupertinoColors.secondarySystemGroupedBackground
                                        .resolveFrom(context),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(14),
                                  topRight: const Radius.circular(14),
                                  bottomLeft: Radius.circular(isUser ? 14 : 3),
                                  bottomRight: Radius.circular(isUser ? 3 : 14),
                                ),
                              ),
                              child: Text(m['content'] ?? '',
                                  style: TextStyle(
                                      color: CupertinoColors.label.resolveFrom(context),
                                      fontSize: 14, height: 1.5)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: EdgeInsets.only(
            left: 12, right: 8, top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom + 8,
          ),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: CupertinoColors.separator.resolveFrom(context), width: 0.5),
            ),
          ),
          child: Row(children: [
            Expanded(
              child: CupertinoTextField(
                controller: _ctrl,
                placeholder: 'Ask about waste management…',
                onSubmitted: (_) => _send(),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: CupertinoColors.tertiarySystemBackground.resolveFrom(context),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CupertinoTheme(
              data: const CupertinoThemeData(primaryColor: Color(0xFF22C55E)),
              child: CNButton.icon(
                icon: CNSymbol('arrow.up', size: 16),
                config: CNButtonConfig(style: CNButtonStyle.filled),
                enabled: !_loading,
                onPressed: _send,
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
