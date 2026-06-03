#!/usr/bin/env bash
#
# restart-with-watch.sh
# Boot 2 iPhone simulators + 1 Apple Watch paired to the FIRST iPhone,
# build MbengkelIn once, then install + (re)launch the iOS app on both phones
# and the watch app on the paired watch.
#
# Phone 1 (with the watch) = the CUSTOMER device (the watch companion mirrors
# the customer's active order over WatchConnectivity).
# Phone 2 (standalone)     = the BENGKEL device, for side-by-side testing.
#
# The watch only "connects" to a phone through a live, ACTIVE simulator pair, so
# this script reuses (or creates) a watch<->Phone-1 pair, boots Phone 1 fully BEFORE
# the watch, and waits for the bridge to report "connected" before launching the apps.
#
# Override any device with env vars, e.g.:
#   PHONE2_NAME="iPhone Air" WATCH_NAME="Apple Watch Ultra 3 (49mm)" scripts/restart-with-watch.sh
#
set -euo pipefail

# --- Config ---------------------------------------------------------------
SCHEME="MbengkelIn"
APP_BUNDLE_ID="com.reisoemanto.MbengkelIn"
WATCH_BUNDLE_ID="com.reisoemanto.MbengkelIn.watchkitapp"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$PROJECT_DIR/MbengkelIn.xcodeproj"
DERIVED="$PROJECT_DIR/build"

PHONE1_NAME="${PHONE1_NAME:-iPhone 17 Pro}"          # gets the watch (customer)
PHONE2_NAME="${PHONE2_NAME:-iPhone 17}"              # standalone (bengkel)
WATCH_NAME="${WATCH_NAME:-Apple Watch Series 11 (46mm)}"
# -------------------------------------------------------------------------

# Resolve a simulator name to its first matching available UDID.
udid_for() {
  xcrun simctl list devices available \
    | grep -F "$1 (" | head -1 \
    | grep -oiE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}'
}

PHONE1=$(udid_for "$PHONE1_NAME"); [[ -n "$PHONE1" ]] || { echo "!! Simulator not found: $PHONE1_NAME"; exit 1; }
PHONE2=$(udid_for "$PHONE2_NAME"); [[ -n "$PHONE2" ]] || { echo "!! Simulator not found: $PHONE2_NAME"; exit 1; }
WATCH=$(udid_for "$WATCH_NAME");   [[ -n "$WATCH"  ]] || { echo "!! Simulator not found: $WATCH_NAME"; exit 1; }

echo "==> Phone 1 (customer, +watch): $PHONE1_NAME  $PHONE1"
echo "==> Phone 2 (bengkel):          $PHONE2_NAME  $PHONE2"
echo "==> Watch:                      $WATCH_NAME  $WATCH"

echo "==> Shutting down all simulators"
xcrun simctl shutdown all 2>/dev/null || true

# Reuse an existing watch <-> Phone-1 pair if there is one; only create a fresh pair
# when none exists. Re-pairing on every run churns the WatchConnectivity bridge and
# is the usual reason the watch app never becomes reachable. (Pairs survive a
# shutdown; creating one requires the devices to be shut down, done above.)
PAIR_UDID=$(xcrun simctl list pairs | awk -v w="$WATCH" -v p="$PHONE1" '
  /^[0-9A-Fa-f-]{36} / { pid=$1; next }
  pid && index($0, w) { hasW[pid]=1 }
  pid && index($0, p) { hasP[pid]=1 }
  END { for (id in hasW) if (hasP[id]) { print id; exit } }')

if [[ -n "$PAIR_UDID" ]]; then
  echo "==> Reusing existing pair: $PAIR_UDID"
else
  echo "==> No watch <-> Phone-1 pair found — creating one"
  xcrun simctl list pairs \
    | grep -oiE '^[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' \
    | while read -r pr; do xcrun simctl unpair "$pr" 2>/dev/null || true; done
  PAIR_UDID=$(xcrun simctl pair "$WATCH" "$PHONE1")
  echo "==> Created pair: $PAIR_UDID"
fi

# Boot Phone 1 FULLY before the watch so the watch's companion bridge finds a ready
# phone — booting them at the same time is the usual cause of "watch won't connect".
echo "==> Booting $PHONE1_NAME (waiting until ready)"
xcrun simctl boot "$PHONE1" 2>/dev/null || true
xcrun simctl bootstatus "$PHONE1" 2>/dev/null || true
echo "==> Booting watch, then $PHONE2_NAME"
xcrun simctl boot "$WATCH" 2>/dev/null || true
xcrun simctl bootstatus "$WATCH" 2>/dev/null || true
xcrun simctl boot "$PHONE2" 2>/dev/null || true

echo "==> Activating pair"
xcrun simctl pair_activate "$PAIR_UDID" 2>/dev/null || true

echo "==> Opening Simulator app"
open -a Simulator

# Wait for the watch<->phone bridge to report "connected" so WCSession activates
# against a live pair. Non-fatal: it often finishes connecting as the apps launch.
printf "==> Waiting for pair to connect"
for _ in $(seq 1 30); do
  if xcrun simctl list pairs | grep -F "$PAIR_UDID" | grep -q "connected"; then
    printf " ... connected\n"; break
  fi
  printf "."; sleep 1
done
echo

echo "==> Building $SCHEME (this can take a minute)"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "$DERIVED" \
  build | tail -5

APP_PATH="$DERIVED/Build/Products/Debug-iphonesimulator/$SCHEME.app"
WATCH_APP_PATH="$APP_PATH/Watch/MbengkelInWatchOS Watch App.app"
[[ -d "$APP_PATH" ]] || { echo "!! iOS app not found at $APP_PATH"; exit 1; }
[[ -d "$WATCH_APP_PATH" ]] || { echo "!! Embedded watch app not found at $WATCH_APP_PATH"; exit 1; }

echo "==> Installing iOS app on both phones"
xcrun simctl install "$PHONE1" "$APP_PATH"
xcrun simctl install "$PHONE2" "$APP_PATH"

echo "==> Installing watch app on the watch"
xcrun simctl install "$WATCH" "$WATCH_APP_PATH"

# Pre-grant location so the app gets GPS fixes without a permission prompt. Without
# this the BENGKEL never writes order_locations and never appears on the customer's
# tracking map (the customer side prompts on its own and usually gets granted).
echo "==> Granting location permission to the app on both phones"
xcrun simctl privacy "$PHONE1" grant location-always "$APP_BUNDLE_ID" 2>/dev/null || true
xcrun simctl privacy "$PHONE2" grant location-always "$APP_BUNDLE_ID" 2>/dev/null || true

echo "==> Launching apps"
xcrun simctl launch "$PHONE1" "$APP_BUNDLE_ID"  >/dev/null
xcrun simctl launch "$PHONE2" "$APP_BUNDLE_ID"  >/dev/null
xcrun simctl launch "$WATCH"  "$WATCH_BUNDLE_ID" >/dev/null

echo "==> Pair status"
xcrun simctl list pairs | grep -A2 -F "$PAIR_UDID" || true

cat <<EOF
==> Done.
    • Phone 1 ($PHONE1_NAME) is paired with the watch — log in here as the CUSTOMER.
    • Phone 2 ($PHONE2_NAME) is standalone — log in here as the BENGKEL.
    • Keep BOTH the Phone-1 app and the watch app in the foreground: WatchConnectivity
      'sendMessage' (approve / finish / rate) needs WCSession.isReachable on both sides.
    • GPS is handled separately by scripts/sim-route.sh:
          scripts/sim-route.sh init   # place customer + bengkel (do this BEFORE ordering)
          scripts/sim-route.sh go     # drive the bengkel — run AFTER the order is accepted
                                      # (On Progress). The bengkel only writes its live
                                      # position (order_locations) while MOVING during an order.
EOF
