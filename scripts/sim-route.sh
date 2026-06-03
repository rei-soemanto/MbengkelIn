#!/usr/bin/env bash
#
#  sim-route.sh
#  MbengkelIn
#
#  The geospatial test driver: pins the CUSTOMER at a fixed Surabaya location and
#  drives the BENGKEL toward the customer, so the customer sees the bengkel approach
#  on the map and the within-range "Selesaikan Pesanan" gate (<= 80 m) unlocks.
#
#  Pairs with restart-with-watch.sh (which only boots the 3 emulators + the app):
#    scripts/restart-with-watch.sh        # boot the emulators + install/launch
#    scripts/sim-route.sh init            # place customer + bengkel (run this first)
#    scripts/sim-route.sh go              # drive the bengkel to the customer
#    scripts/sim-route.sh go --speed=25   # drive faster (m/s, default 12)
#    scripts/sim-route.sh clear           # clear both GPS overrides
#
#  Devices default to restart-with-watch.sh's: customer = iPhone 17 Pro,
#  bengkel = iPhone 17. Override with env vars, e.g.:
#    CUSTOMER="iPhone 17 Pro" BENGKEL="iPhone Air" scripts/sim-route.sh go
#
set -euo pipefail

CUSTOMER="${CUSTOMER:-${PHONE1_NAME:-iPhone 17 Pro}}"   # the customer's phone
BENGKEL="${BENGKEL:-${PHONE2_NAME:-iPhone 17}}"         # the bengkel's phone

# Customer is fixed; the bengkel starts ~600 m away and drives to the customer.
CUST_LAT="${CUST_LAT:--7.2845}";  CUST_LON="${CUST_LON:-112.6315}"
BENG_LAT="${BENG_LAT:--7.2814}";  BENG_LON="${BENG_LON:-112.6275}"

cmd="${1:-go}"
shift || true
SPEED="12"   # ~12 m/s (~43 km/h); the ~600 m drive plays over ~50s
for arg in "$@"; do
  case "$arg" in --speed=*) SPEED="${arg#*=}" ;; esac
done

case "$cmd" in
  init)
    echo "Placing customer '$CUSTOMER' -> $CUST_LAT,$CUST_LON"
    xcrun simctl location "$CUSTOMER" set "$CUST_LAT,$CUST_LON"
    echo "Placing bengkel  '$BENGKEL' -> $BENG_LAT,$BENG_LON"
    xcrun simctl location "$BENGKEL" set "$BENG_LAT,$BENG_LON"
    ;;
  go)
    echo "Pinning customer '$CUSTOMER' -> $CUST_LAT,$CUST_LON"
    xcrun simctl location "$CUSTOMER" set "$CUST_LAT,$CUST_LON"
    echo "Driving bengkel  '$BENGKEL' to the customer at ${SPEED} m/s ..."
    # Waypoints start with '-' (negative latitude), which simctl would read as
    # flags, so feed them via stdin ('-' = read waypoints from stdin). simctl
    # interpolates from the bengkel's start to the customer over time.
    printf '%s\n%s\n' "$BENG_LAT,$BENG_LON" "$CUST_LAT,$CUST_LON" \
      | xcrun simctl location "$BENGKEL" start --speed="$SPEED" -
    echo "Bengkel en route to the customer. Run '$0 clear' to stop."
    ;;
  clear)
    echo "Clearing GPS overrides on '$CUSTOMER' and '$BENGKEL'"
    xcrun simctl location "$CUSTOMER" clear 2>/dev/null || true
    xcrun simctl location "$BENGKEL" clear 2>/dev/null || true
    ;;
  *)
    echo "Unknown command: $cmd" >&2
    echo "Usage: $0 {init|go [--speed=N]|clear}" >&2
    exit 1
    ;;
esac
