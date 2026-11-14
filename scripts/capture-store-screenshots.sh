#!/usr/bin/env bash
# Capture Play Store screenshots from a real device or emulator.
#
# The CI sandbox has no Android SDK and no emulator, so the screenshots in
# store/screenshots/ must be produced on a machine that has one. Play requires
# 2-8 phone screenshots, 16:9 or 9:16, minimum 320px, maximum 3840px per side.
#
#   ./scripts/capture-store-screenshots.sh emulator-5554
#
# Screens must be reached by hand (or by integration_test); this script only
# drives the capture so every image is 1080x1920 and free of debug banners.
set -euo pipefail

device="${1:-emulator-5554}"
out="store/screenshots"
mkdir -p "$out"

adb -s "$device" shell wm size 1080x1920
adb -s "$device" shell settings put global window_animation_scale 0
adb -s "$device" shell settings put global transition_animation_scale 0
adb -s "$device" shell settings put global animator_duration_scale 0

shoot() {
  local name="$1"
  read -r -p "Open the '$name' screen, then press Enter…" _
  adb -s "$device" exec-out screencap -p > "$out/$name.png"
  python3 - "$out/$name.png" <<'PY'
import sys
from PIL import Image
im = Image.open(sys.argv[1])
print(f'  {sys.argv[1]} {im.size} {im.mode}')
if im.mode not in ('RGB', 'RGBA'):
    im.convert('RGB').save(sys.argv[1])
PY
}

./scripts/refresh-store-assets.py

shoot 01-feed
shoot 02-composer
shoot 03-reactions
shoot 04-chat
shoot 05-profile
shoot 06-settings

echo "==> ready in $out (6 images, 1080x1920)"
