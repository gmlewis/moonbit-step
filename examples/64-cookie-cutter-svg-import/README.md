# 64 — Cookie Cutter Svg Import

This folder contains a **working example** that generates a STEP model for: Turn a vector outline into a cookie-cutter-style wall with thickness rules.

The intent is that you can run the code here to emit a STEP file, open it in a CAD viewer, and/or import it into your slicer to 3D print and iterate.

## What this example demonstrates
- importing or reproducing vector outlines
- offsetting curves for wall thickness
- turning 2D paths into 3D solids
- parametric dimensions as first-class inputs

## Parameters to try
- `wallThickness`
- `offsetDistance`
- `cornerRadius`
- `filletRadius`
- `chamferSize`

## Suggested extensions
- add multi-layer outlines for strength
- add a handle or hanging hole
- add a variant generator (small/medium/large)
