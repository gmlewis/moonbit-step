# 35 — Linear Rail Endcap

This folder contains a **working example** that generates a STEP model for: Endcaps that fit common rail profiles, with optional wipers and covers.

The intent is that you can run the code here to emit a STEP file, open it in a CAD viewer, and/or import it into your slicer to 3D print and iterate.

## What this example demonstrates
- tolerance sweeps as code
- dimension-driven feature generation
- repeatable measurement artifacts
- precision seats/pockets

## Parameters to try
- `clearance`
- `interference`
- `stepCount`
- `seatDiameter`
- `seatDepth`

## Suggested extensions
- emit a small “label plaque” with the chosen settings
- add a quick-fit calibration part alongside the main part
- add retention clips or covers
