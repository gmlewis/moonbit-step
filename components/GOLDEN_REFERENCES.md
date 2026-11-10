# Golden STEP References

Golden references are independent test oracles, never production geometry.
The parametric MoonBit generator remains authoritative.

## Licensing decision

No external STEP model is committed to this repository.

The investigated catalog is [step.parts](https://www.step.parts/)
([source](https://github.com/earthtojake/step.parts)). Its
`THIRD_PARTY_NOTICES.md` says third-party-derived STEP files retain their
source license:

| Source | License |
|---|---|
| KiCad `kicad-packages3D` | CC-BY-SA-4.0 WITH KiCad-libraries-exception |
| FreeCAD-library | CC-BY-3.0 |
| Adafruit CAD Parts | MIT |
| SparkFun KiCad Libraries | CC-BY-4.0 |
| SparkFun 3D Models | CC-BY-SA-4.0 |
| Original step.parts material | MIT (does not relicense derived STEP files) |

The step.parts API exposes `stepUrl`, `sha256`, and `byteSize`, but **not** the
per-file source, author, or license. A complete attribution and redistribution
record therefore cannot be produced for an individual file. The models are
downloaded only to a temporary directory for local comparison, and
`components/testdata/golden/external/` is ignored by Git.

If a per-file license and attribution are later confirmed, add the file to
`components/testdata/golden/external/`, record it in `manifest.json`, and
remove the corresponding `.gitignore` entry.

## Fetch and measurement procedure

The fetch script now selects a **comprehensive standardized corpus** by catalog
standard, family, nominal size, and representative lengths. It verifies that
each record's standard designation matches the requested standard, skips
records without the required size/length, and checks every downloaded file
against the catalog SHA-256 and byte size.

```bash
# Default core corpus: M2, M2.5, M3, M4, M5.
python3 scripts/fetch_golden_references.py \
  --out components/testdata/golden/external \
  --accept-unverified-license

# Add M6 and M8.
python3 scripts/fetch_golden_references.py \
  --out components/testdata/golden/external \
  --accept-unverified-license --scope extended

# Every catalog size and length for the selected standards (large).
python3 scripts/fetch_golden_references.py \
  --out components/testdata/golden/external \
  --accept-unverified-license --scope all --allow-large

# Inspect the plan without downloading.
python3 scripts/fetch_golden_references.py --scope core --list
python3 scripts/fetch_golden_references.py --list-selections

# Limit a run to selected families.
python3 scripts/fetch_golden_references.py \
  --out components/testdata/golden/external \
  --accept-unverified-license \
  --selection iso4762 --selection iso4032 --selection iso7089
```

Scope counts at the time of writing:

| Scope | Planned files | Coverage |
|---|---:|---|
| `core` | 167 | M2-M5 standardized fasteners, washers, pins, bearings, rods |
| `extended` | 237 | M2-M8 |
| `all` | 1048 | every catalog size/length for the selected standards |

The core corpus includes:

- **Screws/bolts:** ISO 4762, ISO 4017, ISO 7380 (catalog starts at M3),
  ISO 10642 (catalog starts at M3), DIN 913 (catalog starts at M3).
- **Nuts:** ISO 4032, ISO 4035, DIN 1587 (M4+), DIN 557 (M5+).
- **Washers:** ISO 7089, ISO 7091, ISO 7092, ISO 7093, ISO 7090, DIN 125,
  DIN 127, DIN 7349, DIN 93, DIN 440.
- **Pins:** ISO 2338 dowel pins, ISO 8752 slotted spring pins, ISO 1234 cotter
  pins.
- **Bearings:** common 608/6000/6200-class boundary references.
- **Rods:** metric threaded rods (clearly labeled as DIN 976-compatible rather
  than catalog-standard-designated).
- **Retaining rings:** DIN 471 is included in `--scope all` because the catalog
  starts at M10.
- **Non-standardized oracles:** a 2020 extrusion profile and two spur gears,
  clearly labeled and never treated as normative references.

The script writes `fetch-report.json` in the output directory. It records the
catalog commit, scope, missing combinations, per-file provenance, SHA-256,
byte size, cache/download status, and any failures. Some catalog families
(notably the ISO 4017 and ISO 7380 "simple" variants) carry
`threadRepresentation: simplified` or `geometryRepresentation: analytic
simplified`; the report records this, and the standard's normative dimensions
remain the primary acceptance criterion. Existing files with a matching
checksum are reused; `--force` re-downloads. Failed downloads are retried
(`--retries`, default 3) and written through a temporary `.part` file so a
partial download is never left as a cached fixture.

The script uses the Git LFS batch API and the short-lived signed download URL,
because some networks cannot reach `media.githubusercontent.com` directly.
Signed URLs are never written to the report.

```bash
# Verify/measure the downloaded corpus with Open CASCADE.
python3 scripts/measure_step_occt.py components/testdata/golden/external/*.step
```

`components/testdata/golden/manifest.json` remains the hand-curated record of
the v1 fixtures that were individually measured and classified. The new
comprehensive corpus is inventoried by `fetch-report.json`; the next audit
should measure selected fixtures and promote them into the manifest with
feature-level verdicts.

## Comparison rules

External STEP text is never compared for byte equality. STEP exporters differ
in entity order, identifiers, surface splitting, and metadata. Comparisons are
geometric:

1. Normalize units to millimetres.
2. Align coordinate frames by comparing axis-aligned bounding boxes; the
   frame's origin and axes are documented in `GEOMETRY.md`.
3. Compare solid count.
4. Compare overall bounding-box dimensions.
5. Compare volume where the fixture's internal geometry is comparable.
6. Treat normative standard dimensions as the primary acceptance criterion.
7. Treat a vendor model as a secondary geometric oracle.
8. Report every mismatch explicitly; do not average it away.

Tolerances (`components/testdata/golden/manifest.json`):

- linear: 0.01 mm
- volume (relative): 5 %
- contact: 0.001 mm
- surface deviation: 0.01 mm

AABB comparison is sufficient for the boundary dimensions below. Tooth flanks,
thread forms, slot cavities, and chamfers are not compared unless the fixture
and the parametric model claim the same feature.

## Curated corpus and verdicts

The full provenance record, hashes, byte sizes, measured dimensions, and
parametric values are in `components/testdata/golden/manifest.json`.

| Fixture | Reference | Measured (mm) | Parametric (mm) | Verdict |
|---|---|---|---|---|
| `fasteners/iso4762-m3x10` | ISO 4762 M3 x 10 | 5.5 x 5.5 x 13.0 | 5.5 x 5.5 x 13.0 | accepted (envelope) |
| `fasteners/iso4762-m4x20` | ISO 4762 M4 x 20 | 7.0 x 7.0 x 24.0 | 7.0 x 7.0 x 24.0 | accepted (envelope) |
| `fasteners/iso4762-m5x10` | ISO 4762 M5 x 10 | 9.2003 x 9.2003 x 15.0 | 8.5 x 8.5 x 15.0 | **rejected** — head diameter exceeds ISO 4762 dk max 8.5 |
| `fasteners/iso4032-m4` | ISO 4032 M4 | 7.66 x 7.66 x 3.2027 | 7.0 x 8.0829 x 3.2 | height accepted; across-flats not confirmable from bbox |
| `fasteners/iso7089-m4` | ISO 7089 M4 | 9.0 x 9.0 x 1.8 | 9.0 x 9.0 x 0.8 | **rejected** — thickness contradicts ISO 7089 h = 0.8 |
| `bearings/608zz` | 608ZZ | 22.0 x 22.0 x 7.0 | 22.0 x 22.0 x 7.0 | accepted (envelope) |
| `profiles/b-slot6-2020-l50` | 20 x 20 B-type slot-6, 50 mm | 20.0 x 50.0 x 20.0 | generic 20 x 20 section | **section differs materially**; envelope only, exact B-slot6 profile deferred |
| `gears/spur-m2-z20-bore8` | m2.0, z20, width 16, bore 8 | 44.0 x 44.0 x 16.0 | 44.0 x 44.0 x 16.0 | accepted (envelope) |

The 2020 profile reference is an important known discrepancy, not an accepted
section match. `profile_2020_b_slot6_a_l50` is a manufacturer-specific B-type
slot-6 section with a measured volume of 8716.82 mm^3 over 50 mm, so its solid
section area is about 174.336 mm^2. It has rounded outer corners and a lobed
core region built from 2.75 mm-radius cylindrical/arc surfaces. The generic
2020 envelope is 192.345108 mm^2 with sharp corners, a 4.2 mm bore, and simple
T-slots. The 20 x 20 x 50 envelope matches, but the section does not. Exact
B-slot6 support is deferred to the next session because it requires an
arc-capable 2D section representation and verification of the reference's
provenance/license. See `KNOWN_ISSUES.md` and `perfect-prompt-03.md`.

The two rejected models are the reason for the "verify the golden models
themselves" rule: a catalog designation is not proof that the model follows
the standard.

## Analytic references

The extrusion-frame fixtures are **analytic**, not external:

- `frames/2020-400x300x500`
- `frames/2020-600x300x400` (non-square width/depth)
- `frames/2020-45x45x45` (near the minimum valid rail span)

They are checked by `scripts/validate_frame_geometry.py`, which independently
re-derives the member schedule and section area from the declared frame
semantics instead of importing MoonBit code. These are clearly identified as
locally authored references in the manifest; they are not misrepresented as
external manufacturer models.

## Known gaps

- No suitably licensed planetary assembly reference was found in the curated
  corpus; the planetary checks are analytic tooth-outline tests.
- No external reference is committed, so golden comparison is a development
  procedure, not a hermetic CI test. The committed tests cover normative
  dimensions and analytic geometry.
- Slot, cavity, wall, and bore dimensions of the 2020 reference differ from the
  generic profile and are deliberately not compared.
