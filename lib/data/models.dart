import 'package:cloud_firestore/cloud_firestore.dart';

class ScanSession {
  final String id;
  final String location;
  final String date;
  final int itemCount;
  final int hazardCount;
  final int recyclableCount;
  final String userEmail;
  final List<ClassificationResult> items;
  final DateTime? timestamp;
  final List<String> imageUrls;

  ScanSession({
    required this.id,
    required this.location,
    required this.date,
    required this.itemCount,
    required this.hazardCount,
    required this.recyclableCount,
    required this.userEmail,
    required this.items,
    this.timestamp,
    this.imageUrls = const [],
  });

  /// Reads a session written by either client.
  ///
  /// The web app (public/field-agent.html) stores `results` and `recyclePct`;
  /// this app stores `items` and `recyclableCount`. Without accepting both,
  /// every scan made on the website shows up here with no items and zero
  /// recyclables, which silently wrecks the analytics.
  factory ScanSession.fromMap(Map<String, dynamic> map, String docId) {
    final rawItems = (map['items'] ?? map['results']) as List<dynamic>? ?? [];
    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map(ClassificationResult.fromMap)
        .toList();

    final itemCount = (map['itemCount'] as num?)?.toInt() ?? items.length;

    // recyclableCount if present, else derive it from the web's percentage,
    // else count the flags on the items themselves.
    int recyclable;
    if (map['recyclableCount'] is num) {
      recyclable = (map['recyclableCount'] as num).toInt();
    } else if (map['recyclePct'] is num) {
      recyclable = ((map['recyclePct'] as num) * itemCount / 100).round();
    } else {
      recyclable = items.where((i) => i.recyclable).length;
    }

    final hazard = (map['hazardCount'] as num?)?.toInt() ??
        items
            .where((i) =>
                i.hazardLevel.isNotEmpty &&
                i.hazardLevel.toLowerCase() != 'none')
            .length;

    return ScanSession(
      id: docId,
      location: map['location'] ?? '',
      date: map['date'] ?? '',
      itemCount: itemCount,
      hazardCount: hazard,
      recyclableCount: recyclable,
      userEmail: map['userEmail'] ?? '',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : map['timestamp'] is num
              ? DateTime.fromMillisecondsSinceEpoch(
                  (map['timestamp'] as num).toInt())
              : null,
      items: items,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'location': location,
        'date': date,
        'itemCount': itemCount,
        'hazardCount': hazardCount,
        'recyclableCount': recyclableCount,
        'userEmail': userEmail,
        'imageUrls': imageUrls,
        'timestamp': timestamp != null
            ? Timestamp.fromDate(timestamp!)
            : FieldValue.serverTimestamp(),
        'items': items.map((i) => i.toMap()).toList(),
      };

  /// Estimated mass of everything in this session, in kilograms.
  ///
  /// Derived rather than stored: sessions written before weight estimates
  /// existed, and items the classifier could not size, simply contribute
  /// nothing instead of making the total wrong.
  double get estimatedKg =>
      items.fold(0.0, (sum, i) => sum + (i.estimatedKg ?? 0));

  /// Mass kept out of landfill — the number a client actually asks for.
  ///
  /// Counts anything recyclable or headed for compost. Landfill and urgent
  /// removal are excluded: those were handled, not diverted, and calling them
  /// diverted would overstate the one figure this platform exists to report.
  double get divertedKg => items
      .where((i) =>
          i.recyclable ||
          i.recommendedAction.toLowerCase().contains('compost') ||
          i.recommendedAction.toLowerCase().contains('recycle'))
      .fold(0.0, (sum, i) => sum + (i.estimatedKg ?? 0));

  /// True when at least one item carries an estimate, so the UI can stay quiet
  /// rather than reporting a confident "0 kg" for an older session.
  bool get hasWeightData => items.any((i) => i.estimatedKg != null);
}

class ClassificationResult {
  final String itemName;
  final String wasteType;
  final bool recyclable;
  final String hazardLevel;
  final String condition;
  final String recommendedAction;
  final int confidence;
  final int? photoIndex; // which photo in the batch produced this item

  /// Rough mass in kilograms, estimated by the classifier from the photo.
  ///
  /// Nullable because an estimate is not always possible — a blurred shot or
  /// an item with no size reference is better left blank than guessed at. The
  /// figure is deliberately coarse: it exists to total up 'kg diverted from
  /// landfill' across hundreds of scans, where individual error averages out,
  /// not to weigh any single item accurately.
  final double? estimatedKg;

  ClassificationResult({
    required this.itemName,
    required this.wasteType,
    required this.recyclable,
    required this.hazardLevel,
    required this.condition,
    required this.recommendedAction,
    required this.confidence,
    this.photoIndex,
    this.estimatedKg,
  });

  ClassificationResult withPhotoIndex(int i) => ClassificationResult(
    itemName: itemName, wasteType: wasteType, recyclable: recyclable,
    hazardLevel: hazardLevel, condition: condition,
    recommendedAction: recommendedAction, confidence: confidence,
    photoIndex: i, estimatedKg: estimatedKg,
  );

  factory ClassificationResult.fromMap(Map<String, dynamic> m) => ClassificationResult(
        itemName: m['item_name'] ?? m['itemName'] ?? 'Unknown',
        wasteType: m['waste_type'] ?? m['wasteType'] ?? 'Mixed',
        recyclable: m['recyclable'] ?? false,
        hazardLevel: m['hazard_level'] ?? m['hazardLevel'] ?? 'None',
        condition: m['condition'] ?? 'Fresh',
        recommendedAction:
            m['recommended_action'] ?? m['recommendedAction'] ?? 'Landfill',
        confidence: m['confidence'] ?? 75,
        photoIndex: m['photoIndex'] as int?,
        estimatedKg: ((m['estimated_kg'] ?? m['estimatedKg']) as num?)?.toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'itemName': itemName,
        'wasteType': wasteType,
        'recyclable': recyclable,
        'hazardLevel': hazardLevel,
        'condition': condition,
        'recommendedAction': recommendedAction,
        'confidence': confidence,
        if (photoIndex != null) 'photoIndex': photoIndex,
        if (estimatedKg != null) 'estimatedKg': estimatedKg,
      };
}

class DirectChat {
  final String id;
  final List<String> participants;
  final Map<String, String> participantNames;
  final String lastMessage;
  final int lastMessageTime;
  final String lastMessageSender;
  final bool isGroup;
  final String groupName;
  final String createdBy;
  final Map<String, int> lastRead;

  DirectChat({
    required this.id,
    required this.participants,
    required this.participantNames,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastMessageSender,
    required this.isGroup,
    required this.groupName,
    required this.createdBy,
    this.lastRead = const {},
  });

  factory DirectChat.fromMap(Map<String, dynamic> m, String docId) => DirectChat(
        id: docId,
        participants: List<String>.from(m['participants'] ?? []),
        participantNames: Map<String, String>.from(m['participantNames'] ?? {}),
        lastMessage: m['lastMessage'] ?? '',
        lastMessageTime: m['lastMessageTime'] ?? 0,
        lastMessageSender: m['lastMessageSender'] ?? '',
        isGroup: m['isGroup'] ?? false,
        groupName: m['groupName'] ?? '',
        createdBy: m['createdBy'] ?? '',
        lastRead: Map<String, int>.from(m['lastRead'] ?? {}),
      );
}

class DirectMessage {
  final String id;
  final String senderEmail;
  final String senderName;
  final String content;
  final int timestamp;
  final String? replyToId;
  final String? replyToContent;
  final String? replyToSenderName;
  final Map<String, List<String>> reactions;

  DirectMessage({
    required this.id,
    required this.senderEmail,
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.replyToId,
    this.replyToContent,
    this.replyToSenderName,
    this.reactions = const {},
  });

  factory DirectMessage.fromMap(Map<String, dynamic> m, String docId) {
    final raw = m['reactions'] as Map<String, dynamic>? ?? {};
    final reactions = raw.map((k, v) =>
        MapEntry(k, List<String>.from(v as List? ?? [])));
    return DirectMessage(
      id: docId,
      senderEmail: m['senderEmail'] ?? '',
      senderName: m['senderName'] ?? '',
      content: m['content'] ?? '',
      timestamp: m['timestamp'] ?? 0,
      replyToId: m['replyToId'] as String?,
      replyToContent: m['replyToContent'] as String?,
      replyToSenderName: m['replyToSenderName'] as String?,
      reactions: reactions,
    );
  }
}

class ChannelMessage {
  final String id;
  final String text;
  final String authorId;
  final String authorName;
  final String? scanId;
  final String? scanSummary;
  final DateTime? timestamp;

  ChannelMessage({
    required this.id,
    required this.text,
    required this.authorId,
    required this.authorName,
    this.scanId,
    this.scanSummary,
    this.timestamp,
  });

  factory ChannelMessage.fromMap(Map<String, dynamic> m, String docId) =>
      ChannelMessage(
        id: docId,
        text: m['text'] ?? '',
        authorId: m['authorId'] ?? '',
        authorName: m['authorName'] ?? '',
        scanId: m['scanId'],
        scanSummary: m['scanSummary'],
        timestamp: (m['timestamp'] as Timestamp?)?.toDate(),
      );
}
