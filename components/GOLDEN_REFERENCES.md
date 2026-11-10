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

```bash
# 1. Download the curated candidates to a temporary directory.
python3 scripts/fetch_golden_references.py \
  --out /tmp/step-golden \
  --accept-unverified-license

# 2. Verify that each file's SHA-256 and byte size match the catalog record
#    (the fetch script already does this and writes fetch-report.json).

# 3. Measure each reference with Open CASCADE.
python3 scripts/measure_step_occt.py /tmp/step-golden/*.step

# 4. Generate the corresponding parametric part or assembly, then measure it
#    with the same script. The exact commands per fixture are in
#    components/testdata/golden/manifest.json.
```

The fetch script uses the Git LFS batch API and the short-lived signed download
URL, because some networks cannot reach `media.githubusercontent.com`
directly. Signed URLs are never written to the report.

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
| `profiles/b-slot6-2020-l50` | 20 x 20 B-type slot-6, 50 mm | 20.0 x 50.0 x 20.0 | 20 x 20 section | envelope accepted; section is manufacturer-specific |
| `gears/spur-m2-z20-bore8` | m2.0, z20, width 16, bore 8 | 44.0 x 44.0 x 16.0 | 44.0 x 44.0 x 16.0 | accepted (envelope) |

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
