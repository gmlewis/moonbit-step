#!/usr/bin/env python3
"""Validate a STEP file the way a strict importer or fabricator will.

Checks (optional parts are skipped when their tool is unavailable):

  * ISO 10303-21 envelope and real-number syntax.  Reals need an upper-case
    ``E`` and a mandatory decimal point; lower-case ``e`` is non-conforming.
  * every ``#id`` reference resolves.
  * per-shell topology: every edge is used exactly twice, by two different
    faces, with opposite senses.  (Shared edges between separate shells are
    allowed: each closed shell is checked on its own.)
  * every ``ADVANCED_FACE`` belongs to exactly one ``CLOSED_SHELL`` and every
    shell to a solid.
  * every face on a ``PLANE`` has a planar boundary (default 0.01 mm; a
    warning is reported above 1e-6 mm, e.g. for deliberately snapped models).
  * OCCT ``checkshape`` (via ``scripts/validate_with_occt.sh``).
  * OCCT tessellation to STL: every mesh edge is shared by exactly two
    triangles (open edges fail; >2 is reported as a warning because separate
    bodies may touch).
  * optional gmsh tessellation with the same STL check.

Exit status is 0 only when every required check passes.

Usage:
    python3 scripts/validate_step.py part.step
    python3 scripts/validate_step.py --no-mesh part.step
    python3 scripts/validate_step.py --gmsh --json part.step
"""

from __future__ import annotations

import argparse
import json
import math
import re
import shutil
import struct
import subprocess
import sys
import tempfile
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path

# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------

@dataclass
class Check:
    name: str
    ok: bool
    detail: str = ""
    skipped: bool = False


@dataclass
class Result:
    path: str
    checks: list[Check] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return all(c.ok for c in self.checks if not c.skipped)

    def as_dict(self) -> dict:
        return {
            "path": self.path,
            "ok": self.ok,
            "checks": [
                {
                    "name": c.name,
                    "ok": c.ok,
                    "skipped": c.skipped,
                    "detail": c.detail,
                }
                for c in self.checks
            ],
        }


# ---------------------------------------------------------------------------
# STEP text: strings, comments, statements, numbers
# ---------------------------------------------------------------------------

NUMBER_RE = re.compile(r"[+-]?(?:\d+\.\d*|\.\d+|\d+)(?:[eE][+-]?\d+)?")
ENTITY_RE = re.compile(r"^#(\d+)\s*=\s*(.*)$", re.DOTALL)


def split_statements(text: str) -> list[str]:
    """Split on semicolons outside strings and comments."""
    statements: list[str] = []
    start = 0
    i = 0
    n = len(text)
    while i < n:
        c = text[i]
        if c == "'":
            i += 1
            while i < n:
                if text[i] == "'":
                    if i + 1 < n and text[i + 1] == "'":
                        i += 2
                        continue
                    i += 1
                    break
                i += 1
        elif c == "/" and i + 1 < n and text[i + 1] == "*":
            i += 2
            while i < n:
                if text[i] == "*" and i + 1 < n and text[i + 1] == "/":
                    i += 2
                    break
                i += 1
        elif c == ";":
            statements.append(text[start:i])
            i += 1
            start = i
        else:
            i += 1
    tail = text[start:]
    if tail.strip():
        statements.append(tail)
    return statements


def mask_strings_and_comments(text: str) -> str:
    """Replace string and comment contents with spaces, keeping newlines."""
    out = list(text)
    i = 0
    n = len(text)

    def blank(k: int) -> None:
        if text[k] != "\n":
            out[k] = " "

    while i < n:
        c = text[i]
        if c == "'":
            blank(i)
            i += 1
            while i < n:
                if text[i] == "'":
                    if i + 1 < n and text[i + 1] == "'":
                        blank(i)
                        blank(i + 1)
                        i += 2
                        continue
                    blank(i)
                    i += 1
                    break
                blank(i)
                i += 1
        elif c == "/" and i + 1 < n and text[i + 1] == "*":
            blank(i)
            blank(i + 1)
            i += 2
            while i < n:
                if text[i] == "*" and i + 1 < n and text[i + 1] == "/":
                    blank(i)
                    blank(i + 1)
                    i += 2
                    break
                blank(i)
                i += 1
        else:
            i += 1
    return "".join(out)


def check_envelope(text: str) -> Check:
    body = text.lstrip("﻿ \t\r\n")
    if not body.startswith("ISO-10303-21;"):
        return Check("syntax envelope", False, "does not start with ISO-10303-21;")
    stripped = text.rstrip()
    if not stripped.endswith("END-ISO-10303-21;"):
        return Check("syntax envelope", False, "does not end with END-ISO-10303-21;")
    for token in ("HEADER;", "DATA;", "ENDSEC;"):
        if token not in text:
            return Check("syntax envelope", False, f"missing {token}")
    return Check("syntax envelope", True, "ISO-10303-21 with HEADER and DATA")


def check_reals(text: str) -> Check:
    """Check the lexical form of every numeric literal outside strings/comments."""
    masked = mask_strings_and_comments(text)
    errors: list[str] = []
    checked = 0
    for m in NUMBER_RE.finditer(masked):
        token = m.group(0)
        start, end = m.start(), m.end()
        prev = masked[start - 1] if start > 0 else ""
        nxt = masked[end] if end < len(masked) else ""
        # Entity ids (#123), identifiers and dotted names are not numbers.
        if prev == "#" or prev.isalnum() or prev == "_":
            continue
        if nxt.isalnum() or nxt == "_":
            continue
        checked += 1
        reason = ""
        if "e" in token:
            reason = "lower-case exponent (STEP requires E)"
        elif "E" in token:
            if not re.fullmatch(r"[+-]?\d+\.\d*E[+-]?\d+", token):
                reason = "exponent needs a decimal point in the mantissa"
        elif "." in token:
            if not re.fullmatch(r"[+-]?\d+\.\d*", token):
                reason = "real needs digits before the decimal point"
        else:
            if not re.fullmatch(r"[+-]?\d+", token):
                reason = "malformed integer"
        if reason:
            line = masked.count("\n", 0, start) + 1
            errors.append(f"line {line}: {token!r}: {reason}")
            if len(errors) >= 10:
                break
    if errors:
        detail = f"{len(errors)}+ non-conforming numeric literals: " + "; ".join(errors[:5])
        return Check("reals", False, detail)
    return Check("reals", True, f"{checked} numeric literals are ISO 10303-21 conforming")


# ---------------------------------------------------------------------------
# Entity parsing
# ---------------------------------------------------------------------------

RE_ADVANCED_FACE = re.compile(
    r"^ADVANCED_FACE\('.*?',\(([^)]*)\),#(\d+),\.([TF])\.\)$"
)
RE_FACE_BOUND = re.compile(
    r"^FACE_(?:OUTER_)?BOUND\('.*?',#(\d+),\.([TF])\.\)$"
)
RE_EDGE_LOOP = re.compile(r"^EDGE_LOOP\('.*?',\(([^)]*)\)\)$")
RE_ORIENTED_EDGE = re.compile(
    r"^ORIENTED_EDGE\('.*?',\*,\*,#(\d+),\.([TF])\.\)$"
)
RE_EDGE_CURVE = re.compile(
    r"^EDGE_CURVE\('.*?',#(\d+),#(\d+),#(\d+),\.([TF])\.\)$"
)
RE_VERTEX_POINT = re.compile(r"^VERTEX_POINT\('.*?',#(\d+)\)$")
RE_CARTESIAN_POINT = re.compile(r"^CARTESIAN_POINT\('.*?',\(([^)]*)\)\)$")
RE_DIRECTION = re.compile(r"^DIRECTION\('.*?',\(([^)]*)\)\)$")
RE_AXIS2 = re.compile(r"^AXIS2_PLACEMENT_3D\('.*?',#(\d+),#(\d+),#(\d+)\)$")
RE_PLANE = re.compile(r"^PLANE\('.*?',#(\d+)\)$")
RE_CLOSED_SHELL = re.compile(r"^CLOSED_SHELL\('.*?',\(([^)]*)\)\)$")
RE_SOLID = re.compile(r"^(?:MANIFOLD_SOLID_BREP|BREP_WITH_VOIDS)\('.*?',#(\d+)")


@dataclass
class Model:
    entities: dict[int, str] = field(default_factory=dict)
    points: dict[int, tuple[float, float, float]] = field(default_factory=dict)
    directions: dict[int, tuple[float, float, float]] = field(default_factory=dict)
    vertex_points: dict[int, int] = field(default_factory=dict)
    edge_curves: dict[int, tuple[int, int]] = field(default_factory=dict)
    oriented_edges: dict[int, tuple[int, bool]] = field(default_factory=dict)
    edge_loops: dict[int, list[int]] = field(default_factory=dict)
    face_bounds: dict[int, int] = field(default_factory=dict)
    # FACE_BOUND(...,.T.) keeps the loop direction; .F. reverses it.
    face_bound_orientation: dict[int, bool] = field(default_factory=dict)
    advanced_faces: dict[int, tuple[list[int], int]] = field(default_factory=dict)
    planes: dict[int, int] = field(default_factory=dict)
    axis2: dict[int, tuple[int, int, int]] = field(default_factory=dict)
    closed_shells: dict[int, list[int]] = field(default_factory=dict)
    solids: dict[int, int] = field(default_factory=dict)


def parse_entities(text: str) -> Model:
    model = Model()
    for stmt in split_statements(text):
        s = stmt.strip()
        if not s:
            continue
        m = ENTITY_RE.match(s)
        if not m:
            continue
        eid = int(m.group(1))
        body = re.sub(r"\s+", "", m.group(2))
        model.entities[eid] = body

    for eid, body in model.entities.items():
        m = RE_CARTESIAN_POINT.match(body)
        if m:
            vals = _nums(m.group(1))
            if len(vals) == 3:
                model.points[eid] = (vals[0], vals[1], vals[2])
            continue
        m = RE_DIRECTION.match(body)
        if m:
            vals = _nums(m.group(1))
            if len(vals) == 3:
                model.directions[eid] = (vals[0], vals[1], vals[2])
            continue
        m = RE_VERTEX_POINT.match(body)
        if m:
            model.vertex_points[eid] = int(m.group(1))
            continue
        m = RE_EDGE_CURVE.match(body)
        if m:
            model.edge_curves[eid] = (int(m.group(1)), int(m.group(2)))
            continue
        m = RE_ORIENTED_EDGE.match(body)
        if m:
            model.oriented_edges[eid] = (int(m.group(1)), m.group(2) == "T")
            continue
        m = RE_EDGE_LOOP.match(body)
        if m:
            model.edge_loops[eid] = _refs(m.group(1))
            continue
        m = RE_FACE_BOUND.match(body)
        if m:
            model.face_bounds[eid] = int(m.group(1))
            model.face_bound_orientation[eid] = m.group(2) == "T"
            continue
        m = RE_ADVANCED_FACE.match(body)
        if m:
            model.advanced_faces[eid] = (_refs(m.group(1)), int(m.group(2)))
            continue
        m = RE_PLANE.match(body)
        if m:
            model.planes[eid] = int(m.group(1))
            continue
        m = RE_AXIS2.match(body)
        if m:
            model.axis2[eid] = (int(m.group(1)), int(m.group(2)), int(m.group(3)))
            continue
        m = RE_CLOSED_SHELL.match(body)
        if m:
            model.closed_shells[eid] = _refs(m.group(1))
            continue
        m = RE_SOLID.match(body)
        if m:
            model.solids[eid] = int(m.group(1))
    return model


def _nums(s: str) -> list[float]:
    out = []
    for part in s.split(","):
        part = part.strip()
        if not part:
            continue
        out.append(float(part))
    return out


def _refs(s: str) -> list[int]:
    return [int(x) for x in re.findall(r"#(\d+)", s)]


def _refs_in_body(body: str) -> list[int]:
    # Names in this writer never contain '#', and split_statements already
    # removed statement-ending semicolons outside strings.
    return _refs(body)


def _unit(v: tuple[float, float, float]) -> tuple[float, float, float]:
    length = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])
    if length == 0.0:
        return (0.0, 0.0, 1.0)
    return (v[0] / length, v[1] / length, v[2] / length)


def check_references(model: Model) -> Check:
    missing: list[str] = []
    for eid, body in model.entities.items():
        for ref in _refs_in_body(body):
            if ref not in model.entities:
                missing.append(f"#{eid} -> #{ref}")
                if len(missing) >= 10:
                    break
        if len(missing) >= 10:
            break
    if missing:
        return Check("references", False, "missing entity references: " + "; ".join(missing))
    return Check("references", True, f"{len(model.entities)} entities, all references resolve")


# ---------------------------------------------------------------------------
# Topology and planarity
# ---------------------------------------------------------------------------

def check_topology(model: Model) -> list[Check]:
    checks: list[Check] = []

    # Every ADVANCED_FACE exactly once in a CLOSED_SHELL.
    face_shell: dict[int, int] = {}
    shell_faces: dict[int, list[int]] = {}
    for shell_id, face_ids in model.closed_shells.items():
        for face_id in face_ids:
            if face_id in face_shell:
                checks.append(
                    Check(
                        "shells",
                        False,
                        f"face #{face_id} is in shells #{face_shell[face_id]} and #{shell_id}",
                    )
                )
                return checks
            face_shell[face_id] = shell_id
            shell_faces.setdefault(shell_id, []).append(face_id)

    orphan_faces = [f for f in model.advanced_faces if f not in face_shell]
    solid_shells = set(model.solids.values())
    orphan_shells = [s for s in model.closed_shells if s not in solid_shells]
    if orphan_faces:
        checks.append(
            Check("shells", False, f"{len(orphan_faces)} faces are not in a CLOSED_SHELL")
        )
        return checks
    if orphan_shells:
        checks.append(
            Check("shells", False, f"{len(orphan_shells)} CLOSED_SHELLs are not in a solid")
        )
        return checks
    checks.append(
        Check(
            "shells",
            True,
            f"{len(model.solids)} solids, {len(model.closed_shells)} closed shells, "
            f"{len(model.advanced_faces)} faces",
        )
    )

    # Face -> oriented edges.
    face_edges: dict[int, list[tuple[int, bool]]] = {}
    for face_id, (bound_ids, _surface) in model.advanced_faces.items():
        uses: list[tuple[int, bool]] = []
        ok = True
        for bound_id in bound_ids:
            loop_id = model.face_bounds.get(bound_id)
            if loop_id is None or loop_id not in model.edge_loops:
                ok = False
                break
            # A reversed bound reverses every use in its loop.
            reversed_bound = not model.face_bound_orientation.get(bound_id, True)
            for oe_id in model.edge_loops[loop_id]:
                oe = model.oriented_edges.get(oe_id)
                if oe is None:
                    ok = False
                    break
                edge_id, sense = oe
                uses.append((edge_id, sense != reversed_bound))
        if not ok:
            checks.append(
                Check("topology", False, f"face #{face_id} has an unparsable bound")
            )
            return checks
        face_edges[face_id] = uses

    bad_edges: list[str] = []
    same_edges: list[str] = []
    total_edges = 0
    for shell_id, face_ids in shell_faces.items():
        edge_uses: dict[int, list[tuple[int, bool]]] = defaultdict(list)
        for face_id in face_ids:
            for edge_id, sense in face_edges[face_id]:
                edge_uses[edge_id].append((face_id, sense))
        for edge_id, uses in edge_uses.items():
            total_edges += 1
            if len(uses) != 2:
                if len(bad_edges) < 5:
                    bad_edges.append(f"#{edge_id} used {len(uses)}x")
                continue
            first_face, first_sense = uses[0]
            second_face, second_sense = uses[1]
            if first_face == second_face:
                # A seam edge is used twice by the same face (once in each
                # direction) to close a periodic surface such as a cylinder.
                # It is valid only when the two uses have opposite sense.
                if first_sense == second_sense:
                    if len(same_edges) < 5:
                        same_edges.append(f"#{edge_id}")
            elif first_sense == second_sense:
                if len(same_edges) < 5:
                    same_edges.append(f"#{edge_id}")

    if bad_edges:
        checks.append(
            Check(
                "topology",
                False,
                f"{len(bad_edges)}+ edges are not used by exactly two faces: "
                + ", ".join(bad_edges),
            )
        )
    else:
        checks.append(
            Check("topology", True, f"{total_edges} edges, each used by exactly two faces")
        )

    if same_edges:
        checks.append(
            Check(
                "orientation",
                False,
                f"{len(same_edges)}+ edges are traversed in the same direction by both faces: "
                + ", ".join(same_edges),
            )
        )
    else:
        checks.append(
            Check("orientation", True, "every shared edge is traversed in opposite directions")
        )
    return checks


def check_planarity(model: Model, tol: float) -> Check:
    worst = 0.0
    worst_face = None
    non_planar = 0
    checked = 0
    for face_id, (bound_ids, surface_id) in model.advanced_faces.items():
        if surface_id not in model.planes:
            continue
        plane_id = model.planes[surface_id]
        axis2 = model.axis2.get(plane_id)
        if axis2 is None:
            return Check("planarity", False, f"face #{face_id} has an unparsable PLANE")
        loc_id, axis_id, _ref_id = axis2
        loc = model.points.get(loc_id)
        direction = model.directions.get(axis_id)
        if loc is None or direction is None:
            return Check("planarity", False, f"face #{face_id} has an unparsable plane frame")
        normal = _unit(direction)

        vertex_ids: set[int] = set()
        for bound_id in bound_ids:
            loop_id = model.face_bounds.get(bound_id)
            if loop_id is None or loop_id not in model.edge_loops:
                continue
            for oe_id in model.edge_loops[loop_id]:
                oe = model.oriented_edges.get(oe_id)
                if oe is None:
                    continue
                edge = model.edge_curves.get(oe[0])
                if edge is not None:
                    vertex_ids.add(edge[0])
                    vertex_ids.add(edge[1])

        face_worst = 0.0
        ok = True
        for vertex_id in vertex_ids:
            cp_id = model.vertex_points.get(vertex_id)
            if cp_id is None:
                ok = False
                break
            p = model.points.get(cp_id)
            if p is None:
                ok = False
                break
            d = abs(
                (p[0] - loc[0]) * normal[0]
                + (p[1] - loc[1]) * normal[1]
                + (p[2] - loc[2]) * normal[2]
            )
            if d > face_worst:
                face_worst = d
        if not ok:
            return Check("planarity", False, f"face #{face_id} has an unparsable vertex")
        checked += 1
        if face_worst > worst:
            worst = face_worst
            worst_face = face_id
        if face_worst > tol:
            non_planar += 1

    if non_planar:
        return Check(
            "planarity",
            False,
            f"{non_planar} PLANE faces deviate more than {tol:g} mm "
            f"(worst {worst:.3g} mm on face #{worst_face})",
        )
    warning = " (warning: above 1e-6 mm)" if worst > 1e-6 else ""
    return Check(
        "planarity",
        True,
        f"{checked} PLANE faces, worst deviation {worst:.3g} mm{warning}",
    )


# ---------------------------------------------------------------------------
# OCCT checkshape and tessellation
# ---------------------------------------------------------------------------

def _occt_tool() -> str | None:
    return shutil.which("occt-draw") or shutil.which("DRAWEXE")


def check_occt_checkshape(path: Path, required: bool) -> Check:
    tool = _occt_tool()
    if tool is None:
        if required:
            return Check(
                "occt checkshape",
                False,
                "neither occt-draw nor DRAWEXE is on PATH (use --no-mesh to skip OCCT)",
            )
        return Check("occt checkshape", True, "skipped: OCCT not installed", skipped=True)

    validator = Path(__file__).resolve().parent / "validate_with_occt.sh"
    if not validator.exists():
        if required:
            return Check("occt checkshape", False, f"missing {validator}")
        return Check("occt checkshape", True, f"skipped: missing {validator}", skipped=True)
    try:
        proc = subprocess.run(
            [str(validator), str(path)],
            capture_output=True,
            text=True,
            timeout=900,
        )
    except subprocess.TimeoutExpired:
        return Check("occt checkshape", False, "timed out after 900 s")
    if proc.returncode == 0:
        return Check("occt checkshape", True, "This shape seems to be valid")
    output = (proc.stdout + proc.stderr).strip().splitlines()
    tail = "; ".join(line.strip() for line in output[-3:] if line.strip())
    return Check("occt checkshape", False, tail or "checkshape failed")


def _tcl_escape(path: str) -> str:
    return path.replace("\\", "\\\\").replace('"', '\\"')


def _read_stl_triangles(path: Path) -> list[tuple[tuple[float, float, float], ...]]:
    data = path.read_bytes()
    if len(data) >= 84:
        count = struct.unpack_from("<I", data, 80)[0]
        if count > 0 and 84 + 50 * count <= len(data):
            triangles = []
            off = 84
            for _ in range(count):
                v = struct.unpack_from("<12f", data, off)[3:12]
                triangles.append(
                    ((v[0], v[1], v[2]), (v[3], v[4], v[5]), (v[6], v[7], v[8]))
                )
                off += 50
            return triangles

    triangles = []
    current: list[tuple[float, float, float]] = []
    for line in data.decode("utf-8", errors="replace").splitlines():
        parts = line.strip().split()
        if len(parts) == 4 and parts[0] == "vertex":
            current.append((float(parts[1]), float(parts[2]), float(parts[3])))
        elif parts and parts[0] == "endfacet":
            if len(current) == 3:
                triangles.append(tuple(current))
            current = []
    return triangles


def _stl_edges(triangles) -> tuple[int, int, int, int]:
    edges: Counter = Counter()

    def q(p):
        return (round(p[0], 5), round(p[1], 5), round(p[2], 5))

    for triangle in triangles:
        pts = [q(p) for p in triangle]
        for i in range(3):
            a = pts[i]
            b = pts[(i + 1) % 3]
            key = (a, b) if a < b else (b, a)
            edges[key] += 1
    open_edges = sum(1 for c in edges.values() if c == 1)
    nonmanifold = sum(1 for c in edges.values() if c > 2)
    return len(triangles), len(edges), open_edges, nonmanifold


def check_occt_mesh(path: Path, deflection: float, required: bool) -> Check:
    tool = _occt_tool()
    if tool is None:
        if required:
            return Check(
                "occt mesh",
                False,
                "neither occt-draw nor DRAWEXE is on PATH (use --no-mesh to skip)",
            )
        return Check("occt mesh", True, "skipped: OCCT not installed", skipped=True)

    with tempfile.TemporaryDirectory(prefix="step-validate-") as tmp:
        stl = Path(tmp) / "mesh.stl"
        cmd = (
            f'pload ALL; testreadstep "{_tcl_escape(str(path))}" a; '
            f"incmesh a {deflection}; writestl a \"{_tcl_escape(str(stl))}\""
        )
        try:
            proc = subprocess.run(
                [tool, "-b", "-c", cmd],
                capture_output=True,
                text=True,
                timeout=1200,
            )
        except subprocess.TimeoutExpired:
            return Check("occt mesh", False, "tessellation timed out after 1200 s")
        if not stl.exists() or stl.stat().st_size == 0:
            tail = (proc.stdout + proc.stderr).strip().splitlines()[-3:]
            return Check(
                "occt mesh",
                False,
                "no STL produced: " + "; ".join(line.strip() for line in tail),
            )
        triangles = _read_stl_triangles(stl)

    if not triangles:
        return Check("mesh", False, "the STL could not be parsed")
    tris, edges, open_edges, nonmanifold = _stl_edges(triangles)
    if open_edges:
        return Check(
            "occt mesh",
            False,
            f"{tris} triangles, {edges} edges, {open_edges} open edges",
        )
    warning = f", {nonmanifold} non-manifold edges (separate bodies may touch)" if nonmanifold else ""
    return Check(
        "occt mesh",
        True,
        f"{tris} triangles, {edges} edges, 0 open edges{warning}",
    )


def check_gmsh_mesh(path: Path, required: bool) -> Check:
    tool = shutil.which("gmsh")
    if tool is None:
        if required:
            return Check("gmsh mesh", False, "gmsh is not on PATH")
        return Check("gmsh mesh", True, "skipped: gmsh not installed", skipped=True)

    with tempfile.TemporaryDirectory(prefix="step-validate-gmsh-") as tmp:
        stl = Path(tmp) / "mesh.stl"
        try:
            proc = subprocess.run(
                [tool, str(path), "-2", "-format", "stl", "-o", str(stl), "-v", "1"],
                capture_output=True,
                text=True,
                timeout=1800,
            )
        except subprocess.TimeoutExpired:
            return Check("gmsh mesh", False, "tessellation timed out after 1800 s")
        if not stl.exists() or stl.stat().st_size == 0:
            tail = (proc.stdout + proc.stderr).strip().splitlines()[-3:]
            return Check("gmsh mesh", False, "no STL produced: " + "; ".join(line.strip() for line in tail))
        triangles = _read_stl_triangles(stl)

    if not triangles:
        return Check("mesh", False, "the STL could not be parsed")
    tris, edges, open_edges, nonmanifold = _stl_edges(triangles)
    if open_edges:
        return Check(
            "gmsh mesh",
            False,
            f"{tris} triangles, {edges} edges, {open_edges} open edges",
        )
    warning = f", {nonmanifold} non-manifold edges (separate bodies may touch)" if nonmanifold else ""
    return Check(
        "gmsh mesh",
        True,
        f"{tris} triangles, {edges} edges, 0 open edges{warning}",
    )


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def validate_step_file(
    path: str | Path,
    *,
    tessellate: bool = True,
    gmsh: bool = False,
    planarity_tol: float = 0.01,
    deflection: float = 0.05,
) -> Result:
    path = Path(path)
    result = Result(str(path))
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        result.checks.append(Check("read", False, str(exc)))
        return result

    result.checks.append(check_envelope(text))
    result.checks.append(check_reals(text))
    try:
        model = parse_entities(text)
    except Exception as exc:  # noqa: BLE001 - report malformed input, don't crash
        result.checks.append(Check("entities", False, f"could not parse: {exc}"))
        return result

    result.checks.append(check_references(model))
    result.checks.extend(check_topology(model))
    result.checks.append(check_planarity(model, planarity_tol))
    result.checks.append(check_occt_checkshape(path, required=tessellate))
    if tessellate:
        result.checks.append(check_occt_mesh(path, deflection, required=True))
    if gmsh:
        result.checks.append(check_gmsh_mesh(path, required=True))
    return result


def print_result(result: Result, quiet: bool = False) -> None:
    if quiet and result.ok:
        print(f"{result.path}: OK")
        return
    print(result.path)
    for check in result.checks:
        if check.skipped:
            tag = "SKIP"
        elif check.ok:
            tag = "PASS"
        else:
            tag = "FAIL"
        print(f"  [{tag}] {check.name}: {check.detail}")
    print("  OK" if result.ok else "  FAILED")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Validate STEP files for strict/importer compatibility."
    )
    parser.add_argument("files", nargs="+", help="STEP files to validate")
    parser.add_argument(
        "--no-mesh",
        action="store_true",
        help="skip OCCT tessellation (also lets a machine without OCCT validate syntax/topology)",
    )
    parser.add_argument(
        "--gmsh",
        action="store_true",
        help="also tessellate with gmsh and check the mesh",
    )
    parser.add_argument(
        "--deflection",
        type=float,
        default=0.05,
        help="tessellation deflection in mm (default: 0.05)",
    )
    parser.add_argument(
        "--planarity-tol",
        type=float,
        default=0.01,
        help="maximum PLANE-face deviation in mm (default: 0.01)",
    )
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    parser.add_argument("--quiet", action="store_true", help="print only failures and a one-line OK")
    args = parser.parse_args(argv)

    results = [
        validate_step_file(
            f,
            tessellate=not args.no_mesh,
            gmsh=args.gmsh,
            planarity_tol=args.planarity_tol,
            deflection=args.deflection,
        )
        for f in args.files
    ]

    if args.json:
        print(json.dumps([r.as_dict() for r in results], indent=2))
    else:
        for result in results:
            print_result(result, quiet=args.quiet)
    return 0 if all(r.ok for r in results) else 1


if __name__ == "__main__":
    sys.exit(main())
