#!/usr/bin/env python3
"""
Post-processes STEP files to compute boolean differences using OCC via CadQuery.

Usage:
    ./scripts/compute_booleans.py input.step output.step

Expects input STEP file to have products named with pattern:
  - {name}-base: The base solid
  - {name}-cutter1, {name}-cutter2, ...: Solids to subtract
"""

import sys
from pathlib import Path

# CadQuery includes OCC (pythonocc-core)
try:
    from OCC.Core.STEPControl import STEPControl_Reader
    from OCC.Core.BRepAlgoAPI import BRepAlgoAPI_Cut
    from OCC.Core.TopAbs import TopAbs_SOLID
    from OCC.Core.TopExp import TopExp_Explorer
    from OCC.Core.TopoDS import topods_Solid
    from OCC.Extend.DataExchange import write_step_file
    from OCC.Core.GProp import GProp_GProps
    from OCC.Core.BRepGProp import brepgprop_VolumeProperties
except ImportError:
    print("Error: pythonocc-core not found.")
    print("")
    print("Install with uv:")
    print("  uv pip install pyparsing")
    print("  uv pip install --find-links https://github.com/tpaviot/pythonocc-core/releases/download/7.8.1 pythonocc-core")
    print("")
    print("Or try build123d as alternative:")
    print("  uv pip install build123d")
    sys.exit(1)


def compute_boolean_difference(input_step: str, output_step: str) -> None:
    """
    Read STEP file with separate base/cutter solids and compute boolean difference.
    """
    print(f"Reading {input_step}...")

    # Use OCC STEP reader to properly handle product structure
    reader = STEPControl_Reader()
    status = reader.ReadFile(input_step)

    if status != 1:  # IFSelect_RetDone
        print(f"Error: Failed to read STEP file (status {status})")
        sys.exit(1)

    # Transfer shapes
    reader.TransferRoots()
    shape = reader.OneShape()

    # Extract all solids from the compound
    solids = []
    explorer = TopExp_Explorer(shape, TopAbs_SOLID)
    while explorer.More():
        solid = topods_Solid(explorer.Current())
        solids.append(solid)
        explorer.Next()

    print(f"Found {len(solids)} solid(s)")

    if len(solids) < 2:
        print("Warning: Expected at least 2 solids (base + cutters), found only 1")
        print("Exporting unchanged...")
        write_step_file(shape, output_step)
        return

    # Use heuristic: largest solid by volume is the base

        brepgprop_VolumeProperties(solid, props)
        volume = props.Mass()
        solids_with_volume.append((solid, volume))

    solids_with_volume.sort(key=lambda x: x[1], reverse=True)

    base_solid, base_volume = solids_with_volume[0]
    cutters = [s for s, v in solids_with_volume[1:]]

    print(f"Base solid volume: {base_volume:.2f}")
    for i, (cutter, vol) in enumerate(solids_with_volume[1:], 1):
        print(f"Cutter {i} volume: {vol:.2f}")

    # Perform boolean difference operations
    result = base_solid
    for i, cutter in enumerate(cutters, 1):
        print(f"Subtracting cutter {i}...")
        cut_op = BRepAlgoAPI_Cut(result, cutter)
        cut_op.Build()
        if not cut_op.IsDone():
            print(f"Warning: Boolean operation {i} failed!")
            continue
        result = cut_op.Shape()

    # Export result
    print(f"Writing {output_step}...")
    write_step_file(result, output_step)
    print("Done!")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} input.step output.step")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    if not Path(input_file).exists():
        print(f"Error: Input file '{input_file}' not found")
        sys.exit(1)

    compute_boolean_difference(input_file, output_file)
