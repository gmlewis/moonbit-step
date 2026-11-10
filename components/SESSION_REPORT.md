# Session Report — Feature Metadata, Golden Harness, and Remaining Features

## 1. Starting state

- Branch: `master`.
- HEAD at session start: `4fc5381fdd56e4204404f0529fff5144cac1da19`
  (`Implement chamfers and fillets`).
- Toolchain: `moon 0.1.20261104 (940aa18 2026-11-04)`,
  `moonc v0.10.20+65efd5b93 (2026-11-05)`.
- Baseline `./test-all.sh`: **458 tests, 458 passed, 0 failed**.
- Optional tools present: OCCT `DRAWEXE` at `/opt/homebrew/bin/DRAWEXE`,
  `gmsh`, Python validators/measurement scripts, `rsvg-convert`.
- The Git-ignored golden corpus `components/testdata/golden/external/` holds
  170 STEP files and `fetch-report.json`.

## 2. Final results

- `./test-all.sh`: **495 tests, 495 passed, 0 failed** (+37 tests).
- `scripts/compare_golden.py`: 6 fixtures, all `PASS` on normative/analytic
  checks, external geometry `SKIP` (per-file licence unverified). No `FAIL`.
- Generated artifacts validated with `scripts/validate_step.py` (syntax,
  references, closed shells, orientation, planarity, OCCT `checkshape`).

## 3. What was built

### Machine-readable feature metadata (Stage M)

- `components/common/features.mbt`: `ApproximationKind` (`PolylineArc`,
  `PolygonRevolve`, `SweptSpline`, `EngineeringDefault`), `Approximation`,
  `Omission`, `FeatureRecord`, and `chord_deviation`.
- `Component` now carries `FeatureRecord`; `Component::documentation()` appends
  it to the STEP header; `Component::features()`/`with_features()` expose it.
- Every builder populates the record: ISO 4762, 4032, 7089, 4014, 4017, 7380,
  10642, DIN 976, bearings, shafts, spacers, keys, pins, standoffs, springs,
  extrusion profiles, gears. `Assembly::features()` aggregates instances.
- Tests assert detail-level differences (detailed nut models
  `nut-face-chamfer`; simplified omits it with a reason; bearings list
  `ball-sphere`; fully modeled lists `helical-thread`).

### Golden comparison harness (Stage M)

- `scripts/compare_golden.py`:
  - verifies SHA-256 and byte size when the external file is present;
  - gates external geometry comparison on a verified licence (all current
    fixtures are `unverified-per-file`, so it reports `SKIP`);
  - generates the parametric part through the example CLI;
  - measures with OCCT (solids, bbox, volume) and `measure_step_features.py`
    (surface types, cone/sphere/torus parameters, vertex radii);
  - checks normative bbox extents, solid count, feature expectations, and an
    optional lower-detail face-count contrast;
  - reports `PASS`/`FAIL`/`SKIP` per check and per fixture.
- `scripts/measure_step_features.py` now reports minimum/maximum vertex radii.
- Manifest recipes added for ISO 4762 M3/M4, ISO 4032 M4, ISO 7089 M4, 608
  bearing, and ISO 10642 M3.
- New example `components/examples/bearing` generates a single bearing.

### Optional evaluated 3D fillet/chamfer (Stage N)

- `Shape::Fillet(EdgeFeature)` / `Shape::Chamfer(EdgeFeature)` with
  `EdgeSelector` (`AllEdges`, `EdgesByDirection`, `EdgesNearPoint`,
  `EdgeIndices`), a size, and an optional angle; builders `fillet_edges` and
  `chamfer_edges`.
- The flat writer refuses with the typed `EdgeFeatureRequiresKernel` error.
- `Design::to_csg_step()` emits `MOONBIT_EDGE_FEATURE`; `scripts/csg_eval.py`
  selects edges (via OCCT edge bounds) and applies `blend` or `chamf`.
- OCCT tests: a cylinder top-rim fillet produces `TOROIDAL_SURFACE`; a chamfer
  produces `CONICAL_SURFACE`; both pass the validator.

### Gear features and mesh cycles (Stage O)

- `external_involute_outline_ex()` applies true root fillets and tip chamfers
  to the involute outline, using the 2D profile helpers with root/tip run
  collapsing and an adaptive root band. Rejected sizes return typed errors.
- Feature records list `root-fillet`/`tip-chamfer` when present.
- A fixed-centre sun/planet rotation-cycle test covers a full mesh cycle.
- Exact internal involute ring: implemented, failed the rotation-cycle check
  (300+ crossings), and was removed rather than shipped; the validated
  trapezoidal approximation is retained with the omission recorded.

### Extrusion features (Stage P)

- `TSlotProfile::with_corner_radius()` rounds the four outer corners; the
  corner arc deviation is recorded.
- Generic 2060/2080/3060/4080 envelopes added (labelled generic).
- Explicit test: the generic 2020 envelope's solid section area (192.345 mm²)
  is not the B-slot6 golden section (174.336 mm²), so no equivalence is
  claimed and no preset is derived from the unlicensed golden.
- The `extrusion_frame` example supports `--cornerRadius` and the new series.

### Catalogue and mixed assembly (Stage Q)

- `components/catalog`: `CatalogEntry`, `lookup`, `query`, and per-family
  catalogues built from the real component builders.
- `assemblies::bolted_joint` (two plates, ISO 4762 screw, ISO 7089 washer,
  ISO 4032 nut); 7 watertight solids; connectivity and contacts checked.
- New example `components/examples/bolted_joint`.
- Property/parameter-sweep tests with a documented fixed seed.

## 4. Defects found and fixed

| # | Severity | Defect | Evidence | Fix |
|---|---|---|---|---|
| 1 | High | ISO 10642 countersunk screws placed the head above the shank, giving M3 x 12 an overall length of 13.7 mm instead of 12.0 mm | `compare_golden.py` bbox check on the ISO 10642 M3 golden (12.0 mm measured) | Head now occupies the top `k` mm of the nominal length; overall equals the nominal length |
| 2 | Medium (avoided) | An "exact" internal involute ring would have shipped unvalidated | Fixed-centre rotation-cycle mesh test found 300+ planet/ring crossings | Removed the involute profile; retained the validated trapezoid and documented the omission |
| 3 | Low | Gear root fillet rejected at high tooth counts because the radial root segment is shorter than the fillet | 40-tooth gear with 0.4 mm fillet failed | Adaptive root band widens until the tangent arc fits; otherwise a typed error |

No pre-existing failure was present or introduced.

## 5. New kernel primitives and representation

- **`FeatureRecord`** — machine-readable modeled/approximated/omitted lists with
  deviations and controls; carried on `Component` and in the STEP header.
- **`EdgeFeature` / `EdgeSelector` / `Fillet` / `Chamfer`** — intent for
  evaluated edge operations; refused by the flat writer and evaluated by OCCT.
- **`MOONBIT_EDGE_FEATURE`** — a STEP data entity emitted only by the CSG path,
  interpreted by `scripts/csg_eval.py`; never emitted by the flat writer.
- **Gear outline feature post-processing** — run collapsing and adaptive root
  band, producing true 2D fillet/chamfer arcs on the involute outline.
- **`TSlotProfile::corner_radius_mm`** — outer corner radii via 2D fillets.

## 6. Chamfer/fillet algorithms, controls, and tolerances

- **2D chamfer:** equal legs by default; optional angle via the law of sines;
  rejected when the adjacent edges cannot absorb the cut.
- **2D fillet:** tangent length `r/tan(theta/2)`, centre `r/sin(theta/2)`;
  arc sampled with `segments`; chord error `r(1-cos(pi/segments))`.
- **Evaluated 3D fillet:** OCCT `blend` with one radius per selected edge.
- **Evaluated 3D chamfer:** OCCT `chamf` equal-distance on one selected edge
  (this DRAW build exposes no multi-edge 3D chamfer); angled chamfers need a
  reference face and are refused.
- **Gear root fillet:** root band `r`, adaptive ×1.5 up to half the addendum
  height; `fillet_segments` controls the arc; deviation reported.
- **Prism chamfer:** parallel inset, planar ruled quads.
- **Tolerances:** feature record `tolerance_mm` default 0.01 mm; golden
  tolerances linear 0.01 mm, volume 5 %, contact 0.001 mm, surface deviation
  0.01 mm.

## 7. Golden fixtures examined

All checksums verify against `manifest.json`; no external file is committed
(per-file licence unverified).

| Fixture | SHA-256 verified | Verdict |
|---|---|---|
| ISO 4762 M3 x 10 | yes | accepted-envelope; harness PASS |
| ISO 4762 M4 x 20 | yes | accepted-envelope; harness PASS |
| ISO 4762 M5 x 10 | yes | rejected (head 9.2003 > 8.5 mm) |
| ISO 4032 M4 | yes | accepted-height-only; harness PASS |
| ISO 7089 M4 | yes | rejected (thickness 1.8 vs 0.8 mm) |
| 608ZZ bearing | yes | accepted-envelope; harness PASS |
| 2020 B-slot6 profile | yes | envelope-only; explicitly not section-equivalent |
| Spur gear m2 z20 | yes | accepted-envelope |
| ISO 10642 M3 x 12 | yes | accepted-envelope; harness PASS (found the length defect) |

Rejected references were rejected on independent dimension contradictions and
are never used as pass criteria.

## 8. Components compared against references

- ISO 4762 detailed: bbox, solid count, and a detailed-vs-simplified face-count
  contrast (80 added faces) prove the head chamfer band exists.
- ISO 4032 detailed: bbox, solid count, 28 added faces (face chamfers).
- ISO 7089: OD, thickness, and vertex radii (bore 2.15, outer 4.5 mm).
- 608 bearing: OD 22, width 7, 10 solids, 16 spherical faces, bore radius 4 mm.
- ISO 10642 M3 x 12: head 6.0, overall 12.0, 45° cone half-angle, 3 solids.
- Extrusion frame: independent OCCT frame geometry validator for the sharp
  profile; rounded-corner post section area 190.37 mm² measured with OCCT.

## 9. Components validated analytically only

- Gear tooth forms and mesh cycles (outline crossing tests, no external gear
  reference was licensed).
- Planetary ring clearance (trapezoidal ring; exact involute deferred).
- Extrusion sections (generic envelopes; the B-slot6 golden is not equivalent
  and its licence is unverified).
- Catalogue entries (built from the real builders; no external oracle).

## 10. Tests and commands

```bash
./test-all.sh                                   # 495 passed
python3 scripts/compare_golden.py               # 6 fixtures PASS/SKIP
python3 scripts/validate_step.py --no-mesh FILE
./components/examples/generate_all.sh
```

New tests cover feature records, the golden harness behaviour (matching/missing
files are handled by the harness itself; the unit tests assert the records and
geometry), flat-writer refusal, evaluated fillet/chamfer (OCCT-gated), gear
root fillet/tip chamfer including rejection, the sun/planet mesh cycle,
extrusion corner radii and B-slot6 non-equivalence, the catalogue, the bolted
joint, and fixed-seed parameter sweeps.

## 11. Tool availability

- OCCT `DRAWEXE` was used for `checkshape`, tessellation, volume, and the
  evaluated fillet/chamfer.
- `gmsh`, `rsvg-convert`, and the Python validators were available; the OCCT
  path was the primary numeric oracle.
- The MCP CAD servers (SolidCraft, Blender, CadCraft, PicoGK) and vision were
  available in the harness. The numeric OCCT/validator results were used as the
  acceptance criterion; no visual claim is made beyond the numeric checks.
- No remote Git state was modified.

## 12. Remaining known issues and deferred features

See `KNOWN_ISSUES.md` for the register. The main deferred items:

- Exact internal involute ring gear (negative rotation-cycle evidence).
- Gear root fillets are polyline arcs with an adaptive band; very high tooth
  counts may reject a requested radius.
- Evaluated 3D chamfer is single-edge in this OCCT DRAW build.
- OBB collision reports nested-bore overlaps as false positives.
- T-nuts, corner brackets, joining plates, end caps, helical gears, and
  verified vendor profiles remain deferred without verified data.

## 13. Honest limitations

- A parseable STEP file is not proof of mechanical validity; every generated
  artifact used here also passed OCCT `checkshape` and watertight tessellation.
- A skipped golden check is reported as `SKIP`, not as a pass.
- The flat writer never emits a sharp edge labelled as a chamfer or fillet.
- The exact internal involute ring is not shipped; the trapezoidal
  approximation is labelled as such in the feature record and catalogue.

## 14. Repository state

No push, release, or commit was performed. The working tree contains the new
and modified files for the owner to review and commit.
