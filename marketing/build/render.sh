#!/bin/bash
# Render an HTML file to a PNG at exact App Store resolution.
# Usage: ./render.sh input.html output.png [width] [height]
set -e
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
IN="$1"
OUT="$2"
W="${3:-1284}"
H="${4:-2778}"
DIR="$(cd "$(dirname "$IN")" && pwd)"
BASE="$(basename "$IN")"
# Drive the export size from the args so any accepted App Store size is one call.
printf ':root{ --ow:%s; --oh:%s; }\n' "$W" "$H" > "${DIR}/_size.css"
"$CHROME" \
  --headless=new \
  --disable-gpu \
  --hide-scrollbars \
  --no-sandbox \
  --force-device-scale-factor=1 \
  --allow-file-access-from-files \
  --default-background-color=00000000 \
  --window-size="${W},${H}" \
  --virtual-time-budget=4000 \
  --screenshot="$OUT" \
  "file://${DIR}/${BASE}" >/dev/null 2>&1
# App Store Connect rejects images with an alpha channel — flatten to opaque RGB.
swift "${DIR}/flatten.swift" "$OUT" >/dev/null 2>&1
echo "rendered $OUT ($W x $H, no alpha)"
