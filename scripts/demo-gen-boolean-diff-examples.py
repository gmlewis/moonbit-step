#!/usr/bin/env python3
"""
Generate a STEP file with two solids for boolean difference operation.
Creates a cube with a cylindrical hole to be subtracted.

Requirements: pip install OCC-Core
(Open CASCADE Technology Python bindings)
"""

from OCC.Core.BRepPrimAPI import BRepPrimAPI_MakeBox, BRepPrimAPI_MakeCylinder
from OCC.Core.BRepAlgoAPI import BRepAlgoAPI_Cut
from OCC.Core.gp import gp_Ax2, gp_Pnt, gp_Dir
from OCC.Core.STEPControl import STEPControl_Writer, STEPControl_AsIs
from OCC.Core.IFSelect import IFSelect_RetDone
from OCC.Core.BRepCheck import BRepCheck_Analyzer

def validate_solid(solid, name):
    """Validate that a solid is topologically correct."""
    analyzer = BRepCheck_Analyzer(solid)
    if not analyzer.IsValid():
        print(f"WARNING: {name} is not valid!")
        return False
    print(f"✓ {name} is valid")
    return True

def create_boolean_difference_step(filename="boolean_difference.step"):
    """
    Create a STEP file with a boolean difference operation.
    Creates a 100x100x100mm cube with a 30mm diameter cylinder subtracted through it.
    """

    print("Creating geometry...")

    # Create the base cube (100mm x 100mm x 100mm)
    box = BRepPrimAPI_MakeBox(100.0, 100.0, 100.0).Shape()
    validate_solid(box, "Base cube")

    # Create cylinder to subtract (diameter 30mm, height 120mm to ensure it cuts through)
    # Position it at the center of the cube, oriented along Z-axis
    cylinder_axis = gp_Ax2(
        gp_Pnt(50.0, 50.0, -10.0),  # Start below the cube
        gp_Dir(0, 0, 1)              # Point upward (Z direction)
    )
    cylinder = BRepPrimAPI_MakeCylinder(cylinder_axis, 15.0, 120.0).Shape()
    validate_solid(cylinder, "Cylinder tool")

    # Perform boolean difference (cut)
    print("\nPerforming boolean difference...")
    cut_operation = BRepAlgoAPI_Cut(box, cylinder)
    cut_operation.Build()

    if not cut_operation.IsDone():
        print("ERROR: Boolean operation failed!")
        return False

    result = cut_operation.Shape()
    validate_solid(result, "Result solid")

    # Write to STEP file
    print(f"\nWriting to {filename}...")
    step_writer = STEPControl_Writer()
    step_writer.Transfer(result, STEPControl_AsIs)

    status = step_writer.Write(filename)

    if status == IFSelect_RetDone:
        print(f"✓ Successfully wrote {filename}")
        print(f"\nFile ready! Import this into Plasticity or Onshape.")
        print(f"You should see a 100mm cube with a 30mm diameter hole through its center.")
        return True
    else:
        print(f"ERROR: Failed to write STEP file (status: {status})")
        return False

def create_separate_solids_step(filename="two_solids.step"):
    """
    Alternative: Create a STEP file with two separate solids (not pre-booleaned).
    You can perform the boolean operation in Plasticity/Onshape manually.
    """

    print("\n" + "="*60)
    print("Creating ALTERNATIVE version with separate solids...")
    print("="*60)

    # Create the base cube
    box = BRepPrimAPI_MakeBox(100.0, 100.0, 100.0).Shape()

    # Create cylinder
    cylinder_axis = gp_Ax2(
        gp_Pnt(50.0, 50.0, -10.0),
        gp_Dir(0, 0, 1)
    )
    cylinder = BRepPrimAPI_MakeCylinder(cylinder_axis, 15.0, 120.0).Shape()

    # Write both shapes to STEP file
    print(f"Writing to {filename}...")
    step_writer = STEPControl_Writer()
    step_writer.Transfer(box, STEPControl_AsIs)
    step_writer.Transfer(cylinder, STEPControl_AsIs)

    status = step_writer.Write(filename)

    if status == IFSelect_RetDone:
        print(f"✓ Successfully wrote {filename}")
        print(f"\nThis file contains two separate solids.")
        print(f"In Plasticity/Onshape, select both and perform a boolean difference.")
        return True
    else:
        print(f"ERROR: Failed to write STEP file")
        return False

if __name__ == "__main__":
    print("STEP Boolean Difference Generator")
    print("=" * 60)

    # Create version with boolean already performed
    create_boolean_difference_step("boolean_difference.step")

    # Create version with separate solids for manual boolean
    create_separate_solids_step("two_solids.step")

    print("\n" + "="*60)
    print("Done! Two files created:")
    print("  1. boolean_difference.step - Result of cube - cylinder")
    print("  2. two_solids.step - Separate cube and cylinder")
    print("="*60)
