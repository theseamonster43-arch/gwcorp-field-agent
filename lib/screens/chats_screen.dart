import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models.dart';
import '../data/direct_chat_repository.dart';
import '../data/user_repository.dart';
import '../theme/gw_theme.dart';
import '../widgets/gw_nav_bar.dart';
import 'package:intl/intl.dart';

class ChatsScreen extends StatefulWidget {
  final ValueChanged<String> onNavigate;
  final ValueChanged<DirectChat>? onSelectChat;
  const ChatsScreen({super.key, required this.onNavigate, this.onSelectChat});
  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  int _tab = 0; // 0 = Direct, 1 = Community

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    return Scaffold(
      backgroundColor: gw.bg,
      appBar: GwNavBar(
        title: _tab == 0 ? 'Messages' : 'Community',
        actions: _tab == 0
            ? [
                GestureDetector(
                  onTap: () => widget.onNavigate('/main/newchat'),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: GwTheme.of(context).greenGlow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: GwTheme.of(context).green.withOpacity(0.35)),
                    ),
                    child: Icon(Icons.add, size: 18, color: GwTheme.of(context).green),
                  ),
                ),
              ]
            : [],
      ),
      body: Column(children: [
        // Tab bar
        Container(
          color: gw.bg2,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(children: [
            _tabChip(gw, 'Direct', 0),
            const SizedBox(width: 8),
            _tabChip(gw, 'Community', 1),
          ]),
        ),
        Divider(color: gw.border, height: 1),
        Expanded(child: _tab == 0
            ? _DmList(
                myEmail: FirebaseAuth.instance.currentUser?.email ?? '',
                onSelect: widget.onSelectChat ??
                    (c) => widget.onNavigate('/main/directchat/${c.id}'),
              )
            : const CommunityChatPanel()),
      ]),
    );
  }

  Widget _tabChip(GwColors gw, String label, int i) {
    final sel = _tab == i;
    return GestureDetector(
      onTap: () => setState(() => _tab = i),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? gw.greenGlow : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: sel ? gw.green.withOpacity(0.35) : gw.border),
        ),
        child: Text(label, style: TextStyle(
          color: sel ? gw.green : gw.muted, fontSize: 12,
          fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

// ── Tablet / Desktop chat list panel ──────────────────────────────────────────

class ChatListPanel extends StatelessWidget {
  final String myEmail;
  final String? selectedChatId;
  final ValueChanged<DirectChat> onSelectChat;
  final VoidCallback onNewChat;
  const ChatListPanel({super.key, required this.myEmail, this.selectedChatId,
      required this.onSelectChat, required this.onNewChat});

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Expanded(child: Text('MESSAGES', style: TextStyle(color: gw.text, fontSize: 13,
                fontWeight: FontWeight.w900, letterSpacing: -0.2))),
            GestureDetector(
              onTap: onNewChat,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: gw.green, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.add, size: 20, color: gw.isDark ? gw.bg : Colors.white),
              ),
            ),
          ]),
        ),
        Divider(color: gw.border, height: 1),
        Expanded(child: _CombinedList(
          myEmail: myEmail,
          selectedChatId: selectedChatId,
          onSelectChat: onSelectChat,
        )),
      ]),
    );
  }
}

class _CombinedList extends StatefulWidget {
  final String myEmail;
  final String? selectedChatId;
  final ValueChanged<DirectChat> onSelectChat;
  const _CombinedList({required this.myEmail, this.selectedChatId, required this.onSelectChat});
  @override
  State<_CombinedList> createState() => _CombinedListState();
}

class _CombinedListState extends State<_CombinedList> {
  List<DirectChat> _chats  = [];
  List<AppUser>    _users  = [];

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    final myEmail        = widget.myEmail;
    final selectedChatId = widget.selectedChatId;
    final onSelectChat   = widget.onSelectChat;
    return StreamBuilder<List<DirectChat>>(
      stream: DirectChatRepository.chatsStream(myEmail),
      builder: (ctx, chatSnap) {
        if (chatSnap.hasError) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_outline, color: gw.amber, size: 32),
              const SizedBox(height: 10),
              Text('Firestore access blocked', style: TextStyle(color: gw.text,
                  fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                'Update your Firebase Console rules:\n'
                'allow read, write: if request.auth != null',
                style: TextStyle(color: gw.muted, fontSize: 11, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text('${chatSnap.error}',
                  style: TextStyle(color: gw.red, fontSize: 10),
                  textAlign: TextAlign.center),
            ]),
          ));
        }
        if (chatSnap.hasData) _chats = chatSnap.data!;
        return StreamBuilder<List<AppUser>>(
          stream: UserRepository.usersStream(myEmail),
          builder: (ctx, userSnap) {
            if (userSnap.hasData) _users = userSnap.data!;
            final chats    = _chats;
            final allUsers = _users;

            // People who already have a chat
            final chattedEmails = chats.expand((c) => c.participants).toSet();

            // People without an existing chat
            final newPeople = allUsers
                .where((u) => !chattedEmails.contains(u.email))
                .toList();

            if (chats.isEmpty && newPeople.isEmpty) {
              return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('◎', style: TextStyle(fontSize: 28, color: gw.muted)),
                const SizedBox(height: 8),
                Text('No contacts yet', style: TextStyle(color: gw.text, fontSize: 12,
                    fontWeight: FontWeight.w600)),
                Text('Tap + to start a chat', style: TextStyle(color: gw.muted, fontSize: 11)),
              ]));
            }

            final itemCount = chats.length + newPeople.length;
            return ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: itemCount,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (_, i) {
                if (i < chats.length) {
                  final chat = chats[i];
                  return ChatRowItem(
                    chat: chat, myEmail: myEmail,
                    isSelected: chat.id == selectedChatId,
                    onTap: () => onSelectChat(chat),
                  );
                }
                final user = newPeople[i - chats.length];
                return _PersonRow(
                  user: user, gw: gw,
                  onTap: () async {
                    final myName = FirebaseAuth.instance.currentUser?.displayName
                        ?? myEmail.split('@')[0];
                    final chatId = await DirectChatRepository.createOrOpenChat(
                      myEmail: myEmail, myName: myName,
                      targetEmails: [user.email],
                      targetNames: {user.email: user.name},
                      isGroup: false, groupName: '',
                    );
                    final chat = DirectChat(
                      id: chatId,
                      participants: [myEmail, user.email],
                      participantNames: {myEmail: myName, user.email: user.name},
                      lastMessage: '',
                      lastMessageTime: 0,
                      lastMessageSender: '',
                      isGroup: false,
                      groupName: '',
                      createdBy: myEmail,
                    );
                    onSelectChat(chat);
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _PersonRow extends StatelessWidget {
  final AppUser user;
  final GwColors gw;
  final VoidCallback onTap;
  const _PersonRow({required this.user, required this.gw, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: gw.bg3,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: gw.border),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 20, backgroundColor: gw.bg2,
            backgroundImage: (user.photoUrl != null && user.photoUrl!.isNotEmpty) ? NetworkImage(user.photoUrl!) : null,
            child: user.photoUrl == null
                ? Text(initial, style: TextStyle(color: gw.muted, fontSize: 16,
                    fontWeight: FontWeight.w700))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user.name, style: TextStyle(color: gw.text, fontSize: 14,
                fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(user.email, style: TextStyle(color: gw.muted, fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Icon(Icons.chat_bubble_outline, size: 16, color: gw.muted),
        ]),
      ),
    );
  }
}

class ChatRowItem extends StatelessWidget {
  final DirectChat chat;
  final String myEmail;
  final bool isSelected;
  final VoidCallback onTap;
  const ChatRowItem({super.key, required this.chat, required this.myEmail,
      required this.isSelected, required this.onTap});

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
            : '${(chat.participantNames[chat.lastMessageSender] ?? chat.lastMessageSender.split('@')[0]).split(' ')[0]}: ${chat.lastMessage}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? gw.greenGlow : gw.bg3,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? gw.green.withOpacity(0.3) : gw.border),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 20, backgroundColor: gw.greenGlow,
            child: Text(initial, style: TextStyle(color: gw.green, fontSize: 16,
                fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: TextStyle(color: gw.text, fontSize: 14,
                fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(preview, style: TextStyle(color: gw.muted, fontSize: 12),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          if (time.isNotEmpty) Text(time, style: TextStyle(color: gw.muted, fontSize: 10)),
        ]),
      ),
    );
  }
}

// ── DM list (phone) ────────────────────────────────────────────────────────────

class _DmList extends StatelessWidget {
  final String myEmail;
  final ValueChanged<DirectChat> onSelect;
  const _DmList({required this.myEmail, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return _CombinedList(
      myEmail: myEmail,
      onSelectChat: onSelect,
    );
  }
}

// ── Community channel ──────────────────────────────────────────────────────────

class CommunityChatPanel extends StatefulWidget {
  const CommunityChatPanel({super.key});
  @override
  State<CommunityChatPanel> createState() => _CommunityChatState();
}

class _CommunityChatState extends State<CommunityChatPanel> {
  final _ctrl      = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  @override
  void dispose() { _ctrl.dispose(); _scrollCtrl.dispose(); super.dispose(); }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
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
    setState(() => _sending = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
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
              .collection('community').doc('main').collection('messages')
              .orderBy('timestamp').snapshots(),
          builder: (ctx, snap) {
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) {
              return Center(child: Text('Say hello to the team!',
                  style: TextStyle(color: gw.muted)));
            }
            return ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(14),
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final m = docs[i].data() as Map<String, dynamic>;
                final isMe = m['authorId'] == myId;
                return _MsgBubble(data: m, isMe: isMe);
              },
            );
          },
        ),
      ),
      Divider(color: gw.border, height: 1),
      Padding(
        padding: EdgeInsets.only(
            left: 12, right: 12, top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              style: TextStyle(color: gw.text, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Message the team…',
                hintStyle: TextStyle(color: gw.muted, fontSize: 13),
                filled: true, fillColor: gw.bg3,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: gw.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: gw.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: gw.green.withOpacity(0.4))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sending ? null : _send,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: gw.green, borderRadius: BorderRadius.circular(10)),
              child: Text('→', style: TextStyle(color: gw.isDark ? gw.bg : Colors.white,
                  fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    ]);
  }
}

class _MsgBubble extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isMe;
  const _MsgBubble({required this.data, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.only(
      topLeft:     const Radius.circular(12),
      topRight:    const Radius.circular(12),
      bottomLeft:  Radius.circular(isMe ? 12 : 2),
      bottomRight: Radius.circular(isMe ? 2 : 12),
    ));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe) Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 3),
            child: Text(data['authorName'] ?? '',
                style: TextStyle(color: gw.muted, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
          Container(
            constraints: const BoxConstraints(maxWidth: 290),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: ShapeDecoration(
              color: isMe ? gw.green.withOpacity(0.1) : gw.bg2,
              shape: shape,
            ),
            child: Text(data['text'] ?? '',
                style: TextStyle(color: gw.text, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
