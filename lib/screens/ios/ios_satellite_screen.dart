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
import '../../widgets/gw_responsive.dart';

/// Search for a disposal site, attach the scans you are carrying, and let the
/// assistant say which one to drive to.
///
/// google_maps_flutter has no Windows/Linux implementation, so desktop gets
/// everything except the map. The Places lookup is plain HTTP and works
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
  Timer? _debounce;

  Position? _pos;
  List<DisposalSite> _sites = [];
  final Set<String> _picked = {}; // session ids attached as context
  bool _loading = true;
  String? _error;

  String? _advice;
  DisposalSite? _advisedSite;
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
    _map?.dispose();
    super.dispose();
  }

  List<ScanSession> get _attached =>
      widget.sessions.where((s) => _picked.contains(s.id)).toList();

  Future<void> _locate() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() { _loading = false; _error = 'Turn on location services to find nearby sites.'; });
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        setState(() { _loading = false; _error = 'Location permission is needed to find the nearest site.'; });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (!mounted) return;
      setState(() => _pos = pos);
      await _search();
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Could not get your location.'; });
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
      _error = sites.isEmpty
          ? (DisposalService.lastError ?? 'Nothing found nearby. Try another search.')
          : null;
    });
  }

  void _onQueryChanged(String _) {
    // One Places call per pause, not per keystroke — it is a billed SKU.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _search);
  }

  Future<void> _navigate(DisposalSite s) =>
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
                  borderRadius: BorderRadius.circular(99),
                ),
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
                  constraints: const BoxConstraints(maxHeight: 320),
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
                          setState(() { _advice = null; _advisedSite = null; });
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

  // ── Ask the assistant ─────────────────────────────────────────────────────
  Future<void> _ask() async {
    final scans = _attached;
    if (scans.isEmpty || _sites.isEmpty) return;
    setState(() { _thinking = true; _advice = null; _advisedSite = null; });

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
    final list = _sites
        .take(8)
        .map((s) => '- ${s.name} (${s.distanceLabel}) — ${s.address}')
        .join('\n');

    final reply = await ClaudeService.chat(
      systemContext:
          'You route waste to disposal sites. Reply in at most 3 short '
          'sentences. Start with the exact site name from the list, then say '
          'why it suits this load. Warn plainly if hazardous items need '
          'special handling or if no listed site looks appropriate.',
      messages: [
        {
          'role': 'user',
          'content': 'I am carrying: $load. Hazardous items: $hazard.\n\n'
              'Nearby sites:\n$list\n\nWhich should I take this to?',
        }
      ],
    );

    if (!mounted) return;
    setState(() {
      _thinking = false;
      _advice = reply ?? (ClaudeService.lastError ?? 'The assistant is unavailable.');
      // Link the answer back to a real site so the button can navigate.
      if (reply != null) {
        for (final s in _sites) {
          if (reply.toLowerCase().contains(s.name.toLowerCase())) {
            _advisedSite = s;
            break;
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    final g  = gwGutter(context);
    final attached = _attached;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: EdgeInsets.fromLTRB(widget.showBack ? 8 : g, 4, g, 0),
            child: Row(children: [
              if (widget.showBack) ...[
                GwGlassIcon(icon: GwIcons.chevronLeft, size: 16,
                    onTap: () => Navigator.of(context).pop()),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text('Disposal', style: TextStyle(
                  color: gw.text, fontSize: gwTitleSize(context),
                  fontWeight: FontWeight.w800, letterSpacing: -0.8)),
              ),
              GwGlassIcon(icon: GwIcons.pin, size: 17, onTap: _locate),
            ]),
          ),
          const SizedBox(height: 12),

          // Search + attach
          Padding(
            padding: EdgeInsets.symmetric(horizontal: g),
            child: Row(children: [
              Expanded(
                child: GwGlass(
                  radius: 16,
                  blur: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onQueryChanged,
                    onSubmitted: (_) => _search(),
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
              ),
              const SizedBox(width: 10),
              GwGlassIcon(icon: GwIcons.plus, size: 18, onTap: _pickScans),
            ]),
          ),

          // Attached scans
          if (attached.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 30,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: g),
                itemCount: attached.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final s = attached[i];
                  return Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: gw.green.withOpacity(.16),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: gw.green.withOpacity(.4)),
                    ),
                    child: Text(
                      '${s.location.isNotEmpty ? s.location : 'Scan'} · ${s.itemCount}',
                      style: TextStyle(color: gw.green,
                          fontSize: 11.5, fontWeight: FontWeight.w700)),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: g),
              child: SizedBox(
                width: double.infinity,
                child: GwGlass(
                  radius: 14,
                  accent: gw.green,
                  onTap: _thinking ? null : _ask,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    GwIcon(GwIcons.sparkle, size: 16, color: gw.green),
                    const SizedBox(width: 8),
                    Text(_thinking ? 'Thinking…' : 'Where do I take this?',
                        style: TextStyle(color: gw.green,
                            fontSize: 13.5, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          ],

          // Advice
          if (_advice != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: g),
              child: GwGlass(
                radius: 18,
                accent: gw.green,
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    GwIcon(GwIcons.sparkle, size: 15, color: gw.green),
                    const SizedBox(width: 7),
                    Text('Recommendation', style: TextStyle(color: gw.green,
                        fontSize: 11.5, fontWeight: FontWeight.w800,
                        letterSpacing: .4)),
                  ]),
                  const SizedBox(height: 8),
                  Text(_advice!, style: TextStyle(
                      color: gw.text, fontSize: 13, height: 1.5)),
                  if (_advisedSite != null) ...[
                    const SizedBox(height: 12),
                    GwGlass(
                      radius: 12,
                      onTap: () => _navigate(_advisedSite!),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        GwIcon(GwIcons.arrowRight, size: 15, color: gw.green),
                        const SizedBox(width: 8),
                        Text('Directions to ${_advisedSite!.name}',
                            style: TextStyle(color: gw.green,
                                fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ],
                ]),
              ),
            ),
          ],

          const SizedBox(height: 12),

          if (_mapSupported && _pos != null) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: g),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: 170,
                  child: GoogleMap(
                    mapType: MapType.hybrid,
                    initialCameraPosition: CameraPosition(
                      target: LatLng(_pos!.latitude, _pos!.longitude), zoom: 12),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    onMapCreated: (c) => _map = c,
                    markers: {
                      for (final s in _sites)
                        Marker(
                          markerId: MarkerId(s.id),
                          position: LatLng(s.lat, s.lng),
                          infoWindow: InfoWindow(
                            title: s.name,
                            snippet: s.distanceLabel,
                            onTap: () => _navigate(s),
                          ),
                        ),
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          Expanded(child: _results(gw, g)),
        ]),
      ),
    );
  }

  Widget _results(GwColors gw, double g) {
    if (_loading) {
      return Center(child: SizedBox(
        width: 22, height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(gw.green)),
      ));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: g + 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            GwIcon(GwIcons.pin, size: 32, color: gw.muted),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center,
                style: TextStyle(color: gw.muted, fontSize: 13, height: 1.45)),
            const SizedBox(height: 14),
            GwGlass(
              radius: 12,
              accent: gw.green,
              onTap: _locate,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Text('Try again', style: TextStyle(
                color: gw.green, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(g, 0, g, gwPageBottom(context)),
      itemCount: _sites.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _row(gw, _sites[i], i == 0),
    );
  }

  Widget _row(GwColors gw, DisposalSite s, bool nearest) {
    return GwGlass(
      radius: 18,
      padding: const EdgeInsets.all(14),
      accent: nearest ? gw.green : null,
      onTap: () => _navigate(s),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: gw.green.withOpacity(.16),
            borderRadius: BorderRadius.circular(13),
          ),
          child: GwIcon(GwIcons.pin, size: 20, color: gw.green),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: gw.text,
                      fontSize: 14.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(s.address, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: gw.muted, fontSize: 11.5)),
              const SizedBox(height: 5),
              Row(children: [
                Text(s.distanceLabel, style: TextStyle(color: gw.green,
                    fontSize: 11.5, fontWeight: FontWeight.w700)),
                if (s.openNow != null) ...[
                  const SizedBox(width: 8),
                  Text(s.openNow! ? 'Open now' : 'Closed', style: TextStyle(
                    color: s.openNow! ? gw.green : gw.amber,
                    fontSize: 11, fontWeight: FontWeight.w600)),
                ],
                if (s.rating != null) ...[
                  const SizedBox(width: 8),
                  Text('★ ${s.rating!.toStringAsFixed(1)}',
                      style: TextStyle(color: gw.muted, fontSize: 11)),
                ],
              ]),
            ],
          ),
        ),
        GwIcon(GwIcons.arrowRight, size: 17, color: gw.muted),
      ]),
    );
  }
}
