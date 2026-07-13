import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models.dart';

class HistoryRepository {
  static final _db   = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static CollectionReference _sessionsRef(String uid) =>
      _db.collection('scans').doc(uid).collection('sessions');

  static Stream<List<ScanSession>> sessionsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _sessionsRef(uid)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ScanSession.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  static Future<ScanSession?> getSession(String sessionId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _sessionsRef(uid).doc(sessionId).get();
    if (!doc.exists) return null;
    return ScanSession.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  static Future<void> saveSession(ScanSession session) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _sessionsRef(uid).doc(session.id).set(session.toMap());
  }

  static Future<void> clearAll() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final snap = await _sessionsRef(uid).get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }
}
