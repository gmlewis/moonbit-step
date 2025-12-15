# 37 — Gearbox Demo Assembly

This folder contains a **working example** that generates a STEP model for: A simple multi-part assembly demonstrating mating parts and alignment features.

The intent is that you can run the code here to emit a STEP file, open it in a CAD viewer, and/or import it into your slicer to 3D print and iterate.

## What this example demonstrates
- curve-driven geometry
- repeatable tooth/pattern generation
- assembly-aware clearances/backlash
- function-driven surfaces

## Parameters to try
- `toothCount`
- `pitchOrModule`
- `backlash`
- `resolution`
- `thickness`

## Suggested extensions
- add bearing pockets and shafts
- emit an exploded-view layout automatically
- add a batch runner that emits many variants
