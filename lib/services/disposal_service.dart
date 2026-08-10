import 'dart:convert';
import 'dart:io' show Platform;
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

  /// Google place types, e.g. recycling_center, storage, point_of_interest.
  final List<String> types;

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
    this.types = const [],
  });

  String get distanceLabel => distanceMeters < 1000
      ? '${distanceMeters.round()} m'
      : '${(distanceMeters / 1000).toStringAsFixed(1)} km';


  /// Words that mark somewhere as actually taking waste. A free-text search
  /// will happily return a pizzeria, and routing an agent there to drop off
  /// hazardous material is worse than returning nothing.
  static const _disposalWords = [
    'recycl', 'waste', 'scrap', 'salvage', 'junk', 'landfill', 'dump',
    'refuse', 'garbage', 'rubbish', 'compost', 'transfer station',
    'skip hire', 'e-waste', 'ewaste', 'sanitation', 'disposal',
  ];

  /// False when nothing about the place suggests it accepts waste.
  bool get acceptsWaste {
    final haystack = [name, address, ...types].join(' ').toLowerCase();
    return _disposalWords.any(haystack.contains);
  }


  /// Google place types that clearly are not somewhere you drop off waste.
  /// Filtering on these rather than on the absence of disposal words means a
  /// facility with an unusual name — Bee'ah, Enviroserve, Tadweer — is still
  /// shown, while a shopping mall is not.
  static const _notDisposalTypes = [
    'shopping_mall', 'restaurant', 'cafe', 'bar', 'bakery', 'food',
    'clothing_store', 'shoe_store', 'jewelry_store', 'book_store',
    'furniture_store', 'department_store', 'supermarket', 'grocery_store',
    'convenience_store', 'liquor_store', 'pharmacy', 'beauty_salon',
    'hair_care', 'spa', 'gym', 'lodging', 'hotel', 'school', 'university',
    'hospital', 'doctor', 'dentist', 'bank', 'atm', 'movie_theater',
    'night_club', 'casino', 'church', 'mosque', 'park', 'tourist_attraction',
    'gas_station', 'car_dealer', 'real_estate_agency', 'travel_agency',
  ];

  /// True when this is plainly a shop, restaurant or similar and nothing
  /// about it suggests it takes waste. Those get dropped from results.
  bool get isIrrelevant {
    if (acceptsWaste) return false;
    return types.any(_notDisposalTypes.contains);
  }

  /// Hands off to the Google Maps app for turn-by-turn. Doing it this way
  /// costs nothing — the Routes API is a billed SKU we do not need.
  Uri get directionsUri => Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
      );
}

/// One manoeuvre along the way — "Turn left onto Al Quoz Street".
class RouteStep {
  final String instruction;
  final String maneuver;
  final double distanceMeters;
  final double endLat;
  final double endLng;

  const RouteStep({
    required this.instruction,
    required this.maneuver,
    required this.distanceMeters,
    required this.endLat,
    required this.endLng,
  });

  String get distanceLabel => distanceMeters < 1000
      ? '${distanceMeters.round()} m'
      : '${(distanceMeters / 1000).toStringAsFixed(1)} km';
}

/// A drivable route to a site: how far, how long, and the line to draw.
class DisposalRoute {
  final double distanceMeters;
  final Duration duration;
  final List<({double lat, double lng})> points;
  final List<RouteStep> steps;

  const DisposalRoute({
    required this.distanceMeters,
    required this.duration,
    required this.points,
    this.steps = const [],
  });

  String get distanceLabel => distanceMeters < 1000
      ? '${distanceMeters.round()} m'
      : '${(distanceMeters / 1000).toStringAsFixed(1)} km';

  String get durationLabel {
    final m = duration.inMinutes;
    if (m < 1) return 'under a minute';
    if (m < 60) return '$m min';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem == 0 ? '$h hr' : '$h hr $rem min';
  }
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

  /// Package name and signing fingerprint the Android key is restricted to.
  /// The Maps SDK sends these automatically; a plain REST call has to add them
  /// by hand or Google sees an anonymous request and returns 403.
  static const _androidPackage = 'com.gwcorp.fieldagent';
  static const _androidCert    = 'A6A9FF1FE6770B4134E885C8825F5A221BB4F9A4';
  static const _iosBundleId    = 'com.gwcorp.fieldagent';

  /// Identity headers matching whichever key restriction applies here.
  static Map<String, String> get _appHeaders {
    if (Platform.isAndroid) {
      return {
        'X-Android-Package': _androidPackage,
        'X-Android-Cert':    _androidCert,
      };
    }
    if (Platform.isIOS) {
      return {'X-Ios-Bundle-Identifier': _iosBundleId};
    }
    // Desktop has no app identity to present, so it needs a key restricted by
    // referrer or left unrestricted with a tight API + quota limit.
    return const {};
  }

  /// Why the last search failed, for the UI to show. Null after a success.
  static String? lastError;

  /// Facilities are static and Places is a billed SKU, so results are cached
  /// per (route, rounded location) for the life of the process.
  static final Map<String, List<DisposalSite>> _cache = {};

  /// [query] overrides the route's default search text, so the search bar can
  /// look for anything ("scrap yard", "Bee'ah") while the chips stay a
  /// one-tap shortcut for the common categories.
  static Future<List<DisposalSite>> nearby({
    required WasteRoute route,
    required double lat,
    required double lng,
    String? query,
    double radiusMeters = 25000,
  }) async {
    final text = (query != null && query.trim().isNotEmpty)
        ? query.trim()
        : route.query;

    // ~1km buckets — moving a few streets should reuse the cached answer.
    final key = '$text:${lat.toStringAsFixed(2)}:${lng.toStringAsFixed(2)}';
    final hit = _cache[key];
    if (hit != null) return hit;

    try {
      final res = await http.post(
        Uri.parse(_endpoint),
        headers: {
          ..._appHeaders,
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          // Field mask is required, and it also controls billing tier — ask
          // for less, pay less.
          'X-Goog-FieldMask':
              'places.id,places.displayName,places.formattedAddress,'
              'places.location,places.rating,places.types,'
              'places.currentOpeningHours.openNow',
        },
        body: jsonEncode({
          'textQuery': text,
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
        lastError = switch (res.statusCode) {
          403 => Platform.isAndroid || Platform.isIOS
              ? 'Maps key rejected this app. Check the package name and SHA-1 on the key.'
              : 'Maps key rejected this request. Desktop needs a key without an app restriction.',
          400 => 'Places rejected the request. Is Places API (New) enabled?',
          _   => 'Could not load disposal sites (${res.statusCode}).',
        };
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
          types: (p['types'] as List?)?.whereType<String>().toList() ?? const [],
          distanceMeters: _haversine(lat, lng, plat, plng),
        ));
      }

      // Shops, restaurants and the like are noise in a disposal finder.
      final kept = sites.where((s) => !s.isIrrelevant).toList();
      final dropped = sites.length - kept.length;
      if (kept.isEmpty && dropped > 0) {
        lastError = 'No disposal sites match that. Those results were shops '
            'or venues, not waste facilities.';
      }
      sites
        ..clear()
        ..addAll(kept);

      sites.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
      if (sites.isNotEmpty) lastError = null;
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

  // ── Routing ───────────────────────────────────────────────────────────────

  static const _routesEndpoint =
      'https://routes.googleapis.com/directions/v2:computeRoutes';

  /// Drive time and the line to draw on the map. Null when Routes is
  /// unavailable — callers fall back to straight-line distance.
  static Future<DisposalRoute?> route({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    try {
      final res = await http.post(
        Uri.parse(_routesEndpoint),
        headers: {
          ..._appHeaders,
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask':
              'routes.duration,routes.distanceMeters,'
              'routes.polyline.encodedPolyline,'
              'routes.legs.steps.navigationInstruction,'
              'routes.legs.steps.distanceMeters,'
              'routes.legs.steps.endLocation',
        },
        body: jsonEncode({
          'origin': {
            'location': {'latLng': {'latitude': fromLat, 'longitude': fromLng}}
          },
          'destination': {
            'location': {'latLng': {'latitude': toLat, 'longitude': toLng}}
          },
          'travelMode': 'DRIVE',
          'routingPreference': 'TRAFFIC_AWARE',
        }),
      );

      if (res.statusCode != 200) {
        // ignore: avoid_print
        print('DisposalService.route: HTTP ${res.statusCode} — ${res.body}');
        return null;
      }

      final body   = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = body['routes'];
      if (routes is! List || routes.isEmpty) return null;
      final r = routes.first as Map<String, dynamic>;

      // Duration comes back as protobuf seconds, e.g. "834s".
      final rawDuration = (r['duration'] as String?) ?? '';
      final seconds = int.tryParse(rawDuration.replaceAll('s', '')) ?? 0;
      final encoded = r['polyline']?['encodedPolyline'] as String?;

      final steps = <RouteStep>[];
      final legs = r['legs'];
      if (legs is List && legs.isNotEmpty) {
        final raw = (legs.first as Map<String, dynamic>)['steps'];
        if (raw is List) {
          for (final st in raw) {
            if (st is! Map<String, dynamic>) continue;
            final nav = st['navigationInstruction'];
            final end = st['endLocation']?['latLng'];
            if (nav is! Map<String, dynamic> || end is! Map<String, dynamic>) continue;
            steps.add(RouteStep(
              instruction: (nav['instructions'] as String?) ?? '',
              maneuver: (nav['maneuver'] as String?) ?? '',
              distanceMeters: (st['distanceMeters'] as num?)?.toDouble() ?? 0,
              endLat: (end['latitude'] as num?)?.toDouble() ?? 0,
              endLng: (end['longitude'] as num?)?.toDouble() ?? 0,
            ));
          }
        }
      }

      return DisposalRoute(
        distanceMeters: (r['distanceMeters'] as num?)?.toDouble() ?? 0,
        duration: Duration(seconds: seconds),
        points: encoded == null ? const [] : decodePolyline(encoded),
        steps: steps,
      );
    } catch (e) {
      // ignore: avoid_print
      print('DisposalService.route: $e');
      return null;
    }
  }

  /// Google's encoded polyline format — a compact delta encoding of the path.
  static List<({double lat, double lng})> decodePolyline(String encoded) {
    final points = <({double lat, double lng})>[];
    var index = 0, lat = 0, lng = 0;

    while (index < encoded.length) {
      int result = 0, shift = 0, b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      result = 0;
      shift = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add((lat: lat / 1e5, lng: lng / 1e5));
    }
    return points;
  }

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

