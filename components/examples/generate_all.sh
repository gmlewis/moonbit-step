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
  -o "$OUT/frame-2020-400x300x500.step"
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
