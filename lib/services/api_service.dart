import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Communicates with the Cruise Ride backend (FastAPI + PostgreSQL).
///
/// Base URL resolves to `10.0.2.2` on Android emulator (host localhost).
/// On web, dynamically uses the browser's hostname so it works from any device.
class ApiService {
  /// Local backend server URL
  /// On Android emulator: 10.0.2.2 maps to host machine's localhost
  /// On physical devices: use your computer's local IP or Cloudflare tunnel
  static const String _localUrl = 'http://10.0.2.2:8000';
  
  /// Public tunnel URL — accessible from anywhere without WiFi.
  /// Powered by Cloudflare Tunnel → routes to the backend server.
  /// UPDATE THIS URL when you start a new Cloudflare tunnel
  static const String _tunnelUrl =
      'https://warner-adware-thickness-kelkoo.trycloudflare.com';

  /// API Key — must match the server's API_KEY in .env
  /// This prevents unauthorized apps from accessing the API.
  static const String _apiKey =
      'HWB88VurhLM-1GdVML2PT92iqNSbeJ52TU1VO37MBZS6RYlyWvfIpaTdD54GT_5u';

  /// HMAC Signing Secret — cryptographically signs every request.
  /// Even if someone extracts the API key, they CANNOT forge valid
  /// requests without this secret + the timestamp + the signature.
  static const String _hmacSecret =
      'qUDmTNu1Dxxg_xo7kaUfRba4XiU_5H1ZhkUMDuVrD2dLQ2ImT8JXZ5FgUyXpSJ5h';

  static String get _baseUrl {
    // Use tunnel URL for physical devices (iPhone/Android)
    // Switch to _localUrl only when running on Android emulator
    return _tunnelUrl;
  }

  // ── Token persistence ────────────────────────────────

  static const String _tokenKey = 'cruise_jwt_token';
  static String? _cachedToken;

  static Future<void> _saveToken(String token) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_tokenKey);
    return _cachedToken;
  }

  static Future<void> clearToken() async {
    _cachedToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // ── Helpers ──────────────────────────────────────────

  static final _rng = Random.secure();

  /// Generate a random 16-char hex nonce for anti-replay uniqueness.
  static String _generateNonce() {
    final bytes = List<int>.generate(8, (_) => _rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Compute HMAC-SHA256 signature: HMAC(secret, "{apiKey}:{timestamp}:{nonce}")
  static String _computeSignature(String timestamp, String nonce) {
    final key = utf8.encode(_hmacSecret);
    final data = utf8.encode('$_apiKey:$timestamp:$nonce');
    final hmacSha256 = Hmac(sha256, key);
    return hmacSha256.convert(data).toString();
  }

  static Map<String, String> _jsonHeaders([String? token]) {
    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000)
        .toString();
    final nonce = _generateNonce();
    final signature = _computeSignature(timestamp, nonce);
    return {
      'Content-Type': 'application/json',
      'X-API-Key': _apiKey,
      'X-Timestamp': timestamp,
      'X-Nonce': nonce,
      'X-Signature': signature,
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Headers with the current JWT attached (for authenticated endpoints).
  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return _jsonHeaders(token);
  }

  /// Parse response — returns decoded JSON map.
  /// Throws [ApiException] on non-2xx.
  static Map<String, dynamic> _parse(http.Response res) {
    final body = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body is Map<String, dynamic> ? body : {'data': body};
    }
    final detail = body is Map ? body['detail'] ?? 'Unknown error' : body;
    throw ApiException(res.statusCode, detail.toString());
  }

  // ═══════════════════════════════════════════════════════
  //  AUTH  ENDPOINTS
  // ═══════════════════════════════════════════════════════

  /// Register a new account.
  /// Returns `{ access_token, token_type, user: { id, first_name, … } }`.
  static Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    String? email,
    String? phone,
    required String password,
    String? photoUrl,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/auth/register'),
          headers: _jsonHeaders(),
          body: jsonEncode({
            'first_name': firstName,
            'last_name': lastName,
            if (email != null && email.isNotEmpty) 'email': email,
            if (phone != null && phone.isNotEmpty) 'phone': phone,
            'password': password,
            // ignore: use_null_aware_elements
            if (photoUrl != null) 'photo_url': photoUrl,
          }),
        )
        .timeout(const Duration(seconds: 10));

    final data = _parse(res);

    // Persist session token
    final token = data['access_token'] as String;
    await _saveToken(token);

    debugPrint('✅ Registered user ${data['user']['id']}');
    return data;
  }

  /// Check whether an email or phone is already registered.
  /// Returns `true` if the account exists.
  static Future<bool> checkExists(String identifier) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth/check-exists'),
        headers: _jsonHeaders(),
        body: jsonEncode({'identifier': identifier.trim()}),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return body['exists'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('⚠️  checkExists failed: $e');
      return false; // Fail open — let the user continue
    }
  }

  /// Validate email-or-phone + password.
  /// Returns `{ login_token, method, email, phone }`.
  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/auth/login'),
          headers: _jsonHeaders(),
          body: jsonEncode({'identifier': identifier, 'password': password}),
        )
        .timeout(const Duration(seconds: 10));
    return _parse(res);
  }

  /// Exchange the temporary login_token for a full JWT.
  /// Call this after the verification code has been confirmed.
  /// Returns `{ access_token, token_type, user: { … } }`.
  static Future<Map<String, dynamic>> completeLogin({
    required String loginToken,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/auth/complete-login'),
          headers: _jsonHeaders(),
          body: jsonEncode({'login_token': loginToken}),
        )
        .timeout(const Duration(seconds: 10));

    final data = _parse(res);
    final token = data['access_token'] as String;
    await _saveToken(token);
    // Clear stale user cache so getCurrentUserId fetches fresh data
    _cachedUser = data['user'] as Map<String, dynamic>?;
    debugPrint('✅ Login complete — user ${data['user']['id']}');
    return data;
  }

  /// Get the current user's profile (requires valid JWT).
  /// Returns user map or `null` if the token is invalid/expired.
  static Future<Map<String, dynamic>?> getMe() async {
    final token = await getToken();
    if (token == null) return null;

    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/auth/me'), headers: _jsonHeaders(token))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return jsonDecode(res.body);
      // Only clear token on 401 (unauthorized / expired)
      if (res.statusCode == 401) {
        await clearToken();
      }
      return null;
    } catch (e) {
      // Network errors / timeouts — keep the token, user is still logged in
      debugPrint('⚠️  getMe failed (offline?): $e');
      return null;
    }
  }

  /// Update profile fields (e.g. photo_url, first_name, …).
  static Future<Map<String, dynamic>> updateMe(
    Map<String, dynamic> updates,
  ) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not logged in');

    final res = await http
        .patch(
          Uri.parse('$_baseUrl/auth/me'),
          headers: _jsonHeaders(token),
          body: jsonEncode(updates),
        )
        .timeout(const Duration(seconds: 10));
    return _parse(res);
  }

  // ═══════════════════════════════════════════════════════
  //  TRIP  ENDPOINTS
  // ═══════════════════════════════════════════════════════

  /// Rider creates a new trip request.
  /// Returns the created trip (status: requested).
  static Future<Map<String, dynamic>> createTrip({
    required int riderId,
    required String pickupAddress,
    required String dropoffAddress,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    double? fare,
    String? vehicleType,
  }) async {
    final h = await _authHeaders();
    final res = await http
        .post(
          Uri.parse('$_baseUrl/trips'),
          headers: h,
          body: jsonEncode({
            'rider_id': riderId,
            'pickup_address': pickupAddress,
            'dropoff_address': dropoffAddress,
            'pickup_lat': pickupLat,
            'pickup_lng': pickupLng,
            'dropoff_lat': dropoffLat,
            'dropoff_lng': dropoffLng,
            'fare': ?fare,
            'vehicle_type': ?vehicleType,
          }),
        )
        .timeout(const Duration(seconds: 10));
    return _parse(res);
  }

  /// Get a trip by ID (for polling status).
  static Future<Map<String, dynamic>> getTrip(int tripId) async {
    final h = await _authHeaders();
    final res = await http
        .get(Uri.parse('$_baseUrl/trips/$tripId'), headers: h)
        .timeout(const Duration(seconds: 8));
    return _parse(res);
  }

  /// Driver polls for available ride requests near their location.
  static Future<List<Map<String, dynamic>>> getAvailableTrips({
    required double lat,
    required double lng,
    double radiusKm = 15.0,
  }) async {
    final h = await _authHeaders();
    final res = await http
        .get(
          Uri.parse(
            '$_baseUrl/trips/available?lat=$lat&lng=$lng&radius_km=$radiusKm',
          ),
          headers: h,
        )
        .timeout(const Duration(seconds: 8));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final list = jsonDecode(res.body) as List;
      return list.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Driver accepts a trip request.
  static Future<Map<String, dynamic>> acceptTrip({
    required int tripId,
    required int driverId,
  }) async {
    final h = await _authHeaders();
    final res = await http
        .post(
          Uri.parse('$_baseUrl/trips/$tripId/accept'),
          headers: h,
          body: jsonEncode({'driver_id': driverId}),
        )
        .timeout(const Duration(seconds: 8));
    return _parse(res);
  }

  /// Update trip status (driver_en_route, arrived, in_trip, completed, canceled).
  static Future<Map<String, dynamic>> updateTripStatus({
    required int tripId,
    required String status,
  }) async {
    final h = await _authHeaders();
    final res = await http
        .patch(
          Uri.parse('$_baseUrl/trips/$tripId/status?status=$status'),
          headers: h,
        )
        .timeout(const Duration(seconds: 8));
    return _parse(res);
  }

  /// Update driver's location and online status.
  static Future<Map<String, dynamic>> updateDriverLocation({
    required int driverId,
    required double lat,
    required double lng,
    bool isOnline = true,
  }) async {
    final h = await _authHeaders();
    final res = await http
        .patch(
          Uri.parse('$_baseUrl/drivers/$driverId/location'),
          headers: h,
          body: jsonEncode({'lat': lat, 'lng': lng, 'is_online': isOnline}),
        )
        .timeout(const Duration(seconds: 8));
    return _parse(res);
  }

  /// Get rider's trip history.
  static Future<List<Map<String, dynamic>>> getRiderTrips(int riderId) async {
    final h = await _authHeaders();
    final res = await http
        .get(Uri.parse('$_baseUrl/riders/$riderId/trips'), headers: h)
        .timeout(const Duration(seconds: 8));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final list = jsonDecode(res.body) as List;
      return list.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Get driver's trip history.
  static Future<List<Map<String, dynamic>>> getDriverTrips(int driverId) async {
    final h = await _authHeaders();
    final res = await http
        .get(Uri.parse('$_baseUrl/drivers/$driverId/trips'), headers: h)
        .timeout(const Duration(seconds: 8));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final list = jsonDecode(res.body) as List;
      return list.cast<Map<String, dynamic>>();
    }
    return [];
  }

  // ═══════════════════════════════════════════════════════
  //  USER ID HELPERS
  // ═══════════════════════════════════════════════════════

  /// Cache for current user data.
  static Map<String, dynamic>? _cachedUser;

  /// Get the current logged-in user's ID (from cache or API).
  static Future<int?> getCurrentUserId() async {
    if (_cachedUser != null) return _cachedUser!['id'] as int?;
    final me = await getMe();
    if (me != null) {
      _cachedUser = me;
      return me['id'] as int?;
    }
    return null;
  }

  /// Get the current user profile (cached).
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    if (_cachedUser != null) return _cachedUser;
    final me = await getMe();
    if (me != null) _cachedUser = me;
    return me;
  }

  /// Clear the user cache (on logout).
  static void clearUserCache() {
    _cachedUser = null;
  }

  // ═══════════════════════════════════════════════════════
  //  DRIVER EARNINGS  ENDPOINTS
  // ═══════════════════════════════════════════════════════

  /// Get driver earnings summary for a period (today, week, month).
  static Future<Map<String, dynamic>> getDriverEarnings({
    String period = 'week',
  }) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not logged in');

    final res = await http
        .get(
          Uri.parse('$_baseUrl/drivers/earnings?period=$period'),
          headers: _jsonHeaders(token),
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    // Return empty data on error instead of crashing
    return {
      'total': 0.0,
      'trips_count': 0,
      'online_hours': 0.0,
      'tips_total': 0.0,
      'daily_earnings': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
      'day_labels': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      'transactions': [],
    };
  }

  /// Request a cashout of driver earnings.
  static Future<Map<String, dynamic>> requestCashout({
    required double amount,
  }) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not logged in');

    final res = await http
        .post(
          Uri.parse('$_baseUrl/drivers/cashout'),
          headers: _jsonHeaders(token),
          body: jsonEncode({'amount': amount}),
        )
        .timeout(const Duration(seconds: 10));
    return _parse(res);
  }

  /// Get list of driver's cashout history.
  static Future<List<Map<String, dynamic>>> getDriverCashouts() async {
    final token = await getToken();
    if (token == null) return [];

    final res = await http
        .get(
          Uri.parse('$_baseUrl/drivers/cashouts'),
          headers: _jsonHeaders(token),
        )
        .timeout(const Duration(seconds: 8));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final list = jsonDecode(res.body) as List;
      return list.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Get driver's payout methods.
  static Future<List<Map<String, dynamic>>> getPayoutMethods() async {
    final token = await getToken();
    if (token == null) return [];

    final res = await http
        .get(
          Uri.parse('$_baseUrl/drivers/payout-methods'),
          headers: _jsonHeaders(token),
        )
        .timeout(const Duration(seconds: 8));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final list = jsonDecode(res.body) as List;
      return list.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Add a payout method for the driver.
  static Future<Map<String, dynamic>> addPayoutMethod({
    required String methodType,
    required String displayName,
    bool setDefault = false,
  }) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not logged in');

    final res = await http
        .post(
          Uri.parse('$_baseUrl/drivers/payout-methods'),
          headers: _jsonHeaders(token),
          body: jsonEncode({
            'method_type': methodType,
            'display_name': displayName,
            'set_default': setDefault,
          }),
        )
        .timeout(const Duration(seconds: 10));
    return _parse(res);
  }

  /// Delete a payout method.
  static Future<void> deletePayoutMethod(int payoutId) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not logged in');

    await http
        .delete(
          Uri.parse('$_baseUrl/drivers/payout-methods/$payoutId'),
          headers: _jsonHeaders(token),
        )
        .timeout(const Duration(seconds: 8));
  }

  // ═══════════════════════════════════════════════════════
  //  PLAID BANK LINKING
  // ═══════════════════════════════════════════════════════

  /// Create a Plaid Link token (backend calls Plaid API).
  static Future<String> createPlaidLinkToken() async {
    final h = await _authHeaders();
    final res = await http
        .post(Uri.parse('$_baseUrl/plaid/create-link-token'), headers: h)
        .timeout(const Duration(seconds: 15));
    final data = _parse(res);
    return data['link_token'] as String;
  }

  /// Exchange Plaid public token for access token and save linked account.
  static Future<Map<String, dynamic>> exchangePlaidPublicToken({
    required String publicToken,
    String? accountId,
    String? institutionName,
    String? accountMask,
    String? accountSubtype,
  }) async {
    final h = await _authHeaders();
    final res = await http
        .post(
          Uri.parse('$_baseUrl/plaid/exchange-token'),
          headers: h,
          body: jsonEncode({
            'public_token': publicToken,
            'account_id': accountId,
            'institution_name': institutionName ?? 'Bank',
            'account_mask': accountMask ?? '',
            'account_subtype': accountSubtype ?? 'checking',
          }),
        )
        .timeout(const Duration(seconds: 15));
    return _parse(res);
  }

  // ═══════════════════════════════════════════════════════
  //  RIDE DISPATCH — Uber-style cascading driver assignment
  // ═══════════════════════════════════════════════════════

  /// Rider creates a ride and the system auto-dispatches to closest driver.
  static Future<Map<String, dynamic>> dispatchRideRequest({
    required int riderId,
    required String pickupAddress,
    required String dropoffAddress,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    double? fare,
    String? vehicleType,
  }) async {
    final h = await _authHeaders();
    final res = await http
        .post(
          Uri.parse('$_baseUrl/dispatch/request'),
          headers: h,
          body: jsonEncode({
            'rider_id': riderId,
            'pickup_address': pickupAddress,
            'dropoff_address': dropoffAddress,
            'pickup_lat': pickupLat,
            'pickup_lng': pickupLng,
            'dropoff_lat': dropoffLat,
            'dropoff_lng': dropoffLng,
            'fare': ?fare,
            'vehicle_type': ?vehicleType,
          }),
        )
        .timeout(const Duration(seconds: 10));
    return _parse(res);
  }

  /// Driver polls for their pending ride offers (returns a LIST now).
  static Future<List<Map<String, dynamic>>> getDriverPendingOffers(
    int driverId,
  ) async {
    final h = await _authHeaders();
    final res = await http
        .get(
          Uri.parse('$_baseUrl/dispatch/driver/pending?driver_id=$driverId'),
          headers: h,
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body);
      if (body is List) {
        return body.cast<Map<String, dynamic>>();
      }
      // Legacy: if backend returns a single map, wrap it
      if (body is Map<String, dynamic> && body.isNotEmpty) {
        return [body];
      }
    }
    return [];
  }

  /// Driver accepts a ride offer.
  static Future<Map<String, dynamic>> acceptRideOffer({
    required int offerId,
    required int driverId,
  }) async {
    final h = await _authHeaders();
    final res = await http
        .post(
          Uri.parse(
            '$_baseUrl/dispatch/driver/accept?offer_id=$offerId&driver_id=$driverId',
          ),
          headers: h,
        )
        .timeout(const Duration(seconds: 8));
    return _parse(res);
  }

  /// Driver rejects a ride offer (cascades to next driver).
  static Future<Map<String, dynamic>> rejectRideOffer({
    required int offerId,
    required int driverId,
  }) async {
    final h = await _authHeaders();
    final res = await http
        .post(
          Uri.parse(
            '$_baseUrl/dispatch/driver/reject?offer_id=$offerId&driver_id=$driverId',
          ),
          headers: h,
        )
        .timeout(const Duration(seconds: 8));
    return _parse(res);
  }

  /// Rider polls dispatch status to see if a driver accepted.
  static Future<Map<String, dynamic>> getDispatchStatus(int tripId) async {
    final h = await _authHeaders();
    final res = await http
        .get(
          Uri.parse('$_baseUrl/dispatch/trip/status?trip_id=$tripId'),
          headers: h,
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    return {'status': 'error'};
  }

  /// Get a route from Google Directions API (or OSRM fallback).
  /// Returns a list of LatLng points for the route polyline, or null on failure.
  static Future<Map<String, dynamic>?> getDirectionsRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    // Try Google Directions API
    try {
      final uri =
          Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
            'origin': '$originLat,$originLng',
            'destination': '$destLat,$destLng',
            'key': 'AIzaSyALnqq4-_jJLUCLxSJaWZGZHgw27RVE78Y',
            'mode': 'driving',
          });
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'OK' && (data['routes'] as List).isNotEmpty) {
          return data as Map<String, dynamic>;
        }
      }
    } catch (_) {}

    // Fallback: OSRM
    try {
      final path = '/route/v1/driving/$originLng,$originLat;$destLng,$destLat';
      final uri = Uri.https('router.project-osrm.org', path, {
        'overview': 'full',
        'geometries': 'polyline',
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);
      if (data is Map<String, dynamic> &&
          data['code']?.toString().toUpperCase() == 'OK') {
        return {'source': 'osrm', ...data};
      }
    } catch (_) {}

    return null;
  }
  /// Check if any drivers are online near a given location.
  /// Returns the count of online drivers. Falls back to 0 on error.
  static Future<int> getNearbyDriversCount({
    required double lat,
    required double lng,
    double radiusKm = 15.0,
  }) async {
    try {
      final h = await _authHeaders();
      final res = await http
          .get(
            Uri.parse('$_baseUrl/drivers/nearby?lat=$lat&lng=$lng&radius_km=$radiusKm'),
            headers: h,
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = jsonDecode(res.body);
        if (body is List) return body.length;
        if (body is Map && body.containsKey('count')) return body['count'] as int;
        return 0;
      }
    } catch (_) {}
    return 0;
  }
}

/// Simple exception with HTTP status code.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
