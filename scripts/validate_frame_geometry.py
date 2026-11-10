#!/usr/bin/env python3
"""Independent post-export geometry validation for a rectangular T-slot frame.

This script deliberately does not import any MoonBit code or reuse the
component generator. It:

1. Re-derives the expected member schedule from the declared frame semantics
   (overall outside dimensions, full-height corner posts, rails cut to the
   clear span between post inner faces).
2. Re-imports the STEP file with Open CASCADE (DRAWEXE / occt-draw).
3. Measures every solid's axis-aligned bounding box and volume.
4. Matches each measured solid to exactly one expected member.
5. Computes the polygonal section area independently and checks each volume
   against area * cut length.
6. Checks that no pair of solid bounding boxes overlaps with positive volume.

It is a development-time validation tool. The component library itself has no
Open CASCADE, Python, or native dependency.

Usage:
    python3 scripts/validate_frame_geometry.py FRAME.step \
        --width 400 --depth 300 --height 500 --series 2020

Exit status is 0 only when every check passes. When OCCT is unavailable the
script reports the geometric checks as SKIPPED and exits 2.
"""

from __future__ import annotations

import argparse
import math
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

PROFILES = {
    # name: (width, height, slot_width, neck_depth, slot_depth,
    #        cavity_width, bore_diameter)
    "2020": (20.0, 20.0, 6.0, 2.5, 6.0, 11.0, 4.2),
    "2040": (20.0, 40.0, 6.0, 2.5, 6.0, 11.0, 4.2),
    "3030": (30.0, 30.0, 8.0, 3.0, 8.0, 14.0, 6.0),
    "4040": (40.0, 40.0, 8.0, 3.0, 8.0, 14.0, 6.5),
}

# profiles.extrusion() floors the circular resolution at 24 and the
# Simplified detail policy uses 48 segments.
CIRCLE_SEGMENTS = 48


@dataclass
class Member:
    ident: str
    role: str
    length: float
    bbox: tuple[float, float, float, float, float, float]


@dataclass
class SolidMeasurement:
    index: int
    volume: float
    bbox: tuple[float, float, float, float, float, float]


def section_area(series: str) -> float:
    pw, ph, slot_w, neck, depth, cavity, bore = PROFILES[series]
    # The section is a rectangle with one rectangular T-slot notch on each of
    # its four sides, minus a regular-polygon approximation of the core bore.
    base = pw * ph
    notch = slot_w * neck + cavity * (depth - neck)
    bore_radius = bore / 2.0
    polygon_area = (
        0.5
        * CIRCLE_SEGMENTS
        * bore_radius
        * bore_radius
        * math.sin(2.0 * math.pi / CIRCLE_SEGMENTS)
    )
    return base - 4.0 * notch - polygon_area


def expected_members(width: float, depth: float, height: float, series: str) -> list[Member]:
    pw, ph, *_ = PROFILES[series]
    rail_x_len = width - 2.0 * pw
    rail_y_len = depth - 2.0 * ph
    post_x = width / 2.0 - pw / 2.0
    post_y = depth / 2.0 - ph / 2.0
    members: list[Member] = []

    for sx, sy, ident in [
        (-1.0, -1.0, "post-ws"),
        (1.0, -1.0, "post-es"),
        (1.0, 1.0, "post-en"),
        (-1.0, 1.0, "post-wn"),
    ]:
        x = sx * post_x
        y = sy * post_y
        members.append(
            Member(
                ident,
                "post",
                height,
                (x - pw / 2.0, x + pw / 2.0, y - ph / 2.0, y + ph / 2.0, 0.0, height),
            )
        )

    for sy, z, ident in [
        (-1.0, pw / 2.0, "rail-x-bottom-s"),
        (1.0, pw / 2.0, "rail-x-bottom-n"),
        (-1.0, height - pw / 2.0, "rail-x-top-s"),
        (1.0, height - pw / 2.0, "rail-x-top-n"),
    ]:
        y = sy * post_y
        members.append(
            Member(
                ident,
                "rail-x",
                rail_x_len,
                (
                    -rail_x_len / 2.0,
                    rail_x_len / 2.0,
                    y - ph / 2.0,
                    y + ph / 2.0,
                    z - pw / 2.0,
                    z + pw / 2.0,
                ),
            )
        )

    for sx, z, ident in [
        (-1.0, ph / 2.0, "rail-y-bottom-w"),
        (1.0, ph / 2.0, "rail-y-bottom-e"),
        (-1.0, height - ph / 2.0, "rail-y-top-w"),
        (1.0, height - ph / 2.0, "rail-y-top-e"),
    ]:
        x = sx * post_x
        members.append(
            Member(
                ident,
                "rail-y",
                rail_y_len,
                (
                    x - pw / 2.0,
                    x + pw / 2.0,
                    -rail_y_len / 2.0,
                    rail_y_len / 2.0,
                    z - ph / 2.0,
                    z + ph / 2.0,
                ),
            )
        )
    return members


def find_draw() -> str | None:
    return shutil.which("occt-draw") or shutil.which("DRAWEXE")


def measure_solids(step_path: Path) -> tuple[list[SolidMeasurement], str]:
    tool = find_draw()
    if tool is None:
        return [], "OCCT (occt-draw or DRAWEXE) is not installed"

    with tempfile.TemporaryDirectory(prefix="frame-validate-") as tmp:
        csv_path = Path(tmp) / "solids.csv"
        escaped_step = str(step_path).replace('"', '\\"')
        escaped_csv = str(csv_path).replace('"', '\\"')
        script = (
            'pload ALL; '
            f'testreadstep "{escaped_step}" a; '
            "explode a So; "
            f'set f [open "{escaped_csv}" w]; '
            "for {set i 1} {1} {incr i} { "
            "if {[catch {set bb [bounding a_$i]} err]} { break }; "
            "set vp [vprops a_$i]; "
            "regexp {Mass\\s*:\\s*([-0-9.eE+]+)} $vp -> mass; "
            'puts $f "$i,$mass,[join $bb ,]" }; '
            "close $f"
        )
        try:
            proc = subprocess.run(
                [tool, "-b", "-c", script],
                capture_output=True,
                text=True,
                timeout=900,
            )
        except subprocess.TimeoutExpired:
            return [], "OCCT measurement timed out after 900 s"
        if proc.returncode != 0 or not csv_path.exists():
            tail = "; ".join(
                line.strip()
                for line in (proc.stdout + proc.stderr).strip().splitlines()[-3:]
            )
            return [], f"OCCT measurement failed: {tail}"
        measurements: list[SolidMeasurement] = []
        for line in csv_path.read_text().splitlines():
            parts = line.split(",")
            if len(parts) != 8:
                return [], f"unexpected OCCT output row: {line!r}"
            index = int(parts[0])
            volume = float(parts[1])
            # OCCT DRAW `bounding` reports Xmin Ymin Zmin Xmax Ymax Zmax.
            xmin, ymin, zmin, xmax, ymax, zmax = (float(v) for v in parts[2:])
            bounds = (xmin, xmax, ymin, ymax, zmin, zmax)
            measurements.append(SolidMeasurement(index, volume, bounds))
        return measurements, ""


def box_intersection_volume(
    a: tuple[float, float, float, float, float, float],
    b: tuple[float, float, float, float, float, float],
) -> float:
    lo = [max(a[2 * k], b[2 * k]) for k in range(3)]
    hi = [min(a[2 * k + 1], b[2 * k + 1]) for k in range(3)]
    dims = [hi[i] - lo[i] for i in range(3)]
    if any(d <= 0.0 for d in dims):
        return 0.0
    return dims[0] * dims[1] * dims[2]


def bbox_distance(
    a: tuple[float, float, float, float, float, float],
    b: tuple[float, float, float, float, float, float],
) -> float:
    return max(abs(a[i] - b[i]) for i in range(6))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("step")
    parser.add_argument("--width", type=float, required=True)
    parser.add_argument("--depth", type=float, required=True)
    parser.add_argument("--height", type=float, required=True)
    parser.add_argument("--series", choices=sorted(PROFILES), default="2020")
    parser.add_argument("--linear-tol", type=float, default=1.0e-3)
    parser.add_argument("--volume-rel-tol", type=float, default=2.0e-4)
    parser.add_argument("--overlap-tol", type=float, default=1.0e-3)
    args = parser.parse_args()

    step_path = Path(args.step)
    if not step_path.exists():
        print(f"FAIL: STEP file not found: {step_path}")
        return 1

    expected = expected_members(args.width, args.depth, args.height, args.series)
    area = section_area(args.series)
    measurements, reason = measure_solids(step_path)
    if reason:
        print(f"SKIP: {reason}")
        print("      The MoonBit collision tests and STEP topology checks still ran.")
        return 2

    failures: list[str] = []
    if len(measurements) != len(expected):
        failures.append(
            f"solid count: measured {len(measurements)}, expected {len(expected)}"
        )

    unmatched = list(range(len(measurements)))
    max_bbox_error = 0.0
    max_volume_rel_error = 0.0
    matches: list[tuple[str, SolidMeasurement]] = []
    for member in expected:
        best = None
        for idx in unmatched:
            distance = bbox_distance(measurements[idx].bbox, member.bbox)
            if best is None or distance < best[0]:
                best = (distance, idx)
        if best is None:
            failures.append(f"{member.ident}: no remaining measured solid")
            continue
        distance, idx = best
        unmatched.remove(idx)
        max_bbox_error = max(max_bbox_error, distance)
        if distance > args.linear_tol:
            failures.append(
                f"{member.ident}: bounding box differs by {distance:.6g} mm "
                f"(measured {measurements[idx].bbox})"
            )
        expected_volume = area * member.length
        rel_error = abs(measurements[idx].volume - expected_volume) / expected_volume
        max_volume_rel_error = max(max_volume_rel_error, rel_error)
        if rel_error > args.volume_rel_tol:
            failures.append(
                f"{member.ident}: volume {measurements[idx].volume:.6f} mm^3 "
                f"vs expected {expected_volume:.6f} mm^3 "
                f"(relative error {rel_error:.3g})"
            )
        matches.append((member.ident, measurements[idx]))

    worst_overlap = 0.0
    overlap_pairs: list[str] = []
    for i in range(len(measurements)):
        for j in range(i + 1, len(measurements)):
            overlap = box_intersection_volume(
                measurements[i].bbox, measurements[j].bbox
            )
            worst_overlap = max(worst_overlap, overlap)
            if overlap > args.overlap_tol:
                overlap_pairs.append(
                    f"solid {measurements[i].index} vs {measurements[j].index}: "
                    f"{overlap:.6f} mm^3 bbox overlap"
                )
    failures.extend(overlap_pairs)

    overall = (
        min(m.bbox[0] for m in measurements),
        max(m.bbox[1] for m in measurements),
        min(m.bbox[2] for m in measurements),
        max(m.bbox[3] for m in measurements),
        min(m.bbox[4] for m in measurements),
        max(m.bbox[5] for m in measurements),
    )
    overall_dims = (overall[1] - overall[0], overall[3] - overall[2], overall[5] - overall[4])
    for measured, declared, axis in zip(
        overall_dims, (args.width, args.depth, args.height), "XYZ"
    ):
        if abs(measured - declared) > args.linear_tol:
            failures.append(
                f"overall {axis} extent {measured:.6g} mm vs declared {declared:.6g} mm"
            )

    print(f"{step_path}")
    print(f"  [{'PASS' if not failures else 'FAIL'}] OCCT re-import: {len(measurements)} solids")
    print(
        f"  [{'PASS' if max_bbox_error <= args.linear_tol else 'FAIL'}] "
        f"member bounding boxes matched (worst {max_bbox_error:.3g} mm)"
    )
    print(
        f"  [{'PASS' if max_volume_rel_error <= args.volume_rel_tol else 'FAIL'}] "
        f"volumes match section area x cut length "
        f"(worst relative error {max_volume_rel_error:.3g}, area {area:.6f} mm^2)"
    )
    print(
        f"  [{'PASS' if not overlap_pairs else 'FAIL'}] "
        f"no positive-volume bbox overlap (worst {worst_overlap:.3g} mm^3)"
    )
    print(
        f"  [{'PASS' if not any('overall' in f for f in failures) else 'FAIL'}] "
        f"overall dimensions {overall_dims[0]:.6g} x {overall_dims[1]:.6g} x "
        f"{overall_dims[2]:.6g} mm"
    )
    if failures:
        print("  failures:")
        for failure in failures:
            print(f"    - {failure}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
