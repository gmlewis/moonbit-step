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

No external STEP file is committed because per-file redistribution rights are
unverified. See `GOLDEN_REFERENCES.md`.

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
   Verify the reference's per-file license before committing a preset derived
   from it; otherwise keep the profile generic and label the discrepancy.
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
