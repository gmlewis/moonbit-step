# Session Report 06 — Audit, Thread-Profile Repair, and Validation Gaps

Date: 2026-11-10. This report covers round 6, an audit-and-repair pass over the
round-5 component library. It records what was inspected, what was wrong, what
changed, and the evidence for each claim.

## 1. Starting state and toolchain

- Branch `master`, HEAD `f86c6f8` (`Fix warnings`).
- The round-5 work was present in the checkout under `components/`; it was
  preserved. No branch, tag, release, push, or remote Git state was created or
  modified.
- Toolchain: `moon 0.1.20261104 (940aa18 2026-11-04)`,
  `moonc v0.10.20+65efd5b93 (2026-11-05)`.
- Optional tools present: OCCT `DRAWEXE` (used), `gmsh` (used), `rsvg-convert`,
  macOS `sips`, Python 3, and the independent SolidCraft CAD kernel (used).
  Blender was available through MCP but was not needed for this round.
- Baseline `./test-all.sh`: **511 tests, 511 passed, 0 failed**.
- Baseline `python3 scripts/compare_golden.py`: 19 generated fixtures PASS,
  external geometry compared with the downloaded golden models, 0 FAIL.

## 2. What round 5 actually delivered

`components/` contains a working layer over the existing `@cad` intent
architecture:

- `common` — validation, `DetailLevel`, `ThreadRepresentation`, metadata,
  rigid `Placement`, immutable `Component`, feature records.
- `standards` — metric sizes M2–M20, ISO 68-1 thread data, ISO 4762, ISO 4032,
  ISO 4014/4017, ISO 7089, ISO 7380-1, ISO 10642, DIN 976-1.
- `fasteners` — all of the above as layered closed solids, including swept
  helical thread ridges at `FullyModeled`.
- `profiles` — generic T-slot envelopes and cut-to-length extrusions.
- `assemblies` — placements, patterns, frames, hardware kits, bolted joints,
  collision/connectivity validation.
- `collision` — AABB/OBB broad and narrow phase with a named tolerance policy.
- `motion` — shafts, stepped/filleted shafts, keyed shafts, spacers, bushings,
  keys, pins, standoffs, springs, simplified bearings.
- `gears` — involute spur gears, pairs, exact internal involute rings, and
  planetary sets.
- `catalog` — catalogue/query API.
- `examples` and generated STEP fixtures under `components/examples/output/`.

The round-5 report's headline engineering result, the exact internal involute
ring and zero-crossing rotation check, was retained. This round did not
re-implement or regress it.

## 3. Before/after inventory

No component family was added or removed. The inventory is unchanged; the
quality and test coverage of existing families changed:

| Family | Before round 6 | After round 6 |
|---|---|---|
| Fasteners (ISO 4762/4014/4017/4032/7089/7380/10642, DIN 976) | implemented; helical ridge placed at pitch radius and with a non-ISO flank angle | corrected ISO 68-1 basic profile; ridges attached; regression-tested |
| Profiles / frames | implemented; rounded frame generated but not independently validated | rounded frame validated with `--corner-radius` |
| Motion | implemented; spring axial extent exceeded nominal length | spring spans exactly `0..length`; swept bbox tight |
| Gears / planetary | exact internal ring, but odd planet tooth counts had a half-pitch ring error and planet overlap was unchecked | odd-count ring offset; planet clearance; backlash bound; undercut disclosure |
| Assemblies / collision | implemented; connectivity was insertion-order dependent; kit nuts misplaced | largest-component connectivity; correct nut positions; policy-aware collisions; zero separation on collision |
| STEP validation | valid assembly document reported a false FAIL | product-structure documents report SKIP for the single-shape gate |

## 4. Defects found and root causes

### D1 — Internal helical ridge detached for M16/M20 (high)

- Observed: an M20 fully modeled nut exported a ridge whose outer radius was
  9.9647 mm inside a 10 mm bore. OCCT `bcommon` of body and ridge returned
  mass **0**.
- Cause: the ridge profile was centred on the pitch diameter. The internal
  basic profile spans `D1/2 .. D/2`; its midpoint is `D/2 - H1/2`, which is
  `0.054P` outside the pitch radius. The nut's clearance bore was also not
  applied to the ridge.
- Fix: `internal_thread_ridge_center_radius_mm` centres between the basic
  crest and root, `internal_thread_ridge` accepts `radial_offset_mm`, and
  `hex_nut` passes its clearance. The root is embedded 0.1 mm into the body.
- Evidence after the fix: OCCT `bcommon` mass **37.97 mm³** (M20) and
  **2.43 mm³** (M4); SolidCraft imports the M20 nut with 0 errors and a ridge
  bbox of ±10.1 mm.

### D2 — External thread flanks were not 60 degrees (high)

- Observed: the M4 external ridge used crest width `P/8` and root width `P/4`.
  Over the ISO depth `h3 = 17H/24`, that gives an included angle of about
  **11.6°**, not 60°. The code and docs claimed the ISO 68-1 basic profile.
- Cause: `root_flat_mm()` returned `P/4`, which is neither the external groove
  root flat (`P/6`) nor the material ridge root width (`5P/6`).
- Fix: the external ridge uses `P/8` at the crest and `5P/6` at the root; the
  internal ridge uses `P/4` and `7P/8` (it was already correct). Every width
  gives `tan(30°) = (root_width - crest_width) / (2 * depth)`.
- Regression: `standards_test.mbt` asserts the widths and the 60° angle for
  every supported metric size; `fasteners_test.mbt` asserts the crest/root
  radii and the M4 crest at nominal major diameter.

### D3 — ISO 68-1 derived constants disagreed (medium)

- `external_thread_depth_mm()` used `0.61343P` while
  `external_minor_diameter_mm()` used `d - 1.226869P`, so
  `d3 = d - 2h3` was false by about 2e-6 mm. The internal pair had the same
  problem.
- Fix: all derived diameters and depths now come from `H`, so
  `d2 = d - (3/4)H`, `d3 = d - (17/12)H`, `D1 = d - (5/4)H`,
  `h3 = (17/24)H`, and `H1 = (5/8)H` are exactly consistent.

### D4 — Spring axial length exceeded the nominal length (medium)

- `compression_spring(10, 1, 20, 8)` spanned `z = -0.5 .. 20.5` although the
  documentation says `0 .. length`.
- Fix: the helix path is inset by `wire_radius` at each end and the pitch is
  based on `length - 2 * wire_radius`. The finished spring spans exactly
  `0 .. 20` for that example.

### D5 — Swept-profile bounding boxes were inflated by 5 mm (medium)

- `Shape::bounding_box` expanded every `SweptProfile` path box by 5 mm in each
  direction. A thread or spring therefore appeared up to 10 mm larger than the
  part; `Component::size()` and the OBB collision phase inherited the error.
- Fix: the bounding box now transforms the actual profile vertices through the
  same frames the STEP compiler uses. `cad/sweep_bbox_wbtest.mbt` proves a
  square-section torus has the exact `r = 9..11 mm`, `z = 0..1 mm` box.

### D6 — Disconnected-instance detection was insertion-order dependent (medium)

- `Assembly::disconnected_instances()` ran one BFS from the first instance. If
  the first item was the floating one, every connected part was reported as
  disconnected.
- Fix: connected components are found and everything outside the largest
  component is reported; if no two instances touch, every instance is reported.
- Regression: a floating screw inserted before two stacked plates is the only
  reported disconnected item.

### D7 — Rounded frame was not independently validated (low)

- `validate_frame_geometry.py` compared the rounded frame with the sharp-corner
  section area and failed by 1.03%.
- Fix: `--corner-radius` and `--corner-segments` subtract the polygonal
  corner-fillet area. The 200x200x200 rounded frame now reports a 1.23e-06
  relative volume error.

### D8 — Valid assembly STEP reported a false FAIL (low, tooling)

- `validate_step.py` applied the single-shape OCCT `checkshape` gate to a STEP
  product-structure document, which has no single topological shape.
- Fix: `is_assembly_document()` detects `NEXT_ASSEMBLY_USAGE_OCCURRENCE`; the
  single-shape `checkshape` and mesh stages are reported as `SKIP` with the
  reason. Syntax, references, shells, topology, orientation, and planarity still
  run and pass. The committed `kit-M4x20-assembly.step` now exits 0.

### D9–D19 — Additional audit findings

A second, independent audit of motion and assemblies (and a gear audit)
surfaced the following. Each was reproduced from the package geometry before
being changed.

- **D9 (high) — filleted shaft rounded the wrong corner.** The torus was at the
  larger cylinder's outer rim; the re-entrant shoulder stayed sharp. The
  example's torus changed from major 6.0 to major 7.0, minor 2.0. The builder
  also emitted zero-length segments for equal diameters and the maximum
  feasible fillet; both now build. The feature record no longer claims a fillet
  when none was applied.
- **D10 (high) — kit nut placements.** `fastener_grid_plate` placed the nut one
  nut height above the free end, and `metric_hardware_kit` used a fixed 2 mm
  offset. M4x6 overlapped the washer by 0.8 mm and the head by 0.4 mm; M2x3
  overlapped similarly. Both nuts now sit at the free end; short-screw
  regressions cover the corrected stack.
- **D11 (high) — planetary ring phase for odd planet tooth counts.** Sun 18 /
  planet 11 / ring 40 had 12 ring/planet crossings at ring phase 0 and zero
  with the ring rotated by `180/40`. The ring is now rotated by half a ring
  pitch for odd planet counts, and the public cycle diagnostic applies the same
  offset. The even-tooth fixtures are unchanged.
- **D12 (high) — planet-to-planet overlap was accepted.** The adjacent centre
  chord must exceed the planet tip diameter; 18/18/6 (chord 36 mm, tip diameter
  40 mm) is now rejected.
- **D13 (medium) — key frame and height.** The key's local origin and extent are
  documented (`0..width`, `0..height`, `0..length`); `key_height_mm` is now an
  explicit parameter, and a taller key is described as protruding into the hub.
  The keyed-shaft feature record uses the clamped segment count.
- **D14 (medium) — bearing validation.** Overlapping roller complements (608
  with 34 rollers) and Detailed rings thinner than the 0.2 mm chamfer are
  rejected. The faceted-bore ball sagitta (~0.018 mm for 608 at 48 segments) is
  documented as an envelope limitation.
- **D15 (medium) — collision aggregation/policy.** A collision or contact
  aggregate now has `separation_mm = 0`; `Assembly::collisions(policy~)` now
  honours a `ContactPolicy` and excludes declared interference pairs.
- **D16 (medium) — external gear backlash/undercut.** Backlash at or above
  `pi * module / 2` is rejected; `backlash_mm` is documented as per-gear. The
  spur feature record now always states the undercut limitation (and says the
  profile is the theoretical involute below the no-undercut limit).
- **D17 (low) — assembly feature aggregation.** Duplicate approximation names
  keep the largest deviation. `to_assembly_step` documentation now says one
  product per materialised layer, not per component instance.
- **D18 (low) — bolted joint length.** `screw_length_mm` lets a caller choose a
  standard length; a length shorter than the nut + plates + washer stack is
  rejected.
- **D19 (low) — spring metadata.** The designation says mean diameter (not OD);
  the wire 12-gon sagitta and radial-axial sweep approximation are documented.

## 5. Architecture and API changes

- `@cad.Shape::bounding_box` for `SweptProfile` is now tight and exact for a
  polyline profile. This is a core capability improvement; it does not change
  the STEP output.
- `@fasteners` adds:
  - `external_thread_crest_radius_mm`, `external_thread_root_radius_mm`,
    `external_thread_ridge_center_radius_mm`
  - `internal_thread_crest_radius_mm`, `internal_thread_root_radius_mm`,
    `internal_thread_ridge_center_radius_mm`
  - `internal_thread_ridge(..., radial_offset_mm~)` (backward compatible).
- `@standards.ThreadSpec` adds ridge-width helpers and corrects
  `root_flat_mm` to the basic groove root flat `P/6`.
- `Assembly::disconnected_instances` semantics are now
  insertion-order-independent and documented as largest-component based.
- `scripts/validate_step.py` detects assembly documents; its self-tests cover
  the new behaviour.
- `filleted_stepped_shaft` now fillets the re-entrant shoulder and skips
  degenerate segments.
- `key_for_keyway` adds `key_height_mm~`; `bolted_joint` adds
  `screw_length_mm?`; `Assembly::collisions` adds `policy~`.
- `SpurGearParams` rejects an excessive backlash; `PlanetaryParams` rejects
  overlapping planets; `planetary_gear_set` applies a half-ring-pitch offset
  for odd planet tooth counts.
- `bearing` rejects overlapping rollers and an impossible Detailed chamfer.
- `Assembly::features` keeps the largest deviation for duplicate
  approximation names.
- No mandatory native dependency was introduced. OCCT, gmsh, Python, and
  SolidCraft remain optional development-time validators.

## 6. Components genuinely complete and supported

Complete for the stated scope (with the limitations in section 9):

- **ISO 4762** socket head cap screws, table M2–M20, tested M3/M4/M5; head,
  socket, blind floor, optional 45° engineering chamfer; helical thread at
  `FullyModeled`.
- **ISO 4017** fully threaded and **ISO 4014** partially threaded hex head
  screws/bolts, M2–M20 table.
- **ISO 4032** hex nuts, M2–M20 table; detailed face chamfer; attached internal
  helical ridge at `FullyModeled`.
- **ISO 7089** plain washers, M2–M20 table.
- **ISO 7380-1** button head screws, M3–M10 table.
- **ISO 10642** countersunk screws, M3–M10 table; overall length measured over
  the flush head.
- **DIN 976-1** threaded rods.
- Generic T-slot profiles 2020/2040/3030/4040 and 2060/2080/3060/4080; frames
  with four posts and eight rails, cut to the clear span.
- Shafts, stepped and filleted shafts, keyed shafts with a real keyway, keys,
  spacers, bushings, pins, standoffs, springs, simplified bearings.
- Involute spur gears, external pairs, exact internal involute ring, planetary
  sets with the tooth-count/spacing conditions.

## 7. End-to-end assembly

`components/examples/bolted_joint` builds two plates (40 x 30 x 5 mm), an
ISO 4762 M4 screw, an ISO 7089 M4 washer, and an ISO 4032 M4 nut. Assumptions:

- Plate holes are `d + 0.4 mm`, so the shank clears the plates.
- The nut bore is nominal `d`; the shank is a contact, not a clearance fit.
- Screw length is `nut_height + 2 * plate_thickness + washer_height`, measured
  from the shank tip to the under-head face. The head underside meets the
  washer top; the nut sits under the bottom plate.
- The exported flat file has seven closed solids; it validates with the
  repository gate and OCCT `checkshape`.

The assembly/product-structure export (`to_assembly_step`) is also generated and
now validates as a product structure with the OCCT single-shape stages
reported as SKIP.

## 8. Collision/contact algorithm and tolerances

- Broad phase: world AABBs of the OBBs with a linear tolerance.
- Narrow phase: 15-axis separating-axis test on the oriented boxes (3 axes per
  box plus 9 edge-cross axes).
- Classification: `clearance` (positive gap), `contact` (zero-volume meeting
  within `contact_mm`), `interference_fit` (declared permitted pair), and
  `collision` (positive-volume envelope overlap). The enum also carries
  `indeterminate`, but the OBB test always resolves an answer; conservatism for
  non-convex sections is documented instead.
- Default tolerances: linear 1e-6 mm, contact 1e-6 mm, volume 1e-6 mm³,
  angular 1e-6°, surface deviation 1e-3 mm. A coarse policy is available.
- OBBs are the convex envelope for non-convex sections (T-slot, bores). A
  reported collision may therefore be an envelope overlap; a reported clearance
  is sound because the solid is inside the OBB. The frame corners are solid
  material, so the frame result is exact for the intended joint.
- With the tight swept bounding box, fully modeled threads and springs no
  longer inflate the collision envelope by 5 mm.
- Aggregated `Contact`/`Collision` reports carry `separation_mm = 0`; a
  declared `ContactPolicy` pair is an `InterferenceFit` and is excluded by
  `collisions(policy~)` but still reported by `interference_fits(policy~)`.

## 9. Golden references, sources, and metrics

- The manifest `components/testdata/golden/manifest.json` carries 23 external
  references: ISO 4762 M3/M4/M5, ISO 4032 M3/M4/M5, ISO 7380 M4/M5, ISO 10642
  M3/M4/M5, ISO 4017 M5, bearings 608/6000/6001/6200, and spur gears m2
  z20/z40, plus rejected records with evidence.
- The golden files are downloaded by the repository owner. The step.parts API does not expose a
  downloaded golden models are supplied by the repository owner. A missing
  file is reported as **SKIP**, never PASS; the normative parametric checks
  still run.
- The harness records SHA-256 checksums, size, units, and frame. Comparison
  kinds include bounding-box extents, solid count, `volume_mm3`, and
  `vertex_radius_present_mm`; geometry is normalized to mm and Z-up. STEP text
  is never compared byte-for-byte.
- `compare_golden.py --self-test` proves PASS/FAIL/SKIP, checksum mismatch,
  normalization, unknown-unit rejection, and the radius feature checks.

## 10. Test and validation commands and results

```bash
./test-all.sh
# 535 tests, 535 passed, 0 failed

python3 scripts/compare_golden.py
# 19 fixtures PASS, external geometry SKIP (19), 0 FAIL, exit 0

python3 scripts/compare_golden.py --self-test
# PASS (0 failures)

python3 scripts/validate_step_test.py
# 10/10 tests pass

python3 scripts/validate_step.py --no-mesh \
  components/examples/output/iso4762-M4x20-fully-modeled.step
python3 scripts/validate_step.py --gmsh \
  components/examples/output/iso4032-M4-fully-modeled.step
# syntax, reals, references, closed shells, topology, orientation, planarity,
# OCCT checkshape, OCCT mesh, gmsh mesh: PASS / OK

python3 scripts/validate_frame_geometry.py \
  components/examples/output/frame-2020-400x300x500.step \
  --width 400 --depth 300 --height 500 --series 2020
python3 scripts/validate_frame_geometry.py \
  components/examples/output/frame-2020-200x200x200-rounded.step \
  --width 200 --depth 200 --height 200 --series 2020 --corner-radius 1.5
# all four committed frames PASS
```

Independent-kernel evidence:

- OCCT `bcommon` of nut body and internal ridge: **0 mm³ before** the fix;
  **37.97 mm³ (M20)** and **2.43 mm³ (M4)** after.
- OCCT `bcommon` of the M4 thread core and external ridge: **10.50 mm³**, so
  the external ridge intersects its core.
- SolidCraft imported the fixed M20 nut with 0 errors, 2 closed bodies, and a
  ridge bbox of ±10.1 mm (it reaches the 10 mm bore).
- `measure_step_features.py` on `filleted-shaft-d10-16.step` reports exactly one
  `TOROIDAL_SURFACE` with major radius 7.0 mm and minor radius 2.0 mm.
- OCCT solid bounding boxes for `kit-M4x20-flat.step` show the nut at
  z = 0..3.2 mm and the washer at 19.2..20 mm, with the head above.
- The odd-planet regression uses the package's own outlines: 12 crossings with
  the unrotated ring and 0 with the assembly's half-ring-pitch placement; the
  sun mesh is 0 in both.

## 11. External tools used and skipped

- Used: OCCT `DRAWEXE` (checkshape, tessellation, boolean common), `gmsh`
  (second mesher), Python validators, SolidCraft (independent import/measure).
- Available but not used this round: Blender (no need; the STEP files are
  B-Rep), `rsvg-convert`/`sips` (no new views were required).
- External golden models: a local download; a missing file makes the external
  geometry comparison SKIP.

## 12. Remaining issues (severity and reproduction)

- **High (documented limitation):** nominal STEP booleans. Layered components
  export several closed solids. Reproduction: validate any fully modeled screw;
  it contains 5 shells. Do not treat the part as one fused manifold.
- **Medium:** no thread runout or root relief. The ridge ends are square swept
  cuts. Reproduction: inspect the axial ends of `helical-thread`.
- **Medium:** the OBB collision phase treats a non-convex section as its convex
  envelope. Reproduction: `Assembly::collisions()` on a nested-bore kit can
  report envelope overlap. It never reports a real overlap as clear.
- **Low:** T-slot profiles are generic envelopes, not manufacturer-specific
  sections. Reproduction: compare `generic-2020` with a vendor B-slot6 drawing.
- **Low:** bearing internals are envelope geometry (ball diameter = modeled
  radial gap); seals, cages, and race grooves are omitted.
- **Low:** gear sets are static layouts; the planetary rotation-cycle check is a
  2D outline test, not a 3D contact solver.
- **Low:** external golden geometry is compared when the downloaded file is present.
- **Low:** a nominally tangent bearing ball can penetrate the faceted ring bore
  by the chord sagitta (~0.018 mm for 608 at 48 segments). The bearing is a
  visual envelope, not a raceway model; roller spacing and chamfer fit are now
  validated.
- **Low:** `ShaftSegment` and `BearingSize` expose public fields; constructing
  them directly bypasses the builder validation. Use the provided lookup and
  builder functions.
- **Low:** the external gear feature record reports conservative circle-chord
  upper bounds for the involute/arc deviations, not measured involute
  deviations. The ring tip-arc deviation is likewise a conservative bound.
- **Low:** OBB collision/connectivity remains conservative for nested bores; a
  shaft inside a clearance bore can be reported as an envelope overlap and as
  connected. This is documented and the kit test records it.

## 13. Regenerating and validating representative outputs

```bash
# Fasteners (affected fully modeled files)
for s in M3 M4 M5; do
  moon run --target native components/examples/fasteners -- \
    --standard iso4032 --size "$s" --detail full \
    -o "components/examples/output/iso4032-$s-fully-modeled.step"
done
moon run --target native components/examples/fasteners -- \
  --standard iso4762 --size M4 --length 20 --detail full \
  -o components/examples/output/iso4762-M4x20-fully-modeled.step

# Spring, filleted shaft, keyed shaft
moon run --target native components/examples/spring -- \
  -o components/examples/output/spring-10x1x20.step
moon run --target native components/examples/filleted_shaft -- --fillet 2 \
  -o components/examples/output/filleted-shaft-d10-16.step
moon run --target native components/examples/keyed_shaft -- \
  --diameter 20 --length 40 --keywayWidth 6 --keywayDepth 3.5 \
  -o components/examples/output/keyed-shaft-20x40.step

# Kits (nut position) and gear/planetary headers
moon run --target native components/examples/hardware_kit -- \
  --size M4 --length 20 -o components/examples/output/kit-M4x20-flat.step
moon run --target native components/examples/hardware_kit -- \
  --size M4 --length 20 --mode assembly \
  -o components/examples/output/assembly-structure/kit-M4x20-assembly.step
moon run --target native components/examples/gear_pair -- \
  --module 2 --teeth 20 --mateTeeth 40 \
  -o components/examples/output/gear-pair-m2-20x40.step
moon run --target native components/examples/planetary -- \
  -o components/examples/output/planetary-m2-s12-p12-r36-3.step

# Independent checks
python3 scripts/validate_step.py --gmsh components/examples/output/spring-10x1x20.step
python3 scripts/validate_step.py --no-mesh \
  components/examples/output/assembly-structure/kit-M4x20-assembly.step
python3 scripts/validate_frame_geometry.py \
  components/examples/output/frame-2020-200x200x200-rounded.step \
  --width 200 --depth 200 --height 200 --series 2020 --corner-radius 1.5

# Full regeneration (changes every STEP header timestamp; use deliberately)
bash components/examples/generate_all.sh
```

## 14. Git statement

No commit, push, tag, release, branch deletion, hard reset, or remote Git
mutation was performed by this session. The owner runs all state-changing Git
commands.
