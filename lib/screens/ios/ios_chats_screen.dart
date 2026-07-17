import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show CircleAvatar, Icons;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/direct_chat_repository.dart';
import '../../data/models.dart';
import '../../data/user_repository.dart';
import '../../widgets/gw_icon_button.dart';

class IosChatsList extends StatefulWidget {
  const IosChatsList({super.key});
  @override
  State<IosChatsList> createState() => _IosChatsListState();
}

class _IosChatsListState extends State<IosChatsList> {
  int _seg = 0;

  @override
  Widget build(BuildContext context) {
    final myEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_seg == 0 ? 'Messages' : 'Community'),
        trailing: _seg == 0
            ? GwIconButton(
                icon: Icons.add,
                size: 20,
                color: CupertinoColors.label.resolveFrom(context),
                onPressed: () => context.push('/main/newchat'),
              )
            : null,
      ),
      child: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: CupertinoSlidingSegmentedControl<int>(
              children: const {0: Text('Direct'), 1: Text('Community')},
              groupValue: _seg,
              onValueChanged: (v) => setState(() => _seg = v ?? 0),
            ),
          ),
          Expanded(
            child: _seg == 0
                ? _IosDmList(myEmail: myEmail)
                : _IosCommunityChat(),
          ),
        ]),
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
  List<AppUser>    _users = [];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DirectChat>>(
      stream: DirectChatRepository.chatsStream(widget.myEmail),
      builder: (ctx, chatSnap) {
        if (chatSnap.hasData) _chats = chatSnap.data!;
        return StreamBuilder<List<AppUser>>(
          stream: UserRepository.usersStream(widget.myEmail),
          builder: (ctx, userSnap) {
            if (userSnap.hasData) _users = userSnap.data!;
            final chattedEmails = _chats.expand((c) => c.participants).toSet();
            final newPeople = _users.where((u) => !chattedEmails.contains(u.email)).toList();

            if (_chats.isEmpty && newPeople.isEmpty) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.chat_bubble_outline, size: 40,
                      color: CupertinoColors.systemGrey),
                  const SizedBox(height: 12),
                  Text('No contacts yet',
                      style: TextStyle(
                          color: CupertinoColors.label.resolveFrom(context),
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  Text('Tap + to start a chat',
                      style: TextStyle(
                          color: CupertinoColors.secondaryLabel.resolveFrom(context),
                          fontSize: 13)),
                ]),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _chats.length + newPeople.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFF22C55E).withOpacity(0.15),
            child: Text(initial,
                style: const TextStyle(color: Color(0xFF22C55E),
                    fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: TextStyle(
                    color: CupertinoColors.label.resolveFrom(context),
                    fontSize: 15, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(preview,
                style: TextStyle(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    fontSize: 13),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          if (time.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(time,
                style: TextStyle(
                    color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                    fontSize: 11)),
          ],
          const SizedBox(width: 4),
          Icon(Icons.chevron_right,
              size: 14, color: CupertinoColors.tertiaryLabel.resolveFrom(context)),
        ]),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  final AppUser user;
  final String myEmail;
  const _PersonRow({required this.user, required this.myEmail});

  @override
  Widget build(BuildContext context) {
    final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';
    return GestureDetector(
      onTap: () async {
        final myName = FirebaseAuth.instance.currentUser?.displayName
            ?? myEmail.split('@')[0];
        final chatId = await DirectChatRepository.createOrOpenChat(
          myEmail: myEmail, myName: myName,
          targetEmails: [user.email],
          targetNames: {user.email: user.name},
          isGroup: false, groupName: '',
        );
        if (context.mounted) context.push('/main/directchat/$chatId');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: CupertinoColors.systemGrey5.resolveFrom(context),
            backgroundImage: (user.photoUrl?.isNotEmpty == true)
                ? NetworkImage(user.photoUrl!)
                : null,
            child: user.photoUrl == null
                ? Text(initial,
                    style: TextStyle(
                        color: CupertinoColors.label.resolveFrom(context),
                        fontSize: 17, fontWeight: FontWeight.w600))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user.name,
                style: TextStyle(
                    color: CupertinoColors.label.resolveFrom(context),
                    fontSize: 15, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(user.email,
                style: TextStyle(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    fontSize: 13),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Icon(Icons.chat_bubble_outline,
              size: 16, color: CupertinoColors.tertiaryLabel.resolveFrom(context)),
        ]),
      ),
    );
  }
}

// ── Community Chat ────────────────────────────────────────────────────────────

class _IosCommunityChat extends StatefulWidget {
  @override
  State<_IosCommunityChat> createState() => _IosCommunityChatState();
}

class _IosCommunityChatState extends State<_IosCommunityChat> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void dispose() { _ctrl.dispose(); _scroll.dispose(); super.dispose(); }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    final me = FirebaseAuth.instance.currentUser;
    _ctrl.clear();
    setState(() => _sending = true);
    await FirebaseFirestore.instance
        .collection('community').doc('main').collection('messages').add({
      'text':       text,
      'authorId':   me?.uid ?? '',
      'authorName': me?.displayName ?? me?.email ?? 'Agent',
      'timestamp':  FieldValue.serverTimestamp(),
    });
    if (mounted) setState(() => _sending = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Column(children: [
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('community').doc('main').collection('messages')
              .orderBy('timestamp').snapshots(),
          builder: (ctx, snap) {
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) {
              return Center(
                child: Text('Say hello to the team! 👋',
                    style: TextStyle(
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                        fontSize: 15)),
              );
            }
            return ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      Container(
        padding: EdgeInsets.only(
          left: 12, right: 8, top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 8,
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
              placeholder: 'Message the team…',
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
              enabled: !_sending,
              onPressed: _send,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe) Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 3),
            child: Text(data['authorName'] ?? '',
                style: TextStyle(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe
                  ? const Color(0xFF22C55E).withOpacity(0.15)
                  : CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(isMe ? 14 : 3),
                bottomRight: Radius.circular(isMe ? 3 : 14),
              ),
            ),
            child: Text(data['text'] ?? '',
                style: TextStyle(
                    color: CupertinoColors.label.resolveFrom(context),
                    fontSize: 14, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
