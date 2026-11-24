#!/usr/bin/env python3
"""Render a STEP file to a four-view PNG preview.

Prefers headless `solidcraft-cli snapshot` (checking `~/tools/bin` first, then
`$PATH`) + `vectorcraft-cli` for fast cross-platform GPU rendering on macOS and
Linux. Falls back to OCCT `DRAWEXE`/`occt-draw` and Inkscape when unavailable.

Usage:
    python3 scripts/render_step.py model.step preview.png
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

_scripts_dir = Path(__file__).resolve().parent
if str(_scripts_dir) not in sys.path:
    sys.path.insert(0, str(_scripts_dir))

from manage_examples import (  # noqa: E402
    VIEWS,
    composite_views,
    find_occt,
    render_view,
)

SC_VIEWS = [
    ("iso", "iso"),
    ("top", "top"),
    ("front", "front"),
    ("side", "right"),
]


def _find_tool(name: str) -> str | None:
    home_bin = Path.home() / "tools" / "bin" / name
    if home_bin.is_file() and os.access(home_bin, os.X_OK):
        return str(home_bin)
    return shutil.which(name)


def _render_view_solidcraft(
    sc: str, step_path: Path, png_path: Path, view: str
) -> bool:
    proc = subprocess.run(
        [
            sc,
            "snapshot",
            str(step_path.resolve()),
            "--out",
            str(png_path),
            "--view",
            view,
            "--width",
            "800",
            "--height",
            "800",
            "--no-grid",
            "--no-axes",
        ],
        capture_output=True,
        text=True,
        timeout=120,
    )
    return proc.returncode == 0 and png_path.is_file() and png_path.stat().st_size > 0


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

    sc = _find_tool("solidcraft-cli")
    occt = None if sc else find_occt()
    if not sc and not occt:
        print(
            "Error: neither solidcraft-cli nor occt-draw/DRAWEXE found "
            "(checked ~/tools/bin and PATH).",
            file=sys.stderr,
        )
        return 1

    with tempfile.TemporaryDirectory() as tmpdir:
        views: dict[str, str] = {}
        if sc:
            for suffix, sc_view in SC_VIEWS:
                png_path = Path(tmpdir) / f"{suffix}.png"
                if not _render_view_solidcraft(sc, step_path, png_path, sc_view):
                    print(
                        f"Error: solidcraft-cli failed to render {suffix} view.",
                        file=sys.stderr,
                    )
                    return 1
                views[suffix] = str(png_path)
        else:
            for suffix, view_cmd in VIEWS:
                png_path = Path(tmpdir) / f"{suffix}.png"
                if not render_view(occt, step_path, png_path, view_cmd):
                    print(
                        f"Error: failed to render the {suffix} view.",
                        file=sys.stderr,
                    )
                    return 1
                views[suffix] = str(png_path)

        compositor = _find_tool("vectorcraft-cli") or shutil.which("inkscape")
        if compositor and composite_views(compositor, views, out_path):
            return 0

        shutil.copyfile(views["iso"], out_path)
        if compositor:
            print(
                "Note: compositing failed; wrote the isometric view only.",
                file=sys.stderr,
            )
        else:
            print(
                "Note: neither vectorcraft-cli nor Inkscape found; wrote the isometric view only.",
                file=sys.stderr,
            )
        return 0


if __name__ == "__main__":
    sys.exit(main())
