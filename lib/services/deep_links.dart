import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

/// A destination handed over from another device.
typedef GwHandoff = ({double lat, double lng, String name});

/// Set when the app is opened via gwcorp://satellite?lat=..&lng=..&n=..
///
/// The desktop app cannot navigate while someone is driving, so Start there
/// shows a QR pointing at go.html, which bounces the phone into this link.
/// Satellite watches this and routes to whatever lands here.
final gwPendingHandoff = ValueNotifier<GwHandoff?>(null);

/// Starts listening for handoff links. Safe to call once, from main.
///
/// Handles both the cold start (app launched *by* the link) and the warm case
/// (already running when the link arrives) — miss the first and a scan that
/// installs-then-opens the app silently does nothing.
Future<void> gwInitDeepLinks() async {
  final links = AppLinks();

  void handle(Uri? uri) {
    if (uri == null) return;
    if (uri.scheme != 'gwcorp') return;
    // gwcorp://satellite?... parses with 'satellite' as the host.
    if (uri.host != 'satellite' && !uri.path.contains('satellite')) return;

    final lat = double.tryParse(uri.queryParameters['lat'] ?? '');
    final lng = double.tryParse(uri.queryParameters['lng'] ?? '');
    if (lat == null || lng == null) return;

    gwPendingHandoff.value = (
      lat: lat,
      lng: lng,
      name: (uri.queryParameters['n'] ?? '').trim().isEmpty
          ? 'Disposal site'
          : uri.queryParameters['n']!.trim(),
    );
  }

  try {
    handle(await links.getInitialLink());
  } catch (_) {
    // No initial link, or the platform has no implementation. Not fatal.
  }

  links.uriLinkStream.listen(handle, onError: (Object _) {});
}
