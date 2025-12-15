# 38 — Cycloidal Reducer Model

This folder contains a **working example** that generates a STEP model for: A programmable cycloidal reducer concept model (great for parametric curves).

The intent is that you can run the code here to emit a STEP file, open it in a CAD viewer, and/or import it into your slicer to 3D print and iterate.

## What this example demonstrates
- curve-driven geometry
- repeatable tooth/pattern generation
- assembly-aware clearances/backlash
- parametric dimensions as first-class inputs

## Parameters to try
- `toothCount`
- `pitchOrModule`
- `backlash`
- `filletRadius`
- `chamferSize`

## Suggested extensions
- add bearing pockets and shafts
- emit an exploded-view layout automatically
- add a variant generator (small/medium/large)
