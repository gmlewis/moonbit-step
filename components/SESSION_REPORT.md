# Session Report — Chamfers, Fillets, Analytic Revolve, and New Head Standards

## 1. Starting state

- Branch: `master`.
- Actual HEAD at session start: `42af9e419891dbc89e3e38c016e461c4de2c15ac`
  (the handoff named `7f61240`; two commits — `Update golden references` and
  `Update progress` — were already on top of it).
- Toolchain: `moon 0.1.20261104 (940aa18 2026-11-04)`,
  `moonc v0.10.20+65efd5b93 (2026-11-05)`.
- Baseline `./test-all.sh`: **432 tests, 432 passed, 0 failed**.
- Optional tools present: OCCT `DRAWEXE` at `/opt/homebrew/bin/DRAWEXE`,
  `gmsh`, Python validators/measurement scripts.

## 2. Final test results

- `./test-all.sh`: **458 tests, 458 passed, 0 failed** (+26 new tests).
- `./components/examples/generate_all.sh`: exit 0; 375 `[PASS]` validator
  checks, 0 `[FAIL]`, plus the three independent frame OCCT checks.

## 3. What was built

### Kernel primitives (`@cad`)

- **`Profile2D::chamfer_vertices` / `fillet_vertices`** — real 2D bevels and
  tangent arcs on a polygon, with convex/concave classification, `All` /
  `ConvexOnly` / `ConcaveOnly` / `Indices` selection, fit validation, and a
  self-intersection check. Typed `ProfileOpError`.
- **`RevolvedProfile`** — a solid of revolution compiled to a single closed
  solid with analytic `CYLINDRICAL_SURFACE`, `CONICAL_SURFACE`,
  `SPHERICAL_SURFACE`, `TOROIDAL_SURFACE`, and `PLANE` faces; real seam edges
  and analytic poles. Presets: `cylinder`, `frustum`, `cone`, `sphere`,
  `sphere_cap`.
- **`ChamferedPrism`** — a convex parallel-inset ring stack with an optional
  prismatic through-hole, used for real face/edge chamfers on prisms.
- New STEP entity **`SPHERICAL_SURFACE`** added to the geometry, repository, and
  parse layers.

### Component features

- **ISO 4032 nut** — real 45° face chamfer on both bearing faces at `Detailed`
  and above (ring-stack chamfer).
- **ISO 4762 screw** — real 45° head top-edge chamfer at `Detailed` and above.
- **ISO 7380-1 button head** and **ISO 10642 countersunk head** — new standards
  (M3–M10) with verified head dimensions and real dome/cone geometry plus
  hexagon sockets.
- **Bearing** — cylindrical roller proxies replaced by analytic spheres; rings
  carry an engineering-default edge chamfer at `Detailed` and above.
- **`filleted_stepped_shaft`** — a single revolved solid with an analytic
  toroidal shoulder fillet (measured major radius 6.0 mm, minor radius 2.0 mm
  for a 5→8 mm shoulder with a 2 mm fillet).

### Validation tooling

- `scripts/measure_step_features.py` — surface-type counts and cone/sphere/
  torus parameters.
- `scripts/validate_step.py` — excludes zero-area tessellation facets at
  singular poles from the watertight edge count and reports them; genuine open
  boundaries still fail.
- New example `components/examples/revolution` and
  `components/examples/filleted_shaft`; both added to `generate_all.sh`.

## 4. Defects found and fixed during the session

All were found by the independent OCCT/validator checks, not by inspection
alone.

| # | Defect | Fix | Evidence |
|---|---|---|---|
| 1 | `CIRCLE` placement origin was on the rim, not the center | center the placement; keep the vertex on the rim | cylinder/frustum/ring went from invalid to watertight |
| 2 | `LINE` seam referenced a `DIRECTION` instead of a `VECTOR` | emit a `VECTOR` | OCCT could not read the file before the fix |
| 3 | `CONICAL_SURFACE` / `TOROIDAL_SURFACE` placement was on the surface, not the axis | place the axis point on the revolution axis | frustum/torus volumes became exact |
| 4 | Trimmed-arc seams were interpreted as tiny arcs | use a plain `CIRCLE` edge trimmed by its two vertices | sphere volume 14.35 → 523.599 mm³ |
| 5 | Chamfered-prism side faces used the radial direction as the plane normal | use the true quad normal | planarity failures (0.7 mm) disappeared |
| 6 | Inset beyond the inradius produced a spurious polygon | require strict containment and area decrease | oversized chamfer is now rejected |
| 7 | Validator reported a singular-pole sphere as open | exclude zero-area facets and report the count | OCCT's own sphere also passes now |

## 5. Independent numeric validation

Revolved primitives (OCCT volume vs closed form), all exact:

| Solid | Measured (mm³) | Closed form |
|---|---:|---|
| Sphere R5 | 523.599 | 4/3 π 5³ = 523.599 |
| Cone R4 h8 | 134.041 | 1/3 π 4² 8 = 134.041 |
| Frustum 4→2 h6 | 175.929 | 56π = 175.929 |
| Cylinder R5 h8 | 628.319 | 200π = 628.319 |
| Ring 2..5 h2 | 131.947 | 42π = 131.947 |
| Torus R5 r1 | 98.696 | 2π²·5 = 98.696 |
| Dome rim4 h3 | 89.535 | π·28.5 = 89.535 |

All generated feature artifacts pass `validate_step.py` with OCCT
`checkshape` and watertight tessellation:
`revolution-{sphere,cone,frustum,cylinder,ring,torus,dome}`,
`iso4032-M4-detailed`, `iso4762-M4-detailed`, `iso7380-M4x16-detailed`,
`iso10642-M4x16-detailed`, `motion-608-stack-detailed`,
`filleted-shaft-d10-16`.

Feature inventory confirms the expected surfaces: the revolve torus reports
four `TOROIDAL_SURFACE` faces (major 5, minor 1); the ISO 10642 head reports a
`CONICAL_SURFACE` with a 45° semi-angle; the chamfered nut is all-planar ruled
quads; the bearing reports `SPHERICAL_SURFACE` balls; the filleted shaft
reports a `TOROIDAL_SURFACE` with major 6 / minor 2.

## 6. Golden references

- No external STEP file is committed (per-file license unverified, unchanged
  policy).
- The downloaded `iso10642_socket_countersunk_screw_m3x12` model was measured
  with OCCT: head 6.046 mm, 45° cone half-angle (90° included), length 12 mm.
  This corroborates the ISO 10642 M3 head diameter (6.0 mm) and the parametric
  90° countersink. Recorded in `manifest.json` and `GOLDEN_REFERENCES.md`.
- The two previously rejected models remain rejected (ISO 4762 M5 head 9.2 mm;
  ISO 7089 M4 thickness 1.8 mm).
- The B-slot6 2020 extrusion profile remains deferred pending provenance; the
  generic envelope is still explicitly not equivalent.

## 7. Files added

- `cad/revolved-profile.mbt`, `cad/compiler-revolved.mbt`,
  `cad/profile-chamfer.mbt`, `cad/chamfered-prism.mbt`
- `cad/revolved_profile_wbtest.mbt`, `cad/profile-chamfer_wbtest.mbt`,
  `cad/chamfered_prism_wbtest.mbt`
- `entities/geometry/sphere-surface.mbt`
- `components/standards/iso7380.mbt`, `components/standards/iso10642.mbt`
- `components/fasteners/special_heads.mbt`
- `components/examples/revolution/*`, `components/examples/filleted_shaft/*`
- `components/FEATURES.md`, `components/SESSION_REPORT.md`
- `scripts/measure_step_features.py`

## 8. Files changed (selection)

- `cad/types.mbt`, `cad/cad.mbt`, `cad/blender-python.mbt`
- `entities/geometry/extends.mbt`, `repository/repository.mbt`, `parse/parse.mbt`
- `components/fasteners/nuts.mbt`, `screws.mbt`, `fasteners_test.mbt`
- `components/motion/bearings.mbt`, `shafts.mbt`, `motion_test.mbt`
- `scripts/validate_step.py`
- `components/examples/generate_all.sh`, `examples/fasteners/main.mbt`,
  `examples/motion_stack/main.mbt`
- Docs: `PROGRESS.md`, `KNOWN_ISSUES.md`, `GEOMETRY.md`, `STANDARDS.md`,
  `DATA_SOURCES.md`, `README.md`, `VALIDATION.md`, `GOLDEN_REFERENCES.md`,
  `manifest.json`

## 9. Chamfer/fillet algorithms and controls

- **2D chamfer**: equal legs by default; optional `angle_deg` uses the
  law of sines to close the bevel triangle. Tangent points at distance
  `distance`; rejected when an edge cannot absorb both neighbours' cuts.
- **2D fillet**: tangent length `r / tan(θ/2)`, centre at `r / sin(θ/2)` along
  the corner bisector; arc sampled with `segments`. Chord error
  `r(1 − cos(π/(2·segments)))`.
- **Prism chamfer**: parallel inset by `c`; planar ruled quads; angle is the
  face/edge offset (45° by default in components).
- **Revolve**: bands are classified by geometry; cone semi-angle emitted in the
  file's declared degree unit; torus/sphere radii emitted in mm. Seam edges and
  analytic poles as described.

## 10. Honest limitations / deferred

- Threads remain swept helical ridges (not tolerance-class geometry).
- Socket bands and head chamfers on prisms are high-resolution polygon/planar
  facets, not continuously curved surfaces; deviation is the polygon chord
  error (well under 0.01 mm at 64 segments).
- ISO 7380's dome profile and flat-top radius are engineering approximations;
  only `dk`, `k`, `s`, `t` are the standard's nominal values.
- Bearing ball diameter and ring chamfers are envelope/engineering geometry,
  not catalogue internals.
- Gear root fillet/tip chamfer, exact internal involute ring, the B-slot6
  profile, and the catalog/query API remain deferred.
- The ISO 7380/10642 dimension tables are transcribed nominal summaries and
  require verification against the current standard before manufacturing.

## 11. Tools used

- OCCT `DRAWEXE` (via `scripts/validate_step.py`,
  `scripts/validate_frame_geometry.py`, `scripts/measure_step_occt.py`) for
  independent geometry, `checkshape`, tessellation, and volume.
- `gmsh` available; the OCCT path was used for the new artifacts.
- Python repo scripts for STEP parsing, feature inventory, and measurement.
- The MCP CAD servers (SolidCraft/Blender/CadCraft/PicoGK) were available but
  not invoked; the numeric OCCT oracles were sufficient and are the stated
  acceptance criterion. No visual claim is made.

## 12. Reproduction

```bash
./test-all.sh
./components/examples/generate_all.sh

python3 scripts/validate_step.py \
  components/examples/output/iso10642-M4x16-detailed.step
python3 scripts/measure_step_features.py \
  components/examples/output/revolution-torus.step \
  components/examples/output/iso4032-M4-detailed.step
python3 scripts/measure_step_occt.py \
  components/examples/output/revolution-sphere.step
```

## 13. Repository state

No push, release, or commit was performed. The working tree contains the new
and modified files listed above for the owner to review and commit.
