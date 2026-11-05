# ICA 13 – Firebase Authentication in Flutter

**Course:** CSC 4360 Mobile App Development · **Student:** Saketh Sagar Kokkireni
**Platform:** Android (APK) · **Stack:** Flutter, `firebase_core`, `firebase_auth`

A Flutter app where a user can **register, sign in, see their email on a protected profile, change their password (with re-authentication), and sign out**. Firebase auth state alone decides which screen is visible.

## Features

| Requirement | Where |
|---|---|
| Firebase initialised **before** `runApp()` with `DefaultFirebaseOptions.currentPlatform` | `lib/main.dart` |
| `AuthService`: register, sign-in, sign-out, password update, re-auth + retry, current user, **cached** `authStateChanges` stream | `lib/services/auth_service.dart` |
| `AuthGate`: `StreamBuilder<User?>` routes signed-in → Profile, signed-out → Sign-in; loading + error states | `lib/screens/auth_gate.dart` |
| Sign-in / Register form: email format check, 6-char password minimum, confirm password, show/hide password, loading spinner, duplicate-submit blocked | `lib/screens/authentication_screen.dart` |
| Profile: signed-in email, account created / last sign-in, change password, sign out | `lib/screens/profile_screen.dart` |
| `requires-recent-login` → "Confirm it's you" dialog (obscured current password) → `reauthenticateWithCredential` → retry `updatePassword` | `profile_screen.dart` + `auth_service.dart` |
| Firebase error codes → safe, helpful text (no raw exception text; sign-in failures don't reveal whether an email is registered) | `lib/utils/auth_error_messages.dart` |
| Stretch: "Forgot password?" reset email with a privacy-aware message | `authentication_screen.dart` |
| Unit tests for validators and error mapping | `test/` |

### Why it's built this way
- **One service ("front desk").** Widgets never call `FirebaseAuth` directly, so auth rules change in one place.
- **No `Navigator.push` after sign-in.** The protected screen exists only while the auth stream has a user. After sign-out there is no back-stack entry leading back to the profile.
- **Stable stream.** `authStateChanges` is created once (`late final`) and `AuthGate` keeps one `AuthService` in its `State`, so rebuilds don't resubscribe.
- **Authentication ≠ authorization.** Hiding a screen in Flutter is UX, not security. Any user data in Firestore must also be protected by Security Rules (e.g. `request.auth.uid == uid`).

## Setup

**Prerequisites:** Flutter SDK, Android SDK and an emulator or device, Node.js (for the Firebase CLI), and a Google account.

1. **Firebase Console** → create a project → **Build → Authentication → Get started → Sign-in method → Email/Password → Enable**.
2. Install the CLIs (once):
   ```bash
   npm install -g firebase-tools
   firebase login
   dart pub global activate flutterfire_cli
   ```
3. From the project root, generate the Firebase config (it is **not committed**; see *Security* below):
   ```bash
   flutter pub get
   flutterfire configure --project=<your-firebase-project-id> --platforms=android
   ```
   This creates `lib/firebase_options.dart` and `android/app/google-services.json`.
4. Make sure `android/app/src/main/AndroidManifest.xml` contains
   `<uses-permission android:name="android.permission.INTERNET" />` directly inside `<manifest>` (already done in this repo).

> One-shot alternative: `bash tools/setup_and_build.sh <your-firebase-project-id>` runs steps 3–4, the tests and the release build.

## Run & test

```bash
flutter run                    # debug on emulator/device
flutter test                   # unit tests (validators + error messages)
flutter build apk --release    # build/app/outputs/flutter-apk/app-release.apk
```

### Manual test plan (run on the release APK)

| # | Test | Expected |
|---|---|---|
| 1 | Register a new test email + valid password | Profile opens showing that email; user appears in Firebase Console → Authentication → Users |
| 2 | Register with `bad-email` / 5-char password / mismatched confirm | Inline field errors, no request sent |
| 3 | Sign in with a wrong password | "Email or password is incorrect…" (doesn't reveal whether the account exists) |
| 4 | Sign in with valid credentials | Spinner on button, then profile |
| 5 | Kill and relaunch the app | Still signed in (session restored by `authStateChanges`) |
| 6 | Update password (fresh sign-in) | "Password updated" |
| 7 | Update password when sign-in is older than ~5 min | `requires-recent-login` → "Confirm it's you" dialog → correct current password → updated |
| 8 | Sign out → press Back / relaunch | Sign-in screen; profile not reachable |
| 9 | Sign in with **old** password | Fails with the generic message |
| 10 | Sign in with **new** password | Succeeds |
| 11 | Network off, then sign in | Loading state, then "Can't reach the server…" |

## Security notes
- Passwords are only ever sent to Firebase Authentication: never logged, stored or written to Firestore.
- `firebase_options.dart`, `google-services.json`, keystores and APKs are git-ignored. Firebase client config isn't a secret, but keeping it out of the repo means each environment regenerates it with `flutterfire configure`.
- The release build is signed with the debug key for this class activity. A store release needs its own keystore, kept out of git.

## Project structure
```
lib/
  main.dart                 Firebase init → MyApp → AuthGate
  theme.dart
  services/auth_service.dart
  screens/auth_gate.dart
  screens/authentication_screen.dart
  screens/profile_screen.dart
  utils/validators.dart
  utils/auth_error_messages.dart
  widgets/common.dart       ErrorBanner, PasswordField, BusyLabel
test/                       validators_test.dart, auth_error_messages_test.dart
tools/                      setup_and_build.sh, device_helper.sh (emulator test relay)
```

## References
- Firebase – Add Firebase to your Flutter app: https://firebase.google.com/docs/flutter/setup
- Firebase – Get started with Firebase Authentication on Flutter: https://firebase.google.com/docs/auth/flutter/start
- Firebase – Manage users in Firebase (update password, re-authenticate): https://firebase.google.com/docs/auth/flutter/manage-users
- Flutter – Build a form with validation: https://docs.flutter.dev/cookbook/forms/validation
- `firebase_auth` API: https://pub.dev/documentation/firebase_auth/latest/

## AI disclosure
Claude (Anthropic) was used to plan the auth flow, generate the code, tests, setup script and this README. All behaviour was verified by running the app and the tests; see the reflection document.
