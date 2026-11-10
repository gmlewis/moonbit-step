# Geometry, Units, and Approximation Policy

## Units

All component dimensions are **millimetres**. Angles in public APIs are in
degrees unless a name explicitly says radians. The component packages use the
repository's `@cad.Length`/`@cad.Angle` types where a typed unit is useful, and
plain millimetre `Double`s where the parameter name already says `_mm`.

No component package silently converts inches or metres; convert at the call
site with `@cad.Length::inches`/`Length::m` and `to_mm()`.

## Coordinate conventions

The STEP/CAD backend is Z-up. Every component documents its own frame:

| Family | Axis | Origin | Orientation |
|---|---|---|---|
| ISO 4762 screw | +Z | free shank end | head on +Z side; socket opens toward +Z |
| ISO 4032 nut | +Z | bearing face | one pair of flats normal to X |
| ISO 7089 washer | +Z | bottom bearing face | bore centered on Z |
| ISO 4014/4017 screw/bolt | +Z | free shank end | hex head on +Z side |
| DIN 976 rod | +Z | one end | no head |
| Shaft / stepped shaft | +Z | bottom end | segments stack in +Z |
| Spacer / bushing | +Z | bottom face | bore centered on Z |
| Key | +Z | corner at (0,0,0) | rectangular block |
| Bearing | +Z | bottom face | rings centered on Z |
| T-slot extrusion | +Z | section at z = 0 | section centered on XY |
| Spur gear | +Z | bottom face | one tooth centered on +X |
| Gear pair | +Z | driver at origin | driven along +X |
| Planetary set | +Z | sun at origin | planets on a circle; ring coaxial |
| Extrusion frame | +Z | overall bounds centered in X/Y, resting on z = 0 | posts at corners; +X = width, +Y = depth, +Z = height |

Placements are rigid transforms in the parent frame. `Placement::compose(outer,
inner)` applies `inner` first. A component's `nodes_under(parent)` applies the
parent transform to every layer without changing the component's local
parametric data.

## Extrusion frame semantics

`extrusion_frame(width, depth, height, profile)` treats `width`, `depth`, and
`height` as **overall outside dimensions**, including the profile section.

- Four vertical posts occupy the corners and run the full height.
- X rails run between post inner faces; their cut length is
  `width - 2 * profile_width`.
- Y rails have cut length `depth - 2 * profile_height`.
- All joints are square butt contacts at post inner faces. There are no mitres,
  brackets, end taps, or fasteners.
- The member schedule is public as `extrusion_frame_members()`; it reports each
  member's stable ID, role, cut length, start/end points, and placement.
- Valid configurations require `width > 2 * profile_width`,
  `depth > 2 * profile_height`, and
  `height > 2 * max(profile_width, profile_height)`.

An X rail and a Y rail meet along a zero-volume edge at each corner; each also
touches its post over a face patch. This is intended contact, not
interpenetration.

## Collision and contact validation

`components/collision` provides a reusable, kernel-free geometric validation
facility:

- **Broad phase:** world AABBs (`Aabb::overlaps`).
- **Narrow phase:** oriented-box separating-axis test over all 15 box axes
  (three face axes per box and nine edge-cross axes). AABB overlap alone is
  never reported as a collision.
- **Classification:** `Clearance`, `Contact`, `InterferenceFit`, `Collision`,
  `Indeterminate`. Two solids sharing a face or edge are `Contact` when the
  minimum overlap is within `TolerancePolicy::contact_mm`.
- **Measured values:** minimum penetration depth, lower-bound separation along
  the best separating axis, an AABB-intersection upper bound on common volume,
  and the intersection region.

`TolerancePolicy::default()` uses 1e-6 mm linear/contact tolerance;
`TolerancePolicy::coarse()` uses 1e-3 mm for large or tessellated models. The
named policy keeps arbitrary epsilons out of call sites.

`Assembly::collision_reports()` aggregates layer pairs by component instance.
`Assembly::collisions()` returns only positive-volume overlaps;
`Assembly::contacts()` returns intended face/edge contact;
`Assembly::interference_fits()` returns declared permitted overlaps.
`Assembly::disconnected_instances()` and `is_connected()` build a contact graph
and report floating members.

Declared fits are handled with `ContactPolicy`:

```moonbit
let policy = @collision.ContactPolicy::none().permit("hub", "shaft")
let reports = assembly.collision_reports(policy~)
```

A permitted pair keeps its measured penetration depth and region but is
classified as `InterferenceFit` instead of `Collision`, so it does not appear in
`collisions()`.

### Conservatism for non-convex sections

A shaped solid is represented by the OBB of its local shape bounding box. For a
box-like extrusion this is the exact outer envelope. For a T-slot profile the
OBB is the convex envelope: slots and the core bore are not subtracted. A
reported collision is therefore conservative (it may report envelope overlap
that the slot voids would avoid). At a frame corner the material that meets is
the solid corner, so the classification is exact for the intended joint. This
limitation is recorded in `KNOWN_ISSUES.md`.

## Detail levels

`DetailLevel` is a request, not a guarantee. Each builder documents its behavior.

| Level | Fastener behavior | Gear behavior | Profile behavior |
|---|---|---|---|
| `Simplified` | Major envelopes; socket modeled; no helical thread | Lower segment counts | Lower bore segments |
| `Detailed` | Same envelope plus small features the kernel supports; no helical thread by default | Higher segment counts | Higher bore segments |
| `FullyModeled` | Adds a swept helical thread ridge | Higher segment counts | Higher bore segments |

`ThreadRepresentation` is explicit and can override the detail policy:

- `None` — plain cylinder; no thread claim.
- `Cosmetic` — reserved for visual-only features; not used by a builder that
  would mislead. Components that cannot model a real thread say `None`.
- `Helical` — a swept helical ridge with the standard pitch and basic profile.

## Layered solids

The repository's STEP booleans (`difference()`, `union_all()`) are **nominal**:
they concatenate faces rather than trimming. The component library therefore
avoids relying on them for features that must be geometrically true.

Examples:

- A socket head cap screw head is a solid floor disc plus a ring with a
  hexagonal through-hole. The socket is blind because the floor body closes it.
- A shaft with a modeled thread is a plain shank, a minor-diameter threaded
  core, and a swept helical ridge.
- A nut with a modeled thread is a hex body with a major-diameter bore plus an
  internal helical ridge.

These are separate closed shells in the STEP file. Each is watertight and passes
the repository validator; together they form the part visually. This is
documented per component, not hidden.

## Approximations and their controls

| Feature | Approximation | Control |
|---|---|---|
| Circular bores/envelopes | Regular polygon extrusion | `circle_segments` in `DetailPolicy` |
| Helical thread | Swept trapezoidal ridge along a helix | `segments_per_turn`, pitch, basic profile |
| Gear tooth flank | Involute sampled at discrete points | `involute_points` |
| Gear tip/root arcs | Polygonal arcs | `arc_points` |
| Bearing rolling elements | Analytic spheres (`SPHERICAL_SURFACE`) | ball diameter = modeled radial gap |
| Bearing ring chamfers | Parallel-inset ring stack | engineering default `bearing_chamfer` |
| T-slot section | Generic polygon with tapered T-slot notches and corner webs ("arrows") | profile dimensions, all explicit |
| Internal ring gear | Trapezoidal internal tooth form | `tooth_fraction`, tip/root arc points |
| 2D chamfer/fillet | Straight bevel or sampled circular arc | `distance`/`radius`, `segments`, `angle_deg` |
| Prism face/edge chamfers | Parallel-inset ring stack (planar facets) | `ChamferedPrism` levels, inset |
| Head socket bands | High-resolution polygon ring stack | `circle_segments` (64 at Detailed) |

## Feature geometry primitives

- **`RevolvedProfile`** — a solid of revolution from a chain of line/arc bands
  in the (r, z) half-plane about +Z. Line bands compile to cylindrical, conical,
  and planar faces; arcs centred on the axis compile to spherical faces and
  off-axis arcs to toroidal faces. The chain must either end on the axis (poles:
  cylinder, cone, sphere, dome) or close away from it (annular: washer, ring).
  Orientation is normalised so the material is on the left; each band uses its
  start circle with oriented-edge sense `.T.` and its end circle with `.F.`, so
  neighbours traverse a shared circle in opposite directions. Full-period bands
  carry a seam edge.
- **`ChamferedPrism`** — a convex prism built from a stack of parallel-inset
  rings with an optional prismatic through-hole. Consecutive rings are joined by
  planar quads (adjacent edges stay parallel under a parallel offset) and the
  ends are planar caps. It produces real, measurable face/edge chamfers on hex
  nuts, socket-head heads, washers, and bearings.
- **`Profile2D::chamfer_vertices` / `fillet_vertices`** — 2D bevel/arc
  operations for extruded sections (plate outlines, extrusion corner radii,
  gear tip details). Convex vertices are cut; re-entrant vertices are beveled or
  rounded. Invalid sizes return a typed error.

Singular poles (cone apex, sphere pole) are analytic; the OCCT tessellator emits
a zero-area facet there, which `scripts/validate_step.py` excludes from the
watertight edge count and reports explicitly.

## Validation

Use the repository validator on generated files:

```bash
python3 scripts/validate_step.py part.step
python3 scripts/validate_step.py --no-mesh part.step
python3 scripts/validate_step.py --gmsh part.step
```

The checks include ISO 10303-21 syntax, reference integrity, per-shell edge
usage and orientation, `PLANE` planarity, OCCT `checkshape`, and watertight
tessellation. OCCT/gmsh are optional; when they are unavailable the validator
reports skipped checks.

For the extrusion frame, `scripts/validate_frame_geometry.py` adds an
independent post-export gate: it re-imports the STEP with OCCT, matches every
solid to a schedule re-derived in Python from the declared frame semantics,
checks each volume against `section_area * cut_length`, checks the overall
outside dimensions, and rejects positive-volume bounding-box overlap.

Gear meshes are checked by 2D tooth-outline crossing tests across a mesh cycle
(`components/gears/gear_mesh_test.mbt`). A single static pose is not treated as
proof that a gearset can rotate.

## Determinism

Component geometry is computed directly from parameters. No solver runs at
export time. For identical inputs and the same detail policy, the STEP output is
deterministic apart from the file timestamp in the STEP header.

## Assembly STEP caveat

`Assembly::to_step()` writes a flat design with one `MANIFOLD_SOLID_BREP` per
component layer; this form passes the repository's full validator.
`Assembly::to_assembly_step()` writes the STEP product/occurrence structure with
`NEXT_ASSEMBLY_USAGE_OCCURRENCE` and `ITEM_DEFINED_TRANSFORMATION`. That file
passes syntax, reference, shell topology, orientation, and planarity checks, but
the repository's OCCT `checkshape` gate reads a single named shape and reports
"not a topological shape" for the assembly document. Use a CAD assembly importer
to inspect the product structure, or use the flat export for the full validator
gate.

## Feature records

A component's `FeatureRecord` is the geometric contract: `modeled` features
are exact analytic/ruled geometry, `approximated` features carry a deviation
and the generating control, and `omitted` features carry a reason. Detail
levels only change geometry when the record says so. A feature is never listed
as modeled unless the STEP contains the corresponding surface or exact
planar/ruled form.

## Edge features (optional)

`EdgeFeature` is intent: a base solid, an edge selector, a size, and an optional
chamfer angle. Its local bounding box is the base's bounds; applying a fillet or
chamfer never grows the part. The flat writer refuses the intent with a typed
diagnostic. The evaluated path selects edges by index, direction, or proximity
and applies OCCT `blend`/`chamf`; a selected edge that cannot absorb the
requested size is an error, not a silently sharp edge.

## Gear root fillet and tip chamfer

The 2D involute outline is post-processed: root runs and tip runs are collapsed
to their transition corners, then rounded/bevelled with the 2D profile helpers.
The root band widens adaptively when the root circle is close to the base
circle. The result is a simple polygon; the arc chord deviation is recorded.
The extruded gear is a single watertight solid.


## Internal involute ring

An internal (ring) gear differs from an external gear: its tooth tips point
inward at `r_p - m`, its roots reach outward at `r_p + 1.25 m`, and its tooth
thickness **grows** outward:

```text
psi(r) = psi_p + inv(a_r) - inv(a_p),   psi_p = pi/(2 z) - backlash/(2 r_p)
```

The bore boundary is the hole; the ring material lies outside it. Tooth 0 is
centred on +X, matching the external gear convention. The tip radius must be
outside the base circle, which at 20° with a standard addendum needs roughly 34
or more ring teeth; a smaller ring is rejected rather than truncated. Internal
meshes use a declared circumferential backlash (`0.05 * module` by default) so
the ring tooth tip clears the planet flank through a full rotation cycle. A
planetary layout is a static pose; the rotation-cycle test is the kinematic
evidence, and it is a 2D outline test, not a 3D contact solver.

## Keyed shaft

The keyway is a rectangular notch in the shaft cross-section on +Y, with the
slot sides at `x = +- w/2` and a flat bottom at `y = r - depth`. The section is
extruded along +Z, so the keyway is real geometric material removal, not a
nominal boolean. The section arc is a polyline; its chord deviation is recorded.
A matching key has X = width, Y = height, Z = length and a declared side
clearance.
