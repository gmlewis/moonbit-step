# Golden fixture data

`manifest.json` is the machine-readable record of the individually verified v1
fixtures:

- `external_references` — step.parts candidates. Their per-file license and
  provenance are **unverified**, so the STEP files themselves are not
  committed.
- `analytic_references` — locally authored frame expectations checked by
  `scripts/validate_frame_geometry.py`. These are clearly labelled analytic,
  not external models.

## Comprehensive standardized corpus

`scripts/fetch_golden_references.py` selects a much larger corpus by standard,
family, size, and representative length. It defaults to M2-M5 and can be
extended:

```bash
# M2, M2.5, M3, M4, M5: ~167 files (screws, nuts, washers, pins, bearings, rods)
python3 scripts/fetch_golden_references.py \
  --out components/testdata/golden/external \
  --accept-unverified-license

# M2 through M8: ~237 files
python3 scripts/fetch_golden_references.py \
  --out components/testdata/golden/external \
  --accept-unverified-license --scope extended

# Every catalog size/length for the selected standards: ~1048 files
python3 scripts/fetch_golden_references.py \
  --out components/testdata/golden/external \
  --accept-unverified-license --scope all --allow-large
```

Inspect before downloading:

```bash
python3 scripts/fetch_golden_references.py --list-selections
python3 scripts/fetch_golden_references.py --scope core --list
```

The script verifies the catalog standard designation, size/length availability,
SHA-256, and byte size. It writes `fetch-report.json` with per-file provenance,
missing combinations, cache/download status, and failures. Existing files with
a matching checksum are reused; failed downloads are retried and written
through temporary `.part` files.

`external/` is a local download target and is ignored by Git. Do not commit a
file there until its license, source, author, and attribution are recorded in
`manifest.json` and `components/GOLDEN_REFERENCES.md`.

See `components/GOLDEN_REFERENCES.md` for the licensing analysis, comparison
rules, tolerances, verdicts, and reproduction commands.

## Comparison harness

`scripts/compare_golden.py` reads this directory's `manifest.json`. Fixtures
with a `generation` recipe are generated through the example CLIs, measured
with OCCT and the STEP feature inventory, and checked against the manifest's
`comparison` block (bbox extents, solid count, surface presence, cone angles,
vertex radii, and a lower-detail face-count contrast). The harness prints
`PASS`/`FAIL`/`SKIP` per check and never reports a skipped check as a pass.

```bash
python3 scripts/compare_golden.py
python3 scripts/compare_golden.py --fixture bearings/608zz
python3 scripts/compare_golden.py --json
```

The external geometry comparison is gated on a verified per-file licence. All
current fixtures are `unverified-per-file`, so that check is `SKIP`; the
normative and analytic checks still run and pass. The parametric parts and
their measurements are reproducible without the external corpus.



## M2–M5 matrix (round 7)

`scripts/golden_matrix.py` builds the 108-cell M2–M5 matrix and writes:

- `matrix.json` — per-cell `NORMATIVE` and `GOLDEN` statuses, the measured
  values, and the development-time comparison evidence.
- `MATRIX.md` — the per-family and per-cell tables.

Every `GOLDEN` status is `SKIP` because the per-file licences are unverified.
The normative checks are the acceptance criterion; the development-time
measurements are recorded, never used as an oracle.

```bash
python3 scripts/golden_matrix.py --write components/testdata/golden
python3 scripts/golden_matrix.py --self-test
```

Additional measurement helpers:

- `scripts/measure_step_features.py` — surface counts, cone/sphere/torus
  parameters, and the vertex-ring `(z, radius, count)` report.
- `scripts/measure_step_occt.py` — solids, bbox, volume, and centre of mass.
- `scripts/measure_step_mesh.py` — sampled bidirectional surface deviation and
  cross-section area/perimeter/extents.
