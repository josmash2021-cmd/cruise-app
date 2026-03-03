import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../config/api_keys.dart';
import '../services/directions_service.dart';
import '../services/navigation_service.dart';

/// Fetches route polylines from the Directions API and wraps them
/// in [NavRoute] for turn-by-turn details.
///
/// Uses the existing [DirectionsService] under the hood.
class RouteService {
  RouteService._();

  static final _dirs = DirectionsService(ApiKeys.webServices);

  /// Fetch a full [NavRoute] with turn-by-turn steps.
  /// Returns `null` on network failure or bad status.
  static Future<NavRoute?> fetchNavRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final raw = await _dirs.getRawDirectionsResponse(
        origin: origin,
        destination: destination,
      );
      if (raw == null) return null;
      return NavigationService.fromDirectionsResponse(raw);
    } catch (e) {
      // ignore – caller should handle null
      return null;
    }
  }

  /// Fetch a simple polyline + metadata (lighter weight than NavRoute).
  static Future<RouteResult?> fetchPolyline({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      return await _dirs.getRoute(origin: origin, destination: destination);
    } catch (_) {
      return null;
    }
  }
}
