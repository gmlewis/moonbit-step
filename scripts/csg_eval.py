#!/usr/bin/env python3
"""Evaluate the boolean tree in a CSG STEP file into a flat B-Rep STEP.

``Design::to_csg_step()`` writes real STEP booleans (``CSG_SOLID`` /
``BOOLEAN_RESULT``), which OCCT's STEP reader cannot consume directly. This
development-time tool works around the reader: it extracts each leaf
``MANIFOLD_SOLID_BREP`` as a standalone flat STEP document, loads the leaves
into OCCT, folds the tree with ``bfuse``/``bcut``/``bcommon``, and writes the
resulting B-Rep.

OCCT (``DRAWEXE`` or ``occt-draw``) must be installed. The library itself
stays kernel-free; nothing here is a runtime dependency.

Usage:
    python3 scripts/csg_eval.py <input-csg.step> -o <output.step>
"""

from __future__ import annotations

import argparse
import json
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import validate_step as v  # noqa: E402

DRAW_OP = {
    ".UNION.": "bfuse",
    ".DIFFERENCE.": "bcut",
    ".INTERSECTION.": "bcommon",
}

SOLID_TYPES = {"MANIFOLD_SOLID_BREP", "BREP_WITH_VOIDS"}

ENTITY_RE = re.compile(r"^\s*#(\d+)\s*=\s*(.*)$", re.S)
TYPE_RE = re.compile(r"^\s*([A-Z_][A-Z0-9_]*)\s*\(")
DEFAULT_SCHEMA = "('AUTOMOTIVE_DESIGN { 1 0 10303 214 1 1 1 1 }')"


class CsgEvalError(Exception):
    """A malformed or unsupported CSG document."""


@dataclass
class Entity:
    id: int
    type: str
    text: str  # "#id=TYPE(...)"; no trailing semicolon


@dataclass(frozen=True)
class Step:
    """One evaluation step; leaves load, booleans combine two operands."""

    kind: str
    ref: int
    op: str = ""
    first: int = 0
    second: int = 0
    operand: int = 0
    payload: dict | None = None


def parse_records(text: str) -> dict[int, Entity]:
    """Parses the ``#id=ENTITY(...)`` records of a STEP data section."""
    records: dict[int, Entity] = {}
    for stmt in v.split_statements(text):
        m = ENTITY_RE.match(stmt)
        if not m:
            continue
        eid = int(m.group(1))
        body = m.group(2).strip()
        tm = TYPE_RE.match(body)
        records[eid] = Entity(eid, tm.group(1) if tm else "", f"#{eid}={body}")
    return records


def split_top_level(s: str) -> list[str]:
    """Splits on commas that are not inside parentheses or strings."""
    parts: list[str] = []
    depth = 0
    in_string = False
    start = 0
    i = 0
    while i < len(s):
        ch = s[i]
        if in_string:
            if ch == "'":
                if i + 1 < len(s) and s[i + 1] == "'":
                    i += 2
                    continue
                in_string = False
            i += 1
            continue
        if ch == "'":
            in_string = True
        elif ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        elif ch == "," and depth == 0:
            parts.append(s[start:i])
            start = i + 1
        i += 1
    parts.append(s[start:])
    return parts


def entity_args(entity: Entity) -> list[str]:
    i = entity.text.find("(")
    j = entity.text.rfind(")")
    if i < 0 or j < i:
        raise CsgEvalError(f"cannot parse the arguments of #{entity.id}")
    return split_top_level(entity.text[i + 1 : j])


def ref_of(arg: str) -> int:
    arg = arg.strip()
    if not arg.startswith("#"):
        raise CsgEvalError(f"expected an entity reference, got {arg!r}")
    return int(arg[1:])


def boolean_operands(entity: Entity) -> tuple[str, int, int]:
    args = entity_args(entity)
    if len(args) != 4:
        raise CsgEvalError(
            f"BOOLEAN_RESULT #{entity.id} has {len(args)} arguments, expected 4"
        )
    return args[1].strip(), ref_of(args[2]), ref_of(args[3])


def csg_roots(records: dict[int, Entity]) -> list[int]:
    """Returns the boolean-tree root of each CSG_SOLID, in file order."""
    roots: list[int] = []
    for eid in sorted(records):
        entity = records[eid]
        if entity.type != "CSG_SOLID":
            continue
        args = entity_args(entity)
        if len(args) != 2:
            raise CsgEvalError(
                f"CSG_SOLID #{entity.id} has {len(args)} arguments, expected 2"
            )
        roots.append(ref_of(args[1]))
    return roots


def require_single_root(records: dict[int, Entity]) -> int:
    roots = csg_roots(records)
    if not roots:
        raise CsgEvalError(
            "no CSG_SOLID found; generate the file with Design::to_csg_step()"
        )
    if len(roots) > 1:
        raise CsgEvalError(f"expected one CSG_SOLID, found {len(roots)}")
    return roots[0]


def _step_string(arg: str) -> str:
    """Unquotes a STEP string argument and undoubles escaped quotes."""
    arg = arg.strip()
    if len(arg) >= 2 and arg[0] == "'" and arg[-1] == "'":
        arg = arg[1:-1]
    return arg.replace("''", "'")


def edge_feature_operand(entity: Entity) -> tuple[int, dict]:
    args = entity_args(entity)
    if len(args) != 3:
        raise CsgEvalError(
            f"MOONBIT_EDGE_FEATURE #{entity.id} has {len(args)} arguments, "
            "expected 3"
        )
    base_ref = ref_of(args[1])
    try:
        payload = json.loads(_step_string(args[2]))
    except json.JSONDecodeError as exc:
        raise CsgEvalError(
            f"MOONBIT_EDGE_FEATURE #{entity.id} has an invalid payload: {exc}"
        ) from exc
    return base_ref, payload


def evaluation_plan(records: dict[int, Entity], root: int) -> list[Step]:
    """Returns the post-order evaluation steps for one boolean tree."""
    plan: list[Step] = []
    visiting: set[int] = set()

    def visit(ref: int) -> None:
        if ref in visiting:
            raise CsgEvalError(f"cyclic boolean tree at #{ref}")
        entity = records.get(ref)
        if entity is None:
            raise CsgEvalError(f"CSG operand #{ref} is not defined")
        if entity.type == "BOOLEAN_RESULT":
            op, first, second = boolean_operands(entity)
            if op not in DRAW_OP:
                raise CsgEvalError(
                    f"unsupported boolean operator {op} on #{ref}"
                )
            visiting.add(ref)
            visit(first)
            visit(second)
            visiting.discard(ref)
            plan.append(Step("boolean", ref, op, first, second))
        elif entity.type == "MOONBIT_EDGE_FEATURE":
            base_ref, payload = edge_feature_operand(entity)
            visiting.add(ref)
            visit(base_ref)
            visiting.discard(ref)
            plan.append(Step("edge", ref, operand=base_ref, payload=payload))
        elif entity.type in SOLID_TYPES:
            plan.append(Step("leaf", ref))
        else:
            kind = entity.type or "complex entity"
            raise CsgEvalError(f"unsupported CSG operand #{ref} ({kind})")

    visit(root)
    return plan


def _refs(text: str) -> list[int]:
    return [int(x) for x in re.findall(r"#(\d+)", text)]


def _closure(records: dict[int, Entity], seeds: list[int]) -> set[int]:
    seen: set[int] = set()
    stack = list(seeds)
    while stack:
        eid = stack.pop()
        if eid in seen:
            continue
        entity = records.get(eid)
        if entity is None:
            raise CsgEvalError(f"reference to undefined entity #{eid}")
        seen.add(eid)
        stack.extend(_refs(entity.text))
    return seen


def _find_context(records: dict[int, Entity]) -> int:
    candidates = [
        e
        for e in records.values()
        if "GEOMETRIC_REPRESENTATION_CONTEXT" in e.text
    ]
    if not candidates:
        raise CsgEvalError("no GEOMETRIC_REPRESENTATION_CONTEXT found")
    for e in candidates:
        if "GLOBAL_UNIT_ASSIGNED_CONTEXT" in e.text:
            return e.id
    return candidates[0].id


def file_schema(text: str) -> str:
    """Returns the schema argument list, e.g. ``('AUTOMOTIVE_DESIGN {...}')``."""
    for stmt in v.split_statements(text):
        if stmt.strip().upper().startswith("FILE_SCHEMA"):
            i = stmt.find("(")
            j = stmt.rfind(")")
            if i >= 0 and j > i:
                return stmt[i + 1 : j].strip()
    return DEFAULT_SCHEMA


def header_section(text: str) -> str | None:
    """Returns the ``HEADER;`` ... ``ENDSEC;`` block, or ``None``."""
    start = text.find("HEADER;")
    if start < 0:
        return None
    end = text.find("ENDSEC;", start)
    if end < 0:
        return None
    return text[start : end + len("ENDSEC;")]


def preserve_input_header(input_text: str, output_path: Path) -> None:
    """Replaces OCCT's synthetic header with the source design's header.

    ``Design::to_csg_step`` writes the component description and the
    machine-readable feature record into the header (as comment and
    ``FILE_DESCRIPTION`` strings). OCCT's ``testwritestep`` replaces them with
    its own translator strings, so the evaluated artifact would otherwise lose
    the component documentation. The input header is self-contained (its
    strings carry no entity references), so it can be spliced into the
    evaluated file unchanged; the data section is not touched.
    """
    input_header = header_section(input_text)
    if input_header is None:
        return
    output_text = output_path.read_text()
    output_header = header_section(output_text)
    if output_header is None:
        return
    output_path.write_text(output_text.replace(output_header, input_header, 1))


# The largest per-coordinate bounding-box difference accepted when matching an
# evaluated solid to its source layer. A disjoint layer's evaluated bbox equals
# its nominal bbox to within the boolean tolerance; a fused solid matches no
# single layer and is therefore left uncoloured.
COLOR_MATCH_TOL_MM = 0.5


def _shape_bbox(shape) -> list[float] | None:
    """Returns [x0, x1, y0, y1, z0, z1] for a shape, or None when empty.

    ``AddOptimal`` is required for colour matching: smooth B-spline walls can
    inflate the conservative ``Add`` box by millimetres, so a valid one-solid-
    per-layer compound would otherwise fail the 0.5 mm match and lose colours.
    """
    from OCP.Bnd import Bnd_Box
    from OCP.BRepBndLib import BRepBndLib

    box = Bnd_Box()
    BRepBndLib.AddOptimal_s(shape, box)
    if box.IsVoid():
        return None
    x0, y0, z0, x1, y1, z1 = box.Get()
    return [x0, x1, y0, y1, z0, z1]


def _solid_count(shape) -> int:
    from OCP.TopAbs import TopAbs_SOLID
    from OCP.TopExp import TopExp_Explorer

    explorer = TopExp_Explorer(shape, TopAbs_SOLID)
    count = 0
    while explorer.More():
        count += 1
        explorer.Next()
    return count


def colorize_output(output_path: Path, layers_path: Path) -> bool:
    """Restores per-solid presentation colours from the layer records.

    ``testwritestep`` drops presentation styles. When the evaluated result is a
    disjoint compound with one solid per source layer, the layer records let us
    match each solid by bounding box and re-emit the STEP with XCAF colours.
    Returns True when the file was recoloured. Missing OCP, a solid/layer count
    mismatch, or an ambiguous match leaves the uncoloured file unchanged.
    """
    try:
        from OCP.BRepBndLib import BRepBndLib  # noqa: F401
        from OCP.Quantity import Quantity_Color, Quantity_TOC_RGB
        from OCP.STEPCAFControl import (
            STEPCAFControl_Reader,
            STEPCAFControl_Writer,
        )
        from OCP.TCollection import TCollection_ExtendedString
        from OCP.TDF import TDF_Label, TDF_LabelSequence
        from OCP.TDocStd import TDocStd_Document
        from OCP.XCAFApp import XCAFApp_Application
        from OCP.XCAFDoc import XCAFDoc_ColorGen, XCAFDoc_DocumentTool
    except Exception:
        return False
    try:
        layers = json.loads(layers_path.read_text())
    except (OSError, json.JSONDecodeError):
        return False
    if not layers:
        return False

    app = XCAFApp_Application.GetApplication_s()
    doc = TDocStd_Document(TCollection_ExtendedString("XmlXCAF"))
    app.NewDocument(TCollection_ExtendedString("XmlXCAF"), doc)
    reader = STEPCAFControl_Reader()
    reader.SetColorMode(True)
    if reader.ReadFile(str(output_path)) != 1 or not reader.Transfer(doc):
        return False
    shape_tool = XCAFDoc_DocumentTool.ShapeTool_s(doc.Main())
    color_tool = XCAFDoc_DocumentTool.ColorTool_s(doc.Main())

    labels = TDF_LabelSequence()
    shape_tool.GetFreeShapes(labels)
    targets: list[tuple[object, list[float]]] = []
    for i in range(1, labels.Length() + 1):
        label = labels.Value(i)
        if shape_tool.IsAssembly_s(label):
            comps = TDF_LabelSequence()
            shape_tool.GetComponents_s(label, comps)
            for j in range(1, comps.Length() + 1):
                component = comps.Value(j)
                referred = TDF_Label()
                use = component
                if shape_tool.GetReferredShape_s(component, referred):
                    use = referred
                shape = shape_tool.GetShape_s(use)
                bbox = _shape_bbox(shape)
                if bbox is not None and _solid_count(shape) == 1:
                    targets.append((use, bbox))
        else:
            shape = shape_tool.GetShape_s(label)
            bbox = _shape_bbox(shape)
            if bbox is not None and _solid_count(shape) == 1:
                targets.append((label, bbox))
    if len(targets) != len(layers):
        return False

    pairs: list[tuple[float, int, int]] = []
    for target_index, (_label, bbox) in enumerate(targets):
        for layer_index, layer in enumerate(layers):
            layer_bbox = layer.get("bbox") or []
            if len(layer_bbox) != 6:
                return False
            distance = max(
                abs(bbox[k] - float(layer_bbox[k])) for k in range(6)
            )
            pairs.append((distance, target_index, layer_index))
    pairs.sort()
    matched_targets: set[int] = set()
    matched_layers: set[int] = set()
    chosen: dict[int, int] = {}
    for distance, target_index, layer_index in pairs:
        if target_index in matched_targets or layer_index in matched_layers:
            continue
        if distance > COLOR_MATCH_TOL_MM:
            break
        matched_targets.add(target_index)
        matched_layers.add(layer_index)
        chosen[target_index] = layer_index
    if len(chosen) != len(targets):
        return False

    for target_index, (label, _bbox) in enumerate(targets):
        color = layers[chosen[target_index]].get("color") or [0.5, 0.5, 0.5]
        quantity = Quantity_Color(
            float(color[0]), float(color[1]), float(color[2]), Quantity_TOC_RGB
        )
        color_tool.SetColor(label, quantity, XCAFDoc_ColorGen)

    writer = STEPCAFControl_Writer()
    writer.SetColorMode(True)
    if not writer.Transfer(doc):
        return False
    if not writer.Write(str(output_path)):
        return False
    return True



def write_leaf(
    records: dict[int, Entity],
    leaf_ref: int,
    context_ref: int,
    out_path: Path,
    schema: str,
) -> None:
    """Writes one leaf solid as a standalone, readable flat STEP document."""
    selected = _closure(records, [leaf_ref, context_ref])
    next_id = max(records) + 1
    fresh: list[str] = []

    def new(text: str) -> int:
        nonlocal next_id
        eid = next_id
        next_id += 1
        fresh.append(f"#{eid}={text};")
        return eid

    origin = new("CARTESIAN_POINT('',(0.0,0.0,0.0))")
    axis = new("DIRECTION('',(0.0,0.0,1.0))")
    ref_direction = new("DIRECTION('',(1.0,0.0,0.0))")
    placement = new(
        f"AXIS2_PLACEMENT_3D('',#{origin},#{axis},#{ref_direction})"
    )
    application = new(
        "APPLICATION_CONTEXT('core data for automotive mechanical design processes')"
    )
    product_context = new(f"PRODUCT_CONTEXT('',#{application},'mechanical')")
    product = new(f"PRODUCT('operand','operand','',(#{product_context}))")
    formation = new(f"PRODUCT_DEFINITION_FORMATION('','',#{product})")
    definition_context = new(
        f"PRODUCT_DEFINITION_CONTEXT('part definition',#{application},'design')"
    )
    definition = new(f"PRODUCT_DEFINITION('','',#{formation},#{definition_context})")
    definition_shape = new(f"PRODUCT_DEFINITION_SHAPE('','',#{definition})")
    representation = new(
        "ADVANCED_BREP_SHAPE_REPRESENTATION("
        f"'operand',(#{placement},#{leaf_ref}),#{context_ref})"
    )
    new(f"SHAPE_DEFINITION_REPRESENTATION(#{definition_shape},#{representation})")

    lines = [
        "ISO-10303-21;",
        "HEADER;",
        "FILE_DESCRIPTION(('CSG operand'),'2;1');",
        "FILE_NAME('operand.step','1970-01-01T00:00:00',('gmlewis'),"
        "('gmlewis/step'),'gmlewis/step','moonbit','none');",
        f"FILE_SCHEMA({schema});",
        "ENDSEC;",
        "DATA;",
    ]
    lines.extend(f"{records[eid].text};" for eid in sorted(selected))
    lines.extend(fresh)
    lines.extend(["ENDSEC;", "END-ISO-10303-21;"])
    out_path.write_text("\n".join(lines) + "\n")


def _draw_tool() -> str | None:
    return shutil.which("occt-draw") or shutil.which("DRAWEXE")


def _tcl_path(path: Path) -> str:
    return str(path).replace("\\", "\\\\").replace('"', '\\"')


def _shape_name(records: dict[int, Entity], ref: int) -> str:
    if records[ref].type in ("BOOLEAN_RESULT", "MOONBIT_EDGE_FEATURE"):
        return f"r{ref}"
    return f"s{ref}"


def _vec3(v: list[float]) -> tuple[float, float, float]:
    return (float(v[0]), float(v[1]), float(v[2]))


def _length(v: tuple[float, ...]) -> float:
    return math.sqrt(sum(c * c for c in v))


def _norm(v: tuple[float, ...]) -> tuple[float, ...]:
    length = _length(v)
    if length < 1.0e-12:
        return tuple(0.0 for _ in v)
    return tuple(c / length for c in v)


def _dot(a: tuple[float, ...], b: tuple[float, ...]) -> float:
    return sum(x * y for x, y in zip(a, b))


def _bbox_distance(point: tuple[float, float, float], bb) -> float:
    xmin, ymin, zmin, xmax, ymax, zmax = bb
    dx = max(xmin - point[0], 0.0, point[0] - xmax)
    dy = max(ymin - point[1], 0.0, point[1] - ymax)
    dz = max(zmin - point[2], 0.0, point[2] - zmax)
    return math.sqrt(dx * dx + dy * dy + dz * dz)


def edge_bounds(tool: str, leaf_path: Path, timeout: int) -> list[tuple]:
    """Returns ``(index, xmin, ymin, zmin, xmax, ymax, zmax)`` for each edge."""
    with tempfile.TemporaryDirectory(prefix="edge-bounds-") as tmp:
        csv_path = Path(tmp) / "edges.csv"
        script = "\n".join(
            [
                "pload ALL",
                f'testreadstep "{_tcl_path(leaf_path)}" s',
                "set els [explode s E]",
                f'set f [open "{_tcl_path(csv_path)}" w]',
                "set i 0",
                'foreach e $els { incr i; puts $f "$i [bounding $e]" }',
                "close $f",
            ]
        )
        proc = subprocess.run(
            [tool, "-b"],
            input=script + "\n",
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        if not csv_path.exists() or not csv_path.read_text().strip():
            raise CsgEvalError(
                "OCCT could not explode the edge-feature base into edges:\n"
                + _tail(proc.stdout + proc.stderr)
            )
        rows: list[tuple] = []
        for line in csv_path.read_text().splitlines():
            parts = line.split()
            if len(parts) != 7:
                continue
            try:
                index = int(parts[0])
                nums = [float(x) for x in parts[1:]]
            except ValueError:
                continue
            rows.append((index, *nums))
        return rows


def select_edges(
    tool: str,
    leaf_path: Path,
    payload: dict,
    timeout: int,
) -> list[int]:
    """Resolves an `EdgeSelector` JSON payload into 1-based edge indices."""
    selector = payload.get("selector") or {"kind": "all"}
    rows = edge_bounds(tool, leaf_path, timeout)
    if not rows:
        raise CsgEvalError("edge selection found no edges")
    kind = selector.get("kind", "all")
    if kind == "all":
        return [row[0] for row in rows]
    if kind == "indices":
        out: list[int] = []
        for raw in selector.get("indices", []):
            index = int(raw)
            if index < 1 or index > len(rows):
                raise CsgEvalError(
                    f"edge index {index} is out of range 1..{len(rows)}"
                )
            out.append(index)
        return out
    if kind == "direction":
        direction = _norm(_vec3(selector["dir"]))
        tol = math.cos(math.radians(float(selector.get("tol_deg", 1.0))))
        out = []
        for row in rows:
            _index, xmin, ymin, zmin, xmax, ymax, zmax = row
            diag = (xmax - xmin, ymax - ymin, zmax - zmin)
            if _length(diag) < 1.0e-9:
                continue
            if abs(_dot(_norm(diag), direction)) >= tol:
                out.append(row[0])
        return out
    if kind == "near_point":
        point = _vec3(selector["point"])
        radius = float(selector["radius"])
        return [
            row[0] for row in rows if _bbox_distance(point, row[1:]) <= radius
        ]
    raise CsgEvalError(f"unsupported edge selector kind {kind!r}")


def evaluate(
    input_path: Path,
    output_path: Path,
    timeout: int = 1800,
    layers_path: Path | None = None,
) -> str:
    """Evaluates the CSG tree and writes a flat B-Rep STEP file.

    Returns the combined DRAWEXE output. Raises ``CsgEvalError`` on failure.
    """
    tool = _draw_tool()
    if tool is None:
        raise CsgEvalError(
            "neither occt-draw nor DRAWEXE is on PATH (install Open CASCADE)"
        )
    text = input_path.read_text()
    records = parse_records(text)
    roots = csg_roots(records)
    if not roots:
        raise CsgEvalError(
            "no CSG_SOLID found; generate the file with Design::to_csg_step()"
        )
    context_ref = _find_context(records)
    schema = file_schema(text)

    with tempfile.TemporaryDirectory(prefix="csg-eval-") as tmp:
        tmpdir = Path(tmp)
        commands = ["pload ALL"]
        for root in roots:
            for step in evaluation_plan(records, root):
                if step.kind == "leaf":
                    leaf_path = tmpdir / f"leaf-{step.ref}.step"
                    write_leaf(
                        records, step.ref, context_ref, leaf_path, schema
                    )
                    commands.append(
                        f'testreadstep "{_tcl_path(leaf_path)}" s{step.ref}'
                    )
                elif step.kind == "boolean":
                    first = _shape_name(records, step.first)
                    second = _shape_name(records, step.second)
                    commands.append(
                        f"{DRAW_OP[step.op]} r{step.ref} {first} {second}"
                    )
                elif step.kind == "edge":
                    base = _shape_name(records, step.operand)
                    if records[step.operand].type not in SOLID_TYPES:
                        raise CsgEvalError(
                            "edge feature base must be a single solid, "
                            "not a boolean result"
                        )
                    leaf_path = tmpdir / f"leaf-{step.operand}.step"
                    payload = step.payload or {}
                    selected = select_edges(tool, leaf_path, payload, timeout)
                    op = payload.get("op")
                    size = float(payload.get("size", 0.0))
                    commands.append(f"explode {base} E")
                    if op == "fillet":
                        if not selected:
                            raise CsgEvalError(
                                "fillet selector matched no edges"
                            )
                        pairs = " ".join(
                            f"{size} {base}_{index}" for index in selected
                        )
                        commands.append(f"blend r{step.ref} {base} {pairs}")
                    elif op == "chamfer":
                        if len(selected) != 1:
                            raise CsgEvalError(
                                "this OCCT DRAW build exposes 3D chamfer for "
                                "one edge at a time; the selector matched "
                                f"{len(selected)} edges. Select a single edge."
                            )
                        angle = payload.get("angle")
                        if angle is not None and abs(float(angle) - 45.0) > 1e-6:
                            raise CsgEvalError(
                                "angled chamfer needs a reference face; only "
                                "equal-distance (45 degree) chamfers are "
                                "supported"
                            )
                        commands.append(
                            f"chamf r{step.ref} {base} "
                            f"{base}_{selected[0]} {size}"
                        )
                    else:
                        raise CsgEvalError(
                            f"unsupported edge operation {op!r}"
                        )
                else:
                    raise CsgEvalError(f"unsupported step kind {step.kind!r}")
        result = _shape_name(records, roots[0])
        for index, root in enumerate(roots[1:]):
            name = f"fused-{index}"
            commands.append(f"bfuse {name} {result} {_shape_name(records, root)}")
            result = name
        commands.append(f"checkshape {result}")
        commands.append(f'testwritestep "{_tcl_path(output_path)}" {result}')

        if os.environ.get("CSG_EVAL_DEBUG"):
            print("COMMANDS:\n" + "\n".join(commands), file=sys.stderr)

        try:
            proc = subprocess.run(
                [tool, "-b"],
                input="\n".join(commands) + "\n",
                capture_output=True,
                text=True,
                timeout=timeout,
            )
        except subprocess.TimeoutExpired as exc:
            raise CsgEvalError(f"OCCT timed out after {timeout} s") from exc

    output = proc.stdout + proc.stderr
    if "is not a topological shape" in output:
        raise CsgEvalError(
            "OCCT could not load an operand as a topological shape:\n"
            + _tail(output)
        )
    if "This shape seems to be valid" not in output:
        raise CsgEvalError(
            "OCCT checkshape did not report a valid shape:\n" + _tail(output)
        )
    if not output_path.exists() or output_path.stat().st_size == 0:
        raise CsgEvalError("OCCT did not write an output file:\n" + _tail(output))
    if layers_path is not None:
        colorize_output(output_path, layers_path)
    preserve_input_header(text, output_path)
    return output


def _tail(text: str, lines: int = 8) -> str:
    return "\n".join(
        line.strip() for line in text.strip().splitlines()[-lines:] if line.strip()
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Evaluate a CSG STEP boolean tree into a flat B-Rep."
    )
    parser.add_argument("input", type=Path, help="input CSG STEP file")
    parser.add_argument(
        "-o", "--output", required=True, type=Path, help="output B-Rep STEP file"
    )
    parser.add_argument(
        "--timeout", type=int, default=1800, help="OCCT timeout in seconds"
    )
    parser.add_argument(
        "--layers",
        type=Path,
        default=None,
        help=(
            "JSON records of the source layers (name, colour, bounding box); "
            "restores per-solid colours when the result is a disjoint compound"
        ),
    )
    args = parser.parse_args(argv)

    if not args.input.exists():
        print(f"error: input not found: {args.input}", file=sys.stderr)
        return 2
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    try:
        evaluate(
            args.input.resolve(),
            output,
            timeout=args.timeout,
            layers_path=args.layers,
        )
    except CsgEvalError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    print(f"Wrote {output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
