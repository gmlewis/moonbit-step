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

# Screw placed in a nut by named mate connectors
moon run components/examples/mate_assembly -- --size M4 --length 20 -o mate.step

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
| `common` | Units-aware validation, detail levels, thread representation, metadata, placement, `Component`, `MateConnector`, and `MatePair`. |
| `standards` | Metric thread data and ISO/DIN dimension tables (ISO 4032/4035/4762/7089/709x/7380/8752/10642, DIN 557/913/916/976/1587, …). |
| `fasteners` | Screws, bolts, nuts, washers, pins, rods, and set screws. |
| `profiles` | Generic T-slot sections and the vendor 2020 B-slot6 A section. |
| `motion` | Shafts, stepped/keyed shafts, spacers, bushings, keys, dowel pins, standoffs, compression springs, ball bearings, LM-series linear bushings, flanged linear housings, and approximated GT2 timing pulleys. |
| `motors` | NEMA 17 and NEMA 23 stepper-motor envelopes, mounting interfaces, and NEMA mounting plates. |
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

## Mate connectors and pairs

`MateConnector` is a named attachment frame on one component. `MatePair` is the
relationship between two named connectors. Both types are defined once in
`components/common`; `gmlewis/urdf` and `gmlewis/cad` import them rather than
keeping local copies.

```moonbit
let hole = @common.MateConnector::new(
  "bore",
  placement=@common.Placement::translation(0.0, 0.0, 0.0),
  axis=(0.0, 0.0, 1.0),
  kind=@common.MateKind::CylindricalBore,
  gender=@common.MateGender::Female,
  diameter_mm=5.0,
  depth_mm=10.0,
)

let pair = @common.MatePair::new(parent="bore", child="shaft", offset_mm=2.0)
let alignment = pair.resolve(parent_connector, child_connector)
```

- **Units.** The connector stores a `Placement` in millimetres and degrees. At a
  URDF boundary use `from_m_rad` and `to_m_rad`, which convert to and from
  metres/radians.
- **Axis.** `axis` is an independent unit direction in the component-local
  frame, not the placement's +Z. It is the insertion, approach, or joint axis.
- **Names.** Names are stable, unique within a component, and lower-case
  kebab-case (`shaft`, `bore`, `mount-front`, `bolt-hole-1`).
- **Kinds and genders.** `MateKind` classifies the interface; `MateGender`
  describes geometric engagement, never strength. A bore is female, a shaft is
  male, and datum/plane/slot frames are neutral.
- **Fit.** `fit` reuses `@cad.Fit`; it records declared clearance intent and does
  not change the nominal STEP geometry.
- **Snapping.** `snap_connectors` reproduces the URDF offset/twist/flip frame
  snap. `MatePair::resolve` additionally checks kind, gender, diameter, and fit,
  and records any interface-convention axis flip in `MateAlignment`.
- **Assembly.** `Assembly::add_mate_pair(parent_instance, child, pair)` resolves
  the pair against a placed parent and returns the updated assembly plus the
  alignment.

Connectors are metadata: adding one, rebasing a component to a connector, or
resolving a pair never changes exported STEP geometry, layer count, or volume.
A geometric mate is not a structural-strength or safety claim.

Every implemented family exposes at least one named connector: fasteners expose
shaft/thread/head or bore/bearing-face frames, bearings expose bore and
outer-seat frames, shafts expose end frames, extrusions expose four face slots
and end datums, NEMA motors expose mounting, pilot, shaft, rear, and per-hole
frames, and plates expose face and per-hole frames.

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
- V-Slot and EMT/conduit-specific mating geometry are not implemented. The
  available step.parts V-Slot models do not encode the real V lips and were not
  accepted as golden references.
- GT2 timing pulleys use an approximate trapezoidal tooth form built from the
  published 2 mm pitch, 0.254 mm pitch-line offset, 0.76 mm depth, and 1.49 mm
  width. They are a prototyping approximation, not a licensed exact profile,
  and carry no torque or belt-life rating.
- NEMA mounting plates are generic plate blanks with the frame bolt pattern and
  pilot clearance bore. Plate size, thickness, and clearance are caller
  parameters; no stiffness or strength rating is implied.

## License

Apache-2.0, matching the parent repository.
