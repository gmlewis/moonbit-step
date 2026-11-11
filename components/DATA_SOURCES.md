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
| Plain washers, DIN A series | DIN 125 A | `d1`, `d2`, `h` (identical to ISO 7089 for the modeled sizes; M8 reference at h_max) |
| Spring washers, form B | DIN 127 B | `d1`, `d2`, `b`, `s`, `h` (h_min reference) |
| Large washers, square hole | DIN 440 V | `d2`, square side `a`, thickness `s` |
| Thick flat washers, heavy pattern | DIN 7349 | `d1`, `d2`, `s` |
| Hexagon socket set screws, flat point | DIN 913 | `s`, `t`, point flat `d_p`, length range |
| Hexagon head screws | ISO 4017:2022 | `s`, `k` |
| Hexagon head bolts | ISO 4014:2022 | `s`, `k`, thread length `b` |
| Button head hex socket screws | ISO 7380-1:2022 designation | `dk`, `k`, `s`, `t`, length range |
| Countersunk head hex socket screws | ISO 10642:2026 designation | `dk`, `k`, 90° angle, `s`, `t`, length range |
| Threaded rods | DIN 976-1:2016 | Metric coarse thread, rod lengths |
| Radial ball bearings | ISO 15:2017 boundary dimensions | `d`, `D`, `B` |
| Involute gear geometry | ISO 21771:2007 terminology / standard practice | radii, involute construction |

The ISO 7380-1 and ISO 10642 tables are transcribed from the published
standards. ISO 10642:2026 has no dimensional changes versus 2019. Its head
diameter dk ranges are 5.54-6.72 / 7.53-8.96 / 9.43-11.20 mm for M3 / M4 / M5
(the reference models use the references' sharp 6.0 / 8.0 / 10.0 mm, within
range); the head edge radius minima are 0.1 / 0.2 / 0.2 mm and t_max is 1.25 /
1.65 / 2.00 mm. The downloaded M3 and M5 head profiles match the standard
(M3 edge radius 0.1275, M5 0.21); the M4 reference edge radius 0.1725 is below
the 0.2 minimum and the M4/M5 socket depths 1.8 / 2.3 mm exceed t_max, so the
parametric parts use the ISO values. The references' socket widths
(2.10 / 2.60 / 3.10 mm) are above the ISO maxima (2.08 / 2.58 / 3.08 mm), so
the parametric parts use s_max.

## Where the numbers live

- `components/standards/metric.mbt` — metric sizes, pitches, derived ISO 68-1
  values.
- `components/standards/iso4762.mbt` — ISO 4762 head/socket table.
- `components/standards/iso4032.mbt` — ISO 4032 nut table.
- `components/standards/iso7089.mbt` — ISO 7089 washer table.
- `components/standards/din125.mbt` — DIN 125 A washer table (reuses ISO 7089
  for the modeled sizes).
- `components/standards/din127.mbt` — DIN 127 B spring-washer table.
- `components/standards/din440.mbt` — DIN 440 V square-hole large-washer table.
- `components/standards/din7349.mbt` — DIN 7349 thick flat-washer table.
- `components/standards/din913.mbt` — DIN 913 set-screw table.
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

## Data reuse

- No proprietary CAD files, catalog drawings, or protected tables are included.
- Dimension values are factual data.
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
- The golden STEP files are downloaded from the open-source step.parts
  corpus by the repository owner. There are no licensing concerns.
- `scripts/fetch_golden_references.py` downloads the golden files to the
  Git-ignored `components/testdata/golden/external/` directory for local
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

## Golden corpus expansion (2026-11-10)

The manifest now records 29 external references. New acceptances corroborated
against the standards tables:

- **ISO 4032 M3/M5:** the reference plan bounding box is the across-corners
  span 6.3509 / 9.2376 mm (= `s / cos 30` for `s` 5.5 / 8.0 mm). The M3 height
  2.4 mm matches ISO 4032:2023; the M5 reference is the older DIN 934 height
  4.0 mm, while ISO 4032:2023 requires 4.7 mm, so the M5 reference is recorded
  as non-compliant and the parametric part follows the ISO height.
- **ISO 7380 M4 x 10 / M5 x 12:** head diameters 7.6 / 9.5 mm and overall
  lengths 12.2 / 14.75 mm (= `L + k`) match `iso7380_size`.
- **ISO 10642 M3 / M4 / M5:** the M3 and M5 head cone/edge profiles match the
  ISO model exactly; M4 uses the ISO minimum edge radius because its reference
  (0.1725 mm) is below 0.2 mm. The references' socket depths M4/M5 (1.8 / 2.3
  mm) exceed t_max (1.65 / 2.00 mm), and their socket across flats
  (2.10 / 2.60 / 3.10 mm) exceed the ISO maxima (2.08 / 2.58 / 3.08 mm); the
  parametric parts use the ISO limits.
- **ISO 4017 M5 x 20:** the plan bbox is the across-corners span for `s` 8.0
  mm; the reference overall length 23.74 mm disagrees with the nominal
  `L + k = 23.5` mm by 0.24 mm, so it is accepted for head width only.
- **Bearings 6000 / 6001 / 6200:** bore 10 / 12 / 10 mm, outer diameter 26 / 28
  / 30 mm, width 8 / 8 / 9 mm match the ISO 15 boundary dimensions.
- **Spur gear m2 z40 bore10:** tip diameter 84 mm, face width 16 mm, bore
  10 mm, pitch diameter 80 mm, root diameter 75 mm match.
- **DIN 125 A M3/M8:** the M3 reference (3.2 / 7 / 0.5 mm) matches DIN 125 A
  exactly. The M8 reference is 8.4 / 16 / 1.8 mm; 1.8 mm is the ISO 7089 /
  DIN 125 A h_max (nominal 1.6, limits 1.4..1.8 mm), so it is standard-correct
  and the DIN 125 A M8 reference thickness is taken at h_max.
- **DIN 913 M3 x 5:** the reference body/topology matches DIN 913 (3 mm
  shank, hex socket, flat point). Its point flat is 2.2 mm and its socket
  across flats is 1.5588 mm, both above the DIN 913 limits (d_p max 2.0,
  s max 1.545), so the parametric part uses the standard limits (point flat
  2.0, socket 1.545) and records the difference. Both are one closed solid
  with 11 faces (1 cylinder, 1 cone, 9 planes), 23 edges, and 15 vertices.
- **DIN 7349 M3/M4/M5/M6/M8:** the thick heavy-pattern washers match the
  DIN 7349 table (M3 3.2 / 9 / 1.0, M4 4.3 / 12 / 1.6, M5 5.3 / 15 / 2.0,
  M6 6.4 / 17 / 3.0, M8 8.4 / 21 / 4.0). The M3 reference and parametric part
  are the same analytic annular solid (two cylinders, two planes); volume and
  area match to rounding.
- **DIN 440 V M5/M6/M8:** the square-hole large washers match the DIN 440 V
  table (M5 18 / 5.5 / 2.0, M6 22 / 6.6 / 2.0, M8 28 / 9.0 / 3.0). Both the
  reference and the parametric part have one analytic outer cylinder, four
  planar square-hole walls, and two planar end faces (7 faces, 15 edges, 10
  vertices); the M5 volume and area match to rounding.
- **DIN 127 B M4/M5/M6/M8:** the reference d1/d2/s values match the DIN 127 B
  table (M4 4.1 / 7.6 / 0.9, M5 5.1 / 9.2 / 1.2, M6 6.1 / 11.8 / 1.6,
  M8 8.1 / 14.8 / 2.0). The free height is taken at h_min (M4 1.8 mm). The
  downloadable M6 reference uses d1 = 6.1 mm; the fasteners.eu table prints
  6.4 as its minimum, while other tables list 6.1. The parametric part uses
  the same native topology as the reference: four cubic B-spline side
  surfaces (24 spans per turn) and two planar caps. The split is a
  parallel-plane slot at the +X side; for M4/M5/M6/M8 the eight split-cap
  vertices are transcribed from the reference and the smooth corner curves
  are blended to meet them exactly. The sweep runs clockwise from high Z to
  low Z. The DIN side length b is recorded in the table, but the radial
  section is `(d2 - d1) / 2` in the modeled references.

Rejected with evidence (not used as oracles):

- **ISO 7089 M3/M4/M5:** reference thicknesses 1.1 / 1.8 / 2.2 mm against
  ISO 7089 normal-series 0.5 / 0.8 / 1.0 mm.
- **"Metric threaded rod M3 x 200":** the model is a 3 x 400 mm cylinder
  (volume 2827.43 mm³), contradicting its 200 mm label.

The harness verifies each file's SHA-256 and byte size. The golden files are
downloaded by the repository owner into the Git-ignored `external/` directory.

## Round 7 matrix data

The M2–M5 matrix uses the same standards tables as the builders, independently
re-encoded in `scripts/golden_matrix.py`:

- ISO 4762: `d, dk, k, s, t`;
- ISO 4032: `s, m`;
- ISO 7089: `d1, d2, h`;
- ISO 4014/4017: `s, k`;
- ISO 7380-1: `dk, k, s, t`;
- ISO 10642: `dk, k, s, t`;
- DIN 976-1: `d` and the requested length.

The engineering-default chamfer formulas are re-encoded independently in the
harness (`tip_chamfer`, `lead_in`, `head_chamfer`, `hex_head_chamfer`,
`nut_chamfer`) so a matrix failure reflects the emitted geometry, not a call
into the generator. The verdict policy and the rejected candidate models are in
`GOLDEN_REFERENCES.md`. Run `scripts/golden_matrix.py` for the current
per-cell results; the generated report is not tracked.
