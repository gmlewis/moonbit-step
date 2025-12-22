# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

## Project Structure

- MoonBit packages are organized per directory, for each directory, there is a
  `moon.pkg.json` file listing its dependencies. Each package has its files and
  blackbox test files (common, ending in `_test.mbt`) and whitebox test files
  (ending in `_wbtest.mbt`).

- In the toplevel directory, this is a `moon.mod.json` file listing about the
  module and some meta information.

- **Workspace Preference**: Avoid creating separate `moon.mod.json` files for
  new examples unless absolutely necessary (e.g., when requiring a large
  dependency like a specific font data package that shouldn't be in the root).
  If an example can run using only root dependencies, keep it as part of the
  main workspace.

## Architectural Principles (CAD Package)

The `cad` package follows an **intent-based architecture**. Do not revert to eager B-Rep generation.

1. **Separation of Intent and Implementation**:
   - `Shape` and `SceneNode` capture *what* the user wants (e.g., "a cube at (10,0,0)").
   - `Design` stores a Scene Graph (`Array[SceneNode]`).
   - Compilation to STEP entities is deferred until `Design::compile()` is called.

2. **Decentralized Compilers**:
   - Each shape has its own compiler (e.g., `compiler_cuboid.mbt`).
   - Compilers take a `StepContext` and return a `@step.Ref` to the generated B-Rep solid.

3. **StepContext & Deduplication**:
   - Use `StepContext` for all repository operations.
   - Always use `ctx.direction()`, `ctx.vector()`, and `ctx.cartesian_point()` to ensure geometric primitives are deduplicated, keeping the STEP file efficient.

4. **Fluent API**:
   - Maintain the builder pattern (`Shape::new().with_name().translate()`).
   - All transformations should return a new `SceneNode` or `Shape` intent, never mutate the repository directly.

## Coding convention

- MoonBit code is organized in block style, each block is separated by `///|`,
  the order of each block is irrelevant. In some refactorings, you can process
  block by block independently.

- Prefer **functional-style programming**:
  - Use `map`, `filter`, `fold`, etc., over manual `for i = 0...` loops.
  - For simple iteration, use the idiomatic `for x in array { ... }` or `for i in 0..<n { ... }`.
  - **Range Precedence**: To ensure `moon fmt` doesn't break range logic, use explicit parentheses: `0..<(n - 1)`.

- Try to keep deprecated blocks in file called `deprecated.mbt` in each
  directory.

- Try to keep filenames relatively short and consistent; 30+
  characters in a filename is starting to feel pretty long.

- Please keep `using` statement contents lexicographically sorted for fast
  visual recognition.

- Please keep imports within `moon.pkg.json` and dependencies within `moon.mod.json`
  lexicographically sorted.

## Tooling & Verification

- `moon fmt` is used to format your code properly.
- `./test-all.sh`: Blazing fast unit tests and format checks. Run this frequently.
- `scripts/manage_examples.py`: Comprehensive suite for validation, rendering, and README generation.
  - **Validation**: Uses OCCT to check topological integrity.
  - **Rendering**: Uses OCCT's `DRAWEXE`. On macOS, this requires a Cocoa/OpenGL context.
  - **macOS Rendering Quirk**: `DRAWEXE` must be called via a STDIN pipe (not script file or `-c`) to properly initialize the Cocoa event loop. It often falls back to `.ppm` files; the script uses `sips` to convert to `.png`.

## Error Handling

- **CLI/Main**: Never use `println` for errors. Use `@cli.eprintln("msg")` followed by `abort("")` to ensure non-zero exit codes and proper short-circuiting in shell chains (`&&`).
- **Library**: Use `Result` or `raise` for internal logic errors.
