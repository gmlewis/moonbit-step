#!/usr/bin/env python3
"""Measure a STEP file with Open CASCADE and print JSON.

Development-time helper for golden-reference comparison. The component library
does not depend on OCCT.

Usage:
    python3 scripts/measure_step_occt.py file.step [file.step ...]

Output (one JSON object per file):
    {"path": ..., "solids": N, "bbox": [xmin,xmax,ymin,ymax,zmin,zmax],
     "volume": V, "solid_bboxes": [...], "solid_volumes": [...]}

Exits 2 when OCCT is unavailable.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def find_draw() -> str | None:
    return shutil.which("occt-draw") or shutil.which("DRAWEXE")


def measure(path: Path) -> dict:
    tool = find_draw()
    if tool is None:
        raise RuntimeError("OCCT (occt-draw or DRAWEXE) is not installed")
    with tempfile.TemporaryDirectory(prefix="step-measure-") as tmp:
        csv_path = Path(tmp) / "solids.csv"
        step_escaped = str(path).replace('"', '\\"')
        csv_escaped = str(csv_path).replace('"', '\\"')
        script = (
            "pload ALL; "
            f'testreadstep "{step_escaped}" a; '
            "puts [nbshapes a]; "
            "puts [bounding a]; "
            "explode a So; "
            f'set f [open "{csv_escaped}" w]; '
            "set n 0; "
            "for {set i 1} {1} {incr i} { "
            "if {[catch {set bb [bounding a_$i]} err]} { break }; "
            "set vp [vprops a_$i]; "
            "regexp {Mass\\s*:\\s*([-0-9.eE+]+)} $vp -> mass; "
            'puts $f "$i,$mass,[join $bb ,]"; '
            "incr n }; "
            "if {$n == 0} { "
            "set vp [vprops a]; "
            "regexp {Mass\\s*:\\s*([-0-9.eE+]+)} $vp -> mass; "
            'puts $f "1,$mass,[join [bounding a] ,]" }; '
            "close $f"
        )
        proc = subprocess.run(
            [tool, "-b", "-c", script],
            capture_output=True,
            text=True,
            timeout=1800,
        )
        if proc.returncode != 0:
            raise RuntimeError(proc.stdout + proc.stderr)

        solids = 0
        for line in proc.stdout.splitlines():
            if "SOLID" in line and "COMPSOLID" not in line and ":" in line:
                try:
                    solids = int(line.split(":")[1].strip())
                except ValueError:
                    pass
        overall = None
        for line in proc.stdout.splitlines():
            parts = line.split()
            if len(parts) == 6:
                try:
                    overall = [float(p) for p in parts]
                except ValueError:
                    continue
        # DRAW prints bbox as Xmin Ymin Zmin Xmax Ymax Zmax.
        if overall is None:
            raise RuntimeError("could not parse overall bounding box")
        xmin, ymin, zmin, xmax, ymax, zmax = overall

        solid_bboxes: list[list[float]] = []
        solid_volumes: list[float] = []
        if csv_path.exists():
            for row in csv_path.read_text().splitlines():
                cols = row.split(",")
                if len(cols) != 8:
                    continue
                solid_volumes.append(float(cols[1]))
                x0, y0, z0, x1, y1, z1 = (float(v) for v in cols[2:])
                solid_bboxes.append([x0, x1, y0, y1, z0, z1])

        return {
            "path": str(path),
            "solids": solids,
            "bbox": [xmin, xmax, ymin, ymax, zmin, zmax],
            "volume": sum(solid_volumes) if solid_volumes else None,
            "solid_bboxes": solid_bboxes,
            "solid_volumes": solid_volumes,
        }


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    if find_draw() is None:
        print("SKIP: OCCT (occt-draw or DRAWEXE) is not installed", file=sys.stderr)
        return 2
    for arg in sys.argv[1:]:
        path = Path(arg)
        if not path.exists():
            print(json.dumps({"path": str(path), "error": "file not found"}))
            continue
        try:
            print(json.dumps(measure(path)))
        except Exception as exc:  # noqa: BLE001 - development helper
            print(json.dumps({"path": str(path), "error": str(exc)}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
