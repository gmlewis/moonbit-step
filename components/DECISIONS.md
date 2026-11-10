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

## D11. Frame dimensions are overall outside dimensions; rails use butt joints

`width x depth x height` means overall outside dimensions. Four full-height
posts occupy the corners; rails are cut to the clear span between post inner
faces (`width - 2 * profile_width`, `depth - 2 * profile_height`). The chosen
joint strategy is square butt contact at post inner faces. This is one coherent
strategy; the library does not mix full-length perimeter members with
shortened cross-members.

Members are generated from an explicit `FrameMember` schedule rather than
scattered translations. The generator computes cut lengths from the declared
frame and profile dimensions; it does not assume every member is the same
length.

## D12. Collision uses an OBB narrow phase, with documented envelope conservatism

AABB overlap is only a broad phase. The narrow phase is a 15-axis
separating-axis test on oriented boxes, so a shared face is contact rather than
collision, and a real positive-volume overlap is detected. For non-convex
sections the OBB is the convex envelope; the slot/bore voids are not subtracted,
which can only over-report, never silently clear, an interference. This policy
is documented in `GEOMETRY.md` and `KNOWN_ISSUES.md`.

## D13. Planetary phasing follows the sun tooth phase per planet

The standard equal-spacing condition `(sun + ring) % planet_count == 0` is
necessary but not sufficient for a static phase. The planet orientation must
compensate for the sun tooth phase at each planet radial. The generator
computes the signed offset from the nearest sun tooth and scales it by
`sun_teeth / planet_teeth`. This preserves the 12/12/36 three-planet layout and
fixes valid layouts such as 18/12/42 with five planets.

Gear-mesh acceptance uses 2D outline crossing tests over a full mesh cycle, not
a single static render.

## D14. External goldens are oracles, not production geometry, and are not committed unverified

The parametric generator remains authoritative. External STEP models are used
only for geometric cross-checks. Because per-file redistribution rights could
not be verified from the step.parts API, no external STEP file is committed;
`scripts/fetch_golden_references.py` downloads candidates to a temporary
directory with SHA-256 verification, and `components/testdata/golden/` records
the provenance and verdicts. Two candidate references that contradict their
claimed standards were rejected rather than used as pass criteria.
