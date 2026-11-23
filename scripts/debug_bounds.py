#!/usr/bin/env python3
"""Debug script to check solid bounding boxes in STEP file.

CadQuery is optional; import it only when the script is actually run, so that
importing this module (or running a linter over it) does not require it.
"""

from __future__ import annotations

import sys


def main(argv: list[str] | None = None) -> int:
    argv = sys.argv if argv is None else argv
    if len(argv) != 2:
        print(f"Usage: {argv[0]} file.step", file=sys.stderr)
        return 1

    try:
        import cadquery as cq
    except ImportError:
        print(
            "error: cadquery is not installed; this debug script needs it to "
            "read STEP solids",
            file=sys.stderr,
        )
        return 1

    filename = argv[1]
    print(f"Reading {filename}...")

    imported = cq.importers.importStep(filename)
    all_solids = imported.solids().vals()

    print(f"\nFound {len(all_solids)} solid(s):\n")

    for i, solid in enumerate(all_solids):
        bb = solid.BoundingBox()
        vol = solid.Volume()
        print(f"Solid {i + 1}:")
        print(f"  Volume: {vol:.2f}")
        print(f"  X: [{bb.xmin:.2f}, {bb.xmax:.2f}]")
        print(f"  Y: [{bb.ymin:.2f}, {bb.ymax:.2f}]")
        print(f"  Z: [{bb.zmin:.2f}, {bb.zmax:.2f}]")
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
