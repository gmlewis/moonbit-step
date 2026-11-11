# Session Report 07 — M2–M5 Golden Matrix, Real Chamfers, and the Thread-Placement Defect

Date: 2026-11-10. This report covers round 7. It records the verified
baseline, the defects found and fixed, the new golden-matrix deliverable, the
independent measurements, and the honest remaining gaps.

## 1. Starting state and baseline

- Branch `master`, HEAD `7f1181a` (`Complete round 6`).
- Toolchain: `moon 0.1.20261104 (940aa18 2026-11-04)`,
  `moonc v0.10.20+65efd5b93`.
- Round-6 work was present and committed; it was preserved.
- Baseline `./test-all.sh`: **535 tests, 535 passed, 0 failed** (verified, not
  assumed).
- Baseline `python3 scripts/compare_golden.py`: **19 fixtures PASS**, external
  geometry `SKIP` (unverified per-file licences), 0 `FAIL`.
- Optional tools present: OCCT `DRAWEXE`, `gmsh`, `rsvg-convert`, macOS `sips`,
  Python 3, and the independent SolidCraft kernel.

No Git state was changed: no commit, push, tag, release, reset, clean, or
branch deletion.

## 2. Defect found first: partially threaded screws were threaded at the wrong end

**P1 (engineering-invalid geometry).** A fully modeled ISO 4762 M4 x 20 screw
exported a plain shank at the free (tip) end (`z = 0..6`) and the threaded core
plus helical ridge under the head (`z = 6..20`). ISO 4762 measures the thread
length `b` from the **tip**: `b = 2d + 6 = 14 mm` for M4 x 20, so the thread must
occupy `z = 0..14` and the plain shank `z = 14..20`. The same reversal existed in
ISO 4014 partially threaded bolts. In the bolted-joint and hardware-kit
assemblies the nut sits at the free end, so it was bearing on an unthreaded
shank.

Root cause: the plain shank was added at `z = 0` and the thread core was placed
at `z = plain_length`, i.e. the two sections were swapped relative to the
standard.

Fix: the thread (core + swept ridge) is now at `z = 0..thread_length`; any plain
shank is placed at `z = thread_length` under the head. Regressions:

- `ISO 4762 thread length is measured from the tip` (M4 x 20: core at 0, plain
  shank at 14).
- `ISO 4014 thread length is measured from the tip` (M8 x 80: core at 0, plain
  shank at 22).
- `ISO 4762 fully modeled core carries a tip chamfer`.

Measured after the fix with OCCT per-solid bounding boxes: the M4 x 20 part is
plain shank `z = 14..20` (r = 2.0), thread core + ridge `z = 0..14`.

## 3. Real chamfers added across the M2–M5 families

All chamfers below are real geometry measured from the STEP vertex rings, not
relabelled sharp edges. Engineering defaults are stated as such; no standard
dimension is invented.

| Family | Feature | Level | Representation |
|---|---|---|---|
| ISO 4762 | head top-edge chamfer | Detailed+ | ruled `ChamferedPrism` ring stack (existing) |
| ISO 4762 | socket lead-in chamfer | Detailed+ | **new** tapered hex hole (ruled, flared top) |
| ISO 4762 | shank tip chamfer | Detailed+ | **new** 45° ruled cone ring stack |
| ISO 4032 | both face chamfers | Detailed+ (now also FullyModeled) | ruled hex ring stack |
| ISO 7089 | no edge chamfer | all | standard-correct sharp edge, documented |
| ISO 4017/4014 | hex-head top chamfer | Detailed+ | **new** ruled parallel-inset hexagon stack |
| ISO 4017/4014 | shank tip chamfer | Detailed+ | **new** 45° ruled cone |
| ISO 7380-1 | socket lead-in chamfer | Detailed+ | **new** tapered hex hole |
| ISO 7380-1 | shank tip chamfer | Detailed+ | **new** 45° ruled cone |
| ISO 10642 | socket lead-in chamfer | Detailed+ | **new** tapered hex hole |
| ISO 10642 | shank tip chamfer | Detailed+ | **new** 45° ruled cone |
| DIN 976-1 | end lead-in chamfers | Detailed+ | **new** 45° ruled cones at both ends |

Kernel extension: `ChamferedPrism` gained an optional `hole_levels` ring stack
(`(z, inward_inset)`). Consecutive hole rings are joined by planar ruled quads,
so a socket lead-in is a real ruled conical-hole approximation rather than a
step or a relabelled bore. `cad/chamfered_prism_wbtest.mbt` verifies the face
count, planarity, and cap-closure rejection.

The fully modeled ISO 4032 body is now also face-chamfered (previously the
helical body was left sharp and the chamfer was recorded as omitted).

### Measured chamfer evidence (ISO 4762 M4 x 20, Detailed)

`scripts/measure_step_features.py` vertex rings:

```text
tip:        z=0.0    r=1.5995 (shank 2.0 - 0.4 tip chamfer)
            z=0.4    r=2.0000
head top:   z=24.0   r=2.7992 (3.5 - 0.7 head chamfer)
socket:     z=22.0   r=1.7321 (nominal hex circumradius, s=3.0)
            z=24.0   r=2.0785 (lead-in hex flared by 0.3 mm)
```

The socket lead-in and tip chamfer are therefore independently measurable in the
emitted B-Rep, not inferred from the builder.

## 4. The centerpiece: 108-cell M2–M5 golden matrix

`scripts/golden_matrix.py` builds and validates every family / size / detail
cell for the M2, M2.5, M3, M4, and M5 families:

- ISO 4762 socket head cap screw;
- ISO 4017 fully threaded hex screw;
- ISO 4014 partially threaded hex bolt;
- ISO 4032 hex nut;
- ISO 7089 plain washer;
- ISO 7380-1 button head screw (M3–M5);
- ISO 10642 countersunk screw (M3–M5);
- DIN 976-1 threaded rod.

Each cell records two statuses:

- **NORMATIVE** — independent standard dimensions, solid count, and measured
  chamfer/lead-in/thread rings (PASS/FAIL).
- **GOLDEN** — independent model comparison (PASS/FAIL/SKIP). The external
  corpus has no verified per-file licence, so every status is `SKIP`; the
  development-time measurement is recorded but is never the acceptance oracle.

Result: **108 cells, NORMATIVE PASS 108, FAIL 0; GOLDEN SKIP 108.** No cell is
described as "fully golden-validated".

The development-time golden cross-check is rotation-invariant: it compares the
axial extent and the outer radius (the larger of the maximum vertex radius and
half the larger in-plane bbox extent), not a raw axis-aligned bbox, which a
15°-rotated hexagon defeats. It agrees for 39 cells (13 family/size pairs × 3 levels) and rejects
69 cells with recorded evidence:

| Family | Development-time result |
|---|---|
| ISO 4762 | M3/M4 head diameter and overall length agree; M2 (4.1131 mm), M2.5 (4.8708 mm), and M5 (9.2003 mm) exceed the ISO maximum head diameter and are rejected. |
| ISO 4032 | M2–M5 across-corners circumradius and height agree (M4 height 3.2027 vs 3.2). |
| ISO 7380-1 | M3–M5 agree exactly. |
| ISO 10642 | M3 agrees; M4/M5 are below the standard maximum head diameter, which is permitted. |
| ISO 4017/4014 | Head radius agrees; overall length exceeds `L + k` by 0.2–0.24 mm (vendor head height larger than the ISO nominal), so the candidate is rejected as an oracle. |
| ISO 7089 | Outer diameter agrees; thickness is 0.7/1.1/1.1/1.8/2.2 mm against ISO 7089 h = 0.3/0.5/0.5/0.8/1.0 mm; rejected. |
| DIN 976 | Diameter agrees; the "l025" models are 50 mm long, i.e. 2× the label; rejected. |

Full provenance, per-cell values, and the machine-readable summary are in
`components/testdata/golden/matrix.json` and `MATRIX.md`.

## 5. Golden harness and independent measurement tooling

- `scripts/measure_step_features.py`: new **vertex-ring** report
  (`(z, radius, count)` from real `VERTEX_POINT`s), used to measure chamfer legs,
  lead-ins, and ring-stack faces.
- `scripts/measure_step_occt.py`: now reports the **centre of mass** as well as
  volume, solids, and bbox.
- `scripts/measure_step_mesh.py` (new): tessellates a STEP with OCCT and
  provides a sampled **bidirectional surface deviation** (Hausdorff-like) and
  **cross-section area/perimeter/extent** at declared planes.
- `scripts/compare_golden.py`: new checks for `mass_properties`, `sections`,
  `surface_deviation`, `vertex_ring`, and `sphere_radius_present_mm`. The
  `--self-test` now proves 15 cases: matching fixture PASS, wrong dimension
  FAIL, missing/unlicensed external SKIP with normative PASS, checksum FAIL,
  units/frame normalization, unknown-unit rejection, feature PASS/FAIL,
  volume/centre-of-mass, section area, identical-shape zero deviation,
  different-size positive deviation, and vertex-ring PASS/FAIL.
- Manifest additions: ISO 7089 M3/M4/M5 now carry analytic mass properties,
  a mid-thickness section area, and an outer-rim vertex ring; the 608/6000/6001/
  6200 bearings carry a measured `sphere_radius_present_mm` (ball diameter =
  modeled radial gap, independently re-derived from the boundary dimensions).

Current `compare_golden.py` result: **19 fixtures PASS, external geometry SKIP,
0 FAIL**; self-test **15/15 PASS**.

## 6. End-to-end assembly and schedule

`Assembly::schedule()` and `schedule_text()` were added. They group identical
parametric components into a BOM (part name, designation, standard, quantity,
instance names). The bolted joint (two plates, ISO 4762 screw, ISO 7089 washer,
ISO 4032 nut) reports four distinct parts and five instances; the test asserts
the plate quantity is 2 and the schedule text names the screw standard.

The existing shaft/bearing/spacer stack (`components/examples/motion_stack`)
covers the shaft/bearing stack; couplings and linear rails are not implemented
(no verified data).

## 7. Full test and validation results

```bash
./test-all.sh
# 546 tests, 546 passed, 0 failed

python3 scripts/compare_golden.py
# 19 fixtures PASS, external geometry SKIP, 0 FAIL, exit 0

python3 scripts/compare_golden.py --self-test
# 15/15 checks PASS

python3 scripts/golden_matrix.py --write components/testdata/golden
# 108 cells, NORMATIVE 108 PASS / 0 FAIL, GOLDEN 0 PASS / 108 SKIP
```

During the final run a pre-existing flaky test surfaced: `assembly does not
change flat export` compared two full STEP strings including the wall-clock
`FILE_NAME` timestamp, so it failed when the exports straddled a second
boundary. It now compares the `DATA;` geometry section (the same approach the
thread-handedness test uses) without weakening the assertion. See KI-30.

All **57** committed STEP fixtures under `components/examples/output/` pass
`scripts/validate_step.py --no-mesh` (syntax, references, closed shells,
topology, orientation, PLANE planarity, OCCT `checkshape`). Representative
regenerated files:

```text
iso4762-M4x20-detailed.step   3 solids, 275 faces  PASS
iso4017-M4x20-detailed.step   2 solids, 144 faces  PASS
iso10642-M4x16-detailed.step  3 solids, 212 faces  PASS
iso4032-M4-fully-modeled.step 2 solids, 620 faces  PASS
```

## 8. Remaining issues and explicit non-implementations

- **Under-head radius**: no verified standard/drawing value for these families;
  recorded as a typed omission rather than a guessed fillet.
- **ISO 4032 bore-edge chamfer**: no verified dimension; typed omission.
- **Thread runout / root relief**: not modelled as a standards-defined form. The
  DIN 976 ends carry a clearly labelled engineering lead-in chamfer; the swept
  ridge ends remain square.
- **T-nuts, corner brackets, joining plates, end caps**: NOT IMPLEMENTED; no
  verified dimensions/licences. The frame remains butt-jointed.
- **Couplings, linear rails, retaining rings/inserts**: NOT IMPLEMENTED; no
  verified data.
- **Gear profile shift / helical gears**: NOT IMPLEMENTED. The planetary contact
  check is a 2D outline rotation cycle, not a 3D solver.
- **Exact B-slot6 extrusion**: NOT IMPLEMENTED pending verified
  provenance/licence; the generic envelope is explicitly not equivalent.
- **Multi-edge evaluated chamfer**: the optional OCCT DRAW path applies one
  selected edge per node; multi-edge fillets are supported.
- **External golden geometry**: `SKIP` for every cell because per-file licences
  are unverified. The development-time measurements and rejections are recorded.

## 9. Reproduction

```bash
./test-all.sh
python3 scripts/compare_golden.py
python3 scripts/compare_golden.py --self-test
python3 scripts/golden_matrix.py --write components/testdata/golden
python3 scripts/golden_matrix.py --self-test

moon run --target native components/examples/fasteners -- \
  --standard iso4762 --size M4 --length 20 --detail detailed \
  -o /tmp/iso4762-M4x20-detailed.step
python3 scripts/validate_step.py --no-mesh /tmp/iso4762-M4x20-detailed.step
python3 scripts/measure_step_features.py /tmp/iso4762-M4x20-detailed.step
```

## 10. Git statement

No commit, push, tag, release, branch deletion, hard reset, or remote Git
mutation was performed by this session. The owner runs all state-changing Git
commands.

## 11. Independent second-kernel evidence (SolidCraft)

The detailed screw and fully modeled nut were imported into SolidCraft (SMLib),
independent of OCCT:

| Model | OCCT volume (mm³) | SolidCraft volume (mm³) | Bodies | Closed |
|---|---:|---:|---:|---|
| ISO 4762 M4 x 20 Detailed | 382.687 | 382.687 | 3 | all |
| ISO 4032 M4 FullyModeled | 92.7776 | 92.7777 | 2 | all |

Bounding boxes agree exactly (screw `±3.5 x ±3.5 x 0..24`; nut
`±3.5 x ±4.0415 x 0..3.2`), and both imports report 0 errors. The renders show
the socket lead-in flare, head top bevel, tip break, and nut face chamfers. The
numeric agreement is the evidence; the renders are supplementary.
