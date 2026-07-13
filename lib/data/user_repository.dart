import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String email;
  final String name;
  final String? photoUrl;

  const AppUser({required this.email, required this.name, this.photoUrl});

  factory AppUser.fromMap(Map<String, dynamic> m) {
    final photo = m['photoUrl'] as String?;
    return AppUser(
      email: m['email'] ?? '',
      name: m['name'] ?? m['email'] ?? '',
      photoUrl: (photo != null && photo.isNotEmpty) ? photo : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'name': name,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'lastActive': DateTime.now().millisecondsSinceEpoch,
      };
}

class UserRepository {
  static final _db    = FirebaseFirestore.instance;
  static CollectionReference get _users => _db.collection('users');

  static Future<void> saveProfile(AppUser user) async {
    try {
      await _users.doc(user.email).set(user.toMap(), SetOptions(merge: true));
    } catch (_) {}
  }

  static Stream<List<AppUser>> usersStream(String excludeEmail) => _users
      .snapshots()
      .map((s) => s.docs
          .map((d) => AppUser.fromMap(d.data() as Map<String, dynamic>))
          .where((u) => u.email != excludeEmail && u.email.isNotEmpty)
          .toList());
}
