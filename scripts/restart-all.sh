#!/usr/bin/env bash
#
# restart-all.sh
# Shut down all simulators, boot 3 devices, build MbengkelIn once,
# then install + (re)launch the app on all three.
#
set -euo pipefail

# --- Config ---------------------------------------------------------------
SCHEME="MbengkelIn"
BUNDLE_ID="com.reisoemanto.MbengkelIn"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$PROJECT_DIR/MbengkelIn.xcodeproj"
DERIVED="$PROJECT_DIR/build"

# Devices to boot. Edit this list to change which 3 simulators start.
DEVICES=("iPhone 17 Pro" "iPhone 17e" "iPhone Air")
# -------------------------------------------------------------------------

echo "==> Shutting down all simulators"
xcrun simctl shutdown all 2>/dev/null || true

# Resolve device names to UDIDs and boot them.
UDIDS=()
for name in "${DEVICES[@]}"; do
  udid=$(xcrun simctl list devices available \
    | grep -F "$name (" \
    | head -1 \
    | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}')
  if [[ -z "$udid" ]]; then
    echo "!! Device not found: $name (skipping)"
    continue
  fi
  echo "==> Booting $name ($udid)"
  xcrun simctl boot "$udid" 2>/dev/null || true
  UDIDS+=("$udid")
done

echo "==> Opening Simulator app"
open -a Simulator

echo "==> Building $SCHEME (this can take a minute)"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "$DERIVED" \
  build | tail -5

APP_PATH="$DERIVED/Build/Products/Debug-iphonesimulator/$SCHEME.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "!! Build product not found at $APP_PATH"
  exit 1
fi

for udid in "${UDIDS[@]}"; do
  echo "==> Installing on $udid"
  xcrun simctl install "$udid" "$APP_PATH"
  echo "==> Launching on $udid"
  xcrun simctl launch "$udid" "$BUNDLE_ID" >/dev/null
done

echo "==> Done. $SCHEME running on ${#UDIDS[@]} simulator(s)."
