import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/disposal_registry.dart';
import '../../data/models.dart';
import '../../services/claude_service.dart';
import '../../services/deep_links.dart';
import '../../services/disposal_service.dart';
import '../../theme/gw_theme.dart';
import '../../widgets/gw_desktop_map.dart';
import '../../widgets/gw_glass.dart';
import '../../widgets/gw_icons.dart';
import '../../widgets/gw_responsive.dart';
import '../../widgets/gw_tab_bar.dart';
import '../../widgets/gw_voice_panel.dart';

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

  /// Where the camera is pointing. Updated without setState while the user
  /// drags — repainting every frame of a pan is pure waste — then committed
  /// once on idle.
  LatLng? _camera;

  /// True once the view has drifted far enough from the agent to be worth
  /// offering a way back. Keeps the button out of the way in the default
  /// centred state.
  bool get _offCentre {
    final c = _camera, pos = _pos;
    if (c == null || pos == null) return false;
    return Geolocator.distanceBetween(
            pos.latitude, pos.longitude, c.latitude, c.longitude) >
        150;
  }

  bool _voiceOpen = false;

  /// Set on arrival so the destination pin can be shown differently.
  bool _arrived = false;

  // Turn-by-turn state.
  bool _navigating = false;
  int _step = 0;
  StreamSubscription<Position>? _followSub;

  @override
  void initState() {
    super.initState();
    DisposalRegistry.start(FirebaseAuth.instance.currentUser?.email ?? '');
    DisposalRegistry.revision.addListener(_onRegistryChanged);
    gwPendingHandoff.addListener(_onHandoff);
    _locate();
    // A link that arrived before this screen existed is still waiting.
    if (gwPendingHandoff.value != null) _onHandoff();
  }

  /// Held when a handoff arrives before the first location fix.
  ///
  /// Routing needs an origin, and the link usually lands during startup — so
  /// selecting immediately produced no route at all, and Start fell through to
  /// the Google Maps hand-off instead of navigating in-app.
  DisposalSite? _awaitingFix;

  /// Routes straight to a destination scanned from the desktop QR.
  ///
  /// The link carries only a name and a position, so this builds a site from
  /// those rather than searching — the agent already picked it on the desktop
  /// and a fresh search could rank something else first.
  void _onHandoff() {
    final h = gwPendingHandoff.value;
    if (h == null || !mounted) return;
    gwPendingHandoff.value = null; // consumed

    final site = DisposalSite(
      id: 'handoff:${h.lat},${h.lng}',
      name: h.name,
      address: '',
      lat: h.lat,
      lng: h.lng,
      distanceMeters: _pos == null
          ? 0
          : Geolocator.distanceBetween(
              _pos!.latitude, _pos!.longitude, h.lat, h.lng),
    );

    if (_pos == null) {
      setState(() => _awaitingFix = site);
      return;
    }
    _select(site);
  }

  /// Runs a handoff that was waiting on a location fix.
  void _flushAwaitingFix() {
    final held = _awaitingFix;
    if (held == null || _pos == null) return;
    _awaitingFix = null;
    _select(held);
  }

  void _onRegistryChanged() {
    // Cached results were filtered against the old verdicts.
    DisposalService.onRegistryChanged();
    if (mounted) _search();
  }

  @override
  void dispose() {
    DisposalRegistry.revision.removeListener(_onRegistryChanged);
    gwPendingHandoff.removeListener(_onHandoff);
    _debounce?.cancel();
    _followSub?.cancel();
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
        _flushAwaitingFix();
        await _search();
      }

      final pos = await _bestEffortFix();
      if (!mounted) return;
      if (pos == null) {
        setState(() {
          _loading = false;
          if (_pos == null) {
            // Say what still works. A device with no GPS is not a dead end —
            // searching by name returns results, just not nearest-first.
            _error = 'No location yet. Search by name to find a site.';
          }
        });
        return;
      }
      final moved = _pos == null ||
          Geolocator.distanceBetween(
              _pos!.latitude, _pos!.longitude, pos.latitude, pos.longitude) > 500;
      setState(() => _pos = pos);
      _flushAwaitingFix();
      if (moved) await _search();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_pos == null) _error = 'Could not get your location.';
      });
    }
  }


  /// Tries progressively coarser fixes.
  ///
  /// A phone gets a GPS fix at medium accuracy quickly. A Wi-Fi-only tablet
  /// has no GPS radio at all, so that request simply never resolves — it has
  /// to fall back to network positioning, which is far less precise but is
  /// plenty for finding a recycling centre a few km away.
  Future<Position?> _bestEffortFix() async {
    const attempts = [
      (LocationAccuracy.medium, 8),
      (LocationAccuracy.low, 8),
      (LocationAccuracy.lowest, 10),
    ];
    for (final (accuracy, seconds) in attempts) {
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: accuracy,
            timeLimit: Duration(seconds: seconds),
          ),
        );
      } on TimeoutException {
        continue; // coarser next
      } catch (_) {
        continue;
      }
    }
    // Last resort: whatever the platform already had cached.
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  Future<void> _search() async {
    final pos = _pos;
    // A typed query works without a fix — it just comes back unbiased. Only a
    // blank search truly needs to know where the agent is.
    if (pos == null && _searchCtrl.text.trim().isEmpty) return;
    setState(() { _loading = true; _error = null; });

    final sites = await DisposalService.nearby(
      route: WasteRoute.recyclable,
      lat: pos?.latitude,
      lng: pos?.longitude,
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

  /// Shows a QR that opens this destination in the phone app.
  ///
  /// The code points at an https link rather than the gwcorp:// scheme
  /// directly — phone cameras open custom schemes inconsistently, and the web
  /// page can also offer the download if the app isn't installed.
  Future<void> _showHandoff(DisposalSite s) async {
    final gw = GwTheme.of(context);
    // .html is explicit: Hosting only strips the extension with cleanUrls on,
    // and turning that on would 301 every existing link on the site.
    final link = Uri.https('ihs-gwcorp.web.app', '/go.html', {
      'lat': s.lat.toStringAsFixed(6),
      'lng': s.lng.toStringAsFixed(6),
      'n': s.name,
    }).toString();

    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: gw.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 24, 26, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Continue on your phone',
                style: TextStyle(
                  color: gw.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Scan to open ${s.name} in the GWCORP app.',
                textAlign: TextAlign.center,
                style: TextStyle(color: gw.muted, fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 18),
              // White quiet zone: scanners need the contrast, and a dark QR on
              // a dark panel reads badly on most phone cameras.
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: QrImageView(
                  data: link,
                  size: 190,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF06210F),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF06210F),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Done',
                  style: TextStyle(color: gw.green, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Draws the route and frames both ends on the map.
  Future<void> _select(DisposalSite s) async {
    DisposalRegistry.loadMyVote(s.id);
    final pos = _pos;
    _searchFocus.unfocus();
    setState(() {
      _selected = s;
      _route = null;
      _listOpen = false;
      _routing = true;
      _arrived = false;
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



  /// Opens the photo strip full screen, starting on the one tapped.
  void _openPhotos(DisposalSite s, int initial) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, anim, __) => FadeTransition(
        opacity: anim,
        child: _PhotoViewer(
          photoNames: s.photoNames,
          initialIndex: initial,
          title: s.name,
        ),
      ),
    ));
  }





  /// Whatever owns the bottom slot right now. Keyed so AnimatedSwitcher can
  /// tell one panel from another and animate the handover.
  Widget _footerSlot(GwColors gw) {
    if (_voiceOpen) {
      return GwVoicePanel(
        key: const ValueKey('voice'),
        context: _voiceContext(),
        onClose: () => setState(() => _voiceOpen = false),
        dark: _navigating,
      );
    }
    if (_selected != null && !_navigating) {
      return KeyedSubtree(key: ValueKey('card:' + _selected!.id), child: _routeCard(gw));
    }
    if (_navigating) {
      return KeyedSubtree(key: const ValueKey('nav'), child: _guidanceFooter(gw));
    }
    return const SizedBox(key: ValueKey('none'), width: double.infinity);
  }

  /// Everything the assistant should know before answering.
  String _voiceContext() {
    final s = _selected;
    final parts = <String>[];
    if (s != null) {
      parts.add('The agent is heading to ${s.name}, ${s.address}.');
      if (_route != null) {
        parts.add('It is ${_route!.durationLabel} away (${_route!.distanceLabel}).');
      }
      if (s.openNow != null) {
        parts.add(s.openNow! ? 'It is open now.' : 'It is closed right now.');
      }
      if (s.rating != null) {
        parts.add('Rated ${s.rating!.toStringAsFixed(1)} on Google.');
      }
      final rec = s.record;
      if (rec != null) parts.add(rec.summary + '.');
    }
    final scans = _attached;
    if (scans.isNotEmpty) {
      final types = <String, int>{};
      for (final sc in scans) {
        for (final i in sc.items) {
          final t = i.wasteType.trim();
          if (t.isNotEmpty) types[t] = (types[t] ?? 0) + 1;
        }
      }
      parts.add('They are carrying: ' +
          types.entries.map((e) => '${e.value}x ${e.key}').join(', ') + '.');
    }
    return parts.isEmpty ? 'No site selected yet.' : parts.join(' ');
  }


  SiteVote? _myVote(DisposalSite s) => DisposalRegistry.myVote(s.id);

  Future<void> _record(DisposalSite s, SiteVote vote) async {
    await DisposalRegistry.vote(
      placeId: s.id,
      name: s.name,
      address: s.address,
      lat: s.lat,
      lng: s.lng,
      vote: vote,
    );
    if (!mounted) return;
    // A single "no" no longer removes a site outright — it counts against
    // it, and the card stays so the running tally is visible.
    setState(() {});
  }

  /// Snaps the camera back to the agent. During guidance it also re-locks
  /// the follow view, which is the usual reason you reach for it after
  /// panning away to look ahead.
  Future<void> _recenter() async {
    final pos = _pos;
    if (pos == null) return;
    setState(() => _camera = LatLng(pos.latitude, pos.longitude));
    await _map?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
      target: LatLng(pos.latitude, pos.longitude),
      zoom: _navigating ? 17 : 15,
      tilt: _navigating ? 45 : 0,
      bearing: _navigating ? pos.heading : 0,
    )));
  }

  void _clearRoute() => setState(() {
        _selected = null;
        _route = null;
        _advice = null;
      });

  /// Enters guidance: camera follows the agent and the current manoeuvre is
  /// shown. Deliberately not full navigation — no voice, and rerouting only
  /// happens if you stray far enough to be clearly off the line.
  Future<void> _startNavigation(DisposalSite s) async {
    // Nobody drives looking at a desktop. Hand the destination to the phone
    // instead of pretending to navigate from a monitor.
    if (!_mapSupported) {
      await _showHandoff(s);
      return;
    }

    if (_route == null || _route!.steps.isEmpty) {
      // No steps to follow, so the Maps app is genuinely the better answer.
      await launchUrl(s.directionsUri, mode: LaunchMode.externalApplication);
      return;
    }

    setState(() { _navigating = true; _step = 0; _listOpen = false; });

    _followSub?.cancel();
    _followSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(_onMove);

    await _map?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
      target: LatLng(_pos!.latitude, _pos!.longitude),
      zoom: 17,
      tilt: 45,
    )));
  }

  void _onMove(Position pos) {
    if (!mounted || !_navigating) return;
    setState(() => _pos = pos);

    final steps = _route?.steps ?? const <RouteStep>[];
    if (_step < steps.length) {
      final target = steps[_step];
      final left = Geolocator.distanceBetween(
          pos.latitude, pos.longitude, target.endLat, target.endLng);
      // Within 30m of the manoeuvre point counts as having taken it.
      if (left < 30 && _step < steps.length - 1) {
        setState(() => _step++);
      }
    }

    final dest = _selected;
    if (dest != null) {
      final toGo = Geolocator.distanceBetween(
          pos.latitude, pos.longitude, dest.lat, dest.lng);
      if (toGo < 50) { _stopNavigation(arrived: true); return; }
    }

    _map?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
      target: LatLng(pos.latitude, pos.longitude),
      zoom: 17,
      tilt: 45,
      bearing: pos.heading,
    )));
  }

  void _stopNavigation({bool arrived = false}) {
    _followSub?.cancel();
    _followSub = null;
    if (!mounted) return;
    setState(() {
      _navigating = false;
      _step = 0;
      if (arrived) { _advice = 'You have arrived.'; _arrived = true; }
    });
    _map?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
      target: LatLng(_pos!.latitude, _pos!.longitude), zoom: 14)));
  }

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
    // On a tablet the controls collect into a column down the left rather
    // than stretching edge to edge — a search bar a metre wide is no easier
    // to use, and it buries the map.
    final wide = gwIsWide(context);
    const panelW = 440.0;
    // Inside the phone shell the floating tab bar overlaps the bottom of the
    // screen, so the map has to stop above it rather than run underneath.
    final barGap = (!widget.showBack && _mapSupported)
        ? GwTabBar.totalHeight(context)
        : 0.0;

    return Scaffold(
      backgroundColor: gw.bg,
      body: Stack(children: [
        Positioned.fill(child: _mapLayer(gw, barGap)),

        // Search + attach, floating over the map
        if (!_navigating) Positioned(
          top: top + 8,
          left: 12,
          right: wide ? null : 12,
          width: wide ? panelW : null,
          child: _SlideFadeIn(
            from: const Offset(0, -0.3),
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

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SizeTransition(
                  sizeFactor: anim, axisAlignment: -1, child: child),
              ),
              child: _listOpen
                  ? Padding(
                      key: const ValueKey('open'),
                      padding: const EdgeInsets.only(top: 8),
                      child: _dropdown(gw),
                    )
                  : const SizedBox(width: double.infinity, key: ValueKey('shut')),
            ),
            if (_attached.isNotEmpty && !_listOpen) ...[
              const SizedBox(height: 8),
              _askBar(gw),
            ],
          ]),
          ),
        ),

        // Route / selection card

        // The turn instruction stays up while the assistant is open — asking a
        // question should never cost you the next manoeuvre.
        if (_navigating)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: wide ? null : 12,
            width: wide ? panelW : null,
            child: _SlideFadeIn(from: const Offset(0, -0.35), child: _guidanceBanner(gw)),
          ),

        // Recenter, route card and guidance footer share one column, so the
        // button always sits clear of whatever card is showing instead of
        // being positioned against a guessed height.
        Positioned(
          left: 12,
          right: wide ? null : 12,
          width: wide ? panelW : null,
          bottom: barGap + 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Recenter lives on the right edge when there is room; on a
              // phone the card already spans the width, so it stacks above.
              if (!wide && _mapSupported && _pos != null && _offCentre && !_voiceOpen) ...[
                _SlideFadeIn(
                  from: const Offset(0.4, 0),
                  child: _RecenterButton(onTap: _recenter),
                ),
                const SizedBox(height: 12),
              ],
              // Voice takes the footer slot outright — two stacked panels
              // would leave nothing but map. AnimatedSwitcher rather than a
              // plain if/else so the outgoing panel drops away instead of
              // vanishing the instant the next one starts arriving.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.35),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                // Anchored to the bottom so panels of different heights slide
                // past each other instead of jumping as the box resizes.
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    ...previous,
                    if (current != null) current,
                  ],
                ),
                child: _footerSlot(gw),
              ),
            ],
          ),
        ),

        if (wide && _mapSupported && _pos != null && _offCentre && !_voiceOpen)
          Positioned(
            right: 16,
            bottom: barGap + 16,
            child: _SlideFadeIn(
              from: const Offset(0.4, 0),
              child: _RecenterButton(onTap: _recenter),
            ),
          ),

        if (_loading && _sites.isEmpty)
          Positioned(
            bottom: barGap + 24, left: 0, right: 0,
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
            bottom: barGap + 24, left: 24, right: 24,
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

  Widget _mapLayer(GwColors gw, double barGap) {
    if (!_mapSupported) {
      // Windows has no map plugin either, but it can render the hosted map
      // page in a WebView — so it gets a real map rather than a bare list.
      if (Platform.isWindows) {
        return GwDesktopMap(
          sites: _sites,
          center: _pos == null
              ? null
              : (lat: _pos!.latitude, lng: _pos!.longitude),
          polyline: _route?.encoded,
          selectedId: _selected?.id,
          onSelect: (id) {
            for (final s in _sites) {
              if (s.id == id) {
                _select(s);
                break;
              }
            }
          },
        );
      }
      // Anything else desktop-ish falls back to the list.
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
      // Live congestion, but only once a route is on screen — it clutters the
      // map while you are still browsing and is the whole point once you are
      // deciding whether to set off.
      trafficEnabled: _selected != null || _navigating,
      // Moves Google's logo and controls above the tab bar and route card
      // without shrinking the map itself, so tiles still run edge to edge.
      padding: EdgeInsets.only(
        left: gwIsWide(context) ? 464 : 0,
        top: gwIsWide(context)
            ? MediaQuery.of(context).padding.top + 8
            : MediaQuery.of(context).padding.top + 70,
        bottom: barGap + (_selected != null && !gwIsWide(context) ? 150 : 8),
      ),
      onMapCreated: (c) => _map = c,
      onTap: (_) => setState(() => _listOpen = false),
      onCameraMove: (p) => _camera = p.target,
      onCameraIdle: () { if (mounted) setState(() {}); },
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
            // Arriving raises the destination pin off the map and gives it
            // a shadow, so it reads as standing up rather than lying flat.
            flat: false,
            zIndex: s.id == _selected?.id ? 2.0 : 1.0,
            anchor: s.id == _selected?.id && _arrived
                ? const Offset(0.5, 1.4)
                : const Offset(0.5, 1.0),
          ),
      },
      polylines: {
        if (_route != null && _route!.points.isNotEmpty) ...[
          // Blue, not brand green: every button, pin and label on this screen is
          // green, so a green route blends into its own UI. Drawn twice — a dark
          // casing under a bright core — because a flat line disappears against
          // satellite imagery wherever it crosses water or shadow.
          Polyline(
            polylineId: const PolylineId('route-casing'),
            width: 10,
            color: const Color(0xFF10357A),
            zIndex: 1,
            points: [
              for (final p in _route!.points) LatLng(p.lat, p.lng),
            ],
          ),
          Polyline(
            polylineId: const PolylineId('route'),
            width: 5,
            color: const Color(0xFF4C9AFF),
            zIndex: 2,
            points: [
              for (final p in _route!.points) LatLng(p.lat, p.lng),
            ],
          ),
        ],
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
                          if (s.isVerified || s.isReported)
                            Row(children: [
                              GwIcon(GwIcons.checkCircle, size: 11,
                                  color: s.isVerified ? gw.green : gw.amber),
                              const SizedBox(width: 4),
                              Text(s.record?.summary ?? '',
                                  style: TextStyle(
                                      color: s.isVerified ? gw.green : gw.amber,
                                      fontSize: 10.5, fontWeight: FontWeight.w700)),
                            ])
                          else if (!s.acceptsWaste)
                            Text('Not a disposal site',
                                style: TextStyle(color: gw.amber,
                                    fontSize: 10.5, fontWeight: FontWeight.w700))
                          else
                            Text(s.address, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: gw.muted, fontSize: 11)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(s.distanceLabel, style: TextStyle(color: gw.green,
                            fontSize: 11.5, fontWeight: FontWeight.w700)),
                        if (s.rating != null)
                          Text('★ ' + s.rating!.toStringAsFixed(1),
                              style: TextStyle(color: gw.muted, fontSize: 10)),
                      ],
                    ),
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

        if (s.photoNames.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: s.photoNames.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _SitePhoto(
                photoName: s.photoNames[i],
                onTap: () => _openPhotos(s, i),
                // Keyed so switching site swaps the images instead of the
                // previous ones lingering while the new bytes load.
                key: ValueKey(s.photoNames[i]),
              ),
            ),
          ),
        ],


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
            if (s.rating != null) ...[
              const SizedBox(width: 10),
              Text('★', style: TextStyle(color: gw.amber, fontSize: 12)),
              const SizedBox(width: 3),
              Text(s.rating!.toStringAsFixed(1), style: TextStyle(
                  color: gw.text, fontSize: 11.5, fontWeight: FontWeight.w700)),
            ],
          ]),

        if (_advice != null) ...[
          const SizedBox(height: 10),
          Text(_advice!, style: TextStyle(
              color: gw.muted, fontSize: 12, height: 1.45)),
        ],

        if (!s.acceptsWaste && !s.isVerified) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: gw.amber.withOpacity(.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: gw.amber.withOpacity(.4)),
            ),
            child: Row(children: [
              GwHazardIcon(size: 15, color: gw.amber),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'This does not look like a waste facility. Check it accepts '
                  'your load before travelling.',
                  style: TextStyle(color: gw.amber, fontSize: 11, height: 1.35)),
              ),
            ]),
          ),
        ],

        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _startNavigation(s),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    // Amber when nothing suggests the place takes waste, so the
                    // warning above is not contradicted by a confident button.
                    colors: (s.acceptsWaste || s.isVerified)
                        ? [const Color(0xFF4ADE80), gw.green, gw.greenDim]
                        : [gw.amber, const Color(0xFFB45309)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ((s.acceptsWaste || s.isVerified) ? gw.green : gw.amber)
                          .withOpacity(.45),
                      blurRadius: 16, offset: const Offset(0, 5)),
                  ],
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                  GwIcon(GwIcons.arrowUp, size: 15, color: Colors.white, strokeWidth: 2.2),
                  SizedBox(width: 8),
                  Text('Start', style: TextStyle(
                      color: Colors.white, fontSize: 13.5,
                      fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          ),
        ]),

        const SizedBox(height: 12),
        // What the team knows, recorded after actually going. This is what
        // replaces guessing from names and place types over time.
        // The team's running tally. One agent's opinion is a data point, not a
        // verdict — confidence only builds as more of them agree.
        if (s.record != null) ...[
          Text(s.record!.summary, style: TextStyle(
              color: s.isVerified
                  ? gw.green
                  : s.isRejected
                      ? gw.red
                      : gw.amber,
              fontSize: 11.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
        ],
        Row(children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _record(s, SiteVote.takesWaste),
              child: Row(children: [
                GwIcon(GwIcons.checkCircle, size: 14,
                    color: _myVote(s) == SiteVote.takesWaste ? gw.green : gw.muted),
                const SizedBox(width: 7),
                Text('Takes waste', style: TextStyle(
                    color: _myVote(s) == SiteVote.takesWaste ? gw.green : gw.muted,
                    fontSize: 11.5,
                    fontWeight: _myVote(s) == SiteVote.takesWaste
                        ? FontWeight.w700 : FontWeight.w600)),
              ]),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _record(s, SiteVote.notASite),
            child: Row(children: [
              GwIcon(GwIcons.close, size: 13,
                  color: _myVote(s) == SiteVote.notASite ? gw.red : gw.muted),
              const SizedBox(width: 6),
              Text('Not a site', style: TextStyle(
                  color: _myVote(s) == SiteVote.notASite ? gw.red : gw.muted,
                  fontSize: 11.5,
                  fontWeight: _myVote(s) == SiteVote.notASite
                      ? FontWeight.w700 : FontWeight.w600)),
            ]),
          ),
        ]),
      ]),
    );
  }


  Widget _guidanceBanner(GwColors gw) {
    final steps = _route?.steps ?? const <RouteStep>[];
    final now = _step < steps.length ? steps[_step] : null;
    // Solid green rather than tinted glass: this has to stay readable at a
    // glance while driving, so the contrast cannot depend on what the map
    // happens to be showing underneath. White throughout, both themes.
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [gw.green, gw.greenDim],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.18, 0), end: Offset.zero).animate(anim),
            child: child,
          ),
        ),
        // Re-keying on the step index is what makes each new manoeuvre
        // animate in rather than silently swapping text.
        child: Row(key: ValueKey(_step), children: [
          GwIcon(_maneuverIcon(now?.maneuver ?? ''),
              size: 26, color: Colors.white, strokeWidth: 2.4),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (now != null)
                Text(now.distanceLabel, style: const TextStyle(
                    color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.w800)),
              Text(
                now?.instruction.isNotEmpty == true
                    ? now!.instruction
                    : 'Continue to ${_selected?.name ?? "destination"}',
                style: const TextStyle(color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.w700, height: 1.3)),
            ],
          ),
        ),
        ]),
      ),
    );
  }

  Widget _guidanceFooter(GwColors gw) {
    // No "then next turn" line here — the banner at the top already carries
    // the instruction, and repeating it just crowds the ETA.
    return GwGlass(
      radius: 18,
      blur: 30,
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Expanded(
          child: Text(
            _route != null
                ? '${_route!.durationLabel}  ·  ${_route!.distanceLabel}'
                : 'On the way',
            style: TextStyle(color: gw.text, fontSize: 15,
                fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        // Ask GWC — sits left of End so the destructive action stays
        // furthest from the thumb.
        GestureDetector(
          onTap: () => setState(() => _voiceOpen = true),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [const Color(0xFF4ADE80), gw.green, gw.greenDim],
              ),
              boxShadow: [
                BoxShadow(color: gw.green.withOpacity(.45),
                    blurRadius: 14, offset: const Offset(0, 4)),
              ],
            ),
            child: const GwIcon(GwIcons.sparkle, size: 16, color: Colors.white),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _stopNavigation,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [gw.red, const Color(0xFFB91C1C)],
              ),
              boxShadow: [
                BoxShadow(
                  color: gw.red.withOpacity(.45),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Text('End', style: TextStyle(
                color: Colors.white, fontSize: 13,
                fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }

  /// Routes API manoeuvre enum -> the closest glyph we have.
  String _maneuverIcon(String m) {
    final v = m.toUpperCase();
    if (v.contains('LEFT')) return GwIcons.chevronLeft;
    if (v.contains('RIGHT')) return GwIcons.chevronRight;
    if (v.contains('DESTINATION')) return GwIcons.pin;
    return GwIcons.arrowUp;
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

/// Plays once when the widget mounts. Guidance panels appear and disappear
/// as navigation starts and stops, so mounting is the natural trigger.
class _SlideFadeIn extends StatefulWidget {
  final Widget child;
  final Offset from;
  const _SlideFadeIn({required this.child, required this.from});

  @override
  State<_SlideFadeIn> createState() => _SlideFadeInState();
}

class _SlideFadeInState extends State<_SlideFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(begin: widget.from, end: Offset.zero)
            .animate(curve),
        child: widget.child,
      ),
    );
  }
}

/// Glass circle that returns the camera to the agent.
class _RecenterButton extends StatefulWidget {
  final VoidCallback onTap;
  const _RecenterButton({required this.onTap});

  @override
  State<_RecenterButton> createState() => _RecenterButtonState();
}

class _RecenterButtonState extends State<_RecenterButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [const Color(0xFF4ADE80), gw.green, gw.greenDim],
            ),
            boxShadow: [
              BoxShadow(color: gw.green.withOpacity(.45),
                  blurRadius: 16, offset: const Offset(0, 5)),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: const [
            GwIcon(GwIcons.pin, size: 16, color: Colors.white, strokeWidth: 2.2),
            SizedBox(width: 8),
            Text('Recenter', style: TextStyle(
                color: Colors.white, fontSize: 13,
                fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }
}

/// One Places photo.
///
/// Bytes are fetched through DisposalService so the request carries the app
/// identity headers the restricted key requires — Image.network cannot, and
/// would come back 403.
class _SitePhoto extends StatefulWidget {
  final String photoName;
  final VoidCallback? onTap;
  const _SitePhoto({super.key, required this.photoName, this.onTap});

  @override
  State<_SitePhoto> createState() => _SitePhotoState();
}

class _SitePhotoState extends State<_SitePhoto> {
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = await DisposalService.photoBytes(widget.photoName, maxWidthPx: 300);
    if (!mounted) return;
    setState(() {
      _bytes = b;
      _failed = b == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    return GestureDetector(
      onTap: _bytes == null ? null : widget.onTap,
      child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 104,
        height: 76,
        child: _bytes != null
            ? Image.memory(_bytes!, fit: BoxFit.cover, gaplessPlayback: true)
            : ColoredBox(
                color: gw.bg3,
                child: Center(
                  child: _failed
                      ? GwIcon(GwIcons.image, size: 18, color: gw.muted)
                      : SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(gw.muted),
                          ),
                        ),
                ),
              ),
      ),
    ),
    );
  }
}

/// Full-screen, swipeable view of a site's photos.
class _PhotoViewer extends StatefulWidget {
  final List<String> photoNames;
  final int initialIndex;
  final String title;

  const _PhotoViewer({
    required this.photoNames,
    required this.initialIndex,
    required this.title,
  });

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _pages =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        // Tapping the backdrop closes, the same as swiping down would.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        PageView.builder(
          controller: _pages,
          itemCount: widget.photoNames.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => Center(
            // Full width at a larger size than the thumbnail strip asks for.
            child: _FullPhoto(photoName: widget.photoNames[i]),
          ),
        ),
        Positioned(
          top: top + 10,
          left: 12,
          right: 12,
          child: Row(children: [
            Expanded(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none),
              ),
            ),
            if (widget.photoNames.length > 1)
              Text('${_index + 1} / ${widget.photoNames.length}',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                      decoration: TextDecoration.none)),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(.16),
                ),
                child: const GwIcon(GwIcons.close, size: 16, color: Colors.white),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// A single full-size photo, fetched with the app identity headers.
class _FullPhoto extends StatefulWidget {
  final String photoName;
  const _FullPhoto({required this.photoName});

  @override
  State<_FullPhoto> createState() => _FullPhotoState();
}

class _FullPhotoState extends State<_FullPhoto> {
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = await DisposalService.photoBytes(widget.photoName, maxWidthPx: 1200);
    if (!mounted) return;
    setState(() {
      _bytes = b;
      _failed = b == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes != null) {
      // Pinch to zoom, drag to pan.
      return InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        child: Image.memory(_bytes!, fit: BoxFit.contain),
      );
    }
    if (_failed) {
      return const GwIcon(GwIcons.image, size: 34, color: Colors.white54);
    }
    return const SizedBox(
      width: 26,
      height: 26,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
      ),
    );
  }
}
