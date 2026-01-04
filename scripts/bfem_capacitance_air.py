#!/usr/bin/env python3
"""Air-only *ballpark* effective capacitance estimate for BFEM.

This script is a pragmatic first step toward SRF estimation before you have a full
capacitance solver workflow wired up.

Model (very approximate)
- Treat the full conductor as a polyline (from `--export_conductor_network`).
- Consider pairs of *spatially nearby* polyline segments that are nearly parallel
  and *not adjacent in index* (i.e., electrically far-ish).
- Approximate mutual capacitance with a parallel-plate proxy:

    c_ij ≈ k * eps0 * (w * overlap_len) / gap

  where:
  - eps0 is vacuum permittivity (air-only)
  - w is wire width (square cross-section), used as a proxy for facing width
  - overlap_len is the shorter of the two segment lengths
  - gap is (centerline distance - w), clamped to a small minimum
  - k is a user-tunable fudge factor (defaults to 0.35) to partially account for
    fringing + non-ideal facing geometry.

Effective terminal capacitance estimate
We assume a *linear* voltage distribution along the conductor from IN to OUT.
Let s ∈ [0,1] be the normalized arclength coordinate. The energy from each
c_ij is 0.5*c_ij*(V_i - V_j)^2 with V_i = V*s_i. Therefore:

    C_eff ≈ Σ c_ij * (s_i - s_j)^2

This is not a substitute for FastCap/PEEC/FEM, but it gives an actionable
ballpark and helps rank parameter changes (gap/width/turns).

Usage:
  ./scripts/bfem_capacitance_air.py
  ./scripts/bfem_capacitance_air.py --wireGap 0.1 --wireWidth 1.0
  ./scripts/bfem_capacitance_air.py --search-mm 3.0 --min-index-sep 25

Outputs:
- total length
- number of interacting segment pairs used
- C_eff estimate (pF)

Then compute SRF once you have L:
  ./scripts/bfem_resonance.py --L-mH <L> --C-pF <C_eff_pF>
"""

from __future__ import annotations

import argparse
import json
import math
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Tuple

EPS0_F_PER_M = 8.8541878128e-12


@dataclass(frozen=True)
class Seg:
    a: Tuple[float, float, float]  # meters
    b: Tuple[float, float, float]  # meters
    mid: Tuple[float, float, float]  # meters
    dir: Tuple[float, float, float]  # unit
    length_m: float
    s_mid: float  # normalized arclength position in [0,1]


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def _mm_to_m(mm: float) -> float:
    return mm * 1.0e-3


def _vsub(a: Tuple[float, float, float], b: Tuple[float, float, float]) -> Tuple[float, float, float]:
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _vdot(a: Tuple[float, float, float], b: Tuple[float, float, float]) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _vadd(a: Tuple[float, float, float], b: Tuple[float, float, float]) -> Tuple[float, float, float]:
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def _vscale(a: Tuple[float, float, float], s: float) -> Tuple[float, float, float]:
    return (a[0] * s, a[1] * s, a[2] * s)


def _vlen(a: Tuple[float, float, float]) -> float:
    return math.sqrt(_vdot(a, a))


def _vunit(a: Tuple[float, float, float]) -> Tuple[float, float, float]:
    n = _vlen(a)
    if n == 0:
        return (0.0, 0.0, 0.0)
    return (a[0] / n, a[1] / n, a[2] / n)


def _clamp(x: float, lo: float, hi: float) -> float:
    return lo if x < lo else hi if x > hi else x


def _segment_distance_m(
    p1: Tuple[float, float, float],
    q1: Tuple[float, float, float],
    p2: Tuple[float, float, float],
    q2: Tuple[float, float, float],
) -> float:
    """Minimum distance between 3D line segments p1-q1 and p2-q2.

    Based on the standard closest-points-on-segments formula.
    """

    d1 = _vsub(q1, p1)
    d2 = _vsub(q2, p2)
    r = _vsub(p1, p2)
    a = _vdot(d1, d1)
    e = _vdot(d2, d2)
    f = _vdot(d2, r)

    if a <= 1e-18 and e <= 1e-18:
        return _vlen(_vsub(p1, p2))
    if a <= 1e-18:
        t = _clamp(f / e, 0.0, 1.0)
        c2 = _vadd(p2, _vscale(d2, t))
        return _vlen(_vsub(p1, c2))

    c = _vdot(d1, r)
    if e <= 1e-18:
        s = _clamp(-c / a, 0.0, 1.0)
        c1 = _vadd(p1, _vscale(d1, s))
        return _vlen(_vsub(c1, p2))

    b = _vdot(d1, d2)
    denom = a * e - b * b

    if denom != 0.0:
        s = _clamp((b * f - c * e) / denom, 0.0, 1.0)
    else:
        s = 0.0

    t = (b * s + f) / e

    if t < 0.0:
        t = 0.0
        s = _clamp(-c / a, 0.0, 1.0)
    elif t > 1.0:
        t = 1.0
        s = _clamp((b - c) / a, 0.0, 1.0)

    c1 = _vadd(p1, _vscale(d1, s))
    c2 = _vadd(p2, _vscale(d2, t))
    return _vlen(_vsub(c1, c2))


def _export_network(args: argparse.Namespace, json_path: Path) -> None:
    repo = _repo_root()

    cmd = [
        "moon",
        "run",
        "--target",
        "native",
        "examples/12-bifilar-electromagnet",
        "--",
        "--nostep",
        "--export_conductor_network",
        str(json_path),
        "--innerDiam",
        str(args.innerDiam),
        "--numPairs",
        str(args.numPairs),
        "--numSegs",
        str(args.numSegs),
        "--vertTurns",
        str(args.vertTurns),
        "--wireWidth",
        str(args.wireWidth),
        "--wireGap",
        str(args.wireGap),
    ]
    if args.nocage:
        cmd.append("--nocage")
    if args.nocoil:
        cmd.append("--nocoil")
    if args.nowires:
        cmd.append("--nowires")
    if args.nosupport:
        cmd.append("--nosupport")

    proc = subprocess.run(cmd, cwd=str(repo), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if proc.returncode != 0:
        sys.stderr.write(proc.stderr)
        raise SystemExit(proc.returncode)


def _load_series(json_path: Path) -> Tuple[List[Tuple[float, float, float]], Dict[str, float]]:
    data = json.loads(json_path.read_text(encoding="utf-8"))
    if data.get("schema") != "bfem:conductor-network:v1":
        raise ValueError(f"Unexpected schema: {data.get('schema')}")

    params = data.get("params") or {}
    wire_width_mm = float(params.get("wireWidth_mm"))

    paths = data.get("paths")
    if not isinstance(paths, list) or not paths:
        raise ValueError("No paths in JSON")
    pts = paths[0].get("points")
    if not isinstance(pts, list) or len(pts) < 2:
        raise ValueError("Path has insufficient points")

    points_m = [(_mm_to_m(float(p[0])), _mm_to_m(float(p[1])), _mm_to_m(float(p[2]))) for p in pts]
    return points_m, {"wire_width_m": _mm_to_m(wire_width_mm)}


def _build_segments(points_m: List[Tuple[float, float, float]]) -> Tuple[List[Seg], float]:
    seg_lens: List[float] = []
    for i in range(1, len(points_m)):
        seg_lens.append(_vlen(_vsub(points_m[i], points_m[i - 1])))
    total = sum(seg_lens)
    if total <= 0:
        raise ValueError("Total length is zero")

    segs: List[Seg] = []
    s_acc = 0.0
    for i in range(1, len(points_m)):
        a = points_m[i - 1]
        b = points_m[i]
        d = _vsub(b, a)
        L = _vlen(d)
        if L <= 0:
            continue
        mid = _vadd(a, _vscale(d, 0.5))
        s_mid = (s_acc + 0.5 * L) / total
        segs.append(Seg(a=a, b=b, mid=mid, dir=_vunit(d), length_m=L, s_mid=s_mid))
        s_acc += L
    return segs, total


def _cell_key(p: Tuple[float, float, float], cell_m: float) -> Tuple[int, int, int]:
    return (int(math.floor(p[0] / cell_m)), int(math.floor(p[1] / cell_m)), int(math.floor(p[2] / cell_m)))


def estimate_ceff_air(
    segs: List[Seg],
    wire_width_m: float,
    search_m: float,
    min_index_sep: int,
    parallel_cos: float,
    k_factor: float,
) -> Tuple[float, int]:
    """Return (C_eff_F, pair_count_used)."""

    cell_m = search_m
    grid: Dict[Tuple[int, int, int], List[int]] = {}
    for i, s in enumerate(segs):
        key = _cell_key(s.mid, cell_m)
        grid.setdefault(key, []).append(i)

    ceff = 0.0
    pairs = 0

    for i, si in enumerate(segs):
        kx, ky, kz = _cell_key(si.mid, cell_m)
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    bucket = grid.get((kx + dx, ky + dy, kz + dz))
                    if not bucket:
                        continue
                    for j in bucket:
                        if j <= i:
                            continue
                        if abs(j - i) <= min_index_sep:
                            continue
                        sj = segs[j]

                        # Cheap midpoint radius cull.
                        if _vlen(_vsub(si.mid, sj.mid)) > search_m:
                            continue

                        # Nearly parallel (or anti-parallel).
                        if abs(_vdot(si.dir, sj.dir)) < parallel_cos:
                            continue

                        d_center = _segment_distance_m(si.a, si.b, sj.a, sj.b)
                        gap = max(d_center - wire_width_m, 1e-6)

                        overlap = min(si.length_m, sj.length_m)
                        area = wire_width_m * overlap
                        cij = k_factor * EPS0_F_PER_M * area / gap

                        ds = si.s_mid - sj.s_mid
                        ceff += cij * (ds * ds)
                        pairs += 1

    return ceff, pairs


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Estimate air-only effective capacitance of BFEM (ballpark).")

    # Mirror key generator args.
    p.add_argument("--innerDiam", type=float, default=6.0)
    p.add_argument("--numPairs", type=int, default=10)
    p.add_argument("--numSegs", type=int, default=36)
    p.add_argument("--vertTurns", type=float, default=15.0)
    p.add_argument("--wireWidth", type=float, default=1.0)
    p.add_argument("--wireGap", type=float, default=0.2)

    p.add_argument("--nocage", action="store_true")
    p.add_argument("--nocoil", action="store_true")
    p.add_argument("--nowires", action="store_true")
    p.add_argument("--nosupport", action="store_true")

    # Estimator knobs.
    p.add_argument("--search-mm", type=float, default=3.0, help="Neighbor search radius (mm)")
    p.add_argument("--min-index-sep", type=int, default=50, help="Ignore pairs closer than this many segments in the polyline")
    p.add_argument("--parallel-cos", type=float, default=0.95, help="Min |cos(theta)| for segments to be considered parallel")
    p.add_argument("--k", type=float, default=0.35, help="Fudge factor multiplying eps0*A/gap")

    p.add_argument("--dump-json", action="store_true", help="Print the exported JSON path")

    return p


def main() -> None:
    args = build_parser().parse_args()

    with tempfile.TemporaryDirectory(prefix="bfem_cap_air_") as td:
        json_path = Path(td) / "bfem_conductor_network.json"
        _export_network(args, json_path)

        points_m, meta = _load_series(json_path)
        segs, total_len = _build_segments(points_m)

        ceff, pairs = estimate_ceff_air(
            segs,
            wire_width_m=meta["wire_width_m"],
            search_m=_mm_to_m(args.search_mm),
            min_index_sep=int(args.min_index_sep),
            parallel_cos=float(args.parallel_cos),
            k_factor=float(args.k),
        )

        if args.dump_json:
            print(f"json: {json_path}")

    print(f"segments: {len(segs)}")
    print(f"length_total: {total_len:.6g} m")
    print(f"pairs_used: {pairs}")
    print(f"C_eff_air_est: {ceff:.6g} F")
    print(f"C_eff_air_est: {ceff*1e12:.6g} pF")


if __name__ == "__main__":
    main()
