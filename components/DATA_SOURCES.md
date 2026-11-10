# Data Sources and Provenance

Access date for all sources below: **2026-11-09**.

The component library records nominal dimensional data for standardized
families. The tables were transcribed from commonly published standard
dimension summaries and manufacturer engineering tables. They are intentionally
small, reviewable, and in source control; they are not copied CAD models,
proprietary catalog graphics, or manufacturer part files.

> **Verification requirement:** ISO and DIN standards are the normative source.
> Before manufacturing, verify every dimension against the current official
> standard edition or the selected manufacturer's drawing. Nominal values in
> this repository are not a substitute for a controlled drawing.

## Standards metadata used

| Family | Standard/revision used | Data used |
|---|---|---|
| Metric thread profile | ISO 68-1:1998 | Basic profile diameters and depths |
| Metric thread pitches | ISO 261:1998 | Coarse and one fine pitch per size |
| Socket head cap screws | ISO 4762:2004 | `dk`, `k`, `s`, `t`, length ranges |
| Hexagon regular nuts | ISO 4032:2023 | `s`, `m` |
| Plain washers, normal series | ISO 7089:2000 | `d1`, `d2`, `h` |
| Hexagon head screws | ISO 4017:2014 | `s`, `k` |
| Hexagon head bolts | ISO 4014:2011 | `s`, `k`, thread length `b` |
| Threaded rods | DIN 976-1:2016 | Metric coarse thread, rod lengths |
| Radial ball bearings | ISO 15:2017 boundary dimensions | `d`, `D`, `B` |
| Involute gear geometry | ISO 21771:2007 terminology / standard practice | radii, involute construction |

## Where the numbers live

- `components/standards/metric.mbt` — metric sizes, pitches, derived ISO 68-1
  values.
- `components/standards/iso4762.mbt` — ISO 4762 head/socket table.
- `components/standards/iso4032.mbt` — ISO 4032 nut table.
- `components/standards/iso7089.mbt` — ISO 7089 washer table.
- `components/standards/hex_heads.mbt` — ISO 4014/4017 head table and DIN 976
  rod validation.
- `components/motion/bearings.mbt` — bearing boundary table.
- `components/profiles/tslot.mbt` — generic T-slot presets (engineering
  assumptions, not a standard).

## Source categories

1. **Normative standard metadata**: ISO/DIN designations and edition years. The
   standard documents are the normative source for dimensions.
2. **Commonly published dimension summaries**: public engineering tables used
   to cross-check the nominal values transcribed here.
3. **Engineering assumptions**: generic T-slot presets, bearing ring and roller
   proportions, gear tooth resolution defaults, color choices, and detail
   policies. These are clearly labeled as assumptions, not standard data.
   The generic T-slot cavity is tapered at the back when a rectangular cavity
   would intersect the adjacent face's cavity; this is an envelope choice that
   leaves the four corner webs, not a claim about any manufacturer's cavity
   profile.

Organization references (metadata only; no document content is reproduced):

- ISO: <https://www.iso.org/standards.html>
- DIN: <https://www.din.de/en>
- Manufacturer bearing boundary-dimension tables were used only as
  cross-checks for the common 60xx/62xx/63xx series.

## Copyright and licensing

- No proprietary CAD files, catalog drawings, or protected tables are included.
- Dimension values are factual data; the repository's Apache-2.0 license covers
  the source code and documentation. Users remain responsible for the terms of
  any external standards documents they consult.
- Generated STEP files are the output of this library and contain only the
  generated geometry and the provenance text embedded by the component
  metadata.

## Change policy

When a dimension is corrected:

1. Update the table and the `source` string for that family.
2. Add or update a unit test asserting the corrected value.
3. Note the change in `PROGRESS.md` and, if it changes supported
   configurations, in `KNOWN_ISSUES.md`.

## External golden references

External STEP models examined during the correctness audit are recorded in
`components/testdata/golden/manifest.json` and
`components/GOLDEN_REFERENCES.md`.

- Catalog: [step.parts](https://www.step.parts/), commit
  `c6113328a5695b976a010a203a90fe86191769bf`.
- The catalog's `THIRD_PARTY_NOTICES.md` lists the source licenses (KiCad,
  FreeCAD-library, Adafruit, SparkFun) but the public API does not identify the
  per-file source. Per-file redistribution rights are therefore **unverified**.
- No external STEP file is committed. `scripts/fetch_golden_references.py`
  downloads candidates to a temporary or Git-ignored directory for local
  comparison and verifies the catalog standard designation, SHA-256, and byte
  size.
- The fetch script selects a comprehensive standardized corpus by standard,
  family, size, and representative length. The default `core` scope covers
  M2-M5 (including ISO 4032/4035 nuts; ISO 4762/4017/7380/10642 and DIN 913
  screws; ISO 7089/7091/7092/7093 and DIN 125/127/7349/93/440 washers; ISO
  2338/8752/1234 pins; common bearings; and labeled DIN 976-compatible rods).
  `--scope extended` adds M6/M8 and `--scope all` selects every catalog
  size/length for the chosen standards.
- Two candidates were rejected because they contradict the standard they
  claim: the step.parts ISO 4762 M5 x 10 head diameter is 9.2 mm (ISO maximum
  8.5 mm), and the step.parts ISO 7089 M4 washer is 1.8 mm thick (ISO 7089
  normal series is 0.8 mm).
- The locally authored frame fixtures are analytic references, not external
  models, and are labelled as such in the manifest.
