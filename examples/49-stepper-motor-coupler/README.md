# 49 — Stepper Motor Coupler

This folder contains a **working example** that generates a STEP model for: A coupler body with configurable bore diameters, clamp slots, and screw seats.

The intent is that you can run the code here to emit a STEP file, open it in a CAD viewer, and/or import it into your slicer to 3D print and iterate.

## What this example demonstrates
- mount geometry derived from standards
- patterned hole circles and slots
- strength-focused fillets/ribs
- procedural patterns

## Parameters to try
- `holeSpacing`
- `mountThickness`
- `slotLength`
- `patternScale`
- `thickness`

## Suggested extensions
- add cable routing features
- generate variants for multiple hardware standards
- add snap-fit mounting rings
