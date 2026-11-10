# Architecture Decisions

## D1. Build on `@cad` intent and the existing STEP writer

Components return `@cad.Shape` layers wrapped in `Component`; assembly export
uses `@cad.Design` and `Design::to_assembly_step`. No parallel serializer is
introduced. This keeps one STEP pipeline and preserves the repository's
existing behavior.

## D2. Layered closed solids instead of relying on nominal booleans

The repository's `difference()`/`union_all()` are nominal: they concatenate
faces and do not trim. A blind socket, threaded shank, or hollow nut built with
them would be geometrically misleading even though a coarse validator may pass
it.

Decision: build features as explicit closed bodies (floor disc + socket ring,
core + helical ridge, body + bore). Each body passes the topology and
tessellation checks. The component description states the layering.

Consequence: fastener parts export as multiple `MANIFOLD_SOLID_BREP` bodies in
one design. This is visible and honest; it is not presented as one fused solid.

## D3. Explicit `ThreadRepresentation`

A plain cylinder is not a thread. `ThreadRepresentation::None`,
`Cosmetic`, and `Helical` are separate values. Builders that cannot produce a
real thread default to `None` and say so in metadata. `FullyModeled` requests
`Helical`; callers can override explicitly.

## D4. Millimetres and documented origins

All component APIs use millimetres. Each family documents its axis and origin
in `GEOMETRY.md` and in source doc comments. `@cad.Length` is used where a typed
unit prevents mistakes, but `_mm`-suffixed parameters are plain `Double`s to
keep the API light.

## D5. Specification data separated from geometry

Standards tables and validated spec types live in `components/standards`.
Geometry builders in `components/fasteners` consume those specs. This keeps
dimensional data reviewable and testable without compiling geometry.

## D6. Validation errors are typed and explicit

`@common.SpecError` reports invalid dimensions and unsupported sizes/lengths.
Spec constructors return `Result[T, SpecError]`; executables convert a failure
to `@cli.eprintln` + non-zero exit. No builder silently clamps a dimension it
cannot support.

## D7. Assembly keeps components separate

`Assembly` stores placed component instances and materializes one solid per
layer. It never merges geometry. `Assembly::to_step()` is the flat, fully
validated representation; `to_assembly_step()` is the product-structure
representation for CAD importers.

## D8. Generic extrusion profiles are labeled generic

T-slot sections are not universal. The presets are named `generic-*`, every
dimension is explicit, and documentation says not to assume vendor
compatibility. `TSlotProfile::custom` is the supported way to model a verified
manufacturer section.

## D9. Approximation controls are part of the API

Circular resolution, helical segments per turn, involute points, arc points,
and roller count are explicit parameters or detail-policy values. This makes
the trade between file size and accuracy a caller decision and keeps output
deterministic.

## D10. Optional external validation, no mandatory native dependency

The library and tests are pure MoonBit and use only the existing packages.
OCCT/gmsh validation is an external, optional gate. The generated artifacts are
validated when the tools are present; their absence does not add a dependency
to the library.
