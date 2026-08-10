import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// One agent's verdict on a place.
enum SiteVote {
  /// Went there and it accepted the load.
  takesWaste,

  /// Went there and it was not a disposal site, or refused the waste.
  notASite,
}

/// How much the team's verdict on a place can be trusted.
///
/// Confidence is not just "what did the majority say" — two agents agreeing is
/// far weaker evidence than two hundred, so the ratio is pulled toward
/// uncertain when the sample is small.
enum SiteConfidence {
  /// Nobody has been yet.
  unknown,

  /// A handful of reports leaning one way. Worth showing, worth doubting.
  reported,

  /// Enough agreement to rely on.
  confirmed,

  /// The team says this is not a disposal site.
  rejected,
}

/// The team's collective knowledge about one place.
class DisposalRecord {
  final String placeId;
  final String name;
  final String address;
  final double lat;
  final double lng;

  final int takesWasteVotes;
  final int notASiteVotes;

  /// Waste categories agents reported this site accepting.
  final List<String> acceptedWaste;

  final int updatedAt;

  const DisposalRecord({
    required this.placeId,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    this.takesWasteVotes = 0,
    this.notASiteVotes = 0,
    this.acceptedWaste = const [],
    this.updatedAt = 0,
  });

  int get totalVotes => takesWasteVotes + notASiteVotes;

  /// Agreement, smoothed so a lone vote cannot look like certainty.
  ///
  /// The `+3` pulls small samples toward 0.5: one "yes" lands around 0.63,
  /// five around 0.81, fifty near 0.99. That is the "low people, low chance"
  /// behaviour — the same ratio counts for more as more agents weigh in.
  double get confidence {
    if (totalVotes == 0) return 0.5;
    final ratio = takesWasteVotes / totalVotes;
    final weight = totalVotes / (totalVotes + 3);
    return 0.5 + (ratio - 0.5) * weight;
  }

  SiteConfidence get level {
    if (totalVotes == 0) return SiteConfidence.unknown;
    if (confidence < 0.4) return SiteConfidence.rejected;
    if (confidence >= 0.7 && takesWasteVotes >= 3) return SiteConfidence.confirmed;
    return SiteConfidence.reported;
  }

  /// Short line for the UI, e.g. "Verified · 12 agents".
  String get summary {
    switch (level) {
      case SiteConfidence.unknown:
        return 'No reports yet';
      case SiteConfidence.confirmed:
        return 'Verified · $takesWasteVotes agent${takesWasteVotes == 1 ? '' : 's'}';
      case SiteConfidence.reported:
        return notASiteVotes == 0
            ? 'Reported by $takesWasteVotes agent${takesWasteVotes == 1 ? '' : 's'}'
            : '$takesWasteVotes of $totalVotes agents say yes';
      case SiteConfidence.rejected:
        return '$notASiteVotes of $totalVotes agents say no';
    }
  }

  factory DisposalRecord.fromMap(Map<String, dynamic> m, String id) =>
      DisposalRecord(
        placeId: id,
        name: (m['name'] as String?) ?? '',
        address: (m['address'] as String?) ?? '',
        lat: (m['lat'] as num?)?.toDouble() ?? 0,
        lng: (m['lng'] as num?)?.toDouble() ?? 0,
        takesWasteVotes: (m['takesWasteVotes'] as num?)?.toInt() ?? 0,
        notASiteVotes: (m['notASiteVotes'] as num?)?.toInt() ?? 0,
        acceptedWaste:
            (m['acceptedWaste'] as List?)?.whereType<String>().toList() ?? const [],
        updatedAt: (m['updatedAt'] as num?)?.toInt() ?? 0,
      );
}

/// Shared registry of which places actually take waste.
///
/// Each agent's vote is its own document, so one person cannot flip a site on
/// their own and voting twice replaces their earlier call rather than stacking
/// another one. Running totals live on the parent so filtering a search does
/// not need to read every vote.
class DisposalRegistry {
  static final _db = FirebaseFirestore.instance;
  static CollectionReference get _col => _db.collection('disposalSites');

  static final Map<String, DisposalRecord> _cache = {};
  static final Map<String, SiteVote> _myVotes = {};
  static StreamSubscription<QuerySnapshot>? _sub;
  static String _email = '';

  /// Bumped whenever anything changes, so open screens can re-filter.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Starts mirroring the registry. Safe to call repeatedly.
  static void start(String myEmail) {
    _email = myEmail;
    if (_sub != null) return;
    _sub = _col.snapshots().listen((snap) {
      _cache
        ..clear()
        ..addEntries(snap.docs.map((d) => MapEntry(
              d.id,
              DisposalRecord.fromMap(d.data() as Map<String, dynamic>, d.id),
            )));
      revision.value++;
    }, onError: (Object e) {
      // ignore: avoid_print
      print('DisposalRegistry: $e');
    });
  }

  static void stop() {
    _sub?.cancel();
    _sub = null;
  }

  static DisposalRecord? of(String placeId) => _cache[placeId];

  static SiteConfidence levelOf(String placeId) =>
      _cache[placeId]?.level ?? SiteConfidence.unknown;

  /// This agent's own vote, once known. Populated lazily by [loadMyVote].
  static SiteVote? myVote(String placeId) => _myVotes[placeId];

  static Future<void> loadMyVote(String placeId) async {
    if (_email.isEmpty || _myVotes.containsKey(placeId)) return;
    try {
      final doc = await _col.doc(placeId).collection('votes').doc(_email).get();
      final v = doc.data()?['vote'] as String?;
      if (v != null) {
        _myVotes[placeId] = v == 'notASite' ? SiteVote.notASite : SiteVote.takesWaste;
        revision.value++;
      }
    } catch (_) {/* offline is fine — it just stays unknown */}
  }

  /// Casts or changes this agent's vote and keeps the totals in step.
  ///
  /// Done in a transaction because two agents voting at once would otherwise
  /// both read the same total and one increment would be lost.
  static Future<void> vote({
    required String placeId,
    required String name,
    required String address,
    required double lat,
    required double lng,
    required SiteVote vote,
  }) async {
    if (_email.isEmpty) return;
    final siteRef = _col.doc(placeId);
    final voteRef = siteRef.collection('votes').doc(_email);

    await _db.runTransaction((tx) async {
      // Every read must happen before any write.
      final voteSnap = await tx.get(voteRef);
      final siteSnap = await tx.get(siteRef);

      final previous = voteSnap.exists
          ? ((voteSnap.data() as Map<String, dynamic>)['vote'] as String?)
          : null;
      if (previous == vote.name) return; // unchanged

      final data = siteSnap.exists
          ? (siteSnap.data() as Map<String, dynamic>)
          : <String, dynamic>{};
      var yes = (data['takesWasteVotes'] as num?)?.toInt() ?? 0;
      var no = (data['notASiteVotes'] as num?)?.toInt() ?? 0;

      // Retract the old vote before counting the new one.
      if (previous == SiteVote.takesWaste.name) yes = yes > 0 ? yes - 1 : 0;
      if (previous == SiteVote.notASite.name) no = no > 0 ? no - 1 : 0;
      if (vote == SiteVote.takesWaste) yes++; else no++;

      tx.set(siteRef, {
        'name': name,
        'address': address,
        'lat': lat,
        'lng': lng,
        'takesWasteVotes': yes,
        'notASiteVotes': no,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));

      tx.set(voteRef, {
        'vote': vote.name,
        'at': DateTime.now().millisecondsSinceEpoch,
      });
    });

    _myVotes[placeId] = vote;
    revision.value++;
  }
}
