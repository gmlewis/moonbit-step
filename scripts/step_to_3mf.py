#!/usr/bin/env python3
"""Convert a STEP file into an OrcaSlicer-ready 3MF archive.

Uses `solidcraft-cli` when available (preserving per-body meshes and wrapping
multi-body assemblies into a single composite `<object><components>` so
OrcaSlicer / Bambu Studio / PrusaSlicer load print-in-place cartridges
pre-assembled with zero overlap warnings). Falls back to OCCT (`occt-draw` /
`DRAWEXE`) STL tessellation packed into a valid 3MF archive using only the
Python standard library.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

MODEL_NS = "http://schemas.microsoft.com/3dmanufacturing/core/2015/02"
RELS_NS = "http://schemas.openxmlformats.org/package/2006/relationships"
TYPES_NS = "http://schemas.openxmlformats.org/package/2006/content-types"

CONTENT_TYPES_XML = (
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    f'<Types xmlns="{TYPES_NS}">\n'
    '  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\n'
    '  <Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/>\n'
    "</Types>\n"
)

RELS_XML = (
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    f'<Relationships xmlns="{RELS_NS}">\n'
    '  <Relationship Target="/3D/3dmodel.model" Id="rel0"'
    ' Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/>\n'
    "</Relationships>\n"
)


def _wrap_multibody_assembly(
    root: ET.Element, ns: str, assembly_name: str
) -> bool:
    """Group multiple top-level `<build><item>` entries into one composite
    `<object><components>` so slicers load multi-body prints pre-assembled."""
    resources = root.find(f"{{{ns}}}resources")
    build = root.find(f"{{{ns}}}build")
    if resources is None or build is None:
        return False
    items = list(build.findall(f"{{{ns}}}item"))
    if len(items) <= 1:
        return False

    used_ids: set[int] = set()
    for obj in resources.findall(f"{{{ns}}}object"):
        raw_id = obj.attrib.get("id")
        if raw_id and raw_id.isdigit():
            used_ids.add(int(raw_id))
    assembly_id = str((max(used_ids) if used_ids else 0) + 1)

    asm_obj = ET.SubElement(
        resources,
        f"{{{ns}}}object",
        {"id": assembly_id, "type": "model", "name": assembly_name},
    )
    comps = ET.SubElement(asm_obj, f"{{{ns}}}components")
    for item in items:
        comp_attrib: dict[str, str] = {"objectid": item.attrib["objectid"]}
        if "transform" in item.attrib:
            comp_attrib["transform"] = item.attrib["transform"]
        ET.SubElement(comps, f"{{{ns}}}component", comp_attrib)
        build.remove(item)

    ET.SubElement(build, f"{{{ns}}}item", {"objectid": assembly_id})
    return True


def postprocess_3mf_assembly(three_mf_path: Path) -> None:
    """Ensure multi-body 3MF files are wrapped as a single pre-assembled object."""
    ET.register_namespace("", MODEL_NS)
    tmp_path = three_mf_path.with_suffix(".3mf.tmp")
    with (
        zipfile.ZipFile(three_mf_path, "r") as zin,
        zipfile.ZipFile(tmp_path, "w", compression=zipfile.ZIP_DEFLATED) as zout,
    ):
        for item in zin.infolist():
            data = zin.read(item.filename)
            if item.filename.lower() == "3d/3dmodel.model":
                try:
                    root = ET.fromstring(data)
                    ns = (
                        root.tag.split("}")[0][1:]
                        if root.tag.startswith("{")
                        else MODEL_NS
                    )
                    if _wrap_multibody_assembly(root, ns, three_mf_path.stem):
                        data = ET.tostring(
                            root, encoding="utf-8", xml_declaration=True
                        )
                except ET.ParseError:
                    pass
            zout.writestr(item, data)
    tmp_path.replace(three_mf_path)


def export_via_solidcraft(
    tool: str,
    step_path: Path,
    out_path: Path,
    quality: str,
    lay_flat: bool,
    timeout: float,
) -> tuple[bool, str]:
    script = [
        {
            "command": "file.insert_step",
            "params": {"path": str(step_path.resolve()), "flatten": True},
        },
        {
            "command": "file.export_3mf",
            "params": {
                "path": str(out_path.resolve()),
                "lay_on_print_faces": lay_flat,
                "quality": quality,
            },
        },
    ]
    out_path.unlink(missing_ok=True)
    with tempfile.TemporaryDirectory(prefix="step-to-3mf-") as tmp:
        script_path = Path(tmp) / "script.json"
        results_path = Path(tmp) / "results.json"
        script_path.write_text(json.dumps(script, indent=2), encoding="utf-8")
        try:
            proc = subprocess.run(
                [
                    tool,
                    "run",
                    str(script_path),
                    "--validation",
                    "off",
                    "--quiet",
                    "--results",
                    "--json-out",
                    str(results_path),
                ],
                capture_output=True,
                text=True,
                timeout=timeout,
            )
        except subprocess.TimeoutExpired:
            return False, f"solidcraft-cli timed out after {timeout:g}s"
        if proc.returncode != 0 or not out_path.is_file() or out_path.stat().st_size == 0:
            detail = (proc.stderr or proc.stdout).strip()
            return False, f"solidcraft-cli failed: {detail}"
    postprocess_3mf_assembly(out_path)
    return True, ""


def binary_stl_to_3mf(stl_path: Path, out_path: Path, model_name: str) -> int:
    """Pack a binary STL mesh into a valid millimeter-unit 3MF archive.

    Returns the triangle count written.
    """
    raw = stl_path.read_bytes()
    if len(raw) < 84:
        raise ValueError(f"STL file too short: {stl_path}")
    tri_count = struct.unpack_from("<I", raw, 80)[0]
    expected = 84 + tri_count * 50
    if len(raw) < expected:
        raise ValueError(
            f"Truncated binary STL: expected {expected} bytes, got {len(raw)}"
        )

    vert_index: dict[tuple[float, float, float], int] = {}
    verts: list[tuple[float, float, float]] = []
    tris: list[tuple[int, int, int]] = []

    offset = 84
    for _ in range(tri_count):
        # Skip 12-byte normal, read 3 vertices (9 floats), skip 2-byte attr
        vals = struct.unpack_from("<9f", raw, offset + 12)
        offset += 50
        idxs = []
        for k in range(3):
            v = (
                round(vals[3 * k], 5),
                round(vals[3 * k + 1], 5),
                round(vals[3 * k + 2], 5),
            )
            idx = vert_index.get(v)
            if idx is None:
                idx = len(verts)
                vert_index[v] = idx
                verts.append(v)
            idxs.append(idx)
        if idxs[0] != idxs[1] and idxs[1] != idxs[2] and idxs[2] != idxs[0]:
            tris.append((idxs[0], idxs[1], idxs[2]))

    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        f'<model unit="millimeter" xml:lang="en-US" xmlns="{MODEL_NS}">',
        "  <resources>",
        f'    <object id="1" type="model" name="{model_name}">',
        "      <mesh>",
        "        <vertices>",
    ]
    for x, y, z in verts:
        lines.append(f'          <vertex x="{x:g}" y="{y:g}" z="{z:g}"/>')
    lines.append("        </vertices>")
    lines.append("        <triangles>")
    for v1, v2, v3 in tris:
        lines.append(f'          <triangle v1="{v1}" v2="{v2}" v3="{v3}"/>')
    lines.extend(
        [
            "        </triangles>",
            "      </mesh>",
            "    </object>",
            "  </resources>",
            "  <build>",
            '    <item objectid="1"/>',
            "  </build>",
            "</model>",
            "",
        ]
    )
    model_xml = "\n".join(lines).encode("utf-8")

    with zipfile.ZipFile(out_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("[Content_Types].xml", CONTENT_TYPES_XML)
        zf.writestr("_rels/.rels", RELS_XML)
        zf.writestr("3D/3dmodel.model", model_xml)
    return len(tris)


def _tcl_quote(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def export_via_occt(
    occt: str,
    step_path: Path,
    out_path: Path,
    deflection: float,
    timeout: float,
) -> tuple[bool, str]:
    with tempfile.TemporaryDirectory(prefix="occt-3mf-") as tmp:
        stl_path = Path(tmp) / "mesh.stl"
        tcl = (
            "pload ALL\n"
            f"testreadstep {_tcl_quote(str(step_path.resolve()))} a\n"
            f"incmesh a {deflection:g}\n"
            f"writestl a {_tcl_quote(str(stl_path))}\n"
            "exit\n"
        )
        try:
            proc = subprocess.run(
                [occt],
                input=tcl,
                capture_output=True,
                text=True,
                timeout=timeout,
            )
        except subprocess.TimeoutExpired:
            return False, f"OCCT timed out after {timeout:g}s"
        if proc.returncode != 0 or not stl_path.is_file() or stl_path.stat().st_size < 84:
            detail = (proc.stderr or proc.stdout).strip().splitlines()[-5:]
            return False, "OCCT failed: " + "\n".join(detail)
        binary_stl_to_3mf(stl_path, out_path, out_path.stem)
    return True, ""


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Convert a STEP file into an OrcaSlicer-ready 3MF archive."
    )
    parser.add_argument("step_path", type=Path, help="Input STEP file")
    parser.add_argument("out_path", type=Path, help="Output .3mf file")
    parser.add_argument(
        "--quality",
        default=os.environ.get("THREEMF_QUALITY", "fine"),
        help="solidcraft-cli mesh quality: standard, fine, or finest (default: fine)",
    )
    parser.add_argument(
        "--deflection",
        type=float,
        default=float(os.environ.get("STL_DEFLECTION", "0.05")),
        help="OCCT fallback tessellation deflection in mm (default: 0.05)",
    )
    parser.add_argument(
        "--lay-flat",
        action="store_true",
        help="Re-orient bodies onto print faces (disabled by default to preserve STEP pose)",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=180.0,
        help="Subprocess timeout in seconds (default: 180)",
    )
    args = parser.parse_args(argv)

    if not args.step_path.is_file():
        print(f"Error: STEP file not found: {args.step_path}", file=sys.stderr)
        return 1

    args.out_path.parent.mkdir(parents=True, exist_ok=True)

    sc = shutil.which("solidcraft-cli")
    if sc:
        ok, err = export_via_solidcraft(
            sc,
            args.step_path,
            args.out_path,
            args.quality,
            args.lay_flat,
            args.timeout,
        )
        if ok:
            return 0
        print(f"note: {err}; falling back to OCCT", file=sys.stderr)

    occt = shutil.which("occt-draw") or shutil.which("DRAWEXE")
    if not occt:
        print(
            "Error: neither solidcraft-cli nor occt-draw/DRAWEXE is on PATH.",
            file=sys.stderr,
        )
        return 1

    ok, err = export_via_occt(
        occt, args.step_path, args.out_path, args.deflection, args.timeout
    )
    if not ok:
        print(f"Error: {err}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
