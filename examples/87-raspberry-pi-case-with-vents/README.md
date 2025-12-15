# 87 — Raspberry Pi Case With Vents

This folder contains a **working example** that generates a STEP model for: A case variant that explores vent patterns, bosses, and cable cutouts.

The intent is that you can run the code here to emit a STEP file, open it in a CAD viewer, and/or import it into your slicer to 3D print and iterate.

## What this example demonstrates
- lid/body workflows
- bosses, standoffs, and fastener-friendly geometry
- cutouts driven from a declarative spec
- parametric dimensions as first-class inputs

## Parameters to try
- `wallThickness`
- `lidClearance`
- `screwBossOD`
- `filletRadius`
- `chamferSize`

## Suggested extensions
- add gasket grooves or light pipes
- add vent patterns tied to thermal needs
- add a variant generator (small/medium/large)
