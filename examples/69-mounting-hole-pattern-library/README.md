# 69 — Mounting Hole Pattern Library

This folder contains a **working example** that generates a STEP model for: A catalog of hole patterns (NEMA, VESA, fans) used by other examples.

The intent is that you can run the code here to emit a STEP file, open it in a CAD viewer, and/or import it into your slicer to 3D print and iterate.

## What this example demonstrates
- mount geometry derived from standards
- patterned hole circles and slots
- strength-focused fillets/ribs
- transition solids (inlet→outlet)

## Parameters to try
- `holeSpacing`
- `mountThickness`
- `slotLength`
- `inletSize`
- `outletSize`

## Suggested extensions
- add cable routing features
- generate variants for multiple hardware standards
- add mounting flanges and bolt patterns
