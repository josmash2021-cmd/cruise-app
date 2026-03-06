class ApiKeys {
  /// Unrestricted key for Places Autocomplete, Place Details, Geocoding, Directions.
  /// This key must NOT have HTTP referrer restrictions (breaks mobile/server calls).
  /// In Google Cloud Console → Credentials → this key should have:
  ///   - Application restriction: None (or Android/iOS app restrictions)
  ///   - API restriction: Maps SDK, Places API, Geocoding API, Directions API
  static const String webServices = 'AIzaSyALnqq4-_jJLUCLxSJaWZGZHgw27RVE78Y';

  /// Stripe publishable key (pk_test_... or pk_live_...)
  /// Replace with your real key from https://dashboard.stripe.com/apikeys
  static const String stripePublishableKey = 'pk_test_REPLACE_WITH_YOUR_KEY';

  /// Stripe merchant identifier for Apple Pay / Google Pay
  static const String stripeMerchantId = 'merchant.com.cruise.app';
}
