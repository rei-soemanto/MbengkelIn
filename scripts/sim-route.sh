#!/usr/bin/env bash
#
#  sim-route.sh
#  MbengkelIn
#
#  Drive a booted iOS Simulator's GPS along simulation/route.gpx.
#
#  Route: (-7.2813896,112.6274774) -> (-7.28229,112.634072)
#
#  Usage:
#    scripts/sim-route.sh init            # set the INITIAL (start) location only
#    scripts/sim-route.sh go              # replay the full route (start -> end)
#    scripts/sim-route.sh go --speed=5    # replay slower (m/s, default 9)
#    scripts/sim-route.sh clear           # stop sim & clear the override
#
#  Target device: defaults to "iPhone 17 Pro" (emulator 1).
#  Override with:  DEVICE="iPhone Air" scripts/sim-route.sh go
#  or a UDID:      DEVICE=AE9CC18C-... scripts/sim-route.sh go
#
set -euo pipefail

DEVICE="${DEVICE:-iPhone 17 Pro}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GPX="$HERE/simulation/route.gpx"

START_LAT="-7.2813896"
START_LON="112.6274774"

cmd="${1:-go}"
shift || true
SPEED="108"   # 12x the original ~9 m/s (4x then 3x)
for arg in "$@"; do
  case "$arg" in
    --speed=*) SPEED="${arg#*=}" ;;
  esac
done

# Pull "lat,lon" waypoints out of the GPX (handles wpt/trkpt).
waypoints() {
  /usr/bin/python3 - "$GPX" <<'PY'
import re, sys
txt = open(sys.argv[1]).read()
for lat, lon in re.findall(r'lat="([-0-9.]+)"\s+lon="([-0-9.]+)"', txt):
    print(f"{lat},{lon}")
PY
}

case "$cmd" in
  init)
    echo "Setting initial location on '$DEVICE' -> $START_LAT,$START_LON"
    xcrun simctl location "$DEVICE" set "$START_LAT,$START_LON"
    ;;
  go)
    echo "Replaying route on '$DEVICE' at ${SPEED} m/s ..."
    # Waypoints have negative latitudes (leading '-'), which simctl would treat
    # as flags, so feed them via stdin ('-' = read waypoints from stdin).
    waypoints | xcrun simctl location "$DEVICE" start --speed="$SPEED" -
    echo "Route playback started. Run '$0 clear' to stop."
    ;;
  clear)
    echo "Clearing location override on '$DEVICE'"
    xcrun simctl location "$DEVICE" clear
    ;;
  *)
    echo "Unknown command: $cmd" >&2
    echo "Usage: $0 {init|go [--speed=N]|clear}" >&2
    exit 1
    ;;
esac
