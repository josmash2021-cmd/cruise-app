class ApiKeys {
  /// Unrestricted key for Places Autocomplete, Place Details, Geocoding, Directions.
  /// This key must NOT have HTTP referrer restrictions (breaks mobile/server calls).
  /// In Google Cloud Console → Credentials → this key should have:
  ///   - Application restriction: None (or Android/iOS app restrictions)
  ///   - API restriction: Maps SDK, Places API, Geocoding API, Directions API
  static const String webServices = 'AIzaSyALnqq4-_jJLUCLxSJaWZGZHgw27RVE78Y';
}
