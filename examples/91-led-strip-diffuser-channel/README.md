# 91 — Led Strip Diffuser Channel

This folder contains a **working example** that generates a STEP model for: A channel profile generator with snap lids and diffuser clearances.

The intent is that you can run the code here to emit a STEP file, open it in a CAD viewer, and/or import it into your slicer to 3D print and iterate.

## What this example demonstrates
- tolerance sweeps as code
- dimension-driven feature generation
- repeatable measurement artifacts
- spring features by construction

## Parameters to try
- `clearance`
- `interference`
- `stepCount`
- `snapClearance`
- `armThickness`

## Suggested extensions
- emit a small “label plaque” with the chosen settings
- add a quick-fit calibration part alongside the main part
- generate a “fit ladder” variant automatically
