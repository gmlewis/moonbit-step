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

## D15. Every component carries a machine-readable feature record

`FeatureRecord` is part of `Component`, not an optional side table. A component
cannot claim to model a feature without listing it, and cannot silently omit one
without a documented reason. The record is copied into the STEP header. This
makes detail-level differences and approximations auditable by downstream tools
and is required by the catalogue.

## D16. Evaluated edge fillet/chamfer is opt-in; the flat writer refuses

The kernel-free flat writer cannot trim edges. `Shape::Fillet`/`Shape::Chamfer`
therefore produce an `EdgeFeatureRequiresKernel` error diagnostic, and
`to_step_file_checked()` refuses the design. The intent is evaluated only by
`Design::to_step_evaluated()` (OCCT) or the Blender backend. The CSG writer
emits a `MOONBIT_EDGE_FEATURE` node that `scripts/csg_eval.py` understands.
The library remains usable without OCCT.

## D17. The exact internal involute ring is deferred on negative evidence

An involute internal tooth profile was implemented, but the fixed-centre
rotation-cycle mesh test found persistent planet/ring outline crossings
(300+). Rather than keep an unvalidated "exact" profile, it was removed and the
validated trapezoidal approximation retained with the omission recorded. The
acceptance criterion for shipping the exact profile is a passing rotation-cycle
test (and a reference tooth form).

## D18. The catalogue is built from the real builders

`components/catalog` constructs a representative component for each entry and
reads its metadata and `FeatureRecord`. This avoids a second dimension table
that could drift from the geometry; the cost is that catalogue construction
runs the builders, which is acceptable for a query-time API. The catalogue
lists supported parameters and detail levels explicitly.


## D19. Thread length is measured from the tip

ISO 4762 and ISO 4014 define `b` from the free end (tip). The builders now place
the thread at `z = 0..b` and the plain shank under the head. This is a
correctness decision, not a style choice: a nut at the free end of a bolted
joint must land on the thread. Regressions assert the placed layer positions.

## D20. Real tapered holes instead of a stepped socket

A socket lead-in is a tapered hole. Rather than fake it with a smaller hexagon
step, `ChamferedPrism` gained a per-level `hole_levels` ring stack. The resulting
hole wall is a chain of planar ruled quads, and the lead-in is measurable from
the emitted vertices. This keeps the "no relabelled sharp edge" rule.

## D21. Engineering-default chamfers are declared, not guessed silently

Where a standard does not fix a chamfer (head top edge, socket lead-in, tip,
nut faces, hex-head top, rod ends), the builder uses a small documented formula
and records it as an engineering default. The feature record and the component
description state the default. No standard dimension or tolerance class is
invented.

## D22. The golden matrix reports SKIP, not PASS, for unlicensed models

The matrix has two statuses per cell. NORMATIVE is the acceptance criterion.
GOLDEN is `SKIP` whenever the per-file licence is unverified, even when the
development-time measurement agrees. This prevents an unlicensed vendor model
from being presented as a validated oracle. The measured agreement/rejection is
still recorded for engineering information.

## D23. Compare rotation-invariant quantities for vendor models

A vendor hex model may be rotated about Z, so an axis-aligned bbox is not a
sound frame normalization. The matrix compares the axial extent and the maximum
vertex radius. This avoids rejecting a conforming model merely because its hex
orientation differs, while still rejecting a head that exceeds a standard
maximum.
