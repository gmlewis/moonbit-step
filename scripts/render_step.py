#!/usr/bin/env python3
"""Render a STEP file to a four-view PNG preview.

This is the single-file companion to `scripts/manage_examples.py --render`.
It uses the same OCCT DRAWEXE views (isometric, top, front, side) followed by
Inkscape compositing. When Inkscape is unavailable it falls back to the
isometric view alone.

Requires OCCT (`occt-draw` or `DRAWEXE`) and macOS `sips` for PPM -> PNG
conversion; compositing also needs Inkscape.

Usage:
    python3 scripts/render_step.py model.step preview.png
"""

from __future__ import annotations

import argparse
import shutil
import sys
import tempfile
from pathlib import Path

_scripts_dir = Path(__file__).resolve().parent
if str(_scripts_dir) not in sys.path:
    sys.path.insert(0, str(_scripts_dir))

from manage_examples import composite_views, find_occt, render_view  # noqa: E402

VIEWS = [
    ("iso", "vviewparams -proj 1 -1 1 -up 0 0 1"),
    ("top", "vtop"),
    ("front", "vfront"),
    ("side", "vleft"),
]


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Render a STEP file to a PNG preview.",
    )
    parser.add_argument("step", help="input STEP file")
    parser.add_argument("png", help="output PNG file")
    args = parser.parse_args()

    step_path = Path(args.step)
    if not step_path.is_file():
        print(f"Error: STEP file not found: {step_path}", file=sys.stderr)
        return 1

    out_path = Path(args.png)
    if not out_path.parent.is_dir():
        print(
            f"Error: output directory does not exist: {out_path.parent}",
            file=sys.stderr,
        )
        return 1

    occt = find_occt()
    if not occt:
        print(
            "Error: neither occt-draw nor DRAWEXE is on PATH. "
            "Install OpenCASCADE to render previews.",
            file=sys.stderr,
        )
        return 1

    with tempfile.TemporaryDirectory() as tmpdir:
        views: dict[str, str] = {}
        for suffix, view_cmd in VIEWS:
            png_path = Path(tmpdir) / f"{suffix}.png"
            if not render_view(occt, step_path, png_path, view_cmd):
                print(f"Error: failed to render the {suffix} view.", file=sys.stderr)
                return 1
            views[suffix] = str(png_path)

        inkscape = shutil.which("inkscape")
        if inkscape and composite_views(inkscape, views, out_path):
            return 0

        # No compositor: still produce a useful preview.
        shutil.copyfile(views["iso"], out_path)
        if inkscape:
            print(
                "Note: compositing failed; wrote the isometric view only.",
                file=sys.stderr,
            )
        else:
            print(
                "Note: Inkscape not found; wrote the isometric view only.",
                file=sys.stderr,
            )
        return 0


if __name__ == "__main__":
    sys.exit(main())
