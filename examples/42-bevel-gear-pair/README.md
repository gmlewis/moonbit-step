# 42 — Bevel Gear Pair

This folder contains a **working example** that generates a STEP model for: A bevel gear pair concept model to explore alignment, offsets, and clearances.

The intent is that you can run the code here to emit a STEP file, open it in a CAD viewer, and/or import it into your slicer to 3D print and iterate.

## What this example demonstrates
- tolerance sweeps as code
- dimension-driven feature generation
- repeatable measurement artifacts
- curve-driven geometry

## Parameters to try
- `clearance`
- `interference`
- `stepCount`
- `toothCount`
- `pitchOrModule`

## Suggested extensions
- emit a small “label plaque” with the chosen settings
- add a quick-fit calibration part alongside the main part
- add bearing pockets and shafts
