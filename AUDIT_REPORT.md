# Cruise App — Comprehensive Audit Report

**Date:** 2025-07-14
**Codebase:** `lib/` — ~72,000 lines across ~103 Dart files
**Stack:** Flutter + FastAPI + PostgreSQL + Firebase + Stripe + Google Maps/Apple Maps

---

## Summary

| Severity | Count |
|----------|-------|
| CRITICAL | 3 |
| HIGH | 9 |
| MEDIUM | 10 |
| LOW | 8 |
| **Total** | **30** |

---

## CRITICAL Issues

### C-1 · Client-Side Verification Code Generation (SECURITY)
**File:** `lib/screens/login_screen.dart` · **Lines:** 76–85, 112, 132
**Description:** During email signup, the 6-digit verification code is generated **client-side** via `_generateCode()` using `Random()` (not even `Random.secure()`), then passed as `expectedCode` to `VerifyCodeScreen`. The comparison happens entirely on the device — an attacker with a modified APK can bypass the verification. For phone/SMS (Twilio trial accounts), a fallback also uses a local code (line 178–187).
**Fix:** Generate and validate verification codes **server-side only**. The client should never know the expected code. Use `ApiService` to request a code, let the backend send it via email/SMS, then submit the entered code to the backend for verification.

---

### C-2 · Support Chat via `ChatScreen(isSupport: true)` Is a Dead End
**File:** `lib/screens/rider_tracking_screen.dart` · **Line:** 1400–1403
**File:** `lib/screens/chat_screen.dart` · **Lines:** 56–62, 104–108
**Description:** The "Contact Support" button on the rider tracking screen opens `ChatScreen(isSupport: true)`. In this mode, the screen only displays a static welcome message and has no `tripId`. When the user sends a message, `_sendMessage()` adds it to the local list but never calls any API — the messages go **nowhere**. This is distinct from `CruiseSupportChatScreen` (used in help_screen.dart) which properly connects to the backend AI agent.
**Fix:** Replace the `ChatScreen(isSupport: true)` usage in `rider_tracking_screen.dart` line 1400 with `CruiseSupportChatScreen()`, or pass the `tripId` so messages are routed to the trip's support thread.

---

### C-3 · Corrupted Emoji in Ride Option Icons
**File:** `lib/state/rider_trip_controller.dart` · **Lines:** 277, 296
**Description:** The `icon` field for Suburban and Fusion ride options contains the Unicode replacement character U+FFFD (`�`) instead of valid emoji. Bytes `EF BF BD` confirm the original emoji was irreversibly corrupted. The Camry icon (`🚙`) is fine. These broken characters will render as `�` squares in the ride selection UI.
**Fix:** Replace the corrupted values with the intended emoji. Likely `'🚐'` for Suburban and `'🚗'` for Fusion, or use asset-based icons instead.

---

## HIGH Issues

### H-1 · 11 Unused Local Variables in Home Screen Build Method
**File:** `lib/screens/home_screen.dart` · **Lines:** 743–763
**Description:** Eleven theme-related variables (`textMain`, `textSub`, `textMuted`, `textFaint`, `surface`, `cardBg`, `cardBorder`, `iconMuted`, `iconFaint`, `glassColor`, `glassBorder`) are declared at the top of `build()` with `// ignore: unused_local_variable` directives. These are dead code that clutters the build method and bloats the widget rebuild.
**Fix:** Remove all unused variables and their ignore directives. Use `AppColors.of(context)` or compute inline where needed.

---

### H-2 · Safety Features "Ride Check" and "Audio Recording" Show "Coming Soon"
**File:** `lib/screens/safety_screen.dart` · **Lines:** 134, 142, 669–672
**Description:** Two user-facing safety features show a dialog saying "Coming soon" when tapped, with no implementation behind them. These are visible in the safety settings and mislead users into thinking safety features are available.
**Fix:** Either implement the features or hide them until ready. Consider removing the UI entries and adding a feature flag. "Coming soon" dialogs should not be in production safety features.

---

### H-3 · Unused Fields in `rider_tracking_screen.dart`
**File:** `lib/screens/rider_tracking_screen.dart`
- **Line 86:** `final bool _arrivedNotifSent = false;` — declared `final` so it can **never be set to true**. It appears intended to gate "driver arrived" notifications but is completely non-functional (dead code).
- **Line 114:** `final double _tgtBrg = 0;` — declared but never read or written.
**Fix:** Remove both fields. The notification gating logic for driver arrival should use the `_phase` state machine instead (which already handles this correctly).

---

### H-4 · 143 Silent `catch (_) {}` Blocks Across the Codebase
**Files:** Distributed across all `lib/` files
**Description:** There are 143 instances of `catch (_) {}` or `catch (_) { }` that silently swallow errors with no logging, user feedback, or retry logic. While some are intentional fire-and-forget calls, many mask real failures (network errors, parsing errors, permission issues).
**Fix:** Audit each `catch` block. At minimum, add `debugPrint` logging. For user-affecting operations (save profile, send message, submit rating), surface errors via SnackBar or retry logic. Keep silent catches only for truly optional/best-effort operations.

---

### H-5 · Edit Profile Backend Sync Failure Silently Swallowed
**File:** `lib/screens/edit_profile_screen.dart`
**Description:** When `ApiService.updateMe()` fails during profile save, the error is caught silently with `debugPrint`. The user sees a success confirmation even though their data wasn't synced to the server. On next login from another device, they'll see old data.
**Fix:** Show a warning SnackBar: "Profile saved locally but couldn't sync. Will retry automatically." Consider implementing a queue for failed syncs.

---

### H-6 · Ride Rating Submission Failure Silently Swallowed
**File:** `lib/screens/ride_rating_screen.dart` · **Line:** 82
**Description:** `await ApiService.rateTrip(...)` is wrapped in `catch (_) {}` — if the rating fails to submit, the user isn't notified. The screen pops with the rating result as if it succeeded, but the driver never receives the rating or tip.
**Fix:** On failure, show a retry dialog or queue the rating for later submission.

---

### H-7 · Unused Fields in `driver_online_screen.dart`
**File:** `lib/screens/driver/driver_online_screen.dart`
- **Line 135:** `int _etaToPickup = 0; // ignore: unused_field`
- **Line 137:** `int _tripEta = 0; // ignore: unused_field`
- **Line 183:** `late Animation<Offset> _reqSlide; // ignore: unused_field`
- **Line 3950:** `const cCardBg = ...; // ignore: unused_local_variable`
**Fix:** Remove all unused fields and their ignore directives. `late` unused fields with no initializer can cause `LateInitializationError` if accidentally accessed.

---

### H-8 · Home Screen Greeting Not Localized
**File:** `lib/screens/home_screen.dart` · **Lines:** 1230–1232
**Description:** `_getGreeting()` returns hardcoded English strings ("Good morning", "Good afternoon", "Good evening") despite localization strings existing in `app_localizations.dart` (`goodMorning`, `goodAfternoon`, `goodEvening`).
**Fix:** Replace with `S.of(context).goodMorning` / `S.of(context).goodAfternoon` / `S.of(context).goodEvening`.

---

### H-9 · `glowAngle` Unused Variable in Home Screen
**File:** `lib/screens/home_screen.dart` · **Line:** 1297
**Description:** `final glowAngle = v * 2 * 3.14159265;` is computed but never used (`// ignore: unused_local_variable`). This is a wasted calculation on every animation frame inside `ListenableBuilder`, which runs at 60fps.
**Fix:** Remove the variable and the `// ignore` comment.

---

## MEDIUM Issues

### M-1 · Hardcoded Placeholder Play Store URL
**File:** `lib/screens/about_screen.dart`
**Description:** The "Rate Us" feature links to `com.cruise_app` as the app ID in the Play Store URL. This is a placeholder that will result in a 404 on the Play Store.
**Fix:** Replace with the actual production app ID before release.

---

### M-2 · Privacy Toggle Keys May Not Match Backend Fields
**File:** `lib/screens/privacy_screen.dart`
**Description:** Toggle switches persist keys like `'privacy_location'` and send them to `ApiService.updateMe({key: value})`. If the backend user model doesn't have fields named `privacy_location`, etc., the update will silently fail or be ignored.
**Fix:** Verify that the key names match the backend schema. Consider defining a shared constant for privacy field names.

---

### M-3 · Driver Settings Accessibility Toggle Has No Effect
**File:** `lib/screens/driver/driver_settings_screen.dart`
**Description:** The accessibility toggle persists its value to `SharedPreferences` but no code anywhere reads that value to change app behavior (font sizes, contrast, screen reader hints, etc.).
**Fix:** Either implement accessibility features driven by this toggle, or remove it from the settings UI.

---

### M-4 · Trip Receipt Email Uses Hardcoded Headers
**File:** `lib/screens/trip_receipt_screen.dart` · **Lines:** 79–82
**Description:** The EmailJS API call uses `'User-Agent': 'Mozilla/5.0'` and `'origin': 'http://localhost'` headers. These are browser-spoofing headers that may be rejected by EmailJS in production, or trigger CORS/security filters.
**Fix:** Use proper mobile app headers or configure EmailJS to accept requests from the app's domain.

---

### M-5 · Driver Documents Default to "Approved" When Missing
**File:** `lib/screens/driver/driver_documents_screen.dart` · **Lines:** 87–95
**Description:** When a required document type isn't returned by the API, it's added to the local list with `'status': 'approved'`. This could mask genuinely missing documents, showing drivers a false "100% complete" status.
**Fix:** Default missing documents to `'not_uploaded'` or `'pending'` instead of `'approved'`.

---

### M-6 · Welcome Screen Hardcoded English Text
**File:** `lib/screens/welcome_screen.dart` · **Lines:** ~270–315
**Description:** "Want to drive?" and "Sign up to drive" are hardcoded English strings, not using the localization system. Spanish-language users will see English on this screen.
**Fix:** Replace with localization keys from `S.of(context)`.

---

### M-7 · Coming Soon Features in Driver Info Pages
**File:** `lib/screens/driver/driver_info_pages.dart` · **Lines:** 203, 208, 478
**Description:** Three driver opportunity sections ("Deliver packages", "Partner with grocery stores", and a "Coming Soon" label) reference features that don't exist. These are visible to drivers and may cause confusion.
**Fix:** Hide these sections behind a feature flag or remove until implemented.

---

### M-8 · `Random()` Used for ETA Jitter in Ride Options
**File:** `lib/state/rider_trip_controller.dart` · **Lines:** 276, 282, 292
**Description:** `math.Random().nextInt(...)` is called to add random jitter to ETA estimates, but a new `Random` instance is created each time. This produces predictable sequences and inconsistent ETAs if called rapidly.
**Fix:** Use a single `math.Random()` instance at the class level, or better, derive ETA from real backend data.

---

### M-9 · Notification Tapped Handler Does Nothing
**File:** `lib/services/notification_service.dart` · **Lines:** 60–62
**Description:** `_onNotificationTapped` only prints a debug message. When users tap a notification (e.g., "driver arrived"), nothing happens — they aren't navigated to the tracking screen or the relevant trip.
**Fix:** Implement deep linking based on the notification payload (e.g., `'ride_reminder:$tripId'` could navigate to the scheduled ride).

---

### M-10 · `deprecated_member_use` Suppression in Home Screen
**File:** `lib/screens/home_screen.dart` · **Line:** 374
**Description:** A `// ignore: deprecated_member_use` directive suppresses a deprecation warning. This may mask breaking API changes in future Flutter/package versions.
**Fix:** Migrate to the non-deprecated API.

---

## LOW Issues

### L-1 · Timezone Guessing Is US-Only
**File:** `lib/services/notification_service.dart` · **Lines:** 50–57
**Description:** `_guessTimezone()` only maps 4 US timezone offsets (-5, -6, -7, -8). International users or those in US territories with different offsets (Alaska, Hawaii, Guam) will default to `'America/Chicago'`, causing scheduled ride reminders to fire at wrong times.
**Fix:** Use a proper timezone detection package like `flutter_timezone` or `timezone_detector`.

---

### L-2 · Trip History Capped at 25 Without Notification
**File:** `lib/services/local_data_service.dart`
**Description:** `addTrip()` silently drops trips beyond 25 entries. Power users will lose ride history without any indication.
**Fix:** This is acceptable for local cache if the backend retains full history (which it does via `ApiService.getRideHistory()`). Consider increasing the limit or adding pagination.

---

### L-3 · `XOR + HMAC` Encryption for SharedPreferences Data
**File:** `lib/services/security_service.dart` · **Lines:** 128–150
**Description:** `encryptForPrefs()` uses an XOR cipher with HMAC-derived key bytes — this is not standard AES encryption. While the comment notes this is for less-sensitive data (with `storeCredential()` for truly sensitive data), XOR ciphers are easily broken by known-plaintext attacks.
**Fix:** Acceptable for the current use case (email/phone in SharedPreferences as local cache). For production hardening, consider using `encrypt` package with AES-CBC or AES-GCM.

---

### L-4 · Console Output Encoding Issues in `driver_online_screen.dart`
**File:** `lib/screens/driver/driver_online_screen.dart` · Multiple lines
**Description:** Several `debugPrint` statements contain mojibake characters (e.g., `âœ…` instead of `✅`, `âš ï¸` instead of `⚠️`). This indicates the file was saved/converted with incorrect encoding at some point. The emoji in debug output are cosmetic, but the encoding corruption could spread to user-visible strings.
**Fix:** Re-save the file with proper UTF-8 encoding. Replace corrupted characters with correct Unicode equivalents.

---

### L-5 · `_togglePinLabels()` Is a No-Op
**File:** `lib/screens/ride_request_screen.dart`
**Description:** `void _togglePinLabels() {}` — the method is registered as an `onTap` handler for map markers but does nothing. The comment says "Labels always visible — no toggle behavior."
**Fix:** Remove the empty method and the `onTap` registration, or implement toggle behavior if desired.

---

### L-6 · Notification IDs Use `hashCode` Which Can Collide
**File:** `lib/screens/rider_tracking_screen.dart`
**Description:** `NotificationService.show(id: title.hashCode, ...)` — `hashCode` for strings can collide, causing one notification to silently replace another.
**Fix:** Use a deterministic unique ID based on trip ID + notification type.

---

### L-7 · Phone Validation Is US-Only
**File:** `lib/screens/login_screen.dart` · **Lines:** 64–68
**Description:** `_isValidPhone()` and `_normalizePhone()` only support US phone numbers (10 digits, +1 prefix). International users cannot sign up with their phone numbers.
**Fix:** Acceptable if the app is US-only. For international expansion, add country code selection and use `libphonenumber` for validation.

---

### L-8 · `_selectedPaymentMethod` Defaults Based on Platform, Not User Preference
**File:** `lib/screens/ride_request_screen.dart` · **Line:** ~90
**Description:** Default payment is `'credit_card'` on iOS and `'google_pay'` on Android, regardless of what the user has actually linked. If the user only has PayPal linked, they'll see the wrong default.
**Fix:** Load the user's last-used or preferred payment method from `LocalDataService`.

---

## Architecture Notes (Not Bugs)

These are observations about the codebase architecture that are worth noting but not bugs:

1. **Security model is strong:** HMAC request signing, encrypted credential storage (Keystore/Keychain), biometric auth, device fingerprinting, anti-replay nonces, input sanitization — the security layer is well-implemented.

2. **Dual map support (Google Maps + Apple Maps)** is implemented throughout the codebase. This adds significant code complexity but provides platform-native experiences.

3. **Real-time tracking** uses both Firestore streams and backend polling as fallback — a solid redundancy strategy.

4. **`RiderTripController`** is a clean state machine with well-defined phases and proper backend integration for dispatch polling.

5. **`CruiseSupportChatScreen`** (in help_screen.dart) properly connects to the backend AI agent with chat creation, message polling, supervisor escalation, and session management. This is separate from the broken `ChatScreen(isSupport: true)` (issue C-2).

6. **Localization** is partially implemented — many screens use `S.of(context)`, but some screens have hardcoded English strings (issues H-8, M-6).

7. **GPS simulation** in `driver_online_screen.dart` uses Catmull-Rom spline interpolation at 60fps with route snapping — sophisticated and smooth for development/testing.

---

*End of audit report.*
