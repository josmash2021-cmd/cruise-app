import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;

/// Full driver lifecycle — mirrors Uber Driver's state machine.
///
/// States:
///   OFFLINE → ONLINE_IDLE → INCOMING_REQUEST → TO_PICKUP
///   → ARRIVED_PICKUP → ON_TRIP → ARRIVED_DROPOFF → COMPLETED
///
/// Each transition is validated; invalid transitions are no-ops.
enum DriverPhase {
  offline,
  onlineIdle,
  incomingRequest,
  toPickup,
  arrivedPickup,
  onTrip,
  arrivedDropoff,
  completed,
}

/// Trip request data passed to the state machine when a request comes in.
class TripRequest {
  final String tripId;
  final String riderName;
  final String riderPhotoUrl;
  final double riderRating;
  final String pickupAddress;
  final String dropoffAddress;
  final LatLng pickupLatLng;
  final LatLng dropoffLatLng;
  final double estimatedFare;
  final double distanceToPickupMiles;
  final int etaToPickupMinutes;
  final double tripDistanceMiles;
  final int tripDurationMinutes;
  final String vehicleType;
  final String vehiclePlate;
  final DateTime requestedAt;

  const TripRequest({
    required this.tripId,
    this.riderName = 'Rider',
    this.riderPhotoUrl = '',
    this.riderRating = 5.0,
    this.pickupAddress = '',
    this.dropoffAddress = '',
    required this.pickupLatLng,
    required this.dropoffLatLng,
    this.estimatedFare = 0,
    this.distanceToPickupMiles = 0,
    this.etaToPickupMinutes = 0,
    this.tripDistanceMiles = 0,
    this.tripDurationMinutes = 0,
    this.vehicleType = '',
    this.vehiclePlate = '',
    DateTime? requestedAt,
  }) : requestedAt = requestedAt ?? const _DefaultDateTime();

  /// Time remaining before the request auto-declines (in seconds).
  int get timeoutSeconds {
    final elapsed = DateTime.now().difference(requestedAt).inSeconds;
    return (30 - elapsed).clamp(0, 30);
  }
}

/// Sentinel so const constructor works.
class _DefaultDateTime implements DateTime {
  const _DefaultDateTime();
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      DateTime.now().noSuchMethod(invocation);
}

/// Callback signatures for the driver state machine.
typedef PhaseCallback = void Function(DriverPhase phase);
typedef RequestCallback = void Function(TripRequest request);

/// Production-grade driver state machine with:
///  • Validated transitions
///  • ValueNotifier for reactive UI binding
///  • Proximity-based auto-transitions (arrivedPickup, arrivedDropoff)
///  • Request timeout timer
///  • Backend hook points
class DriverStateMachine {
  DriverStateMachine({
    this.onPhaseChanged,
    this.onRequestReceived,
    this.onRequestTimeout,
    this.arrivalRadiusMeters = 50.0,
  });

  final PhaseCallback? onPhaseChanged;
  final RequestCallback? onRequestReceived;
  final VoidCallback? onRequestTimeout;
  final double arrivalRadiusMeters;

  /// Reactive phase notifier — bind with ValueListenableBuilder.
  final ValueNotifier<DriverPhase> phaseNotifier = ValueNotifier(
    DriverPhase.offline,
  );

  DriverPhase get phase => phaseNotifier.value;

  /// Active trip request (non-null during incomingRequest and later).
  TripRequest? _activeRequest;
  TripRequest? get activeRequest => _activeRequest;

  /// Trip-level data.
  LatLng? _pickupLatLng;
  LatLng? _dropoffLatLng;
  String? _tripId;

  LatLng? get pickupLatLng => _pickupLatLng;
  LatLng? get dropoffLatLng => _dropoffLatLng;
  String? get tripId => _tripId;

  // ─── TRANSITIONS ───

  void _setPhase(DriverPhase next) {
    if (phaseNotifier.value == next) return;
    debugPrint('DriverSM: ${phaseNotifier.value.name} → ${next.name}');
    phaseNotifier.value = next;
    onPhaseChanged?.call(next);
  }

  /// Go online — start accepting rides.
  void goOnline() {
    if (phase != DriverPhase.offline) return;
    _setPhase(DriverPhase.onlineIdle);
  }

  /// Go offline — stop accepting rides.
  void goOffline() {
    if (phase == DriverPhase.offline) return;
    // Only allow going offline from idle or completed
    if (phase != DriverPhase.onlineIdle && phase != DriverPhase.completed) {
      return;
    }
    _activeRequest = null;
    _tripId = null;
    _pickupLatLng = null;
    _dropoffLatLng = null;
    _setPhase(DriverPhase.offline);
  }

  /// A trip request arrives from the backend.
  void receiveRequest(TripRequest request) {
    if (phase != DriverPhase.onlineIdle) return;
    _activeRequest = request;
    _setPhase(DriverPhase.incomingRequest);
    onRequestReceived?.call(request);
  }

  /// Driver accepts the incoming request.
  void acceptRequest() {
    if (phase != DriverPhase.incomingRequest || _activeRequest == null) return;
    _tripId = _activeRequest!.tripId;
    _pickupLatLng = _activeRequest!.pickupLatLng;
    _dropoffLatLng = _activeRequest!.dropoffLatLng;
    _setPhase(DriverPhase.toPickup);
  }

  /// Driver declines the incoming request.
  void declineRequest() {
    if (phase != DriverPhase.incomingRequest) return;
    _activeRequest = null;
    _setPhase(DriverPhase.onlineIdle);
  }

  /// Request timed out (called by UI timer).
  void requestTimedOut() {
    if (phase != DriverPhase.incomingRequest) return;
    _activeRequest = null;
    _setPhase(DriverPhase.onlineIdle);
    onRequestTimeout?.call();
  }

  /// Driver reached pickup location.
  void arriveAtPickup() {
    if (phase != DriverPhase.toPickup) return;
    _setPhase(DriverPhase.arrivedPickup);
  }

  /// Driver starts the trip (rider is in the car).
  void beginTrip() {
    if (phase != DriverPhase.arrivedPickup) return;
    _setPhase(DriverPhase.onTrip);
  }

  /// Driver reached the dropoff location.
  void arriveAtDropoff() {
    if (phase != DriverPhase.onTrip) return;
    _setPhase(DriverPhase.arrivedDropoff);
  }

  /// Trip is complete — show summary.
  void completeTrip() {
    if (phase != DriverPhase.arrivedDropoff) return;
    _setPhase(DriverPhase.completed);
  }

  /// Return to online idle (after completing a trip).
  void returnToIdle() {
    if (phase != DriverPhase.completed) return;
    _activeRequest = null;
    _tripId = null;
    _setPhase(DriverPhase.onlineIdle);
  }

  /// Full reset to offline.
  void reset() {
    _activeRequest = null;
    _tripId = null;
    _pickupLatLng = null;
    _dropoffLatLng = null;
    _setPhase(DriverPhase.offline);
  }

  // ─── PROXIMITY DETECTION ───

  /// Call on every GPS update. Auto-transitions when close enough.
  void checkProximity(LatLng driverPos) {
    if (phase == DriverPhase.toPickup && _pickupLatLng != null) {
      final dist = _haversineM(driverPos, _pickupLatLng!);
      if (dist <= arrivalRadiusMeters) {
        arriveAtPickup();
      }
    } else if (phase == DriverPhase.onTrip && _dropoffLatLng != null) {
      final dist = _haversineM(driverPos, _dropoffLatLng!);
      if (dist <= arrivalRadiusMeters) {
        arriveAtDropoff();
      }
    }
  }

  // ─── HELPERS ───

  /// Whether the driver is actively navigating (to pickup or on trip).
  bool get isNavigating =>
      phase == DriverPhase.toPickup || phase == DriverPhase.onTrip;

  /// Current destination based on phase.
  LatLng? get currentDestination {
    switch (phase) {
      case DriverPhase.toPickup:
      case DriverPhase.arrivedPickup:
        return _pickupLatLng;
      case DriverPhase.onTrip:
      case DriverPhase.arrivedDropoff:
        return _dropoffLatLng;
      default:
        return null;
    }
  }

  /// Human-readable phase label.
  String get phaseLabel {
    switch (phase) {
      case DriverPhase.offline:
        return 'Offline';
      case DriverPhase.onlineIdle:
        return 'Online';
      case DriverPhase.incomingRequest:
        return 'New Request';
      case DriverPhase.toPickup:
        return 'En Route to Pickup';
      case DriverPhase.arrivedPickup:
        return 'Arrived at Pickup';
      case DriverPhase.onTrip:
        return 'On Trip';
      case DriverPhase.arrivedDropoff:
        return 'Arrived at Destination';
      case DriverPhase.completed:
        return 'Trip Complete';
    }
  }

  void dispose() {
    phaseNotifier.dispose();
  }

  static double _haversineM(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLng = _toRad(b.longitude - a.longitude);
    final x =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(a.latitude)) *
            math.cos(_toRad(b.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return R * 2 * math.atan2(math.sqrt(x), math.sqrt(1 - x));
  }

  static double _toRad(double deg) => deg * math.pi / 180;
}
