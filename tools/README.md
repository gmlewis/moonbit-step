# Analysis tools

Two pure-MoonBit executables inspect the library's own models without Python,
OCCT, or STEP re-import. Python/OCCT remain development-time oracles for
imported golden geometry; see `scripts/analysis-crosscheck.py`.

## `tools/inspect`

Builds a component with the same builders the examples use and reports the
in-memory scene graph.

```bash
moon run --target native tools/inspect -- --help
moon run --target native tools/inspect -- \
  --standard iso4762 --size M4 --length 20 --detail detailed --json
moon run --target native tools/inspect -- --bearing 608 --shielded --json
moon run --target native tools/inspect -- --module 2 --teeth 40 --bore 10 --json
moon run --target native tools/inspect -- \
  --bearing 608 --section z=3.3 --volume
moon run --target native tools/inspect -- --standard iso4762 --mesh part.obj
moon run --target native tools/inspect -- --self-test
```

Families: fasteners (`--standard`, `--size`, `--length`, `--detail`,
`--threads`), bearings (`--bearing`, `--rollers`, `--shielded`), a single spur
gear (`--module`, `--teeth`, `--bore`, `--faceWidth`), motion
(`--shaft`/`--filleted-shaft`/`--keyed-shaft`), T-slot extrusions
(`--profile`, `--length`), and rectangular frames (`--frame WxDxH`).

Output: component name, layer count, per-layer shape/bbox/surface inventory,
exact sections (`--section`, repeatable, accepts `5` or `z=5`), volumes and
centroids, a stable `--json` schema, an OBJ mesh (`--mesh`), and a STEP writer
for cross-checks (`--step`).

### Analytic coverage

Exact sections and volume/centroid:

- `Cylinder`, `Cuboid`.
- `RevolvedProfile` (line and arc bands; caps; open-on-axis and annular
  profiles).
- `ExtrudedProfile` (polygonal holes and an analytic round bore).
- `ChamferedPrism` (outer level stack, hole levels, and round bore), with
  prismatoid band integration.
- `CalibrationChamferBlock`.

Surface inventories mirror the compilers for every shape, including
`ExtrudedBezierProfile` (planes plus `SURFACE_OF_LINEAR_EXTRUSION`) and
`SweptProfile` (its planar triangle split).

### Typed limitations

- `ExtrudedBezierProfile`, `SweptProfile`: sections/volume are
  `NotAnalytic("... requires tessellation")`; the inventory is still exact.
- `Fillet`, `Chamfer`, `Difference`: no trimmed Boolean semantics; volume and
  sections are `NotAnalytic` and the inventory is nominal.
- `Union` volumes are the nominal sum of children; layered components report
  `nominal_union: true` and are never presented as trimmed solids.
- World-z sections are exact only for translations and pure Z rotations;
  otherwise the tool reports `UnsupportedTransform: <layer>` and skips that
  layer. It never silently approximates.
- Empty planes return `EmptySection`; an ambiguous profile returns a typed
  `DegenerateProfile`/`NotAnalytic` error.

## `tools/step-stats`

Parse-only structure inspection for this repository's STEP and downloaded
goldens (including entities the typed parser does not model, preserved as
`RawEntity`).

```bash
moon run --target native tools/step-stats -- \
  components/testdata/golden/external/iso4762_socket_head_cap_screw_m4x20.step --json
moon run --target native tools/step-stats -- \
  target/golden-compare/parametric-bearing_608zz.step --json
moon run --target native tools/step-stats -- --self-test
```

Reports file size, entity counts (`ADVANCED_FACE`, `CLOSED_SHELL`,
`MANIFOLD_SOLID_BREP`, `CARTESIAN_POINT`, `EDGE_CURVE`, `CIRCLE`, `LINE`, ...),
surface counts (plane/cylinder/cone/sphere/torus/bspline/revolution/extrusion),
solid and shell counts, and `bbox_from_points_mm`.

Limitation: it does not tessellate, trim, or compute true sections.
`bbox_from_points_mm` spans every `CARTESIAN_POINT`, so it is not a
trimmed-geometry bounding box. Use `scripts/measure_step_*.py` for imported
golden sections, deviation, and validity.

## Cross-check

```bash
python3 scripts/analysis-crosscheck.py
```

The matrix builds each representative part with `tools/inspect`, writes STEP,
and compares against `measure_step_occt.py`, `measure_step_features.py`, and
tessellated interior sections from `measure_step_mesh.py`. Tolerances: bbox
0.01 mm, volume 0.5 % (2 % for layered unions), surface counts exact, section
area/perimeter/extent 2 %. Every check prints PASS/FAIL/SKIP; a SKIP always
carries its typed reason (swept thread, rotated assembly member, or an extent
that needs a 2D outline).

`scripts/compare-golden.sh --inspect` additionally prints the
`tools/inspect --json` summary for each generated counterpart.
