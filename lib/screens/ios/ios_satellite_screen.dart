import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/disposal_service.dart';
import '../../theme/gw_theme.dart';
import '../../widgets/gw_glass.dart';
import '../../widgets/gw_icons.dart';
import '../../widgets/gw_responsive.dart';

/// Finds the nearest place to take waste, routed by what the waste actually is.
///
/// google_maps_flutter has no Windows/Linux implementation, so desktop gets the
/// ranked list without the map. The Places lookup is plain HTTP and works
/// everywhere.
class IosSatelliteScreen extends StatefulWidget {
  final bool showBack;
  const IosSatelliteScreen({super.key, this.showBack = true});

  @override
  State<IosSatelliteScreen> createState() => _IosSatelliteScreenState();
}

class _IosSatelliteScreenState extends State<IosSatelliteScreen> {
  static bool get _mapSupported => Platform.isAndroid || Platform.isIOS;

  WasteRoute _route = WasteRoute.recyclable;
  Position? _pos;
  List<DisposalSite> _sites = [];
  bool _loading = true;
  String? _error;
  GoogleMapController? _map;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() { _loading = true; _error = null; });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() { _loading = false; _error = 'Turn on location services to find nearby sites.'; });
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() { _loading = false; _error = 'Location permission is needed to find the nearest site.'; });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (!mounted) return;
      setState(() => _pos = pos);
      await _search();
    } catch (e) {
      if (mounted) {
        setState(() { _loading = false; _error = 'Could not get your location.'; });
      }
    }
  }

  Future<void> _search() async {
    final pos = _pos;
    if (pos == null) return;
    setState(() { _loading = true; _error = null; });

    final sites = await DisposalService.nearby(
      route: _route,
      lat: pos.latitude,
      lng: pos.longitude,
    );
    if (!mounted) return;
    setState(() {
      _sites = sites;
      _loading = false;
      _error = sites.isEmpty ? (DisposalService.lastError ?? 'No sites found nearby.') : null;
    });
  }

  void _pickRoute(WasteRoute r) {
    if (r == _route) return;
    setState(() => _route = r);
    _search();
  }

  Future<void> _navigate(DisposalSite s) async {
    // Hand off to the Maps app rather than paying for the Routes API.
    await launchUrl(s.directionsUri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    final g  = gwGutter(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: EdgeInsets.fromLTRB(widget.showBack ? 8 : g, 4, g, 0),
            child: Row(children: [
              if (widget.showBack) ...[
                GwGlassIcon(
                  icon: GwIcons.chevronLeft,
                  size: 16,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Disposal', style: TextStyle(
                      color: gw.text, fontSize: gwTitleSize(context),
                      fontWeight: FontWeight.w800, letterSpacing: -0.8)),
                    Text('Nearest place to take this waste',
                        style: TextStyle(color: gw.muted, fontSize: 12.5)),
                  ],
                ),
              ),
              GwGlassIcon(icon: GwIcons.search, size: 17, onTap: _locate),
            ]),
          ),
          const SizedBox(height: 12),

          // Waste-type routing
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: g),
              itemCount: WasteRoute.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _chip(gw, WasteRoute.values[i]),
            ),
          ),
          const SizedBox(height: 12),

          if (_mapSupported && _pos != null)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: g),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: 200,
                  child: GoogleMap(
                    mapType: MapType.hybrid,
                    initialCameraPosition: CameraPosition(
                      target: LatLng(_pos!.latitude, _pos!.longitude),
                      zoom: 12,
                    ),
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

          if (_mapSupported && _pos != null) const SizedBox(height: 14),

          Expanded(child: _body(gw, g)),
        ]),
      ),
    );
  }

  Widget _chip(GwColors gw, WasteRoute r) {
    final selected = r == _route;
    return GestureDetector(
      onTap: () => _pickRoute(r),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? gw.green.withOpacity(.18) : gw.bg2.withOpacity(.5),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? gw.green : gw.border),
        ),
        child: Text(r.label, style: TextStyle(
          color: selected ? gw.green : gw.muted,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600)),
      ),
    );
  }

  Widget _body(GwColors gw, double g) {
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
            GwIcon(GwIcons.pin, size: 34, color: gw.muted),
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
                  style: TextStyle(color: gw.text, fontSize: 14.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(s.address, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: gw.muted, fontSize: 11.5)),
              const SizedBox(height: 5),
              Row(children: [
                Text(s.distanceLabel, style: TextStyle(
                  color: gw.green, fontSize: 11.5, fontWeight: FontWeight.w700)),
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
