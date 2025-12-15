# 40 — Rack And Pinion Slider

This folder contains a **working example** that generates a STEP model for: A rack/pinion slider showing repeatable tooth patterns and assembly tolerances.

The intent is that you can run the code here to emit a STEP file, open it in a CAD viewer, and/or import it into your slicer to 3D print and iterate.

## What this example demonstrates
- tolerance sweeps as code
- dimension-driven feature generation
- repeatable measurement artifacts
- arraying features from data

## Parameters to try
- `clearance`
- `interference`
- `stepCount`
- `rows`
- `cols`

## Suggested extensions
- emit a small “label plaque” with the chosen settings
- add a quick-fit calibration part alongside the main part
- generate multiple sizes in one run
