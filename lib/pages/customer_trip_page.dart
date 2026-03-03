import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/map_styles.dart';
import '../navigation/car_icon_loader.dart';
import '../navigation/nav_state_machine.dart';
import '../navigation/route_snapper.dart';
import '../navigation/smooth_motion.dart';

/// Customer "follow-my-trip" screen.
///
/// Shows a top-down map with:
///  • Black 3D car marker moving along the route
///  • Pickup + dropoff markers
///  • Polyline route (driver→pickup or pickup→dropoff)
///  • ETA / distance / time overlays
///
/// Expects driver location updates via [driverLocationStream].
/// If no stream is provided, a demo simulation runs automatically.
class CustomerTripPage extends StatefulWidget {
  const CustomerTripPage({
    super.key,
    required this.pickupLatLng,
    required this.dropoffLatLng,
    this.driverLocationStream,
    this.driverBearingStream,
    this.routePoints,
    this.driverName = 'Carlos M.',
    this.vehiclePlate = 'ABC-1234',
    this.tripId = 'demo-trip',
    this.initialPhase = TripPhase.toPickup,
  });

  final LatLng pickupLatLng;
  final LatLng dropoffLatLng;
  final Stream<LatLng>? driverLocationStream;
  final Stream<double>? driverBearingStream;

  /// Pre-fetched route polyline. If null a straight line is used.
  final List<LatLng>? routePoints;

  final String driverName;
  final String vehiclePlate;
  final String tripId;
  final TripPhase initialPhase;

  @override
  State<CustomerTripPage> createState() => _CustomerTripPageState();
}

class _CustomerTripPageState extends State<CustomerTripPage>
    with TickerProviderStateMixin {
  GoogleMapController? _map;
  BitmapDescriptor? _carIcon;

  late final NavStateMachine _sm;
  late final SmoothMotion _motion;

  // Driver state
  LatLng _driverPos = const LatLng(0, 0);
  double _driverBearing = 0;
  int _snapSegIdx = 0;

  // Route
  List<LatLng> _routePts = [];
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  // ETA / distance
  double _distRemainingKm = 0;
  int _etaMinutes = 0;

  // Streams
  StreamSubscription? _locSub;
  StreamSubscription? _bearSub;
  Timer? _demoTimer;

  bool _mapReady = false;

  @override
  void initState() {
    super.initState();

    _sm = NavStateMachine(
      onPhaseChanged: (_) {
        if (mounted) setState(() {});
      },
    );
    _sm.startTrip(
      tripId: widget.tripId,
      pickup: widget.pickupLatLng,
      dropoff: widget.dropoffLatLng,
    );

    _driverPos = widget.pickupLatLng; // start near pickup

    _motion = SmoothMotion(
      onTick: _onMotionTick,
      lerpFactor: 0.12,
      bearingLerpFactor: 0.15,
    );
    _motion.start(this);

    _routePts = widget.routePoints ?? _generateStraightRoute();
    _buildPolyline();

    _loadIcon();
    _subscribeStreams();
  }

  @override
  void dispose() {
    _locSub?.cancel();
    _bearSub?.cancel();
    _demoTimer?.cancel();
    _motion.dispose();
    _sm.dispose();
    _map?.dispose();
    super.dispose();
  }

  // ─── BOOT ───

  Future<void> _loadIcon() async {
    _carIcon = await CarIconLoader.load();
    if (mounted) setState(() {});
  }

  void _subscribeStreams() {
    if (widget.driverLocationStream != null) {
      _locSub = widget.driverLocationStream!.listen(_onDriverLocation);
      _bearSub = widget.driverBearingStream?.listen((b) {
        _driverBearing = b;
      });
    } else {
      _startDemoSimulation();
    }
  }

  // ─── DEMO SIMULATION ───

  void _startDemoSimulation() {
    int idx = 0;
    _driverPos = _routePts.first;
    _motion.teleport(_routePts.first, 0);

    _demoTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (!mounted) return;
      idx = (idx + 1).clamp(0, _routePts.length - 1);
      final pos = _routePts[idx];
      final bearing = idx > 0
          ? SmoothMotion.computeBearing(_routePts[idx - 1], pos)
          : 0.0;
      _onDriverLocation(pos);
      _driverBearing = bearing;

      // Check if reached pickup → switch to onTrip phase
      if (_sm.phase == TripPhase.toPickup && idx >= _routePts.length ~/ 2) {
        _sm.arriveAtPickup();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _sm.beginTrip();
        });
      }
      if (idx >= _routePts.length - 1) {
        _demoTimer?.cancel();
        _sm.arriveAtDropoff();
      }
    });
  }

  // ─── DRIVER LOCATION UPDATE ───

  void _onDriverLocation(LatLng raw) {
    // Snap to route
    final snap = RouteSnapper.snap(raw, _routePts, lastIndex: _snapSegIdx);
    _snapSegIdx = snap.segmentIndex;

    // Compute bearing from delta if no bearing stream
    if (widget.driverBearingStream == null) {
      final prev = _driverPos;
      if (_haversineM(prev, snap.snapped) > 1) {
        _driverBearing = SmoothMotion.computeBearing(prev, snap.snapped);
      }
    }

    _motion.pushTarget(snap.snapped, _driverBearing);

    // Update ETA / distance
    final dest = _sm.phase == TripPhase.onTrip
        ? widget.dropoffLatLng
        : widget.pickupLatLng;
    final distM = _haversineM(snap.snapped, dest);
    setState(() {
      _distRemainingKm = distM / 1000;
      _etaMinutes = (distM / 500 /* ~30 km/h */ / 60).ceil().clamp(1, 99);
    });
  }

  void _onMotionTick(LatLng pos, double bearing) {
    if (!mounted) return;
    _driverPos = pos;
    _driverBearing = bearing;
    setState(() {});
    _updateCamera();
  }

  // ─── CAMERA ───

  void _updateCamera() {
    if (_map == null || !_mapReady) return;

    final dest = _sm.phase == TripPhase.onTrip
        ? widget.dropoffLatLng
        : widget.pickupLatLng;

    // Fit bounds: driver + destination
    _fitBounds([_driverPos, dest]);
  }

  void _fitBounds(List<LatLng> points) {
    if (points.length < 2) return;
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _map?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80, // padding
      ),
    );
  }

  // ─── ROUTE POLYLINE ───

  void _buildPolyline() {
    _polylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        points: _routePts,
        color: const Color(0xFF4285F4),
        width: 5,
        patterns: const [],
      ),
    };
  }

  List<LatLng> _generateStraightRoute() {
    // If no route provided, interpolate straight line pickup → dropoff
    final from = widget.pickupLatLng;
    final to = widget.dropoffLatLng;
    const steps = 60;
    return List.generate(steps + 1, (i) {
      final t = i / steps;
      return LatLng(
        from.latitude + (to.latitude - from.latitude) * t,
        from.longitude + (to.longitude - from.longitude) * t,
      );
    });
  }

  // ─── MARKERS ───

  Set<Marker> get _allMarkers {
    final m = <Marker>{};

    // Driver car
    if (_carIcon != null) {
      m.add(
        Marker(
          markerId: const MarkerId('driver_car'),
          position: _driverPos,
          icon: _carIcon!,
          rotation: _driverBearing,
          flat: true, // top-down view → flat on map
          anchor: const Offset(0.5, 0.5),
          zIndex: 100,
        ),
      );
    }

    // Pickup
    if (_sm.phase == TripPhase.toPickup ||
        _sm.phase == TripPhase.arrivedPickup) {
      m.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: widget.pickupLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          zIndex: 90,
        ),
      );
    }

    // Dropoff
    m.add(
      Marker(
        markerId: const MarkerId('dropoff'),
        position: widget.dropoffLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        zIndex: 90,
      ),
    );

    return m;
  }

  // ─── BUILD ───

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.pickupLatLng,
              zoom: 14,
              tilt: 0, // top-down
              bearing: 0,
            ),
            onMapCreated: (c) {
              _map = c;
              _mapReady = true;
              try {
                c.setMapStyle(isDark ? MapStyles.dark : MapStyles.light);
              } catch (_) {}
              // Initial fit
              Future.delayed(const Duration(milliseconds: 300), () {
                _fitBounds([widget.pickupLatLng, widget.dropoffLatLng]);
              });
            },
            markers: _allMarkers,
            polylines: _polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            buildingsEnabled: false,
            padding: EdgeInsets.only(top: top + 100, bottom: 200),
          ),

          // ─── TOP STATUS BAR ───
          Positioned(top: 0, left: 0, right: 0, child: _topBar(isDark, top)),

          // ─── BOTTOM TRIP INFO ───
          Positioned(bottom: 0, left: 0, right: 0, child: _bottomPanel(isDark)),
        ],
      ),
    );
  }

  // ─── UI WIDGETS ───

  Widget _topBar(bool isDark, double topPad) {
    final bg = isDark ? const Color(0xE6111111) : const Color(0xE6FFFFFF);
    final text = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final sub = isDark ? Colors.white70 : Colors.black54;

    String title;
    switch (_sm.phase) {
      case TripPhase.toPickup:
        title = 'Driver en camino';
        break;
      case TripPhase.arrivedPickup:
        title = 'Driver arrived';
        break;
      case TripPhase.onTrip:
        title = 'En viaje';
        break;
      case TripPhase.arrivedDropoff:
        title = 'Arriving';
        break;
      case TripPhase.completed:
        title = 'Trip completed';
        break;
      default:
        title = 'Waiting...';
    }

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            top: topPad + 12,
            bottom: 16,
            left: 20,
            right: 20,
          ),
          decoration: BoxDecoration(
            color: bg,
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(
                      Icons.arrow_back_ios_rounded,
                      color: text,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: text,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statChip(
                    Icons.access_time_rounded,
                    '$_etaMinutes min',
                    'ETA',
                    sub,
                    text,
                  ),
                  _statChip(
                    Icons.straighten_rounded,
                    '${_distRemainingKm.toStringAsFixed(1)} km',
                    'Distance',
                    sub,
                    text,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statChip(
    IconData icon,
    String value,
    String label,
    Color sub,
    Color text,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: sub),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                color: text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        Text(label, style: TextStyle(color: sub, fontSize: 11)),
      ],
    );
  }

  Widget _bottomPanel(bool isDark) {
    final bg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final sub = isDark ? Colors.white54 : Colors.black45;
    final bot = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(top: 20, bottom: bot + 16, left: 20, right: 20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: sub,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Driver info row
          Row(
            children: [
              // Avatar placeholder
              CircleAvatar(
                radius: 24,
                backgroundColor: isDark
                    ? const Color(0xFF333333)
                    : const Color(0xFFE0E0E0),
                child: Icon(Icons.person, color: text, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.driverName,
                      style: TextStyle(
                        color: text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.vehiclePlate,
                      style: TextStyle(color: sub, fontSize: 13),
                    ),
                  ],
                ),
              ),
              // Action buttons
              _circleBtn(Icons.phone_rounded, isDark, () {}),
              const SizedBox(width: 10),
              _circleBtn(Icons.message_rounded, isDark, () {}),
            ],
          ),
          const SizedBox(height: 16),
          // Phase progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _phaseProgress,
              minHeight: 4,
              backgroundColor: isDark
                  ? Colors.white12
                  : Colors.black.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF4285F4),
              ),
            ),
          ),
          if (_sm.phase == TripPhase.toPickup ||
              _sm.phase == TripPhase.arrivedPickup) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  // Cancel / support stub
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Support coming soon')),
                  );
                },
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: const Text('Cancel ride'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
        ),
        child: Icon(
          icon,
          color: isDark ? Colors.white70 : Colors.black54,
          size: 20,
        ),
      ),
    );
  }

  double get _phaseProgress {
    switch (_sm.phase) {
      case TripPhase.idle:
        return 0;
      case TripPhase.toPickup:
        return 0.2;
      case TripPhase.arrivedPickup:
        return 0.4;
      case TripPhase.onTrip:
        return 0.7;
      case TripPhase.arrivedDropoff:
        return 0.9;
      case TripPhase.completed:
        return 1.0;
    }
  }

  // ─── UTILS ───

  double _haversineM(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = _r(b.latitude - a.latitude);
    final dLng = _r(b.longitude - a.longitude);
    final x =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_r(a.latitude)) *
            math.cos(_r(b.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return R * 2 * math.atan2(math.sqrt(x), math.sqrt(1 - x));
  }

  double _r(double d) => d * math.pi / 180;
}
