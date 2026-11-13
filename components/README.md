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

# OpenBuilds V-Slot system
moon run components/examples/vslot -- \
  --part profile --profile 2020 --length 100 -o vslot-2020.step
moon run components/examples/vslot -- --part wheel -o vwheel.step
moon run components/examples/vslot -- --part tnut -o vslot-tnut.step
moon run components/examples/vslot -- --part bracket -o bracket.step
moon run components/examples/vslot -- --part spacer -o spacer.step
moon run components/examples/vslot -- --part eccentric -o eccentric.step

# EMT tube, shaft collar, and tube mount plate
moon run components/examples/tubing -- \
  --part emt --trade 1/2 --length 304.8 -o emt.step
moon run components/examples/tubing -- \
  --part collar --bore 8 --outer 16 --width 8 -o collar.step

# Counterbored plate and smooth idler
moon run components/examples/stock_primitive -- \
  --part counterbore --width 50 --height 40 --plateThickness 8 \
  --holeSpacing 24 --through 5.5 --counterbore 9 --counterboreDepth 2 -o cb.step
moon run components/examples/stock_primitive -- \
  --part bearing --width 50 --height 40 --plateThickness 6 \
  --bearingOD 22 --fit 0.1 --boltDiameter 5.5 --holeSpacing 30 -o bearing.step
moon run components/examples/idler -- \
  --outer 20 --bore 8 --width 10 --flangeDiameter 24 --flangeThickness 1.5 -o idler.step

# EMT end cap and split clamp
moon run components/examples/tubing -- --part endcap --trade 1/2 -o endcap.step
moon run components/examples/tubing -- --part clamp --trade 1/2 -o clamp.step

# Countersunk plate and tube-to-V-Slot bracket
moon run components/examples/stock_primitive -- \
  --part countersink --width 50 --height 40 --plateThickness 8 \
  --holeSpacing 24 --through 5.5 --countersinkDiameter 9 \
  --countersinkDepth 2 -o countersink.step
moon run components/examples/stock_primitive -- \
  --part tube-bracket --tubeOD 17.9324 --tubeClearance 0.5 \
  --width 60 --height 40 -o tube-bracket.step

# P1000-style strut channel and channel nut
moon run components/examples/profile_extrusion -- \
  --profile channel-p1000 --length 1000 -o strut.step
moon run components/examples/profile_extrusion -- \
  --profile channel-nut --thread 5 -o channel-nut.step

# Rigid coupling and flanged bearing housing
moon run components/examples/motion_stack -- \
  --part coupling --couplingBore 8 --couplingOuter 16 \
  --couplingLength 20 -o coupling.step
moon run components/examples/motion_stack -- \
  --part flange-housing --housingBearingOD 22 \
  --housingBearingWidth 7 -o housing.step

# Generic solid rivet
moon run components/examples/rivet -- --shank 3 --length 10 -o rivet.step

# MakerBeam 10 x 10 mm extrusion (drawing article 100168)
moon run components/examples/makerbeam -- --length 100 -o makerbeam.step
moon run components/examples/makerbeam -- --length 250 --cornerRadius 0.2 -o mb.step

# DIN 471 type A external retaining ring (A 10 to A 34)
moon run components/examples/retaining_ring -- --size 20 -o din471-20.step

# Built-in M3/M4/M5 fastener catalogue
mkdir -p components/examples/output
moon run components/examples/fasteners -- --catalog components/examples/output
```

All dimensions are millimetres, Z is up, and components use the origins and
axes documented in each builder. Every `-o` path above is a local output.
`components/examples/output/` is generated by
`components/examples/generate_all.sh` and is Git-ignored: no STEP, STL, or SVG
example artifact is stored in this repository.

## Construction systems and commodity tubing

`profile` V-Slot parts use the OpenBuilds 20-series cross-section: 20 x 20 or
20 x 40, a 9.16 mm V mouth narrowing to a 6.25 mm neck, 90 degree included V
lips, an 11 mm cavity, 1.5 mm diagonal webs, and 4.2 mm core bores. V-Slot is
**not** the generic T-slot envelope in `profiles/tslot.mbt` and is not
interchangeable with a vendor B-slot6 section; keep the mating geometry with
the intended rail.

The V-wheel body is modelled at its published boundary (23.89 mm OD, 10.23 mm
wide, 90 degree groove, Ø16 bearing pockets, Ø11 mid-lip bore). Bearing pockets
and core bores are analytic cylinders. Bearings, shims, threads, and structural
ratings are not modelled.

MakerBeam 10 x 10 mm uses the section of MakerBeam's drawing article 100168: a
3 mm slot on each face over a 41.1 degree dovetail undercut, a 4 x 4 mm core,
and a Ø2.5 mm centre bore that is the M3 end-thread tap drill. The section area
is 48.75 mm². It is **not** the generic T-slot or the OpenBuilds V-Slot section,
and a generic T-nut does not automatically fit it. MakerBeam's R0.2 drawing
radii and the M3 x 8 mm end threads are not modelled; the end threads are
declared by `end-thread-a`/`end-thread-b` connectors only. MakerBeamXL 15 x 15
and OpenBeam 15 x 15 are not implemented: their dimensioned sections could not
be obtained under usable terms.

EMT tubes use the measured ANSI C80.3 / UL 797 outside diameter and nominal
wall (a 1/2 in EMT is 17.9324 mm OD, not 12.7 mm). No coupling, thread, bend, or
electrical/structural rating is claimed. The EMT end cap is a spigot closure
sized from the tube OD/ID, and the split clamp is a generic one-bolt collar
whose ring is a slit tube and whose ears are separate prisms embedded into the
slit edges.

P1000-style strut channel uses the published 41.3 mm envelope, 2.6 mm (12
gauge) wall, 22.2 mm front opening, and 14.3 mm back-wall holes on 47.6 mm
centres. It is manufacturer-style geometry, not a universal standard; the
brand's serrated lip teeth, end treatment, and load rating are not modelled.
The channel nut is a generic block sized to enter the opening and bear on the
lips, not a vendor spring nut.

A conical countersink is not a prismatic cut. `plate_with_countersinks` builds
each seat as an exact annular wedge of revolution layered between a stepped
through-hole layer and a countersink-diameter layer, so the seat is a real
`CONICAL_SURFACE` and the layer volumes sum exactly. The layered split clamp and
the layered channel have the same property; where a layer deliberately embeds
into another (the clamp ears), the documentation states the embed and the union
is a nominal rather than a boolean result.

## Named connectors and the golden preview

Every public component builder exposes at least one named `MateConnector`
(`cylindrical-bore`, `cylindrical-shaft`, `plane-face`, `threaded`,
`profile-slot`, or `datum`). Connectors are metadata: they never add geometry,
change the volume or bounding box, or appear in the STEP file.

For developer inspection, `Component::connector_sidecar()` lists each
connector's origin, primary axis, and a deterministic secondary axis. The
secondary axis stays on a global axis unless the connector's placement
deliberately carries a twist. With `STEP_CONNECTOR_SIDECAR` set,
`Component::write_step` writes a sibling `<out>.connectors.tsv`.

`./compare-golden.sh` uses this by default: it generates the sidecar, opens the
golden and parametric pair in SolidCraft, and adds a named `joint.origin`
(`connector/<name>`) at every connector frame. SolidCraft's native joint
origins are the interactive equivalent of OnShape mate connectors; STEP itself
has no standard visual mate connector. The `joint.origin` frames are a
developer visualization only: they are application features in the running
SolidCraft session, never part geometry, and they do not change the STEP file,
its volume, bounding box, layer count, or golden measurement. A missing sidecar,
an unavailable GUI, a refused tab, or a failed `joint.origin` prints a note and
never fails generation or measurement. Use `--no-connectors` to disable the
frames or `--no-helper` to fall back to `open -a` without them; automated agents
use `--headless`.

## Package map

| Package | Contents |
|---|---|
| `common` | Units-aware validation, detail levels, thread representation, metadata, placement, `Component`, `MateConnector`, and `MatePair`. |
| `standards` | Metric thread data and ISO/DIN dimension tables (ISO 4032/4035/4762/7089/709x/7380/8752/10642, DIN 557/913/916/976/1587, …). |
| `fasteners` | Screws, bolts, nuts, washers, pins, rods, set screws, generic solid rivets, and DIN 471 type A external retaining rings (A 10 to A 34). |
| `profiles` | Generic T-slot sections, the vendor 2020 B-slot6 A section, OpenBuilds-compatible V-Slot 2020/2040 sections, the MakerBeam 10 x 10 section, a gusseted V-Slot corner bracket, P1000-style strut channel, and a generic channel nut. |
| `motion` | Shafts, stepped/keyed shafts, spacers and V-Slot wheel spacers (plain and eccentric), bushings, shaft collars, keys, dowel pins, standoffs, compression springs, ball bearings, LM-series linear bushings, flanged linear housings, approximated GT2 timing pulleys, smooth idlers, V-Slot wheels, EMT tubing with end caps and split clamps, rigid couplings, and flanged bearing housings. |
| `motors` | NEMA 17 and NEMA 23 stepper-motor envelopes, mounting interfaces, and NEMA mounting plates. |
| `stock` | EN 10056 angle sections, configurable flat plate blanks with analytic circular holes and obround slots, counterbored and countersunk plates, bearing-housing plates, and tube-to-plate and tube-to-V-Slot adapter brackets. |
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
- The EN 10056 angle root fillet is one analytic cylindrical surface; its toe
  radii are analytic arcs.
- A plate blank is a generic primitive. Hole patterns do not imply a
  standardized commercial part.
- V-Slot has real lip, cavity, web, and core-bore geometry, plus V-wheels,
  T-nuts, a gusseted corner bracket, and plain/eccentric wheel spacers. The
  V-Slot section is verified analytically; the wheel and corner-bracket goldens
  are Xem Studio references (CC BY 4.0). EMT coupling, clamp, and bracket
  accessories are not implemented yet.
- DIN 471 type A external retaining rings are flat stamped rings with two
  lugs, plier holes, a free bore, and a declared shaft-groove interface. The
  DIN 471 table (d1, s, d3, a, b, d5, d2, m, t, n) is cross-checked between two
  independent sources and covers A 10 to A 34. The *free-state outline*
  between the back and the lugs is not dimensioned by DIN 471; it is the
  published FreeCAD-library model geometry (CC BY 3.0, by nachotineo), so the
  model bore can differ from d3 by up to 0.13 mm. Sharp edges, no edge breaks,
  no spring temper, and no load or fatigue rating. The shaft groove is
  declared by the `groove-seat` connector but is not modelled.
- MakerBeam 10 x 10 is the exact dimensioned section of drawing article 100168
  (3 mm slot, 1 mm lip, 41.1 degree dovetail, 4 x 4 core, Ø2.5 bore), verified
  against an independent MIT-licensed implementation of the same drawing. The
  R0.2 drawing radii and M3 end threads are omitted. MakerBeamXL 15 x 15 and
  OpenBeam 15 x 15 are not implemented: the drawing folder is access-restricted
  and no licensed step model matched the published dimensions.
- GT2 timing pulleys use an approximate trapezoidal tooth form built from the
  published 2 mm pitch, 0.254 mm pitch-line offset, 0.76 mm depth, and 1.49 mm
  width. They are a prototyping approximation, not a licensed exact profile,
  and carry no torque or belt-life rating.
- NEMA mounting plates are generic plate blanks with the frame bolt pattern and
  pilot clearance bore. Plate size, thickness, and clearance are caller
  parameters; no stiffness or strength rating is implied.

## License

Apache-2.0, matching the parent repository.
