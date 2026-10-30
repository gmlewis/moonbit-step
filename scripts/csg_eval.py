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
    if records[ref].type == "BOOLEAN_RESULT":
        return f"r{ref}"
    return f"s{ref}"


def evaluate(input_path: Path, output_path: Path, timeout: int = 1800) -> str:
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
                else:
                    first = _shape_name(records, step.first)
                    second = _shape_name(records, step.second)
                    commands.append(
                        f"{DRAW_OP[step.op]} r{step.ref} {first} {second}"
                    )
        result = _shape_name(records, roots[0])
        for index, root in enumerate(roots[1:]):
            name = f"fused-{index}"
            commands.append(f"bfuse {name} {result} {_shape_name(records, root)}")
            result = name
        commands.append(f"checkshape {result}")
        commands.append(f'testwritestep "{_tcl_path(output_path)}" {result}')

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
    args = parser.parse_args(argv)

    if not args.input.exists():
        print(f"error: input not found: {args.input}", file=sys.stderr)
        return 2
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    try:
        evaluate(args.input.resolve(), output, timeout=args.timeout)
    except CsgEvalError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    print(f"Wrote {output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
