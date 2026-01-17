#!/usr/bin/env python3
"""
Generate a STEP file with boolean difference operation using CadQuery.
Creates a cube with a cylindrical hole.

Requirements: pip install cadquery
"""

import cadquery as cq

def create_boolean_difference_step(filename="boolean_difference.step"):
    """
    Create a STEP file with a boolean difference operation.
    Creates a 100x100x100mm cube with a 30mm diameter cylinder subtracted through it.
    """

    print("Creating geometry with CadQuery...")

    # Create a cube and subtract a cylinder from its center
    result = (
        cq.Workplane("XY")
        .box(100, 100, 100)  # 100mm cube
        .faces(">Z")  # Select top face
        .workplane()
        .hole(30)  # 30mm diameter hole through the entire cube
    )

    # Export to STEP
    print(f"Writing to {filename}...")
    cq.exporters.export(result, filename)
    print(f"✓ Successfully wrote {filename}")
    print(f"\nFile ready! Import this into Plasticity or Onshape.")
    print(f"You should see a 100mm cube with a 30mm diameter hole through its center.")

def create_separate_solids_step(filename="two_solids.step"):
    """
    Create a STEP file with two separate solids for manual boolean operation.
    """

    print("\n" + "="*60)
    print("Creating version with separate solids...")
    print("="*60)

    # Create cube
    cube = cq.Workplane("XY").box(100, 100, 100)

    # Create cylinder (positioned to go through cube center)
    cylinder = (
        cq.Workplane("XY")
        .workplane(offset=-10)  # Start below the cube
        .circle(15)  # 15mm radius = 30mm diameter
        .extrude(120)  # Extend through the cube
    )

    # Combine both into an assembly
    assembly = cq.Assembly()
    assembly.add(cube, name="cube", color=cq.Color("lightblue"))
    assembly.add(cylinder, name="cylinder", color=cq.Color("red"))

    # Export assembly to STEP
    print(f"Writing to {filename}...")
    assembly.save(filename)
    print(f"✓ Successfully wrote {filename}")
    print(f"\nThis file contains two separate solids.")
    print(f"In Plasticity/Onshape, select both and perform a boolean difference.")

def create_complex_example(filename="complex_boolean.step"):
    """
    Create a more complex example with multiple boolean operations.
    """

    print("\n" + "="*60)
    print("Creating BONUS complex example...")
    print("="*60)

    result = (
        cq.Workplane("XY")
        .box(100, 100, 100)  # Base cube
        .faces(">Z").workplane()  # Top face
        .hole(30)  # Center hole
        .faces(">X").workplane()  # Side face
        .workplane(offset=-50)
        .circle(15)
        .extrude(100)  # Side hole
        .faces(">Y").workplane()  # Another side
        .workplane(offset=-50)
        .circle(15)
        .extrude(100)  # Another side hole
    )

    print(f"Writing to {filename}...")
    cq.exporters.export(result, filename)
    print(f"✓ Successfully wrote {filename}")
    print(f"This cube has three perpendicular holes through it!")

if __name__ == "__main__":
    print("STEP Boolean Difference Generator (CadQuery)")
    print("=" * 60)

    try:
        # Create version with boolean already performed
        create_boolean_difference_step("boolean_difference.step")

        # Create version with separate solids
        create_separate_solids_step("two_solids.step")

        # Create complex example
        create_complex_example("complex_boolean.step")

        print("\n" + "="*60)
        print("Done! Three files created:")
        print("  1. boolean_difference.step - Cube with one hole")
        print("  2. two_solids.step - Separate cube and cylinder")
        print("  3. complex_boolean.step - Cube with three holes")
        print("="*60)

    except Exception as e:
        print(f"\nERROR: {e}")
        print("\nMake sure CadQuery is installed:")
        print("  pip install cadquery")
