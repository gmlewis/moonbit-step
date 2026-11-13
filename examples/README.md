# Examples

This directory contains runnable example projects that demonstrate how to use
this package to generate **CAD/CAM/CAE STEP files** with code.

The core idea: model parts and assemblies with a real programming language —
parametric dimensions, reusable generators, design families, programmatic text
and vector artwork, and deterministic outputs for versioning and CI.

You can use this package as a replacement for traditional CAD where
programmability and repeatability matter, or alongside CAD tools to generate
tricky geometry and then finish it in a slicer or CAD application.

## Running an example

Run an example with `./run-example.sh <number|name> [args...]`. Add
`-o file.step` to write the STEP file (otherwise it goes to stdout), and add
`-stl` to also tessellate it into an STL using OpenCASCADE:

```sh
./run-example.sh --list                      # top-level and component examples
./run-example.sh 12 -o coil.step -stl        # writes coil.step and coil.stl
./run-example.sh 12 -stl=coil.stl            # names the STL explicitly
./run-example.sh --view 12                   # writes /tmp/12-*.step and opens it
./run-example.sh --headless bearing          # generate only; prints the STEP path
```

`--view` opens and raises SolidCraft. Agents must use `--headless` instead: it
generates to `/tmp/<example>.step` (or the `-o` path), prints the STEP and
connector-sidecar paths, and never touches the GUI.

The same wrapper runs the parametric component builders in
`components/examples/` by name, including the OCCT-evaluated ones:

```sh
./run-example.sh --view bearing              # component example by bare name
./run-example.sh components/vslot --part wheel --view
./run-example.sh clamp_shaft_collar --view   # OCCT-evaluated compound
./run-example.sh fasteners -- --help         # the builder's own options
```

`STL_DEFLECTION=<mm>` sets the tessellation tolerance (default `0.05`). The
`-stl` and `--png` previews need either `occt-draw` or `DRAWEXE` on `PATH`.

Named mate connectors are shown by default for every component example: the
run writes a `<step>.connectors.tsv` sidecar and, with `--view`, adds a named
SolidCraft joint origin for each connector. Pass `--no-connectors` to suppress
both.

All examples share the standard output options (`--out` and, where supported,
`--blend`, `--bpy`, `--gltf`, `--nostep`) through the `examples/common`
package, so an example's `main.mbt` only declares its own geometry parameters.

Every generated STEP file is **self-documenting**: its header begins with a
comment block listing the repository URL, the exact command line used, and the
resolved value of every parameter, so a downloaded file always explains how to
reproduce it.

## Working examples

- [12-bifilar-electromagnet](./12-bifilar-electromagnet) - A bifilar electromagnet with a PEEC/FastHenry export path and derived electrical geometry reporting.
- [38-planetary-gearbox](./38-planetary-gearbox) - A print-in-place herringbone planetary gearbox (sun, planets, and internal ring gear) with configurable elbows; used by `gen-planetary-gears.sh`.

## Shared support

- [`common/`](./common) - Output-path handling and shared example arguments.
- [`run-example.sh`](./run-example.sh) - The wrapper used to run an example and
  derive STL/PNG previews.
