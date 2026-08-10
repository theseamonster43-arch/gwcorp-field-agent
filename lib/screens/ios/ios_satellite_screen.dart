import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models.dart';
import '../../services/claude_service.dart';
import '../../services/disposal_service.dart';
import '../../theme/gw_theme.dart';
import '../../widgets/gw_glass.dart';
import '../../widgets/gw_icons.dart';

/// Full-bleed satellite map with the search, results and route drawn over it.
///
/// The route is computed and drawn in-app rather than punting to the Maps app,
/// so the agent sees drive time before committing. Handing off to Maps stays
/// available as "Start", which is where turn-by-turn belongs.
///
/// google_maps_flutter has no Windows/Linux implementation, so desktop falls
/// back to the list. The Places and Routes calls are plain HTTP and work
/// everywhere.
class IosSatelliteScreen extends StatefulWidget {
  final bool showBack;
  final List<ScanSession> sessions;

  const IosSatelliteScreen({
    super.key,
    this.showBack = true,
    this.sessions = const [],
  });

  @override
  State<IosSatelliteScreen> createState() => _IosSatelliteScreenState();
}

class _IosSatelliteScreenState extends State<IosSatelliteScreen> {
  static bool get _mapSupported => Platform.isAndroid || Platform.isIOS;

  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;

  Position? _pos;
  List<DisposalSite> _sites = [];
  final Set<String> _picked = {};

  DisposalSite? _selected;
  DisposalRoute? _route;
  bool _routing = false;

  bool _listOpen = false;
  bool _loading = true;
  String? _error;

  String? _advice;
  bool _thinking = false;

  GoogleMapController? _map;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _map?.dispose();
    super.dispose();
  }

  List<ScanSession> get _attached =>
      widget.sessions.where((s) => _picked.contains(s.id)).toList();

  Future<void> _locate() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() { _loading = false; _error = 'Turn on location services.'; });
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        setState(() { _loading = false; _error = 'Location permission is needed.'; });
        return;
      }

      // Cached fix first so the map has something to show immediately.
      final cached = await Geolocator.getLastKnownPosition();
      if (cached != null && mounted) {
        setState(() => _pos = cached);
        await _search();
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;
      final moved = _pos == null ||
          Geolocator.distanceBetween(
              _pos!.latitude, _pos!.longitude, pos.latitude, pos.longitude) > 500;
      setState(() => _pos = pos);
      if (moved) await _search();
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_pos == null) _error = 'Timed out getting your location.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_pos == null) _error = 'Could not get your location.';
      });
    }
  }

  Future<void> _search() async {
    final pos = _pos;
    if (pos == null) return;
    setState(() { _loading = true; _error = null; });

    final sites = await DisposalService.nearby(
      route: WasteRoute.recyclable,
      lat: pos.latitude,
      lng: pos.longitude,
      query: _searchCtrl.text,
    );
    if (!mounted) return;
    setState(() {
      _sites = sites;
      _loading = false;
      _listOpen = sites.isNotEmpty;
      _error = sites.isEmpty
          ? (DisposalService.lastError ?? 'Nothing found nearby.')
          : null;
    });
  }

  void _onQueryChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _search);
  }

  /// Draws the route and frames both ends on the map.
  Future<void> _select(DisposalSite s) async {
    final pos = _pos;
    _searchFocus.unfocus();
    setState(() {
      _selected = s;
      _route = null;
      _listOpen = false;
      _routing = true;
    });
    if (pos == null) { setState(() => _routing = false); return; }

    final r = await DisposalService.route(
      fromLat: pos.latitude, fromLng: pos.longitude,
      toLat: s.lat, toLng: s.lng,
    );
    if (!mounted) return;
    setState(() { _route = r; _routing = false; });

    await _map?.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(
          pos.latitude  < s.lat ? pos.latitude  : s.lat,
          pos.longitude < s.lng ? pos.longitude : s.lng),
        northeast: LatLng(
          pos.latitude  > s.lat ? pos.latitude  : s.lat,
          pos.longitude > s.lng ? pos.longitude : s.lng),
      ),
      64,
    ));
  }

  void _clearRoute() => setState(() {
        _selected = null;
        _route = null;
        _advice = null;
      });

  Future<void> _startNavigation(DisposalSite s) =>
      launchUrl(s.directionsUri, mode: LaunchMode.externalApplication);

  // ── Attach scans ──────────────────────────────────────────────────────────
  Future<void> _pickScans() async {
    final gw = GwTheme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(.45),
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 14, right: 14,
            bottom: MediaQuery.of(sheetContext).padding.bottom + 14,
          ),
          child: GwGlass(
            radius: 26,
            blur: 30,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 38, height: 4,
                decoration: BoxDecoration(
                  color: gw.muted.withOpacity(.5),
                  borderRadius: BorderRadius.circular(99)),
              ),
              const SizedBox(height: 14),
              Text('Add your scans', style: TextStyle(
                color: gw.text, fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('The assistant uses these to pick the right site',
                  style: TextStyle(color: gw.muted, fontSize: 11.5)),
              const SizedBox(height: 14),
              if (widget.sessions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text('No scans yet.',
                      style: TextStyle(color: gw.muted, fontSize: 13)),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: widget.sessions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final s  = widget.sessions[i];
                      final on = _picked.contains(s.id);
                      return GwGlass(
                        radius: 14,
                        blur: 12,
                        padding: const EdgeInsets.all(12),
                        accent: on ? gw.green : null,
                        onTap: () {
                          setSheet(() {
                            if (on) { _picked.remove(s.id); } else { _picked.add(s.id); }
                          });
                          setState(() => _advice = null);
                        },
                        child: Row(children: [
                          GwIcon(on ? GwIcons.checkCircle : GwIcons.scan,
                              size: 18, color: on ? gw.green : gw.muted),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  s.location.isNotEmpty ? s.location : 'Unknown location',
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: gw.text,
                                      fontSize: 13.5, fontWeight: FontWeight.w700)),
                                Text('${s.itemCount} items · ${s.hazardCount} hazard',
                                    style: TextStyle(color: gw.muted, fontSize: 11)),
                              ],
                            ),
                          ),
                        ]),
                      );
                    },
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  // ── Assistant ─────────────────────────────────────────────────────────────
  Future<void> _ask() async {
    final scans = _attached;
    if (scans.isEmpty || _sites.isEmpty) return;
    setState(() { _thinking = true; _advice = null; });

    final types = <String, int>{};
    var hazard = 0;
    for (final s in scans) {
      hazard += s.hazardCount;
      for (final i in s.items) {
        final t = i.wasteType.trim();
        if (t.isNotEmpty) types[t] = (types[t] ?? 0) + 1;
      }
    }
    final load = types.entries.map((e) => '${e.value}x ${e.key}').join(', ');
    final list = _sites.take(8)
        .map((s) => '- ${s.name} (${s.distanceLabel})')
        .join('\n');

    final reply = await ClaudeService.chat(
      systemContext:
          'You route waste to disposal sites. Reply in at most 2 short '
          'sentences. Start with the exact site name from the list. Warn '
          'plainly if hazardous items need special handling.',
      messages: [{
        'role': 'user',
        'content': 'Carrying: $load. Hazardous items: $hazard.\n\n'
            'Nearby:\n$list\n\nWhich one?',
      }],
    );

    if (!mounted) return;
    setState(() {
      _thinking = false;
      _advice = reply ?? (ClaudeService.lastError ?? 'Assistant unavailable.');
    });

    // Jump straight to the site it named.
    if (reply != null) {
      for (final s in _sites) {
        if (reply.toLowerCase().contains(s.name.toLowerCase())) {
          await _select(s);
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: gw.bg,
      body: Stack(children: [
        Positioned.fill(child: _mapLayer(gw)),

        // Search + attach, floating over the map
        Positioned(
          top: top + 8, left: 12, right: 12,
          child: Column(children: [
            Row(children: [
              if (widget.showBack) ...[
                GwGlassIcon(icon: GwIcons.chevronLeft, size: 16,
                    onTap: () => Navigator.of(context).pop()),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: GwGlass(
                  radius: 16,
                  blur: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        focusNode: _searchFocus,
                        onChanged: _onQueryChanged,
                        onSubmitted: (_) => _search(),
                        onTap: () => setState(() => _listOpen = _sites.isNotEmpty),
                        style: TextStyle(color: gw.text, fontSize: 13.5),
                        cursorColor: gw.green,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          hintText: 'Search',
                          hintStyle: TextStyle(color: gw.muted, fontSize: 13.5),
                          icon: GwIcon(GwIcons.search, size: 18, color: gw.muted),
                        ),
                      ),
                    ),
                    if (_sites.isNotEmpty)
                      GestureDetector(
                        onTap: () => setState(() => _listOpen = !_listOpen),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: GwIcon(
                            _listOpen ? GwIcons.chevronLeft : GwIcons.chevronRight,
                            size: 16, color: gw.muted),
                        ),
                      ),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              GwGlassIcon(icon: GwIcons.plus, size: 18, onTap: _pickScans),
            ]),

            if (_listOpen) ...[
              const SizedBox(height: 8),
              _dropdown(gw),
            ],
            if (_attached.isNotEmpty && !_listOpen) ...[
              const SizedBox(height: 8),
              _askBar(gw),
            ],
          ]),
        ),

        // Route / selection card
        if (_selected != null)
          Positioned(left: 12, right: 12, bottom: 16, child: _routeCard(gw)),

        if (_loading && _sites.isEmpty)
          Positioned(
            bottom: 24, left: 0, right: 0,
            child: Center(child: GwGlass(
              radius: 99,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(gw.green))),
                const SizedBox(width: 10),
                Text('Finding sites…',
                    style: TextStyle(color: gw.text, fontSize: 12.5)),
              ]),
            )),
          ),

        if (_error != null && _sites.isEmpty)
          Positioned(
            bottom: 24, left: 24, right: 24,
            child: GwGlass(
              radius: 16,
              padding: const EdgeInsets.all(14),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_error!, textAlign: TextAlign.center,
                    style: TextStyle(color: gw.muted, fontSize: 12.5, height: 1.4)),
                const SizedBox(height: 10),
                GwGlass(
                  radius: 10,
                  accent: gw.green,
                  onTap: _locate,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Try again', style: TextStyle(
                    color: gw.green, fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _mapLayer(GwColors gw) {
    if (!_mapSupported) {
      // Desktop has no map plugin, so the list becomes the whole screen.
      return Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 76),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: _sites.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _siteRow(gw, _sites[i], i == 0),
        ),
      );
    }
    if (_pos == null) return ColoredBox(color: gw.bg);

    return GoogleMap(
      mapType: MapType.hybrid,
      initialCameraPosition: CameraPosition(
        target: LatLng(_pos!.latitude, _pos!.longitude), zoom: 13),
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 70,
        bottom: _selected != null ? 150 : 0,
      ),
      onMapCreated: (c) => _map = c,
      onTap: (_) => setState(() => _listOpen = false),
      markers: {
        for (final s in _sites)
          Marker(
            markerId: MarkerId(s.id),
            position: LatLng(s.lat, s.lng),
            onTap: () => _select(s),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              s.id == _selected?.id
                  ? BitmapDescriptor.hueGreen
                  : BitmapDescriptor.hueOrange),
          ),
      },
      polylines: {
        if (_route != null && _route!.points.isNotEmpty)
          Polyline(
            polylineId: const PolylineId('route'),
            width: 5,
            color: gw.green,
            points: [
              for (final p in _route!.points) LatLng(p.lat, p.lng),
            ],
          ),
      },
    );
  }

  Widget _dropdown(GwColors gw) => GwGlass(
        radius: 18,
        blur: 26,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.all(8),
            itemCount: _sites.length,
            separatorBuilder: (_, __) => Divider(
              color: gw.border, height: 12, indent: 8, endIndent: 8),
            itemBuilder: (_, i) {
              final s = _sites[i];
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _select(s),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(children: [
                    GwIcon(GwIcons.pin, size: 16, color: gw.green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: gw.text,
                                  fontSize: 13.5, fontWeight: FontWeight.w700)),
                          Text(s.address, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: gw.muted, fontSize: 11)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(s.distanceLabel, style: TextStyle(color: gw.green,
                        fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ]),
                ),
              );
            },
          ),
        ),
      );

  Widget _askBar(GwColors gw) => GwGlass(
        radius: 14,
        accent: gw.green,
        onTap: _thinking ? null : _ask,
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          GwIcon(GwIcons.sparkle, size: 15, color: gw.green),
          const SizedBox(width: 8),
          Text(
            _thinking
                ? 'Thinking…'
                : 'Where do I take ${_attached.length} scan'
                    '${_attached.length == 1 ? '' : 's'}?',
            style: TextStyle(color: gw.green,
                fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _routeCard(GwColors gw) {
    final s = _selected!;
    return GwGlass(
      radius: 20,
      blur: 30,
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: gw.text,
                    fontSize: 15.5, fontWeight: FontWeight.w800)),
          ),
          GestureDetector(
            onTap: _clearRoute,
            child: GwIcon(GwIcons.close, size: 16, color: gw.muted),
          ),
        ]),
        const SizedBox(height: 3),
        Text(s.address, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: gw.muted, fontSize: 11.5)),
        const SizedBox(height: 12),

        if (_routing)
          Row(children: [
            SizedBox(width: 13, height: 13, child: CircularProgressIndicator(
              strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(gw.green))),
            const SizedBox(width: 9),
            Text('Working out the drive…',
                style: TextStyle(color: gw.muted, fontSize: 12)),
          ])
        else
          Row(children: [
            GwIcon(GwIcons.arrowRight, size: 15, color: gw.green),
            const SizedBox(width: 7),
            Text(
              _route != null
                  ? '${_route!.durationLabel}  ·  ${_route!.distanceLabel}'
                  : '${s.distanceLabel} away (straight line)',
              style: TextStyle(color: gw.text,
                  fontSize: 13.5, fontWeight: FontWeight.w700)),
            if (s.openNow != null) ...[
              const SizedBox(width: 10),
              Text(s.openNow! ? 'Open' : 'Closed', style: TextStyle(
                color: s.openNow! ? gw.green : gw.amber,
                fontSize: 11.5, fontWeight: FontWeight.w600)),
            ],
          ]),

        if (_advice != null) ...[
          const SizedBox(height: 10),
          Text(_advice!, style: TextStyle(
              color: gw.muted, fontSize: 12, height: 1.45)),
        ],

        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: GwGlass(
              radius: 12,
              accent: gw.green,
              onTap: () => _startNavigation(s),
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                GwIcon(GwIcons.arrowUp, size: 15, color: gw.green),
                const SizedBox(width: 8),
                Text('Start', style: TextStyle(color: gw.green,
                    fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _siteRow(GwColors gw, DisposalSite s, bool nearest) => GwGlass(
        radius: 18,
        padding: const EdgeInsets.all(14),
        accent: nearest ? gw.green : null,
        onTap: () => _select(s),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: gw.green.withOpacity(.16),
              borderRadius: BorderRadius.circular(13)),
            child: GwIcon(GwIcons.pin, size: 19, color: gw.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: gw.text,
                        fontSize: 14, fontWeight: FontWeight.w700)),
                Text(s.address, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: gw.muted, fontSize: 11.5)),
              ],
            ),
          ),
          Text(s.distanceLabel, style: TextStyle(color: gw.green,
              fontSize: 11.5, fontWeight: FontWeight.w700)),
        ]),
      );
}
