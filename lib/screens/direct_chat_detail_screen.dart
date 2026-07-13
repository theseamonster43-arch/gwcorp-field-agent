import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../data/models.dart';
import '../data/direct_chat_repository.dart';
import '../services/claude_service.dart';
import '../theme/gw_theme.dart';
import '../widgets/gw_nav_bar.dart';

class DirectChatDetailScreen extends StatefulWidget {
  final String chatId;
  final DirectChat? chat;
  final ValueChanged<BuildContext>? onBack;
  const DirectChatDetailScreen(
      {super.key, required this.chatId, this.chat, this.onBack});

  @override
  State<DirectChatDetailScreen> createState() => _DirectChatDetailScreenState();
}

class _DirectChatDetailScreenState extends State<DirectChatDetailScreen> {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();
  bool _sending    = false;
  bool _aiMode     = false;
  bool _aiThinking = false;
  DirectMessage? _replyingTo;
  Timer? _typingTimer;

  String get _myEmail =>
      FirebaseAuth.instance.currentUser?.email ?? '';
  String get _myName =>
      FirebaseAuth.instance.currentUser?.displayName?.trim().isNotEmpty == true
          ? FirebaseAuth.instance.currentUser!.displayName!
          : _myEmail;

  @override
  void initState() {
    super.initState();
    DirectChatRepository.markRead(widget.chatId, _myEmail);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    DirectChatRepository.setTyping(widget.chatId, _myEmail, _myName, false);
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onTextChanged(String _) {
    DirectChatRepository.setTyping(widget.chatId, _myEmail, _myName, true);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () =>
        DirectChatRepository.setTyping(widget.chatId, _myEmail, _myName, false));
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    _typingTimer?.cancel();
    DirectChatRepository.setTyping(widget.chatId, _myEmail, _myName, false);
    final reply    = _replyingTo;
    final wasAi    = _aiMode;
    setState(() { _sending = true; _replyingTo = null; });
    await DirectChatRepository.sendMessage(
      widget.chatId, _myEmail, _myName, text,
      replyToId:         reply?.id,
      replyToContent:    reply?.content,
      replyToSenderName: reply?.senderName,
    );
    setState(() => _sending = false);
    _scrollToBottom();

    if (wasAi) {
      setState(() => _aiThinking = true);
      try {
        final aiReply = await ClaudeService.chat(
          systemContext: 'You are GWCORP AI, an expert waste management assistant. '
              'Answer questions about recycling, waste disposal, environmental sustainability, '
              'and hazardous materials. Be concise, practical, and helpful.',
          messages: [
            {'role': 'user', 'content': text}
          ],
        );
        await DirectChatRepository.sendMessage(
          widget.chatId, 'ai@gwcorp.app', 'GWCORP AI',
          aiReply ?? 'Sorry, I could not process that right now.');
      } catch (_) {
        await DirectChatRepository.sendMessage(
          widget.chatId, 'ai@gwcorp.app', 'GWCORP AI',
          'Sorry, I could not process that right now.');
      } finally {
        if (mounted) setState(() => _aiThinking = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
      }
    });
  }

  void _showEmojiPicker(DirectMessage msg) {
    final gw = GwTheme.of(context);
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _EmojiSheet(
        gw: gw,
        myEmail: _myEmail,
        reactions: msg.reactions,
        onPick: (emoji) {
          Navigator.pop(context);
          DirectChatRepository.toggleReaction(
              widget.chatId, msg.id, emoji, _myEmail);
        },
      ),
    );
  }

  String _chatTitle() {
    final chat = widget.chat;
    if (chat == null) return 'Chat';
    if (chat.isGroup) {
      return chat.groupName.isEmpty ? 'Group Chat' : chat.groupName;
    }
    final entry = chat.participantNames.entries.firstWhere(
      (e) => e.key != _myEmail,
      orElse: () => MapEntry(
          chat.participants.firstWhere((p) => p != _myEmail, orElse: () => ''),
          ''),
    );
    return entry.value.isNotEmpty
        ? entry.value
        : chat.participants.firstWhere((p) => p != _myEmail, orElse: () => 'Chat');
  }

  int _otherLastRead() {
    final chat = widget.chat;
    if (chat == null) return 0;
    final others = chat.lastRead.entries
        .where((e) => e.key != _myEmail)
        .map((e) => e.value);
    return others.isNotEmpty ? others.reduce((a, b) => a < b ? a : b) : 0;
  }

  @override
  Widget build(BuildContext context) {
    final gw          = GwTheme.of(context);
    final otherRead   = _otherLastRead();

    return Scaffold(
      backgroundColor: gw.bg,
      appBar: GwNavBar(
        title: _chatTitle(),
        onBack: widget.onBack != null ? () => widget.onBack!(context) : null,
      ),
      body: Column(children: [

        // ── Message list ──────────────────────────────────
        Expanded(
          child: StreamBuilder<List<DirectMessage>>(
            stream: DirectChatRepository.messagesStream(widget.chatId),
            builder: (ctx, snap) {
              if (snap.hasError) {
                return Center(
                  child: Text('Could not load messages\n${snap.error}',
                      style: TextStyle(color: gw.red, fontSize: 12),
                      textAlign: TextAlign.center),
                );
              }
              final msgs = snap.data ?? [];
              if (msgs.isEmpty && !_aiThinking) {
                return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('◎', style: TextStyle(fontSize: 36, color: gw.muted)),
                  const SizedBox(height: 10),
                  Text('No messages yet',
                      style: TextStyle(color: gw.text, fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  Text('Say hello!', style: TextStyle(color: gw.muted, fontSize: 12)),
                ]));
              }
              _scrollToBottom();
              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                itemCount: msgs.length + (_aiThinking ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == msgs.length) return _AiThinkingBubble(gw: gw);
                  final msg  = msgs[i];
                  final isMe = msg.senderEmail == _myEmail;
                  final isRead = isMe && otherRead >= msg.timestamp;
                  return _SwipeableMessage(
                    key: ValueKey(msg.id),
                    enabled: true,
                    onReply: () => setState(() => _replyingTo = msg),
                    child: _DmBubble(
                      msg:       msg,
                      isMe:      isMe,
                      isAi:      msg.senderEmail == 'ai@gwcorp.app',
                      isRead:    isRead,
                      myEmail:   _myEmail,
                      onLongPress: () => _showEmojiPicker(msg),
                      onReactionTap: (emoji) => DirectChatRepository.toggleReaction(
                          widget.chatId, msg.id, emoji, _myEmail),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // ── Typing indicator ───────────────────────────────
        StreamBuilder<List<String>>(
          stream: DirectChatRepository.typingStream(widget.chatId, _myEmail),
          builder: (_, snap) {
            final typers = snap.data ?? [];
            if (typers.isEmpty) return const SizedBox.shrink();
            final label = typers.length == 1
                ? '${typers[0]} is typing'
                : '${typers.length} people are typing';
            return Container(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
              alignment: Alignment.centerLeft,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _TypingDots(gw: gw),
                const SizedBox(width: 7),
                Text(label,
                    style: TextStyle(color: gw.muted, fontSize: 11)),
              ]),
            );
          },
        ),

        // ── Reply preview ─────────────────────────────────
        if (_replyingTo != null)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            color: gw.bg2,
            child: Row(children: [
              Container(width: 3, height: 38, color: gw.green,
                  margin: const EdgeInsets.only(right: 10)),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_replyingTo!.senderName,
                    style: TextStyle(color: gw.green, fontSize: 11,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 1),
                Text(_replyingTo!.content,
                    style: TextStyle(color: gw.muted, fontSize: 12),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              IconButton(
                icon: Icon(Icons.close, color: gw.muted, size: 18),
                onPressed: () => setState(() => _replyingTo = null),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ]),
          ),

        Divider(color: gw.border, height: 1),

        // ── AI mode banner ────────────────────────────────
        if (_aiMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            color: gw.green.withOpacity(0.07),
            child: Row(children: [
              Icon(Icons.auto_awesome, color: gw.green, size: 13),
              const SizedBox(width: 6),
              Text('AI Mode · ask about waste management',
                  style: TextStyle(color: gw.green, fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ]),
          ),

        // ── Input bar ─────────────────────────────────────
        Padding(
          padding: EdgeInsets.only(
              left: 10, right: 10, top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom +
                  MediaQuery.of(context).padding.bottom + 8),
          child: Row(children: [
            // AI toggle button
            GestureDetector(
              onTap: () => setState(() => _aiMode = !_aiMode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _aiMode ? gw.green.withOpacity(0.12) : gw.bg3,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _aiMode ? gw.green.withOpacity(0.5) : gw.border),
                ),
                child: Icon(Icons.auto_awesome,
                    color: _aiMode ? gw.green : gw.muted, size: 18),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _ctrl,
                onChanged: _onTextChanged,
                style: TextStyle(color: gw.text, fontSize: 13),
                maxLines: 4,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: _aiMode ? 'Ask about waste…' : 'Message…',
                  hintStyle: TextStyle(color: gw.muted, fontSize: 13),
                  filled: true,
                  fillColor: gw.bg3,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: gw.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: gw.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: gw.green.withOpacity(0.5), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: (_sending || _aiThinking) ? null : _send,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 42, height: 42,
                decoration: BoxDecoration(
                    color: (_sending || _aiThinking)
                        ? gw.green.withOpacity(0.35)
                        : gw.green,
                    borderRadius: BorderRadius.circular(10)),
                child: (_sending || _aiThinking)
                    ? Padding(
                        padding: const EdgeInsets.all(11),
                        child: CircularProgressIndicator(strokeWidth: 2,
                            color: gw.isDark ? gw.bg : Colors.white))
                    : Icon(Icons.send_rounded,
                        color: gw.isDark ? gw.bg : Colors.white, size: 18),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Swipe-to-reply wrapper ─────────────────────────────────────────────────────
class _SwipeableMessage extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final VoidCallback onReply;
  const _SwipeableMessage(
      {super.key, required this.child, required this.enabled,
        required this.onReply});
  @override
  State<_SwipeableMessage> createState() => _SwipeableMessageState();
}

class _SwipeableMessageState extends State<_SwipeableMessage>
    with SingleTickerProviderStateMixin {
  double _dx       = 0;
  bool _triggered  = false;
  bool _animating  = false;
  double _animFrom = 0;
  late AnimationController _snap;
  late CurvedAnimation _curve;

  @override
  void initState() {
    super.initState();
    _snap  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _curve = CurvedAnimation(parent: _snap, curve: Curves.easeOut);
    _snap.addListener(_onSnapTick);
    _snap.addStatusListener(_onSnapStatus);
  }

  void _onSnapTick() {
    if (_animating && mounted) {
      setState(() => _dx = _animFrom * (1 - _curve.value));
    }
  }

  void _onSnapStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed && mounted) {
      setState(() { _dx = 0; _animating = false; });
      _snap.reset();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _snap.dispose();
    super.dispose();
  }

  void _onUpdate(DragUpdateDetails d) {
    if (!widget.enabled || d.delta.dx < 0 || _animating) return;
    setState(() => _dx = (_dx + d.delta.dx).clamp(0.0, 72.0));
    if (_dx >= 58 && !_triggered) {
      _triggered = true;
      HapticFeedback.lightImpact();
      widget.onReply();
    }
  }

  void _onEnd(DragEndDetails _) {
    if (_dx <= 0) return;
    _triggered = false;
    _animFrom  = _dx;
    _animating = true;
    _snap.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    return GestureDetector(
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd:    _onEnd,
      child: Stack(clipBehavior: Clip.none, children: [
        if (_dx > 12)
          Positioned(
            left: 6, top: 0, bottom: 0,
            child: Opacity(
              opacity: (_dx / 58).clamp(0.0, 1.0),
              child: Center(child: Icon(Icons.reply, color: gw.green, size: 18)),
            ),
          ),
        Transform.translate(
          offset: Offset(_dx, 0),
          child: widget.child,
        ),
      ]),
    );
  }
}

// ── Message bubble ─────────────────────────────────────────────────────────────
class _DmBubble extends StatelessWidget {
  final DirectMessage msg;
  final bool isMe;
  final bool isAi;
  final bool isRead;
  final String myEmail;
  final VoidCallback onLongPress;
  final void Function(String) onReactionTap;

  const _DmBubble({
    required this.msg,
    required this.isMe,
    required this.isAi,
    required this.isRead,
    required this.myEmail,
    required this.onLongPress,
    required this.onReactionTap,
  });

  @override
  Widget build(BuildContext context) {
    final gw   = GwTheme.of(context);
    final time = msg.timestamp > 0
        ? DateFormat('HH:mm')
            .format(DateTime.fromMillisecondsSinceEpoch(msg.timestamp))
        : '';
    final shape = BorderRadius.only(
      topLeft:     const Radius.circular(14),
      topRight:    const Radius.circular(14),
      bottomLeft:  Radius.circular(isMe ? 14 : 2),
      bottomRight: Radius.circular(isMe ? 2 : 14),
    );

    final bubbleColor = isMe
        ? gw.green.withOpacity(0.11)
        : isAi
            ? gw.green.withOpacity(0.06)
            : gw.bg2;
    final textColor = isMe
        ? (gw.isDark ? const Color(0xFF86EFAC) : gw.greenDim)
        : gw.text;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
          // Sender label
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 3),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (isAi)
                  Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                      color: gw.greenGlow, shape: BoxShape.circle,
                      border: Border.all(color: gw.green.withOpacity(0.4)),
                    ),
                    child: Icon(Icons.auto_awesome, color: gw.green, size: 10),
                  )
                else
                  CircleAvatar(
                    radius: 9, backgroundColor: gw.greenGlow,
                    child: Text(
                      msg.senderName.isNotEmpty
                          ? msg.senderName[0].toUpperCase()
                          : '?',
                      style: TextStyle(color: gw.green, fontSize: 8,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                const SizedBox(width: 5),
                Text(msg.senderName,
                    style: TextStyle(
                      color: isAi ? gw.green : gw.muted,
                      fontSize: 10, fontWeight: FontWeight.w600,
                    )),
              ]),
            ),

          // Bubble
          GestureDetector(
            onLongPress: onLongPress,
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.74),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: shape,
                border: Border.all(
                    color: (isMe || isAi)
                        ? gw.green.withOpacity(0.18)
                        : gw.border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Reply quote
                if (msg.replyToId != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 7),
                    padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
                    decoration: BoxDecoration(
                      color: gw.bg3,
                      borderRadius: BorderRadius.circular(6),
                      border: Border(left: BorderSide(color: gw.green, width: 2.5)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(msg.replyToSenderName ?? '',
                          style: TextStyle(color: gw.green, fontSize: 10,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 1),
                      Text(msg.replyToContent ?? '',
                          style: TextStyle(color: gw.muted, fontSize: 11),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                ],
                Text(msg.content,
                    style: TextStyle(color: textColor, fontSize: 13, height: 1.4)),
              ]),
            ),
          ),

          // Reactions
          if (msg.reactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(spacing: 4, children: msg.reactions.entries.map((e) {
                final iReacted = e.value.contains(myEmail);
                return GestureDetector(
                  onTap: () => onReactionTap(e.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: iReacted
                          ? gw.green.withOpacity(0.12)
                          : gw.bg2,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                          color: iReacted
                              ? gw.green.withOpacity(0.45)
                              : gw.border),
                    ),
                    child: Text('${e.key} ${e.value.length}',
                        style: TextStyle(fontSize: 11,
                            color: iReacted ? gw.green : gw.muted)),
                  ),
                );
              }).toList()),
            ),

          // Time + read receipt
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (time.isNotEmpty)
                Text(time, style: TextStyle(color: gw.muted, fontSize: 9)),
              if (isMe) ...[
                const SizedBox(width: 4),
                Icon(Icons.done_all, size: 12,
                    color: isRead
                        ? gw.green
                        : gw.muted.withOpacity(0.5)),
              ],
            ]),
          ),
        ]), // end inner Column
        ), // end Flexible
        ], // end outer Row children
      ),   // end outer Row
    );
  }
}

// ── Emoji reaction sheet ───────────────────────────────────────────────────────
class _EmojiSheet extends StatelessWidget {
  final GwColors gw;
  final String myEmail;
  final Map<String, List<String>> reactions;
  final void Function(String) onPick;
  const _EmojiSheet(
      {required this.gw, required this.myEmail, required this.reactions,
        required this.onPick});

  static const _emojis = ['👍', '❤️', '😂', '😮', '😢', '🔥', '👏', '✅'];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: gw.bg2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gw.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _emojis.map((e) {
          final reacted = reactions[e]?.contains(myEmail) ?? false;
          return GestureDetector(
            onTap: () => onPick(e),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: reacted ? gw.green.withOpacity(0.15) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Text(e, style: const TextStyle(fontSize: 26)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── AI "thinking" bubble ───────────────────────────────────────────────────────
class _AiThinkingBubble extends StatelessWidget {
  final GwColors gw;
  const _AiThinkingBubble({required this.gw});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 3),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 18, height: 18,
              decoration: BoxDecoration(
                color: gw.greenGlow, shape: BoxShape.circle,
                border: Border.all(color: gw.green.withOpacity(0.4)),
              ),
              child: Icon(Icons.auto_awesome, color: gw.green, size: 10),
            ),
            const SizedBox(width: 5),
            Text('GWCORP AI',
                style: TextStyle(color: gw.green, fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: gw.green.withOpacity(0.06),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14), topRight: Radius.circular(14),
              bottomRight: Radius.circular(14), bottomLeft: Radius.circular(2),
            ),
            border: Border.all(color: gw.green.withOpacity(0.18)),
          ),
          child: _TypingDots(gw: gw),
        ),
      ]),
    );
  }
}

// ── Animated typing dots ───────────────────────────────────────────────────────
class _TypingDots extends StatefulWidget {
  final GwColors gw;
  const _TypingDots({required this.gw});
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (int i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          _Dot(
            gw: widget.gw,
            phase: (_ctrl.value + i / 3) % 1,
          ),
        ],
      ]),
    );
  }
}

class _Dot extends StatelessWidget {
  final GwColors gw;
  final double phase;
  const _Dot({required this.gw, required this.phase});

  @override
  Widget build(BuildContext context) {
    final t = (phase < 0.5 ? phase * 2 : (1 - phase) * 2).clamp(0.0, 1.0);
    final scale = 0.6 + 0.4 * t;
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 7, height: 7,
        decoration: BoxDecoration(
            color: gw.green.withOpacity(0.4 + 0.6 * t),
            shape: BoxShape.circle),
      ),
    );
  }
}
