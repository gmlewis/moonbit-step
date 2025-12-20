# 01 — Hello Cube

![Preview](preview.png)

This folder contains a **working example** that generates a STEP model for: The smallest “hello world”: a parameterized cube with a few named dimensions.

The intent is that you can run the code here to emit a STEP file, open it in a CAD viewer, and/or import it into your slicer to 3D print and iterate.

## What this example demonstrates
- parametric dimensions as first-class inputs
- exporting a clean STEP solid you can reuse in other tools

## Parameters to try
- `--edge <mm>`
- `--tx <mm> --ty <mm> --tz <mm>`
- `-t <x> <y> <z>` / `--translate <x> <y> <z>`

## Run

- From the `moonbit-step` root: `./examples/run-example.sh examples/01-hello-cube/ > hello-cube.step`

## Suggested extensions
- add a variant generator (small/medium/large)
- add a quick-print calibration mode
