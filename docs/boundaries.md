# Architecture boundaries

This repository is one tier of a three-tier CAD stack. The boundary is
deliberate: keeping the kernel out of this repository keeps the geometry
builders deterministic, portable, and testable.

## Tier 1 — this repository (`gmlewis/step`)

- Kernel-free parametric hardware, geometry primitives, mechanism envelopes,
  and structural features.
- Named `MateConnector` metadata (`CylindricalBore`, `CylindricalShaft`,
  `PlaneFace`, `ProfileSlot`, `Threaded`, `Datum`) and `MatePair` relationships.
- Deterministic STEP (ISO 10303-21) authoring. The flat writer represents
  `difference()`/`union_all()` nominally: child faces are concatenated and a
  real trim is the engine's job.
- Analytic tests, catalogues, and validation tooling (`scripts/validate_step.py`,
  `scripts/compare_golden.py`, `scripts/golden_matrix.py`).
- The `@cad` intent DSL, `Component`, `Assembly`, collision/contact checks, and
  the additive `ParamSpec`/`ParamSet`/`DesignFamily` design API.

The nominal boolean representation is the architectural contract, not a
limitation. A component that needs a blind socket, a radial hole, or a real
trim is built as one closed solid with explicit faces, or is exported through
the evaluated path (`Component::write_step_evaluated`, which uses OCCT).

## Engine — SolidCore / SolidCraft

SolidCore / SolidCraft is the required CAD engine:

- boolean trimming, fillets and chamfers;
- tessellation and mesh output;
- import of vendor STEP parts;
- interactive edits and assembly inspection;
- the `--view` preview loop.

Open a generated STEP in SolidCraft when real boolean or edge-feature geometry
is required. Do not make a kernel or a STEP importer a library dependency; the
optional evaluated export path (`scripts/csg_eval.py`, OCCT) is a development
tool, not part of the library's build.

## Tier 2/3 — `moonbit-19-cad`

`moonbit-19-cad` is the higher-level assembly, robotics, BOM, and control
layer: assemblies and joints/URDF, `PartMeta` and BOM generation, actuators,
sensors, PCBs, harness routing, control code, and system examples. It imports
this repository's components and connectors; it does not replace them. This
repository does not duplicate those layers.

## The `--view` iteration loop

The loop is author → export STEP → open in SolidCraft → resolve booleans,
fillets, and imports → iterate.

```bash
# Agents: generate only, never touch the GUI.
./run-example.sh --headless mechanism_design --length 140 -o /tmp/linkage.step

# Owner: write to /tmp and open the part in SolidCraft.
./run-example.sh mechanism_design --length 140 --view

# Direct component export (all dimensions in millimetres, Z is up).
moon run components/examples/mechanism_kit -- --part hinge -o hinge.step
STEP_CONNECTOR_SIDECAR=1 moon run components/examples/mechanism_kit -- \
  --part oldham -o oldham.step     # also writes oldham.step.connectors.tsv
```

In SolidCraft, resolve the parts' nominal boolean intent (the flat STEP
concatenates faces), apply fillets/chamfers, and import vendor parts. Export
the resolved model from SolidCraft if downstream work needs a trimmed
manifold.

Connector joint origins are metadata only. `compare-golden.sh` reads the
`.connectors.tsv` sidecar and adds a named `joint.origin` for every connector
in the SolidCraft session. Those frames never change the STEP file, its
volume, bounding box, or layer count, and a missing sidecar or GUI is a note,
never a failure. Use `--no-connectors` to skip them or `--headless` for
generation-only runs.

## Imported vendor parts

This repository does not implement a STEP importer. A licensed vendor part is
opened in SolidCraft, where it is imported and positioned interactively. The
interface contract in this repository is the named connector (origin, axis,
kind, gender, diameter, depth) and the `MatePair` that resolves two connectors.
A builder may therefore reference a vendor interface (for example an LM8UU
seat or an MGN rail) without redistributing vendor geometry.
