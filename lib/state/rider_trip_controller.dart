import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/directions_service.dart';
import '../services/places_service.dart';
import '../config/api_keys.dart';

// ═══════════════════════════════════════════════════════════════════
//  Rider trip phases — mirrors Uber rider flow
// ═══════════════════════════════════════════════════════════════════
enum RiderPhase {
  idle, // Home screen — "Where to?"
  selectingLocations, // Typing pickup / dropoff
  previewRoute, // Map shows route preview
  selectingRide, // Ride options (X, Comfort, XL, Black)
  requesting, // "Looking for a driver…"
  searchingDriver, // Searching animation
  driverAssigned, // Driver matched — show info
  driverArriving, // Car moving to pickup
  onTrip, // Rider in the car
  completed, // Trip done
  cancelled, // Cancelled by rider or driver
}

// ═══════════════════════════════════════════════════════════════════
//  Ride type option
// ═══════════════════════════════════════════════════════════════════
class RideOption {
  final String id;
  final String name;
  final String description;
  final double priceEstimate; // USD
  final int etaMinutes;
  final String icon; // emoji or asset ref
  final int capacity;

  const RideOption({
    required this.id,
    required this.name,
    required this.description,
    required this.priceEstimate,
    required this.etaMinutes,
    required this.icon,
    this.capacity = 4,
  });
}

// ═══════════════════════════════════════════════════════════════════
//  Driver info after match
// ═══════════════════════════════════════════════════════════════════
class MatchedDriver {
  final String id;
  final String name;
  final double rating;
  final int totalTrips;
  final String vehicleMake;
  final String vehicleModel;
  final String vehicleColor;
  final String vehiclePlate;
  final String vehicleYear;
  final String? photoUrl;

  const MatchedDriver({
    required this.id,
    required this.name,
    required this.rating,
    required this.totalTrips,
    required this.vehicleMake,
    required this.vehicleModel,
    required this.vehicleColor,
    required this.vehiclePlate,
    required this.vehicleYear,
    this.photoUrl,
  });
}

// ═══════════════════════════════════════════════════════════════════
//  State snapshot emitted by the controller
// ═══════════════════════════════════════════════════════════════════
class RiderTripState {
  final RiderPhase phase;

  // Locations
  final PlaceDetails? pickup;
  final PlaceDetails? dropoff;
  final String pickupLabel;
  final String dropoffLabel;

  // Route
  final RouteResult? route;

  // Ride options
  final List<RideOption> rideOptions;
  final RideOption? selectedOption;

  // After match
  final MatchedDriver? driver;
  final int etaMinutes;

  // Driver location (for tracking)
  final LatLng? driverLocation;
  final double driverBearing;

  // Scheduling & airport
  final DateTime? scheduledAt;
  final bool isAirportTrip;

  const RiderTripState({
    this.phase = RiderPhase.idle,
    this.pickup,
    this.dropoff,
    this.pickupLabel = '',
    this.dropoffLabel = '',
    this.route,
    this.rideOptions = const [],
    this.selectedOption,
    this.driver,
    this.etaMinutes = 0,
    this.driverLocation,
    this.driverBearing = 0,
    this.scheduledAt,
    this.isAirportTrip = false,
  });

  RiderTripState copyWith({
    RiderPhase? phase,
    PlaceDetails? pickup,
    PlaceDetails? dropoff,
    String? pickupLabel,
    String? dropoffLabel,
    RouteResult? route,
    List<RideOption>? rideOptions,
    RideOption? selectedOption,
    MatchedDriver? driver,
    int? etaMinutes,
    LatLng? driverLocation,
    double? driverBearing,
    DateTime? scheduledAt,
    bool? isAirportTrip,
  }) {
    return RiderTripState(
      phase: phase ?? this.phase,
      pickup: pickup ?? this.pickup,
      dropoff: dropoff ?? this.dropoff,
      pickupLabel: pickupLabel ?? this.pickupLabel,
      dropoffLabel: dropoffLabel ?? this.dropoffLabel,
      route: route ?? this.route,
      rideOptions: rideOptions ?? this.rideOptions,
      selectedOption: selectedOption ?? this.selectedOption,
      driver: driver ?? this.driver,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      driverLocation: driverLocation ?? this.driverLocation,
      driverBearing: driverBearing ?? this.driverBearing,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      isAirportTrip: isAirportTrip ?? this.isAirportTrip,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Main controller
// ═══════════════════════════════════════════════════════════════════
class RiderTripController extends ChangeNotifier {
  RiderTripState _state = const RiderTripState();
  RiderTripState get state => _state;

  final DirectionsService _directions = DirectionsService(ApiKeys.webServices);

  Timer? _searchTimer;
  Timer? _driverSimTimer;
  int _simStep = 0;

  // ─── Location selection ──────────────────────────────────────

  void setPickup(PlaceDetails place, String label) {
    _state = _state.copyWith(pickup: place, pickupLabel: label);
    notifyListeners();
    _tryFetchRoute();
  }

  void setDropoff(PlaceDetails place, String label) {
    _state = _state.copyWith(dropoff: place, dropoffLabel: label);
    notifyListeners();
    _tryFetchRoute();
  }

  void startLocationSelection() {
    _state = _state.copyWith(phase: RiderPhase.selectingLocations);
    notifyListeners();
  }

  void setSchedule(DateTime? dateTime) {
    _state = _state.copyWith(scheduledAt: dateTime);
    notifyListeners();
  }

  // ─── Route preview ──────────────────────────────────────────

  Future<void> _tryFetchRoute() async {
    if (_state.pickup == null || _state.dropoff == null) return;

    final origin = LatLng(_state.pickup!.lat, _state.pickup!.lng);
    final dest = LatLng(_state.dropoff!.lat, _state.dropoff!.lng);

    final result = await _directions.getRoute(
      origin: origin,
      destination: dest,
    );

    if (result != null) {
      final options = _generateRideOptions(result);
      _state = _state.copyWith(
        phase: RiderPhase.previewRoute,
        route: result,
        rideOptions: options,
        selectedOption: options.isNotEmpty ? options.first : null,
      );
      notifyListeners();
    }
  }

  static bool _isAirport(String label) {
    final l = label.toLowerCase();
    return l.contains('airport') ||
        l.contains('aeropuerto') ||
        l.contains('intl') ||
        l.contains('terminal') ||
        l.contains('aviation') ||
        RegExp(r'\b(mia|jfk|lax|atl|ord|dfw|bhm|sfo|ewr|lga)\b').hasMatch(l);
  }

  List<RideOption> _generateRideOptions(RouteResult route) {
    // Base: ~$1.50/mi + $0.25/min, with multiplier per type
    final miles = route.distanceMeters / 1609.344;
    final mins = _parseDurationMinutes(route.durationText);
    double baseFare = 2.50 + (miles * 1.50) + (mins * 0.25);

    // Airport surcharge: +$8 flat + 15% uplift
    final airportTrip = _isAirport(_state.pickupLabel) || _isAirport(_state.dropoffLabel);
    if (airportTrip) {
      baseFare = (baseFare + 8.0) * 1.15;
    }
    _state = _state.copyWith(isAirportTrip: airportTrip);

    return [
      RideOption(
        id: 'suburban',
        name: 'Suburban',
        description: 'Premium SUV experience',
        priceEstimate: _round(baseFare * 2.20),
        etaMinutes: 5 + math.Random().nextInt(8),
        icon: '�',
        capacity: 7,
      ),
      RideOption(
        id: 'camry',
        name: 'Camry',
        description: 'Comfortable sedan',
        priceEstimate: _round(baseFare * 1.35),
        etaMinutes: 4 + math.Random().nextInt(6),
        icon: '🚙',
        capacity: 4,
      ),
      RideOption(
        id: 'fusion',
        name: 'Fusion',
        description: 'Affordable rides',
        priceEstimate: _round(baseFare),
        etaMinutes: 3 + math.Random().nextInt(5),
        icon: '�',
        capacity: 4,
      ),
    ];
  }

  double _round(double v) => (v * 100).roundToDouble() / 100;

  int _parseDurationMinutes(String text) {
    // "12 min" or "1 h 5 min"
    final parts = text.split(RegExp(r'\s+'));
    int total = 0;
    for (int i = 0; i < parts.length; i++) {
      final n = int.tryParse(parts[i]);
      if (n != null && i + 1 < parts.length) {
        if (parts[i + 1].startsWith('h')) {
          total += n * 60;
        } else {
          total += n;
        }
      }
    }
    return total > 0 ? total : 10;
  }

  // ─── Ride selection ─────────────────────────────────────────

  void showRideOptions() {
    _state = _state.copyWith(phase: RiderPhase.selectingRide);
    notifyListeners();
  }

  void selectRideOption(RideOption option) {
    _state = _state.copyWith(selectedOption: option);
    notifyListeners();
  }

  // ─── Request ride ───────────────────────────────────────────

  void requestRide() {
    _state = _state.copyWith(phase: RiderPhase.requesting);
    notifyListeners();

    // Simulate searching → match in 3–6 seconds
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 800), () {
      _state = _state.copyWith(phase: RiderPhase.searchingDriver);
      notifyListeners();
    });

    Timer(const Duration(seconds: 15), () {
      _onDriverMatched();
    });
  }

  void _onDriverMatched() {
    // Pick vehicle based on selected ride option
    String make = 'Toyota';
    String model = 'Camry';
    String color = 'Gray';
    String plate = 'ABC-1234';
    String year = '2022';
    String name = 'Yuniel';

    final optId = _state.selectedOption?.id ?? 'fusion';
    switch (optId) {
      case 'fusion':
        // Fusion → Black Ford Fusion
        make = 'Ford';
        model = 'Fusion';
        color = 'Black';
        plate = 'KTR-7293';
        year = '2024';
        name = 'Carlos M.';
        break;
      case 'camry':
        // Camry → White Toyota Camry
        make = 'Toyota';
        model = 'Camry';
        color = 'White';
        plate = 'MFL-4821';
        year = '2023';
        name = 'Yuniel';
        break;
      case 'suburban':
        // VIP Suburban → Black Chevrolet Suburban
        make = 'Chevrolet';
        model = 'Suburban';
        color = 'Black';
        plate = 'LUX-0088';
        year = '2025';
        name = 'David L.';
        break;
    }

    final driver = MatchedDriver(
      id: 'drv-001',
      name: name,
      rating: 4.9,
      totalTrips: 1847,
      vehicleMake: make,
      vehicleModel: model,
      vehicleColor: color,
      vehiclePlate: plate,
      vehicleYear: year,
    );

    _state = _state.copyWith(
      phase: RiderPhase.driverAssigned,
      driver: driver,
      etaMinutes: _state.selectedOption?.etaMinutes ?? 5,
    );
    notifyListeners();

    // After 1.5s transition to arriving
    Timer(const Duration(milliseconds: 1500), () {
      _state = _state.copyWith(phase: RiderPhase.driverArriving);
      notifyListeners();
      _startDriverSimulation();
    });
  }

  // ─── Driver simulation (demo) ──────────────────────────────

  void _startDriverSimulation() {
    if (_state.route == null || _state.route!.points.isEmpty) return;

    final pts = _state.route!.points;
    // Driver starts 30% of the way if going to pickup, simulates from there
    _simStep = 0;
    final totalSteps = (pts.length * 0.4).round().clamp(1, pts.length - 1);

    _driverSimTimer?.cancel();
    _driverSimTimer = Timer.periodic(const Duration(milliseconds: 120), (
      timer,
    ) {
      if (_simStep >= totalSteps) {
        timer.cancel();
        // Arrived at pickup
        _state = _state.copyWith(
          phase: RiderPhase.onTrip,
          driverLocation: _state.pickup != null
              ? LatLng(_state.pickup!.lat, _state.pickup!.lng)
              : pts.last,
        );
        notifyListeners();

        // Simulate trip for 8 seconds then complete
        Timer(const Duration(seconds: 8), () {
          _state = _state.copyWith(phase: RiderPhase.completed);
          notifyListeners();
        });
        return;
      }

      final idx = (_simStep * pts.length ~/ totalSteps).clamp(
        0,
        pts.length - 1,
      );
      final pos = pts[idx];
      double bearing = 0;
      if (idx + 1 < pts.length) {
        bearing = _calcBearing(pos, pts[idx + 1]);
      }

      _state = _state.copyWith(
        driverLocation: pos,
        driverBearing: bearing,
        etaMinutes: ((totalSteps - _simStep) * 0.12 / 60 * 100).round().clamp(
          1,
          99,
        ),
      );
      notifyListeners();
      _simStep++;
    });
  }

  double _calcBearing(LatLng from, LatLng to) {
    final dLon = (to.longitude - from.longitude) * math.pi / 180;
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  // ─── Cancel ─────────────────────────────────────────────────

  void cancelRide() {
    _searchTimer?.cancel();
    _driverSimTimer?.cancel();
    _state = _state.copyWith(phase: RiderPhase.cancelled);
    notifyListeners();
  }

  void reset() {
    _searchTimer?.cancel();
    _driverSimTimer?.cancel();
    _state = const RiderTripState();
    notifyListeners();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _driverSimTimer?.cancel();
    super.dispose();
  }
}
