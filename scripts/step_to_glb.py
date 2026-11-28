#!/usr/bin/env python3
"""Convert an OCCT-readable STEP assembly (and optional exploded.step) into a
high-quality binary glTF (.glb) plus per-node explode animation metadata.

Unlike MoonBit's flat `to_gltf()` writer (which approximates imported vendor
STEPs as bounding boxes and skips smooth curves), this script reads the real
STEP B-Rep with OpenCASCADE (`OCP.STEPCAFControl`), tessellates every solid at
crisp visual quality, preserves part names and colors, and writes a compact
`.glb` via `OCP.RWGltf.RWGltf_CafWriter`.

When `exploded.step` is also present alongside `assembly.step`, it computes the
exact per-part `(dx, dy, dz)` displacement vector (in glTF metres) and optional
role-coded exploded color for every node, writing `explode.json` so
`START-HERE.html`'s Three.js viewer can smoothly animate between Assembled and
Exploded views without duplicating geometry.

Usage:
    python3 scripts/step_to_glb.py build/02
    python3 scripts/step_to_glb.py assembly.step --exploded exploded.step -o assembly.glb
"""

from __future__ import annotations

import argparse
import json
import math
import os
import struct
import sys
from pathlib import Path
from typing import Any

from OCP.Bnd import Bnd_Box
from OCP.BRepBndLib import BRepBndLib
from OCP.BRepMesh import BRepMesh_IncrementalMesh
from OCP.IFSelect import IFSelect_RetDone
from OCP.Message import Message_ProgressRange
from OCP.Quantity import Quantity_Color, Quantity_TOC_RGB
from OCP.RWGltf import RWGltf_CafWriter
from OCP.STEPCAFControl import STEPCAFControl_Reader
from OCP.TColStd import TColStd_IndexedDataMapOfStringString
from OCP.TCollection import TCollection_AsciiString, TCollection_ExtendedString
from OCP.TDataStd import TDataStd_Name
from OCP.TDF import TDF_Label, TDF_LabelSequence
from OCP.TDocStd import TDocStd_Document
from OCP.TopLoc import TopLoc_Location
from OCP.XCAFApp import XCAFApp_Application
from OCP.XCAFDoc import XCAFDoc_ColorGen, XCAFDoc_ColorSurf, XCAFDoc_DocumentTool


def _label_name(label: TDF_Label) -> str:
    attr = TDataStd_Name()
    if label.FindAttribute(TDataStd_Name.GetID_s(), attr):
        return attr.Get().ToExtString()
    return ""


def _label_color(color_tool, label: TDF_Label, shape) -> list[float] | None:
    col = Quantity_Color()
    if shape is not None and not shape.IsNull():
        for ctype in (XCAFDoc_ColorSurf, XCAFDoc_ColorGen):
            if color_tool.GetColor(shape, ctype, col):
                return [round(col.Red(), 4), round(col.Green(), 4), round(col.Blue(), 4)]
    return None


def _shape_center_mm(shape) -> tuple[float, float, float] | None:
    if shape is None or shape.IsNull():
        return None
    box = Bnd_Box()
    BRepBndLib.Add_s(shape, box)
    if box.IsVoid():
        return None
    xmin, ymin, zmin, xmax, ymax, zmax = box.Get()
    return (0.5 * (xmin + xmax), 0.5 * (ymin + ymax), 0.5 * (zmin + zmax))


def _read_step_doc(step_path: Path) -> TDocStd_Document:
    app = XCAFApp_Application.GetApplication_s()
    doc = TDocStd_Document(TCollection_ExtendedString("MDTV-XCAF"))
    app.NewDocument(TCollection_ExtendedString("MDTV-XCAF"), doc)

    reader = STEPCAFControl_Reader()
    reader.SetColorMode(True)
    reader.SetNameMode(True)
    reader.SetLayerMode(True)

    status = reader.ReadFile(str(step_path))
    if status != IFSelect_RetDone:
        raise RuntimeError(f"Failed to read STEP file: {step_path}")
    if not reader.Transfer(doc):
        raise RuntimeError(f"Failed to transfer STEP document: {step_path}")
    return doc


def _collect_leaf_instances(doc: TDocStd_Document) -> list[dict[str, Any]]:
    """Walk the XCAF assembly tree and collect each leaf part's name, world
    bounding-box center (mm), and color in deterministic traversal order."""
    shape_tool = XCAFDoc_DocumentTool.ShapeTool_s(doc.Main())
    color_tool = XCAFDoc_DocumentTool.ColorTool_s(doc.Main())
    leaves: list[dict[str, Any]] = []

    def visit(label: TDF_Label, loc: TopLoc_Location, inherited_name: str, inherited_color):
        own_name = _label_name(label)
        cur_name = own_name or inherited_name

        if shape_tool.IsReference_s(label):
            ref_label = TDF_Label()
            if shape_tool.GetReferredShape_s(label, ref_label):
                inst_loc = loc.Multiplied(shape_tool.GetLocation_s(label))
                ref_shape = shape_tool.GetShape_s(ref_label)
                col = _label_color(color_tool, label, None) or _label_color(color_tool, ref_label, ref_shape) or inherited_color
                visit(ref_label, inst_loc, cur_name, col)
            return

        if shape_tool.IsAssembly_s(label):
            comps = TDF_LabelSequence()
            shape_tool.GetComponents_s(label, comps)
            for idx in range(1, comps.Length() + 1):
                visit(comps.Value(idx), loc, cur_name, inherited_color)
            return

        shape = shape_tool.GetShape_s(label)
        if shape is None or shape.IsNull():
            return
        located = shape.Located(loc)
        center = _shape_center_mm(located)
        col = _label_color(color_tool, label, shape) or inherited_color
        leaves.append({
            "name": cur_name,
            "center_mm": center,
            "color": col,
        })

    roots = TDF_LabelSequence()
    shape_tool.GetFreeShapes(roots)
    for idx in range(1, roots.Length() + 1):
        visit(roots.Value(idx), TopLoc_Location(), "", None)
    return leaves


def _auto_tessellation(shapes: list) -> tuple[float, float]:
    """Choose scale-aware (lin_deflection_mm, ang_deflection_rad) so small parts
    like bearings and fasteners render silky smooth without bloating huge assemblies."""
    box = Bnd_Box()
    for shape in shapes:
        BRepBndLib.Add_s(shape, box)
    if box.IsVoid():
        return (0.05, 0.15)
    xmin, ymin, zmin, xmax, ymax, zmax = box.Get()
    diag = math.sqrt((xmax - xmin) ** 2 + (ymax - ymin) ** 2 + (zmax - zmin) ** 2)
    lin = max(0.01, min(0.25, diag * 0.0006))
    if diag <= 80.0:
        ang = 0.12  # ~6.9 deg (~52 segments/circle) for bearings, screws, small gears
    elif diag <= 250.0:
        ang = 0.18  # ~10.3 deg (~35 segments/circle) for medium parts & assemblies
    else:
        ang = 0.25  # ~14.3 deg (~25 segments/circle) for large assemblies
    return (lin, ang)


def _tessellate_doc(
    doc: TDocStd_Document,
    lin_deflection: float | None,
    ang_deflection: float | None,
) -> None:
    shape_tool = XCAFDoc_DocumentTool.ShapeTool_s(doc.Main())
    roots = TDF_LabelSequence()
    shape_tool.GetFreeShapes(roots)
    shapes = []
    for idx in range(1, roots.Length() + 1):
        shape = shape_tool.GetShape_s(roots.Value(idx))
        if shape is not None and not shape.IsNull():
            shapes.append(shape)
    if not shapes:
        return
    auto_lin, auto_ang = _auto_tessellation(shapes)
    lin = auto_lin if lin_deflection is None else lin_deflection
    ang = auto_ang if ang_deflection is None else ang_deflection
    for shape in shapes:
        BRepMesh_IncrementalMesh(shape, lin, False, ang, True)


def _read_glb_json(glb_path: Path) -> dict[str, Any]:
    data = glb_path.read_bytes()
    if len(data) < 20 or data[:4] != b"glTF":
        raise RuntimeError(f"Invalid GLB header in {glb_path}")
    chunk_len, chunk_type = struct.unpack_from("<II", data, 12)
    if chunk_type != 0x4E4F534A:  # JSON
        raise RuntimeError(f"Expected JSON chunk first in {glb_path}")
    return json.loads(data[20 : 20 + chunk_len].decode("utf-8"))


def _build_explode_metadata(
    asm_leaves: list[dict[str, Any]],
    exp_leaves: list[dict[str, Any]],
    glb_json: dict[str, Any],
) -> dict[str, Any]:
    """Match assembly leaves to exploded leaves 1-to-1 by exact name and emit
    per-node explode vectors (in glTF metres, STEP Z-up frame) plus staged
    animation windows [t0, t1] so outer parts separate first.

    Raises ValueError if assembly.step and exploded.step have mismatched part
    counts or unmatched names (e.g. built with different --detail levels) or
    if sub-parts of a rigid bearing diverge in their explode displacement."""
    if len(asm_leaves) != len(exp_leaves):
        raise ValueError(
            f"assembly.step ({len(asm_leaves)} parts) and exploded.step "
            f"({len(exp_leaves)} parts) do not match — rebuild both with the "
            "same --detail level"
        )

    # Map by exact name occurrence index so duplicate names match 1-to-1.
    exp_by_name: dict[str, list[dict[str, Any]]] = {}
    for leaf in exp_leaves:
        exp_by_name.setdefault(leaf["name"], []).append(leaf)

    name_counts: dict[str, int] = {}
    entries: list[dict[str, Any]] = []
    max_dist = 0.0

    for a_leaf in asm_leaves:
        nm = a_leaf["name"]
        occ = name_counts.get(nm, 0)
        name_counts[nm] = occ + 1

        if nm not in exp_by_name or occ >= len(exp_by_name[nm]):
            raise ValueError(
                f"Part {nm!r} (occurrence {occ}) in assembly.step has no "
                "matching part in exploded.step — rebuild both with the same "
                "--detail level"
            )
        e_leaf = exp_by_name[nm][occ]

        dx = dy = dz = 0.0
        exp_color = None
        if a_leaf["center_mm"] and e_leaf["center_mm"]:
            ac = a_leaf["center_mm"]
            ec = e_leaf["center_mm"]
            dx = (ec[0] - ac[0]) / 1000.0
            dy = (ec[1] - ac[1]) / 1000.0
            dz = (ec[2] - ac[2]) / 1000.0
            exp_color = e_leaf.get("color")

        dist = math.sqrt(dx * dx + dy * dy + dz * dz)
        if dist > max_dist:
            max_dist = dist

        ac_m = (
            [round(a_leaf["center_mm"][0] / 1000.0, 6), round(a_leaf["center_mm"][1] / 1000.0, 6), round(a_leaf["center_mm"][2] / 1000.0, 6)]
            if a_leaf["center_mm"]
            else [0.0, 0.0, 0.0]
        )
        entries.append({
            "name": nm,
            "occurrence": occ,
            "center_gltf": ac_m,
            # RWGltf_CafWriter preserves the STEP Z-up frame (converted from mm to metres).
            "offset_gltf": [round(dx, 6), round(dy, 6), round(dz, 6)],
            "offset_step_mm": [round(dx * 1000.0, 3), round(dy * 1000.0, 3), round(dz * 1000.0, 3)],
            "dist_m": round(dist, 6),
            "explode_color": exp_color,
        })

    # Rigid-bearing invariant: all sub-parts of a bearing (outer-ring,
    # inner-ring, ball-*) sharing the same bearing prefix and occurrence must
    # translate identically so a purchased bearing never breaks apart.
    bearing_groups: dict[tuple[str, int], list[tuple[str, list[float]]]] = {}
    for entry in entries:
        nm = entry["name"]
        if "bearing-" in nm and "/" in nm:
            prefix = nm.rsplit("/", 1)[0]
            bearing_groups.setdefault((prefix, entry["occurrence"]), []).append(
                (nm, entry["offset_gltf"])
            )
    for (prefix, occ), members in bearing_groups.items():
        ref_nm, ref_off = members[0]
        for mem_nm, mem_off in members[1:]:
            delta = max(abs(a - b) for a, b in zip(ref_off, mem_off))
            if delta > 1e-4:
                raise ValueError(
                    f"Rigid bearing {prefix!r} (occ {occ}) broke apart during "
                    f"explode: {ref_nm} offset={ref_off} vs {mem_nm} offset={mem_off}"
                )

    # Compute staged animation windows [start, end] in [0, 1]:
    # Farther parts start moving immediately (t0 ≈ 0.0) and finish around 0.85–1.0;
    # inner parts start slightly later (up to t0 ≈ 0.25) so covers/screws clear
    # before inner gears slide out, and reverse cleanly on Assemble.
    for entry in entries:
        if max_dist > 1e-6 and entry["dist_m"] > 1e-6:
            frac = entry["dist_m"] / max_dist  # 0 = inner, 1 = outermost
            t0 = round(0.28 * (1.0 - frac), 3)
            t1 = round(min(1.0, t0 + 0.72), 3)
        else:
            t0, t1 = 0.0, 1.0
        entry["window"] = [t0, t1]

    # Build quick lookup by name -> list of entries (with assembled center for exact spatial matching)
    by_name: dict[str, list[dict[str, Any]]] = {}
    for entry in entries:
        by_name.setdefault(entry["name"], []).append({
            "center": entry["center_gltf"],
            "offset": entry["offset_gltf"],
            "window": entry["window"],
            "color": entry["explode_color"],
        })

    return {
        "version": 1,
        "node_count": len(glb_json.get("nodes", [])),
        "leaf_count": len(entries),
        "max_offset_mm": round(max_dist * 1000.0, 2),
        "parts": by_name,
    }


def export_step_to_glb(
    assembly_step: Path,
    out_glb: Path,
    exploded_step: Path | None = None,
    explode_json: Path | None = None,
    lin_deflection: float | None = None,
    ang_deflection: float | None = None,
) -> tuple[int, int]:
    """Export `assembly_step` to `out_glb` (and optional `explode_json`).
    Returns (glb_bytes, part_count)."""
    asm_doc = _read_step_doc(assembly_step)
    _tessellate_doc(asm_doc, lin_deflection, ang_deflection)

    out_glb.parent.mkdir(parents=True, exist_ok=True)
    writer = RWGltf_CafWriter(TCollection_AsciiString(str(out_glb)), True)
    file_info = TColStd_IndexedDataMapOfStringString()
    ok = writer.Perform(asm_doc, file_info, Message_ProgressRange())
    if not ok or not out_glb.exists():
        raise RuntimeError(f"RWGltf_CafWriter failed for {assembly_step}")

    part_count = 0
    if exploded_step is not None and exploded_step.exists() and explode_json is not None:
        asm_leaves = _collect_leaf_instances(asm_doc)
        exp_doc = _read_step_doc(exploded_step)
        exp_leaves = _collect_leaf_instances(exp_doc)
        glb_json = _read_glb_json(out_glb)
        meta = _build_explode_metadata(asm_leaves, exp_leaves, glb_json)
        part_count = meta["leaf_count"]
        explode_json.write_text(json.dumps(meta, separators=(",", ":")), encoding="utf-8")

    return out_glb.stat().st_size, part_count


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Convert STEP assembly to high-quality GLB + explode metadata.")
    parser.add_argument("input", help="Build package directory (containing assembly.step) or a .step file")
    parser.add_argument("-o", "--out", help="Output .glb path (default: <dir>/assembly.glb)")
    parser.add_argument("--exploded", help="Optional exploded.step path (default: <dir>/exploded.step if present)")
    parser.add_argument("--explode-json", help="Output explode.json path (default: <dir>/explode.json)")
    parser.add_argument("--lin-deflection", type=float, default=None, help="Linear tessellation deflection in mm (default: auto by part size)")
    parser.add_argument("--ang-deflection", type=float, default=None, help="Angular tessellation deflection in radians (default: auto by part size)")
    args = parser.parse_args(argv)

    inp = Path(args.input)
    if inp.is_dir():
        asm_path = inp / "assembly.step"
        out_glb = Path(args.out) if args.out else (inp / "assembly.glb")
        exp_path = Path(args.exploded) if args.exploded else (inp / "exploded.step")
        exp_json = Path(args.explode_json) if args.explode_json else (inp / "explode.json")
    else:
        asm_path = inp
        out_glb = Path(args.out) if args.out else inp.with_suffix(".glb")
        exp_path = Path(args.exploded) if args.exploded else None
        exp_json = Path(args.explode_json) if args.explode_json else (out_glb.parent / "explode.json")

    if not asm_path.exists():
        print(f"error: assembly STEP not found: {asm_path}", file=sys.stderr)
        return 1

    size, parts = export_step_to_glb(
        asm_path,
        out_glb,
        exploded_step=exp_path if (exp_path and exp_path.exists()) else None,
        explode_json=exp_json,
        lin_deflection=args.lin_deflection,
        ang_deflection=args.ang_deflection,
    )
    print(f"  {out_glb} ({size / 1024:.1f} KiB, {parts} animated parts)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
