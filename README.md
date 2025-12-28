# gmlewis/step (MoonBit)

A high-level 3D modeling DSL and lossless STEP (ISO 10303-21) parser/serializer in MoonBit.

This repo allows you to build 3D models using a simple API and export them to valid,
topologically-sound STEP files.

![Chronos Gear-Flower](examples/100-chronos-gear-flower/preview-1.png)

*Example 100: The Chronos Gear-Flower, a parametric design with multiple colors.*

## Quick Start (Modeling)

Building a model is intuitive:

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

## Quick Start (Parsing)

Parsing from a string:

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

## Features

- **Fluent 3D DSL**: Chain transformations like `.translate()`, `.with_color()`, and `.with_name()`.
- **Lossless Roundtrips**: Unknown/unmodeled entities are preserved during parse/serialize cycles.
- **Robust CLI**: Built-in validation, proper `stderr` reporting, and short-circuiting exit codes.
- **Deterministic**: Serializer output is stable (parse → serialize → parse is idempotent).

## Development & Validation

### Verification
Run the unit tests and formatters:
- `./test-all.sh`

### Geometric Validation & Rendering
We use Open CASCADE (`occt-draw` or `DRAWEXE`) to ensure topological validity and generate previews:
- `./scripts/manage_examples.py all --validate --render --readme`

## Goals

- Provide a pleasant authoring UX for 3D models in MoonBit.
- Parse real-world STEP files without panicking.
- Provide actionable parse errors (line/col + statement snippets).

## License

Apache-2.0

## Status

The code has been updated to support compiler:

```bash
$ moon version --all
moon 0.1.20251222 (3f6c70c 2025-12-22) ~/.moon/bin/moon
moonc v0.6.36+607dbed8f (2025-12-22) ~/.moon/bin/moonc
moonrun 0.1.20251222 (3f6c70c 2025-12-22) ~/.moon/bin/moonrun
moon-pilot 0.0.1-df92511 (2025-12-22) ~/.moon/bin/moon-pilot
```
