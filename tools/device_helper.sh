#!/usr/bin/env bash
# Boots an Android emulator (if none is connected), installs the RELEASE APK,
# launches it, then runs a small request relay so test steps and screenshots
# can be scripted from files in tools/.relay/requests/.
#
# Each request file holds ONE line, processed in filename order:
#   shot NAME        -> docs/screenshots/NAME.png   (adb screencap)
#   dump NAME        -> tools/.relay/ui/NAME.xml     (UI hierarchy)
#   tap X Y | swipe X1 Y1 X2 Y2 MS | key KEYCODE | text TEXT
#   restart | stop | launch | net off | net on | install
# Only these adb actions are allowed; anything else is ignored.
set -uo pipefail

PKG="com.saketh.ica13_firebase_auth"
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
export PATH="$PATH:$SDK/platform-tools:$SDK/emulator"
APK="$ROOT/submission/Kokkireni_Saketh_ICA13.apk"
RELAY="$ROOT/tools/.relay"; REQ="$RELAY/requests"; UI="$RELAY/ui"; SHOTS="$ROOT/docs/screenshots"
mkdir -p "$REQ" "$UI" "$SHOTS"
LOG="$RELAY/log.txt"
log() { echo "$(date '+%H:%M:%S') $*" | tee -a "$LOG"; }

command -v adb >/dev/null || { echo "adb not found (expected in $SDK/platform-tools)"; exit 1; }

if ! adb devices | awk 'NR>1 && $2=="device"' | grep -q .; then
  AVD="$(emulator -list-avds 2>/dev/null | head -1)"
  if [ -z "$AVD" ]; then
    echo "No emulator found. Create one in Android Studio > Device Manager, or plug in a phone with USB debugging, then re-run: bash tools/device_helper.sh"
    exit 1
  fi
  log "Booting emulator $AVD ..."
  nohup emulator -avd "$AVD" -netdelay none -netspeed full >/dev/null 2>&1 &
fi
adb wait-for-device
until [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do sleep 2; done
SERIAL="$(adb devices | awk 'NR>1 && $2=="device"{print $1; exit}')"
A() { adb -s "$SERIAL" "$@"; }
log "Device ready: $SERIAL ($(A shell wm size | tr -d '\r' | awk '{print $3}'))"

launch() { A shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; }
if [ -f "$APK" ]; then
  log "Installing release APK..."; A install -r "$APK" | tail -1 | tee -a "$LOG"
fi
launch; log "App launched. Relay watching $REQ"
echo "ready $(date +%s)" > "$RELAY/status"

num='^[0-9]+$'; safe_text='^[A-Za-z0-9@._+!-]+$'; safe_name='^[A-Za-z0-9_-]+$'
while true; do
  for f in $(ls "$REQ"/*.req 2>/dev/null | sort); do
    line="$(head -1 "$f" | tr -d '\r')"; rm -f "$f"
    set -- $line; cmd="${1:-}"; shift || true
    case "$cmd" in
      shot)  [[ "${1:-}" =~ $safe_name ]] && A exec-out screencap -p > "$SHOTS/$1.png" && log "shot $1";;
      dump)  [[ "${1:-}" =~ $safe_name ]] && A shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1 && A exec-out cat /sdcard/ui.xml > "$UI/$1.xml" && log "dump $1";;
      tap)   [[ "${1:-}" =~ $num && "${2:-}" =~ $num ]] && A shell input tap "$1" "$2" && log "tap $1 $2";;
      swipe) [[ "${1:-}" =~ $num && "${2:-}" =~ $num && "${3:-}" =~ $num && "${4:-}" =~ $num && "${5:-}" =~ $num ]] && A shell input swipe "$1" "$2" "$3" "$4" "$5" && log "swipe";;
      key)   [[ "${1:-}" =~ $num ]] && A shell input keyevent "$1" && log "key $1";;
      text)  [[ "${1:-}" =~ $safe_text ]] && A shell input text "'$1'" && log "text (${#1} chars)";;
      restart) A shell am force-stop "$PKG"; sleep 1; launch; log "restart app";;
      stop)  A shell am force-stop "$PKG"; log "stop app";;
      launch) launch; log "launch app";;
      net)   if [ "${1:-}" = off ]; then A shell svc wifi disable; A shell svc data disable; log "network OFF";
             elif [ "${1:-}" = on ]; then A shell svc wifi enable; A shell svc data enable; log "network ON"; fi;;
      info)  { echo "model=$(A shell getprop ro.product.model)"; echo "android=$(A shell getprop ro.build.version.release)"; echo "sdk=$(A shell getprop ro.build.version.sdk)"; echo "size=$(A shell wm size)"; } | tr -d '\r' > "$RELAY/info.txt"; log "info";;
      install) A install -r "$APK" | tail -1 | tee -a "$LOG"; launch;;
      *) log "ignored: $line";;
    esac
    echo "ok $(date +%s) $cmd" > "$RELAY/status"
  done
  sleep 0.5
done
