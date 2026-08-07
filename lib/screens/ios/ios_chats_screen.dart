import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/direct_chat_repository.dart';
import '../../data/models.dart';
import '../../data/user_repository.dart';
import '../../theme/gw_theme.dart';
import '../../widgets/gw_icons.dart';
import '../../widgets/gw_glass.dart';

class IosChatsList extends StatefulWidget {
  const IosChatsList({super.key});
  @override
  State<IosChatsList> createState() => _IosChatsListState();
}

class _IosChatsListState extends State<IosChatsList> {
  int _seg = 0;

  Widget _segBtn(int i, String label) {
    final gw = GwTheme.of(context);
    final selected = _seg == i;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _seg = i),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? gw.green.withOpacity(.20) : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? gw.green : gw.muted,
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    final myEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GwScreenBg(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: Row(children: [
                GwGlassIcon(
                  icon: GwIcons.chevronLeft,
                  size: 16,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _seg == 0 ? 'Messages' : 'Community',
                    style: TextStyle(
                      color: gw.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
                if (_seg == 0)
                  GwGlassIcon(
                    icon: GwIcons.plus,
                    onTap: () => context.push('/main/newchat'),
                  ),
              ]),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GwGlass(
                radius: 14,
                padding: const EdgeInsets.all(4),
                child: Row(children: [
                  _segBtn(0, 'Direct'),
                  _segBtn(1, 'Community'),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _seg == 0
                  ? _IosDmList(myEmail: myEmail)
                  : const _IosCommunityChat(),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── DM List ───────────────────────────────────────────────────────────────────

class _IosDmList extends StatefulWidget {
  final String myEmail;
  const _IosDmList({required this.myEmail});
  @override
  State<_IosDmList> createState() => _IosDmListState();
}

class _IosDmListState extends State<_IosDmList> {
  List<DirectChat> _chats = [];
  List<AppUser> _users = [];

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    return StreamBuilder<List<DirectChat>>(
      stream: DirectChatRepository.chatsStream(widget.myEmail),
      builder: (ctx, chatSnap) {
        if (chatSnap.hasData) _chats = chatSnap.data!;
        return StreamBuilder<List<AppUser>>(
          stream: UserRepository.usersStream(widget.myEmail),
          builder: (ctx, userSnap) {
            if (userSnap.hasData) _users = userSnap.data!;
            final chattedEmails = _chats.expand((c) => c.participants).toSet();
            final newPeople =
                _users.where((u) => !chattedEmails.contains(u.email)).toList();

            if (_chats.isEmpty && newPeople.isEmpty) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  GwIcon(GwIcons.chat, size: 40, color: gw.muted),
                  const SizedBox(height: 12),
                  Text(
                    'No contacts yet',
                    style: TextStyle(
                      color: gw.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap + to start a chat',
                    style: TextStyle(color: gw.muted, fontSize: 12.5),
                  ),
                ]),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
              itemCount: _chats.length + newPeople.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                if (i < _chats.length) {
                  return _ChatRow(
                    chat: _chats[i],
                    myEmail: widget.myEmail,
                    onTap: () => context.push('/main/directchat/${_chats[i].id}'),
                  );
                }
                final user = newPeople[i - _chats.length];
                return _PersonRow(user: user, myEmail: widget.myEmail);
              },
            );
          },
        );
      },
    );
  }
}

class _ChatRow extends StatelessWidget {
  final DirectChat chat;
  final String myEmail;
  final VoidCallback onTap;
  const _ChatRow({required this.chat, required this.myEmail, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    final name = chat.isGroup
        ? (chat.groupName.isEmpty ? 'Group' : chat.groupName)
        : chat.participantNames.entries
            .firstWhere((e) => e.key != myEmail,
                orElse: () => const MapEntry('', 'Chat'))
            .value;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final time = chat.lastMessageTime > 0
        ? DateFormat('HH:mm').format(
            DateTime.fromMillisecondsSinceEpoch(chat.lastMessageTime))
        : '';
    final preview = chat.lastMessage.isEmpty
        ? 'No messages yet'
        : chat.lastMessageSender == myEmail
            ? 'You: ${chat.lastMessage}'
            : '${(chat.participantNames[chat.lastMessageSender] ?? '').split(' ').first}: ${chat.lastMessage}';

    return GwGlass(
      radius: 16,
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(children: [
        CircleAvatar(
          radius: 21,
          backgroundColor: gw.green.withOpacity(.15),
          child: Text(
            initial,
            style: TextStyle(
              color: gw.green,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              name,
              style: TextStyle(
                color: gw.text,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              preview,
              style: TextStyle(color: gw.muted, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
        if (time.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(time, style: TextStyle(color: gw.muted, fontSize: 10.5)),
        ],
        const SizedBox(width: 4),
        GwIcon(GwIcons.chevronRight, size: 15, color: gw.muted),
      ]),
    );
  }
}

class _PersonRow extends StatelessWidget {
  final AppUser user;
  final String myEmail;
  const _PersonRow({required this.user, required this.myEmail});

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';
    final hasPhoto = user.photoUrl?.isNotEmpty == true;
    return GwGlass(
      radius: 16,
      padding: const EdgeInsets.all(12),
      onTap: () async {
        final myName =
            FirebaseAuth.instance.currentUser?.displayName ?? myEmail.split('@')[0];
        final chatId = await DirectChatRepository.createOrOpenChat(
          myEmail: myEmail,
          myName: myName,
          targetEmails: [user.email],
          targetNames: {user.email: user.name},
          isGroup: false,
          groupName: '',
        );
        if (context.mounted) context.push('/main/directchat/$chatId');
      },
      child: Row(children: [
        CircleAvatar(
          radius: 21,
          backgroundColor: gw.bg3,
          backgroundImage: hasPhoto ? NetworkImage(user.photoUrl!) : null,
          child: hasPhoto
              ? null
              : Text(
                  initial,
                  style: TextStyle(
                    color: gw.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              user.name,
              style: TextStyle(
                color: gw.text,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              user.email,
              style: TextStyle(color: gw.muted, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
        const SizedBox(width: 8),
        GwIcon(GwIcons.chat, size: 16, color: gw.muted),
      ]),
    );
  }
}

// ── Community Chat ────────────────────────────────────────────────────────────

class _IosCommunityChat extends StatefulWidget {
  const _IosCommunityChat();
  @override
  State<_IosCommunityChat> createState() => _IosCommunityChatState();
}

class _IosCommunityChatState extends State<_IosCommunityChat> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    final me = FirebaseAuth.instance.currentUser;
    _ctrl.clear();
    setState(() => _sending = true);
    await FirebaseFirestore.instance
        .collection('community')
        .doc('main')
        .collection('messages')
        .add({
      'text': text,
      'authorId': me?.uid ?? '',
      'authorName': me?.displayName ?? me?.email ?? 'Agent',
      'timestamp': FieldValue.serverTimestamp(),
    });
    if (mounted) setState(() => _sending = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    final myId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Column(children: [
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('community')
              .doc('main')
              .collection('messages')
              .orderBy('timestamp')
              .snapshots(),
          builder: (ctx, snap) {
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) {
              return Center(
                child: Text(
                  'Say hello to the team 👋',
                  style: TextStyle(color: gw.muted, fontSize: 14),
                ),
              );
            }
            return ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final m = docs[i].data() as Map<String, dynamic>;
                final isMe = m['authorId'] == myId;
                return _CommBubble(data: m, isMe: isMe);
              },
            );
          },
        ),
      ),
      Padding(
        // The enclosing Scaffold already resizes the body for the keyboard
        // (resizeToAvoidBottomInset defaults to true) but does NOT strip
        // viewInsets from the MediaQuery it hands the body. Adding
        // viewInsets.bottom here would double-count it and float the composer
        // a full keyboard-height above the keyboard.
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(children: [
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
                  hintText: 'Message the team…',
                  hintStyle: TextStyle(color: gw.muted, fontSize: 13.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Opacity(
            opacity: _sending ? 0.5 : 1.0,
            child: GestureDetector(
              onTap: _sending ? null : _send,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [const Color(0xFF4ADE80), gw.green, gw.greenDim],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: gw.green.withOpacity(.45),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const GwIcon(GwIcons.arrowUp,
                    size: 20, color: Colors.white),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }
}

class _CommBubble extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isMe;
  const _CommBubble({required this.data, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 3),
              child: Text(
                data['authorName'] ?? '',
                style: TextStyle(
                  color: gw.muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe
                  ? gw.green.withOpacity(.18)
                  : (gw.isDark
                      ? Colors.white.withOpacity(.09)
                      : Colors.white.withOpacity(.62)),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(isMe ? 14 : 3),
                bottomRight: Radius.circular(isMe ? 3 : 14),
              ),
              border: Border.all(
                color: isMe ? gw.green.withOpacity(.32) : gw.border,
                width: 1,
              ),
            ),
            child: Text(
              data['text'] ?? '',
              style: TextStyle(color: gw.text, fontSize: 13.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
