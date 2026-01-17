#!/usr/bin/env python3
"""Debug script to check solid bounding boxes in STEP file."""

import sys
import cadquery as cq

if len(sys.argv) != 2:
    print(f"Usage: {sys.argv[0]} file.step")
    sys.exit(1)

filename = sys.argv[1]
print(f"Reading {filename}...")

imported = cq.importers.importStep(filename)
all_solids = imported.solids().vals()

print(f"\nFound {len(all_solids)} solid(s):\n")

for i, solid in enumerate(all_solids):
    bb = solid.BoundingBox()
    vol = solid.Volume()
    print(f"Solid {i+1}:")
    print(f"  Volume: {vol:.2f}")
    print(f"  X: [{bb.xmin:.2f}, {bb.xmax:.2f}]")
    print(f"  Y: [{bb.ymin:.2f}, {bb.ymax:.2f}]")
    print(f"  Z: [{bb.zmin:.2f}, {bb.zmax:.2f}]")
    print()
