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

### ISO 10642 cross-check

The downloaded `iso10642_socket_countersunk_screw_m3x12` model (SHA-256
recorded in the fetch report) was measured with OCCT during the feature
session: its head is 6.046 mm across, its conical bearing surface has a 45°
half-angle (90° included), and its overall length is 12 mm. This corroborates
the ISO 10642 M3 head diameter (6.0 mm) and the 90° countersink used by the
parametric builder. It is a cross-check of nominal data, not a committed
fixture; the model is not redistributed.

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

## Comparison harness (2026-11-10)

`scripts/compare_golden.py` is the reproducible PASS/FAIL/SKIP harness. For
each manifest fixture with a `generation` recipe it:

1. verifies the external file's SHA-256 and byte size when present;
2. skips the external geometry comparison when the per-file licence is not
   verified (all current fixtures are `unverified-per-file`);
3. generates the parametric part through the example CLI (never internal
   dimension functions);
4. measures it with OCCT (solids, bbox, volume) and with
   `measure_step_features.py` (surface types, cone/sphere/torus parameters,
   vertex radii);
5. checks the manifest's normative bbox extents, solid count, and feature
   expectations;
6. optionally builds a lower-detail contrast part and asserts that the detailed
   build adds faces (a real chamfer/fillet presence check);
7. prints `PASS`/`FAIL`/`SKIP` per check and per fixture.

The harness runs the normative/analytic checks even when the external file is
absent. A missing file or unverified licence is reported as `SKIP`, never as a
pass.

Current fixture results (all external files present, all licences unverified):

| Fixture | Result | Notes |
|---|---|---|
| ISO 4762 M3 x 10 | PASS | 3 solids, bbox, detailed adds 80 faces |
| ISO 4762 M4 x 20 | PASS | 3 solids, bbox, detailed adds 80 faces |
| ISO 4032 M4 | PASS | 1 solid, AF 7.0, h 3.2, adds 28 faces |
| ISO 7089 M4 | PASS | OD 9.0, t 0.8, vertex radii 2.15 / 4.5 |
| 608 bearing | PASS | 10 solids, OD 22, width 7, 16 sphere faces, bore radius 4 |
| ISO 10642 M3 x 12 | PASS | 3 solids, head 6.0, overall 12.0, cone half-angle 45° |

The harness found the ISO 10642 length defect (13.7 mm instead of 12.0 mm),
which was fixed; see `KNOWN_ISSUES.md` KI-01.

```bash
python3 scripts/compare_golden.py
python3 scripts/compare_golden.py --fixture bearings/608zz
```


## Golden validation expansion (2026-11-10, exact-ring/keyway session)

### Promoted fixtures

`components/testdata/golden/manifest.json` now records 23 external references.
Every one has SHA-256, byte size, source page/URL, declared and measured
dimensions, the parametric counterpart recipe, and a licence status of
`unverified-per-file`. No external STEP file is committed.

| Fixture | Reference | Measured (mm) | Verdict |
|---|---|---|---|
| ISO 4762 M3 x 10 / M4 x 20 | head dia, overall length | matches ISO 4762 | accepted-envelope |
| ISO 4032 M3 / M4 / M5 | height; plan = across corners | matches | accepted-envelope / height-only |
| ISO 7089 M3 / M4 / M5 | OD matches; thickness 1.1 / 1.8 / 2.2 | ISO 7089 h = 0.5 / 0.8 / 1.0 | **rejected** (thickness) |
| ISO 4017 M5 x 20 | head width = across corners; overall 23.74 | nominal L + k = 23.5 | accepted-head-width-only |
| ISO 7380 M4 x 10 / M5 x 12 | dk and overall (L + k) | matches | accepted-envelope |
| ISO 10642 M3 x 12 / M4 x 10 / M5 x 12 | overall length; 90° countersink | matches; dk slightly below max | accepted-envelope |
| Bearings 608 / 6000 / 6001 / 6200 | bore, OD, width | matches ISO 15 boundary dims | accepted-envelope |
| Spur gear m2 z20 / z40 | tip dia, face width, bore, root dia | matches | accepted-envelope |
| 2020 B-slot6 profile | 20 x 20 x 50 envelope | section differs | envelope-only |
| Metric threaded rod "M3 x 200" | model is 3 mm x **400 mm** | contradicts 200 mm label | **rejected** |

The washer and rod rejections are deliberate: a catalogue designation is not
proof that the model follows its standard. They are recorded, not used as
oracles. The ISO 4032 plan bounding box is the across-corners span
(`s / cos 30°`), so it is consistent with the standard across-flats but cannot
prove it from an axis-aligned bbox.

### Harness self-test

`python3 scripts/compare_golden.py --self-test` proves:

- a matching fixture reports `PASS` and the external geometry check really runs;
- a deliberately mismatched expected dimension reports `FAIL`;
- a missing/unlicensed external file reports the external check `SKIP` while
  the normative/parametric checks run and the fixture verdict is `PASS`;
- a checksum mismatch reports `FAIL`;
- a Y-up/inch reference normalizes to mm/Z-up; unknown units raise;
- the `vertex_radius_present_mm` feature kind passes and fails correctly.

All eight cases pass. This is a development-time harness, never a runtime
dependency.

### Independent measurement (MCP)

The exact-ring planetary (`planetary-m2-s12-p12-r36-3.step`) and the keyed shaft
(`keyed-shaft-20x40.step`) were imported into SolidCraft as an independent
kernel:

| Model | OCCT volume | SolidCraft volume | Bodies | Result |
|---|---:|---:|---:|---|
| Keyed shaft + key | 12161.0 mm³ | 12161.0146 mm³ | 2 closed | agree |
| Planetary 12/12/36 (exact ring) | 34743.98 mm³ | 34744.013 mm³ | 5 closed | agree |

The planetary render shows the orange planet teeth sitting in the purple ring
spaces with no visible overlap. The keyed-shaft render shows the rectangular
keyway notch at the crown. Numeric agreement is the acceptance criterion; the
renders confirm the feature is where the measurement says it is.

### Comparison capability gap (honest)

The manifest declares a `surface_deviation_mm` tolerance, but the current
harness does **not** yet implement a sampled surface-distance or section
comparison. It compares solid count, bbox, volume, analytic surface/feature
counts, cone angle, sphere count, and clustered vertex radii. A
surface-deviation or cross-section comparison is future work; until it exists,
no fixture is reported as surface-deviation-verified.

### Families not promoted this session

The curated set is intentionally small. The following families exist in the
local corpus and have parametric counterparts, but were not promoted with a
generation/comparison recipe this session: ISO 4014 (partially threaded hex
bolt), DIN 913 set screws, ISO 4035 thin nuts, ISO 2338 dowel pins, ISO 8752
spring pins, and DIN 471 retaining rings. The 6300-series bearing reference is
absent from the downloaded core corpus. The 2040/3030/4040 extrusion envelopes
remain analytically checked in the profile tests, not against an external
model. These are honest coverage gaps, not passes.

## M2–M5 golden matrix (round 7, 2026-11-10)

`scripts/golden_matrix.py` is the reproducible matrix harness. It covers eight
families and every M2/M2.5/M3/M4/M5 size they support, at Simplified, Detailed,
and FullyModeled:

`iso4762`, `iso4017`, `iso4014`, `iso4032`, `iso7089`, `iso7380`,
`iso10642`, `din976`.

Each cell records:

- **NORMATIVE**: independent standard outside dimensions, solid count, and the
  measured chamfer/lead-in/thread vertex rings (PASS/FAIL).
- **GOLDEN**: the independent model comparison (PASS/FAIL/SKIP).

Result: **108 cells, NORMATIVE 108 PASS / 0 FAIL; GOLDEN 0 PASS / 108 SKIP.**
Every external candidate has `license_status = unverified-per-file`, so it is
measured for development-time information only and is never the acceptance
oracle. A `SKIP` is never reported as a pass.

### Rotation-invariant comparison

A vendor hex model may be rotated about Z, so an axis-aligned bounding box is
not rotation invariant (a hexagon rotated 15° has a square bbox). The harness
compares:

- the axial extent, and
- the outer radius, taken as the larger of the maximum vertex radius and half
  the larger in-plane bbox extent. The bbox term is a sound lower bound that
  catches a widest analytic surface with no vertex at its own radius; the
  vertex term recovers a hexagon's across-corners radius.

Both are invariant under a Z rotation, with the declared tolerance. For ISO 4762,
ISO 7380, and ISO 10642 the standard head diameter is a **maximum**, so a model
below it is recorded as `below-standard-maximum` (permitted) rather than a
contradiction.

### Development-time results

39 cells agree (13 family/size pairs × 3 detail levels):

| Family | Agreement |
|---|---|
| ISO 4762 | M3/M4 head diameter and overall length |
| ISO 4032 | M2–M5 across-corners radius and height |
| ISO 7380-1 | M3–M5 head radius and overall length |
| ISO 10642 | M3 exactly; M4/M5 below the standard maximum (permitted) |

69 cells are rejected with measured evidence:

| Family | Rejection evidence |
|---|---|
| ISO 4762 M2/M2.5/M5 | head diameter 4.1131 / 4.8708 / 9.2003 mm vs ISO maxima 3.8 / 4.5 / 8.5 mm |
| ISO 4017/4014 | overall length exceeds `L + k` by 0.2–0.24 mm (vendor head height larger than ISO nominal) |
| ISO 7089 | thickness 0.7/1.1/1.1/1.8/2.2 mm vs ISO 7089 h = 0.3/0.5/0.5/0.8/1.0 mm |
| DIN 976 | the "l025" model is 50 mm long (2× the label) |
| ISO 10642 M4/M5 | head below but within the standard maximum (recorded as permitted) |

The machine-readable record is `components/testdata/golden/matrix.json`; the
table is `components/testdata/golden/MATRIX.md`. No external STEP file is
committed and no committed preset is derived from an unlicensed golden.

```bash
python3 scripts/golden_matrix.py                        # print the matrix
python3 scripts/golden_matrix.py --write components/testdata/golden
python3 scripts/golden_matrix.py --family iso4762 --size M4
python3 scripts/golden_matrix.py --self-test
```

### Harness measurement capabilities

- **Vertex rings** (`measure_step_features.py`): `(z, radius, count)` from real
  `VERTEX_POINT`s, used to measure chamfer legs, socket lead-ins, and ring
  stacks.
- **Mass properties** (`measure_step_occt.py`): volume and centre of mass.
- **Sections** (`measure_step_mesh.py`): tessellate, slice at a plane, and
  report area, perimeter, and extents.
- **Surface deviation** (`measure_step_mesh.py`): sampled bidirectional
  point-to-triangle distance (Hausdorff-like).
- **Checks** (`compare_golden.py`): `mass_properties`, `sections`,
  `surface_deviation`, `vertex_ring`, `sphere_radius_present_mm`.
- **Self-test**: 15 checks covering PASS/FAIL/SKIP, checksum, units/frame,
  feature kinds, mass, sections, deviation, and vertex rings.
