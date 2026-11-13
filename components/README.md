# Parametric Mechanical Components

A pure-MoonBit library for dimensioned mechanical components and assemblies that
export to STEP through the `gmlewis/step` CAD pipeline. The component packages
depend only on the root module: no native runtime, OCCT, or Python is required
to build models.

## Quick start

```bash
# One ISO 4762 M4 x 20 socket head cap screw
moon run components/examples/fasteners -- \
  --standard iso4762 --size M4 --length 20 --detail detailed -o M4x20.step

# Screw + washer + nut kit
moon run components/examples/hardware_kit -- --size M4 --length 20 -o kit.step

# Generic 2020 T-slot frame
moon run components/examples/extrusion_frame -- \
  --width 400 --depth 300 --height 500 --series 2020 -o frame.step

# Involute gear pair
moon run components/examples/gear_pair -- \
  --module 2 --teeth 20 --mateTeeth 40 -o gear-pair.step

# NEMA 17 stepper-motor envelope
moon run components/examples/stepper_motor -- \
  --frame NEMA17 --bodyLength 40 -o nema17.step

# LM8UU linear bushing and flanged housing
moon run components/examples/linear_bearing -- --bearing LM8UU -o lm8uu.step
moon run components/examples/linear_bearing -- \
  --bearing LM8UU --flanged -o lm8uu-flanged.step

# Extrusion T-nut or heat-set insert
moon run components/examples/extrusion_hardware -- \
  --part tnut --thread M3 --slot 5 -o tnut.step
moon run components/examples/extrusion_hardware -- \
  --part heat-set --length long -o heatset.step

# Steel angle or plate blank
moon run components/examples/stock_primitive -- \
  --part angle --legA 40 --legB 40 --thickness 4 --length 50 -o angle.step

# Built-in M3/M4/M5 fastener catalogue
mkdir -p components/examples/output
moon run components/examples/fasteners -- --catalog components/examples/output
```

All dimensions are millimetres, Z is up, and components use the origins and
axes documented in each builder.

## Package map

| Package | Contents |
|---|---|
| `common` | Units-aware validation, detail levels, thread representation, metadata, placement, `Component`. |
| `standards` | Metric thread data and ISO/DIN dimension tables (ISO 4032/4035/4762/7089/709x/7380/8752/10642, DIN 557/913/916/976/1587, …). |
| `fasteners` | Screws, bolts, nuts, washers, pins, rods, and set screws. |
| `profiles` | Generic T-slot sections and the vendor 2020 B-slot6 A section. |
| `motion` | Shafts, stepped/keyed shafts, spacers, bushings, keys, dowel pins, standoffs, compression springs, ball bearings, LM-series linear bushings, and flanged linear housings. |
| `motors` | NEMA 17 and NEMA 23 stepper-motor envelopes and mounting interfaces. |
| `stock` | EN 10056 angle sections and configurable flat plate blanks with through holes. |
| `gears` | Involute spur gears, external pairs, and exact-internal-involute planetary sets. |
| `assemblies` | Rigid placements, linear/circular patterns, hardware kits, extrusion frames, bolted joints, collision/contact reports, connectivity checks. |
| `collision` | Kernel-free AABB/OBB collision and contact classification. |
| `catalog` | Machine-readable catalogue/query API over the component families. |
| `examples/*` | Runnable generation programs and generated STEP output. |

## Verification

```bash
./test-all.sh
python3 scripts/compare_golden.py             # fixtures against the downloaded corpus
python3 scripts/validate_step.py components/examples/output/iso4762-M4x20.step
python3 scripts/validate_frame_geometry.py \
  components/examples/output/frame-2020-400x300x500.step \
  --width 400 --depth 300 --height 500 --series 2020
```

`validate_step.py` checks ISO 10303-21 syntax, references, per-shell topology
and orientation, PLANE planarity, OCCT `checkshape`, and watertight
tessellation. The validators and OCCT are optional development tools; the
library itself does not depend on them.

Assembly checks are available in MoonBit:

```moonbit
let collisions = assembly.collisions()
let contacts = assembly.contacts()
let floating = assembly.disconnected_instances()
```

## Limitations

- STEP booleans are nominal: geometry that needs a blind socket or a real trim
  is built as one closed solid with explicit faces, not as an untrimmed stack.
- Helical threads use the ISO 68-1 basic profile as a swept ridge. They are not
  tolerance-class threads and omit runout and root relief.
- Generic T-slot profiles are engineering envelopes, not a claim of
  cross-manufacturer compatibility. The 2020 B-slot6 A section is a faithful
  reproduction of its vendor reference.
- Extrusion frames use full-height posts and rails cut to the clear span;
  brackets, T-nuts, and end machining are not modelled.
- Bearing rolling elements are analytic spheres; ball diameter and ring
  chamfers are envelope geometry.
- Detailed fastener chamfers are real ruled or conical faces with
  engineering-default sizes where the standard leaves them open.
- Every component carries a machine-readable feature record (modeled,
  approximated with deviation, omitted with reason) in the STEP header.
- Evaluated 3D fillets/chamfers are optional (OCCT); the flat writer refuses
  them with a typed error.
- The internal ring gear uses an exact involute envelope with a declared
  `0.05 * module` backlash; profile shift, helix, and ring root fillets are
  omitted.
- NEMA motor envelopes model the mounting interface, pilot boss, and plain
  shaft. Body length and shaft length are parameters, not standards; electrical
  internals, rear shafts, shaft flats, and load ratings are omitted.
- LM-series linear bushings and flanged housings are boundary envelopes. Rolling
  elements, cages, seals, recirculation grooves, flange hole patterns, and load
  ratings are omitted.
- Extrusion T-nuts use one generic hex body for every catalogued retention
  style. The bore is a thread envelope; spring balls and style-specific
  retention are not modelled.
- Heat-set inserts model the two raised knurl bands as cylindrical reliefs, not
  a diamond knurl. Pull-out and torque strength require testing.
- The EN 10056 angle root fillet is sampled with 16 lines because the arc
  profile accepts only counter-clockwise minor arcs; its toe radii are analytic.
- A plate blank is a generic primitive. Hole patterns do not imply a
  standardized commercial part.
- V-Slot extrusion profiles, GT2 timing pulleys, and EMT/conduit fittings are
  not implemented. The available MIT-licensed step.parts V-Slot and GT2 models
  are smooth or simplified envelopes and do not encode the real mating geometry,
  so they were not accepted as golden references.

## License

Apache-2.0, matching the parent repository.
