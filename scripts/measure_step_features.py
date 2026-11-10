#!/usr/bin/env python3
"""Report the analytic feature inventory of a STEP file.

This is a development-time comparison helper, complementary to
``measure_step_occt.py`` (which reports volume and the bounding box). It reads
the STEP text directly and reports, per file:

  * the number of manifold solids and advanced faces;
  * a count of every analytic surface type (plane, cylinder, cone, sphere,
    torus, B-spline);
  * the parameters of every cone (radius and semi-angle), sphere, and torus;
  * the declared plane-angle unit, so cone/fillet angles can be reported in
    degrees consistently.

It is used to verify that a chamfer or fillet really produced the expected
conical/toroidal/spherical geometry, rather than a relabelled sharp edge.

Usage:
    python3 scripts/measure_step_features.py part.step [more.step ...]
    python3 scripts/measure_step_features.py --json part.step
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path

ENTITY_RE = re.compile(r"#(\d+)\s*=\s*(.*?);", re.DOTALL)
NUM_RE = re.compile(r"[+-]?(?:\d+\.\d*|\.\d+|\d+)(?:[eE][+-]?\d+)?")

ANALYTIC = {
    "PLANE": "plane",
    "CYLINDRICAL_SURFACE": "cylinder",
    "CONICAL_SURFACE": "cone",
    "SPHERICAL_SURFACE": "sphere",
    "TOROIDAL_SURFACE": "torus",
    "B_SPLINE_SURFACE": "bspline",
    "B_SPLINE_SURFACE_WITH_KNOTS": "bspline",
    "SURFACE_OF_REVOLUTION": "surface_of_revolution",
}


def split_args(body: str) -> list[str]:
    """Split a STEP argument list on top-level commas."""
    out: list[str] = []
    depth = 0
    cur: list[str] = []
    in_str = False
    i = 0
    while i < len(body):
        c = body[i]
        if c == "'":
            in_str = not in_str
            cur.append(c)
        elif in_str:
            cur.append(c)
        elif c == "(":
            depth += 1
            cur.append(c)
        elif c == ")":
            depth -= 1
            cur.append(c)
        elif c == "," and depth == 0:
            out.append("".join(cur).strip())
            cur = []
        else:
            cur.append(c)
        i += 1
    if cur:
        out.append("".join(cur).strip())
    return out


def parse_entities(text: str) -> dict[int, str]:
    return {int(m.group(1)): m.group(2).strip() for m in ENTITY_RE.finditer(text)}


def num_literal(arg: str) -> float | None:
    m = NUM_RE.search(arg)
    if not m:
        return None
    try:
        return float(m.group(0))
    except ValueError:
        return None


def angle_unit_degrees(text: str) -> bool:
    """Return True when the representation context's plane-angle unit is
    degrees (a CONVERSION_BASED_UNIT named DEGREE is declared)."""
    return bool(re.search(r"CONVERSION_BASED_UNIT\('DEGREE'", text))


def analyze(path: Path) -> dict:
    text = path.read_text(errors="replace")
    ents = parse_entities(text)
    counts: dict[str, int] = {}
    surfaces = {"cone": [], "sphere": [], "torus": [], "cylinder": []}
    faces = 0
    solids = 0
    for _eid, body in ents.items():
        head = body.split("(", 1)[0].strip().upper()
        if head == "ADVANCED_FACE":
            faces += 1
        elif head == "MANIFOLD_SOLID_BREP":
            solids += 1
        if head in ANALYTIC:
            kind = ANALYTIC[head]
            counts[kind] = counts.get(kind, 0) + 1
            args = split_args(body[body.find("(") + 1 : body.rfind(")")])
            if kind == "cone" and len(args) >= 4:
                r = num_literal(args[2])
                a = num_literal(args[3])
                surfaces["cone"].append({"radius": r, "semi_angle": a})
            elif kind == "sphere" and len(args) >= 3:
                surfaces["sphere"].append({"radius": num_literal(args[2])})
            elif kind == "torus" and len(args) >= 4:
                surfaces["torus"].append(
                    {
                        "major_radius": num_literal(args[2]),
                        "minor_radius": num_literal(args[3]),
                    }
                )
            elif kind == "cylinder" and len(args) >= 3:
                surfaces["cylinder"].append({"radius": num_literal(args[2])})
    deg = angle_unit_degrees(text)
    if deg:
        for cone in surfaces["cone"]:
            if cone["semi_angle"] is not None:
                cone["semi_angle_deg"] = cone["semi_angle"]
    else:
        for cone in surfaces["cone"]:
            if cone["semi_angle"] is not None:
                cone["semi_angle_deg"] = math.degrees(cone["semi_angle"])
    return {
        "path": str(path),
        "solids": solids,
        "advanced_faces": faces,
        "surface_counts": counts,
        "angle_unit": "degree" if deg else "radian",
        "cones": surfaces["cone"],
        "spheres": surfaces["sphere"],
        "tori": surfaces["torus"],
        "cylinders": surfaces["cylinder"],
    }


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("files", nargs="+")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    results = [analyze(Path(p)) for p in args.files]
    if args.json:
        print(json.dumps(results, indent=2))
        return 0
    for r in results:
        print(r["path"])
        print(f"  solids: {r['solids']}  advanced faces: {r['advanced_faces']}")
        print(f"  plane-angle unit: {r['angle_unit']}")
        counts = ", ".join(f"{k}={v}" for k, v in sorted(r["surface_counts"].items()))
        print(f"  surfaces: {counts}")
        for cone in r["cones"]:
            deg = cone.get("semi_angle_deg")
            print(
                f"    cone: radius={cone['radius']} "
                f"semi_angle={deg:.4f} deg" if deg is not None else
                f"    cone: radius={cone['radius']}"
            )
        for s in r["spheres"]:
            print(f"    sphere: radius={s['radius']}")
        for t in r["tori"]:
            print(
                f"    torus: major={t['major_radius']} minor={t['minor_radius']}"
            )
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
