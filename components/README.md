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
| `components/fasteners` | ISO 4762 socket head cap screws, ISO 4032 hex nuts, ISO 7089 washers, ISO 4014/4017 hex head screws/bolts, ISO 7380-1 button head screws, ISO 10642 countersunk head screws, DIN 976 threaded rods. |
| `components/profiles` | Generic T-slot extrusion sections and cut-to-length profiles. |
| `components/motion` | Shafts, stepped and keyed shafts, spacers, bushings, keys, dowel pins, standoffs, compression springs, ball bearings with analytic spheres. |
| `components/gears` | Involute spur gears, external gear pairs, and exact-internal-involute planetary sets. |
| `components/assemblies` | Rigid placements, linear/circular patterns, hardware kits, extrusion frames, bolted joints, collision/contact reports, and connectivity checks. |
| `components/collision` | Kernel-free AABB/OBB collision and contact classification with a named tolerance policy. |
| `components/catalog` | Machine-readable catalogue/query API over the component families, including supported parameters, detail levels, feature records, and provenance. |
| `components/examples/*` | Runnable generation programs and generated STEP output. |

## Documented status

- `STANDARDS.md` — standards covered, exact revisions used, supported sizes.
- `DATA_SOURCES.md` — dimensional provenance and verification notes.
- `AUDIT.md` — component inventory, defects by severity, and audit results.
- `GOLDEN_REFERENCES.md` — external reference policy, licensing, comparison
  rules, and verdicts.
- `GEOMETRY.md` — units, axes, origins, frame semantics, detail levels,
  approximations, and collision policy.
- `ASSEMBLIES.md` — assembly model, placements, patterns, contacts, and
  connectivity.
- `PROGRESS.md` — current status and next tasks.
- `DECISIONS.md` — architecture decisions.
- `KNOWN_ISSUES.md` — defects, unsupported cases, deferred features.

## Testing and validation

```bash
./test-all.sh
python3 scripts/compare_golden.py            # PASS/FAIL/SKIP against the manifest
python3 scripts/compare_golden.py --self-test # prove the harness behaviour
python3 scripts/validate_step.py components/examples/output/iso4762-M4x20.step
python3 scripts/validate_frame_geometry.py \
  components/examples/output/frame-2020-400x300x500.step \
  --width 400 --depth 300 --height 500 --series 2020
```

`scripts/validate_step.py` checks ISO 10303-21 syntax, references, per-shell
topology/orientation, PLANE planarity, OCCT `checkshape`, and watertight
tessellation. `scripts/validate_frame_geometry.py` re-imports a frame with OCCT
and independently checks every solid's position, dimensions, volume, and
pairwise overlap. OCCT, gmsh, and the validators are optional external tools;
the component library itself does not depend on them.

Assembly interference checks are available in MoonBit:

```moonbit
let collisions = assembly.collisions()
let contacts = assembly.contacts()
let floating = assembly.disconnected_instances()
```

Visual diagnostics for the frame:

```bash
moon run --target native components/examples/extrusion_frame -- \
  --width 400 --depth 300 --height 500 --series 2020 \
  --views components/examples/output/views
```

Golden references and their licensing status are documented in
`GOLDEN_REFERENCES.md`; no external model is committed because per-file
redistribution rights are unverified.

## Important limitations

- STEP booleans remain nominal in this repository. Components that need a blind
  socket or layered construction are built from multiple closed solid bodies
  rather than pretending a nominal boolean trimmed them.
- Helical threads are swept ridges, not ISO tolerance-class-compliant thread
  geometry.
- Extrusion profiles are generic engineering envelopes, **not** a claim of
  cross-manufacturer compatibility.
- Extrusion frames use full-height corner posts and rails cut to the clear
  inner span; joints are square butt contacts. Brackets, T-nuts, and end
  machining are not modeled.
- Bearing rolling elements are analytic spheres; ball diameter and ring
  chamfers are envelope/engineering geometry, not catalogue internals.
- Chamfers on ISO 4032 and ISO 4762 at `Detailed` and above are real ruled
  chamfers with engineering-default sizes; ISO 7380/10642 socket bands are
  high-resolution polygons. See `FEATURES.md`.
- Every component carries a machine-readable feature record (modeled /
  approximated with deviation / omitted with reason) in the STEP header. See
  `FEATURES.md`.
- Evaluated 3D edge fillets/chamfers are optional (OCCT); the kernel-free flat
  writer refuses them with a typed error.
- The internal ring gear uses an exact internal involute envelope and is
  validated over a rotation cycle; internal meshes carry a declared
  `0.05 * module` backlash, and the old trapezoidal profile remains an explicit
  fallback. Profile shift, helix, and ring root fillets are omitted.
- `keyed_shaft` cuts a real flat-bottomed rectangular keyway into the extruded
  section (one watertight solid); the keyway ends are square, not end-milled.
- See `KNOWN_ISSUES.md` for the full list.

## License

Apache-2.0, matching the parent repository.
