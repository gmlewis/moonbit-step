# gmlewis/step (MoonBit)

A 3D modeling DSL and lossless STEP (ISO 10303-21) parser/serializer in
MoonBit. Build models with a fluent API, export valid topologically-sound STEP
files, and read or rewrite existing STEP data without losing entities you do
not model.

## Quick start

```moonbit
async fn main {
  let design = @cad.Design::new(name="my-model")
    .add(
      @cad.Cuboid::new(20, 20, 20)
        .with_name("base")
        .with_color(@cad.Rgb::orange())
    )
    .add(
      @cad.CalibrationChamferBlock::new(10, 10, 5, chamfer_size_mm=1.0)
        .with_name("top-part")
        .translate(z=20)
    )

  design.write_step(Some("model.step"))
}
```

Use `to_step_file_checked()` / `write_step(..., checked=true)` as the normal
export entry point: it refuses designs with error diagnostics. See
[`examples/README.md`](examples/README.md) for runnable programs and
[`components/README.md`](components/README.md) for the parametric parts
library.

## Output formats

| Format | How | Notes |
|---|---|---|
| STEP | `./examples/run-example.sh 12 -o coil.step` | Exact B-Rep; opens in any CAD viewer or slicer. |
| STL | `./examples/run-example.sh 12 -o coil.step -stl` | OCCT tessellation; `STL_DEFLECTION=<mm>` (default 0.05). |
| PNG | `./examples/run-example.sh 12 -o coil.step --png=preview.png` | Four views; needs OCCT, macOS `sips`, and optionally Inkscape. |

The Blender and glTF backends are available through the CAD API; see
[`examples/README.md`](examples/README.md) for the runnable example.

`./examples/run-example.sh --help` lists the wrapper options, and
`./examples/run-example.sh 12 -- --help` lists an example's own parameters.

### STEP booleans are nominal

`difference()` and `union_all()` concatenate child faces; they do not trim or
subtract. The output is still a valid closed shell, but overlaps are not
resolved. `Design::diagnostics()` reports nominal and dropped booleans, and
checked export refuses error designs. For real trims use the Blender backend or
the evaluated path:

- `Design::to_csg_step()` writes a real CSG tree (`CSG_SOLID` /
  `BOOLEAN_RESULT`).
- `Design::write_step_evaluated()` evaluates that tree with OCCT through
  `scripts/csg_eval.py` and writes a flat B-Rep.
- `Design::planar_faces()` and `cut_on_face(...)` support face queries and
  sketch-on-face placement; use the evaluated export for a trimmed result.

The STEP entity layer itself models true booleans and CSG constructs and
preserves unrecognized entities verbatim as `RawEntity`, so files using richer
constructs round-trip intact.

## Parsing

```moonbit
fn parse_example(step_text : String) -> Unit {
  match @parse.parse_repository_from_string_result(step_text) {
    @parse.ParseRepositoryResult::Ok(repo) => {
      let normalized = repo.to_step_file()
      println("entities=" + repo.len().to_string())
      println(normalized)
    }
    @parse.ParseRepositoryResult::Err(info) =>
      @cli.eprintln(@parse.format_step_parse_error(info))
  }
}
```

## Profile helpers and fits

`Profile2D` helpers compute exact coordinates, so output depends only on your
numbers and stays diffable:

```moonbit
@cad.bolt_circle(6, 22.0)                 // hole centers on a bolt circle
@cad.grid_of_holes(3, 2, 20.0, 15.0)      // centered, row-major centers
@cad.point_on_circle(10.0, 90.0)          // one point at an angle

let profile = @cad.Profile2D::new(@cad.Profile2D::centered_circle(60.0))
  .with_hole_at(0.0, 0.0, 20.0)                       // central bore
  .with_bolt_circle(6, 22.0, 5.0, fit=@cad.Fit::Free) // holes grow by the fit
let plate = @cad.ExtrudedProfile::new(profile.outer, 8.0, holes=profile.holes)
```

`Fit` expresses printed-hole clearance per face: `Nominal` (0.00 mm),
`Close` (0.10), `Free` (0.25), `Press` (-0.05). A fit changes the modelled
void; it is not a printer compensation layer.

## Verification

```bash
./test-all.sh
python3 scripts/validate_step.py part.step
python3 scripts/validate_step.py --no-mesh part.step   # syntax/topology only
python3 scripts/validate_step.py --gmsh part.step      # second mesher
```

`validate_step.py` checks ISO 10303-21 syntax (upper-case `E`, mandatory decimal
point), `#id` references, per-shell edge usage and orientation, `PLANE`
planarity, OCCT `checkshape`, and watertight tessellation. OCCT is an optional
development tool; the library itself has no native dependency.

`scripts/manage_examples.py all --validate --render` validates and renders every
example. Text examples use the vendored `baloo` font in
`assets/fonts/baloo.json.gz` (SIL Open Font License 1.1; license in
[assets/fonts/LICENSE-baloo.txt](assets/fonts/LICENSE-baloo.txt)).

## Repository layout

| Path | Contents |
|---|---|
| `cad/` | Intent-based modeling DSL, shape compilers, STEP writer, analysis, glTF/Blender backends. |
| `entities/`, `parse/`, `repository/`, `header/` | STEP entity model, parser, and serializer. |
| `cli/` | Command-line argument and error-reporting helpers. |
| `components/` | Parametric fasteners, profiles, motion, motors, stock, gears, assemblies, collision, catalogue. |
| `examples/` | Runnable example programs (see [`examples/README.md`](examples/README.md)). |
| `tools/` | Inspection and STEP statistics utilities (see [`tools/README.md`](tools/README.md)). |
| `scripts/` | Development validation and rendering harnesses. |
| `tests/` | Cross-package integration tests. |

Toolchain: MoonBit `moon` 0.1.20261104, `moonc` v0.10.20.

## License

Apache-2.0
