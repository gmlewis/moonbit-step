# Assemblies

## Model

`components/assemblies` provides two levels:

- `Component` — a named, metadata-bearing collection of `ComponentLayer` solid
  bodies in a local millimetre frame.
- `Assembly` — an ordered list of placed component instances
  (`AssemblyItem`), each with its own rigid `Placement` and unique instance
  name.

A component keeps its parametric identity. An assembly never merges components
into one opaque solid; `Assembly::to_step()` writes every layer as its own
`MANIFOLD_SOLID_BREP`, and `Assembly::to_assembly_step()` writes one product per
materialized solid with a placement transformation.

## Placements

`Placement` is a rigid transform with a matching `Rz * Ry * Rx` rotation
convention:

```moonbit
let p = @common.Placement::at(10.0, 0.0, 0.0, rz=90.0)
```

`Placement::compose(outer, inner)` applies `inner` first:

```text
compose(outer, inner).apply_point(p) == outer.apply_point(inner.apply_point(p))
```

`Placement::inverse()` reverses translation and rotation. Tests cover identity,
composition order, inverse round-trips, and agreement with `@cad.rotate_point`.

## Patterns

```moonbit
Assembly::new(name="row")
  .linear_pattern(screw, 4, dx=10.0, dy=0.0, dz=0.0)

Assembly::new(name="ring")
  .circular_pattern(screw, 8, 20.0, start_angle_deg=0.0)
```

`linear_pattern` places item `i` at `base + i * (dx, dy, dz)`.
`circular_pattern` places items evenly around the Z axis and rotates each by its
angular position plus `orientation_deg`. Both accept a `base` placement that is
applied first, so a rotation in `base` rotates the whole pattern.

## Included assemblies

- `metric_hardware_kit(size, length)` — screw + washer + nut, separated along
  +Z.
- `fastener_grid_plate(...)` — a rectangular pattern of screws, washers, and
  nuts.
- `extrusion_frame(width, depth, height, profile)` — 4 full-height corner
  posts and 8 rails cut to the clear span between post inner faces.
  `extrusion_frame_members()` exposes the member schedule (stable ID, role, cut
  length, start/end points, placement). Overall outside dimensions are
  `width x depth x height`.
- `gear_pair(driver, driven)` — two external involute gears at the standard
  centre distance plus an offset.
- `planetary_gear_set(params)` — sun, equally spaced planets, and an approximate
  internal ring gear. Each planet is individually phased against the sun tooth
  phase at its radial.

## Collision, contact, and connectivity

Every assembly can be validated as an arrangement of physical instances:

```moonbit
let reports = assembly.collision_reports()
let collisions = assembly.collisions()      // unintended positive-volume overlap
let contacts = assembly.contacts()          // intended face/edge contact
let fits = assembly.interference_fits()     // declared permitted overlap
let floating = assembly.disconnected_instances()
let connected = assembly.is_connected()
```

Declare a permitted fit with `@collision.ContactPolicy`:

```moonbit
let policy = @collision.ContactPolicy::none().permit("hub", "shaft")
let reports = assembly.collision_reports(policy~)
```

`collision_reports()` uses an AABB broad phase and an OBB separating-axis narrow
phase. A shared face or edge is `Contact`, not `Collision`; a declared
interference fit is a separate `CollisionKind::InterferenceFit`. Reports carry
the instance pair, penetration depth, separation lower bound, overlap-volume
upper bound, and the intersection region.

The extrusion frame's intended contacts are:

- each rail end face against a post inner face;
- each X rail and Y rail meeting along a zero-volume edge at a corner.

Nested-bore assemblies (the hardware kit's screw through a washer and nut)
necessarily report envelope overlap because an OBB does not subtract the bore.
For those assemblies, coaxial alignment, bore clearance, and engagement are
checked analytically (`assemblies_test.mbt`) rather than by treating the
envelope report as a collision.

The frame regression tests require `collisions().is_empty()`, at least one
contact, `is_connected() == true`, and no disconnected instances for the
400 x 300 x 500, 600 x 300 x 400, and near-minimum 45 x 45 x 45 configurations.

## Visual diagnostics

`components/examples/extrusion_frame --views DIR` writes top, front, side,
isometric, and cross-section SVG views. Each member has a stable color, its ID
and cut length are labelled, and any collision reported by the validator is
stroked red and listed in the caption. The section view draws the actual
T-slot outer boundary and core bore, so the four corner "arrows" and slot
cavities are directly visible. The views are diagnostics only; the numeric
tests remain the acceptance criterion.

## STEP representation

Flat export (recommended for the repository validator):

```moonbit
assembly.write_step(Some("kit.step"), checked=true)
```

This yields separate solids in one design. It passes the full validator,
including OCCT `checkshape` and watertight tessellation.

Assembly/product export:

```moonbit
assembly.write_assembly_step(Some("kit-assembly.step"))
```

This writes the STEP product structure: a parent product, one child product per
materialized solid, `NEXT_ASSEMBLY_USAGE_OCCURRENCE`, and
`ITEM_DEFINED_TRANSFORMATION`. It passes the validator's syntax, reference,
shell, topology, orientation, and planarity checks. The repository's OCCT
single-shape gate reports "not a topological shape" because it asks OCCT to read
one named shape from an assembly document; use a CAD assembly importer or the
flat export when the OCCT gate is required.

## Documentation in generated files

Each component embeds its metadata (designation, standard/revision, family,
size, length, material, source) in the STEP header documentation. An assembly
adds its name, instance count, and one line per component instance. Generated
files therefore carry their provenance when copied out of the repository.
