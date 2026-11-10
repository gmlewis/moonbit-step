# Parametric Mechanical Components for MoonBit

A MoonBit-native library for generating dimensioned mechanical components and
assemblies and exporting them as valid STEP files through the existing
`gmlewis/step` CAD pipeline.

Everything here is under `components/` and builds on the repository's existing
`@cad.Design`, `Shape`, and STEP writer. No C, C++, Open CASCADE, Python, or
other native runtime is required to use the component packages.

## Quick start

Generate a single ISO 4762 M4 x 20 socket head cap screw:

```bash
moon run --target native components/examples/fasteners -- \
  --standard iso4762 --size M4 --length 20 --detail detailed -o M4x20.step
```

Generate a screw + washer + nut kit:

```bash
moon run --target native components/examples/hardware_kit -- \
  --size M4 --length 20 -o kit.step
```

Generate a generic 2020 T-slot frame:

```bash
moon run --target native components/examples/extrusion_frame -- \
  --width 400 --depth 300 --height 500 --series 2020 -o frame.step
```

Generate an involute gear pair:

```bash
moon run --target native components/examples/gear_pair -- \
  --module 2 --teeth 20 --mateTeeth 40 -o gear-pair.step
```

Generate the built-in M3/M4/M5 fastener catalog:

```bash
mkdir -p components/examples/output
moon run --target native components/examples/fasteners -- \
  --catalog components/examples/output
```

## Package map

| Package | Purpose |
|---|---|
| `components/common` | Units-aware validation, detail levels, thread representation, metadata, rigid placement, `Component`. |
| `components/standards` | Metric thread data and ISO/DIN dimension tables. |
| `components/fasteners` | ISO 4762 socket head cap screws, ISO 4032 hex nuts, ISO 7089 washers, ISO 4014/4017 hex head screws/bolts, DIN 976 threaded rods. |
| `components/profiles` | Generic T-slot extrusion sections and cut-to-length profiles. |
| `components/motion` | Shafts, stepped shafts, spacers, bushings, keys, dowel pins, standoffs, compression springs, simplified bearings. |
| `components/gears` | Involute spur gears, external gear pairs, and approximate straight-spur planetary sets. |
| `components/assemblies` | Rigid placements, linear/circular patterns, hardware kits, extrusion frames. |
| `components/examples/*` | Runnable generation programs and generated STEP output. |

## Documented status

- `STANDARDS.md` — standards covered, exact revisions used, supported sizes.
- `DATA_SOURCES.md` — dimensional provenance and verification notes.
- `GEOMETRY.md` — units, axes, origins, detail levels, approximations.
- `ASSEMBLIES.md` — assembly model, placements, patterns, STEP representation.
- `PROGRESS.md` — current status and next tasks.
- `DECISIONS.md` — architecture decisions.
- `KNOWN_ISSUES.md` — defects, unsupported cases, deferred features.

## Testing and validation

```bash
./test-all.sh
python3 scripts/validate_step.py components/examples/output/iso4762-M4x20.step
```

`scripts/validate_step.py` checks ISO 10303-21 syntax, references, per-shell
topology/orientation, PLANE planarity, OCCT `checkshape`, and watertight
tessellation. OCCT, gmsh, and the validator are optional external tools; the
component library itself does not depend on them.

## Important limitations

- STEP booleans remain nominal in this repository. Components that need a blind
  socket or layered construction are built from multiple closed solid bodies
  rather than pretending a nominal boolean trimmed them.
- Helical threads are swept ridges, not ISO tolerance-class-compliant thread
  geometry.
- Extrusion profiles are generic engineering envelopes, **not** a claim of
  cross-manufacturer compatibility.
- Bearing rolling elements are simplified cylindrical proxies, not spheres.
- See `KNOWN_ISSUES.md` for the full list.

## License

Apache-2.0, matching the parent repository.
