import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/direct_chat_repository.dart';
import '../theme/gw_theme.dart';
import '../widgets/gw_nav_bar.dart';

class NewDirectChatScreen extends StatefulWidget {
  final void Function(BuildContext ctx) onDismiss;
  final void Function(BuildContext ctx, String chatId, DirectChat chat) onChatCreated;
  const NewDirectChatScreen({super.key, required this.onDismiss, required this.onChatCreated});

  @override
  State<NewDirectChatScreen> createState() => _NewDirectChatScreenState();
}

class _NewDirectChatScreenState extends State<NewDirectChatScreen> {
  final _emailCtrl  = TextEditingController();
  final _groupCtrl  = TextEditingController();
  final _added      = <String>[];
  bool _isGroup     = false;
  bool _loading     = false;
  String _error     = '';

  String get _myEmail => FirebaseAuth.instance.currentUser?.email ?? '';
  String get _myName  =>
      FirebaseAuth.instance.currentUser?.displayName?.trim().isNotEmpty == true
          ? FirebaseAuth.instance.currentUser!.displayName!
          : _myEmail;

  void _addEmail() {
    final e = _emailCtrl.text.trim().toLowerCase();
    if (e.isEmpty)               { setState(() => _error = 'Enter an email'); return; }
    if (!e.contains('@'))        { setState(() => _error = 'Invalid email'); return; }
    if (e == _myEmail)           { setState(() => _error = "That's your own email"); return; }
    if (_added.contains(e))      { setState(() => _error = 'Already added'); return; }
    setState(() { _added.add(e); _emailCtrl.clear(); _error = ''; });
  }

  Future<void> _start() async {
    if (_added.isEmpty) { setState(() => _error = 'Add at least one email'); return; }
    if (_isGroup && _groupCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter a group name'); return;
    }
    setState(() { _loading = true; _error = ''; });
    try {
      final names  = Map.fromEntries(_added.map((e) => MapEntry(e, e.split('@')[0])));
      final chatId = await DirectChatRepository.createOrOpenChat(
        myEmail: _myEmail, myName: _myName,
        targetEmails: List.from(_added),
        targetNames: names,
        isGroup: _isGroup && _added.length >= 2,
        groupName: _groupCtrl.text.trim(),
      );
      final chat = DirectChat(
        id: chatId, participants: ([..._added, _myEmail]..sort()),
        participantNames: {...names, _myEmail: _myName},
        lastMessage: '', lastMessageTime: 0, lastMessageSender: '',
        isGroup: _isGroup && _added.length >= 2,
        groupName: _groupCtrl.text.trim(), createdBy: _myEmail,
      );
      if (mounted) widget.onChatCreated(context, chatId, chat);
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  void dispose() { _emailCtrl.dispose(); _groupCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    return Scaffold(
      backgroundColor: gw.bg,
      appBar: GwNavBar(title: 'New Message',
          onBack: () => widget.onDismiss(context)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('TO', style: TextStyle(color: gw.muted, fontSize: 9,
              fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 8),

          // Email chips
          ..._added.map((e) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: gw.greenGlow, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: gw.green.withOpacity(0.3)),
            ),
            child: Row(children: [
              CircleAvatar(radius: 12, backgroundColor: gw.green.withOpacity(0.2),
                  child: Text(e[0].toUpperCase(),
                      style: TextStyle(color: gw.green, fontSize: 10, fontWeight: FontWeight.w700))),
              const SizedBox(width: 8),
              Expanded(child: Text(e, style: TextStyle(color: gw.text, fontSize: 13))),
              GestureDetector(
                onTap: () => setState(() => _added.remove(e)),
                child: Icon(Icons.close, size: 16, color: gw.muted),
              ),
            ]),
          )),

          Row(children: [
            Expanded(
              child: TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: gw.text, fontSize: 13),
                onSubmitted: (_) => _addEmail(),
                decoration: InputDecoration(
                  hintText: 'Enter email address',
                  hintStyle: TextStyle(color: gw.muted, fontSize: 13),
                  filled: true, fillColor: gw.bg3,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: gw.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: gw.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: gw.green.withOpacity(0.6))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _addEmail,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: gw.bg3, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: gw.border),
                ),
                child: Text('Add', style: TextStyle(color: gw.green, fontSize: 13,
                    fontWeight: FontWeight.w600)),
              ),
            ),
          ]),

          if (_added.length >= 2) ...[
            const SizedBox(height: 16),
            Row(children: [
              Switch(
                value: _isGroup,
                onChanged: (v) => setState(() => _isGroup = v),
                activeColor: gw.green,
              ),
              const SizedBox(width: 12),
              Text('Group chat', style: TextStyle(color: gw.text, fontSize: 14)),
            ]),
            if (_isGroup) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _groupCtrl,
                style: TextStyle(color: gw.text, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Group name e.g. Site Alpha Team',
                  hintStyle: TextStyle(color: gw.muted, fontSize: 13),
                  filled: true, fillColor: gw.bg3,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: gw.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: gw.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: gw.green.withOpacity(0.6))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ],

          if (_error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: gw.red.withOpacity(0.08), borderRadius: BorderRadius.circular(8),
                border: Border.all(color: gw.red.withOpacity(0.2)),
              ),
              child: Text(_error, style: TextStyle(color: gw.red, fontSize: 12)),
            ),
          ],

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _added.isEmpty || _loading ? null : _start,
              style: ElevatedButton.styleFrom(
                backgroundColor: gw.green,
                foregroundColor: gw.isDark ? gw.bg : Colors.white,
                disabledBackgroundColor: gw.green.withOpacity(0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2,
                          color: gw.isDark ? gw.bg : Colors.white))
                  : Text(
                      _isGroup && _added.length >= 2 ? 'Create Group Chat' : 'Start Chat',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }
}
