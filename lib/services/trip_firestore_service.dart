import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Writes ride requests directly to the shared Firestore `trips` collection
/// so Dispatch Admin sees them in real time.
class TripFirestoreService {
  static final _db = FirebaseFirestore.instance;
  static CollectionReference get _trips => _db.collection('trips');

  /// Submit a new ride request. Returns the Firestore document ID.
  static Future<String> submitRideRequest({
    required String passengerName,
    required String passengerPhone,
    required String pickupAddress,
    required String dropoffAddress,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    required double fare,
    required double distanceKm,
    required int durationMin,
    required String vehicleType,
    String paymentMethod = 'Cash',
  }) async {
    final now = DateTime.now();
    final docRef = await _trips.add({
      'tripId': '',
      'passengerId': '',
      'passengerName': passengerName,
      'passengerPhone': passengerPhone,
      'driverId': null,
      'driverName': null,
      'driverPhone': null,
      'pickupAddress': pickupAddress,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'dropoffAddress': dropoffAddress,
      'dropoffLat': dropoffLat,
      'dropoffLng': dropoffLng,
      'status': 'requested',
      'fare': fare,
      'distance': distanceKm,
      'duration': durationMin,
      'paymentMethod': paymentMethod,
      'vehicleType': vehicleType,
      'rating': null,
      'cancelReason': null,
      'createdAt': Timestamp.fromDate(now),
      'acceptedAt': null,
      'driverArrivedAt': null,
      'startedAt': null,
      'completedAt': null,
      'cancelledAt': null,
    });

    // Back-fill the tripId field with the real Firestore ID
    await docRef.update({'tripId': docRef.id});
    debugPrint('✅ Trip submitted to Firestore: ${docRef.id}');
    return docRef.id;
  }

  /// Watch a trip's status in real time (so the passenger can see updates).
  static Stream<Map<String, dynamic>?> watchTrip(String tripId) {
    return _trips.doc(tripId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return snap.data() as Map<String, dynamic>;
    });
  }

  /// Cancel a trip from the passenger side.
  static Future<void> cancelTrip(String tripId) async {
    await _trips.doc(tripId).update({
      'status': 'cancelled',
      'cancelReason': 'Cancelled by passenger',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Real-time sync: push backend status changes to Firestore ───

  /// Assign driver info + mark trip as accepted in Firestore.
  static Future<void> syncDriverAssigned(
    String tripId, {
    required String driverName,
    String? driverPhone,
    String? driverId,
  }) async {
    try {
      await _trips.doc(tripId).update({
        'status': 'accepted',
        'driverId': driverId,
        'driverName': driverName,
        'driverPhone': driverPhone,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('🔄 Firestore synced: accepted (driver: $driverName)');
    } catch (e) {
      debugPrint('⚠️ Firestore sync (accepted) failed: $e');
    }
  }

  /// Sync status: driver arrived at pickup.
  static Future<void> syncDriverArrived(String tripId) async {
    try {
      await _trips.doc(tripId).update({
        'status': 'driver_arrived',
        'driverArrivedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('🔄 Firestore synced: driver_arrived');
    } catch (e) {
      debugPrint('⚠️ Firestore sync (driver_arrived) failed: $e');
    }
  }

  /// Sync status: trip in progress (passenger picked up).
  static Future<void> syncTripStarted(String tripId) async {
    try {
      await _trips.doc(tripId).update({
        'status': 'in_progress',
        'startedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('🔄 Firestore synced: in_progress');
    } catch (e) {
      debugPrint('⚠️ Firestore sync (in_progress) failed: $e');
    }
  }

  /// Sync status: trip completed.
  static Future<void> syncTripCompleted(String tripId) async {
    try {
      await _trips.doc(tripId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('🔄 Firestore synced: completed');
    } catch (e) {
      debugPrint('⚠️ Firestore sync (completed) failed: $e');
    }
  }

  /// Sync status: trip cancelled.
  static Future<void> syncTripCancelled(String tripId, {String reason = 'Cancelled'}) async {
    try {
      await _trips.doc(tripId).update({
        'status': 'cancelled',
        'cancelReason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      debugPrint('🔄 Firestore synced: cancelled');
    } catch (e) {
      debugPrint('⚠️ Firestore sync (cancelled) failed: $e');
    }
  }
}
