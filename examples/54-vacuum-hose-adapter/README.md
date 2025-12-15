# 54 — Vacuum Hose Adapter

This folder contains a **working example** that generates a STEP model for: An adapter generator that maps between two measured hose diameters.

The intent is that you can run the code here to emit a STEP file, open it in a CAD viewer, and/or import it into your slicer to 3D print and iterate.

## What this example demonstrates
- transition solids (inlet→outlet)
- arrays and placement rules
- printability constraints for internal passages
- measurement-driven parts

## Parameters to try
- `inletSize`
- `outletSize`
- `length`
- `thickness`
- `holeDiameter`

## Suggested extensions
- add mounting flanges and bolt patterns
- add flow-straightening vanes or ribs
- add alignment pins/keys
