#!/usr/bin/env python3
"""Measure a STEP file's tessellation for distance and section comparison.

Development-time helper only. OCCT is used to tessellate; the resulting mesh is
parsed in pure Python and is never a runtime dependency of the component
library.

Usage:
    python3 scripts/measure_step_mesh.py file.step [--deflection 0.1] [--json]

The module also exposes:

    mesh_triangles(path, deflection) -> list[tuple[Vec3, Vec3, Vec3]]
    surface_deviation(a_path, b_path, deflection, samples) -> dict
    section_at(triangles, z) -> dict
"""

from __future__ import annotations

import argparse
import json
import math
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

Vec3 = tuple[float, float, float]
Tri = tuple[Vec3, Vec3, Vec3]


def find_draw() -> str | None:
    return shutil.which("occt-draw") or shutil.which("DRAWEXE")


def mesh_triangles(path: Path, deflection: float = 0.1) -> list[Tri]:
    """Tessellate a STEP file with OCCT and return ASCII-STL triangles."""
    tool = find_draw()
    if tool is None:
        raise RuntimeError("OCCT (occt-draw or DRAWEXE) is not installed")
    with tempfile.TemporaryDirectory(prefix="step-mesh-") as tmp:
        stl = Path(tmp) / "mesh.stl"
        step = str(path).replace('"', '\\"')
        out = str(stl).replace('"', '\\"')
        script = (
            "pload ALL; "
            f'testreadstep "{step}" a; '
            f"incmesh a {deflection}; "
            f'writestl a "{out}" 0'
        )
        proc = subprocess.run(
            [tool, "-b", "-c", script], capture_output=True, text=True, timeout=1800
        )
        if proc.returncode != 0:
            raise RuntimeError(proc.stdout + proc.stderr)
        text = stl.read_text(errors="replace")
    tris: list[Tri] = []
    cur: list[Vec3] = []
    for line in text.splitlines():
        parts = line.split()
        if len(parts) == 4 and parts[0].lower() == "vertex":
            cur.append((float(parts[1]), float(parts[2]), float(parts[3])))
            if len(cur) == 3:
                tris.append((cur[0], cur[1], cur[2]))
                cur = []
    return tris


def _sub(a: Vec3, b: Vec3) -> Vec3:
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _dot(a: Vec3, b: Vec3) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _dist_point_triangle(p: Vec3, tri: Tri) -> float:
    """Minimum distance from a point to a triangle (Ericson, RTCD)."""
    a, b, c = tri
    ab = _sub(b, a)
    ac = _sub(c, a)
    ap = _sub(p, a)
    d1 = _dot(ab, ap)
    d2 = _dot(ac, ap)
    if d1 <= 0.0 and d2 <= 0.0:
        return math.dist(p, a)
    bp = _sub(p, b)
    d3 = _dot(ab, bp)
    d4 = _dot(ac, bp)
    if d3 >= 0.0 and d4 <= d3:
        return math.dist(p, b)
    vc = d1 * d4 - d3 * d2
    if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
        v = d1 / (d1 - d3)
        return math.dist(p, (a[0] + v * ab[0], a[1] + v * ab[1], a[2] + v * ab[2]))
    cp = _sub(p, c)
    d5 = _dot(ab, cp)
    d6 = _dot(ac, cp)
    if d6 >= 0.0 and d5 <= d6:
        return math.dist(p, c)
    vb = d5 * d2 - d1 * d6
    if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
        w = d2 / (d2 - d6)
        return math.dist(p, (a[0] + w * ac[0], a[1] + w * ac[1], a[2] + w * ac[2]))
    va = d3 * d6 - d5 * d4
    if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
        w = (d4 - d3) / ((d4 - d3) + (d5 - d6))
        bc = _sub(c, b)
        return math.dist(p, (b[0] + w * bc[0], b[1] + w * bc[1], b[2] + w * bc[2]))
    denom = 1.0 / (va + vb + vc)
    v = vb * denom
    w = vc * denom
    q = (
        a[0] + ab[0] * v + ac[0] * w,
        a[1] + ab[1] * v + ac[1] * w,
        a[2] + ab[2] * v + ac[2] * w,
    )
    return math.dist(p, q)


def _grid(tris: list[Tri], cell: float) -> dict[tuple[int, int, int], list[Tri]]:
    grid: dict[tuple[int, int, int], list[Tri]] = {}
    for tri in tris:
        keys = set()
        for v in tri:
            keys.add(
                (math.floor(v[0] / cell), math.floor(v[1] / cell), math.floor(v[2] / cell))
            )
        for key in keys:
            grid.setdefault(key, []).append(tri)
    return grid


def _one_way(points: list[Vec3], tris: list[Tri], cell: float) -> tuple[float, float]:
    grid = _grid(tris, cell)
    worst = 0.0
    total = 0.0
    for p in points:
        key = (math.floor(p[0] / cell), math.floor(p[1] / cell), math.floor(p[2] / cell))
        candidates: list[Tri] = []
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    candidates.extend(grid.get((key[0] + dx, key[1] + dy, key[2] + dz), []))
        if not candidates:
            candidates = tris
        d = min(_dist_point_triangle(p, t) for t in candidates)
        worst = max(worst, d)
        total += d
    return worst, (total / len(points) if points else 0.0)


def surface_deviation(
    a_path: Path, b_path: Path, deflection: float = 0.1, samples: int = 4000
) -> dict:
    """Bidirectional sampled surface deviation (Hausdorff-like)."""
    a = mesh_triangles(a_path, deflection)
    b = mesh_triangles(b_path, deflection)
    if not a or not b:
        raise RuntimeError("empty tessellation")
    pa = [v for tri in a for v in tri]
    pb = [v for tri in b for v in tri]
    # Deterministic subsample of the vertex cloud.
    def sample(points: list[Vec3]) -> list[Vec3]:
        if len(points) <= samples:
            return points
        step = len(points) / samples
        return [points[int(i * step)] for i in range(samples)]

    pa_s, pb_s = sample(pa), sample(pb)
    # Cell size from the average triangle edge length, floored for stability.
    avg = 0.0
    for tri in a[:200]:
        avg += math.dist(tri[0], tri[1]) + math.dist(tri[1], tri[2])
    avg = max(avg / max(len(a[:200]) * 2, 1), 1e-3)
    cell = max(avg * 4.0, deflection)
    a_to_b_max, a_to_b_mean = _one_way(pa_s, b, cell)
    b_to_a_max, b_to_a_mean = _one_way(pb_s, a, cell)
    return {
        "triangles_a": len(a),
        "triangles_b": len(b),
        "a_to_b_max_mm": a_to_b_max,
        "a_to_b_mean_mm": a_to_b_mean,
        "b_to_a_max_mm": b_to_a_max,
        "b_to_a_mean_mm": b_to_a_mean,
        "max_mm": max(a_to_b_max, b_to_a_max),
        "mean_mm": max(a_to_b_mean, b_to_a_mean),
    }


def _segment_z(tri: Tri, z: float) -> tuple[tuple[float, float], tuple[float, float]] | None:
    pts: list[tuple[float, float]] = []
    for i in range(3):
        p, q = tri[i], tri[(i + 1) % 3]
        if (p[2] - z) * (q[2] - z) < 0.0:
            t = (z - p[2]) / (q[2] - p[2])
            pts.append((p[0] + t * (q[0] - p[0]), p[1] + t * (q[1] - p[1])))
        elif abs(p[2] - z) <= 1e-12:
            pts.append((p[0], p[1]))
    if len(pts) < 2:
        return None
    return (pts[0], pts[1])


def section_at(tris: list[Tri], z: float) -> dict:
    """Area, perimeter and extents of the cross-section at plane z."""
    segs = [s for s in (_segment_z(t, z) for t in tris) if s is not None]
    area = 0.0
    perimeter = 0.0
    xs: list[float] = []
    ys: list[float] = []
    for (x0, y0), (x1, y1) in segs:
        area += 0.5 * (x0 * y1 - x1 * y0)
        perimeter += math.hypot(x1 - x0, y1 - y0)
        xs += [x0, x1]
        ys += [y0, y1]
    return {
        "z_mm": z,
        "segments": len(segs),
        "area_mm2": abs(area),
        "perimeter_mm": perimeter,
        "x_extent_mm": (max(xs) - min(xs)) if xs else 0.0,
        "y_extent_mm": (max(ys) - min(ys)) if ys else 0.0,
    }


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("files", nargs="+")
    ap.add_argument("--deflection", type=float, default=0.1)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    results = []
    for p in args.files:
        tris = mesh_triangles(Path(p), args.deflection)
        results.append({"path": p, "triangles": len(tris)})
    if args.json:
        print(json.dumps(results, indent=2))
    else:
        for r in results:
            print(f"{r['path']}: {r['triangles']} triangles")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
