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
- `depth`
- `clearance`
- `interference`

## Suggested extensions
- add a second font/style variant
- add alignment marks or registration features
- emit a small “label plaque” with the chosen settings

---

### Variant 1

Command line: `./run-example.sh 14 --length 100`

![](preview-1.png)

### Variant 2

Command line: `./run-example.sh 14 --length 150 --width 50`

![](preview-2.png)

### Variant 3

Command line: `./run-example.sh 14 --length 80 --height 12`

![](preview-3.png)

