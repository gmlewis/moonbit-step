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

moon run components/examples/fasteners -- --catalog "$OUT"
moon run components/examples/hardware_kit -- \
  --size M4 --length 20 -o "$OUT/kit-M4x20-flat.step"
moon run components/examples/hardware_kit -- \
  --size M4 --length 20 --mode assembly \
  -o "$OUT/assembly-structure/kit-M4x20-assembly.step"
moon run components/examples/extrusion_frame -- \
  --width 400 --depth 300 --height 500 --series 2020 \
  -o "$OUT/frame-2020-400x300x500.step" --views "$OUT/views"
moon run components/examples/extrusion_frame -- \
  --width 600 --depth 300 --height 400 --series 2020 \
  -o "$OUT/frame-2020-600x300x400.step"
moon run components/examples/extrusion_frame -- \
  --width 45 --depth 45 --height 45 --series 2020 \
  -o "$OUT/frame-2020-45x45x45.step"
moon run components/examples/gear_pair -- \
  --module 2 --teeth 20 --mateTeeth 40 \
  -o "$OUT/gear-pair-m2-20x40.step"
moon run components/examples/planetary -- \
  -o "$OUT/planetary-m2-s12-p12-r36-3.step"
moon run components/examples/motion_stack -- \
  --bearing 608 -o "$OUT/motion-608-stack.step"
moon run components/examples/spring -- \
  -o "$OUT/spring-10x1x20.step"
# New feature-geometry artifacts (Stage G/H/I).
moon run components/examples/revolution -- --out-dir "$OUT"
for std in iso4762 iso4032; do
  moon run components/examples/fasteners -- \
    --standard "$std" --size M4 --length 20 --detail detailed \
    -o "$OUT/$std-M4-detailed.step"
done
for std in iso7380 iso10642; do
  moon run components/examples/fasteners -- \
    --standard "$std" --size M4 --length 16 --detail detailed \
    -o "$OUT/$std-M4x16-detailed.step"
done
# Round-7 chamfer coverage: hex-head and rod lead-ins.
moon run components/examples/fasteners -- \
  --standard iso4017 --size M4 --length 20 --detail detailed \
  -o "$OUT/iso4017-M4x20-detailed.step"
moon run components/examples/fasteners -- \
  --standard iso4014 --size M4 --length 20 --detail detailed \
  -o "$OUT/iso4014-M4x20-detailed.step"
moon run components/examples/fasteners -- \
  --standard din976 --size M5 --length 50 --detail detailed \
  -o "$OUT/din976-M5x50-detailed.step"
moon run components/examples/fasteners -- \
  --standard iso7089 --size M4 --detail detailed \
  -o "$OUT/iso7089-M4-detailed.step"
moon run components/examples/motion_stack -- \
  --bearing 608 --detail detailed -o "$OUT/motion-608-stack-detailed.step"
moon run components/examples/filleted_shaft -- \
  --fillet 2 -o "$OUT/filleted-shaft-d10-16.step"
# Feature-record, catalogue, and mixed-assembly artifacts (Stage M/Q).
moon run components/examples/bearing -- \
  --bearing 608 --detail detailed -o "$OUT/bearing-608-detailed.step"
moon run components/examples/bolted_joint -- \
  --size M4 --width 40 --depth 30 --thickness 5 \
  -o "$OUT/bolted-joint-M4-2x5.step"
moon run components/examples/gear_pair -- \
  --module 2 --teeth 20 --mateTeeth 40 --rootFillet 0.4 --tipChamfer 0.1 \
  -o "$OUT/gear-pair-m2-20x40-filleted.step"
moon run components/examples/extrusion_frame -- \
  --width 200 --depth 200 --height 200 --series 2020 --cornerRadius 1.5 \
  -o "$OUT/frame-2020-200x200x200-rounded.step"
# Exact internal involute ring, keyed shaft, and single-gear fixtures (Stage H/K).
moon run components/examples/planetary -- \
  --sunTeeth 18 --planetTeeth 12 --planets 5 \
  -o "$OUT/planetary-m2-s18-p12-r42-5-exact.step"
moon run components/examples/keyed_shaft -- \
  --diameter 20 --length 40 --keywayWidth 6 --keywayDepth 3.5 \
  -o "$OUT/keyed-shaft-20x40.step"
moon run components/examples/gear_pair -- \
  --module 2 --teeth 40 --faceWidth 16 --bore 10 --single \
  -o "$OUT/gear-m2-z40-bore10.step"

echo "Validating generated fixtures..."
for f in "$OUT"/*.step; do
  echo "== $(basename "$f")"
  python3 "$ROOT/scripts/validate_step.py" --no-mesh "$f"
done
echo "== assembly-structure/kit-M4x20-assembly.step"
python3 "$ROOT/scripts/validate_step.py" --no-mesh \
  "$OUT/assembly-structure/kit-M4x20-assembly.step"

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
python3 "$ROOT/scripts/validate_frame_geometry.py" \
  "$OUT/frame-2020-200x200x200-rounded.step" \
  --width 200 --depth 200 --height 200 --series 2020 --corner-radius 1.5
rounded_status=$?
set -e
for status in "$main_status" "$wide_status" "$small_status" "$rounded_status"; do
  if [ "$status" -eq 2 ]; then
    echo "frame geometry check skipped: OCCT not installed"
  elif [ "$status" -ne 0 ]; then
    echo "frame geometry validation failed" >&2
    exit "$status"
  fi
done
