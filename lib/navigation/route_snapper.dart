import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Snaps a GPS coordinate to the nearest point on a polyline,
/// biased forward so the car never jumps backwards along the route.
class RouteSnapper {
  RouteSnapper._();

  /// Snap [raw] to the closest point on [polyline].
  ///
  /// * [maxSnapMeters] — if the nearest point is farther than this, the
  ///   raw coordinate is returned as-is (driver is off-route).
  /// * [lastIndex] — optional hint: the polyline segment index the car was
  ///   on last frame. The search starts here and prefers forward segments
  ///   to prevent backward snapping.
  /// * [lookaheadSegments] — how many segments ahead of [lastIndex] to
  ///   prioritise before falling back to a full search (default 15).
  static SnapResult snap(
    LatLng raw,
    List<LatLng> polyline, {
    double maxSnapMeters = 50,
    int lastIndex = 0,
    int lookaheadSegments = 15,
  }) {
    if (polyline.length < 2) {
      return SnapResult(
        snapped: raw,
        segmentIndex: 0,
        distanceMeters: 0,
        isOnRoute: true,
        bearingDeg: 0,
        distanceAlongRouteMeters: 0,
      );
    }

    double bestDist = double.infinity;
    LatLng bestPt = raw;
    int bestIdx = lastIndex.clamp(0, polyline.length - 2);

    // ── Pass 1: forward lookahead from lastIndex ──
    final fwdEnd = (lastIndex + lookaheadSegments).clamp(
      0,
      polyline.length - 1,
    );
    for (int i = lastIndex.clamp(0, polyline.length - 2); i < fwdEnd; i++) {
      final proj = _closestPointOnSegment(raw, polyline[i], polyline[i + 1]);
      final d = _haversineM(raw, proj);
      // Forward pass gets a small preference (subtract 2 m from distance)
      if (d - 2.0 < bestDist) {
        bestDist = d;
        bestPt = proj;
        bestIdx = i;
      }
    }

    // ── Pass 2: full fallback if nothing close found ──
    if (bestDist > maxSnapMeters * 0.6) {
      for (int i = 0; i < polyline.length - 1; i++) {
        if (i >= lastIndex && i < fwdEnd) continue; // already checked
        final proj = _closestPointOnSegment(raw, polyline[i], polyline[i + 1]);
        final d = _haversineM(raw, proj);
        if (d < bestDist) {
          bestDist = d;
          bestPt = proj;
          bestIdx = i;
        }
      }
    }

    final onRoute = bestDist <= maxSnapMeters;
    final snapped = onRoute ? bestPt : raw;

    // Bearing along the segment at the snap point
    final bearing = _bearingDeg(
      polyline[bestIdx],
      polyline[(bestIdx + 1).clamp(0, polyline.length - 1)],
    );

    // Cumulative distance from start of route to snap point
    double along = 0;
    for (int i = 0; i < bestIdx; i++) {
      along += _haversineM(polyline[i], polyline[i + 1]);
    }
    along += _haversineM(polyline[bestIdx], snapped);

    return SnapResult(
      snapped: snapped,
      segmentIndex: bestIdx,
      distanceMeters: bestDist,
      isOnRoute: onRoute,
      bearingDeg: bearing,
      distanceAlongRouteMeters: along,
    );
  }

  /// Total length of [polyline] in metres.
  static double totalRouteMeters(List<LatLng> polyline) {
    double total = 0;
    for (int i = 0; i < polyline.length - 1; i++) {
      total += _haversineM(polyline[i], polyline[i + 1]);
    }
    return total;
  }

  /// Remaining route distance from segment [segIdx] + [snapped] to end.
  static double remainingMeters(
    LatLng snapped,
    int segIdx,
    List<LatLng> polyline,
  ) {
    if (polyline.length < 2) return 0;
    final clampedIdx = segIdx.clamp(0, polyline.length - 2);
    double rem = _haversineM(snapped, polyline[clampedIdx + 1]);
    for (int i = clampedIdx + 1; i < polyline.length - 1; i++) {
      rem += _haversineM(polyline[i], polyline[i + 1]);
    }
    return rem;
  }

  /// Project point [p] onto segment [a]→[b] (clamped).
  static LatLng _closestPointOnSegment(LatLng p, LatLng a, LatLng b) {
    final dx = b.latitude - a.latitude;
    final dy = b.longitude - a.longitude;
    if (dx == 0 && dy == 0) return a;
    final t =
        ((p.latitude - a.latitude) * dx + (p.longitude - a.longitude) * dy) /
        (dx * dx + dy * dy);
    final tc = t.clamp(0.0, 1.0);
    return LatLng(a.latitude + dx * tc, a.longitude + dy * tc);
  }

  static double _haversineM(LatLng a, LatLng b) {
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

  /// Bearing from [a] to [b] in degrees (0 = north, 90 = east).
  static double _bearingDeg(LatLng a, LatLng b) {
    final dLng = _r(b.longitude - a.longitude);
    final y = math.sin(dLng) * math.cos(_r(b.latitude));
    final x =
        math.cos(_r(a.latitude)) * math.sin(_r(b.latitude)) -
        math.sin(_r(a.latitude)) * math.cos(_r(b.latitude)) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  static double _r(double d) => d * math.pi / 180;
}

/// Result of a snap operation.
class SnapResult {
  /// The snapped position (or the raw position if off-route).
  final LatLng snapped;

  /// The polyline segment index closest to the driver.
  final int segmentIndex;

  /// Distance from the raw GPS to the nearest route point, in metres.
  final double distanceMeters;

  /// Whether the GPS was within snap radius of the route.
  final bool isOnRoute;

  /// Bearing along the route at the snap point (degrees, 0 = north).
  final double bearingDeg;

  /// Cumulative distance along the route from start to this snap point.
  final double distanceAlongRouteMeters;

  const SnapResult({
    required this.snapped,
    required this.segmentIndex,
    required this.distanceMeters,
    required this.isOnRoute,
    this.bearingDeg = 0,
    this.distanceAlongRouteMeters = 0,
  });
}
