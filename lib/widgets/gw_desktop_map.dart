import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

import '../services/disposal_service.dart';
import '../services/gw_callable.dart';
import '../theme/gw_theme.dart';

/// The map, for Windows.
///
/// google_maps_flutter ships no Windows implementation, so the desktop app
/// renders the hosted /map page in a WebView2 surface instead. The page is
/// behind a single-use nonce, so this fetches a fresh ticket every time it
/// mounts — tickets expire after a minute and are burned on first use.
///
/// The page only draws. Everything billable still goes through the `maps`
/// proxy, so nothing here needs a Maps key.
class GwDesktopMap extends StatefulWidget {
  const GwDesktopMap({
    super.key,
    required this.sites,
    this.center,
    this.polyline,
    this.selectedId,
    this.onSelect,
  });

  final List<DisposalSite> sites;
  final ({double lat, double lng})? center;

  /// Encoded polyline from the Routes proxy, drawn as-is.
  final String? polyline;

  final String? selectedId;
  final void Function(String siteId)? onSelect;

  @override
  State<GwDesktopMap> createState() => _GwDesktopMapState();
}

class _GwDesktopMapState extends State<GwDesktopMap> {
  static const _origin = 'https://ihs-gwcorp.web.app';

  final _controller = WebviewController();
  StreamSubscription<dynamic>? _messages;

  bool _ready = false;      // the page has called back 'ready'
  String? _error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _messages?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(GwDesktopMap old) {
    super.didUpdateWidget(old);
    // Only push when something the page draws actually changed — executeScript
    // on every rebuild would redraw the markers continuously.
    if (widget.selectedId != old.selectedId ||
        widget.polyline != old.polyline ||
        widget.sites.length != old.sites.length ||
        widget.center != old.center) {
      _push();
    }
  }

  Future<void> _boot() async {
    try {
      await _controller.initialize();
      await _controller.setBackgroundColor(const Color(0xFF0A0F0C));

      _messages = _controller.webMessage.listen(_onMessage);

      final nonce = await _mintNonce();
      if (nonce == null) {
        if (mounted) setState(() => _error = 'Could not open the map.');
        return;
      }
      await _controller.loadUrl('$_origin/map?s=$nonce');
      if (mounted) setState(() {});
    } catch (e) {
      // WebView2 runtime missing is the likely cause on a bare Windows box.
      if (mounted) {
        setState(() => _error = 'Map unavailable. WebView2 may not be installed.');
      }
      // ignore: avoid_print
      print('GwDesktopMap: $e');
    }
  }

  Future<String?> _mintNonce() async {
    try {
      final res = await GwCallable.call('mapSession');
      final nonce = res['nonce'];
      return nonce is String && nonce.isNotEmpty ? nonce : null;
    } catch (e) {
      // ignore: avoid_print
      print('GwDesktopMap.nonce: $e');
      return null;
    }
  }

  void _onMessage(dynamic raw) {
    final map = raw is String
        ? jsonDecode(raw) as Map<String, dynamic>
        : Map<String, dynamic>.from(raw as Map);

    switch (map['type']) {
      case 'ready':
        _ready = true;
        _push();
      case 'select':
        final id = map['id'];
        if (id is String) widget.onSelect?.call(id);
    }
  }

  /// Hands the page everything it draws, in one call.
  Future<void> _push() async {
    if (!_ready) return;
    final payload = jsonEncode({
      if (widget.center != null)
        'center': {'lat': widget.center!.lat, 'lng': widget.center!.lng},
      'sites': [
        for (final s in widget.sites)
          {'id': s.id, 'name': s.name, 'lat': s.lat, 'lng': s.lng},
      ],
      'polyline': widget.polyline,
      'selectedId': widget.selectedId,
    });
    try {
      await _controller.executeScript('window.gwSetData($payload);');
    } catch (e) {
      // ignore: avoid_print
      print('GwDesktopMap.push: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: gw.muted, fontSize: 13),
          ),
        ),
      );
    }

    if (!_controller.value.isInitialized) {
      return Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.2, color: gw.green),
        ),
      );
    }

    return Webview(_controller);
  }
}
