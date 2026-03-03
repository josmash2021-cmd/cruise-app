import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/map_styles.dart';
import '../navigation/car_sprite_manager.dart';
import '../navigation/nav_state_machine.dart';
import '../navigation/route_snapper.dart';
import '../navigation/route_service.dart';
import '../navigation/smooth_motion.dart';
import '../services/navigation_service.dart';

class DriverNavigationPage extends StatefulWidget {
  const DriverNavigationPage({
    super.key,
    required this.pickupLatLng,
    required this.dropoffLatLng,
    this.tripId = 'demo-trip',
    this.initialDriverPos,
    this.routePoints,
    this.demoMode = false,
    this.riderName = 'Rider',
    this.vehiclePlate = '',
    this.speedLimitMph = 35,
  });

  final LatLng pickupLatLng;
  final LatLng dropoffLatLng;
  final String tripId;
  final LatLng? initialDriverPos;
  final List<LatLng>? routePoints;
  final bool demoMode;
  final String riderName;
  final String vehiclePlate;
  final int speedLimitMph;

  @override
  State<DriverNavigationPage> createState() => _DriverNavigationPageState();
}

class _DriverNavigationPageState extends State<DriverNavigationPage>
    with TickerProviderStateMixin {
  GoogleMapController? _map;
  bool _mapReady = false;
  late final NavStateMachine _sm;
  late final SmoothMotion _motion;
  final NavigationService _navService = NavigationService();

  LatLng _pos = const LatLng(0, 0);
  double _bearing = 0;
  int _snapIdx = 0;
  bool _cameraFollowing = true;
  Timer? _reFollowTimer;

  List<LatLng> _routePts = [];
  List<LatLng> _displayRoutePts = [];
  NavigationState? _navState;

  double _distRemainingMi = 0;
  int _etaMinutes = 0;

  StreamSubscription? _gpsSub;
  Timer? _demoTimer;
  int _demoIdx = 0;
  bool _muted = false;

  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _red = Color(0xFFEF5350);
  static const _gold = Color(0xFFD4A24C);

  @override
  void initState() {
    super.initState();
    _pos = widget.initialDriverPos ?? widget.pickupLatLng;
    _sm = NavStateMachine(
      onPhaseChanged: (p) {
        if (mounted) setState(() {});
        _onPhaseChanged(p);
      },
    );
    _sm.startTrip(
      tripId: widget.tripId,
      pickup: widget.pickupLatLng,
      dropoff: widget.dropoffLatLng,
    );
    _motion = SmoothMotion(
      onTick: _onMotionTick,
      lerpFactor: 0.15,
      enablePrediction: true,
    );
    _motion.start(this);
    _motion.teleport(_pos, 0);
    _routePts =
        widget.routePoints ?? _makeStraightRoute(_pos, widget.pickupLatLng);
    _displayRoutePts = List.of(_routePts);
    _buildRouteOnInit();
    _loadIcon();
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _demoTimer?.cancel();
    _reFollowTimer?.cancel();
    _motion.dispose();
    _sm.dispose();
    _map?.dispose();
    super.dispose();
  }

  Future<void> _loadIcon() async {
    await CarSpriteManager.init();
    if (mounted) setState(() {});
  }

  Future<void> _buildRouteOnInit() async {
    if (widget.routePoints == null) {
      final dest = (_sm.phase == TripPhase.toPickup)
          ? widget.pickupLatLng
          : widget.dropoffLatLng;
      final route = await RouteService.fetchNavRoute(
        origin: _pos,
        destination: dest,
      );
      if (route != null && mounted) {
        _routePts = route.overviewPolyline;
        _displayRoutePts = List.of(_routePts);
        _navService.startNavigation(route);
      }
    }
    if (mounted) setState(() {});
    widget.demoMode ? _startDemo() : _startGPS();
  }

  void _startGPS() {
    _gpsSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 1,
          ),
        ).listen((pos) {
          if (!mounted) return;
          _onRawPosition(LatLng(pos.latitude, pos.longitude), pos.heading);
        });
  }

  void _startDemo() {
    if (_routePts.length < 2) return;
    _demoIdx = 0;
    _demoTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (!mounted) return;
      _demoIdx = (_demoIdx + 1).clamp(0, _routePts.length - 1);
      final pt = _routePts[_demoIdx];
      final prev = _routePts[(_demoIdx - 1).clamp(0, _routePts.length - 1)];
      final bearing = SmoothMotion.computeBearing(prev, pt);
      _onRawPosition(pt, bearing);
      if (_demoIdx >= _routePts.length - 1) {
        _demoTimer?.cancel();
        if (_sm.phase == TripPhase.toPickup) {
          _sm.arriveAtPickup();
        } else if (_sm.phase == TripPhase.onTrip) {
          _sm.arriveAtDropoff();
        }
      }
    });
  }

  void _onRawPosition(LatLng raw, double rawBearing) {
    final snap = RouteSnapper.snap(raw, _routePts, lastIndex: _snapIdx);
    _snapIdx = snap.segmentIndex;
    _motion.pushTarget(snap.snapped, snap.bearingDeg);
    if (_navService.isNavigating)
      _navState = _navService.updatePosition(snap.snapped);
    _sm.checkProximity(snap.snapped);
    _trimRouteBehind(snap.segmentIndex);
    final dest = _sm.phase == TripPhase.onTrip
        ? widget.dropoffLatLng
        : widget.pickupLatLng;
    final dM = _haversineM(snap.snapped, dest);
    setState(() {
      _distRemainingMi = dM / 1609.34;
      _etaMinutes =
          _navState?.etaMinutes ?? (dM / 500 / 60).ceil().clamp(1, 99);
    });
  }

  void _trimRouteBehind(int segIdx) {
    if (segIdx < 2 || segIdx >= _routePts.length) return;
    _displayRoutePts = _routePts.sublist(segIdx);
  }

  void _onMotionTick(LatLng pos, double bearing) {
    if (!mounted) return;
    _pos = pos;
    _bearing = bearing;
    setState(() {});
    if (_cameraFollowing && _map != null && _mapReady) {
      _map!.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: pos, zoom: 17.8, bearing: bearing, tilt: 65),
        ),
      );
    }
  }

  void _onPhaseChanged(TripPhase phase) {
    if (phase == TripPhase.onTrip) _switchToDropoffRoute();
  }

  Future<void> _switchToDropoffRoute() async {
    final route = await RouteService.fetchNavRoute(
      origin: _pos,
      destination: widget.dropoffLatLng,
    );
    if (route != null && mounted) {
      _routePts = route.overviewPolyline;
      _displayRoutePts = List.of(_routePts);
      _navService.startNavigation(route);
      _snapIdx = 0;
      setState(() {});
      if (widget.demoMode) {
        _demoTimer?.cancel();
        _startDemo();
      }
    } else if (mounted) {
      _routePts = _makeStraightRoute(_pos, widget.dropoffLatLng);
      _displayRoutePts = List.of(_routePts);
      _snapIdx = 0;
      setState(() {});
      if (widget.demoMode) {
        _demoTimer?.cancel();
        _startDemo();
      }
    }
  }

  void _onCameraMoveStarted() {
    if (!_cameraFollowing) return;
    setState(() => _cameraFollowing = false);
    _reFollowTimer?.cancel();
    _reFollowTimer = Timer(const Duration(seconds: 7), _recenter);
  }

  void _recenter() {
    if (!mounted) return;
    _reFollowTimer?.cancel();
    setState(() => _cameraFollowing = true);
    _map?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _pos, zoom: 17.8, bearing: _bearing, tilt: 65),
      ),
    );
  }

  Set<Marker> get _allMarkers {
    final m = <Marker>{};
    m.add(
      Marker(
        markerId: const MarkerId('driver'),
        position: _pos,
        icon: CarSpriteManager.iconForBearing(_bearing),
        rotation: 0,
        flat: false,
        anchor: const Offset(0.5, 0.65),
        zIndexInt: 100,
      ),
    );
    final dest =
        _sm.phase == TripPhase.onTrip || _sm.phase == TripPhase.arrivedDropoff
        ? widget.dropoffLatLng
        : widget.pickupLatLng;
    m.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: dest,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          _sm.phase == TripPhase.toPickup
              ? BitmapDescriptor.hueGreen
              : BitmapDescriptor.hueRed,
        ),
        zIndexInt: 90,
      ),
    );
    return m;
  }

  Set<Polyline> get _polylines {
    final s = <Polyline>{};
    if (_displayRoutePts.length >= 2) {
      s.add(
        Polyline(
          polylineId: const PolylineId('shadow'),
          points: _displayRoutePts,
          color: const Color(0x44000000),
          width: 12,
        ),
      );
      s.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: _displayRoutePts,
          color: _sm.phase == TripPhase.toPickup ? _green : _blue,
          width: 7,
        ),
      );
    }
    return s;
  }

  // =========================================================================
  //  BUILD
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final top = mq.padding.top;
    final bot = mq.padding.bottom;

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Stack(
        children: [
          // ── FULLSCREEN MAP ────────────────────────────────────────────────
          Positioned.fill(
            child: GoogleMap(
              style: MapStyles.dark,
              initialCameraPosition: CameraPosition(
                target: _pos,
                zoom: 17.8,
                tilt: 65,
              ),
              onMapCreated: (c) {
                _map = c;
                _mapReady = true;
                _map!.moveCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: _pos, zoom: 17.8, tilt: 65),
                  ),
                );
              },
              onCameraMoveStarted: _onCameraMoveStarted,
              markers: _allMarkers,
              polylines: _polylines,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
              buildingsEnabled: true,
              trafficEnabled: true,
              padding: EdgeInsets.only(top: top + 130, bottom: 200 + bot),
            ),
          ),

          // ── TOP NAV BANNER ────────────────────────────────────────────────
          Positioned(top: top + 8, left: 12, right: 12, child: _navBanner()),

          // ── SPEED LIMIT SIGN (bottom-left above ETA bar) ──────────────────
          Positioned(bottom: 172 + bot, left: 14, child: _speedLimitSign()),

          // ── RIGHT FLOATING BUTTON STACK ───────────────────────────────────
          Positioned(right: 14, bottom: 192 + bot, child: _rightFabStack()),

          // ── RECENTER BUTTON ───────────────────────────────────────────────
          if (!_cameraFollowing)
            Positioned(bottom: 190 + bot, left: 80, child: _recenterButton()),

          // ── ACTION PILL (ARRIVED / START / END TRIP) ──────────────────────
          if (_showActionPill)
            Positioned(
              bottom: 132 + bot,
              left: 16,
              right: 16,
              child: _actionPill(),
            ),

          // ── BOTTOM ETA BAR ────────────────────────────────────────────────
          Positioned(bottom: 0, left: 0, right: 0, child: _etaBar(bot)),
        ],
      ),
    );
  }

  // =========================================================================
  //  TOP NAV BANNER
  // =========================================================================

  Widget _navBanner() {
    final maneuver = _navState?.currentManeuver ?? 'straight';
    final mInfo = NavigationService.getManeuverIcon(maneuver);
    final distText = _navState?.distanceToTurnText ?? '';
    final instruction = _navState?.currentInstruction ?? _phaseInstruction;
    final streetName = _navState?.currentStep?.streetName ?? '';
    final isOffRoute = _navState?.isOffRoute ?? false;

    final bgColor = isOffRoute
        ? const Color(0xFFB71C1C)
        : (_sm.phase == TripPhase.toPickup
              ? const Color(0xFF1B5E20)
              : const Color(0xFF0A2E6E));

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Maneuver arrow
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    IconData(mInfo.iconCodePoint, fontFamily: 'MaterialIcons'),
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                const SizedBox(width: 14),
                // Distance + instruction
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (distText.isNotEmpty)
                        Text(
                          distText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        instruction,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isOffRoute)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'OFF\nROUTE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        height: 1.2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Street name
          if (streetName.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.turn_slight_right_rounded,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      streetName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String get _phaseInstruction {
    switch (_sm.phase) {
      case TripPhase.toPickup:
        return 'Head to pickup';
      case TripPhase.arrivedPickup:
        return 'Arrived at pickup';
      case TripPhase.onTrip:
        return 'Head to drop-off';
      case TripPhase.arrivedDropoff:
        return 'Arrived at destination';
      case TripPhase.completed:
        return 'Trip complete';
      default:
        return 'Ready';
    }
  }

  // =========================================================================
  //  SPEED LIMIT SIGN — US MUTCD style (white box, black border, number)
  // =========================================================================

  Widget _speedLimitSign() {
    return Container(
      width: 48,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'SPEED\nLIMIT',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black,
              fontSize: 7.5,
              fontWeight: FontWeight.w900,
              height: 1.15,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            '${widget.speedLimitMph}',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  //  RIGHT FLOATING ACTION BUTTONS
  // =========================================================================

  Widget _rightFabStack() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _circleFab(
          icon: Icons.home_rounded,
          tooltip: 'Go Home',
          onTap: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 10),
        _circleFab(
          icon: Icons.share_rounded,
          tooltip: 'Share ETA',
          onTap: () {
            HapticFeedback.lightImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('ETA shared'),
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        _circleFab(
          icon: _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          tooltip: _muted ? 'Unmute' : 'Mute',
          active: _muted,
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _muted = !_muted);
          },
        ),
        const SizedBox(height: 10),
        _circleFab(
          icon: Icons.report_problem_rounded,
          tooltip: 'Report incident',
          onTap: () {
            HapticFeedback.mediumImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Incident reported'),
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _circleFab({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: active
                ? _blue
                : const Color(0xFF1E1E2A).withValues(alpha: 0.92),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.85),
            size: 22,
          ),
        ),
      ),
    );
  }

  // =========================================================================
  //  RECENTER BUTTON
  // =========================================================================

  Widget _recenterButton() {
    return GestureDetector(
      onTap: _recenter,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2A).withValues(alpha: 0.92),
          shape: BoxShape.circle,
          border: Border.all(color: _blue.withValues(alpha: 0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(Icons.navigation_rounded, color: _blue, size: 24),
      ),
    );
  }

  // =========================================================================
  //  BOTTOM ETA BAR  — 3 columns: arrival | time remaining | distance
  // =========================================================================

  Widget _etaBar(double botPad) {
    final arrival = DateTime.now().add(Duration(minutes: _etaMinutes));
    final h12 = arrival.hour % 12 == 0 ? 12 : arrival.hour % 12;
    final min = arrival.minute.toString().padLeft(2, '0');
    final ampm = arrival.hour < 12 ? 'AM' : 'PM';
    final arrivalStr = '$h12:$min $ampm';
    final distStr = _distRemainingMi < 0.1
        ? '${(_distRemainingMi * 5280).round()} ft'
        : '${_distRemainingMi.toStringAsFixed(1)} mi';

    return Container(
      padding: EdgeInsets.only(top: 14, bottom: botPad + 14),
      decoration: const BoxDecoration(
        color: Color(0xFF111116),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _etaCell(primary: arrivalStr, secondary: 'arrival'),
          ),
          _etaDivider(),
          Expanded(
            child: _etaCell(
              primary: '$_etaMinutes min',
              secondary: 'remaining',
            ),
          ),
          _etaDivider(),
          Expanded(
            child: _etaCell(primary: distStr, secondary: 'distance'),
          ),
        ],
      ),
    );
  }

  Widget _etaCell({required String primary, required String secondary}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          primary,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            fontFeatures: [FontFeature.tabularFigures()],
            height: 1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          secondary,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _etaDivider() => Container(
    width: 1,
    height: 28,
    color: Colors.white.withValues(alpha: 0.1),
  );

  // =========================================================================
  //  ACTION PILL  — floating above bottom bar, only when action needed
  // =========================================================================

  bool get _showActionPill =>
      _sm.phase == TripPhase.toPickup ||
      _sm.phase == TripPhase.arrivedPickup ||
      _sm.phase == TripPhase.onTrip ||
      _sm.phase == TripPhase.arrivedDropoff;

  Widget _actionPill() {
    String label;
    Color bg;
    VoidCallback onTap;
    switch (_sm.phase) {
      case TripPhase.toPickup:
        label = 'ARRIVED AT PICKUP';
        bg = const Color(0xFF2E7D32);
        onTap = () {
          HapticFeedback.heavyImpact();
          _sm.arriveAtPickup();
        };
        break;
      case TripPhase.arrivedPickup:
        label = 'START TRIP';
        bg = _gold;
        onTap = () {
          HapticFeedback.heavyImpact();
          _sm.beginTrip();
        };
        break;
      case TripPhase.onTrip:
        label = 'END TRIP';
        bg = _red;
        onTap = () {
          HapticFeedback.heavyImpact();
          _sm.arriveAtDropoff();
        };
        break;
      case TripPhase.arrivedDropoff:
        label = 'FINISH RIDE';
        bg = _gold;
        onTap = () {
          HapticFeedback.heavyImpact();
          _sm.completeTrip();
          Navigator.of(context).pop();
        };
        break;
      default:
        return const SizedBox.shrink();
    }
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: Colors.black54,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }

  // =========================================================================
  //  UTILS
  // =========================================================================

  List<LatLng> _makeStraightRoute(LatLng from, LatLng to) {
    const n = 60;
    return List.generate(n + 1, (i) {
      final t = i / n;
      return LatLng(
        from.latitude + (to.latitude - from.latitude) * t,
        from.longitude + (to.longitude - from.longitude) * t,
      );
    });
  }

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
