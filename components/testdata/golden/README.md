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

