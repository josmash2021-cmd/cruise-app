$filePath = "c:\Users\josma\cruise-app\lib\screens\driver\driver_online_screen.dart"
$content = [System.IO.File]::ReadAllText($filePath, [System.Text.Encoding]::UTF8)

# 1. Insert _updateNavState and _triggerReroute before "bool _nearPickupNotified"
$navMethods = @"
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
    debugPrint('Rerouting (#`$_rerouteCount)');
    HapticFeedback.mediumImpact();

    final dest = _phase == _Phase.enRouteToPickup ? _pickupLL : _dropoffLL;
    final routeId = _phase == _Phase.enRouteToPickup ? 'pickup' : 'trip';
    final routeColor = _phase == _Phase.enRouteToPickup ? _goldLight : _gold;

    await _drawRoute(from, dest, routeId, routeColor);
    _isRerouting = false;
  }

"@

$marker1 = "  bool _nearPickupNotified = false;"
$content = $content.Replace($marker1, $navMethods + "`n" + $marker1)
Write-Host "Step 1: Inserted _updateNavState methods"

# 2. Add _updateNavState call in enRouteToPickup GPS handler
# Find first occurrence of "_navProgress = progress;" followed by closing brace in the GPS stream handler
$old1 = "            // Update nav stats" + "`n" + "            final dist = _hav(newLL, _pickupLL);"
$new1 = "            // Update turn-by-turn nav state" + "`n" + "            _updateNavState(newLL);" + "`n" + "            // Update nav stats" + "`n" + "            final dist = _hav(newLL, _pickupLL);"

$idx1 = $content.IndexOf($old1)
if ($idx1 -ge 0) {
    $content = $content.Remove($idx1, $old1.Length).Insert($idx1, $new1)
    Write-Host "Step 2: Added _updateNavState to enRouteToPickup"
} else {
    Write-Host "Step 2: SKIP - marker not found for enRouteToPickup"
}

# 3. Add _updateNavState call in inTrip GPS handler
$old2 = "            // Update nav stats" + "`n" + "            final dist = _hav(newLL, _dropoffLL);"
$new2 = "            // Update turn-by-turn nav state" + "`n" + "            _updateNavState(newLL);" + "`n" + "            // Update nav stats" + "`n" + "            final dist = _hav(newLL, _dropoffLL);"

$idx2 = $content.IndexOf($old2)
if ($idx2 -ge 0) {
    $content = $content.Remove($idx2, $old2.Length).Insert($idx2, $new2)
    Write-Host "Step 3: Added _updateNavState to inTrip" 
} else {
    Write-Host "Step 3: SKIP - marker not found for inTrip"
}

# 4. Cleanup nav on complete
$old3 = "    _stopSimulation();" + "`n" + "    HapticFeedback.heavyImpact();" + "`n" + "    _navTimer?.cancel();"
$new3 = "    _stopSimulation();" + "`n" + "    _navService.stopNavigation();" + "`n" + "    _navState = null;" + "`n" + "    _currentNavRoute = null;" + "`n" + "    HapticFeedback.heavyImpact();" + "`n" + "    _navTimer?.cancel();"

$idx3 = $content.IndexOf($old3)
if ($idx3 -ge 0) {
    $content = $content.Remove($idx3, $old3.Length).Insert($idx3, $new3)
    Write-Host "Step 4: Added nav cleanup to _complete"
} else {
    Write-Host "Step 4: SKIP - _complete marker not found"
}

# 5. Cleanup nav on cancel
$old4 = "    _stopSimulation();" + "`n" + "    _navTimer?.cancel();" + "`n" + "    if (_tripId != null) {"
$new4 = "    _stopSimulation();" + "`n" + "    _navService.stopNavigation();" + "`n" + "    _navState = null;" + "`n" + "    _currentNavRoute = null;" + "`n" + "    _navTimer?.cancel();" + "`n" + "    if (_tripId != null) {"

$idx4 = $content.IndexOf($old4)
if ($idx4 -ge 0) {
    $content = $content.Remove($idx4, $old4.Length).Insert($idx4, $new4)
    Write-Host "Step 5: Added nav cleanup to _cancel"
} else {
    Write-Host "Step 5: SKIP - _cancel marker not found"
}

# Write the file
[System.IO.File]::WriteAllText($filePath, $content, [System.Text.Encoding]::UTF8)
Write-Host "`nAll patches applied successfully!"
