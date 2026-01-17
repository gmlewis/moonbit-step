#!/usr/bin/env python3
"""
Use Blender to compute boolean difference from STEP file.

Usage:
    blender --background --python compute_booleans_blender.py -- input.step output.step

Or:
    ./scripts/compute_booleans_blender.py input.step output.step
"""

import sys
import bpy
from pathlib import Path


def compute_boolean_difference(input_step: str, output_step: str) -> None:
    """Import STEP, compute boolean, export result."""
    print(f"Reading {input_step}...")

    # Clear default scene
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

    # Import STEP
    bpy.ops.import_mesh.stl(filepath=input_step)  # Blender uses different importer
    # Actually, for STEP we need:
    bpy.ops.wm.step_import(filepath=input_step)

    objects = list(bpy.context.scene.objects)
    print(f"Imported {len(objects)} object(s)")

    if len(objects) < 2:
        print("Error: Need at least 2 objects")
        sys.exit(1)

    # Sort by volume (largest is base)
    def get_volume(obj):
        if obj.type != 'MESH':
            return 0
        return obj.dimensions.x * obj.dimensions.y * obj.dimensions.z

    objects.sort(key=get_volume, reverse=True)

    base = objects[0]
    cutters = objects[1:]

    print(f"Base: {base.name}")
    for i, cutter in enumerate(cutters, 1):
        print(f"Cutter {i}: {cutter.name}")

    # Apply boolean modifiers
    for cutter in cutters:
        mod = base.modifiers.new(name="Boolean", type='BOOLEAN')
        mod.operation = 'DIFFERENCE'
        mod.object = cutter
        mod.solver = 'FAST'  # or 'EXACT'

    # Apply all modifiers
    bpy.context.view_layer.objects.active = base
    for mod in base.modifiers:
        bpy.ops.object.modifier_apply(modifier=mod.name)

    # Delete cutters
    for cutter in cutters:
        bpy.data.objects.remove(cutter, do_unlink=True)

    # Export
    print(f"Writing {output_step}...")
    bpy.ops.wm.step_export(filepath=output_step)
    print("Done!")


if __name__ == "__main__":
    # When run from command line
    if "--" in sys.argv:
        args = sys.argv[sys.argv.index("--") + 1:]
    else:
        args = sys.argv[1:]

    if len(args) != 2:
        print(f"Usage: blender --background --python {sys.argv[0]} -- input.step output.step")
        sys.exit(1)

    compute_boolean_difference(args[0], args[1])
