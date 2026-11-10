# Progress

## Baseline

- Repository: `gmlewis/step` (working checkout `moonbit-17-step`).
- MoonBit toolchain: `moon 0.1.20261104`, `moonc v0.10.20+65efd5b93`.
- Baseline `./test-all.sh`: **345 tests, 345 passed, 0 failed** before the
  component work.
- Optional tools detected: OCCT `DRAWEXE` at `/opt/homebrew/bin/DRAWEXE`,
  gmsh at `/opt/homebrew/bin/gmsh`, `scripts/validate_step.py`,
  macOS `sips`.

## Completed

### Foundations
- `components/common`: validation (`SpecError`), detail levels, explicit thread
  representation, provenance metadata, rigid `Placement`, immutable
  `Component` with layers and deterministic names.
- `components/standards`: metric sizes M2–M20, coarse/fine pitches, ISO 68-1
  derived thread dimensions, ISO 4762, ISO 4032, ISO 7089, ISO 4014/4017,
  DIN 976-1 tables and validated specs.

### Fasteners
- ISO 4762 socket head cap screws (M3/M4/M5 explicitly tested; M2–M20 table).
- ISO 4032 hex nuts (M3/M4/M5 tested).
- ISO 7089 plain washers (M3/M4/M5 tested).
- ISO 4017 fully threaded hex head screws.
- ISO 4014 partially threaded hex head bolts.
- DIN 976-1 threaded rods.
- Helical thread representation: swept external and internal ridges.
- Built-in catalog generation for M3/M4/M5.

### Assemblies
- `Assembly` with rigid placements, unique instance names, linear and circular
  patterns, flat export, and assembly/product export.
- `metric_hardware_kit` (screw + washer + nut).
- `fastener_grid_plate` (rectangular fastener pattern).
- `extrusion_frame` (4 posts + 8 rails).

### Profiles and motion
- Generic T-slot profiles: 2020, 2040, 3030, 4040 with configurable section.
- Cut-to-length extrusion components.
- Shafts, stepped shafts, spacers, bushings, keys, dowel pins, hex standoffs,
  compression springs.
- Common bearing boundary table and simplified bearing envelope (rings +
  cylindrical roller proxies).

### Gears
- Involute gear radii and outline generation.
- External spur gears with module, teeth, pressure angle, face width, bore,
  backlash, and resolution controls.
- External gear pair assembly with standard centre distance and phase.
- Approximate straight-spur planetary set (sun + equally spaced planets +
  approximate internal ring), with the standard tooth-count and spacing
  conditions enforced.

### Examples and artifacts
- `components/examples/fasteners` (single part + catalog generator).
- `components/examples/hardware_kit`.
- `components/examples/extrusion_frame`.
- `components/examples/gear_pair`.
- `components/examples/planetary`.
- `components/examples/motion_stack`.
- `components/examples/spring`.
- Generated STEP files in `components/examples/output/`:
  - ISO 4762 M3/M4/M5 screw set + M4x20.
  - ISO 4032 M3/M4/M5 nuts.
  - ISO 7089 M3/M4/M5 washers.
  - Fully modeled M4x20 screw and M3/M4/M5 nuts.
  - M4x20 hardware kit (flat + assembly structure).
  - ISO 4017 M5x20, ISO 4014 M8x40, DIN 976 M8x200.
  - 2020 T-slot frame 400 x 300 x 500.
  - 20/40-tooth gear pair.
  - 12/12/36 three-planet planetary set.
  - 608 bearing / shaft / spacer stack.
  - 10 x 1 x 20 compression spring.

## Current status

- Full test suite is kept green (`./test-all.sh`): **408 tests, 408 passed,
  0 failed** (baseline was 345).
- Representative generated files pass `scripts/validate_step.py` with OCCT
  `checkshape` and watertight tessellation.
- Flat assembly exports pass the full validator. The STEP product-structure
  export passes all non-OCCT checks; see `KNOWN_ISSUES.md`.

## Next tasks (priority order)

1. Add button-head (ISO 7380) and countersunk (ISO 10642) screw builders after
   verifying the exact dimensional tables.
2. Replace the approximate internal ring gear with an exact internal involute
   envelope and verify tooth contact in the planetary set.
3. Add T-nuts, corner brackets, and end caps for the extrusion system only when
   verified data is available.
4. Add a machine-readable component catalog/query API.
5. Add springs, threaded inserts, pins, and standoffs.
6. Consider adding a `Sphere` shape and analytic B-Rep compiler to `@cad` so
   bearings can carry true balls; this is an upstream extension, not a
   component-package workaround.

## Reproduction commands

```bash
./test-all.sh

moon run --target native components/examples/fasteners -- \
  --standard iso4762 --size M4 --length 20 --detail fully-modeled \
  -o components/examples/output/iso4762-M4x20-fully-modeled.step

moon run --target native components/examples/hardware_kit -- \
  --size M4 --length 20 -o components/examples/output/kit-M4x20-flat.step

moon run --target native components/examples/extrusion_frame -- \
  --width 400 --depth 300 --height 500 --series 2020 \
  -o components/examples/output/frame-2020-400x300x500.step

moon run --target native components/examples/gear_pair -- \
  --module 2 --teeth 20 --mateTeeth 40 \
  -o components/examples/output/gear-pair-m2-20x40.step

moon run --target native components/examples/planetary -- \
  -o components/examples/output/planetary-m2-s12-p12-r36-3.step

moon run --target native components/examples/motion_stack -- \
  --bearing 608 -o components/examples/output/motion-608-stack.step

for f in components/examples/output/*.step; do
  python3 scripts/validate_step.py --no-mesh "$f"
done
```
