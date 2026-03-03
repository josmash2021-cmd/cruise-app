import re

filepath = r"c:\Users\josma\cruise-app\lib\screens\driver\driver_online_screen.dart"

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Insert _updateNavState and _triggerReroute before "bool _nearPickupNotified"
nav_methods = '''
  /// Update turn-by-turn navigation state from GPS position.
  void _updateNavState(LatLng pos) {
    if (!_navService.isNavigating) return;
    final state = _navService.updatePosition(pos);
    if (state == null) return;

    _navState = state;

    // Update displayed instruction & distance from NavigationService
    if (state.currentInstruction.isNotEmpty) {
      _navInstruct = state.currentInstruction;
    }
    _navEta = state.etaMinutes;
    _navDist = state.distanceRemainingMiles;
    _navProgress = state.progress;

    // Off-route detection & auto-reroute
    if (state.isOffRoute && !_isRerouting) {
      final now = DateTime.now();
      final canReroute = _lastRerouteTime == null ||
          now.difference(_lastRerouteTime!).inSeconds > 10;
      if (canReroute && _rerouteCount < 5) {
        _triggerReroute(pos);
      }
    }
  }

  /// Reroute from current position to the active destination.
  Future<void> _triggerReroute(LatLng from) async {
    if (_isRerouting) return;
    _isRerouting = true;
    _lastRerouteTime = DateTime.now();
    _rerouteCount++;
    debugPrint('Rerouting (#$_rerouteCount) from ${from.latitude},${from.longitude}');
    HapticFeedback.mediumImpact();

    final dest = _phase == _Phase.enRouteToPickup ? _pickupLL : _dropoffLL;
    final routeId = _phase == _Phase.enRouteToPickup ? 'pickup' : 'trip';
    final routeColor = _phase == _Phase.enRouteToPickup ? _goldLight : _gold;

    await _drawRoute(from, dest, routeId, routeColor);
    _isRerouting = false;
  }

'''

marker1 = '  bool _nearPickupNotified = false;\n'
if marker1 in content:
    content = content.replace(marker1, nav_methods + marker1, 1)
    print("OK: Inserted _updateNavState and _triggerReroute")
else:
    print("WARN: Could not find _nearPickupNotified marker")

# 2. Insert _updateNavState(newLL) calls in the GPS handler
# After each enRouteToPickup camera animation block, after "tilt: 67.5," ... add _updateNavState

# In the enRouteToPickup block, replace the simple nav stats update with _updateNavState
# Find: "// Update nav stats" in enRouteToPickup context
# We'll insert _updateNavState(newLL); right after the camera animation in enRouteToPickup

# Find the enRouteToPickup block's nav stats section and add the call
old_pickup_nav = '''            // Update nav stats
            final dist = _hav(newLL, _pickupLL);
            final eta = (dist * 1000 / 17.88 / 60).ceil().clamp(0, 99);
            final progress = _distToPickup > 0
                ? (1.0 - dist / _distToPickup).clamp(0.0, 1.0)
                : 0.0;
            setState(() {
              _navDist = dist;
              _navEta = eta;
              _navProgress = progress;
            });'''

new_pickup_nav = '''            // Update turn-by-turn nav state
            _updateNavState(newLL);
            // Update nav stats
            final dist = _hav(newLL, _pickupLL);
            final eta = (dist * 1000 / 17.88 / 60).ceil().clamp(0, 99);
            final progress = _distToPickup > 0
                ? (1.0 - dist / _distToPickup).clamp(0.0, 1.0)
                : 0.0;
            if (!_navService.isNavigating) {
              setState(() {
                _navDist = dist;
                _navEta = eta;
                _navProgress = progress;
              });
            } else {
              setState(() {});
            }'''

count = content.count(old_pickup_nav)
if count >= 1:
    # Replace the FIRST occurrence (enRouteToPickup)
    content = content.replace(old_pickup_nav, new_pickup_nav, 1)
    print(f"OK: Updated enRouteToPickup nav stats (found {count} occurrences)")
else:
    print("WARN: Could not find enRouteToPickup nav stats block")

# Now find the inTrip block's nav stats section
old_trip_nav = '''            // Update nav stats
            final dist = _hav(newLL, _dropoffLL);
            final eta = (dist * 1000 / 17.88 / 60).ceil().clamp(0, 99);
            final progress = _tripDist > 0
                ? (1.0 - dist / _tripDist).clamp(0.0, 1.0)
                : 0.0;
            setState(() {
              _navDist = dist;
              _navEta = eta;
              _navProgress = progress;
            });'''

new_trip_nav = '''            // Update turn-by-turn nav state
            _updateNavState(newLL);
            // Update nav stats
            final dist = _hav(newLL, _dropoffLL);
            final eta = (dist * 1000 / 17.88 / 60).ceil().clamp(0, 99);
            final progress = _tripDist > 0
                ? (1.0 - dist / _tripDist).clamp(0.0, 1.0)
                : 0.0;
            if (!_navService.isNavigating) {
              setState(() {
                _navDist = dist;
                _navEta = eta;
                _navProgress = progress;
              });
            } else {
              setState(() {});
            }'''

count2 = content.count(old_trip_nav)
if count2 >= 1:
    content = content.replace(old_trip_nav, new_trip_nav, 1)
    print(f"OK: Updated inTrip nav stats (found {count2} occurrences)")
else:
    print("WARN: Could not find inTrip nav stats block")

# 3. Stop navigation on trip completion/cancellation
# In _complete() and _cancel(), add _navService.stopNavigation()
old_complete = '_stopSimulation();\n    HapticFeedback.heavyImpact();\n    _navTimer?.cancel();'
new_complete = '_stopSimulation();\n    _navService.stopNavigation();\n    _navState = null;\n    _currentNavRoute = null;\n    HapticFeedback.heavyImpact();\n    _navTimer?.cancel();'
if old_complete in content:
    content = content.replace(old_complete, new_complete, 1)
    print("OK: Added nav cleanup to _complete")
else:
    print("WARN: Could not find _complete cleanup marker")

# In _cancel
old_cancel = '    _stopSimulation();\n    _navTimer?.cancel();\n    if (_tripId != null) {'
new_cancel = '    _stopSimulation();\n    _navService.stopNavigation();\n    _navState = null;\n    _currentNavRoute = null;\n    _navTimer?.cancel();\n    if (_tripId != null) {'
if old_cancel in content:
    content = content.replace(old_cancel, new_cancel, 1)
    print("OK: Added nav cleanup to _cancel")
else:
    print("WARN: Could not find _cancel cleanup marker")

# In _decline
old_decline = '    _stopSimulation();\n    setState(() {\n      _phase = _Phase.searching;'
new_decline = '    _stopSimulation();\n    _navService.stopNavigation();\n    _navState = null;\n    _currentNavRoute = null;\n    setState(() {\n      _phase = _Phase.searching;'
if old_decline in content:
    content = content.replace(old_decline, new_decline, 1)
    print("OK: Added nav cleanup to _decline")
else:
    print("WARN: Could not find _decline cleanup marker")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("\nDone! File updated successfully.")
