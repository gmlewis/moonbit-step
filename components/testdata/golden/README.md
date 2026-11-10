# Golden fixture data

`manifest.json` is the machine-readable record of every reference examined by
the audit:

- `external_references` — step.parts candidates. Their per-file license and
  provenance are **unverified**, so the STEP files themselves are not
  committed. Download them with `scripts/fetch_golden_references.py`.
- `analytic_references` — locally authored frame expectations checked by
  `scripts/validate_frame_geometry.py`. These are clearly labelled analytic,
  not external models.

`external/` is a local download target and is ignored by Git. Do not commit a
file there until its license, source, author, and attribution are recorded in
`manifest.json` and `components/GOLDEN_REFERENCES.md`.

See `components/GOLDEN_REFERENCES.md` for the licensing analysis, comparison
rules, tolerances, verdicts, and reproduction commands.
