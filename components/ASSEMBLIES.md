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
- `extrusion_frame(width, depth, height, profile)` — 4 posts and 8 overlapping
  rails of a generic T-slot profile.
- `gear_pair(driver, driven)` — two external involute gears at the standard
  centre distance plus an offset.
- `planetary_gear_set(params)` — sun, equally spaced planets, and an approximate
  internal ring gear.

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
