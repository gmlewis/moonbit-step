# Component and Assembly Audit

Audit date: 2026-11-09

## Starting state

- Branch: `master`
- Starting commit: `994bd0edd931d4a2160ce447a3f2380d6d0fc26c`
- MoonBit toolchain: `moon 0.1.20261104`, `moonc v0.10.20+65efd5b93`
- Baseline test suite: **408 tests, 408 passed, 0 failed** (`./test-all.sh`).
- Optional tools available: OCCT `DRAWEXE` at `/opt/homebrew/bin/DRAWEXE`,
  gmsh, `scripts/validate_step.py`, macOS `/usr/bin/curl`.

## Inventory

| Package | Public component families | Geometry strategy | STEP path | Existing tests | Audit result |
|---|---|---|---|---|---|
| `components/common` | `Component`, `Placement`, `Metadata`, `DetailPolicy`, validation | Rigid transforms and layered solids | Materialised through `@cad.Design` | `common_test.mbt` | Sound. Transform composition and inverse tested. |
| `components/standards` | ISO 4762, ISO 4032, ISO 7089, ISO 4014/4017, DIN 976, ISO 68-1 threads | Dimension tables only | N/A | `standards_test.mbt` | M3/M4/M5 tables verified against the standards. |
| `components/fasteners` | Socket head cap screws, hex head screws/bolts, hex nuts, washers, threaded rods, thread ridges | Layered prisms/extrusions; swept helical ridge for `FullyModeled` | Flat STEP | `fasteners_test.mbt` | Dimensions correct; layered construction documented. Helical ridge is an approximation, not a tolerance-class thread. |
| `components/profiles` | Generic 2020/2040/3030/4040 T-slot envelopes, cut-to-length extrusion | Extruded non-convex profile with core bore | Flat STEP | `profiles_test.mbt` | Envelopes only; not manufacturer-compatible. |
| `components/motion` | Shafts, stepped shafts, spacers, bushings, keys, dowel pins, standoffs, springs, simplified bearings | Cylinders, extrusions, helices | Flat STEP | `motion_test.mbt` | Boundary dimensions correct; internal bearing geometry is a proxy. |
| `components/gears` | Involute spur gear, external gear pair, approximate internal ring, planetary set | Polygonal involute extrusion; trapezoidal internal ring | Flat STEP | `gears_test.mbt`, `gear_mesh_test.mbt` | **P1 defect found and fixed** in planetary phasing. |
| `components/assemblies` | Hardware kit, fastener grid, extrusion frame, patterns | Placed component instances | Flat and product-structure STEP | `assemblies_test.mbt`, `extrusion_frame_test.mbt` | **P0 defect found and fixed** in the extrusion frame. |
| `components/collision` | OBB/AABB collision and contact classification, assembly connectivity | Separating-axis test | N/A | `collision_test.mbt` | New. Narrow phase rejects AABB false positives and distinguishes contact from penetration. |

## Defects

### P0-1 — Extrusion frame members interpenetrate

- **Affected component:** `assemblies/extrusion_frame`.
- **Reproduction:** `moon run --target native components/examples/extrusion_frame -- --width 400 --depth 300 --height 500 --series 2020 -o /tmp/frame.step`
- **Observed:** every rail overlapped its corner post by 10 mm; every X rail
  overlapped the adjacent Y rails by 10 mm. AABB and OBB analysis both
  reported positive-volume intersections at all eight corners.
- **Expected:** overall outside dimensions 400 x 300 x 500; four full-height
  posts; eight rails cut to the clear span; square butt contacts only.
- **Root cause:** rails were cut to `width - profile_width` and
  `depth - profile_height` and placed from `-(length)/2`, so each rail extended
  from the outer face of one post to the outer face of the opposite post. The
  correct clear span between post inner faces is `width - 2 * profile_width`
  and `depth - 2 * profile_height`.
- **Regression tests:** `components/assemblies/extrusion_frame_test.mbt`
  (`frame has no unintended positive-volume interpenetration`, cut lengths,
  endpoints, connectivity, additional sizes, invalid boundaries, STEP
  round-trip).
- **Fix:** `extrusion_frame_members()` computes an explicit member schedule from
  the declared semantics; the assembly is built from that schedule.
- **Status:** closed. See `PROGRESS.md` for the before/after collision report.

### P0-2 — T-slot section cavities overlap at the corners

- **Affected component:** `profiles/tslot` and every extrusion built from it.
- **Reproduction:** render `TSlotProfile::generic_2020().outline()` (or the
  frame section view). The rectangular cavity from each face reached the core
  corner and intersected the cavity on the adjacent face.
- **Observed:** a self-intersecting 2D outline. The generated section looked
  like blocky "pixel art"; the four T-slots and corner arrows were not
  distinguishable as a valid solid section.
- **Expected:** a simple (non-self-intersecting) polygon with four T-slots,
  four corner "arrow" solids, and one core bore, all connected.
- **Root cause:** the cavity was a full rectangle of width `cavity_width` and
  depth `slot_depth - neck`. In a 20 x 20 section, `cavity_width / 2 = 5.5` and
  the core corner is at `10 - 6 = 4`, so adjacent cavity rectangles overlap.
- **Fix:** `slot_taper()` detects when a rectangular cavity would reach the
  core corner and tapers the cavity back to leave a solid corner web of half
  thickness `wall_mm / 2`. The four corner solids become the characteristic
  arrows, connected to the central core. Profiles whose cavities do not reach
  the corner (for example the 2040 long-side cavities) keep the rectangular
  cavity.
- **Regression tests:** `profiles_test.mbt` checks that all four presets have
  simple outlines and that the 2020 outer area is 206.16 mm^2. The frame STEP
  gate and the independent volume check were re-run.
- **Status:** closed.

### P1-1 — Planetary phase ignored the sun tooth phase

- **Affected component:** `gears/planetary_gear_set`.
- **Reproduction:** `PlanetaryParams::new(module_mm=2.0, sun_teeth=18,
  planet_teeth=12, planet_count=5)` satisfies `(sun + ring) % planets == 0`
  (`(18 + 42) % 5 == 0`) but the sun tooth phase differs at each planet angle.
- **Observed:** the shared planet orientation produced **16 proper tooth-outline
  crossings** around the sun mesh.
- **Expected:** no positive-area tooth overlap at any planet over a mesh cycle.
- **Root cause:** the planet phase was `theta + 180 + 180 / planet_teeth`,
  which assumes a sun tooth is centred on every planet radial. It is correct
  only when the planet angle is a multiple of the sun pitch (for example
  `12/12/36` with three planets).
- **Regression test:** `components/gears/gear_mesh_test.mbt`
  (`planetary sun-planet phases mesh for a non-divisible layout`) plus the
  ring-clearance test.
- **Fix:** subtract the signed sun-tooth offset (scaled by
  `sun_teeth / planet_teeth`) from each planet's phase.
- **Status:** closed.

### P2-1 — Frame validation accepted zero-length rails

- **Observed:** the old guard only required `width > profile_width`, so
  `width == 2 * profile_width` was accepted and produced a zero-length rail.
- **Fix:** `extrusion_frame_members` requires `width > 2 * profile_width`,
  `depth > 2 * profile_height`, and `height > 2 * max(profile_width,
  profile_height)`.
- **Regression test:** `frame rejects spans that leave no rail length`.
- **Status:** closed.

### P2-2 — No independent collision/contact validation

- **Observed:** no facility existed to classify clearances, contacts, and
  interference; the frame defect was invisible to the test suite.
- **Fix:** new `components/collision` package with AABB broad phase, OBB/SAT
  narrow phase, tolerance policy, per-instance aggregation, and an assembly
  connectivity check.
- **Status:** closed. The envelope conservatism for slotted profiles is
  documented in `KNOWN_ISSUES.md`.

### P2-3 — No independent post-export frame geometry check

- **Observed:** the existing STEP validator checks syntax, topology,
  planarity, OCCT `checkshape`, and watertight meshing, but not whether the
  twelve solids have the intended dimensions and positions.
- **Fix:** `scripts/validate_frame_geometry.py` re-imports the STEP with OCCT,
  matches every solid to an independently derived member schedule, checks
  volume against an independent section-area calculation, checks the overall
  dimensions, and checks pairwise bounding-box overlap.
- **Status:** closed for the frame. Runs are recorded in `PROGRESS.md`.

### P2-4 — External reference models can contradict their claimed standard

- **Observed:** the step.parts `ISO 4762 M5 x 10` model has a 9.2003 mm head
  diameter (ISO 4762 maximum is 8.5 mm). The step.parts `ISO 7089 M4` model is
  1.8 mm thick (ISO 7089 normal series is 0.8 mm).
- **Decision:** reject both as normative references. They are recorded in
  `components/testdata/golden/manifest.json` with `verdict: rejected` and are
  not used as pass criteria.
- **Status:** recorded.

## Remaining limitations

These are documented engineering limitations, not undiscovered silence:

- STEP `difference()`/`union_all()` remain nominal in the kernel-free writer.
  Components avoid using them for real features and export multiple closed
  bodies where layering is mechanically honest.
- Threads are swept helical ridges with the ISO 68-1 basic profile; they are
  not tolerance-class-compliant threads.
- Bearing rolling elements are cylindrical proxies, not spheres.
- The internal ring gear is a trapezoidal approximation, not an exact internal
  involute envelope.
- Golden STEP models are downloaded by the repository owner from the
  open-source step.parts corpus; the fetch and comparison procedures are
  documented.
