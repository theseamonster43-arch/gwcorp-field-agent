import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// What the team knows about a place, as opposed to what Google guesses.
enum SiteStatus {
  /// An agent has delivered here and it accepted the load.
  verified,

  /// An agent went and it was not a disposal site, or refused the waste.
  rejected,
}

/// A site an agent has actually been to.
///
/// Keyed by Google's place id so a record lines up with whatever Places
/// returns later, regardless of how the search was phrased.
class DisposalRecord {
  final String placeId;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final SiteStatus status;

  /// Waste categories this site takes, e.g. Hazardous, E-Waste.
  final List<String> acceptedWaste;

  final String notes;
  final String updatedBy;
  final int updatedAt;

  const DisposalRecord({
    required this.placeId,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.status,
    this.acceptedWaste = const [],
    this.notes = '',
    this.updatedBy = '',
    this.updatedAt = 0,
  });

  bool get isVerified => status == SiteStatus.verified;

  factory DisposalRecord.fromMap(Map<String, dynamic> m, String id) =>
      DisposalRecord(
        placeId: id,
        name: (m['name'] as String?) ?? '',
        address: (m['address'] as String?) ?? '',
        lat: (m['lat'] as num?)?.toDouble() ?? 0,
        lng: (m['lng'] as num?)?.toDouble() ?? 0,
        status: (m['status'] as String?) == 'rejected'
            ? SiteStatus.rejected
            : SiteStatus.verified,
        acceptedWaste:
            (m['acceptedWaste'] as List?)?.whereType<String>().toList() ?? const [],
        notes: (m['notes'] as String?) ?? '',
        updatedBy: (m['updatedBy'] as String?) ?? '',
        updatedAt: (m['updatedAt'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'address': address,
        'lat': lat,
        'lng': lng,
        'status': status == SiteStatus.rejected ? 'rejected' : 'verified',
        'acceptedWaste': acceptedWaste,
        'notes': notes,
        'updatedBy': updatedBy,
        'updatedAt': updatedAt,
      };
}

/// The team's shared list of places that do and do not take waste.
///
/// Small and slow-changing, so it is mirrored in memory and read
/// synchronously while filtering search results — a per-result Firestore
/// lookup during a search would be far too slow.
class DisposalRegistry {
  static final _db = FirebaseFirestore.instance;
  static CollectionReference get _col => _db.collection('disposalSites');

  static final Map<String, DisposalRecord> _cache = {};
  static StreamSubscription<QuerySnapshot>? _sub;

  /// Fires whenever the registry changes so open screens can re-filter.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Starts mirroring the collection. Safe to call repeatedly.
  static void start() {
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

  static bool isVerified(String placeId) => _cache[placeId]?.isVerified ?? false;

  static bool isRejected(String placeId) =>
      _cache[placeId]?.status == SiteStatus.rejected;

  /// Records a verdict. Writing under the place id keeps one row per site, so
  /// a later visit corrects the earlier call rather than adding a duplicate.
  static Future<void> record({
    required String placeId,
    required String name,
    required String address,
    required double lat,
    required double lng,
    required SiteStatus status,
    List<String> acceptedWaste = const [],
    String notes = '',
    required String updatedBy,
  }) async {
    final rec = DisposalRecord(
      placeId: placeId,
      name: name,
      address: address,
      lat: lat,
      lng: lng,
      status: status,
      acceptedWaste: acceptedWaste,
      notes: notes,
      updatedBy: updatedBy,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _col.doc(placeId).set(rec.toMap());
    // Apply locally straight away rather than waiting for the round trip.
    _cache[placeId] = rec;
    revision.value++;
  }

  static Future<void> clear(String placeId) async {
    await _col.doc(placeId).delete();
    _cache.remove(placeId);
    revision.value++;
  }
}
