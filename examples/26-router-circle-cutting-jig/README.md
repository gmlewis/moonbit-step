# 26 — Router Circle Cutting Jig

This folder contains a **working example** that generates a STEP model for: A circle-cutting jig where radius, mounting, and handle are all variables.

The intent is that you can run the code here to emit a STEP file, open it in a CAD viewer, and/or import it into your slicer to 3D print and iterate.

## What this example demonstrates
- mount geometry derived from standards
- patterned hole circles and slots
- strength-focused fillets/ribs
- measurement-driven parts

## Parameters to try
- `holeSpacing`
- `mountThickness`
- `slotLength`
- `thickness`
- `holeDiameter`

## Suggested extensions
- add cable routing features
- generate variants for multiple hardware standards
- add alignment pins/keys

---

### Variant 1

Command line: `./run-example.sh 26 --armLength 250`

![](preview-1.png)

### Variant 2

Command line: `./run-example.sh 26 --baseDiameter 180 --armLength 400 --armWidth 50`

![](preview-2.png)

