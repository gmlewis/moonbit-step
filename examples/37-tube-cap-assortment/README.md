# 12 — Tube Cap Assortment

This folder contains a **working example** that generates a STEP model for: Endcaps for common tubes (PVC/aluminum) with configurable wall thickness and ribs.

The intent is that you can run the code here to emit a STEP file, open it in a CAD viewer, and/or import it into your slicer to 3D print and iterate.

## What this example demonstrates
- parametric dimensions as first-class inputs
- exporting a clean STEP solid you can reuse in other tools

## Parameters to try
- `filletRadius`
- `chamferSize`

## Suggested extensions
- add a variant generator (small/medium/large)
- add a quick-print calibration mode

---

### Variant 1

Command line: `./run-example.sh 12 --diameter 25.4 --type cap`

![](preview-1.png)

### Variant 2

Command line: `./run-example.sh 12 --diameter 25.4 --type plug --topThickness 5`

![](preview-2.png)

### Variant 3

Command line: `./run-example.sh 12 --diameter 50 --wall 1.2 --height 20`

![](preview-3.png)

