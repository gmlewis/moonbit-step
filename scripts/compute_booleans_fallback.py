#!/usr/bin/env python3
"""
Fallback: Post-process STEP files using CadQuery with manual transform parsing.

Usage:
    ./scripts/compute_booleans_fallback.py input.step output.step
"""

import sys
import re
from pathlib import Path
import cadquery as cq


def parse_step_transforms(step_file):
    """Parse STEP file to extract product names and their transforms."""
    with open(step_file, 'r') as f:
        content = f.read()

    # Find AXIS2_PLACEMENT_3D entities
    axis_pattern = r'#(\d+)=AXIS2_PLACEMENT_3D\([^,]*,#(\d+),#(\d+),#(\d+)\)'
    cartesian_pattern = r'#(\d+)=CARTESIAN_POINT\([^,]*,\(([^)]+)\)\)'
    direction_pattern = r'#(\d+)=DIRECTION\([^,]*,\(([^)]+)\)\)'

    axis_placements = {}
    cartesian_points = {}
    directions = {}

    for match in re.finditer(axis_pattern, content):
        axis_id = match.group(1)
        point_ref = match.group(2)
        dir1_ref = match.group(3)
        dir2_ref = match.group(4)
        axis_placements[axis_id] = (point_ref, dir1_ref, dir2_ref)

    for match in re.finditer(cartesian_pattern, content):
        point_id = match.group(1)
        coords = [float(x.strip()) for x in match.group(2).split(',')]
        cartesian_points[point_id] = coords

    for match in re.finditer(direction_pattern, content):
        dir_id = match.group(1)
        coords = [float(x.strip()) for x in match.group(2).split(',')]
        directions[dir_id] = coords

    # Find ADVANCED_BREP_SHAPE_REPRESENTATION with transforms
    brep_pattern = r'#(\d+)=ADVANCED_BREP_SHAPE_REPRESENTATION\([^,]*,\(#(\d+),#\d+\)'

    transforms = []
    for match in re.finditer(brep_pattern, content):
        axis_ref = match.group(2)
        if axis_ref in axis_placements:
            point_ref, dir1_ref, dir2_ref = axis_placements[axis_ref]
            if point_ref in cartesian_points:
                origin = cartesian_points[point_ref]
                transforms.append(origin)

    return transforms


def compute_boolean_difference(input_step: str, output_step: str) -> None:
    """
    Read STEP with separate solids, parse transforms, apply them, then boolean.
    """
    print(f"Reading {input_step}...")

    # Parse transforms from STEP file
    transforms = parse_step_transforms(input_step)
    print(f"Found {len(transforms)} transforms")

    # Import geometry (without transforms)
    imported = cq.importers.importStep(input_step)
    all_solids = imported.solids().vals()

    print(f"Found {len(all_solids)} solid(s)")

    if len(all_solids) < 2:
        print("Warning: Need at least 2 solids")
        imported.val().exportStep(output_step)
        return

    # Apply transforms to solids
    transformed_solids = []
    for i, solid in enumerate(all_solids):
        if i < len(transforms):
            tx, ty, tz = transforms[i]
            # Create workplane and move solid
            wp = cq.Workplane("XY").add(solid)
            wp = wp.translate((tx, ty, tz))
            transformed_solids.append(wp.val())
        else:
            transformed_solids.append(solid)

    # Use volume heuristic for base vs cutters
    solids_with_volume = [(s, s.Volume()) for s in transformed_solids]
    solids_with_volume.sort(key=lambda x: x[1], reverse=True)

    base_solid = solids_with_volume[0][0]
    cutters = [s for s, v in solids_with_volume[1:]]

    print(f"Base volume: {solids_with_volume[0][1]:.2f}")
    for i, (s, v) in enumerate(solids_with_volume[1:], 1):
        print(f"Cutter {i} volume: {v:.2f}")

    # Perform boolean
    result = cq.Workplane("XY").add(base_solid)
    for i, cutter in enumerate(cutters, 1):
        print(f"Subtracting cutter {i}...")
        result = result.cut(cq.Workplane("XY").add(cutter))

    # Export
    print(f"Writing {output_step}...")
    result.val().exportStep(output_step)
    print("Done!")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} input.step output.step")
        sys.exit(1)

    compute_boolean_difference(sys.argv[1], sys.argv[2])
