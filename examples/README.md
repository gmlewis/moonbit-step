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
./run-example.sh 12 -o coil.step -stl        # writes coil.step and coil.stl
./run-example.sh 12 -stl=coil.stl            # names the STL explicitly
./run-example.sh --view 12                   # writes /tmp/12-*.step and opens it
```

`STL_DEFLECTION=<mm>` sets the tessellation tolerance (default `0.05`). The
`-stl` and `--png` previews need either `occt-draw` or `DRAWEXE` on `PATH`.

All examples share the standard output options (`--out` and, where supported,
`--blend`, `--bpy`, `--gltf`, `--nostep`) through the `examples/common`
package, so an example's `main.mbt` only declares its own geometry parameters.

Every generated STEP file is **self-documenting**: its header begins with a
comment block listing the repository URL, the exact command line used, and the
resolved value of every parameter, so a downloaded file always explains how to
reproduce it.

## Working examples

- [12-bifilar-electromagnet](./12-bifilar-electromagnet) - A bifilar
  electromagnet with a PEEC/FastHenry export path and derived electrical
  geometry reporting.

## Shared support

- [`common/`](./common) - Output-path handling and shared example arguments.
- [`run-example.sh`](./run-example.sh) - The wrapper used to run an example and
  derive STL/PNG previews.
