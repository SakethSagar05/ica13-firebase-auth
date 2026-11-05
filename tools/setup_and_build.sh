#!/usr/bin/env bash
# ICA 13 one-shot setup:
#   platform folders -> Firebase packages -> Android config -> flutterfire configure
#   -> tests -> release APK -> git commits -> (optional) GitHub push -> device helper
# Usage:  bash tools/setup_and_build.sh <firebase-project-id>
set -euo pipefail

PROJECT_ID="${1:-}"
PKG="com.saketh.ica13_firebase_auth"
cd "$(dirname "$0")/.."
ROOT="$(pwd)"

export PATH="$PATH:$HOME/.pub-cache/bin:$HOME/.npm-global/bin:/opt/homebrew/bin:/usr/local/bin:$HOME/flutter/bin:$HOME/development/flutter/bin"
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
export PATH="$PATH:$SDK/platform-tools:$SDK/emulator"

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

command -v flutter >/dev/null || { echo "flutter is not on PATH. Open a terminal where 'flutter --version' works and re-run."; exit 1; }
flutter --version | head -1

step "1/8 Create Flutter platform folders (keeps the hand-written lib/ and test/)"
if [ ! -f pubspec.yaml ]; then
  TMP="$(mktemp -d)"
  mv lib test README.md "$TMP"/
  flutter create --org com.saketh --project-name ica13_firebase_auth --platforms android .
  rm -rf lib test README.md
  mv "$TMP"/lib "$TMP"/test "$TMP"/README.md .
  rmdir "$TMP" 2>/dev/null || true
else
  echo "pubspec.yaml exists, skipping flutter create"
fi

if ! grep -q "ICA13 Firebase" .gitignore 2>/dev/null; then
  cat >> .gitignore <<'GI'

# ICA13 Firebase / local-only files (regenerate with `flutterfire configure`)
lib/firebase_options.dart
android/app/google-services.json
firebase.json
tools/.relay/
submission/
*.keystore
*.jks
key.properties
GI
fi

step "2/8 Add firebase_core + firebase_auth"
flutter pub add firebase_core firebase_auth

step "3/8 Android config: INTERNET permission in main manifest, app label, minSdk >= 23"
MANIFEST=android/app/src/main/AndroidManifest.xml
grep -q 'android.permission.INTERNET' "$MANIFEST" || \
  perl -0pi -e 's/(<manifest[^>]*>)/$1\n    <uses-permission android:name="android.permission.INTERNET" \/>/' "$MANIFEST"
perl -pi -e 's/android:label="ica13_firebase_auth"/android:label="ICA13 Auth"/' "$MANIFEST"
if [ -f android/app/build.gradle.kts ]; then
  perl -pi -e 's/minSdk = flutter\.minSdkVersion/minSdk = maxOf(flutter.minSdkVersion, 23)/' android/app/build.gradle.kts
elif [ -f android/app/build.gradle ]; then
  perl -pi -e 's/minSdkVersion flutter\.minSdkVersion/minSdkVersion Math.max(flutter.minSdkVersion, 23)/; s/minSdk = flutter\.minSdkVersion/minSdk = Math.max(flutter.minSdkVersion, 23)/' android/app/build.gradle
fi
grep -n 'INTERNET' "$MANIFEST"

step "4/8 Firebase CLI + FlutterFire configure (Android)"
command -v firebase >/dev/null || npm install -g firebase-tools
firebase projects:list >/dev/null 2>&1 || firebase login
command -v flutterfire >/dev/null || dart pub global activate flutterfire_cli
if [ -n "$PROJECT_ID" ]; then
  flutterfire configure --project="$PROJECT_ID" --platforms=android --android-package-name="$PKG" --yes
else
  flutterfire configure --platforms=android --android-package-name="$PKG"
fi
test -f lib/firebase_options.dart && echo "lib/firebase_options.dart generated OK"

step "5/8 Unit tests + analyzer"
mkdir -p docs
{ flutter --version; echo; firebase --version 2>/dev/null | sed "s/^/firebase-tools /"; flutterfire --version 2>/dev/null | tail -1 | sed "s/^/flutterfire /"; } > docs/env.txt 2>&1 || true
flutter test 2>&1 | tee docs/test_output.txt || echo "(some tests failed, see above; continuing to the build)"
flutter analyze 2>&1 | tee docs/analyze_output.txt || echo "(analyzer reported issues above; not fatal)"

step "6/8 Release APK"
flutter build apk --release
mkdir -p submission
cp build/app/outputs/flutter-apk/app-release.apk submission/Kokkireni_Saketh_ICA13.apk
ls -lh submission/Kokkireni_Saketh_ICA13.apk

step "7/8 Git history"
TRAILER=$'\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_016XgwNWg6JgUMZTbkZPK1v6'
if [ ! -d .git ]; then
  git init -q -b main
  git add -A
  git rm -r -q --cached --ignore-unmatch lib/services lib/utils lib/screens lib/widgets lib/theme.dart test README.md tools docs
  git commit -q -m "Set up Flutter app: Firebase init before runApp, Android INTERNET permission${TRAILER}"
  git add lib/services
  git commit -q -m "Add AuthService for register, sign-in, sign-out, password update and auth-state stream${TRAILER}"
  git add lib/utils test
  git commit -q -m "Add email/password validators, safe Firebase error messages and unit tests${TRAILER}"
  git add lib/screens lib/widgets lib/theme.dart
  git commit -q -m "Add AuthGate routing, sign-in/register screen and protected profile with password update + reauth${TRAILER}"
  git add -A
  git commit -q -m "Add README, setup script and emulator test helper${TRAILER}" || true
fi
git log --oneline | cat

step "8/8 GitHub (optional)"
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1 && ! git remote get-url origin >/dev/null 2>&1; then
  read -r -p "Create PUBLIC GitHub repo 'ica13-firebase-auth' and push? [y/N] " ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    gh repo create ica13-firebase-auth --public --source=. --remote=origin --push
    gh repo view --json url -q .url
  fi
else
  echo "Skipping auto-push (gh missing/not logged in, or origin already set)."
  echo "Manual: git remote add origin https://github.com/<you>/ica13-firebase-auth.git && git push -u origin main"
fi

printf '\n\033[1;32mSetup done. APK: %s/submission/Kokkireni_Saketh_ICA13.apk\033[0m\n' "$ROOT"
echo "Starting the emulator test helper (Ctrl+C to stop)..."
exec bash tools/device_helper.sh
