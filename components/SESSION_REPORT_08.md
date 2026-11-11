# Session Report 08 — Golden Models Are Downloaded, Not Generated

Date: 2026-11-11
Repository: `/Users/glenn/src/github.com/gmlewis/moonbit-17-step`
Branch at start: `master`, HEAD `98a9709` (`Complete session 7`).

## 1. Baseline

- Toolchain: `moon 0.1.20261104 (940aa18 2026-11-04)`,
  `moonc v0.10.20+65efd5b93`.
- Round-7 work was present and is preserved.
- Baseline `./test-all.sh`: **546 tests, 546 passed, 0 failed**.
- Baseline `compare_golden.py`: 19 generated fixtures `PASS`, external geometry
  `SKIP`, 0 `FAIL`; `--self-test` 15/15.
- Baseline matrix: 108 cells, NORMATIVE 108 `PASS`, GOLDEN 108 `SKIP`.
- Downloaded golden corpus: 170 STEP files plus `fetch-report.json` in
  `components/testdata/golden/external/`.

## 2. Correction to the golden-model approach

Golden files are **not generated in this repository**. They are downloaded by
the repository owner from the open-source
[step.parts](https://github.com/earthtojake/step.parts) corpus. There are no
licensing concerns: they are independent reference models.

The generated analytic-golden experiment from the start of this session was
wrong and has been removed completely:

- deleted `components/testdata/golden/analytic/` (108 generated files);
- deleted `scripts/analytic_golden.py`;
- removed every analytic-golden comparison and self-test from
  `scripts/golden_matrix.py`;
- removed all restriction gates, attribution requirements, and redistribution
  warnings from the harness, manifest, fetch script, and documentation;
- corrected every document (including `perfect-prompt*.md`) to state that the
  golden files are downloaded by the user from the open-source step.parts
  repository with no licensing concerns.

`components/testdata/golden/external/` remains Git-ignored because it is a
download cache, not because of any restriction on the files.

## 3. Matrix against the downloaded golden models

`scripts/golden_matrix.py` now compares each parametric part with the
downloaded golden file using a rotation-invariant maximum outer radius and
axial extent. A missing family/size is `SKIP`, never `PASS`.

Current result:

| Status | Cells |
|---|---:|
| NORMATIVE PASS | 108 |
| NORMATIVE FAIL | 0 |
| GOLDEN PASS | 39 |
| GOLDEN FAIL | 54 |
| GOLDEN SKIP | 15 |
| Fully validated (both PASS) | 39 |

Per family:

| Family | GOLDEN result |
|---|---|
| ISO 4032 hex nut | 15 PASS |
| ISO 7380-1 button head | 9 PASS |
| ISO 10642 countersunk | 9 PASS |
| ISO 4762 socket head | 6 PASS (M3/M4), 9 FAIL (M2/M2.5/M5) |
| ISO 4017 hex screw | 15 FAIL |
| ISO 4014 hex bolt | 15 SKIP (no ISO 4014 file downloaded) |
| ISO 7089 washer | 15 FAIL |
| DIN 976 rod | 15 FAIL |

The failures are measured contradictions in the downloaded files, not
parametric failures. NORMATIVE is `PASS` for every one of those cells.

| Family | Measured contradiction |
|---|---|
| ISO 4762 M2 / M2.5 / M5 | head diameter 4.1131 / 4.8708 / 9.2003 mm vs ISO maxima 3.8 / 4.5 / 8.5 mm |
| ISO 4017/4014 | overall length `L + k + 0.2–0.24 mm` (downloaded head height is larger than the ISO nominal) |
| ISO 7089 | thickness 0.7 / 1.1 / 1.1 / 1.8 / 2.2 mm vs ISO 7089 h = 0.3 / 0.5 / 0.5 / 0.8 / 1.0 mm |
| DIN 976 | the "l025" model measures 50 mm, twice its label |
| ISO 10642 M4/M5 | head below the standard maximum, which is permitted → PASS |

The 15 `SKIP` cells are ISO 4014: the downloaded corpus contains ISO 4017
(fully threaded) models but no ISO 4014 (partially threaded) model, so no
valid golden exists for that family.

## 4. Harness changes

- `scripts/golden_matrix.py`:
  - uses the downloaded golden files as the GOLDEN oracle;
  - records per-feature `golden-outer-radius` and `golden-axial-extent` checks;
  - reports `FAIL` with measured evidence when a downloaded model contradicts
    the standard;
  - reports `SKIP` only when no model has been downloaded;
  - self-tests prove a matching golden `PASS`es, a wrong-sized golden `FAIL`s,
    and a missing golden `SKIP`s without becoming a pass.
- `scripts/compare_golden.py`: removed the external-geometry gate; it is
  measured whenever the downloaded file is present. All 19 fixtures now report
  `PASS` with `external_geometry: recorded reference matches`.
- `scripts/fetch_golden_references.py`: removed the acknowledgement flag and
  the old report fields; it records the open-source source and
  verifies SHA-256/byte size.
- `manifest.json`: removed the old per-file status fields; added a `golden_source`
  record pointing at the open-source step.parts corpus.
- `scripts/measure_step_mesh.py`: section segments are now oriented by the
  triangle normal (`t = z_hat x n_xy`), fixing signed-area cancellation on
  threaded/multi-body sections. This is a real measurement fix, independent of
  the golden source.

## 5. MoonBit tests added

Two regressions in `components/fasteners/fasteners_test.mbt`:

- `M2-M5 detailed and full detail records the required features` checks the
  feature records for every supported size and family.
- `M2-M5 tip chamfer is real geometry at Detailed and absent at Simplified`
  asserts a `ChamferedPrism` at Detailed and a plain `Cylinder` at Simplified
  for every M2–M5 socket-head screw.

## 6. Commands and results

```bash
./test-all.sh
# 548 tests, 548 passed, 0 failed

python3 scripts/compare_golden.py
# 19 fixtures PASS, external geometry compared, 0 FAIL

python3 scripts/compare_golden.py --self-test
# 15/15 checks PASS

python3 scripts/golden_matrix.py --write components/testdata/golden
# 108 cells, NORMATIVE 108 PASS / 0 FAIL,
# GOLDEN 39 PASS / 54 FAIL / 15 SKIP, fully validated 39

python3 scripts/golden_matrix.py --self-test
# PASS

python3 scripts/validate_step.py --no-mesh \
  components/testdata/golden/external/iso4762_socket_head_cap_screw_m4x20.step
# PASS including occt checkshape

python3 scripts/validate_step_test.py
# OK
```

## 7. External tools and MCP

- OCCT `DRAWEXE` was used for measurement, tessellation, and `checkshape`.
- SolidCraft independently measured the ISO 4762 M4×20 detailed pair and
  agreed with OCCT: parametric 382.687 mm³, 3 closed bodies; all bodies with
  identical bounding boxes.
- gmsh, sips, and the MCP CAD servers are available; the numeric and geometric
  checks remain the acceptance criterion.

## 8. Remaining issues

- **Downloaded-model contradictions (low, reference quality):** the 54 GOLDEN
  failures listed in §3. They are recorded with measured values in
  `matrix.json`/`MATRIX.md`; no parametric dimension was changed to match a
  nonconforming reference.
- **ISO 4014 (low, coverage):** no downloaded partially-threaded model, so its
  15 cells are `SKIP`.
- **Typed omissions unchanged:** under-head radius, ISO 4032 bore-edge chamfer,
  and standards-defined thread runout have no verified value.
- **Deferred families unchanged:** T-nuts, corner brackets, joining plates, end
  caps, couplings, linear rails, retaining rings, profile shift, helical gears,
  exact B-slot6, and multi-edge evaluated chamfers.

## 9. Git

No commit, push, tag, release, or remote Git mutation occurred. The owner runs
all state-changing Git commands.
