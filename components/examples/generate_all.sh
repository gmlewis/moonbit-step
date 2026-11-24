#!/usr/bin/env bash
# Regenerate every component fixture and run the repository STEP validator on
# each flat part/assembly. OCCT (DRAWEXE or occt-draw) and gmsh are optional;
# they are used automatically when present.
#
# Usage: ./generate_all.sh [--clean] [--no-evaluated]
#   --clean         remove prior generated STEP/STL/SVG/PNG files under output/
#                   before regenerating (recommended after changing builders)
#   --no-evaluated  skip the slow OCCT-evaluated mechanism fixtures
set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT="$ROOT/components/examples/output"
CLEAN=0
EVALUATED=1
for arg in "$@"; do
  case "$arg" in
    --clean) CLEAN=1 ;;
    --no-evaluated) EVALUATED=0 ;;
    -h | --help)
      sed -n '6,9p' "$0"
      exit 0
      ;;
    *)
      echo "unknown option: $arg (use --clean or --no-evaluated)" >&2
      exit 2
      ;;
  esac
done
mkdir -p "$OUT" "$OUT/assembly-structure"
if [ "$CLEAN" -eq 1 ]; then
  rm -f "$OUT"/*.step "$OUT"/*.stl "$OUT"/*.svg "$OUT"/*.png
  rm -f "$OUT/assembly-structure"/*.step
  rm -rf "$OUT/views"
fi
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
moon run components/examples/bevel_gear -- \
  --module 2 --teeth 20 --mateTeeth 40 --faceWidth 10 --bore 6 \
  -o "$OUT/bevel-gear-m2-z20-d26.6.step"
moon run components/examples/bevel_gear -- \
  --module 2 --teeth 20 --mateTeeth 20 --faceWidth 8 --bore 6 \
  -o "$OUT/bevel-gear-m2-z20-miter.step"
moon run components/examples/bevel_gear -- \
  --module 2 --teeth 16 --pitchAngle 30 --faceWidth 8 \
  -o "$OUT/bevel-gear-m2-z16-d30-standalone.step"
moon run components/examples/bevel_gear -- \
  --module 2 --teeth 20 --mateTeeth 40 --faceWidth 10 --backlash 0.05 --pair \
  -o "$OUT/bevel-gear-pair-m2-20x40.step"
moon run components/examples/bevel_gear -- \
  --module 2 --teeth 20 --mateTeeth 40 --faceWidth 10 --bore 6 --rootFillet 0.2 \
  --tipChamfer 0.1 --endFace flat \
  -o "$OUT/bevel-gear-m2-z20-filleted-flat.step"
moon run components/examples/bevel_gear -- \
  --module 2 --teeth 20 --mateTeeth 20 --faceWidth 10 --bore 15 \
  --hubDiameter 34 --hubLength 14 -o "$OUT/bevel-gear-m2-z20-miter-catalog.step"
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
moon run components/examples/brushless_motor -- \
  -o "$OUT/brushless-motor-50x23.step"
moon run components/examples/a12_motor -- -o "$OUT/a12-8318-motor-91x33.step"
moon run components/examples/tire -- -o "$OUT/tire-177.8x38.1.step"
moon run components/examples/tire_mount -- -o "$OUT/tire-mount-86.3x23.05.step"
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
moon run components/examples/stock_primitive -- \
  --part heat-boss -o "$OUT/heat-set-boss-m3x4.step"

# Generic mechanism and structural primitives plus the design-from-scratch
# example. Every artifact is validated by the loop below.
for part in hinge clevis pin rod-end linkage rail carriage lead-screw lead-nut \
  belt belt-unequal cam roller oldham extension-spring torsion-spring snap \
  o-ring grooved-shaft bracket u-bracket z-bracket boss rack sprocket \
  chain-segment; do
  moon run components/examples/mechanism_kit -- \
    --part "$part" -o "$OUT/mechanism-$part.step"
done
moon run components/examples/mechanism_design -- \
  --length 140 --width 24 --pivot 8 \
  -o "$OUT/mechanism-design-linkage.step"
moon run components/examples/mechanism_design -- \
  --variant compact -o "$OUT/mechanism-design-linkage-compact.step"
moon run components/examples/mechanism_assembly -- \
  -o "$OUT/mechanism-clevis-rod-end.step"
moon run components/examples/mechanism_assembly -- --mode assembly \
  -o "$OUT/assembly-structure/mechanism-clevis-rod-end-assembly.step"
moon run components/examples/belt_drive -- \
  --teethA 20 --teethB 40 --pitchLength 400 \
  -o "$OUT/belt-drive-gt2-20x40.step"
moon run components/examples/belt_drive -- --mode assembly \
  --teethA 20 --teethB 40 --pitchLength 400 \
  -o "$OUT/assembly-structure/belt-drive-gt2-20x40-assembly.step"
moon run components/examples/rack_pinion -- \
  --module 2 --pinionTeeth 20 --rackTeeth 20 \
  -o "$OUT/rack-pinion-m2-z20x20.step"
moon run components/examples/rack_pinion -- --mode assembly \
  --module 2 --pinionTeeth 20 --rackTeeth 20 \
  -o "$OUT/assembly-structure/rack-pinion-m2-z20x20-assembly.step"
moon run components/examples/four_bar -- \
  --ground 40 --crank 10 --coupler 40 --rocker 30 --crankAngle 45 \
  -o "$OUT/four-bar-40-10-40-30.step"
moon run components/examples/four_bar -- --mode assembly \
  --ground 40 --crank 10 --coupler 40 --rocker 30 --crankAngle 45 \
  -o "$OUT/assembly-structure/four-bar-40-10-40-30-assembly.step"

# Maker Store USA parts (calibrated L plates and provenance presets).
moon run components/examples/makerstore_l_plate -- \
  -o "$OUT/makerstore-l-plate-40x40.step"
moon run components/examples/makerstore_l_plate -- \
  --part l40x80 -o "$OUT/makerstore-l-plate-40x80.step"
moon run components/examples/makerstore_hardware -- \
  --part spacer --length 10 -o "$OUT/makerstore-spacer-od10-id5x10.step"
moon run components/examples/makerstore_hardware -- \
  --part thrust --size F5-10M -o "$OUT/makerstore-thrust-f5-10m.step"
moon run components/examples/makerstore_hardware -- \
  --part tnut20 --thread M5 -o "$OUT/makerstore-tnut20-m5.step"
moon run components/examples/makerstore_hardware -- \
  --part tnut40 --thread M6 -o "$OUT/makerstore-tnut40-m6.step"
moon run components/examples/makerstore_hardware -- \
  --part bracket --leg 20 -o "$OUT/makerstore-bracket-20.step"
moon run components/examples/makerstore_hardware -- \
  --part bracket --leg 40 -o "$OUT/makerstore-bracket-40.step"
# goBILDA grid plates (4 mm holes on the 8 mm pattern).
moon run components/examples/gobilda_kit -- -o "$OUT/gobilda-grid-plate-5x5.step"
moon run components/examples/gobilda_kit -- \
  --cols 11 --rows 29 -o "$OUT/gobilda-grid-plate-11x29.step"
# Component examples that previously had no generator entry. Each is covered
# by the validation loop below, just like every other generated fixture.
moon run components/examples/makerpipe_frame -- -o "$OUT/makerpipe-frame.step"
moon run components/examples/makerpipe_kit -- -o "$OUT/makerpipe-kit.step"
moon run components/examples/mate_assembly -- -o "$OUT/mate-assembly.step"
moon run components/examples/profile_extrusion -- -o "$OUT/profile-extrusion.step"
moon run components/examples/pvc -- -o "$OUT/pvc.step"
moon run components/examples/rivet -- -o "$OUT/rivet.step"

echo "Validating generated fixtures..."
for f in "$OUT"/*.step; do
  echo "== $(basename "$f")"
  python3 "$ROOT/scripts/validate_step.py" --no-mesh "$f"
done
echo "== assembly-structure/kit-M4x20-assembly.step"
python3 "$ROOT/scripts/validate_step.py" --no-mesh \
  "$OUT/assembly-structure/kit-M4x20-assembly.step"
echo "== assembly-structure/mechanism-clevis-rod-end-assembly.step"
python3 "$ROOT/scripts/validate_step.py" --no-mesh \
  "$OUT/assembly-structure/mechanism-clevis-rod-end-assembly.step"
echo "== assembly-structure/belt-drive-gt2-20x40-assembly.step"
python3 "$ROOT/scripts/validate_step.py" --no-mesh \
  "$OUT/assembly-structure/belt-drive-gt2-20x40-assembly.step"
echo "== assembly-structure/rack-pinion-m2-z20x20-assembly.step"
python3 "$ROOT/scripts/validate_step.py" --no-mesh \
  "$OUT/assembly-structure/rack-pinion-m2-z20x20-assembly.step"
echo "== assembly-structure/four-bar-40-10-40-30-assembly.step"
python3 "$ROOT/scripts/validate_step.py" --no-mesh \
  "$OUT/assembly-structure/four-bar-40-10-40-30-assembly.step"

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
moon run components/examples/motion_stack -- \
  --part idler --idlerOuter 20 --idlerBore 8 --idlerWidth 10 \
  --idlerFlangeDiameter 24 --idlerFlangeThickness 1.5 \
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
moon run components/examples/din472_ring -- \
  --size 20 -o "$OUT/din472-20.step"
# A parametric table size (no measured reference; flat writer, no OCCT needed).
moon run components/examples/din472_ring -- \
  --size 22 -o "$OUT/din472-22-parametric.step"
moon run components/examples/adapters -- \
  --part motor -o "$OUT/motor-to-extrusion-adapter.step"
moon run components/examples/adapters -- \
  --part channel -o "$OUT/channel-to-extrusion-adapter.step"
moon run components/examples/stepper_motor -- \
  --mountingPlate -o "$OUT/nema-mounting-plate.step"
moon run components/examples/motion_stack -- \
  --part standoff -o "$OUT/standoff.step"
moon run components/examples/motion_stack -- \
  --part dowel -o "$OUT/dowel-pin.step"
moon run components/examples/motion_stack -- \
  --part gt2-pulley -o "$OUT/gt2-pulley-20t.step"
# The set-screw collar's primary artifact is the OCCT-evaluated trimmed solid.
if command -v python3 >/dev/null 2>&1 &&
  { command -v DRAWEXE >/dev/null 2>&1 ||
    command -v occt-draw >/dev/null 2>&1; }; then
  moon run components/examples/set_screw_collar -- \
    --bore 8 --outer 16 --width 8 --thread M4 --drill 4.1 \
    --screw M4 --screwLength 4.0 \
    -o "$OUT/set-screw-collar-d8.step"
  python3 "$ROOT/scripts/validate_step.py" "$OUT/set-screw-collar-d8.step"
  moon run components/examples/clamp_shaft_collar -- \
    --bore 20 --outer 40 --width 15 --thread M6 --screwOffset 14.73 \
    --screw M6 --screwLength 16 \
    -o "$OUT/clamp-collar-d20.step"
  python3 "$ROOT/scripts/validate_step.py" "$OUT/clamp-collar-d20.step"
  moon run components/examples/stock_primitive -- \
    --part sc8uu -o "$OUT/sc8uu-bearing-block.step"
  python3 "$ROOT/scripts/validate_step.py" "$OUT/sc8uu-bearing-block.step"
  moon run components/examples/motion_stack -- \
    --part pillow-block --pillowBlock UCP204 \
    -o "$OUT/ucp204-pillow-block.step"
  python3 "$ROOT/scripts/validate_step.py" "$OUT/ucp204-pillow-block.step"
  moon run components/examples/motion_stack -- \
    --part helical-coupling -o "$OUT/helical-coupling-5-to-8.step"
  python3 "$ROOT/scripts/validate_step.py" "$OUT/helical-coupling-5-to-8.step"
  moon run components/examples/din472_ring -- \
    --size 10 -o "$OUT/din472-10.step"
  python3 "$ROOT/scripts/validate_step.py" "$OUT/din472-10.step"
  moon run components/examples/din472_ring -- \
    --size 40 -o "$OUT/din472-40.step"
  python3 "$ROOT/scripts/validate_step.py" "$OUT/din472-40.step"
  moon run components/examples/adapters -- \
    --part clamp -o "$OUT/tube-to-extrusion-clamp.step"
  python3 "$ROOT/scripts/validate_step.py" "$OUT/tube-to-extrusion-clamp.step"
else
  echo "skipping evaluated collars, chamfered retaining rings, pillow blocks, and the tube clamp: evaluated export needs python3 and OCCT" >&2
fi
for part in vslot-2020x100 vslot-2040x100 vslot-wheel vslot-tnut-m5 \
  vslot-joining-plate vslot-corner-bracket vslot-spacer-10x5x6 \
  vslot-eccentric-spacer plate-counterbore-50x40x8 bearing-plate-od22 \
  idler-flanged-20x10 \
  emt-1-2in-304 shaft-collar-d8 tube-mount-plate \
  makerbeam-1010-l100 din471-a20 din472-20 din472-22-parametric \
  motor-to-extrusion-adapter channel-to-extrusion-adapter \
  nema-mounting-plate standoff dowel-pin gt2-pulley-20t \
  clamp-collar-d20 sc8uu-bearing-block heat-set-boss-m3x4 \
  mechanism-hinge mechanism-clevis mechanism-pin mechanism-rod-end mechanism-linkage \
  mechanism-rail mechanism-carriage mechanism-lead-screw \
  mechanism-lead-nut mechanism-belt mechanism-belt-unequal mechanism-cam mechanism-roller \
  mechanism-oldham mechanism-extension-spring mechanism-torsion-spring \
  mechanism-snap mechanism-o-ring mechanism-grooved-shaft \
  mechanism-bracket mechanism-u-bracket mechanism-z-bracket \
  mechanism-boss mechanism-rack mechanism-sprocket \
  mechanism-chain-segment \
  mechanism-design-linkage mechanism-design-linkage-compact \
  mechanism-clevis-rod-end belt-drive-gt2-20x40 rack-pinion-m2-z20x20 \
  four-bar-40-10-40-30; do
  python3 "$ROOT/scripts/validate_step.py" --no-mesh "$OUT/$part.step"
done

# OCCT-evaluated mechanism fixtures: fuse the layered bodies into one trimmed
# manifold and run the full validator (including tessellation).
if [ "$EVALUATED" -eq 1 ] && command -v python3 >/dev/null 2>&1 &&
  { command -v DRAWEXE >/dev/null 2>&1 ||
    command -v occt-draw >/dev/null 2>&1; }; then
  for part in hinge rail carriage bracket oldham; do
    moon run components/examples/mechanism_kit -- \
      --part "$part" --evaluated -o "$OUT/mechanism-$part-evaluated.step"
    python3 "$ROOT/scripts/validate_step.py" "$OUT/mechanism-$part-evaluated.step"
  done
  for teeth in 16 24; do
    moon run components/examples/mechanism_kit -- \
      --part sprocket --sprocketTeeth "$teeth" --evaluated \
      -o "$OUT/mechanism-sprocket-${teeth}t-evaluated.step"
    python3 "$ROOT/scripts/validate_step.py" \
      "$OUT/mechanism-sprocket-${teeth}t-evaluated.step"
  done
else
  echo "skipping evaluated mechanism fixtures: --no-evaluated or OCCT unavailable" >&2
fi

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
