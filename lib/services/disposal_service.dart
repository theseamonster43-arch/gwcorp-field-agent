import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

/// A place the agent can take waste to.
class DisposalSite {
  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final double? rating;
  final bool? openNow;

  /// Straight-line metres from the agent. Google returns no distance for a
  /// nearby search, so this is computed locally.
  final double distanceMeters;

  const DisposalSite({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.distanceMeters,
    this.rating,
    this.openNow,
  });

  String get distanceLabel => distanceMeters < 1000
      ? '${distanceMeters.round()} m'
      : '${(distanceMeters / 1000).toStringAsFixed(1)} km';

  /// Hands off to the Google Maps app for turn-by-turn. Doing it this way
  /// costs nothing — the Routes API is a billed SKU we do not need.
  Uri get directionsUri => Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
      );
}

/// Where each kind of waste is allowed to go.
///
/// The classifier already tells us what is in a batch, so the app can send the
/// agent to a facility that will actually accept it rather than to whatever
/// happens to be closest.
enum WasteRoute {
  hazardous('Hazardous', 'hazardous waste disposal facility'),
  eWaste('E-Waste', 'electronic waste recycling'),
  organic('Organic', 'composting facility'),
  recyclable('Recyclable', 'recycling center'),
  general('General', 'waste transfer station');

  const WasteRoute(this.label, this.query);
  final String label;
  final String query;

  /// Maps a classifier `wasteType` onto the facility that accepts it.
  static WasteRoute forWasteType(String wasteType) {
    switch (wasteType.trim().toLowerCase()) {
      case 'hazardous':
        return WasteRoute.hazardous;
      case 'e-waste':
      case 'ewaste':
        return WasteRoute.eWaste;
      case 'organic':
        return WasteRoute.organic;
      case 'plastic':
      case 'metal':
      case 'paper':
      case 'glass':
        return WasteRoute.recyclable;
      default:
        return WasteRoute.general;
    }
  }
}

class DisposalService {
  /// Restricted in Cloud Console to this app's package and signing
  /// fingerprint, so shipping it in the client is the intended design.
  static const _apiKey = String.fromEnvironment(
    'GW_MAPS_KEY',
    defaultValue: 'AIzaSyAtbVbVAV3DjNS59R2F1Ms0RVkUI_NckBQ',
  );

  static const _endpoint = 'https://places.googleapis.com/v1/places:searchText';

  /// Why the last search failed, for the UI to show. Null after a success.
  static String? lastError;

  /// Facilities are static and Places is a billed SKU, so results are cached
  /// per (route, rounded location) for the life of the process.
  static final Map<String, List<DisposalSite>> _cache = {};

  static Future<List<DisposalSite>> nearby({
    required WasteRoute route,
    required double lat,
    required double lng,
    double radiusMeters = 25000,
  }) async {
    // ~1km buckets — moving a few streets should reuse the cached answer.
    final key = '${route.name}:${lat.toStringAsFixed(2)}:${lng.toStringAsFixed(2)}';
    final hit = _cache[key];
    if (hit != null) return hit;

    try {
      final res = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          // Field mask is required, and it also controls billing tier — ask
          // for less, pay less.
          'X-Goog-FieldMask':
              'places.id,places.displayName,places.formattedAddress,'
              'places.location,places.rating,places.currentOpeningHours.openNow',
        },
        body: jsonEncode({
          'textQuery': route.query,
          'maxResultCount': 10,
          'locationBias': {
            'circle': {
              'center': {'latitude': lat, 'longitude': lng},
              'radius': radiusMeters,
            },
          },
        }),
      );

      if (res.statusCode != 200) {
        lastError = res.statusCode == 403
            ? 'Maps key rejected this request. Check the Places API restriction.'
            : 'Could not load disposal sites (${res.statusCode}).';
        // ignore: avoid_print
        print('DisposalService: HTTP ${res.statusCode} — ${res.body}');
        return const [];
      }

      final body   = jsonDecode(res.body) as Map<String, dynamic>;
      final places = body['places'];
      if (places is! List) {
        lastError = null;
        return const [];
      }

      final sites = <DisposalSite>[];
      for (final p in places) {
        if (p is! Map<String, dynamic>) continue;
        final loc = p['location'];
        if (loc is! Map<String, dynamic>) continue;
        final plat = (loc['latitude'] as num?)?.toDouble();
        final plng = (loc['longitude'] as num?)?.toDouble();
        if (plat == null || plng == null) continue;

        sites.add(DisposalSite(
          id: (p['id'] as String?) ?? '$plat,$plng',
          name: (p['displayName']?['text'] as String?) ?? 'Disposal site',
          address: (p['formattedAddress'] as String?) ?? '',
          lat: plat,
          lng: plng,
          rating: (p['rating'] as num?)?.toDouble(),
          openNow: p['currentOpeningHours']?['openNow'] as bool?,
          distanceMeters: _haversine(lat, lng, plat, plng),
        ));
      }

      sites.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
      lastError = null;
      _cache[key] = sites;
      return sites;
    } catch (e) {
      lastError = 'Could not reach Google Places. Check your connection.';
      // ignore: avoid_print
      print('DisposalService: $e');
      return const [];
    }
  }

  static void clearCache() => _cache.clear();

  /// Great-circle distance in metres.
  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final p1 = lat1 * 3.141592653589793 / 180;
    final p2 = lat2 * 3.141592653589793 / 180;
    final dp = (lat2 - lat1) * 3.141592653589793 / 180;
    final dl = (lon2 - lon1) * 3.141592653589793 / 180;
    final a = math.pow(math.sin(dp / 2), 2) +
        math.cos(p1) * math.cos(p2) * math.pow(math.sin(dl / 2), 2);
    return 2 * r * math.asin(math.sqrt(a).clamp(0.0, 1.0));
  }
}

