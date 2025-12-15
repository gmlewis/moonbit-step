# 27 — Camera Tripod Adapter

This folder contains a **working example** that generates a STEP model for: Adapter geometry driven by measured dimensions and thread insert allowances.

The intent is that you can run the code here to emit a STEP file, open it in a CAD viewer, and/or import it into your slicer to 3D print and iterate.

## What this example demonstrates
- arraying features from data
- layout rules (spacing, margins)
- family generation from a single config
- measurement-driven parts

## Parameters to try
- `rows`
- `cols`
- `cellSize`
- `thickness`
- `holeDiameter`

## Suggested extensions
- generate multiple sizes in one run
- add embossed labels for each pocket
- add alignment pins/keys
