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

Placements are rigid transforms in the parent frame. `Placement::compose(outer,
inner)` applies `inner` first. A component's `nodes_under(parent)` applies the
parent transform to every layer without changing the component's local
parametric data.

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
| Bearing rolling elements | Cylindrical proxies, not spheres | `roller_count`, ring thickness |
| T-slot section | Generic polygon with T notches | profile dimensions, all explicit |
| Internal ring gear | Trapezoidal internal tooth form | `tooth_fraction`, tip/root arc points |
| Head chamfers / fillets | Not modeled | documented limitation |

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
