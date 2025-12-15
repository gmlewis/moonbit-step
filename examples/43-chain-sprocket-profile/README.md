# 43 — Chain Sprocket Profile

This folder contains a **working example** that generates a STEP model for: A sprocket profile derived from parameters, with mounting patterns and lightening holes.

The intent is that you can run the code here to emit a STEP file, open it in a CAD viewer, and/or import it into your slicer to 3D print and iterate.

## What this example demonstrates
- curve-driven geometry
- repeatable tooth/pattern generation
- assembly-aware clearances/backlash
- mount geometry derived from standards

## Parameters to try
- `toothCount`
- `pitchOrModule`
- `backlash`
- `holeSpacing`
- `mountThickness`

## Suggested extensions
- add bearing pockets and shafts
- emit an exploded-view layout automatically
- add cable routing features
