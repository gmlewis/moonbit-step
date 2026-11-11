# Validation Summary

Environment: macOS, MoonBit `moon 0.1.20261104 (940aa18 2026-11-04)`,
`moonc v0.10.20+65efd5b93`; OCCT `DRAWEXE` and `gmsh` present.

## Current status (round 8, 2026-11-11)

- `./test-all.sh`: **548 tests, 548 passed, 0 failed**.
- `python3 scripts/compare_golden.py`: 19 generated fixtures `PASS`, external
  geometry compared against the downloaded golden models.
- `python3 scripts/compare_golden.py --self-test`: **15/15 checks PASS**.
- `python3 scripts/golden_matrix.py`: **108 cells, NORMATIVE 108 PASS / 0 FAIL;
  GOLDEN 39 PASS / 54 FAIL / 15 SKIP; 39 fully validated**. The GOLDEN failures
  are measured contradictions in the downloaded files (ISO 4762 M2/M2.5/M5
  oversized heads, ISO 7089 thickness, DIN 976 doubled length, ISO 4017 head
  height); ISO 4014 has no downloaded partially-threaded model.
- `python3 scripts/golden_matrix.py --self-test`: PASS.
- The corrected thread placement and every new chamfer are measured from the
  emitted STEP and validated with OCCT `checkshape`; representative files:
  `iso4762-M4x20-detailed` (3 solids, 275 faces),
  `iso4017-M4x20-detailed` (2/144), `iso10642-M4x16-detailed` (3/212),
  `iso4032-M4-fully-modeled` (2/620).

## Round 6 status (historical)

- `./test-all.sh`: **535 tests, 535 passed, 0 failed**.
- `python3 scripts/compare_golden.py`: 19 generated fixtures `PASS`, external
  geometry compared against the downloaded golden models.
- `python3 scripts/compare_golden.py --self-test`: PASS.
- Regenerated fully modeled fasteners and the spring validate with
  `scripts/validate_step.py` (syntax, references, closed shells, topology,
  orientation, PLANE planarity, OCCT `checkshape`).
- Independent OCCT evidence for the thread-ridge repair: a `bcommon` of the nut
  body and its internal ridge returned mass 0 before the fix and 37.97 mm³
  (M20) / 2.43 mm³ (M4) after; the external M4 ridge intersects its thread core
  with mass 10.50 mm³.
- SolidCraft independently imports the fixed M20 nut with zero errors; the
  ridge bounding box is ±10.1 mm (it reaches the 10 mm bore).
- `scripts/validate_frame_geometry.py --corner-radius 1.5` now passes the
  rounded 200x200x200 frame (volume relative error 1.23e-06).
- `scripts/validate_step.py` detects a STEP product-structure document and
  reports the single-shape OCCT `checkshape`/mesh stages as `SKIP` instead of a
  false `FAIL`; the committed `kit-M4x20-assembly.step` now reports PASS/PASS/
  PASS/PASS/PASS/PASS/PASS + SKIP + SKIP and exits 0.
- `python3 scripts/validate_step_test.py`: 10/10 self-tests pass, including the
  assembly-detection and skip behaviour.

New round-6 regressions:

- `cad/sweep_bbox_wbtest.mbt` — tight swept-profile bounding box and empty-path
  behaviour.
- `components/fasteners/fasteners_test.mbt` — ISO 68-1 crest/root radii for all
  sizes, internal-ridge attachment for every size/clearance, M20 regression,
  and M4 crest on the nominal major diameter.
- `components/standards/standards_test.mbt` — `d3 = d - 2h3`,
  `D1 = d - 2H1`, thread ridge widths, and the 60-degree included angle for
  every supported size.
- `components/motion/motion_test.mbt` — exact spring bounding box, shoulder
  fillet location (torus major 7.0), equal diameters, maximum fillet, bearing
  roller spacing and chamfer fit.
- `components/motion/keyed_shaft_test.mbt` — key height is independent of the
  keyway depth and negative heights are rejected.
- `components/assemblies/assemblies_test.mbt` — floating-member detection is
  independent of insertion order; kit/grid short-screw placements; collision
  policy; largest-deviation feature aggregation; bolted-joint length override.
- `components/gears/gear_mesh_test.mbt` — odd planet-tooth ring phase with a
  non-vacuous negative control, planet-to-planet clearance, external backlash
  bound, and undercut disclosure.
- `components/collision/collision_test.mbt` — a collision aggregate has zero
  separation after an earlier clearance pair.

## Unit tests

```bash
./test-all.sh
```

Result after the chamfer/fillet session: **457 tests, 457 passed, 0 failed**
(432 at the start of that session; 408 before the earlier audit; 345 before the
component work). `test-all.sh` also runs `moon fmt` and
`moon info --target native`.

New regression coverage added by the feature session:

- `cad/profile-chamfer_wbtest.mbt` — 2D chamfer/fillet area, oversized
  rejection, convex-only selection, explicit indices, winding, asymmetric angle.
- `cad/revolved_profile_wbtest.mbt` — analytic cylinder/cone/sphere/torus
  surface counts, planar caps, poles, annular rings, bbox, validation errors.
- `cad/chamfered_prism_wbtest.mbt` — chamfered prism faces and rejection.
- `components/fasteners/fasteners_test.mbt` — ISO 7380/10642 dimensions, layers,
  and standard designation.
- `components/motion/motion_test.mbt` — analytic sphere balls and detailed ring
  chamfers.

- `components/collision/collision_test.mbt` — contact vs collision vs
  clearance, penetration depth, AABB false-positive rejection, OBB placement.
- `components/assemblies/extrusion_frame_test.mbt` — member count, cut
  lengths, endpoints, overall dimensions, pairwise interference, intended
  contacts, connectivity, no floating members, invalid boundaries, STEP
  round-trip, and additional frame sizes.
- `components/gears/gear_mesh_test.mbt` — external gear mesh cycle,
  non-divisible planetary phasing, and planet/ring clearance.

## STEP validation

```bash
python3 scripts/validate_step.py <file.step>
```

The validator checks ISO 10303-21 syntax, real-number grammar, reference
integrity, per-shell edge usage and orientation, `PLANE` planarity, OCCT
`checkshape`, and watertight tessellation.

### Degenerate facets at singular poles

A singular surface of revolution (cone apex, sphere pole) makes OCCT's
tessellator emit a zero-area facet there. Such a facet has no surface area and
its coincident edge is not a real boundary. `scripts/validate_step.py` now
excludes degenerate facets from the watertight edge count and reports how many
it ignored (for example `2 degenerate facets ignored at singular points`). This
fixes a false negative that also affected an OCCT-generated sphere; genuine open
boundaries (an edge used once by a non-degenerate facet) still fail. It is not
a relaxation of the watertightness requirement.

### Feature measurement

`scripts/measure_step_features.py` reports surface-type counts and the
parameters of every cone (radius and semi-angle in degrees), sphere, and torus,
along with the declared plane-angle unit. It is used to confirm that a chamfer
or fillet produced real conical/toroidal/spherical geometry:

```bash
python3 scripts/measure_step_features.py \
  components/examples/output/revolution-torus.step \
  components/examples/output/iso10642-M4x16-detailed.step
```

Representative output: the revolve torus reports four `TOROIDAL_SURFACE` faces
(major 5, minor 1); the ISO 10642 head reports a `CONICAL_SURFACE` with a 45°
semi-angle; the chamfered ISO 4032 nut reports all-planar faces (ruled chamfer
quads); the 608 bearing reports `SPHERICAL_SURFACE` balls.

Representative results:

| Artifact | Solids | Faces | Result |
|---|---:|---:|---|
| `iso4762-M4x20.step` | 3 | 62 | OK |
| `iso4762-M4x20-fully-modeled.step` | 5 | 2825 | OK |
| `iso4032-M4.step` | 1 | 56 | OK |
| `iso4032-M4-fully-modeled.step` | 2 | 590 | OK |
| `iso7089-M5.step` | 1 | 98 | OK |
| `iso4017-M5x20.step` | 2 | 11 | OK |
| `iso4014-M8x40.step` | 2 | 11 | OK |
| `din976-M8x200.step` | 1 | 3 | OK |
| `kit-M4x20-flat.step` | 5 | 216 | OK |
| `frame-2020-400x300x500.step` | 12 | 1128 | OK |
| `gear-pair-m2-20x40.step` | 2 | 2652 | OK |
| `planetary-m2-s12-p12-r36-3.step` | 5 | 2598 | OK |
| `motion-608-stack.step` | 22 | 573 | OK |
| `spring-10x1x20.step` | 1 | 4610 | OK |

All 31 flat fixtures in `components/examples/output/` pass
`validate_step.py --no-mesh`; the larger ones above were also checked with
tessellation enabled (`occt mesh: 0 open edges`).

## Assembly product structure

`components/examples/output/assembly-structure/kit-M4x20-assembly.step` is the
STEP product/occurrence representation. It passes syntax, references, shell
topology, orientation, and planarity. The repository's OCCT stage asks OCCT to
read a single named shape and reports "a is not a topological shape" for an
assembly document. See `KNOWN_ISSUES.md`; the flat kit export is the fully
validated form.

## Independent frame post-export validation

`scripts/validate_frame_geometry.py` re-imports a frame STEP with OCCT,
re-derives the member schedule in Python, and checks every solid's bounding box,
volume, and pairwise overlap. Results:

| Frame | Solids | Worst bbox error | Worst volume error | Positive-volume overlaps | Result |
|---|---:|---:|---:|---:|---|
| 400 x 300 x 500 | 12 | 1e-07 mm | 5.61e-07 | 0 | PASS |
| 600 x 300 x 400 | 12 | 1e-07 mm | 2.42e-06 | 0 | PASS |
| 45 x 45 x 45 | 12 | 1e-07 mm | 4.79e-07 | 0 | PASS |
| 400 x 300 x 500, 2040 profile | 12 | 1e-07 mm | 2.19e-06 | 0 | PASS |

The independent section area for the generic 2020 envelope is
192.345108 mm^2 (rectangle minus four tapered T-slot notches minus the 48-gon
core bore), which matches the OCCT-measured volume / cut length to the errors
above.

## Golden-reference results

External candidates were downloaded to a temporary directory, checksum-verified,
and measured with OCCT. Full provenance is in
`components/testdata/golden/manifest.json`; the policy is in
`components/GOLDEN_REFERENCES.md`.

| Fixture | Verdict | Evidence |
|---|---|---|
| ISO 4762 M3 x 10 | accepted envelope | 5.5 x 5.5 x 13.0 matches |
| ISO 4762 M4 x 20 | accepted envelope | 7.0 x 7.0 x 24.0 matches |
| ISO 4762 M5 x 10 | **rejected** | head diameter 9.2003 mm vs ISO max 8.5 |
| ISO 4032 M4 | height accepted | 3.2027 vs 3.2 mm; plan bbox not confirmable |
| ISO 7089 M4 | **rejected** | thickness 1.8 mm vs ISO 7089 h = 0.8 |
| 608ZZ bearing | accepted envelope | 22 x 22 x 7 matches |
| 2020 B-slot6 profile | envelope only | 20 x 20 x 50 matches; section not compared |
| Spur gear m2 z20 bore8 | accepted envelope | 44 x 44 x 16 matches |

The golden files are downloaded by the repository owner, so these
comparisons run when the fetch procedure has been executed. No planetary
assembly golden is present; planetary checks are analytic.

## Reproduce

```bash
./components/examples/generate_all.sh
```

## Additions (2026-11-10)

- **Golden harness:** `scripts/compare_golden.py` reports PASS/FAIL/SKIP per
  check. It verifies checksums when files are present, uses the downloaded golden
  file when present, generates parts through the example CLIs, measures
  them with OCCT and the STEP feature inventory, checks normative bbox/solid
  counts and feature expectations, and runs analytic checks when the external
  file is absent. See `GOLDEN_REFERENCES.md`.
- **Feature-record tests:** every family asserts its modeled / approximated /
  omitted lists, including detail-level differences; the STEP header is checked
  to carry the record.
- **Evaluated edge features (OCCT-gated):** a cylinder top-rim fillet must
  produce a `TOROIDAL_SURFACE`, a chamfer a `CONICAL_SURFACE`, and both must
  pass `validate_step.py`. The flat writer must raise the typed
  `EdgeFeatureRequiresKernel` diagnostic; it is never allowed to emit the
  sharp base.
- **Gear features:** the root-filleted/tip-chamfered outline must be a simple
  polygon with the stated chord deviation, and the extruded pair must pass the
  STEP validator. A generated m2 20/40 pair with root fillet 0.4 and tip
  chamfer 0.1 validates with 1932 planar faces and OCCT `checkshape`.
- **Extrusion corner radii:** a 1.5 mm-radius 2020 frame validates; OCCT
  measures a post section area of 190.37 mm² (sharp 192.345 mm²).
- **Mixed assembly:** the bolted joint is checked for instance count, bbox,
  connectivity, contacts, and 7 watertight solids; nested-bore OBB false
  positives are documented rather than reported as clearance.
- **Property sweeps:** fastener sizes/lengths, bearing designations, gear
  modules/teeth, extrusion series, frame dimensions, and a fixed-seed transform
  round-trip/composition sweep.

Final `./test-all.sh`: **495 tests, 495 passed, 0 failed**.


## Exact internal ring, keyway, and harness self-test (2026-11-10)

- **Golden harness self-test:** `scripts/compare_golden.py --self-test` proves
  PASS/FAIL/SKIP, checksum gating, units/frame normalization, and the
  `vertex_radius_present_mm` feature kind. It passes all eight cases; a skipped
  check is never reported as a pass.
- **Internal involute ring and mesh cycle:** the profile is a simple closed
  bore boundary whose minimum/maximum radii equal the tip/root circles; tooth
  thickness follows the internal relation. `internal_mesh_interference` samples
  32 poses over one planet pitch while the ring turns at `z_p / z_r` in the same
  direction; it must report zero crossings. A zero-backlash z36/z12 control must
  report crossings, proving the check is sensitive. The exact-ring planetary
  STEP is five watertight solids and passes OCCT `checkshape`.
- **Keyed shaft:** the cross-section is a simple notched disc; the extruded body
  is one watertight solid. A key sized from the keyway stays inside the slot
  envelope and does not pierce the shaft wall. The shaft + key STEP is two
  closed solids.
- **Independent kernels:** OCCT and SolidCraft agree on the keyed-shaft volume
  (12161.0 mm³) and the exact-ring planetary volume (34744.0 mm³, 0.0001 %
  difference), and SolidCraft imports both with zero errors and all bodies
  closed. The SolidCraft renders are diagnostic, not the acceptance criterion.
- **Promoted golden fixtures:** 19 fixtures report `PASS`; external geometry is
  `SKIP` when no golden file is present. No `FAIL`. The rejected
  washer and rod references are recorded with their contradictory measurements.

Final state after these additions: run `./test-all.sh` and
`python3 scripts/compare_golden.py` for the current counts.


## Round 7 additions (2026-11-10)

### Commands and results

```bash
./test-all.sh
# 546 tests, 546 passed, 0 failed

python3 scripts/compare_golden.py
# 19 fixtures PASS, external geometry SKIP, 0 FAIL, exit 0

python3 scripts/compare_golden.py --self-test
# 15/15 checks PASS (PASS/FAIL/SKIP, checksum, units/frame, feature kinds,
# mass properties, section area, surface deviation, vertex ring)

python3 scripts/golden_matrix.py --write components/testdata/golden
# 108 cells, NORMATIVE 108 PASS / 0 FAIL, GOLDEN 39 PASS / 54 FAIL / 15 SKIP

python3 scripts/golden_matrix.py --self-test
# PASS
```

### Measured chamfer evidence

`scripts/measure_step_features.py --json` on
`iso4762-M4x20-detailed.step` reports these real vertex rings:

```text
z=0.0   r=1.5995  (tip chamfer: 2.0 - 0.4)
z=0.4   r=2.0000  (full shank radius)
z=22.0  r=1.7321  (nominal socket hex circumradius, s=3.0)
z=24.0  r=2.0785  (lead-in top hex, s+2c = 3.6)
z=24.0  r=2.7992  (head top ring, 3.5 - 0.7)
```

`iso4032-M4-fully-modeled.step` reports the face-chamfer ring at both
`z=0` and `z=3.2` with circumradius `3.2332` (from `4.0415 - 0.7/cos30`) and
the internal-ridge crest at the basic minor radius.

### Independent mass, section, and surface checks

The manifest now carries analytic washer checks and bearing ball-radius checks:

- ISO 7089 M4 at `z=0.4`: section area 49.016 mm² vs analytic 49.095 mm²
  (0.16 %, tessellation chord error); volume 39.213 mm³ vs 39.276 mm³; centre
  of mass `z=0.4`.
- 608 bearing: ball radius 0.7 mm (diameter 1.4 mm), independently re-derived
  from the boundary dimensions; 16 spherical surfaces (8 balls × 2 hemispheres).
- Surface deviation: identical shapes 0.000000 mm; M4 vs M5 washer 0.5385 mm.

### STEP validation of the new geometry

```text
iso4762-M4x20-detailed.step   [PASS] syntax/reals/references/shells/topology/
                                     orientation/planarity/OCCT checkshape
iso4017-M4x20-detailed.step   [PASS] same gates
iso10642-M4x16-detailed.step  [PASS] same gates
iso4032-M4-fully-modeled.step [PASS] same gates, 620 planar faces
```

### Honest skips

- External golden geometry: compared against the downloaded models; a
  missing file is `SKIP`. The measurements are recorded in
  `components/testdata/golden/matrix.json`.
- No 3D kinematic gear-contact solver: the planetary check remains a 2D outline
  rotation cycle.

### Independent second kernel (SolidCraft, round 7)

The new detailed screw and the fully modeled nut were imported into SolidCraft
(SMLib kernel) as an independent B-Rep implementation:

| Model | OCCT volume (mm³) | SolidCraft volume (mm³) | Bodies | Closed |
|---|---:|---:|---:|---|
| ISO 4762 M4 x 20 Detailed | 382.687 | 382.687 | 3 | all |
| ISO 4032 M4 FullyModeled | 92.7776 | 92.7777 | 2 | all |

SolidCraft reports the expected bounding boxes: screw `±3.5 x ±3.5 x 0..24`,
nut `±3.5 x ±4.0415 x 0..3.2`. Both imports report 0 errors. The screw's shank
body has 130 faces (tip chamfer), the head socket 142 faces (head chamfer and
socket lead-in), and the nut body 84 faces (both face chamfers) plus a 536-face
internal helical ridge.

Renders (`iso` view) show the hex socket with its flared lead-in, the head top
bevel, the shank tip break, and the nut face chamfers with the cyan internal
ridge. The numeric agreement is the acceptance evidence; the render is
supplementary.
