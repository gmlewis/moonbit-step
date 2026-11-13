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
moon run components/examples/fasteners -- \
  --standard din127 --size M4 --detail detailed \
  -o "$OUT/din127-M4-detailed.step"
moon run components/examples/fasteners -- \
  --standard din440 --size M5 --detail detailed \
  -o "$OUT/din440-M5-detailed.step"
moon run components/examples/fasteners -- \
  --standard din7349 --size M3 --detail detailed \
  -o "$OUT/din7349-M3-detailed.step"
moon run components/examples/fasteners -- \
  --standard din913 --size M3 --length 5 --detail detailed \
  -o "$OUT/din913-M3x5-detailed.step"
moon run components/examples/fasteners -- \
  --standard din93 --size M4 --detail detailed \
  -o "$OUT/din93-M4-detailed.step"
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
# Session 12: construction hardware, motion, and stock primitives.
moon run components/examples/stepper_motor -- \
  --frame NEMA17 --bodyLength 40 -o "$OUT/nema17-l40.step"
moon run components/examples/linear_bearing -- \
  --bearing LM8UU -o "$OUT/lm8uu.step"
moon run components/examples/linear_bearing -- \
  --bearing LM8UU --flanged --orient-to-reference \
  -o "$OUT/lm8uu-flanged.step"
moon run components/examples/extrusion_hardware -- \
  --part tnut --thread M3 --slot 5 -o "$OUT/extrusion-tnut-M3.step"
moon run components/examples/extrusion_hardware -- \
  --part heat-set --length short -o "$OUT/heat-set-m3-short.step"
moon run components/examples/stock_primitive -- \
  --part angle --legA 40 --legB 40 --thickness 4 --rootRadius 6 \
  --toeRadius 3 --length 50 -o "$OUT/angle-en10056-40x40x4.step"
moon run components/examples/stock_primitive -- \
  --part plate --width 50 --height 50 --plateThickness 3 \
  -o "$OUT/plate-50x50x3.step"

echo "Validating generated fixtures..."
for f in "$OUT"/*.step; do
  echo "== $(basename "$f")"
  python3 "$ROOT/scripts/validate_step.py" --no-mesh "$f"
done
echo "== assembly-structure/kit-M4x20-assembly.step"
python3 "$ROOT/scripts/validate_step.py" --no-mesh \
  "$OUT/assembly-structure/kit-M4x20-assembly.step"

# Construction-system, tubing, and adapter primitives.
moon run components/examples/vslot -- \
  --part profile --profile 2020 --length 100 -o "$OUT/vslot-2020x100.step"
moon run components/examples/vslot -- \
  --part profile --profile 2040 --length 100 -o "$OUT/vslot-2040x100.step"
moon run components/examples/vslot -- --part wheel -o "$OUT/vslot-wheel.step"
moon run components/examples/vslot -- --part tnut -o "$OUT/vslot-tnut-m5.step"
moon run components/examples/vslot -- \
  --part plate --length 60 --width 20 --thickness 3 -o "$OUT/vslot-joining-plate.step"
moon run components/examples/vslot -- --part bracket -o "$OUT/vslot-corner-bracket.step"
moon run components/examples/vslot -- --part spacer -o "$OUT/vslot-spacer-10x5x6.step"
moon run components/examples/vslot -- \
  --part eccentric -o "$OUT/vslot-eccentric-spacer.step"
moon run components/examples/stock_primitive -- \
  --part counterbore --width 50 --height 40 --plateThickness 8 \
  --holeSpacing 24 --through 5.5 --counterbore 9 --counterboreDepth 2 \
  -o "$OUT/plate-counterbore-50x40x8.step"
moon run components/examples/stock_primitive -- \
  --part bearing --width 50 --height 40 --plateThickness 6 \
  --bearingOD 22 --fit 0.1 --boltDiameter 5.5 --holeSpacing 30 \
  -o "$OUT/bearing-plate-od22.step"
moon run components/examples/idler -- \
  --outer 20 --bore 8 --width 10 --flangeDiameter 24 --flangeThickness 1.5 \
  -o "$OUT/idler-flanged-20x10.step"
moon run components/examples/tubing -- \
  --part emt --trade 1/2 --length 304.8 -o "$OUT/emt-1-2in-304.step"
moon run components/examples/tubing -- \
  --part collar --bore 8 --outer 16 --width 8 -o "$OUT/shaft-collar-d8.step"
moon run components/examples/tubing -- \
  --part adapter --tubeOD 17.9324 --clearance 0.5 -o "$OUT/tube-mount-plate.step"
moon run components/examples/makerbeam -- \
  --length 100 -o "$OUT/makerbeam-1010-l100.step"
moon run components/examples/retaining_ring -- \
  --size 20 -o "$OUT/din471-a20.step"
for part in vslot-2020x100 vslot-2040x100 vslot-wheel vslot-tnut-m5 \
  vslot-joining-plate vslot-corner-bracket vslot-spacer-10x5x6 \
  vslot-eccentric-spacer plate-counterbore-50x40x8 bearing-plate-od22 \
  idler-flanged-20x10 \
  emt-1-2in-304 shaft-collar-d8 tube-mount-plate \
  makerbeam-1010-l100 din471-a20; do
  python3 "$ROOT/scripts/validate_step.py" --no-mesh "$OUT/$part.step"
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
