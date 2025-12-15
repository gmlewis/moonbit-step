# 52 — Drone Frame Arm

This folder contains a **working example** that generates a STEP model for: A frame arm generator that explores lightweighting patterns and cable channels.

The intent is that you can run the code here to emit a STEP file, open it in a CAD viewer, and/or import it into your slicer to 3D print and iterate.

## What this example demonstrates
- mount geometry derived from standards
- patterned hole circles and slots
- strength-focused fillets/ribs
- parametric dimensions as first-class inputs

## Parameters to try
- `holeSpacing`
- `mountThickness`
- `slotLength`
- `filletRadius`
- `chamferSize`

## Suggested extensions
- add cable routing features
- generate variants for multiple hardware standards
- add a variant generator (small/medium/large)
