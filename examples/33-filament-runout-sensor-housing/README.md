# 33 — Filament Runout Sensor Housing

This folder contains a **working example** that generates a STEP model for: A housing generator with controlled clearances for switches and fasteners.

The intent is that you can run the code here to emit a STEP file, open it in a CAD viewer, and/or import it into your slicer to 3D print and iterate.

## What this example demonstrates
- tolerance sweeps as code
- dimension-driven feature generation
- repeatable measurement artifacts
- lid/body workflows

## Parameters to try
- `clearance`
- `interference`
- `stepCount`
- `wallThickness`
- `lidClearance`

## Suggested extensions
- emit a small “label plaque” with the chosen settings
- add a quick-fit calibration part alongside the main part
- add gasket grooves or light pipes
