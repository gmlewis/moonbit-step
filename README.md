# gmlewis/step (MoonBit)

Lossless STEP (ISO 10303-21) parser/serializer in MoonBit.
For more information, please see the STEP Standard:
https://www.steptools.com/stds/step/

This is an experimental port of the TypeScript repo: https://github.com/tscircuit/stepts
using AI agents to assist with the port.

## Goals

- Parse real-world STEP files without panicking/aborting on malformed input.
- Preserve unknown/unmodeled entities for stable roundtrips.
- Provide actionable parse errors (line/col + statement snippet when available).

## Quick start

Parsing from a string (Result-style API, never raises):

```moonbit
// In your moon.pkg.json:
// {
//   "import": [
//     { "path": "gmlewis/step", "alias": "step" },
//     { "path": "gmlewis/step/parse", "alias": "parse" }
//   ]
// }

fn parse_example(step_text : String) -> Unit {
	match @parse.parse_repository_from_string_result(step_text) {
		@parse.ParseRepositoryResult::Ok(repo) => {
			let normalized = repo.to_step_file()
			println("entities=" + repo.len().to_string())
			println(normalized)
		}
		@parse.ParseRepositoryResult::Err(info) =>
			println(@parse.format_step_parse_error(info))
	}
}
```

Parsing from a file (raises `@parse.StepParseError` on failure):

```moonbit
fn parse_file_example(path : Bytes) -> Unit {
	let repo = @parse.parse_repository_from_file(path) catch {
		@parse.StepParseError(info) => {
			println(@parse.format_step_parse_error(info))
			return
		}
		_ => {
			println("unexpected error")
			return
		}
	}
	println(repo.to_step_file())
}
```

## What gets preserved

- Unknown/unmodeled DATA entities are represented as `@step.RawEntity` and are serialized back out.
- Serializer output is deterministic, so parse→serialize→parse→serialize stabilizes.

## Development

From this directory:

- Format + typecheck + test: `./test-all.sh`
- Tests only: `moon test --target native`
- Show warnings: `moon info --target native`

### Benchmarks

**NOTE** Benchmarks are currently broken with `moonc v0.6.34+e16ca94e6 (2025-12-05)`
because `async` is not yet supported.

Benchmarks live in the `tests` package and run via `moon bench`:

- All benchmarks: `moon bench --target native -p gmlewis/step/tests`
- Only the main benchmark file: `moon bench --target native -p gmlewis/step/tests -f bench_parse_test.mbt`

Notes:

- Benchmarks load fixture files once; per-iteration timings exclude file I/O.
- Use `@bench.T.keep` in benchmarks to prevent dead-code elimination.

## Validating STEP files (recommended: OCCT / Open CASCADE)

This repo can *parse* and *serialize* STEP, but CAD interoperability problems usually only show up when you validate with a real importer.
The most reliable “reference-ish” checker that’s easy to automate is Open CASCADE’s DRAWEXE (`occt-draw`).

### 1) Install / verify `occt-draw`

- Ensure `occt-draw` is on your PATH:
	- `occt-draw -h`

If your distro doesn’t ship `occt-draw` under that exact name, look for Open CASCADE “DRAWEXE” packages (names vary by distro).

### 2) Generate a STEP file (example)

From the `moonbit-step` directory, generate an example STEP file to a known location:

- `./examples/run-example.sh examples/01-hello-cube/ > /tmp/hello-cube.step`

Notes:

- The examples run with `moon run --target native` (see [examples/run-example.sh](examples/run-example.sh)).
- Use `--target native` for `moon check`/`moon test` as well (see [AGENTS.md](AGENTS.md)).

### 3) Import in OCCT (batch mode)

Use `testreadstep` inside DRAW to import the STEP and name the resulting top-level shape (here: `a`).

- `occt-draw -b -c "pload ALL; testreadstep /tmp/hello-cube.step a; nbshapes a;"`

What you want to see:

- Non-zero topology counts (especially `FACE` and `SOLID`) for solid models.
- For a cube-like solid you’ll typically see counts like `VERTEX: 8`, `EDGE: 12`, `FACE: 6`, `SOLID: 1`.

If you see something like `SHELL: 1` but `FACE: 0`, `EDGE: 0`, `VERTEX: 0`, OCCT imported “something” but could not build any usable topology from it.
That’s a strong indicator of a standards/interop issue in the emitted STEP.

### 4) Run basic shape validity checks

Once the shape is imported, run:

- `occt-draw -b -c "pload ALL; testreadstep /tmp/hello-cube.step a; checkshape a;"`

Typical healthy output ends with:

- `This shape seems to be valid`

Optional quick sanity checks:

- Bounding box: `occt-draw -b -c "pload ALL; testreadstep /tmp/hello-cube.step a; bbox a;"`
- Dump summary: `occt-draw -b -c "pload ALL; testreadstep /tmp/hello-cube.step a; dump a;"`

### 4b) Official one-command validation (recommended)

If you have OCCT installed, the easiest “official” validation path is the helper script:

- `./scripts/validate_with_occt.sh /tmp/hello-cube.step`

It runs OCCT import + `nbshapes` + `checkshape` in batch mode and exits non-zero if `checkshape` does not report a valid shape.

Tip: if the script isn’t executable in your environment, run it via bash:

- `bash ./scripts/validate_with_occt.sh /tmp/hello-cube.step`

### 5) Compare against a known-good fixture

If you’re debugging an import failure, compare your generated file against a fixture that OCCT can read:

- `occt-draw -b -c "pload ALL; testreadstep tests/fixtures/simple-box.step a; nbshapes a; checkshape a;"`

This helps distinguish “OCCT setup/tooling issue” from “our STEP output issue”.

### Troubleshooting checklist (when CAD tools won’t open your STEP)

- Confirm you’re actually testing the file you think you are (regenerate it and re-run the OCCT commands).
- If `nbshapes` shows zero faces/edges/vertices, treat it as a serialization/interop bug even if this repo can roundtrip the file.
- CAD importers can be strict about entity names and schema spellings (e.g. `AXIS2_PLACEMENT_3D` vs nonstandard variants).
- Use the fixture comparison above to sanity-check the OCCT toolchain and your expectations.

## Status

The code has been updated to support compiler:

```bash
$ moon version --all
moon 0.1.20251205 (073bdea 2025-12-05) ~/.moon/bin/moon
moonc v0.6.34+e16ca94e6 (2025-12-05) ~/.moon/bin/moonc
moonrun 0.1.20251205 (073bdea 2025-12-05) ~/.moon/bin/moonrun
moon-pilot 0.0.1-df92511 (2025-12-05) ~/.moon/bin/moon-pilot
```
