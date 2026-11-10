# Session Report 05 — Golden Validation, Exact Internal Ring, and Keyways

## 1. Starting state and toolchain

- Branch: `master`.
- HEAD at session start: `b825f5e9ea2931d8ee52456abe6ac0ee138651ff`
  (`Work on components`).
- Toolchain: `moon 0.1.20261104 (940aa18 2026-11-04)`,
  `moonc v0.10.20+65efd5b93 (2026-11-05)`.
- Baseline `./test-all.sh`: **495 tests, 495 passed, 0 failed**.
- Optional tools present: OCCT `DRAWEXE`, `gmsh`, `rsvg-convert`, macOS `sips`,
  the repository Python validators/measurement scripts, and the SolidCraft MCP
  server (used as an independent kernel).

Note: the MoonBit toolchain bumped `moonbitlang/async` in `moon.mod` from
`0.22.7` to `0.22.9` while resolving the module; this was tool-driven, the suite
is green with it, and the owner can review or pin it.

## 2. Final results

- `./test-all.sh`: **511 tests, 511 passed, 0 failed** (+16 tests).
- `python3 scripts/compare_golden.py`: 19 generated fixtures report `PASS`;
  external geometry is `SKIP` for every fixture because the per-file licence is
  unverified; no `FAIL`.
- `python3 scripts/compare_golden.py --self-test`: 8/8 cases pass.
- `components/examples/generate_all.sh`: every generated STEP validates with
  `scripts/validate_step.py` and OCCT `checkshape`; the analytic frame geometry
  validator passes for all three frames.

## 3. What was built

### 3.1 Exact internal involute ring gear (Stage H)

`components/gears/internal.mbt` adds:

- `internal_ring_geometry(module, teeth, pressure_angle, addendum_factor~,
  dedendum_factor~)` — tip/tip/root radii with the internal sign convention.
- `internal_involute_ring_profile(...)` — the exact internal involute bore
  boundary. Tooth thickness is
  `psi(r) = psi_p + inv(a_r) - inv(a_p)` (thickness grows outward), the inverse
  of the external formula. Tooth 0 is centred on +X. A tip radius at or below
  the base circle is a typed error rather than a truncated involute.
- `internal_mesh_interference(...)` — samples one planet angular pitch (32
  poses by default) while the ring turns in the same direction at
  `z_p / z_r`; returns the number of proper planet/ring outline crossings.
- `internal_ring_gear_exact(...)` — a body whose bore is the exact envelope,
  with the machine-readable feature record
  `internal-involute-tooth-envelope`.

`planetary_gear_set()` now uses the exact ring and applies a default
circumferential backlash of `0.05 * module` to the sun, planet, and ring. The
old trapezoidal `internal_ring_gear()` is retained as an explicit fallback; it
was not silently replaced.

The earlier session's 300+ crossings came from two causes: the external
tooth-thickness sign (which made the ring space too narrow) and the ring tooth
tip grazing the planet flank. Both are fixed; the zero-backlash control still
reports crossings, which proves the passing test is not vacuous.

### 3.2 Keyed shaft with a real keyway (Stage K)

`components/motion/keyed_shafts.mbt` adds:

- `keyed_shaft_cross_section(...)` — a circular section with a real
  rectangular keyway notch on +Y. The slot sides are at `x = +-w/2` and the
  flat bottom is at `y = r - depth`; the section is a simple polygon.
- `keyed_shaft(...)` — extrudes the notched section into one watertight solid.
  The keyway is real geometric material removal, not a nominal boolean.
- `key_for_keyway(...)` — a matching key with X = width, Y = height, Z = length
  and a declared side clearance.

Example: `components/examples/keyed_shaft`, producing the shaft and key as two
closed solids. The keyway ends are square (documented omission
`keyway-end-radius`).

### 3.3 Golden validation expansion (Stage G)

- The manifest now carries 23 external references (14 newly promoted): ISO
  4032 M3/M5, ISO 7089 M3/M5, ISO 7380 M4/M5, ISO 10642 M4/M5, ISO 4017 M5,
  bearings 6000/6001/6200, a z40 spur gear, and rejected records for the
  nonconforming washer and threaded-rod references.
- `scripts/compare_golden.py` adds `volume_mm3` and
  `vertex_radius_present_mm` comparison kinds, units/frame normalization
  (`normalize_extents`), and a `--self-test` mode.
- `scripts/measure_step_features.py` now emits `vertex_radius_clusters`, so a
  named gear tip/root radius can be checked from the generated polyline.
- The harness self-test proves PASS on a matching fixture (with the external
  geometry check actually running), FAIL on a wrong expected dimension,
  `SKIP` + normative PASS for a missing/unlicensed external file, FAIL on a
  checksum mismatch, Y-up/inch normalization, unknown-unit rejection, and the
  present-radius feature kind.

### 3.4 Catalogue and tests

- `gear_catalog` now uses the exact ring; new `motion_catalog` exposes the
  keyed shaft and key.
- New tests: `components/gears/internal_gear_test.mbt` (10 tests),
  `components/motion/keyed_shaft_test.mbt` (6 tests), a catalogue motion test,
  and sweep tests for both new features.
- Fastener feature records now record `thread-runout` on the helical path and
  assert the `socket-lead-in-chamfer`, `shank-tip-chamfer`, and
  `under-head-radius` typed omissions.

## 4. Defects found

| # | Severity | Defect | Evidence | Resolution |
|---|---|---|---|---|
| 1 | High | An early exact internal ring used the external tooth-thickness sign and grazed the ring tip; the mesh crossed through the cycle | 300+ crossings reported by the prior session; reproduced independently in a Python model | Correct internal sign plus a declared `0.05 * module` backlash; 32-pose cycle now has zero crossings |
| 2 | Medium | Washer golden references do not follow ISO 7089 thickness | M3 1.1 mm vs 0.5, M4 1.8 vs 0.8, M5 2.2 vs 1.0 | Rejected as oracles and recorded with evidence |
| 3 | Medium | The "M3 x 200" threaded-rod reference models a 3 x 400 mm cylinder | bbox 3 x 3 x 400, volume 2827.43 mm³ | Rejected and recorded with evidence |
| 4 | Low | ISO 4017 M5 reference overall length is 23.74 mm vs the nominal L + k = 23.5 mm | bbox z 23.74 vs 23.5 | Marked head-width-only; the parametric check is normative |

No pre-existing failure was present or introduced.

## 5. New kernel primitives

- `internal_involute_ring_profile` / `internal_ring_geometry` /
  `internal_ring_gear_exact` / `internal_mesh_interference` (2D exact bore
  envelope and rotation-cycle outline check).
- `keyed_shaft_cross_section` / `keyed_shaft` / `key_for_keyway` (notched
  section extrusion).
- `FeatureRecord::has_omitted` (small query addition).
- Harness: `volume_mm3`, `vertex_radius_present_mm`, `normalize_extents`,
  `--self-test`, `vertex_radius_clusters`.

## 6. Files changed

New:

- `components/gears/internal.mbt`
- `components/gears/internal_gear_test.mbt`
- `components/motion/keyed_shafts.mbt`
- `components/motion/keyed_shaft_test.mbt`
- `components/examples/keyed_shaft/{main.mbt,moon.pkg}`
- `components/SESSION_REPORT_05.md`

Modified (source/docs):

- `components/gears/planetary.mbt`, `components/gears/pkg.generated.mbti`
- `components/motion/pkg.generated.mbti`
- `components/common/features.mbt`
- `components/fasteners/features.mbt`, `components/fasteners/fasteners_test.mbt`
- `components/catalog/catalog.mbt`, `components/catalog/catalog_test.mbt`
- `components/examples/gear_pair/main.mbt` (single-gear mode)
- `components/examples/generate_all.sh`
- `scripts/compare_golden.py`, `scripts/measure_step_features.py`
- `components/testdata/golden/manifest.json`
- `components/{FEATURES,KNOWN_ISSUES,GOLDEN_REFERENCES,VALIDATION,GEOMETRY,
  PROGRESS,README}.md`
- Regenerated `components/examples/output/*.step` (feature-record headers and
  the exact-ring planetary).

## 7. Algorithms, controls, and tolerances

- **Internal involute:** `inv(a_r) = tan(a_r) - a_r`,
  `a_r = acos(r_b / r)`, `psi(r) = psi_p + inv(a_r) - inv(a_p)`,
  `psi_p = pi/(2z) - backlash/(2 r_p)`. Flanks are sampled with
  `involute_points`; tip/root arcs with `arc_points`.
- **Rotation cycle:** the planet advances one angular pitch over `phases`
  poses; the ring turns `z_p/z_r` in the same direction (the internal rolling
  condition). Proper segment crossings only; endpoint contact is not a
  crossing.
- **Keyway:** circle plus a rectangular notch; the shaft section arc is a
  polyline with chord deviation `r(1 - cos(pi/segments))`.
- **Golden tolerances:** linear 0.01 mm, volume relative 5 %, contact
  0.001 mm, surface deviation 0.01 mm.
- **Independent measurements:** OCCT and SolidCraft agree on the keyed shaft
  (12161.0 mm³) and the exact-ring planetary (34744.0 mm³, 0.0001 %).

## 8. Golden fixtures examined

The full record is in `components/testdata/golden/manifest.json` and
`GOLDEN_REFERENCES.md`. Accepted envelopes: ISO 4762 M3/M4/M5, ISO 4032
M3/M4/M5, ISO 7380 M4/M5, ISO 10642 M3/M4/M5, bearings 608/6000/6001/6200,
spur gears m2 z20/z40. Rejected: ISO 7089 M3/M4/M5 (thickness), the "M3 x 200"
rod (400 mm model). Head-width-only: ISO 4017 M5. Envelope-only: the 2020
B-slot6 profile (section differs; licence unverified).

## 9. Components compared and the method

- Fasteners and bearings: OCCT bbox/volume/solids plus STEP feature inventory
  (surface counts, cone angle, sphere count, vertex radii); the harness
  generates through the example CLI.
- Gear: OCCT bbox plus clustered vertex radii for the tip (42.0) and root
  (37.5) circles.
- Keyed shaft and planetary: OCCT and SolidCraft (independent kernel), plus
  SolidCraft renders inspected with vision.
- Frames: `scripts/validate_frame_geometry.py` (independent OCCT re-import).

## 10. Analytic-only validation

- Internal involute tooth form and the planet/ring rotation cycle (no licensed
  gear or planetary reference).
- The keyway/key fit and the keyed-shaft section (no standard key table is
  claimed).
- The extrusion section (generic envelope; the B-slot6 golden is not
  section-equivalent).
- The catalogue records (built from the real builders).

## 11. Tests and commands

```bash
./test-all.sh
python3 scripts/compare_golden.py
python3 scripts/compare_golden.py --self-test
bash components/examples/generate_all.sh
python3 scripts/measure_step_occt.py <file>.step
python3 scripts/measure_step_features.py --json <file>.step
python3 scripts/validate_step.py --no-mesh <file>.step
```

Counts: final suite 511/511; golden 19 fixtures PASS, external SKIP, 0 FAIL;
self-test 8/8.

## 12. Tool availability and use

- OCCT `DRAWEXE`: `checkshape`, tessellation, volume, bbox, feature inventory.
- `gmsh`, `rsvg-convert`, `sips`, and the Python validators: available.
- SolidCraft MCP: independent STEP import, volume/bbox/topology, and renders
  (keyed shaft and exact-ring planetary); zero import errors, all bodies
  closed, volumes agree with OCCT.
- Blender/CadCraft/PicoGK: not needed for this session's acceptance; no claim
  is made that they were used.

## 13. Remaining known issues and deferred work

- Extrusion framing hardware (end caps, corner brackets, joining plates,
  T-nuts) and a bracket/T-nut frame are still deferred; only the generic
  profile and butt-jointed frame exist. These require verified dimensions.
- Thread runout/lead-in, socket lead-in chamfers, shank tip chamfers, and
  under-head radii are typed omissions, not modelled geometry.
- Evaluated 3D chamfer remains single-edge in this OCCT DRAW build.
- Nested-bore OBB collision false positives remain; a shape-aware clearance
  test is still required.
- Keyway ends are square, not end-milled; the key is sized by a declared
  clearance, not a standard key table.
- Internal ring: no profile shift, helix, root fillet, or tip chamfer;
  internal meshes need the declared backlash.
- External golden files are not committed (per-file licences unverified), so
  external geometry comparison is `SKIP` by design.

## 14. Reproduction

```bash
# Exact ring and planetary
moon run --target native components/examples/planetary -- -o /tmp/planetary.step
python3 scripts/validate_step.py --no-mesh /tmp/planetary.step

# Keyed shaft and key
moon run --target native components/examples/keyed_shaft -- \
  --diameter 20 --length 40 --keywayWidth 6 --keywayDepth 3.5 -o /tmp/keyed.step
python3 scripts/measure_step_occt.py /tmp/keyed.step

# Golden validation
python3 scripts/compare_golden.py
python3 scripts/compare_golden.py --self-test
```

## 15. Git state

No push, release, commit, or remote Git modification was performed. The owner
runs all state-changing Git commands. Generated artifacts remain under
`components/examples/output/`; external golden files remain out of Git.
