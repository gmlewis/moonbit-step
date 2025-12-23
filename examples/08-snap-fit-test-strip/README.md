# 08 — Snap Fit Test Strip

This folder contains a **working example** that generates a STEP model for: A strip of snap-fit geometries with varying interference to measure your tolerances.

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

---

### Variant 1

Command line: `./run-example.sh 08 --stepCount 3`

_[Render Failed]_

### Variant 2

Command line: `./run-example.sh 08 --stepCount 5 --interference 0.2 --interferenceStep 0.2`

_[Render Failed]_

