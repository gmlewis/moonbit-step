# Known Issues and Deferred Features

## Audit issue register

All audit issues below are closed. A closed issue has a passing regression test
and independent validation. See `AUDIT.md` and `PROGRESS.md` for the evidence.

| ID | Severity | Component | Reproduction | Observed | Expected | Root cause | Regression test | Status |
|---|---|---|---|---|---|---|---|---|
| P0-1 | Critical | `assemblies/extrusion_frame` | generate 400x300x500 2020 frame; run `Assembly::collisions()` | 24 positive-volume overlaps (rails into posts and into each other) | rails cut to clear span; contacts only | cut length used `dimension - one profile size`, not `dimension - 2 * profile size` | `extrusion_frame_test.mbt` | closed |
| P0-2 | Critical | `profiles/tslot` | render `generic_2020().outline()` or the frame section view | self-intersecting outline; rectangular cavities overlap at the core corners | simple outline with four T-slots and four corner arrows | cavity back not relieved when it reaches the core corner | `profiles_test.mbt` section tests | closed |
| P1-1 | High | `gears/planetary_gear_set` | 18/12/42 with 5 planets; `gear_mesh_test.mbt` | 16 tooth-outline crossings | no tooth overlap over a mesh cycle | shared planet phase ignored the sun tooth phase | `gear_mesh_test.mbt` | closed |
| P2-1 | Medium | `assemblies/extrusion_frame` | width `= 2 * profile_width` | accepted, zero-length rail | reject impossible span | guard only compared against one profile size | `frame rejects spans that leave no rail length` | closed |
| P2-2 | Medium | validation | inspect test suite | frame defect invisible | independent interference/contact check | no collision facility existed | `collision_test.mbt`, frame tests | closed |
| P2-3 | Medium | validation | inspect STEP gate | validator checked topology but not frame member dimensions | independent post-export geometry check | no post-export schedule comparison | `scripts/validate_frame_geometry.py` | closed |
| P2-4 | Medium | golden references | measure step.parts models | M5 screw head 9.2 mm; M4 washer 1.8 mm | models should follow their claimed standards | external models can be nonconforming | `manifest.json` verdicts | recorded |

## Geometry limitations

1. **Nominal STEP booleans.** `@cad.difference()` and `@cad.union_all()` are
   nominal in the STEP backend. The component library avoids using them for
   real features, but components that are naturally layered export as several
   closed bodies. This is documented per family; do not expect one fused
   manifold from a layered screw.
2. **Head, socket, and tip chamfers are real but engineering defaults.** ISO
   4762 socket-head screws carry a 45° head top-edge chamfer, a socket lead-in
   chamfer (a tapered hex hole), and a shank tip chamfer at `Detailed` and
   above. ISO 4032 nuts carry 45° face chamfers on both faces at `Detailed` and
   above, including the fully modeled helical body. ISO 4017/4014 carry the
   exact 75° conical washer face (one `CONICAL_SURFACE` per corner patch,
   trimmed by the flats) and a tip chamfer; ISO 7380/10642 carry a
   socket lead-in and tip chamfer; DIN 976 carries engineering lead-in chamfers
   at both ends.
   These are real ruled ring stacks measured from the STEP. The standards do not
   fix most of these sizes, so the insets are declared engineering defaults.
   Under-head radii are still omitted (no verified value).
3. **No standards-defined thread runout or root relief.** The swept ridge ends
   are square cuts. DIN 976 ends carry a clearly labelled engineering lead-in
   chamfer; that is not a tolerance-class runout.
4. **No under-head radius or ISO 4032 bore-edge chamfer.** No verified
   standard/drawing value exists; both are typed omissions rather than guessed
   fillets/chamfers.
5. **Helical thread ridge uses the ISO 68-1 basic profile.** The radial
   placement, axial crest/root widths, 60-degree included angle, pitch, and
   handedness are exact basic-profile values (tests assert them for every
   supported size). Remaining approximations: it does not model tolerance
   classes, the root-radius relief of an actual thread, flank grind, or
   thread runout; the ends are square swept cuts. It is a real swept helix, not
   a cosmetic texture.
6. **Gear root fillet omitted.** Tooth flanks are involute; tip and root arcs
   are polygonal. Root fillets, tip chamfers, profile shift, and helix are not
   modeled.
7. **Gear pair is a static layout.** It uses the standard centre distance plus
   an offset and a half-pitch phase. It is not a kinematic solver and does not
   verify tooth contact.
8. **Internal ring gear is now an exact internal involute envelope.** The
   planetary set uses `internal_ring_gear_exact`; tooth thickness follows
   `psi(r) = psi_p + inv(a_r) - inv(a_p)` (thickness grows outward). The flanks
   are exact involutes sampled as polylines; tips and roots are polyline arcs.
   Internal meshes use a declared backlash of `0.05 * module` by default because
   a zero-backlash z36/z12 mesh grazes the ring tooth tip through part of the
   cycle. The trapezoidal `internal_ring_gear` remains an explicit fallback.
   Profile shift, helix, root fillets, and tip chamfers on the ring are omitted
   and recorded in its feature record.
9. **Bearing rolling elements are analytic spheres; internals are envelope
   geometry.** Balls are closed `SPHERICAL_SURFACE` solids, and the rings carry
   an engineering-default edge chamfer at `Detailed` and above. Ball diameter
   equals the modeled radial gap and the ring proportions are derived from the
   boundary dimensions, so this is not catalogue-internal geometry. Seals,
   cages, grooves, and bore chamfers are omitted.
10. **Stepped shafts are separate cylinders by default.** Sharp shoulders, no
    fillets or undercuts, at the plain builder. The new
    `filleted_stepped_shaft` builds a single revolved solid with analytic
    toroidal shoulder fillets on increasing steps; decreasing steps stay sharp
    and undercuts are not modeled. `keyed_shaft` cuts a real flat-bottomed
    rectangular keyway into the extruded section (one watertight solid); the
    keyway ends are square, not end-milled with a cutter radius, and the shaft
    has no chamfers.
11. **Springs are simplified.** Open helix with flat end caps; closed/ground
    ends, spring rate, and preload are not modeled.
12. **Standoffs, pins, and keys have no thread/tolerance model.** They are
    parametric shapes with explicit dimensions, not standard part numbers.
13. **T-slot profiles are generic envelopes.** Slot, neck, cavity, wall, and
    bore dimensions are engineering assumptions. They are not manufacturer
    compatible without verification. Section corners are sharp; end taps and
    machining are not modeled.
14. **Extrusion frame joints are simple butt contacts.** The frame now uses
    four full-height corner posts and eight rails cut to the clear span between
    post inner faces; members no longer interpenetrate. Corner brackets, end
    taps, T-nuts, and fasteners are not modeled. The profile is a generic
    envelope, not a manufacturer-compatible section.
15. **The generic 2020 profile is not the step.parts B-slot6 profile.** The
    reference `profile_2020_b_slot6_a_l50` is a manufacturer-specific B-type
    slot-6 section: 20 x 20 x 50 mm, volume 8716.82 mm^3, so its solid section
    area is about 174.336 mm^2. It has rounded outer corners and a lobed core
    region built from 2.75 mm-radius cylindrical/arc surfaces. The generic
    `generic-2020` envelope is 192.345108 mm^2 with sharp corners, a 4.2 mm
    bore, and simple T-slots. The two must not be described as equivalent.
    Exact B-slot6 support is deferred to the next session because it requires
    an arc-capable 2D section representation and verification of the
    reference's provenance. See `GOLDEN_REFERENCES.md`.

## API / packaging

1. **No separate `iso4762` package.** Functions live in
   `components/standards` and `components/fasteners` to avoid one trivial
   package per standard. The public functions are named `iso4762_spec`,
   `iso4762_screw`, etc.
2. **Optional thread override forwarding.** MoonBit optional named arguments
   cannot be forwarded as an option directly; wrapper functions use a `match`
   on `Some`/`None`. This is a readability cost only.
3. **Color defaults.** Components default to bright colors (blue/orange/green/
   purple/cyan) to keep previews readable. Pass `color=` where a neutral or
   material-specific color is required.

## Validation issues

1. **Assembly STEP product structure and the OCCT single-shape gate.**
   `Assembly::to_assembly_step()` writes a valid product/occurrence structure
   with `NEXT_ASSEMBLY_USAGE_OCCURRENCE` and
   `ITEM_DEFINED_TRANSFORMATION`. The repository validator checks syntax,
   references, shells, topology, orientation, and planarity successfully. Its
   OCCT stage cannot read an assembly as one topological shape, so
   `validate_step.py` now detects the assembly entity and reports the
   single-shape `checkshape`/mesh stages as `SKIP` with the reason instead of a
   false `FAIL`. Use a CAD assembly importer or the flat export
   (`Assembly::to_step()`) when a single-shape OCCT gate is required.
2. **Fully modeled files are large.** An M4x20 fully modeled screw is about
   2.2 MB at the default 24 segments per turn (it was ~4 MB at 48). A fully
   modeled nut is ~0.5 MB; simplified/detailed files are ~60 KB. Reduce
   `segments_per_turn` or use `Detailed` for catalog-wide generation when size
   matters.
3. **Swept-profile bounding boxes are now tight.** `@cad`'s `SweptProfile`
   bounding box follows the actual profile vertices through every path frame,
   so a thread or spring is no longer 5 mm larger in every direction. The box
   is still axis-aligned, so a rotated coil is conservative. This change makes
   `Component::size()` and the OBB collision phase meaningful for swept parts.
4. **Collision uses convex envelopes.** `components/collision` tests the OBB of
   each layer's local bounding box. For a T-slot extrusion the slots and core
   bore are not subtracted, and for a washer or nut the bore is not subtracted.
   A collision report is therefore conservative: it may report envelope overlap
   that the holes would avoid. It never reports a real overlap as clear. At
   frame corners the contacting material is solid, so the frame classification
   is exact. Nested-bore assemblies such as the hardware kit report envelope
   overlaps by construction; their coaxial alignment, bore clearance, and
   engagement are checked analytically in `assemblies_test.mbt`.
5. **Gear-mesh collision is a 2D outline test.** `gear_mesh_test.mbt` checks
   tooth-outline crossings across one mesh cycle and planet/ring clearance. It
   is not a 3D contact solver and does not model profile shift, helix, or load
   deformation.
6. **Golden files are a local download.** The open-source golden STEP models
   are downloaded by the repository owner into the Git-ignored `external/`
   directory, so the golden comparison is a documented fetch procedure rather
   than a hermetic test. Models that contradict their claimed standards are
   reported with measured evidence (see `GOLDEN_REFERENCES.md`).

## Deferred standards/components

- ISO 4762 additional lengths and preferred-length series outside the tested
  range.
- Fine-thread fasteners beyond the first-choice fine pitch per size.
- Threaded inserts, retaining rings, and additional verified nuts/washers.
- Helical gears, bevel gears, worm gears, timing belts/pulleys, sprockets.
- T-nuts, corner brackets, joining plates, end caps (no verified data).
- Couplings, linear rails, retaining rings/inserts (no verified data).
- Motor envelopes and mounting patterns.
- Exact B-slot6 extrusion (provenance).
- Multi-edge evaluated chamfers (the optional OCCT DRAW path is single-edge for
  chamfers; fillets support multi-edge `blend`).

Implemented in the feature session (previously deferred): ISO 7380-1 button
head screws, ISO 10642 countersunk head screws, bearing spheres, the 2D
chamfer/fillet helpers, `RevolvedProfile`, and `ChamferedPrism`. Their
approximations are recorded above and in `FEATURES.md`.

## Round-7 issues (2026-11-10)

### KI-25 — Partially threaded screws were threaded at the wrong end (fixed)

- Severity: high (engineering-invalid geometry; the nut of a bolted joint sat
  on an unthreaded shank).
- Reproduction before the fix: ISO 4762 M4 x 20 FullyModeled exported a plain
  shank at `z = 0..6` and the thread core/ridge at `z = 6..20`. ISO 4762
  measures `b = 2d + 6 = 14 mm` from the tip, so the thread must be
  `z = 0..14` and the plain shank `z = 14..20`.
- Root cause: the plain shank was added at `z = 0` and the thread core was
  placed at `z = plain_length`.
- Fix: thread core and ridge at `z = 0..thread_length`; plain shank at
  `z = thread_length`. The same fix applies to ISO 4014.
- Regression: `fasteners_test.mbt` asserts the placed layer positions for
  M4 x 20 and M8 x 80.

### KI-26 — Socket lead-in and tip chamfers were missing (implemented)

- Severity: medium (feature coverage).
- ISO 4762/7380/10642 sockets now have a real tapered hex lead-in at
  `Detailed`+, built with the new `ChamferedPrism` `hole_levels` ring stack.
  Shanks carry a 45° ruled tip chamfer. The measured vertex rings show the
  flared top hex and the reduced tip radius.
- `cad/chamfered_prism_wbtest.mbt` covers the tapered-hole face count,
  planarity, and cap-closure validation.

### KI-27 — Hex-head top chamfer was missing (implemented)

- Severity: medium (feature coverage).
- ISO 4017/4014 hex heads carry the exact 75° conical washer face at every
  detail level, plus a tip chamfer and a machine-readable feature record.
- The flat/cone intersection is emitted exactly: each flat ends in two
  hyperbolas, each chamfer patch is a trimmed `CONICAL_SURFACE` bounded by two
  hyperbolas and a circular top arc, and the top face is the circle of radius
  `s/2` tangent to every flat. The parametric head's volume matches the
  reference hex-head bolt exactly (475.479 mm³ for M5 × 20).

### KI-28 — Fully modeled nut body was not face-chamfered (implemented)

- Severity: medium (inconsistent detail level).
- The helical ISO 4032 body is now the same chamfered prism ring stack as the
  Detailed body, so face chamfers exist at `FullyModeled` too. The internal
  ridge is unchanged.

### KI-29 — Some downloaded golden models contradict their standards

- Severity: low (reference quality), but it must not be misreported.
- The golden files are downloaded from the open-source step.parts corpus by
  the repository owner; there are no licensing concerns.
- `scripts/golden_matrix.py` compares each part with the downloaded model using
  a rotation-invariant radius and axial extent. Models that contradict the
  standard are `FAIL` with measured evidence (for example ISO 4762 M2/M2.5/M5
  oversized heads, ISO 7089 thick washers, DIN 976 doubled length, ISO 4017
  head height). ISO 4014 has no downloaded partially-threaded model and is
  `SKIP`. Run the harness for the current per-family verdicts.

### KI-30 — Timestamp made the flat-export test flaky (fixed)

- Severity: low (test reliability).
- `cad/assembly_wbtest.mbt` compared two full STEP exports including the
  wall-clock `FILE_NAME` timestamp. When the two exports straddled a second
  boundary the test failed although the geometry was identical.
- Fix: compare the `DATA;` section (the geometry) and keep the assertion that
  no `NEXT_ASSEMBLY_USAGE_OCCURRENCE` appears in the flat export. This is the
  same approach the thread-handedness test already uses; no geometric assertion
  was weakened.

## Session issues (2026-11-10)

### KI-01 — ISO 10642 countersunk length was measured over the head incorrectly (fixed)

- Severity: high (dimensional error).
- Reproduction: `components/examples/fasteners --standard iso10642 --size M3
  --length 12` produced an overall z extent of 13.7 mm.
- Root cause: the head was placed above the shank instead of occupying the top
  `k` millimetres of the nominal length.
- Fix: the countersunk head now sits at `length - k`; the shank runs below it.
  Overall extent equals the nominal length.
- Regression: `fasteners_test.mbt` asserts 16.0 mm for M4 x 16; the golden
  harness asserts 12.0 mm for the M3 x 12 fixture.

### KI-02 — Exact internal involute ring gear (closed)

- Severity: medium (was a documented approximation).
- Resolved: `internal_involute_ring_profile` implements the exact internal
  involute relation, and `internal_mesh_interference` proves zero planet/ring
  outline crossings through a full rotation cycle (32 poses) for modules 1–3 and
  ring tooth counts 36/42/48. The earlier 300+ crossings came from using the
  external tooth-thickness sign and from tip grazing without backlash.
- The trapezoidal `internal_ring_gear` remains as an explicit fallback; the
  exact builder models `internal-involute-tooth-envelope` and the catalogue
  reports it.
- Regression: `components/gears/internal_gear_test.mbt` (including a
  zero-backlash control that must report crossings, proving the check is not
  vacuous).

### KI-03 — Gear root fillet polyline and adaptive band

- Severity: low.
- Root fillets are polyline arcs; the chord deviation is recorded
  (`fillet_segments`). For high tooth counts the root circle is close to the
  base circle, so the fillet widens its root band; if no band fits, the builder
  returns a typed error instead of a sharp root.

### KI-04 — Evaluated 3D chamfer is single-edge in this OCCT DRAW build

- Severity: low (optional path).
- `scripts/csg_eval.py` applies `chamf` to one selected edge per node; a
  selector matching multiple edges returns a typed error. Fillets support
  multi-edge `blend`. The flat writer refuses both intents with
  `EdgeFeatureRequiresKernel`.

### KI-05 — Nested-bore OBB collision false positives

- Severity: low (documented limitation).
- The collision facility uses oriented bounding boxes. A shank inside a plate
  or nut bore is reported as an overlap because the box contains the bore. This
  affects the hardware-kit and bolted-joint assemblies; connectivity and
  contacts are still meaningful. A shape-aware (B-Rep) clearance test is
  required to close this.


### KI-06 — Keyway ends are square (new)

- Severity: low (documented approximation).
- `keyed_shaft` cuts a flat-bottomed rectangular keyway with square ends. A real
  end-milled keyway has a cutter-radius bottom and rounded ends. The keyway is
  a real geometric notch in the extruded section (not a nominal boolean), but
  the end radius is omitted and recorded as `keyway-end-radius` in the feature
  record. A matching key is sized with a declared side clearance.

### KI-07 — Internal meshes need a declared backlash (new)

- Severity: low (documented engineering default).
- A zero-backlash internal mesh with a 12-tooth planet grazes the ring tooth
  tip through part of the rotation cycle. `planetary_gear_set` therefore applies
  `0.05 * module` circumferential backlash by default, and
  `internal_mesh_interference` reports crossings when the backlash is zero. This
  is a declared engineering value, not a standards-mandated one. A caller may
  override it with `PlanetaryParams::new(backlash_mm=...)`.

### KI-08 — Golden corpus is a local download

- Severity: low (reproducibility).
- The golden STEP files are downloaded by the repository owner from the
  open-source step.parts corpus into the Git-ignored `external/` directory.
  A missing file is reported as `SKIP`; the normative/parametric checks still
  run and pass. The harness `--self-test` proves the PASS/FAIL/SKIP behaviour
  without depending on the downloaded corpus.

### KI-09 — Internal thread ridge was detached for M16/M20 (fixed)

- Severity: high (engineering-invalid geometry).
- Reproduction before the fix: `components/examples/fasteners --standard
  iso4032 --size M20 --detail full`. The internal ridge's outer radius was
  9.9647 mm inside a 10.0 mm bore, so the "helical-thread" solid floated free
  of the nut body. The same placement error made every ridge 0.054P too deep
  at the crest. An OCCT `bcommon` of body and ridge returned mass 0.
- Root cause: the ridge profile was centred on the pitch diameter, but the
  internal basic profile spans `D1/2 .. D/2`, whose midpoint is
  `D/2 - H1/2` (pitch radius plus `0.054P`), and the nut's clearance bore was
  not applied to the ridge.
- Fix: `internal_thread_ridge_center_radius_mm` centres the profile between
  the basic crest and root and accepts `radial_offset_mm`; `hex_nut` passes its
  bore clearance. The root is embedded 0.1 mm into the body.
- Regression: `fasteners_test.mbt` checks every size/clearance and the M20
  bounding box; OCCT `bcommon` now reports a positive common volume (M20
  ≈ 38 mm³, M4 ≈ 2.4 mm³).

### KI-10 — External thread flanks were not 60 degrees (fixed)

- Severity: high (engineering-invalid thread profile).
- Reproduction before the fix: the M4 external ridge profile used crest width
  `P/8` and root width `P/4`. Over the ISO depth `h3 = 17H/24` that gives a
  flank slope of about 0.10, an included angle of about 11.6 degrees, not 60.
  The docstring nevertheless claimed the ISO 68-1 basic profile.
- Root cause: `root_flat_mm()` returned `P/4`, which is neither the external
  groove root flat (`P/6`) nor the material ridge root width (`5P/6`).
- Fix: the external ridge uses crest width `P/8` and root width `5P/6`; the
  internal profile uses `P/4` and `7P/8` (it was already correct). Both give
  `tan(30 deg) = (root_width - crest_width) / (2 * depth)`.
- Regression: `standards_test.mbt` asserts the widths and the 60-degree
  included angle for every supported metric size. The regenerated
  `iso4762-M4x20-fully-modeled.step` validates and its ridge still intersects
  the thread core (OCCT common mass ≈ 10.5 mm³).
- Related consistency fix: `d3`, `D1`, `h3`, and `H1` are now all derived from
  `H`, so `d3 = d - 2 h3` and `D1 = d - 2 H1` hold exactly.

### KI-11 — Spring axial length exceeded the nominal length (fixed)

- Severity: medium (dimensional semantics).
- Reproduction before the fix: `compression_spring(10, 1, 20, 8)` had a
  `z` extent of -0.5 .. 20.5 mm although the docstring and metadata say
  `z = 0 .. length`.
- Root cause: the helix path ran from `z = 0` to `z = length`, and the wire
  profile extends one wire radius beyond each path point.
- Fix: the path is inset by `wire_radius` at each end and the pitch is based
  on `length - 2 * wire_radius`, so the finished spring spans exactly
  `0 .. length`.
- Regression: `motion_test.mbt` asserts the exact bounding box
  (`±5.5` mm radially, `0 .. 20` mm axially).

### KI-12 — Rounded frame was not independently validated (fixed, tooling)

- Severity: low (validation gap).
- `scripts/validate_frame_geometry.py` compared the rounded frame's volume with
  the sharp-corner section area and failed by 1.03%.
- Fix: the validator accepts `--corner-radius` and `--corner-segments` and
  subtracts the polygonal corner-fillet area. `generate_all.sh` now validates
  the rounded fixture too. It reports a 1.23e-06 relative volume error.

### KI-13 — Disconnected-instance detection depended on insertion order (fixed)

- Severity: medium (floating-member validation could invert its answer).
- `Assembly::disconnected_instances()` ran a BFS from the first instance. If the
  first instance was the floating one, it reported every connected member as
  disconnected and the floating member as the only connected part.
- Fix: the function now finds connected components (contact, collision, or
  declared interference) and reports everything outside the largest component.
  If no instance touches another, every instance is reported.
- Regression: `assemblies_test.mbt` builds a floating screw inserted before two
  stacked plates and asserts the screw is the only reported disconnected item.

### KI-14 — Filleted shaft rounded the wrong corner (fixed)

- Severity: high (engineering-invalid geometry).
- Repro: `filleted_stepped_shaft([(10,20),(16,15)], fillet_radius_mm=2)`.
  The STEP contained `TOROIDAL_SURFACE('',#axis,6.0,2.0)` — the outer rim of
  the larger cylinder — while the re-entrant shoulder at r=5 stayed sharp.
- Fix: the fillet centre is now `(r_small + f, shoulder_z - f)`, tangent to the
  small cylinder and the shoulder face. The same example reports major radius
  **7.0**, minor **2.0**. The fit check now uses the small segment's length and
  skips zero-length lines, so equal consecutive diameters and the maximum
  feasible fillet (`f = radial step`) build instead of returning an error.
- Regression: `motion_test.mbt` checks the torus location, equal diameters, the
  maximum fillet, and that no fillet is claimed when none is modelled.
- Also fixed: the feature record previously claimed `shoulder-fillet` whenever
  `f > 0`, even with no shoulder.

### KI-15 — Hardware-kit and fastener-grid nuts were misplaced (fixed)

- Severity: high (real interference for short valid screws).
- `fastener_grid_plate` placed the nut at `-L + nut_height` (one nut height
  above the free end). For M4x6 the nut overlapped the washer by 0.8 mm and the
  head by 0.4 mm. It is now at `-L`.
- `metric_hardware_kit` used a fixed `nut_z = 2.0`. For M2x3 the nut overlapped
  the washer and head. It now sits at the free end (`z = 0`).
- Regressions: short-screw checks for both builders. The existing test that
  asserted `nut_z == 2.0` was updated to `0.0` for the corrected placement.

### KI-16 — Key frame and height were undocumented/inexact (fixed)

- `key_for_keyway` now documents that the cuboid occupies `0..width`,
  `0..height`, `0..length` (origin at the bottom-left-near corner), and accepts
  `key_height_mm` independently of the keyway depth. A taller key is described
  as protruding into the hub. A negative height is rejected.
- The keyed-shaft feature record now uses the clamped section segment count.

### KI-17 — Bearing roller spacing and chamfer fit were unvalidated (fixed)

- Added a check that adjacent ball centres are at least one ball diameter apart
  (608 accepts 33 rollers, rejects 34).
- At `Detailed`, a ring thinner than the 0.2 mm minimum edge chamfer (or a width
  below twice the chamfer) is rejected instead of emitting an inverted annulus.
- The rings are now real annular solids of revolution: outer and bore surfaces
  are analytic cylinders and the edge break is an analytic cone, so a nominally
  tangent ball meets the true bore with no chord sagitta. The internals remain a
  visual envelope model, not a raceway model (no groove, cage, or seal).

### KI-18 — Collision aggregation and policy handling (fixed)

- Upgrading a clearance aggregate to `Contact`/`Collision` now resets
  `separation_mm` to zero; previously a collision could report the old positive
  gap.
- `Assembly::collisions(policy~)` now accepts and honours a `ContactPolicy`, so
  a declared interference pair is excluded from `collisions()` as documented.

### KI-19 — Planetary ring phase was wrong for odd planet tooth counts (fixed)

- Severity: high (tooth-on-tooth contact).
- Sun 18 / planet 11 / ring 40 (a valid set) had 12 ring/planet crossings at
  the old ring phase 0 and zero with the ring rotated by half a ring pitch
  (`180/40 = 4.5 deg`). The planet's sun-side and ring-side phases are half a
  planet pitch apart for odd tooth counts.
- Fix: `planetary_gear_set` rotates the ring by `180 / ring_teeth` when the
  planet tooth count is odd; `internal_mesh_interference` applies the same
  offset. Existing even-tooth sets are unchanged.
- Regression: the odd set has zero ring/planet and zero sun/planet crossings,
  the unrotated ring is a non-vacuous negative control, and the public cycle
  diagnostic reports zero crossings.

### KI-20 — Planet-to-planet overlap was not validated (fixed)

- `PlanetaryParams::new` now requires the adjacent centre chord
  `2 C sin(pi / count)` to exceed the planet tip diameter. Sun 18 / planet 18 /
  6 planets (adjacent 36 mm, tip diameter 40 mm) is rejected.
- Regression: that case is an error; 18/12/5 remains valid.

### KI-21 — External gear backlash bound and undercut disclosure (fixed)

- `SpurGearParams::new` rejects `backlash_mm >= pi * module / 2`, which would
  make the tooth thickness negative.
- `backlash_mm` is a **per-gear** thickness reduction; a mesh of two gears gets
  twice that as total clearance. The docs now say so.
- The spur feature record always states the undercut limitation; below the
  standard no-undercut limit (17 teeth at 20 degrees) it says the profile is the
  theoretical involute, not a cutter-generated trochoid.
- Remaining limitation: the external involute-flank and tip/root deviations are
  conservative circle-chord upper bounds, not measured involute deviations.

### KI-22 — Spring designation and wire approximation (fixed/documented)

- The designation now says "mean dia", not "OD" (the outer diameter is
  mean + wire).
- The feature record includes the 12-gon wire-section sagitta. The wire is
  swept in the radial-axial plane with a horizontal path tangent, so the
  section normal to the true helix is slightly elliptical; end caps are not
  ground flat.

### KI-23 — Assembly feature and product-structure documentation (fixed)

- `Assembly::features` now keeps the largest deviation for a repeated
  approximation name instead of the first.
- `to_assembly_step` documentation now says one product per materialised
  **layer**, not per component instance (a screw is several products).

### KI-24 — Bolted joint could not use a longer standard screw (fixed)

- `bolted_joint` accepts `screw_length_mm`. The default is the exact
  nut + plates + washer length; a longer standard length is accepted (and
  protrudes past the nut), while a shorter one is rejected. Thin stacks whose
  exact length is below the ISO 4762 minimum still need the override.


## Session 10 open items (2026-11-11)

- ISO 4762 detailed geometry matches the reference shape and volume; the
  reference family mixes two source constructions. The simpler source (flat
  socket floor, under-head torus, no countersink) is not copied.
- ISO 2338 dowel-pin and DIN 976 rod reference files are twice their labelled
  length; the library follows the label.
- ISO 8752 slotted spring pins remain unmodeled: the reference slot is closed
  at the ends and the flat writer has no verified slit-tube construction.
- Gears (spur m2 z20/z40) still use the existing approximating tooth flank;
  the reference volumes differ by about 20%, so they are recorded as an
  approximation, not a match.

- ISO 4032 Detailed nuts are conical; the FullyModeled (helical) variant still
  uses the ruled planar face band. The M4/M5/M8 downloaded references disagree
  with ISO 4032 on corner rounding (M4) and height (M5, M8); the standard values
  are modeled.

- ISO 10642 Detailed uses the reference's deeper socket (hexagon corners at the
  head underside, drill point in the shank) rather than the nominal t = 1.2 mm;
  the Simplified and fully-threaded variants keep the ISO minor-diameter shank
  and arc edge radius.

- The `--unified` hex-head representation's analytic volume, centroid, section
  and inventory are exact; its `analysis_mesh` still uses the head-only proxy
  (Blender visualization omits the shank for that option).
