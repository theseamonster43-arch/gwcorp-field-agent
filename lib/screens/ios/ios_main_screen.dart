import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/history_repository.dart';
import '../../data/models.dart';
import '../dashboard_screen.dart';
import '../chats_screen.dart';
import '../account_screen.dart';
import '../ai_chat_screen.dart';

class IosMainScreen extends StatefulWidget {
  const IosMainScreen({super.key});
  @override
  State<IosMainScreen> createState() => _IosMainScreenState();
}

class _IosMainScreenState extends State<IosMainScreen> {
  int _tab = 0;
  List<ScanSession> _sessions = [];
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    FirebaseAuth.instance.authStateChanges().listen((u) {
      if (mounted) setState(() => _user = u);
    });
    HistoryRepository.sessionsStream().listen((s) {
      if (mounted) setState(() => _sessions = s);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          DashboardScreen(
            onMenuClick: () {},
            sessionCount: _sessions.length,
          ),
          ChatsScreen(onNavigate: (p) => context.push(p)),
          AccountScreen(onNavigate: (p) => context.push(p)),
          AiChatScreen(onMenuClick: () {}),
        ],
      ),
      bottomNavigationBar: CNTabBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        split: true,
        rightCount: 1,
        items: [
          CNTabBarItem(label: 'Scans',   icon: CNSymbol('qrcode.viewfinder')),
          CNTabBarItem(label: 'Chats',   icon: CNSymbol('bubble.left.and.bubble.right')),
          CNTabBarItem(label: 'Account', icon: CNSymbol('person.circle')),
          CNTabBarItem(label: 'AI',      icon: CNSymbol('sparkles')),
        ],
      ),
    );
  }
}
