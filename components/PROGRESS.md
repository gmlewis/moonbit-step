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

- Full test suite is kept green (`./test-all.sh`): **457 tests, 457 passed,
  0 failed** (432 at the start of the chamfer/fillet session; 408 at the start
  of the earlier audit).
- Representative generated files pass `scripts/validate_step.py` with OCCT
  `checkshape` and watertight tessellation.
- Flat assembly exports pass the full validator. The STEP product-structure
  export passes all non-OCCT checks; see `KNOWN_ISSUES.md`.

## Chamfer, fillet, and feature session (2026-11-09)

Starting state: branch `master`, 432/432 tests. This session added the
feature-geometry kernel and applied it across fasteners, bearings, and the two
new head standards. See `FEATURES.md` for the full support matrix.

### New kernel primitives

- `Profile2D::chamfer_vertices` / `fillet_vertices`: robust 2D chamfer and
  fillet with convex/concave classification, selection, fit validation, and a
  simple-polygon check. Tests: `cad/profile-chamfer_wbtest.mbt`.
- `RevolvedProfile`: a solid of revolution compiled to analytic
  `CYLINDRICAL_SURFACE`, `CONICAL_SURFACE`, `SPHERICAL_SURFACE`,
  `TOROIDAL_SURFACE`, and planar faces, with real seams and analytic poles.
  Tests: `cad/revolved_profile_wbtest.mbt`. OCCT-measured volumes match the
  closed-form values (sphere 523.599, cone 134.041, frustum 175.929, cylinder
  628.319, ring 131.947, torus 98.696, dome 89.535 mm³).
- `ChamferedPrism`: a parallel-inset ring stack with an optional prismatic
  through-hole, used for real face chamfers on prisms. Tests:
  `cad/chamfered_prism_wbtest.mbt`.
- A `SPHERICAL_SURFACE` STEP entity was added to the geometry, repository, and
  parse layers.

### Applied features

- ISO 4032 nut: 45° face chamfer on both bearing faces at `Detailed` and above
  (real ring-stack chamfer; `iso4032-M4-detailed` validates watertight).
- ISO 4762 screw: 45° head top-edge chamfer at `Detailed` and above
  (`iso4762-M4-detailed`).
- ISO 7380-1 button head and ISO 10642 countersunk head: new standards with
  verified head dimensions and real dome/cone geometry plus hexagon sockets.
  `iso7380-M4x16-detailed` and `iso10642-M4x16-detailed` validate watertight.
- Bearings: cylindrical roller proxies replaced with analytic spheres; rings
  carry an engineering-default edge chamfer at `Detailed` and above
  (`motion-608-stack-detailed`).

### Validation tooling

- `scripts/measure_step_features.py` reports surface-type counts and cone /
  sphere / torus parameters, so a chamfer or fillet can be checked for real
  conical/toroidal/spherical geometry.
- `scripts/validate_step.py` now excludes zero-area tessellation facets at
  singular poles from the watertight edge count and reports the ignored count;
  genuine open boundaries still fail. This fixes a false negative that also
  affected an OCCT-generated sphere.
- `components/examples/revolution` generates the analytic revolve fixtures;
  `generate_all.sh` produces and validates every new artifact.

### Remaining

1. Exact/arc-capable B-slot6 2020 extrusion profile (unchanged from the prior
   audit; still deferred pending provenance).
2. Gear root fillet / tip chamfer and exact internal involute ring.
3. Catalog/query API and mixed-family assemblies.
4. Broader golden corpus promotion with feature-level verdicts.

## Correctness audit (2026-11-09)

Starting state: branch `master`, commit
`994bd0edd931d4a2160ce447a3f2380d6d0fc26c`, baseline **408/408 tests**.

### P0 — extrusion frame interpenetration

Reproduced the owner's defect with the new collision facility. Before the fix,
`frame-2020-400x300x500.step` produced 24 collision reports: every rail
overlapped its post by 10 mm, and every X rail overlapped the adjacent Y rails
by 10 mm. The member cut lengths were `width - profile_width` and
`depth - profile_height` instead of the clear span between post inner faces.

Fix: `extrusion_frame_members()` computes an explicit schedule with
`width - 2 * profile_width` and `depth - 2 * profile_height`; the assembly is
built from the schedule. After the fix:

- pairwise collisions: 0;
- intended contacts: present at every post/rail joint;
- connectivity: all 12 instances reachable;
- floating members: 0;
- overall dimensions: exactly 400 x 300 x 500;
- STEP: 12 separate watertight solids, all validator checks PASS.

Additional frame configurations validated independently:

| Frame | Solids | Bbox error | Volume error | Overlaps | Result |
|---|---:|---:|---:|---:|---|
| 400 x 300 x 500 | 12 | 1e-07 mm | 5.61e-07 | 0 | PASS |
| 600 x 300 x 400 | 12 | 1e-07 mm | 2.42e-06 | 0 | PASS |
| 45 x 45 x 45 | 12 | 1e-07 mm | 4.79e-07 | 0 | PASS |
| 400 x 300 x 500, 2040 profile | 12 | 1e-07 mm | 2.19e-06 | 0 | PASS |

Commands:

```bash
moon run --target native components/examples/extrusion_frame -- \
  --width 400 --depth 300 --height 500 --series 2020 \
  -o components/examples/output/frame-2020-400x300x500.step \
  --views components/examples/output/views

python3 scripts/validate_step.py \
  components/examples/output/frame-2020-400x300x500.step

python3 scripts/validate_frame_geometry.py \
  components/examples/output/frame-2020-400x300x500.step \
  --width 400 --depth 300 --height 500 --series 2020
```

### P0 — T-slot cross-section self-intersection

The generic 2020 outline was not a simple polygon: the rectangular cavity from
each face (11 mm wide, 6 mm deep) reached the core corner at 4 mm and overlapped
the cavity on the adjacent face. The rendered section looked like blocky pixel
art rather than four T-slots and four corner arrows.

Fix: when a rectangular cavity would reach the core corner, the cavity back is
tapered to leave a solid corner web of half thickness `wall_mm / 2`. The
2040 long-side cavities do not reach the corner and keep the rectangular
cavity. The new 2020 outer outline area is **206.16 mm²**; the solid section
area (outer minus the 48-gon bore) is **192.345108 mm²**.

Regression coverage: `profiles_test.mbt` checks that all four presets have
simple, non-self-intersecting outlines and asserts the 2020 outer area. The
frame section SVG (`--views`) now draws the actual outer boundary and bore.

### P1 — planetary phase

The 18/12/42 five-planet layout satisfies the standard equal-spacing condition
but the old shared planet phase produced 16 proper tooth-outline crossings.
The planet phase now compensates for the sun tooth phase at each radial.
Regression tests cover the non-divisible layout, the standard 12/12/36
three-planet layout, a full external mesh cycle, and planet/ring clearance.

### New validation layers

- `components/collision` — AABB broad phase, OBB/SAT narrow phase, named
  tolerance policy, contact vs collision vs clearance, assembly connectivity.
- `components/assemblies/assembly_validation.mbt` — `collision_reports`,
  `collisions`, `contacts`, `disconnected_instances`, `is_connected`.
- `scripts/validate_frame_geometry.py` — independent OCCT post-export frame
  geometry validation.
- `scripts/measure_step_occt.py` — generic OCCT STEP measurement helper.
- `scripts/fetch_golden_references.py` — checksum-verified golden fetch to a
  temporary directory.
- `components/testdata/golden/manifest.json` — provenance, hashes, measured and
  parametric dimensions, and verdicts.
- SVG diagnostics: `--views DIR` on the frame example.

### Golden references

Eight candidates were fetched and verified by SHA-256. Six are useful as
envelope oracles; two were rejected because they contradict their claimed
standard:

- ISO 4762 M5 x 10 reference head diameter 9.2003 mm vs ISO maximum 8.5 mm.
- ISO 7089 M4 reference thickness 1.8 mm vs ISO 7089 h = 0.8 mm.

The golden files are downloaded by the repository owner from the open-source
step.parts corpus. See `GOLDEN_REFERENCES.md`.

### Comprehensive standardized corpus tooling

`scripts/fetch_golden_references.py` now selects a comprehensive standardized
corpus by catalog standard, family, nominal size, and representative length,
instead of an eight-ID list. Scope counts at the time of writing:

- `--scope core` (M2-M5): 167 files;
- `--scope extended` (M2-M8): 237 files;
- `--scope all`: 1048 files.

The corpus includes ISO 4762/4017/7380/10642 and DIN 913 screws, ISO 4032/4035
and DIN 1587/557 nuts, ISO 7089/7091/7092/7093 and DIN 125/127/7349/93/440
washers, ISO 2338/8752/1234 pins, common 608/6000/6200-class bearings, and
clearly labeled DIN 976-compatible rods. DIN 471 retaining rings are included
in `--scope all` (catalog starts at M10). Three non-standardized gear/profile
oracles are included and labeled as such.

The script verifies the standard designation, size/length availability,
SHA-256, and byte size; writes `fetch-report.json`; reuses checksum-matching
files; retries failed downloads; and writes through temporary `.part` files.
The full core corpus was downloaded and verified locally (167/167 files).

## Next tasks (priority order)

1. Add an optional exact/arc-capable B-slot6 2020 reference profile. The
   step.parts `profile_2020_b_slot6_a_l50` has a measured solid section area of
   about 174.336 mm^2 (volume 8716.82 mm^3 / 50 mm), rounded outer corners, and
   a lobed core with 2.75 mm-radius arc/cylindrical surfaces. The generic
   `generic-2020` envelope is 192.345108 mm^2 with sharp corners, a 4.2 mm bore,
   and simple T-slots; it must not be described as an exact B-slot6 section.
   Implementing this needs an arc-capable 2D section representation, a named
   preset with provenance, and a boundary/area comparison against the golden.
   Verify the reference's provenance before committing a preset derived from
   it; otherwise keep the profile generic and label the discrepancy.
2. Add button-head (ISO 7380) and countersunk (ISO 10642) screw builders after
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

## Feature-metadata, golden-harness, and remaining-features session (2026-11-10)

Starting state: branch `master`, HEAD `4fc5381`, **458/458 tests**.

### Completed

- **Machine-readable feature records** (`components/common/features.mbt`):
  `FeatureRecord`, `Approximation`, `Omission`, `ApproximationKind`; carried by
  every `Component`, copied into the STEP header, populated by every builder,
  and aggregated by assemblies. New tests assert detail-level differences.
- **Golden comparison harness** (`scripts/compare_golden.py`): checksum
  verification, parameteric-part generation through the example CLIs, OCCT and STEP
  feature measurement, `PASS`/`FAIL`/`SKIP` reporting, and normative checks
  that run even when the external file is absent. Recipes added to the manifest
  for six fixtures.
- **Optional evaluated 3D fillet/chamfer**: `Shape::Fillet`/`Shape::Chamfer`,
  typed flat-writer refusal, `MOONBIT_EDGE_FEATURE` evaluation in
  `scripts/csg_eval.py`, and OCCT tests producing a toroidal fillet and a
  conical chamfer.
- **Gear root fillet and tip chamfer** with typed rejection and watertight
  extrusion; the 40-tooth case needed an adaptive root band.
- **Extrusion corner radii**, generic 2060/2080/3060/4080 series, and an
  explicit B-slot6 non-equivalence test.
- **Catalogue/query API** (`components/catalog`) and a **bolted-joint**
  mixed-family assembly plus a `bolted_joint` example.
- **Property/parameter-sweep tests** with a documented fixed seed.
- Docs updated; the final report is `SESSION_REPORT.md`.

### Defect found and fixed

- **ISO 10642 countersunk screws placed the head above the shank**, making an
  M3 x 12 part 13.7 mm overall instead of the standard 12.0 mm. The head now
  occupies the top `k` millimetres of the nominal length. Found by the golden
  harness (`bbox` check), not by inspection.

### Deferred, with evidence

- Exact internal involute ring gear: the implemented involute internal profile
  failed the rotation-cycle mesh check (300+ crossings) and was removed; the
  trapezoidal approximation is retained and documented.
- Gear root fillets are polyline arcs and may be rejected for very high tooth
  counts if the adaptive band cannot find a fitting edge.
- Evaluated 3D chamfer is limited to one selected edge per OCCT DRAW node; the
  evaluator returns a typed error for multi-edge chamfers.

### Final status

- `./test-all.sh`: **495 tests, 495 passed, 0 failed**.

```bash
python3 scripts/compare_golden.py            # six fixtures, PASS/SKIP report
python3 scripts/compare_golden.py --json     # machine-readable results
```


## Golden validation, exact internal ring, and keyways (2026-11-10, second session)

Starting state: branch `master`, HEAD `b825f5e`, baseline **495/495 tests**.

### Completed

- **Exact internal involute ring gear** (`components/gears/internal.mbt`):
  `internal_involute_ring_profile`, `internal_ring_geometry`,
  `internal_ring_gear_exact`, and `internal_mesh_interference`. The tooth
  thickness follows the internal relation `psi(r) = psi_p + inv(a_r) - inv(a_p)`;
  a fixed-centre 32-pose rotation cycle must have zero planet/ring outline
  crossings. The planetary set now uses the exact ring with a declared
  `0.05 * module` internal-mesh backlash. The trapezoidal builder remains an
  explicit fallback.
- **Keyed shaft with a real keyway** (`components/motion/keyed_shafts.mbt`):
  `keyed_shaft_cross_section`, `keyed_shaft`, and `key_for_keyway`. The keyway
  is a geometric notch in the extruded section (one watertight solid), with a
  matching key sized by a declared clearance. New example
  `components/examples/keyed_shaft`.
- **Golden harness expansion** (`scripts/compare_golden.py`): 23 manifest
  external references (14 newly promoted), `volume_mm3` and
  `vertex_radius_present_mm` comparison kinds, `vertex_radius_clusters` in
  `measure_step_features.py`, units/frame normalization, and a `--self-test`
  mode proving PASS/FAIL/SKIP, checksum, and normalization behaviour. All 19
  generated fixtures PASS; external geometry compared with the downloaded golden models; no
  FAIL. Rejected washer and rod references are recorded with evidence.
- **Catalogue:** `gear_catalog` now uses the exact ring; new `motion_catalog`
  exposes the keyed shaft and key.
- **Independent measurement:** SolidCraft imports the keyed shaft and the
  exact-ring planetary with zero errors and all bodies closed; OCCT and
  SolidCraft agree to four significant figures on volume (keyed shaft
  12161.0 mm³, planetary 34744.0 mm³). Renders were inspected.
- Docs updated: `FEATURES.md`, `KNOWN_ISSUES.md`, `GOLDEN_REFERENCES.md`,
  `VALIDATION.md`, `GEOMETRY.md`, `README.md`, and `SESSION_REPORT_05.md`.

### Final status

- `./test-all.sh`: **511 tests, 511 passed, 0 failed** (508 before the catalogue
  and sweep additions).
- `python3 scripts/compare_golden.py`: 19 fixtures PASS, external geometry
  SKIP, no FAIL.
- `python3 scripts/compare_golden.py --self-test`: 8/8 cases pass.

## Audit and thread/bbox/spring correctness session (round 6, 2026-11-10)

Starting state: branch `master`, HEAD `f86c6f8`, baseline **511/511 tests**.
Round-5 work was present in the working tree and was preserved; see
`SESSION_REPORT_05.md`. This session audited it rather than trusting the
report.

### Defects found and fixed

1. **Internal helical ridge detached for M16/M20 (high).** The ridge profile was
   centred on the pitch diameter, so its root did not reach the bore; for M20
   it floated 0.035 mm inside the nut. A clearance bore made the gap larger for
   every size. The profile is now centred between `D1/2` and `D/2`, shifted by
   the bore clearance, and embedded 0.1 mm into the body. OCCT `bcommon`
   changed from mass 0 to 37.97 mm³ (M20) / 2.43 mm³ (M4).
2. **External thread flanks were not 60 degrees (high).** The ridge used root
   width `P/4` instead of `5P/6`, producing roughly an 11.6-degree included
   angle while claiming the ISO 68-1 basic profile. It now uses crest `P/8`
   and root `5P/6`; the internal ridge uses `P/4` and `7P/8`. Tests assert
   `(root - crest) / (2 * depth) = tan(30 degrees)` for every size.
3. **ISO 68-1 constants disagreed (medium).** `h3 = 0.61343P` versus
   `d3 = d - 1.226869P` broke `d3 = d - 2h3`. All derived diameters and depths
   now come from `H`, so the identities hold exactly.
4. **Spring overall length was `length + wire_diameter` (medium).** The helix
   path now starts at `wire_radius` and its pitch is based on
   `length - 2 * wire_radius`, so the spring spans exactly `0 .. length`.
5. **Swept-profile bounding boxes were inflated by 5 mm (medium).** The box now
   follows the actual profile vertices in each path frame. This makes
   `Component::size()` and the OBB collision phase accurate for threads and
   springs.
6. **Rounded frame was not independently validated (low).**
   `validate_frame_geometry.py` gained `--corner-radius`/`--corner-segments`;
   the rounded 200x200x200 fixture now passes with a 1.23e-06 volume error.
7. **Disconnected-instance detection was insertion-order dependent (medium).**
   `Assembly::disconnected_instances()` started its BFS at the first instance,
   so a floating first item made every connected member look disconnected. It
   now reports everything outside the largest connected component.
8. **A valid assembly STEP reported a false `FAIL` (low, tooling).**
   `validate_step.py` applied the single-shape OCCT gate to a product-structure
   document. It now detects `NEXT_ASSEMBLY_USAGE_OCCURRENCE` and reports the
   single-shape `checkshape`/mesh stages as `SKIP`; the syntax, reference,
   shell, topology, orientation, and planarity checks still run and pass.

### Additional audit repairs (motion, assemblies, gears)

- **Filleted shaft rounded the wrong corner (high).** The torus was on the
  larger cylinder's outer rim; the re-entrant shoulder stayed sharp. The torus
  centre is now `(r_small + f, shoulder_z - f)`; the fixture measures major 7.0,
  minor 2.0. Equal diameters and the maximum feasible fillet now build.
- **Kit nuts were misplaced (high).** `fastener_grid_plate` put the nut one nut
  height above the free end; `metric_hardware_kit` used a fixed 2 mm offset.
  Short valid screws overlapped the washer/head. Both nuts now sit at the free
  end, with short-screw regressions.
- **Odd planet tooth counts had a ring half-pitch error (high).** Sun 18 /
  planet 11 / ring 40 had 12 ring/planet crossings at ring phase 0; the ring is
  now rotated by `180 / ring_teeth` for odd planet counts, and the cycle
  diagnostic matches. A non-vacuous unrotated control is tested.
- **Planet-planet overlap was accepted (high).** Adjacent centre chord must
  exceed the planet tip diameter; 18/18/6 is now rejected.
- **Key frame/height (medium).** The key's local origin and extent are
  documented, `key_height_mm` is an explicit parameter, and a taller key is
  described as protruding into the hub.
- **Bearing validation (medium).** Overlapping rollers and rings thinner than
  the edge chamfer are rejected. The faceted-bore ball sagitta (~0.018 mm for
  608 at 48 segments) is documented.
- **Collision reporting (medium).** A collision/contact aggregate now has zero
  separation, and `Assembly::collisions(policy~)` honours a `ContactPolicy`.
- **Gear backlash/undercut (medium).** External backlash above half the circular
  pitch is rejected; backlash is documented as per-gear; the spur feature record
  states the undercut limitation.
- **Assembly feature aggregation (low).** Duplicate approximation names keep the
  largest deviation. `to_assembly_step` documentation now says one product per
  materialised layer.
- **Bolted joint length (low).** `screw_length_mm` lets a caller select a
  standard length; a shorter-than-stack length is rejected.
- **Spring metadata (low).** The designation says mean diameter (not OD), and
  the 12-gon wire-section deviation and radial-axial sweep are documented.

### Validation

- `./test-all.sh`: **535 tests, 535 passed, 0 failed** (+24 regressions).
- `python3 scripts/compare_golden.py`: 19 PASS, external SKIP, 0 FAIL.
- Regenerated fixtures `iso4032-{M3,M4,M5}-fully-modeled.step`,
  `iso4762-M4x20-fully-modeled.step`, `spring-10x1x20.step`,
  `filleted-shaft-d10-16.step`, `kit-M4x20-flat.step`,
  `assembly-structure/kit-M4x20-assembly.step`, `keyed-shaft-20x40.step`, the
  three gear-pair/single-gear fixtures, and both planetary fixtures. Every file
  passes `scripts/validate_step.py --no-mesh`; the assembly document reports
  the OCCT single-shape stages as `SKIP`.
- `scripts/measure_step_features.py` on `filleted-shaft-d10-16.step` reports
  one `TOROIDAL_SURFACE` with major 7.0 mm, minor 2.0 mm.
- OCCT and SolidCraft independently confirm the fixed M20 ridge reaches the
  bore. The frame validator passes all four committed frames.

### Remaining

The limitations in `KNOWN_ISSUES.md` still apply: nominal (layered) booleans,
no thread runout/root relief, OBB collision conservatism for non-convex
sections, and external golden geometry compared against the downloaded models.

## M2–M5 golden matrix and chamfer completion (round 7, 2026-11-10)

Starting state: branch `master`, HEAD `7f1181a` (`Complete round 6`),
baseline **535/535 tests** verified. Round-6 work was preserved.

### Defect found and fixed

- **P1: partially threaded screws were threaded at the wrong end.** ISO 4762
  M4 x 20 exported a plain shank at the tip (`z=0..6`) and the thread under the
  head (`z=6..20`), but ISO 4762 measures `b` from the tip. ISO 4014 had the
  same reversal. The thread core and swept ridge now occupy `z = 0..b`; the
  plain shank sits under the head. Regressions assert both placed positions.

### Chamfer/fillet completion (M2–M5)

- ISO 4762: real socket lead-in chamfer (tapered hex hole) and shank tip
  chamfer at `Detailed`+, in addition to the existing head chamfer.
- ISO 4032: face chamfers now also on the fully modeled helical body.
- ISO 7089: documented the sharp edge as standard-correct; no chamfer claimed.
- ISO 4017/4014: real hex-head top chamfer and shank tip chamfer; feature
  records added; thread measured from the tip.
- ISO 7380-1/ISO 10642: socket lead-in and tip chamfers; feature records
  updated.
- DIN 976-1: engineering lead-in chamfers at both ends; feature record added.
- Kernel: `ChamferedPrism` supports a per-level tapered hole (`hole_levels`),
  making the socket lead-in real ruled geometry.

### Golden matrix (centerpiece)

- `scripts/golden_matrix.py` builds and validates **108 cells** (8 families ×
  M2/M2.5/M3/M4/M5 × Simplified/Detailed/FullyModeled).
- **NORMATIVE: 108 PASS, 0 FAIL.** Checks: standard outside dimensions, solid
  count, measured chamfer/lead-in/thread vertex rings, tip lead-ins, and thread
  crests.
- **GOLDEN: 39 PASS, 54 FAIL, 15 SKIP** against the downloaded golden models.
  The failures are measured contradictions in the downloaded files (ISO 4762
  M2/M2.5/M5 oversized heads, ISO 7089 thickness, DIN 976 doubled length,
  ISO 4017/4014 head height). ISO 4014 has no downloaded partially-threaded
  model. ISO 10642 M4/M5 are permitted: the standard head diameter is a maximum
  and those models are below it.
- Reports: `components/testdata/golden/matrix.json` and `MATRIX.md`.

### Harness extensions

- `measure_step_features.py`: vertex-ring report.
- `measure_step_occt.py`: centre of mass.
- `measure_step_mesh.py` (new): sampled bidirectional surface deviation and
  cross-section area/perimeter/extent.
- `compare_golden.py`: mass-properties, section, surface-deviation, vertex-ring,
  and sphere-radius checks; self-test expanded to 15/15.
- Manifest: analytic washer mass/section/ring checks; bearing ball-radius
  checks.

### Assembly schedule

- `Assembly::schedule()`/`schedule_text()` group identical parametric parts into
  a BOM with quantity and instance names. The bolted joint reports four parts /
  five instances.

### Final status

- `./test-all.sh`: **546 tests, 546 passed, 0 failed** (+11 regressions).
- `python3 scripts/compare_golden.py`: 19 PASS, external SKIP, 0 FAIL.
- `python3 scripts/compare_golden.py --self-test`: 15/15 PASS.
- `python3 scripts/golden_matrix.py`: 108 cells, NORMATIVE 108 PASS, GOLDEN 108
  SKIP.

### Explicitly not implemented

T-nuts, corner brackets, joining plates, end caps, couplings, linear rails,
retaining rings, profile shift, helical gears, exact B-slot6, multi-edge
evaluated chamfers, under-head radii, ISO 4032 bore-edge chamfers, and
standards-defined thread runout. Each is recorded with its blocker in
`KNOWN_ISSUES.md` / `INVENTORY.md`; none is claimed as complete.

## Round 8 (2026-11-11): corrected golden-model policy and matrix

Starting state: branch `master`, HEAD `98a9709`, `./test-all.sh` 546/546,
`compare_golden.py` 19 PASS / external SKIP, matrix NORMATIVE 108 PASS /
GOLDEN 108 SKIP.

### Golden-model correction

- Golden STEP files are downloaded by the repository owner from the open-source
  step.parts corpus. They are **not** generated in this repository, and there
  are no licensing concerns.
- Removed the generated analytic-golden experiment (`analytic/` and
  `scripts/analytic_golden.py`) and all gate/attribution wording
  from the harness, manifest, fetch script, and documentation.
- `scripts/golden_matrix.py` now compares every cell against the downloaded
  golden model: rotation-invariant outer radius and axial extent, with
  `PASS`/`FAIL`/`SKIP` and measured evidence. A missing model is `SKIP`, never
  a pass.
- `scripts/compare_golden.py` measures external geometry whenever the golden
  file is present;
  all 19 fixtures report `PASS` with the recorded reference matching.

### Current matrix

- **108 cells: NORMATIVE 108 PASS / 0 FAIL; GOLDEN 39 PASS / 54 FAIL /
  15 SKIP; 39 fully validated.**
- The 54 failures are measured contradictions in the downloaded files:
  ISO 4762 M2/M2.5/M5 oversized heads, ISO 7089 excessive thickness, DIN 976
  doubled length, and ISO 4017/4014 head height.
- ISO 4014 has no downloaded partially-threaded model; those 15 cells are
  `SKIP` with that blocker.

### Tests and validation

- `./test-all.sh`: **548 tests, 548 passed, 0 failed** (two new M2–M5
  feature-record/chamfer regressions).
- `compare_golden.py --self-test`: 15/15 PASS.
- `golden_matrix.py --self-test`: PASS (matching golden PASS, wrong-sized golden
  FAIL, missing golden SKIP).
- Downloaded golden and parametric STEP files pass `validate_step.py`
  including OCCT `checkshape`.
- `measure_step_mesh.section_at` now orients section segments by the triangle
  normal, fixing signed-area cancellation on threaded/multi-body sections.

### Documentation

- `GOLDEN_REFERENCES.md`, `DECISIONS.md`, `INVENTORY.md`, `VALIDATION.md`,
  `FEATURES.md`, `DATA_SOURCES.md`, `KNOWN_ISSUES.md`, `README.md`,
  `testdata/golden/README.md`, and every `perfect-prompt*.md` now state the
  downloaded-golden policy.
- Added `SESSION_REPORT_08.md`.
