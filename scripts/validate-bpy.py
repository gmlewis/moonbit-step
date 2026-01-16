#!/usr/bin/env python3
"""Validate a Blender Python script by running Blender headlessly.

Example:
  ./scripts/validate-bpy.py path/to/script.py
  ./scripts/validate-bpy.py path/to/script.py --blend out.blend
"""

from __future__ import annotations

import argparse
import pathlib
import subprocess
import sys
from typing import List, Optional


def build_command(script: pathlib.Path, blend: Optional[pathlib.Path]) -> List[str]:
    cmd = [
        "blender",
        "--background",
        "--factory-startup",
        "--python",
        str(script),
    ]
    if blend is not None:
        expr = (
            "import bpy; "
            f"bpy.ops.wm.save_as_mainfile(filepath=r'{blend.as_posix()}')"
        )
        cmd.extend(["--python-expr", expr])
    return cmd


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run Blender headlessly to validate a Python script."
    )
    parser.add_argument("script", type=pathlib.Path, help="Blender Python script")
    parser.add_argument(
        "--blend",
        type=pathlib.Path,
        help="Output .blend file path to save after script runs",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=None,
        help="Optional timeout in seconds",
    )
    args = parser.parse_args()

    script = args.script
    if not script.exists():
        print(f"Script not found: {script}", file=sys.stderr)
        return 2

    cmd = build_command(script, args.blend)
    print("Running:", " ".join(cmd))

    try:
        result = subprocess.run(cmd, timeout=args.timeout)
    except FileNotFoundError:
        print("Blender not found in PATH (expected 'blender').", file=sys.stderr)
        return 127
    except subprocess.TimeoutExpired:
        print("Blender run timed out.", file=sys.stderr)
        return 124

    if result.returncode != 0:
        print(f"Blender exited with code {result.returncode}", file=sys.stderr)
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
