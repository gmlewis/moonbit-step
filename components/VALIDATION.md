# Validation Summary

Environment: macOS, MoonBit `moon 0.1.20261104 (940aa18 2026-11-04)`,
`moonc v0.10.20+65efd5b93`; OCCT `DRAWEXE` and `gmsh` present.

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

Honest skips: no external file is committed (per-file license unverified), so
these comparisons run only when the fetch procedure has been executed. No
planetary assembly reference was available; planetary checks are analytic.

## Reproduce

```bash
./components/examples/generate_all.sh
```

## Additions (2026-11-10)

- **Golden harness:** `scripts/compare_golden.py` reports PASS/FAIL/SKIP per
  check. It verifies checksums when files are present, gates external geometry
  on a verified licence, generates parts through the example CLIs, measures
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
  `SKIP` because every per-file licence is unverified. No `FAIL`. The rejected
  washer and rod references are recorded with their contradictory measurements.

Final state after these additions: run `./test-all.sh` and
`python3 scripts/compare_golden.py` for the current counts.
