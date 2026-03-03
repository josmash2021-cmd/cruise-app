import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Trip lifecycle phases shared by both customer and driver screens.
enum TripPhase {
  idle,
  toPickup,
  arrivedPickup,
  onTrip,
  arrivedDropoff,
  completed,
}

/// Driver-side navigation state machine.
///
/// Manages the trip lifecycle:
///   IDLE → TO_PICKUP → ARRIVED_PICKUP → ON_TRIP → ARRIVED_DROPOFF → COMPLETED
///
/// Emits phase changes via [phaseNotifier] so the UI can react.
class NavStateMachine {
  NavStateMachine({
    this.arrivalRadiusMeters = 80,
    this.onPhaseChanged,
    this.onBackendUpdate,
  });

  /// How close (metres) the driver must be to auto-detect arrival.
  final double arrivalRadiusMeters;

  /// Optional callback when the phase changes.
  final void Function(TripPhase phase)? onPhaseChanged;

  /// Stub callback for backend status updates.
  /// Implementations should call their API here.
  final Future<void> Function(TripPhase phase, String tripId)? onBackendUpdate;

  // ─── state ───
  final ValueNotifier<TripPhase> phaseNotifier = ValueNotifier(TripPhase.idle);

  TripPhase get phase => phaseNotifier.value;

  String? _tripId;
  String? get tripId => _tripId;

  LatLng _pickupLL = const LatLng(0, 0);
  LatLng _dropoffLL = const LatLng(0, 0);

  LatLng get pickupLL => _pickupLL;
  LatLng get dropoffLL => _dropoffLL;

  // ─── actions ───

  /// Start a new trip. Moves from IDLE → TO_PICKUP.
  void startTrip({
    required String tripId,
    required LatLng pickup,
    required LatLng dropoff,
  }) {
    _tripId = tripId;
    _pickupLL = pickup;
    _dropoffLL = dropoff;
    _setPhase(TripPhase.toPickup);
  }

  /// Driver taps "ARRIVED" at pickup.
  void arriveAtPickup() {
    if (phase != TripPhase.toPickup) return;
    _setPhase(TripPhase.arrivedPickup);
  }

  /// Driver taps "START TRIP" after rider boards.
  void beginTrip() {
    if (phase != TripPhase.arrivedPickup) return;
    _setPhase(TripPhase.onTrip);
  }

  /// Driver taps "END TRIP" at destination.
  void arriveAtDropoff() {
    if (phase != TripPhase.onTrip) return;
    _setPhase(TripPhase.arrivedDropoff);
  }

  /// Driver taps "FINISH RIDE" — trip complete.
  void completeTrip() {
    if (phase != TripPhase.arrivedDropoff) return;
    _setPhase(TripPhase.completed);
  }

  /// Reset to IDLE for a new trip.
  void reset() {
    _tripId = null;
    _setPhase(TripPhase.idle);
  }

  /// Call on each position update to auto-detect proximity arrival.
  void checkProximity(LatLng driverPos) {
    if (phase == TripPhase.toPickup) {
      if (_distM(driverPos, _pickupLL) <= arrivalRadiusMeters) {
        _setPhase(TripPhase.arrivedPickup);
      }
    } else if (phase == TripPhase.onTrip) {
      if (_distM(driverPos, _dropoffLL) <= arrivalRadiusMeters) {
        _setPhase(TripPhase.arrivedDropoff);
      }
    }
  }

  /// Forcefully set a phase (for testing / external triggers).
  void forcePhase(TripPhase p) => _setPhase(p);

  /// Advance phase, notify listeners, call backend stub.
  void _setPhase(TripPhase p) {
    phaseNotifier.value = p;
    onPhaseChanged?.call(p);
    if (_tripId != null) {
      _notifyBackend(p, _tripId!);
    }
  }

  // ────────────────────────────────────────────────
  //  BACKEND STUBS – replace with real API calls
  // ────────────────────────────────────────────────

  Future<void> _notifyBackend(TripPhase phase, String tripId) async {
    if (onBackendUpdate != null) {
      await onBackendUpdate!(phase, tripId);
      return;
    }
    // Default stub: just log
    debugPrint('🔔 NavStateMachine: phase=$phase tripId=$tripId (stub)');
    // TODO: Replace with real API calls, e.g.:
    // await ApiService.updateTripStatus(tripId: tripId, status: phase.name);
  }

  // ─── haversine helper ───

  static double _distM(LatLng a, LatLng b) {
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

  static double _r(double d) => d * math.pi / 180;

  void dispose() {
    phaseNotifier.dispose();
  }
}
