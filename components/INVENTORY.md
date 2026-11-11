# Component Inventory

Statuses use the project vocabulary: **PASS** (executed and passed), **FAIL**
(executed and failed), **SKIP** (not executed because a tool/data/dependency is
unavailable), **NOT IMPLEMENTED**, and **INDETERMINATE** (evidence is
insufficient). A PASS is never a claim of manufacturing approval.

## Component families

| Family | Package | Status | Scope / evidence |
|---|---|---|---|
| ISO 4762 socket head cap screws | `fasteners`, `standards` | PASS | M2–M20 table; every M2/M2.5/M3/M4/M5 cell matrix-validated; head top chamfer, socket lead-in chamfer, and shank tip chamfer at `Detailed`+ as analytic cylinders/cones; thread measured from the tip; optional 60° helical thread at `FullyModeled`; `iso4762-M4x20*.step` |
| ISO 4017 fully threaded hex head screws | `fasteners`, `standards` | PASS | M2–M20 table; M2–M5 matrix-validated; hex-head top chamfer and shank tip chamfer at `Detailed`+; `iso4017-M5x20.step` |
| ISO 4014 partially threaded hex head bolts | `fasteners`, `standards` | PASS | M2–M20 table; M2–M5 matrix-validated; ISO `b` measured from the tip; hex-head and tip chamfers; M8 example; `iso4014-M8x40.step` |
| ISO 4032 hex nuts | `fasteners`, `standards` | PASS | M2–M20 table; M2–M5 matrix-validated; face chamfers at every `Detailed`+ level (ruled hex approximation) over an analytic circular bore, including the fully modeled helical body; attached internal 60° ridge at `FullyModeled`; `iso4032-M{3,4,5}*.step` |
| ISO 7089 plain washers | `fasteners`, `standards` | PASS | M2–M20 table; M2–M5 matrix-validated; analytic annular solid of revolution (two cylinders, two planes); ISO 7089 specifies no edge chamfer, so the sharp edge is documented as standard-correct and no chamfer is claimed; `iso7089-M{3,4,5}.step` |
| DIN 125 A plain washers | `fasteners`, `standards` | PASS | M2–M20 table (ISO 7089 dimensions); analytic annular solid of revolution (two cylinders, two planes); no edge chamfer specified; M3 and M8 goldens matched (M8 reference at ISO 7089 h_max = 1.8 mm); `din125-M3.step` |
| DIN 93 tab washers | `fasteners`, `standards` | PASS | M4–M20 table; analytic outer cylinder, two tangent transition cylinders, bore, two tab-side planes, tab-end plane, and two caps (9 faces, 21 edges, 14 vertices); M4/M6/M8 goldens match in volume, area, and topology; `din93-M4-detailed.step` |
| DIN 913 set screws | `fasteners`, `standards` | PASS | M3 table (M3 x 5 golden); single closed solid of revolution with flat point and blind hex socket (1 cylinder, 1 cone, 9 planes; 23 edges, 15 vertices); standard limits used where the golden exceeds DIN 913; thread omitted at this detail level; `din913-M3x5-detailed.step` |
| DIN 7349 thick washers | `fasteners`, `standards` | PASS | M3–M20 table; analytic annular solid of revolution (two cylinders, two planes); M3 golden matches in bbox, area, and volume; no edge chamfer specified; `din7349-M3-detailed.step` |
| DIN 440 V square-hole washers | `fasteners`, `standards` | PASS | M5–M20 table; one analytic outer cylinder, four planar square-hole walls, two planar end faces (7 faces, 15 edges, 10 vertices); M5 golden matches exactly in bbox, area, volume, and topology; `din440-M5-detailed.step` |
| DIN 127 B spring washers | `fasteners`, `standards` | PASS | M2–M20 table; native four cubic B-spline side surfaces (24 spans/turn) plus two planar caps, six faces / 12 edges / 8 vertices; split is a parallel-plane slot, clockwise high-Z-to-low-Z sweep; M4/M5/M6/M8 split-cap vertices match the goldens exactly (M4 volume 27.43 vs 27.64 mm³); edge radius documented as omitted; `din127-M4-detailed.step` |
| ISO 7380-1 button head screws | `fasteners`, `standards` | PASS | M3–M10 table; M3/M4/M5 matrix-validated; ISO circular-arc dome (`r_f`/`d_L`); hex socket at the ISO upper across-flats limit; tip chamfer at `Detailed`+; `iso7380-M4x16-detailed.step` |
| ISO 10642 countersunk screws | `fasteners`, `standards` | PASS | M3–M10 table; M3/M4/M5 matrix-validated; 90° countersink; length over the flush head; socket lead-in and tip chamfers at `Detailed`+; `iso10642-M4x16-detailed.step` |
| DIN 976-1 threaded rods | `fasteners`, `standards` | PASS | M2–M20 table; M2–M5 matrix-validated; engineering lead-in chamfers at both ends at `Detailed`+; optional helical thread; `din976-M8x200.step` |
| Generic T-slot profiles | `profiles` | PASS | 2020/2040/2060/2080/3030/3060/4040/4080; generic envelopes, not vendor sections |
| Cut-to-length extrusions | `profiles` | PASS | Extruded section with core bore; optional corner radii; no end machining |
| Rectangular extrusion frames | `assemblies` | PASS | 4 posts + 8 rails; clear-span cut lengths; four fixtures (including rounded); no brackets/T-nuts |
| Plate with hole | `assemblies` | PASS | Parametric plate used by the bolted joint |
| Bolted joint assembly | `assemblies` | PASS | Two plates, screw, washer, nut; `bolted-joint-M4-2x5.step`; optional standard screw length |
| Hardware kit / fastener grid | `assemblies` | PASS | Screw + washer + nut; short-screw placements regression-tested |
| Shafts, stepped and filleted shafts | `motion` | PASS | Plain/stepped cylinders; single-solid filleted shaft with a real torus; `filleted-shaft-d10-16.step` |
| Keyed shafts and keys | `motion` | PASS | Real flat-bottom keyway; key with independent height; `keyed-shaft-20x40.step` |
| Spacers, bushings, pins, standoffs | `motion` | PASS | Parametric envelopes; no standards table claimed |
| Compression springs | `motion` | PASS | Helical sweep; exact axial `0..length`; wire/section approximations recorded |
| Ball bearings | `motion` | PASS | ISO 15 boundary table (22 designations, including 628); analytic rings (cylinders/cones) + analytic spheres; a single-solid shielded variant with recessed 45° face shield grooves and no balls (matches 608ZZ); envelope internals; roller/chamfer validation |
| Involute spur gears | `gears` | PASS | Module/teeth/pressure angle/bore/backlash/fillet/chamfer; theoretical involute; undercut limitation recorded |
| External gear pairs | `gears` | PASS | Standard centre distance + offset; static pose; mesh-cycle tests for several pairs |
| Exact internal involute ring | `gears` | PASS | Internal relation `psi(r)`; rotation-cycle zero-crossing test; trapezoidal fallback retained |
| Planetary gear sets | `gears` | PASS | Tooth-count/spacing conditions; odd-count ring phase; planet-planet clearance; static pose |
| Collision/contact validation | `collision` | PASS (conservative) | AABB broad phase + 15-axis OBB narrow phase; clearance/contact/interference/collision; envelope conservative for non-convex sections |
| Catalogue/query API | `catalog` | PASS | Built from the real builders; feature records and provenance |
| STEP export | `cad`, `components/examples/output` | PASS | Syntax, references, shells, topology, orientation, planarity, OCCT checkshape/mesh, gmsh mesh; assembly document has no single-shape gate |
| M2–M5 golden matrix | `scripts/golden_matrix.py` | PASS (normative) | 8 families × supported sizes × 3 detail levels; NORMATIVE checks and a comparison against the downloaded open-source golden models; generated results are not tracked |

## Explicitly not implemented

- ISO tolerance classes (6g/6H limits), material properties, and certification.
- Thread runout, root relief, and cutter-generated undercuts as standards-defined
  forms. DIN 976 ends carry a labelled engineering lead-in, not a runout.
- Helical, bevel, and worm gears; timing belts/pulleys; sprockets; profile shift.
- T-nuts, corner brackets, joining plates, end caps, machined frame joints,
  couplings, linear rails, and retaining rings/inserts.
- Bearing seals, cages, and race grooves; catalogue-internal bearing geometry.
- Evaluated (trimmed) STEP booleans in the kernel-free writer. Real 3D
  fillet/chamfer evaluation is optional and requires OCCT; chamfers are
  single-edge on the DRAW path, fillets support multi-edge `blend`.
- External golden STEP geometry as committed files: the owner downloads the
  open-source golden models into the Git-ignored `external/` directory.
- Under-head radii and ISO 4032 bore-edge chamfers: no verified values, recorded
  as typed omissions.
- Exact B-slot6 extrusion pending verified provenance.

## Evidence entry points

- `AUDIT.md` — historical defect register and independent checks.
- `FEATURES.md` — per-feature modeled / approximated / omitted detail.
- `KNOWN_ISSUES.md` — current limitations and fixed-defect register.
- `VALIDATION.md` — commands, counts, and external-tool results.
- `GOLDEN_REFERENCES.md` — golden source, comparison rules, checksums, and verdicts.
- `SESSION_REPORT_06.md` — the round-6 audit and fixes.
- `SESSION_REPORT_07.md` — the round-7 thread-placement fix, chamfer coverage,
  and 108-cell matrix.
- `scripts/golden_matrix.py` — generates the per-cell matrix results on demand.
- `tools/inspect` — exact in-memory layer/bbox/surface/section/volume analysis.
- `tools/step-stats` — parse-only entity and surface counts for STEP files.
- `scripts/analysis-crosscheck.py` — MoonBit versus Python/OCCT agreement matrix.
