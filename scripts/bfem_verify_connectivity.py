#!/usr/bin/env python3
"""Connectivity checker for BFEM centerline exports.

This is a *proof tool* for the claim: all conductive geometry (except support)
forms a single series path from one exit wire to the other.

Right now, the MoonBit export `--export_centerlines` emits helix centerlines.
As the export is expanded to include cage/exits/connectors, this checker will
verify that the resulting conductor network is:
- one connected component, and
- a single path graph (exactly two degree-1 nodes, all others degree-2)

Usage:
  moon run --target native examples/12-bifilar-electromagnet -- \
        --export_centerlines /tmp/bfem_centerlines.json

  ./scripts/bfem_verify_connectivity.py /tmp/bfem_centerlines.json
"""

from __future__ import annotations

import argparse
import json
import math
from collections import defaultdict, deque
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Iterable, List, Tuple


@dataclass(frozen=True)
class Key3:
    x: int
    y: int
    z: int


def _quantize_mm(p: List[float], tol_mm: float) -> Key3:
    # Quantize to a grid so that points within tolerance collapse.
    # This is robust to minor floating-point noise.
    q = 1.0 / tol_mm
    return Key3(int(round(p[0] * q)), int(round(p[1] * q)), int(round(p[2] * q)))


def _load(path: Path) -> Dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("JSON root must be an object")
    if data.get("schema") != "bfem:centerlines:v1":
        raise ValueError(f"Unexpected schema: {data.get('schema')}")
    if data.get("units") != "mm":
        raise ValueError(f"Unexpected units: {data.get('units')}")
    return data


def _iter_edges(data: Dict[str, Any]) -> Iterable[Tuple[str, List[float], List[float]]]:
    for idx, path in enumerate(data.get("paths", [])):
        name = str(path.get("name", f"path-{idx}"))
        pts = path.get("points")
        if not isinstance(pts, list) or len(pts) < 2:
            continue
        yield name, pts[0], pts[-1]


def analyze(data: Dict[str, Any], tol_mm: float) -> None:
    # Build undirected endpoint graph.
    adj: Dict[Key3, List[Key3]] = defaultdict(list)
    edge_names: Dict[Tuple[Key3, Key3], List[str]] = defaultdict(list)

    nodes: set[Key3] = set()
    edges = 0
    for name, a, b in _iter_edges(data):
        ka = _quantize_mm(a, tol_mm)
        kb = _quantize_mm(b, tol_mm)
        nodes.add(ka)
        nodes.add(kb)
        adj[ka].append(kb)
        adj[kb].append(ka)
        edge_names[(ka, kb)].append(name)
        edge_names[(kb, ka)].append(name)
        edges += 1

    if not nodes:
        print("No paths found.")
        return

    # Connected components
    seen: set[Key3] = set()
    comps: List[List[Key3]] = []
    for n in nodes:
        if n in seen:
            continue
        q = deque([n])
        seen.add(n)
        comp = []
        while q:
            cur = q.popleft()
            comp.append(cur)
            for nxt in adj.get(cur, []):
                if nxt not in seen:
                    seen.add(nxt)
                    q.append(nxt)
        comps.append(comp)

    degs = [len(adj[n]) for n in nodes]
    deg_hist: Dict[int, int] = defaultdict(int)
    for d in degs:
        deg_hist[d] += 1

    print(f"endpoints: {len(nodes)}")
    print(f"paths (edges): {edges}")
    print(f"components: {len(comps)}")
    print("degree histogram:")
    for d in sorted(deg_hist):
        print(f"  deg {d}: {deg_hist[d]}")

    deg1 = [n for n in nodes if len(adj[n]) == 1]
    deg2 = [n for n in nodes if len(adj[n]) == 2]
    deg_other = [n for n in nodes if len(adj[n]) not in (1, 2)]

    if len(comps) == 1 and len(deg1) == 2 and not deg_other:
        print("OK: graph is a single path (two terminals, all internal nodes degree-2)")
    else:
        print("NOT a single series path yet (given current export)")
        if len(comps) != 1:
            print("  - reason: multiple connected components")
        if len(deg1) != 2:
            print(f"  - reason: expected 2 degree-1 terminals, found {len(deg1)}")
        if deg_other:
            print(f"  - reason: found {len(deg_other)} nodes with degree not in {{1,2}}")


def main() -> None:
    ap = argparse.ArgumentParser(description="Verify exported BFEM conductor connectivity.")
    ap.add_argument("json", type=Path, help="Centerlines JSON file")
    ap.add_argument("--tol-mm", type=float, default=1e-3, help="Endpoint match tolerance in mm")
    args = ap.parse_args()

    data = _load(args.json)
    analyze(data, tol_mm=args.tol_mm)


if __name__ == "__main__":
    main()
