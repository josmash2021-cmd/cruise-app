import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Provides 60 fps interpolation between GPS updates so the car marker
/// moves smoothly instead of jumping.
///
/// Features:
///  • Exponential lerp with frame-rate-independent dt
///  • Velocity-based prediction to extrapolate between GPS gaps
///  • Dead-reckoning for up to 2 s without a GPS fix
///  • Shortest-arc bearing interpolation
///  • Speed-adaptive lerp (faster convergence at low speed)
///
/// Usage:
/// ```dart
/// final motion = SmoothMotion(onTick: (pos, bearing) {
///   setState(() { _pos = pos; _bearing = bearing; });
/// });
/// motion.start(this);
/// // On each GPS update:
/// motion.pushTarget(newLatLng, newBearing);
/// // Cleanup:
/// motion.dispose();
/// ```
class SmoothMotion {
  SmoothMotion({
    required this.onTick,
    this.lerpFactor = 0.15,
    this.bearingLerpFactor = 0.18,
    this.enablePrediction = true,
  });

  /// Called every frame with the interpolated position and bearing.
  final void Function(LatLng position, double bearing) onTick;

  /// How much to lerp per frame (0..1). Higher = faster catch-up.
  final double lerpFactor;

  /// Bearing-specific lerp factor.
  final double bearingLerpFactor;

  /// Whether to extrapolate position using velocity when GPS gaps occur.
  final bool enablePrediction;

  Ticker? _ticker;

  LatLng _current = const LatLng(0, 0);
  double _currentBearing = 0;

  LatLng _target = const LatLng(0, 0);
  double _targetBearing = 0;

  bool _hasInitial = false;

  // ─── Prediction / velocity estimation ───
  LatLng? _prevTarget;
  DateTime? _prevTargetTime;
  double _velocityLat = 0; // degrees per second
  double _velocityLng = 0;
  DateTime? _lastFrameTime;

  /// Max dead-reckoning duration before we stop extrapolating (ms).
  static const int _maxPredictionMs = 2000;

  /// Speed threshold in m/s below which we use higher lerp for snappier stop.
  static const double _lowSpeedThreshold = 2.0;

  /// Current interpolated position.
  LatLng get position => _current;

  /// Current interpolated bearing.
  double get bearing => _currentBearing;

  /// Estimated speed in m/s based on recent GPS deltas.
  double get estimatedSpeedMps {
    final vLat = _velocityLat * 111320; // rough degrees→meters
    final vLng = _velocityLng * 111320 * math.cos(_toRad(_current.latitude));
    return math.sqrt(vLat * vLat + vLng * vLng);
  }

  /// Start the ticker. Call once. Requires a [TickerProvider] (mixin).
  void start(TickerProvider vsync) {
    _ticker?.dispose();
    _ticker = vsync.createTicker(_onFrame);
    _ticker!.start();
    _lastFrameTime = DateTime.now();
  }

  /// Push a new GPS target. The interpolator will smoothly converge to it.
  void pushTarget(LatLng position, [double? bearing]) {
    if (!_hasInitial) {
      _current = position;
      _target = position;
      _currentBearing = bearing ?? 0;
      _targetBearing = _currentBearing;
      _hasInitial = true;
      _prevTarget = position;
      _prevTargetTime = DateTime.now();
      return;
    }

    // Estimate velocity from consecutive targets
    final now = DateTime.now();
    if (_prevTarget != null && _prevTargetTime != null) {
      final dtSec = now.difference(_prevTargetTime!).inMilliseconds / 1000.0;
      if (dtSec > 0.05) {
        // Smooth velocity with EMA (exponential moving average)
        final newVLat = (position.latitude - _prevTarget!.latitude) / dtSec;
        final newVLng = (position.longitude - _prevTarget!.longitude) / dtSec;
        _velocityLat = _velocityLat * 0.6 + newVLat * 0.4;
        _velocityLng = _velocityLng * 0.6 + newVLng * 0.4;
      }
    }
    _prevTarget = position;
    _prevTargetTime = now;

    _target = position;
    if (bearing != null) _targetBearing = bearing;
  }

  /// Immediately teleport to a position (no lerp).
  void teleport(LatLng position, double bearing) {
    _current = position;
    _target = position;
    _currentBearing = bearing;
    _targetBearing = bearing;
    _hasInitial = true;
    _velocityLat = 0;
    _velocityLng = 0;
    _prevTarget = position;
    _prevTargetTime = DateTime.now();
  }

  void dispose() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
  }

  // ─── internals ───

  void _onFrame(Duration _) {
    if (!_hasInitial) return;

    final now = DateTime.now();
    final dtMs = _lastFrameTime != null
        ? now.difference(_lastFrameTime!).inMilliseconds
        : 16;
    _lastFrameTime = now;

    // Frame-rate-independent lerp: factor = 1 - (1 - baseFactor)^(dt/16.67)
    final frames = dtMs / 16.667;
    final posLerp = 1.0 - math.pow(1.0 - lerpFactor, frames);
    final bearLerp = 1.0 - math.pow(1.0 - bearingLerpFactor, frames);

    // Speed-adaptive: at very low speed, use higher lerp for snappier stop
    final speed = estimatedSpeedMps;
    final adaptivePosLerp = speed < _lowSpeedThreshold
        ? math.min(posLerp * 1.8, 0.5)
        : posLerp;

    // Prediction: if GPS is stale, extrapolate target forward
    LatLng effectiveTarget = _target;
    if (enablePrediction && _prevTargetTime != null) {
      final staleness = now.difference(_prevTargetTime!).inMilliseconds;
      if (staleness > 200 && staleness < _maxPredictionMs && speed > 1.0) {
        // Dead-reckoning: extend target by velocity × staleness
        final extSec = staleness / 1000.0;
        effectiveTarget = LatLng(
          _target.latitude + _velocityLat * extSec * 0.5,
          _target.longitude + _velocityLng * extSec * 0.5,
        );
      }
    }

    // Lerp position
    final lat =
        _current.latitude +
        (effectiveTarget.latitude - _current.latitude) * adaptivePosLerp;
    final lng =
        _current.longitude +
        (effectiveTarget.longitude - _current.longitude) * adaptivePosLerp;
    _current = LatLng(lat, lng);

    // Shortest-angle bearing lerp
    _currentBearing = _lerpAngle(_currentBearing, _targetBearing, bearLerp);

    onTick(_current, _currentBearing);
  }

  /// Lerp between two angles using shortest-arc path.
  static double _lerpAngle(double from, double to, double t) {
    double diff = (to - from) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return (from + diff * t) % 360;
  }

  /// Compute bearing from [a] to [b] in degrees (0–360).
  static double computeBearing(LatLng a, LatLng b) {
    final dLng = _toRad(b.longitude - a.longitude);
    final lat1 = _toRad(a.latitude);
    final lat2 = _toRad(b.latitude);
    final y = math.sin(dLng) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (_toDeg(math.atan2(y, x)) + 360) % 360;
  }

  static double _toRad(double d) => d * math.pi / 180;
  static double _toDeg(double r) => r * 180 / math.pi;
}
