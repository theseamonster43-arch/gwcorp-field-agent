import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:cloud_functions/cloud_functions.dart';
import 'gw_callable.dart';
import '../data/disposal_registry.dart';

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

  /// Photo resource names, e.g. 'places/ChIJ.../photos/AeJb...'. Fetched
  /// through [DisposalService.photoBytes] rather than a plain URL.
  final List<String> photoNames;

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
    this.photoNames = const [],
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

  /// What an agent recorded after actually going there. Null when nobody
  /// has been yet, in which case the heuristics below are all we have.
  DisposalRecord? get record => DisposalRegistry.of(id);

  SiteConfidence get confidence => DisposalRegistry.levelOf(id);

  /// Enough agents agree that this is treated as fact.
  bool get isVerified => confidence == SiteConfidence.confirmed;

  /// Some agents have vouched for it, but not enough to be sure.
  bool get isReported => confidence == SiteConfidence.reported;

  /// The team says no.
  bool get isRejected => confidence == SiteConfidence.rejected;

  /// True when this is plainly a shop, restaurant or similar and nothing
  /// about it suggests it takes waste. Those get dropped from results.
  bool get isIrrelevant {
    // Agents have been here, so stop guessing.
    if (isVerified || isReported) return false;
    if (isRejected) return true;
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

  /// The polyline as Google encoded it, kept alongside the decoded points so
  /// the desktop map page can hand it straight to the Maps JS decoder rather
  /// than shipping a few thousand coordinate pairs through a WebView bridge.
  final String? encoded;

  const DisposalRoute({
    required this.distanceMeters,
    required this.duration,
    required this.points,
    this.steps = const [],
    this.encoded,
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
  /// Every billable Maps call goes through the `maps` Cloud Function.
  ///
  /// No Maps key ships in the client any more. Phones could bind a key to their
  /// package or bundle id, but desktop can present no identity at all, so the
  /// only key that worked there was an unrestricted one — extractable from the
  /// exe by anyone who downloaded the installer. Proxying also puts the field
  /// mask server-side, and the field mask is what picks the billing tier.
  ///
  /// The keys in AndroidManifest.xml and AppDelegate.swift stay: those are for
  /// the Maps SDK drawing the map, which never touches this class.
  static Future<Map<String, dynamic>> _fn(Map<String, dynamic> args) =>
      GwCallable.call('maps', args);

  /// Turns a callable failure into something a field agent can act on.
  static String _describe(FirebaseFunctionsException e) => switch (e.code) {
        'unauthenticated'    => 'Sign in to search disposal sites.',
        'resource-exhausted' => 'Too many lookups this hour. Try again later.',
        'not-found'          => 'Maps service is not deployed yet.',
        // The real cause is worth showing: this path covers everything from a
        // missing plugin to an upstream 500, and "could not reach" sent us
        // hunting the network when it was neither time it happened.
        _                    => 'Maps error: ${e.message ?? e.code}',
      };

  /// Why the last search failed, for the UI to show. Null after a success.
  static String? lastError;

  /// Facilities are static and Places is a billed SKU, so results are cached
  /// per (route, rounded location) for the life of the process.
  static final Map<String, List<DisposalSite>> _cache = {};

  /// [query] overrides the route's default search text, so the search bar can
  /// look for anything ("scrap yard", "Bee'ah") while the chips stay a
  /// one-tap shortcut for the common categories.
  /// [lat]/[lng] are optional: a Wi-Fi-only tablet or a device indoors may
  /// never get a fix, and a text search still works without one — it just
  /// comes back unbiased rather than nearest-first.
  static Future<List<DisposalSite>> nearby({
    required WasteRoute route,
    double? lat,
    double? lng,
    String? query,
    double radiusMeters = 25000,
  }) async {
    final text = (query != null && query.trim().isNotEmpty)
        ? query.trim()
        : route.query;

    // ~1km buckets — moving a few streets should reuse the cached answer.
    final where = (lat == null || lng == null)
        ? 'anywhere'
        : '${lat.toStringAsFixed(2)}:${lng.toStringAsFixed(2)}';
    final key = '$text:$where';
    final hit = _cache[key];
    if (hit != null) return hit;

    try {
      final Map<String, dynamic> body;
      try {
        final res = await _fn({
          'mode': 'search',
          'query': text,
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
          'radiusMeters': radiusMeters,
        });
        body = Map<String, dynamic>.from(res['data'] as Map);
      } on FirebaseFunctionsException catch (e) {
        lastError = _describe(e);
        // ignore: avoid_print
        print('DisposalService: ${e.code} — ${e.message}');
        return const [];
      }

      final places = body['places'];
      if (places is! List) {
        lastError = null;
        return const [];
      }

      final sites = <DisposalSite>[];
      for (final raw in places) {
        // Never test for Map<String, dynamic> here. jsonDecode produces that,
        // but the callable plugin hands nested maps across the platform
        // channel as Map<Object?, Object?> — so a type check silently dropped
        // every result on Android while desktop, still on jsonDecode, worked.
        if (raw is! Map) continue;
        final p = Map<String, dynamic>.from(raw);

        final rawLoc = p['location'];
        if (rawLoc is! Map) continue;
        final loc = Map<String, dynamic>.from(rawLoc);

        final plat = (loc['latitude'] as num?)?.toDouble();
        final plng = (loc['longitude'] as num?)?.toDouble();
        if (plat == null || plng == null) continue;

        final displayName = p['displayName'];
        final openingHours = p['currentOpeningHours'];

        sites.add(DisposalSite(
          id: (p['id'] as String?) ?? '$plat,$plng',
          name: (displayName is Map ? displayName['text'] as String? : null) ??
              'Disposal site',
          address: (p['formattedAddress'] as String?) ?? '',
          lat: plat,
          lng: plng,
          rating: (p['rating'] as num?)?.toDouble(),
          openNow:
              openingHours is Map ? openingHours['openNow'] as bool? : null,
          types: (p['types'] as List?)?.whereType<String>().toList() ?? const [],
          photoNames: (p['photos'] as List?)
                  ?.whereType<Map>()
                  .map((ph) => ph['name'] as String?)
                  .whereType<String>()
                  .take(6)
                  .toList() ??
              const [],
          // No fix means no meaningful distance; 0 sorts them by relevance
          // instead, which is the best available ordering.
          distanceMeters: (lat == null || lng == null)
              ? 0
              : _haversine(lat, lng, plat, plng),
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

      // Somewhere the team has actually used outranks a closer unknown.
      // Somewhere the team has confirmed outranks a closer unknown, and a
      // few reports outrank none.
      int rank(DisposalSite x) => x.isVerified ? 0 : (x.isReported ? 1 : 2);
      sites.sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : a.distanceMeters.compareTo(b.distanceMeters);
      });
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

  /// Photo bytes for a Places photo resource.
  ///
  /// Fetched by hand rather than handed to Image.network because the key is
  /// restricted to this app — a plain image request carries no app identity
  /// headers and comes back 403.
  static final Map<String, Uint8List> _photoCache = {};

  static Future<Uint8List?> photoBytes(String photoName,
      {int maxWidthPx = 600}) async {
    final key = '$photoName:$maxWidthPx';
    final hit = _photoCache[key];
    if (hit != null) return hit;

    try {
      final res = await _fn({
        'mode': 'photo',
        'photoName': photoName,
        'maxWidthPx': maxWidthPx,
      });
      final b64 = res['base64'];
      if (b64 is! String || b64.isEmpty) return null;

      // Callables speak JSON, so the bytes arrive base64'd. Decoded once and
      // cached — the list is capped at 6 photos per site.
      final bytes = base64Decode(b64);
      _photoCache[key] = bytes;
      return bytes;
    } catch (e) {
      // ignore: avoid_print
      print('DisposalService.photo: $e');
      return null;
    }
  }

  /// Called when the registry changes — cached results were filtered and
  /// ordered against the old verdicts, so they are no longer valid.
  static void onRegistryChanged() => _cache.clear();

  // ── Routing ───────────────────────────────────────────────────────────────

  /// Drive time and the line to draw on the map. Null when Routes is
  /// unavailable — callers fall back to straight-line distance.
  static Future<DisposalRoute?> route({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    try {
      final res = await _fn({
        'mode': 'route',
        'fromLat': fromLat,
        'fromLng': fromLng,
        'toLat': toLat,
        'toLng': toLng,
      });

      final body   = Map<String, dynamic>.from(res['data'] as Map);
      final routes = body['routes'];
      if (routes is! List || routes.isEmpty) return null;
      // Same platform-channel caveat as the search parser: nested maps are
      // Map<Object?, Object?> on Android, so this cast would throw and the
      // route would come back null with no explanation.
      if (routes.first is! Map) return null;
      final r = Map<String, dynamic>.from(routes.first as Map);

      // Duration comes back as protobuf seconds, e.g. "834s".
      final rawDuration = (r['duration'] as String?) ?? '';
      final seconds = int.tryParse(rawDuration.replaceAll('s', '')) ?? 0;
      final polyline = r['polyline'];
      final encoded =
          polyline is Map ? polyline['encodedPolyline'] as String? : null;

      final steps = <RouteStep>[];
      final legs = r['legs'];
      if (legs is List && legs.isNotEmpty && legs.first is Map) {
        final raw = Map<String, dynamic>.from(legs.first as Map)['steps'];
        if (raw is List) {
          for (final rawStep in raw) {
            if (rawStep is! Map) continue;
            final st = Map<String, dynamic>.from(rawStep);

            final nav = st['navigationInstruction'];
            final endLocation = st['endLocation'];
            if (nav is! Map || endLocation is! Map) continue;
            final end = endLocation['latLng'];
            if (end is! Map) continue;

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
        encoded: encoded,
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

