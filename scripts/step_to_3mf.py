#!/usr/bin/env python3
"""Convert a STEP file into an OrcaSlicer-ready, self-documenting 3MF archive.

Uses `solidcraft-cli` when available (preserving per-body meshes and wrapping
multi-body assemblies into a single composite `<object><components>` so
OrcaSlicer / Bambu Studio / PrusaSlicer load print-in-place cartridges
pre-assembled with zero overlap warnings). Falls back to OCCT (`occt-draw` /
`DRAWEXE`) STL tessellation packed into a valid 3MF archive using only the
Python standard library.

Every exported `.3mf` archive embeds full provenance extracted from the source
STEP file's `HEADER;` block (CLI command, ALL parameters including defaults,
component/family/size, repository), any sibling `provenance.json`, git commit
metadata, UTC timestamp, and source STEP SHA-256:
  * Standard 3MF `<metadata>` tags inside `3D/3dmodel.model`
  * Complete structured `Metadata/provenance.json` inside the `.3mf` ZIP
"""

from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path
from xml.sax.saxutils import escape as xml_escape

MODEL_NS = "http://schemas.microsoft.com/3dmanufacturing/core/2015/02"
RELS_NS = "http://schemas.openxmlformats.org/package/2006/relationships"
TYPES_NS = "http://schemas.openxmlformats.org/package/2006/content-types"
PROVENANCE_MEMBER = "Metadata/provenance.json"

CONTENT_TYPES_XML = (
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    f'<Types xmlns="{TYPES_NS}">\n'
    '  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\n'
    '  <Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/>\n'
    '  <Default Extension="json" ContentType="application/json"/>\n'
    "</Types>\n"
)

RELS_XML = (
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    f'<Relationships xmlns="{RELS_NS}">\n'
    '  <Relationship Target="/3D/3dmodel.model" Id="rel0"'
    ' Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/>\n'
    "</Relationships>\n"
)


def _sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def _git_info(cwd: Path) -> dict[str, object]:
    """Best-effort git commit/branch/dirty metadata for provenance."""
    info: dict[str, object] = {}

    def run_git(*args: str) -> str:
        try:
            proc = subprocess.run(
                ["git", *args],
                cwd=str(cwd),
                capture_output=True,
                text=True,
                timeout=5,
            )
            if proc.returncode == 0:
                return proc.stdout.strip()
        except Exception:  # noqa: BLE001
            pass
        return ""

    commit = run_git("rev-parse", "HEAD")
    if commit:
        info["commit"] = commit
        info["short_commit"] = commit[:12]
    branch = run_git("rev-parse", "--abbrev-ref", "HEAD")
    if branch:
        info["branch"] = branch
    status = run_git("status", "--porcelain")
    if commit:
        info["dirty"] = bool(status)
    return info


def parse_step_header(step_path: Path) -> dict[str, object]:
    """Extract self-documentation metadata from a STEP file's HEADER; section."""
    # Only read the leading chunk — STEP HEADER; is always at the very top.
    try:
        with step_path.open("rb") as fh:
            head = fh.read(65536).decode("utf-8", errors="replace")
    except OSError:
        return {}

    endsec = head.find("ENDSEC;")
    header_text = head[:endsec] if endsec != -1 else head
    comments = re.findall(r"/\*(.*?)\*/", header_text, flags=re.DOTALL)

    meta: dict[str, object] = {}
    params: dict[str, str] = {}
    raw_lines: list[str] = []

    field_map = {
        "repository": "repository",
        "example": "example",
        "command": "command",
        "component": "component",
        "standard": "standard",
        "family": "family",
        "size": "size",
        "source": "source",
    }

    for block in comments:
        in_params = False
        for raw in block.splitlines():
            stripped = raw.strip()
            if not stripped:
                continue
            raw_lines.append(stripped)
            if stripped == "Parameters:":
                in_params = True
                continue
            if in_params:
                if raw.startswith(("    ", "\t")) or stripped.startswith("--"):
                    if "=" in stripped:
                        k, v = stripped.split("=", 1)
                        params[k.strip()] = v.strip()
                        continue
                in_params = False

            # Key: Value format (moonbit-17-step @cli.Args::documentation)
            if ":" in stripped and not stripped.startswith(("http://", "https://")):
                k, v = stripped.split(":", 1)
                norm = k.strip().lower()
                if norm in field_map:
                    val = v.strip()
                    if val:
                        meta[field_map[norm]] = val
                    continue

            # key=value format (component metadata lines)
            if "=" in stripped and " " not in stripped.split("=", 1)[0]:
                k, v = stripped.split("=", 1)
                k = k.strip()
                v = v.strip()
                if v:
                    if k == "designation" and "component" not in meta:
                        meta["component"] = v
                    elif k in ("family", "size", "standard") and k not in meta:
                        meta[k] = v
                    else:
                        params[k] = v

    if params:
        meta["parameters"] = params
    if raw_lines:
        meta["step_header_lines"] = raw_lines
    return meta


def build_provenance(
    step_path: Path,
    tool_name: str,
    quality: str,
    lay_flat: bool,
    wrapper_command: str | None = None,
    repo_dir: Path | None = None,
) -> dict[str, object]:
    """Assemble full provenance from STEP header, sibling provenance.json, and git."""
    now_utc = datetime.datetime.now(datetime.timezone.utc).strftime(
        "%Y-%m-%dT%H:%M:%SZ"
    )
    prov: dict[str, object] = {
        "schema_version": 1,
        "created_utc": now_utc,
        "source_step": step_path.name,
        "source_step_sha256": _sha256_file(step_path),
        "mesh_export": {
            "tool": tool_name,
            "quality": quality,
            "lay_on_print_faces": lay_flat,
        },
    }

    # 1. Extract metadata directly from the source STEP HEADER; comment block.
    step_meta = parse_step_header(step_path)
    merged_params: dict[str, str] = {}
    if isinstance(step_meta.get("parameters"), dict):
        merged_params.update(step_meta["parameters"])
    for k, v in step_meta.items():
        if k != "parameters" and v not in (None, "", []):
            prov[k] = v

    # 2. Merge any sibling provenance.json written by MoonBit (e.g. moonbit-19-cad).
    for cand in (
        step_path.parent / "provenance.json",
        step_path.parent.parent / "provenance.json",
    ):
        if cand.is_file():
            try:
                loaded = json.loads(cand.read_text(encoding="utf-8"))
                if isinstance(loaded, dict):
                    for k in (
                        "component",
                        "command",
                        "argv",
                        "elephant_foot_chamfer_mm",
                    ):
                        if k in loaded and loaded[k] not in (None, ""):
                            prov.setdefault(k, loaded[k])
                    if isinstance(loaded.get("parameters"), dict):
                        for pk, pv in loaded["parameters"].items():
                            merged_params.setdefault(str(pk), str(pv))
                break
            except Exception:  # noqa: BLE001
                pass

    if merged_params:
        prov["parameters"] = merged_params

    if wrapper_command:
        if "command" not in prov:
            prov["command"] = wrapper_command
        elif prov["command"] != wrapper_command:
            prov["wrapper_command"] = wrapper_command

    git_root = repo_dir or Path(__file__).resolve().parent.parent
    git_meta = _git_info(git_root)
    if git_meta:
        prov["git"] = git_meta
    return prov


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


def _ensure_json_content_type(ct_bytes: bytes) -> bytes:
    """Ensure `[Content_Types].xml` declares the `json` extension."""
    text = ct_bytes.decode("utf-8", errors="replace")
    if 'Extension="json"' in text:
        return ct_bytes
    insertion = '  <Default Extension="json" ContentType="application/json"/>\n</Types>'
    if "</Types>" in text:
        return text.replace("</Types>", insertion, 1).encode("utf-8")
    return ct_bytes


_RE_MODEL_OPEN = re.compile(rb"<model\b[^>]*>")
_RE_RESOURCES_OPEN = re.compile(rb"<resources\b[^>]*>")
_RE_OBJECT_ID = re.compile(rb'<object\b[^>]*\bid="(\d+)"')
_RE_BUILD_BLOCK = re.compile(rb"<build\b[^>]*>(.*?)</build>", flags=re.DOTALL)
_RE_ITEM_TAG = re.compile(rb"<item\b([^>]*)/?>")
_RE_ATTR = re.compile(rb'(\w+)="([^"]*)"')


def _build_metadata_entries(
    prov: dict[str, object], fallback_title: str
) -> list[tuple[str, str]]:
    """Build ordered (name, value) pairs for 3MF `<metadata>` tags."""
    desc_parts: list[str] = []
    if prov.get("component"):
        desc_parts.append(f"Component: {prov['component']}")
    if prov.get("command"):
        desc_parts.append(f"Command: {prov['command']}")
    if prov.get("wrapper_command"):
        desc_parts.append(f"Wrapper: {prov['wrapper_command']}")
    git_info = prov.get("git")
    if isinstance(git_info, dict) and git_info.get("short_commit"):
        dirty = " (dirty)" if git_info.get("dirty") else ""
        desc_parts.append(f"Git: {git_info['short_commit']}{dirty}")

    mesh_export = prov.get("mesh_export")
    export_tool = (
        mesh_export.get("tool", "step_to_3mf.py")
        if isinstance(mesh_export, dict)
        else "step_to_3mf.py"
    )

    entries: list[tuple[str, str]] = [
        (
            "Title",
            str(prov.get("component") or prov.get("source_step") or fallback_title),
        ),
        ("Application", f"gmlewis/step / {export_tool}"),
        ("CreationDate", str(prov.get("created_utc", ""))),
    ]
    if desc_parts:
        entries.append(("Description", " | ".join(desc_parts)))
    if prov.get("command"):
        entries.append(("MoonBit:Command", str(prov["command"])))
    if prov.get("wrapper_command"):
        entries.append(("MoonBit:WrapperCommand", str(prov["wrapper_command"])))
    if prov.get("repository"):
        entries.append(("MoonBit:Repository", str(prov["repository"])))
    if prov.get("example"):
        entries.append(("MoonBit:Example", str(prov["example"])))
    if prov.get("component"):
        entries.append(("MoonBit:Component", str(prov["component"])))
    if isinstance(prov.get("parameters"), dict) and prov["parameters"]:
        entries.append(
            ("MoonBit:Parameters", json.dumps(prov["parameters"], sort_keys=True))
        )
    if isinstance(git_info, dict) and git_info.get("commit"):
        dirty = " (dirty)" if git_info.get("dirty") else ""
        entries.append(("MoonBit:GitCommit", f"{git_info['commit']}{dirty}"))
    if prov.get("source_step_sha256"):
        entries.append(("MoonBit:SourceStepSHA256", str(prov["source_step_sha256"])))
    return [(k, v) for k, v in entries if v]


def _splice_3dmodel_xml(
    data: bytes, prov: dict[str, object], assembly_name: str
) -> bytes:
    """Surgically inject `<metadata>` tags at the top and wrap multi-body
    `<build><item>` entries at the bottom without DOM-parsing huge meshes."""
    m_model = _RE_MODEL_OPEN.search(data, 0, min(len(data), 16384))
    if m_model is None:
        return data

    # 1. Splice `<metadata>` tags in the tiny header region before `<resources>`.
    m_res = _RE_RESOURCES_OPEN.search(data, m_model.end(), min(len(data), 65536))
    header_end = m_res.start() if m_res is not None else m_model.end()
    header_slice = data[m_model.end() : header_end]

    entries = _build_metadata_entries(prov, assembly_name)
    managed_names = {k for k, _ in entries}

    # Strip any pre-existing tags we are replacing (e.g. Application=SolidCraft).
    def _strip_managed(match: re.Match[bytes]) -> bytes:
        name = match.group(1).decode("utf-8", errors="replace")
        return b"" if name in managed_names else match.group(0)

    cleaned_header = re.sub(
        rb'\s*<metadata\b[^>]*\bname="([^"]*)"[^>]*>.*?</metadata>',
        _strip_managed,
        header_slice,
        flags=re.DOTALL,
    )
    meta_xml = "".join(
        f'\n  <metadata name="{xml_escape(k)}">{xml_escape(v)}</metadata>'
        for k, v in entries
    ).encode("utf-8")

    prefix = data[: m_model.end()] + meta_xml + cleaned_header

    # 2. Check the tail for multi-body `<build><item>` wrapping.
    body_and_tail = data[header_end:]
    tail_scan_start = max(0, len(body_and_tail) - 131072)
    m_build = _RE_BUILD_BLOCK.search(body_and_tail, tail_scan_start)
    if m_build is None:
        return prefix + body_and_tail

    items: list[dict[str, str]] = []
    for im in _RE_ITEM_TAG.finditer(m_build.group(1)):
        attrs = {
            am.group(1).decode("utf-8"): am.group(2).decode("utf-8")
            for am in _RE_ATTR.finditer(im.group(1))
        }
        if "objectid" in attrs:
            items.append(attrs)

    if len(items) <= 1:
        return prefix + body_and_tail

    res_close = body_and_tail.rfind(b"</resources>", tail_scan_start, m_build.start())
    if res_close == -1:
        res_close = body_and_tail.rfind(b"</resources>", 0, m_build.start())
    if res_close == -1:
        return prefix + body_and_tail

    max_id = 0
    for om in _RE_OBJECT_ID.finditer(body_and_tail):
        oid = int(om.group(1))
        if oid > max_id:
            max_id = oid
    assembly_id = str(max_id + 1)

    comp_lines = []
    for it in items:
        extra = (
            f' transform="{xml_escape(it["transform"])}"'
            if "transform" in it
            else ""
        )
        comp_lines.append(
            f'      <component objectid="{xml_escape(it["objectid"])}"{extra}/>'
        )
    asm_xml = (
        f'\n  <object id="{assembly_id}" type="model" name="{xml_escape(assembly_name)}">\n'
        "    <components>\n"
        + "\n".join(comp_lines)
        + "\n    </components>\n  </object>\n"
    ).encode("utf-8")
    new_build = f'<build>\n    <item objectid="{assembly_id}"/>\n  </build>'.encode(
        "utf-8"
    )

    return (
        prefix
        + body_and_tail[:res_close]
        + asm_xml
        + body_and_tail[res_close : m_build.start()]
        + new_build
        + body_and_tail[m_build.end() :]
    )


def postprocess_3mf(three_mf_path: Path, prov: dict[str, object]) -> None:
    """Embed 3MF `<metadata>` tags, `Metadata/provenance.json`, and wrap
    multi-body assemblies into a single pre-assembled object."""
    tmp_path = three_mf_path.with_suffix(".3mf.tmp")
    with (
        zipfile.ZipFile(three_mf_path, "r") as zin,
        zipfile.ZipFile(
            tmp_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=1
        ) as zout,
    ):
        for item in zin.infolist():
            if item.filename == PROVENANCE_MEMBER:
                continue
            data = zin.read(item.filename)
            if item.filename == "[Content_Types].xml":
                data = _ensure_json_content_type(data)
            elif item.filename.lower() == "3d/3dmodel.model":
                data = _splice_3dmodel_xml(data, prov, three_mf_path.stem)
            zout.writestr(item, data)
        zout.writestr(
            PROVENANCE_MEMBER,
            (json.dumps(prov, indent=2, sort_keys=True) + "\n").encode("utf-8"),
        )
    tmp_path.replace(three_mf_path)


def inspect_3mf(three_mf_path: Path) -> int:
    """Print embedded `<metadata>` tags and `Metadata/provenance.json`."""
    if not three_mf_path.is_file():
        print(f"Error: 3MF file not found: {three_mf_path}", file=sys.stderr)
        return 2
    with zipfile.ZipFile(three_mf_path, "r") as zf:
        names = zf.namelist()
        if PROVENANCE_MEMBER in names:
            print(zf.read(PROVENANCE_MEMBER).decode("utf-8"))
            return 0
        for name in names:
            if name.lower() == "3d/3dmodel.model":
                root = ET.fromstring(zf.read(name))
                ns = (
                    root.tag.split("}")[0][1:]
                    if root.tag.startswith("{")
                    else MODEL_NS
                )
                metas = {
                    el.attrib.get("name", ""): (el.text or "")
                    for el in root.findall(f"{{{ns}}}metadata")
                }
                if metas:
                    print(json.dumps(metas, indent=2, sort_keys=True))
                    return 0
    print(f"No metadata found in {three_mf_path}", file=sys.stderr)
    return 1


def export_via_solidcraft(
    tool: str,
    step_path: Path,
    out_path: Path,
    quality: str,
    lay_flat: bool,
    timeout: float,
    wrapper_command: str | None = None,
    repo_dir: Path | None = None,
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
    prov = build_provenance(
        step_path,
        tool_name="solidcraft-cli",
        quality=quality,
        lay_flat=lay_flat,
        wrapper_command=wrapper_command,
        repo_dir=repo_dir,
    )
    postprocess_3mf(out_path, prov)
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

    # Separate disconnected triangle shells into distinct 3MF `<object>` meshes
    # wrapped in a composite `<components>` assembly (matching solidcraft-cli).
    # Keeping each gear/body in its own `<object>` prevents OrcaSlicer's
    # single-mesh polygon slicer from XOR-cancelling adjacent tight-clearance
    # bodies when chordal mesh facets nearly touch.
    parent = list(range(len(verts)))

    def _find(x: int) -> int:
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for v1, v2, v3 in tris:
        r1, r2, r3 = _find(v1), _find(v2), _find(v3)
        if r1 != r2:
            parent[r2] = r1
        if r1 != r3:
            parent[r3] = r1

    shells_map: dict[int, list[tuple[int, int, int]]] = {}
    for tri in tris:
        shells_map.setdefault(_find(tri[0]), []).append(tri)
    shells = sorted(shells_map.values(), key=len, reverse=True)

    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        f'<model unit="millimeter" xml:lang="en-US" xmlns="{MODEL_NS}">',
        "  <resources>",
    ]
    if len(shells) <= 1:
        lines.append(f'    <object id="1" type="model" name="{xml_escape(model_name)}">')
        lines.append("      <mesh>")
        lines.append("        <vertices>")
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
    else:
        part_ids: list[int] = []
        for idx, shell_tris in enumerate(shells, start=1):
            oid = idx
            part_ids.append(oid)
            local_map: dict[int, int] = {}
            local_verts: list[tuple[float, float, float]] = []
            local_tris: list[tuple[int, int, int]] = []
            for a, b, c in shell_tris:
                la = local_map.get(a)
                if la is None:
                    la = len(local_verts)
                    local_map[a] = la
                    local_verts.append(verts[a])
                lb = local_map.get(b)
                if lb is None:
                    lb = len(local_verts)
                    local_map[b] = lb
                    local_verts.append(verts[b])
                lc = local_map.get(c)
                if lc is None:
                    lc = len(local_verts)
                    local_map[c] = lc
                    local_verts.append(verts[c])
                local_tris.append((la, lb, lc))
            lines.append(
                f'    <object id="{oid}" type="model" name="{xml_escape(model_name)}_part_{idx}">'
            )
            lines.append("      <mesh>")
            lines.append("        <vertices>")
            for x, y, z in local_verts:
                lines.append(f'          <vertex x="{x:g}" y="{y:g}" z="{z:g}"/>')
            lines.append("        </vertices>")
            lines.append("        <triangles>")
            for v1, v2, v3 in local_tris:
                lines.append(f'          <triangle v1="{v1}" v2="{v2}" v3="{v3}"/>')
            lines.append("        </triangles>")
            lines.append("      </mesh>")
            lines.append("    </object>")
        asm_id = len(shells) + 1
        lines.append(
            f'    <object id="{asm_id}" type="model" name="{xml_escape(model_name)}">'
        )
        lines.append("      <components>")
        for pid in part_ids:
            lines.append(f'        <component objectid="{pid}"/>')
        lines.extend(
            [
                "      </components>",
                "    </object>",
                "  </resources>",
                "  <build>",
                f'    <item objectid="{asm_id}"/>',
                "  </build>",
                "</model>",
                "",
            ]
        )
    model_xml = "\n".join(lines).encode("utf-8")

    with zipfile.ZipFile(
        out_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=1
    ) as zf:
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
    wrapper_command: str | None = None,
    repo_dir: Path | None = None,
) -> tuple[bool, str]:
    with tempfile.TemporaryDirectory(prefix="occt-3mf-") as tmp:
        stl_path = Path(tmp) / "mesh.stl"
        tcl = (
            "pload ALL\n"
            f"testreadstep {_tcl_quote(str(step_path.resolve()))} a\n"
            f"incmesh a {deflection:g} -parallel\n"
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
    prov = build_provenance(
        step_path,
        tool_name=f"occt (deflection={deflection:g}mm)",
        quality=f"deflection={deflection:g}mm",
        lay_flat=False,
        wrapper_command=wrapper_command,
        repo_dir=repo_dir,
    )
    postprocess_3mf(out_path, prov)
    return True, ""


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Convert a STEP file into a self-documenting OrcaSlicer-ready 3MF archive."
    )
    parser.add_argument("step_path", type=Path, nargs="?", help="Input STEP file")
    parser.add_argument("out_path", type=Path, nargs="?", help="Output .3mf file")
    parser.add_argument(
        "--inspect",
        type=Path,
        default=None,
        help="Print embedded provenance/metadata from an existing .3mf file and exit",
    )
    parser.add_argument(
        "--command",
        default=None,
        help="Optional wrapper command line to record in 3MF provenance",
    )
    parser.add_argument(
        "--repo-dir",
        type=Path,
        default=None,
        help="Optional git repository root for commit provenance",
    )
    parser.add_argument(
        "--quality",
        default=os.environ.get("THREEMF_QUALITY", "fine"),
        help="solidcraft-cli mesh quality: standard, fine, or finest (default: fine)",
    )
    parser.add_argument(
        "--deflection",
        type=float,
        default=float(os.environ.get("STL_DEFLECTION", "0.015")),
        help="OCCT fallback tessellation deflection in mm (default: 0.015)",
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
    parser.add_argument(
        "--backend",
        choices=("auto", "solidcraft", "occt"),
        default=os.environ.get("THREEMF_BACKEND", "auto"),
        help=(
            "Tessellation backend: auto (default: SolidCraft for <15 MB STEP "
            "files with 45s cap, parallel OCCT directly for >=15 MB STEP files), "
            "solidcraft, or occt"
        ),
    )
    args = parser.parse_args(argv)

    if args.inspect is not None:
        return inspect_3mf(args.inspect)

    if args.step_path is None or args.out_path is None:
        parser.error("step_path and out_path are required unless --inspect is used")

    if not args.step_path.is_file():
        print(f"Error: STEP file not found: {args.step_path}", file=sys.stderr)
        return 1

    args.out_path.parent.mkdir(parents=True, exist_ok=True)

    home_sc = Path.home() / "tools" / "bin" / "solidcraft-cli"
    sc = (
        str(home_sc)
        if home_sc.is_file() and os.access(home_sc, os.X_OK)
        else shutil.which("solidcraft-cli")
    )
    occt = shutil.which("occt-draw") or shutil.which("DRAWEXE")
    step_size = args.step_path.stat().st_size
    auto_prefer_occt = (
        args.backend == "auto" and occt is not None and step_size >= 15 * 1024 * 1024
    )

    if sc and args.backend != "occt" and not auto_prefer_occt:
        sc_timeout = (
            min(args.timeout, 45.0)
            if (args.backend == "auto" and occt is not None)
            else args.timeout
        )
        ok, err = export_via_solidcraft(
            sc,
            args.step_path,
            args.out_path,
            args.quality,
            args.lay_flat,
            sc_timeout,
            wrapper_command=args.command,
            repo_dir=args.repo_dir,
        )
        if ok:
            return 0
        if args.backend == "solidcraft":
            print(f"Error: {err}", file=sys.stderr)
            return 1
        print(f"note: {err}; falling back to OCCT", file=sys.stderr)

    if not occt:
        print(
            "Error: neither solidcraft-cli nor occt-draw/DRAWEXE is on PATH.",
            file=sys.stderr,
        )
        return 1

    ok, err = export_via_occt(
        occt,
        args.step_path,
        args.out_path,
        args.deflection,
        args.timeout,
        wrapper_command=args.command,
        repo_dir=args.repo_dir,
    )
    if not ok:
        print(f"Error: {err}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
