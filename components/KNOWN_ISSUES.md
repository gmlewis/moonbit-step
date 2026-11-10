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
2. **Head chamfers are real but engineering defaults.** ISO 4762 socket-head
   screws now carry a 45° top-edge chamfer and ISO 4032 nuts a 45° face chamfer
   at `Detailed` and above, built as real ruled ring stacks. The standard does
   not fix these chamfer sizes, so the inset is an engineering default
   documented in the component description. Fillets on these families are not
   modeled. The chamfered prism side faces are planar facets, not a
   continuously curved surface.
3. **No screw tip chamfer or thread runout.** The shank ends are square; thread
   runout/lead-in is not modeled.
4. **No socket lead-in chamfer.** The hexagonal sockets are straight
   through-holes/recesses over a floor; the socket rim is not chamfered.
5. **Helical thread ridge is an approximation.** It uses the ISO 68-1 basic
   profile and standard pitch, but does not model tolerance classes, root
   radius, flank grind, or runout. It is a real swept helix, not a cosmetic
   texture.
6. **Gear root fillet omitted.** Tooth flanks are involute; tip and root arcs
   are polygonal. Root fillets, tip chamfers, profile shift, and helix are not
   modeled.
7. **Gear pair is a static layout.** It uses the standard centre distance plus
   an offset and a half-pitch phase. It is not a kinematic solver and does not
   verify tooth contact.
8. **Internal ring gear tooth form is approximate.** The planetary set uses a
   trapezoidal internal tooth profile. It is visually and kinematically laid
   out but is not an exact internal involute envelope. The existing
   `examples/38-planetary-gearbox` herringbone generator is preserved.
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
    and undercuts are not modeled.
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
    reference's provenance/license. See `GOLDEN_REFERENCES.md` and
    `perfect-prompt-03.md`.

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
   references, shells, topology, orientation, and planarity successfully, but
   its OCCT stage calls `testreadstep <file> a` and reports "a is not a
   topological shape" for an assembly document. Use a CAD assembly importer or
   the flat export (`Assembly::to_step()`) when the OCCT gate is required.
2. **Fully modeled files are large.** An M4x20 fully modeled screw is roughly
   4 MB at 48 segments per turn. Simplified/detailed files are ~60 KB. Reduce
   `segments_per_turn` or use `Detailed` for catalog-wide generation when size
   matters.
3. **Bounding boxes of swept profiles are conservative.** `@cad`'s
   `SweptProfile` bounding box expands path points by 5 mm; unit tests inspect
   analytic layers instead of trusting the swept envelope.
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
6. **External golden files are not committed.** Per-file redistribution rights
   are unverified, so golden comparison is a documented fetch procedure rather
   than a hermetic test. Two candidate models that contradict their claimed
   standards were rejected (see `GOLDEN_REFERENCES.md`).

## Deferred standards/components

- ISO 4762 additional lengths and preferred-length series outside the tested
  range.
- Fine-thread fasteners beyond the first-choice fine pitch per size.
- Threaded inserts, retaining rings, and additional verified nuts/washers.
- Exact internal involute ring gears (see the session issue below).
- Helical gears, bevel gears, worm gears, timing belts/pulleys, sprockets.
- T-nuts, corner brackets, joining plates, end caps.
- Motor envelopes and mounting patterns.

Implemented in the feature session (previously deferred): ISO 7380-1 button
head screws, ISO 10642 countersunk head screws, bearing spheres, the 2D
chamfer/fillet helpers, `RevolvedProfile`, and `ChamferedPrism`. Their
approximations are recorded above and in `FEATURES.md`.

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

### KI-02 — Exact internal involute ring gear remains deferred

- Severity: medium (documented approximation).
- The trapezoidal ring tooth form is retained. An involute internal profile was
  implemented and then removed after a fixed-centre rotation-cycle mesh check
  found 300+ planet/ring outline crossings, so it was not shipped.
- The ring feature record explicitly omits
  `exact-involute-internal-envelope`; the catalogue reports this omission.
- Acceptance for closing: an internal profile that passes the rotation-cycle
  crossing test and an external or analytic tooth-form reference.

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

