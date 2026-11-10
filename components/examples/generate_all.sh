#!/usr/bin/env bash
# Regenerate every component fixture and run the repository STEP validator on
# each flat part/assembly. OCCT (DRAWEXE or occt-draw) and gmsh are optional;
# they are used automatically when present.
set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT="$ROOT/components/examples/output"
mkdir -p "$OUT" "$OUT/assembly-structure"
cd "$ROOT"

moon run --target native components/examples/fasteners -- --catalog "$OUT"
moon run --target native components/examples/hardware_kit -- \
  --size M4 --length 20 -o "$OUT/kit-M4x20-flat.step"
moon run --target native components/examples/hardware_kit -- \
  --size M4 --length 20 --mode assembly \
  -o "$OUT/assembly-structure/kit-M4x20-assembly.step"
moon run --target native components/examples/extrusion_frame -- \
  --width 400 --depth 300 --height 500 --series 2020 \
  -o "$OUT/frame-2020-400x300x500.step" --views "$OUT/views"
moon run --target native components/examples/extrusion_frame -- \
  --width 600 --depth 300 --height 400 --series 2020 \
  -o "$OUT/frame-2020-600x300x400.step"
moon run --target native components/examples/extrusion_frame -- \
  --width 45 --depth 45 --height 45 --series 2020 \
  -o "$OUT/frame-2020-45x45x45.step"
moon run --target native components/examples/gear_pair -- \
  --module 2 --teeth 20 --mateTeeth 40 \
  -o "$OUT/gear-pair-m2-20x40.step"
moon run --target native components/examples/planetary -- \
  -o "$OUT/planetary-m2-s12-p12-r36-3.step"
moon run --target native components/examples/motion_stack -- \
  --bearing 608 -o "$OUT/motion-608-stack.step"
moon run --target native components/examples/spring -- \
  -o "$OUT/spring-10x1x20.step"

echo "Validating generated fixtures..."
for f in "$OUT"/*.step; do
  echo "== $(basename "$f")"
  python3 "$ROOT/scripts/validate_step.py" --no-mesh "$f"
done

echo "Independent frame geometry validation (OCCT, optional)..."
set +e
python3 "$ROOT/scripts/validate_frame_geometry.py" \
  "$OUT/frame-2020-400x300x500.step" \
  --width 400 --depth 300 --height 500 --series 2020
main_status=$?
python3 "$ROOT/scripts/validate_frame_geometry.py" \
  "$OUT/frame-2020-600x300x400.step" \
  --width 600 --depth 300 --height 400 --series 2020
wide_status=$?
python3 "$ROOT/scripts/validate_frame_geometry.py" \
  "$OUT/frame-2020-45x45x45.step" \
  --width 45 --depth 45 --height 45 --series 2020
small_status=$?
set -e
for status in "$main_status" "$wide_status" "$small_status"; do
  if [ "$status" -eq 2 ]; then
    echo "frame geometry check skipped: OCCT not installed"
  elif [ "$status" -ne 0 ]; then
    echo "frame geometry validation failed" >&2
    exit "$status"
  fi
done
