# 14 — Bolt Length Gauge

This folder contains a **working example** that generates a STEP model for: A physical “ruler” for bolts that includes embossed size markings.

The intent is that you can run the code here to emit a STEP file, open it in a CAD viewer, and/or import it into your slicer to 3D print and iterate.

## What this example demonstrates
- programmatic text/layout
- consistent engraving/emboss depths
- parametric borders and spacing
- tolerance sweeps as code

## Parameters to try
- `text`
- `fontSize`
- `embossDepth`
- `clearance`
- `interference`

## Suggested extensions
- add a second font/style variant
- add alignment marks or registration features
- emit a small “label plaque” with the chosen settings
