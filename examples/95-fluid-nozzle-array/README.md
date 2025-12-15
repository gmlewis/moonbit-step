# 95 — Fluid Nozzle Array

This folder contains a **working example** that generates a STEP model for: An array of nozzles placed by rules (spacing, angles), ideal for code-driven layouts.

The intent is that you can run the code here to emit a STEP file, open it in a CAD viewer, and/or import it into your slicer to 3D print and iterate.

## What this example demonstrates
- transition solids (inlet→outlet)
- arrays and placement rules
- printability constraints for internal passages
- parametric dimensions as first-class inputs

## Parameters to try
- `inletSize`
- `outletSize`
- `length`
- `filletRadius`
- `chamferSize`

## Suggested extensions
- add mounting flanges and bolt patterns
- add flow-straightening vanes or ribs
- add a variant generator (small/medium/large)
