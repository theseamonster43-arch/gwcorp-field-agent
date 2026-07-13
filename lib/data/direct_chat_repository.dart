import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'models.dart';

class DirectChatRepository {
  static final _db     = FirebaseFirestore.instance;
  static CollectionReference get _chats => _db.collection('directChats');

  static Stream<List<DirectChat>> chatsStream(String myEmail) {
    if (myEmail.isEmpty) return Stream.value([]);
    return _chats
        .where('participants', arrayContains: myEmail)
        .snapshots()
        .map((snap) {
          final chats = snap.docs.map((d) {
            try {
              return DirectChat.fromMap(
                  d.data() as Map<String, dynamic>, d.id);
            } catch (_) {
              return null;
            }
          }).whereType<DirectChat>().toList();
          chats.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
          return chats;
        });
  }

  static Stream<List<DirectMessage>> messagesStream(String chatId) => _chats
      .doc(chatId)
      .collection('messages')
      .orderBy('timestamp')
      .snapshots()
      .map((s) => s.docs
          .map((d) {
            try {
              return DirectMessage.fromMap(
                  d.data() as Map<String, dynamic>, d.id);
            } catch (_) {
              return null;
            }
          })
          .whereType<DirectMessage>()
          .toList());

  static Stream<List<String>> typingStream(String chatId, String myEmail) =>
      _chats.doc(chatId).collection('typing').snapshots().map((s) {
        final now = DateTime.now().millisecondsSinceEpoch;
        return s.docs
            .where((d) => d.id != myEmail)
            .where((d) {
              final data = d.data();
              final isTyping  = (data['isTyping'] as bool?) ?? false;
              final updatedAt = (data['updatedAt'] as int?) ?? 0;
              return isTyping && now - updatedAt < 6000;
            })
            .map((d) => (d.data()['name'] as String?) ?? d.id)
            .toList();
      });

  static Future<void> setTyping(
      String chatId, String userEmail, String userName, bool isTyping) async {
    try {
      final ref = _chats.doc(chatId).collection('typing').doc(userEmail);
      if (isTyping) {
        await ref.set({
          'isTyping':  true,
          'name':      userName,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        await ref.delete();
      }
    } catch (_) {}
  }

  static Future<void> markRead(String chatId, String userEmail) async {
    try {
      await _chats.doc(chatId).update({
        'lastRead.$userEmail': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  static Future<void> toggleReaction(
      String chatId, String msgId, String emoji, String userEmail) async {
    final ref = _chats.doc(chatId).collection('messages').doc(msgId);
    await _db.runTransaction((t) async {
      final snap = await t.get(ref);
      final data = snap.data() as Map<String, dynamic>? ?? {};
      final reactions = Map<String, dynamic>.from(data['reactions'] as Map? ?? {});
      final users = List<String>.from(reactions[emoji] as List? ?? []);
      if (users.contains(userEmail)) {
        users.remove(userEmail);
      } else {
        users.add(userEmail);
      }
      if (users.isEmpty) {
        reactions.remove(emoji);
      } else {
        reactions[emoji] = users;
      }
      t.update(ref, {'reactions': reactions});
    });
  }

  static Future<String> createOrOpenChat({
    required String myEmail,
    required String myName,
    required List<String> targetEmails,
    required Map<String, String> targetNames,
    required bool isGroup,
    required String groupName,
  }) async {
    final participants = ({...targetEmails, myEmail}).toList()..sort();

    if (!isGroup && targetEmails.length == 1) {
      // Check if a 1-to-1 chat already exists via the user's own chat list
      final myChatsSnap = await _db
          .collection('users').doc(myEmail).collection('chats').get();
      for (final ref in myChatsSnap.docs) {
        final chatDoc = await _chats.doc(ref.id).get();
        if (!chatDoc.exists) continue;
        final data  = chatDoc.data() as Map<String, dynamic>;
        final parts = List<String>.from(data['participants'] ?? []);
        final grp   = data['isGroup'] as bool? ?? false;
        if (!grp && parts.length == 2 && parts.contains(targetEmails[0])) {
          return ref.id;
        }
      }
    }

    final names  = {...targetNames, myEmail: myName};
    final chatId = (await _chats.add({
      'participants':      participants,
      'participantNames':  names,
      'lastMessage':       '',
      'lastMessageTime':   DateTime.now().millisecondsSinceEpoch,
      'lastMessageSender': '',
      'isGroup':           isGroup,
      'groupName':         groupName,
      'createdBy':         myEmail,
      'lastRead':          <String, dynamic>{},
    })).id;

    // Register chatId under every participant's own user document
    await Future.wait(participants.map((email) =>
        _db.collection('users').doc(email).collection('chats').doc(chatId)
            .set({'joinedAt': DateTime.now().millisecondsSinceEpoch})));

    return chatId;
  }

  static Future<void> sendMessage(
    String chatId,
    String senderEmail,
    String senderName,
    String content, {
    String? replyToId,
    String? replyToContent,
    String? replyToSenderName,
  }) async {
    if (content.trim().isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final chatRef = _chats.doc(chatId);
    final batch   = _db.batch();
    batch.set(chatRef.collection('messages').doc(), <String, dynamic>{
      'senderEmail': senderEmail,
      'senderName':  senderName,
      'content':     content,
      'timestamp':   now,
      'reactions':   <String, dynamic>{},
      if (replyToId != null) 'replyToId':         replyToId,
      if (replyToId != null) 'replyToContent':     replyToContent ?? '',
      if (replyToId != null) 'replyToSenderName':  replyToSenderName ?? '',
    });
    batch.update(chatRef, {
      'lastMessage':       content,
      'lastMessageTime':   now,
      'lastMessageSender': senderEmail,
    });
    await batch.commit();
  }

  static Future<void> saveFcmToken(String userEmail, String token) async {
    try {
      await _db.collection('userTokens').doc(userEmail).set({
        'fcmToken':  token,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }
}
