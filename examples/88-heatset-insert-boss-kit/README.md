# 88 — Heatset Insert Boss Kit

This folder contains a **working example** that generates a STEP model for: A library of boss geometries for different insert sizes and wall thicknesses.

The intent is that you can run the code here to emit a STEP file, open it in a CAD viewer, and/or import it into your slicer to 3D print and iterate.

## What this example demonstrates
- arraying features from data
- layout rules (spacing, margins)
- family generation from a single config
- parametric dimensions as first-class inputs

## Parameters to try
- `rows`
- `cols`
- `cellSize`
- `filletRadius`
- `chamferSize`

## Suggested extensions
- generate multiple sizes in one run
- add embossed labels for each pocket
- add a variant generator (small/medium/large)
