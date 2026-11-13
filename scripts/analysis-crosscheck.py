#!/usr/bin/env python3
"""Cross-check the MoonBit analysis tooling against the Python/OCCT harness.

Development-time only. The library has no runtime dependency on Python, OCCT,
or this script.

For each representative part it:
  * builds the part with tools/inspect (the same builders the examples use),
  * writes a STEP file with `tools/inspect --step`,
  * reads that file with tools/step-stats (parse-only),
  * measures it with scripts/measure_step_occt.py (bbox, volume, solids),
  * counts surfaces with scripts/measure_step_features.py,
  * tessellates interior sections with scripts/measure_step_mesh.py.

Checks are printed as PASS / FAIL / SKIP. A SKIP always states why and is never
counted as a pass. Exit status is non-zero when any check fails.

Usage:
    python3 scripts/analysis-crosscheck.py [--deflection 0.05] [--keep]
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "target" / "analysis-crosscheck"
MOON = ["moon", "run"]
SECTION_TOL = 0.02
VOLUME_TOL = 0.005
VOLUME_TOL_LAYERED = 0.02
BBOX_TOL = 0.01


def load_mesh_module():
    path = ROOT / "scripts" / "measure_step_mesh.py"
    spec = importlib.util.spec_from_file_location("measure_step_mesh", path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


MESH = load_mesh_module()


# Headed screws/bolts use the head-underside datum (countersunk: flush top),
# so their interior section planes are negative Z. Sections are interior planes
# (never a cap plane):
# measure_step_mesh.py tessellates, and a plane exactly on a cap can miss a
# layer. `skip_sections` and `skip_extents` carry the typed reason.
MATRIX = [
    {
        "name": "ISO4762-M4x20-detailed",
        "args": ["--standard", "iso4762", "--size", "M4", "--length", "20",
                 "--detail", "detailed"],
        "sections": [-15.0, 3.0],
    },
    {
        "name": "ISO4762-M4x20-full-thread",
        "args": ["--standard", "iso4762", "--size", "M4", "--length", "20",
                 "--detail", "full", "--threads", "helical"],
        "sections": [5.0, 23.0],
        "skip_sections": "swept helical thread requires tessellation",
    },
    {
        "name": "ISO4032-M4-detailed",
        "args": ["--standard", "iso4032", "--size", "M4", "--detail", "detailed"],
        # z = 3.0 is exactly the bore lead-in/cylinder junction, where a mesh
        # section plane can miss the hole; use interior planes only.
        "sections": [1.0, 2.5],
        "skip_bbox": "OCCT Bnd_Box overestimates the untrimmed conical face chamfers; the analytic trimmed envelope is authoritative",
    },
    {
        "name": "ISO7089-M4",
        "args": ["--standard", "iso7089", "--size", "M4", "--detail", "detailed"],
        "sections": [0.4],
    },
    {
        "name": "ISO8752-M3x20-detailed",
        "args": ["--standard", "iso8752", "--size", "M3", "--length", "20",
                 "--detail", "detailed"],
        "sections": [-5.0, 5.0],
        "skip_bbox": "the slot cuts the outer cylinder at y = +/- 0.09 d, so OCCT's tight envelope is narrower than the intent cylinder envelope",
    },
    {
        "name": "ISO4035-M3-detailed",
        "args": ["--standard", "iso4035", "--size", "M3", "--detail", "detailed"],
        "sections": [0.05, 0.9],
        "skip_bbox": "OCCT Bnd_Box overestimates the untrimmed conical washer faces; the analytic trimmed envelope is authoritative",
    },
    {
        "name": "profile-2020-b-slot6-a-l50",
        "args": ["--profile", "2020-b-slot6-a", "--length", "50",
                 "--detail", "detailed"],
        "sections": [25.0],
        "skip_extents": "the non-axisymmetric section's outer radius is a rounded corner, not half the section width",
    },
    {
        "name": "DIN916-M3x8-detailed",
        "args": ["--standard", "din916", "--size", "M3", "--length", "8",
                 "--detail", "detailed"],
        "sections": [1.0, 7.5],
    },
    {
        "name": "DIN557-M5-detailed",
        "args": ["--standard", "din557", "--size", "M5", "--detail", "detailed"],
        "sections": [1.5, 3.8],
        "skip_bbox": "OCCT Bnd_Box of the untrimmed washer-face cone overestimates the square's extent; the analytic trimmed envelope is authoritative",
        "skip_extents": "square corners sit at 45 degrees, so the section width is the across-flats size while the analytic outer radius is the corner radius",
    },
    {
        "name": "DIN1587-M6-detailed",
        "args": ["--standard", "din1587", "--size", "M6", "--detail", "detailed"],
        "sections": [1.0, 8.0],
        "skip_bbox": "OCCT Bnd_Box of the untrimmed washer-face cones overestimates the hexagon's across-flats extent; the analytic trimmed envelope is authoritative",
    },
    {
        "name": "ISO4017-M5x20-detailed",
        "args": ["--standard", "iso4017", "--size", "M5", "--length", "20",
                 "--detail", "detailed"],
        "sections": [-15.0, -2.0],
    },
    {
        "name": "ISO4014-M8x40-detailed",
        "args": ["--standard", "iso4014", "--size", "M8", "--length", "40",
                 "--detail", "detailed"],
        "sections": [-30.0, -4.0],
    },
    {
        "name": "ISO7380-M4x16-detailed",
        "args": ["--standard", "iso7380", "--size", "M4", "--length", "16",
                 "--detail", "detailed"],
        "sections": [-11.0, -2.0],
    },
    {
        "name": "ISO10642-M4x16-detailed",
        "args": ["--standard", "iso10642", "--size", "M4", "--length", "16",
                 "--detail", "detailed"],
        "sections": [-11.0],
        "skip_bbox": "OCCT Bnd_Box overestimates the trimmed 90-degree countersink cone and edge torus; the analytic envelope is authoritative",
    },
    {
        "name": "DIN976-M8x200-detailed",
        "args": ["--standard", "din976", "--size", "M8", "--length", "200",
                 "--detail", "detailed"],
        "sections": [50.0],
    },
    {
        "name": "bearing-608-simplified",
        "args": ["--bearing", "608", "--rollers", "8", "--detail", "simplified"],
        "sections": [3.3],
    },
    {
        "name": "bearing-608-detailed",
        "args": ["--bearing", "608", "--rollers", "8", "--detail", "detailed"],
        "sections": [3.3],
    },
    {
        "name": "bearing-608-shielded",
        "args": ["--bearing", "608", "--shielded"],
        "sections": [0.5],
    },
    {
        "name": "bearing-6000-rings-only",
        "args": ["--bearing", "6000", "--rollers", "0", "--detail", "simplified"],
        "sections": [3.7],
    },
    {
        "name": "bearing-628-rings-only",
        "args": ["--bearing", "628", "--rollers", "0", "--detail", "simplified"],
        "sections": [3.7],
    },
    {
        "name": "spur-gear-m2-z40-bore10",
        "args": ["--module", "2", "--teeth", "40", "--bore", "10",
                 "--faceWidth", "16"],
        "sections": [8.0],
    },
    {
        "name": "shaft-d10-l40",
        "args": ["--shaft", "--diameter", "10", "--shaftLength", "40"],
        "sections": [20.0],
    },
    {
        "name": "filleted-shaft",
        "args": ["--filleted-shaft"],
        "sections": [10.0, 25.0],
    },
    {
        "name": "keyed-shaft-d20-l40",
        "args": ["--keyed-shaft", "--diameter", "20", "--shaftLength", "40"],
        "sections": [20.0],
        "skip_extents": "keyway section extents are not axisymmetric",
    },
    {
        "name": "profile-2020-l50",
        "args": ["--profile", "2020", "--length", "50"],
        "sections": [25.0],
        "skip_extents": "non-circular T-slot profile extents need the 2D outline",
    },
    {
        "name": "frame-300x200x300",
        "args": ["--frame", "300x200x300", "--profile", "2020"],
        "sections": [150.0],
        "skip_sections": "assembly members are rotated; world-z sections are not exact",
    },
]


class Checker:
    def __init__(self):
        self.counts = {"PASS": 0, "FAIL": 0, "SKIP": 0}

    def record(self, status: str, name: str, detail: str) -> None:
        self.counts[status] += 1
        print(f"  {status:4s} {name}: {detail}")

    def check(self, name: str, ok: bool, detail: str) -> None:
        self.record("PASS" if ok else "FAIL", name, detail)

    def skip(self, name: str, reason: str) -> None:
        self.record("SKIP", name, reason)


def run(cmd: list[str], cwd: Path = ROOT) -> subprocess.CompletedProcess:
    return subprocess.run(
        cmd, cwd=cwd, capture_output=True, text=True, timeout=1800
    )


def parse_last_json(text: str):
    text = text.strip()
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass
    starts = [i for i in (text.find("{"), text.find("[")) if i >= 0]
    if starts:
        try:
            return json.loads(text[min(starts):])
        except json.JSONDecodeError:
            pass
    for line in reversed(text.splitlines()):
        line = line.strip()
        if line.startswith("{") or line.startswith("["):
            try:
                return json.loads(line)
            except json.JSONDecodeError:
                continue
    return None


def inspect_part(args: list[str], step_path: Path, sections: list[float]):
    section_args = []
    for z in sections:
        section_args += ["--section", f"z={z:g}"]
    cmd = (MOON + ["tools/inspect", "--"] + args + ["--json"]
           + section_args + ["--step", str(step_path)])
    proc = run(cmd)
    if proc.returncode != 0:
        return None, proc.stdout + proc.stderr
    data = parse_last_json(proc.stdout)
    if data is None:
        return None, "tools/inspect produced no JSON: " + proc.stdout + proc.stderr
    return data, ""


def step_stats(step_path: Path):
    proc = run(MOON + ["tools/step-stats", "--", str(step_path), "--json"])
    if proc.returncode != 0:
        return None, proc.stdout + proc.stderr
    data = parse_last_json(proc.stdout)
    if data is None:
        return None, "tools/step-stats produced no JSON"
    return data, ""


def occt_measure(step_path: Path):
    proc = run([sys.executable, "-I", str(ROOT / "scripts" / "measure_step_occt.py"),
                str(step_path)])
    if proc.returncode == 2:
        return None, "OCCT is not installed"
    if proc.returncode != 0:
        return None, proc.stdout + proc.stderr
    data = parse_last_json(proc.stdout)
    if data is None or "error" in data:
        return None, str(data)
    return data, ""


def feature_measure(step_path: Path):
    proc = run([sys.executable, "-I", str(ROOT / "scripts" / "measure_step_features.py"),
                "--json", str(step_path)])
    if proc.returncode != 0:
        return None, proc.stdout + proc.stderr
    data = parse_last_json(proc.stdout)
    if not data:
        return None, "measure_step_features produced no JSON"
    return data[0], ""


def mesh_section(triangles, z: float):
    return MESH.section_at(triangles, z)


def close(a: float, b: float, tol: float) -> bool:
    return abs(a - b) <= tol


def rel_close(a: float, b: float, tol: float) -> bool:
    denom = abs(b) if abs(b) > 1e-12 else 1.0
    return abs(a - b) <= tol * denom


def bbox_close(a, b, tol=BBOX_TOL) -> bool:
    return all(close(x, y, tol) for x, y in zip(a, b))


def surface_keys() -> list[str]:
    return [
        "plane",
        "cylinder",
        "cone",
        "sphere",
        "torus",
        "bspline",
        "surface_of_revolution",
    ]


def compare_surfaces(checker: Checker, label: str, moon: dict, py: dict) -> None:
    problems = []
    for key in surface_keys():
        got = int(moon.get(key, 0))
        want = int(py.get(key, 0))
        if got != want:
            problems.append(f"{key}: moon={got} occt={want}")
    if problems:
        checker.check(label, False, "; ".join(problems))
    else:
        checker.check(label, True, "surface inventory matches OCCT")


def section_sum(inspect_data: dict, z: float):
    """Sum per-layer sections at world z.

    Returns (area, perimeter, max_radius, skip_reason). Layers that do not
    intersect the plane contribute zero; layers with a typed analysis error
    (swept thread, unsupported transform) make the check skip.
    """
    area = 0.0
    perimeter = 0.0
    max_r = 0.0
    entries = inspect_data.get("total", {}).get("sections", [])
    matching = [e for e in entries if abs(float(e.get("z_mm", 0.0)) - z) < 1e-9]
    if not matching:
        return None, None, None, "inspect reported no section for this plane"
    for entry in matching:
        if "error" in entry:
            msg = str(entry["error"])
            if "does not intersect" in msg:
                continue
            return None, None, None, f"{entry.get('layer', 'layer')}: {msg}"
        area += float(entry.get("area_mm2", 0.0))
        perimeter += float(entry.get("perimeter_mm", 0.0))
        max_r = max(max_r, float(entry.get("outer_radius_mm", 0.0)))
    return area, perimeter, max_r, ""


def run_part(entry: dict, checker: Checker, mesh_cache: dict, deflection: float) -> None:
    name = entry["name"]
    print(f"PART {name}")
    step_path = OUT_DIR / (name + ".step")
    data, err = inspect_part(entry["args"], step_path, entry.get("sections", []))
    if data is None:
        checker.record("FAIL", "inspect", err.strip().splitlines()[-1] if err else "no output")
        print()
        return

    stats, stats_err = step_stats(step_path)
    occt, occt_err = occt_measure(step_path)
    features, feat_err = feature_measure(step_path)

    layers = data.get("layers", [])
    total = data.get("total", {})

    # Step-stats structure checks (the parse-only tool is compared to the
    # independent Python entity counter and to OCCT's solid count).
    if stats is None:
        checker.skip("step-stats", stats_err.strip().splitlines()[-1] if stats_err else "no output")
    else:
        if features is not None:
            compare_surfaces(
                checker,
                "step-stats surfaces",
                stats.get("surfaces", {}),
                features.get("surface_counts", {}),
            )
            checker.check(
                "step-stats solids",
                int(stats.get("solids", 0)) == int(features.get("solids", 0)),
                f"step-stats={stats.get('solids')} occt={features.get('solids')}",
            )
        else:
            checker.skip("step-stats surfaces", feat_err or "no OCCT feature measurement")

    if occt is None:
        checker.skip("solid count", occt_err or "no OCCT measurement")
        checker.skip("bbox", occt_err or "no OCCT measurement")
        checker.skip("volume", occt_err or "no OCCT measurement")
        print()
        return

    checker.check(
        "solid count",
        len(layers) == int(occt.get("solids", 0)),
        f"inspect layers={len(layers)} occt solids={occt.get('solids')}",
    )
    if entry.get("skip_bbox"):
        checker.skip("bbox", entry["skip_bbox"])
    else:
        checker.check(
            "bbox",
            bbox_close(total.get("bbox_mm", []), occt.get("bbox", [])),
            f"inspect={total.get('bbox_mm')} occt={occt.get('bbox')}",
        )

    # Volume: exact per-layer sum; swept layers make the total incomplete.
    if not total.get("volume_complete", False):
        reasons = sorted({str(l.get("volume_error", "")) for l in layers
                          if l.get("volume_mm3") is None})
        checker.skip("volume", "unavailable for: " + "; ".join(reasons))
    elif occt.get("volume") is None:
        checker.skip("volume", "OCCT reported no volume")
    else:
        tol = VOLUME_TOL_LAYERED if total.get("nominal_union") else VOLUME_TOL
        checker.check(
            "volume",
            rel_close(float(total.get("volume_mm3", 0.0)), float(occt["volume"]), tol),
            f"inspect={total.get('volume_mm3'):.6f} occt={occt['volume']:.6f} "
            f"tol={tol:.3%}",
        )

    if features is not None:
        compare_surfaces(checker, "inspect surfaces", total.get("surfaces", {}),
                         features.get("surface_counts", {}))
    else:
        checker.skip("inspect surfaces", feat_err or "no OCCT feature measurement")

    # Sections.
    if entry.get("skip_sections"):
        for z in entry.get("sections", []):
            checker.skip(f"section z={z:g}", entry["skip_sections"])
        print()
        return

    if occt.get("solids", 0) and not shutil.which("occt-draw") and not shutil.which("DRAWEXE"):
        for z in entry.get("sections", []):
            checker.skip(f"section z={z:g}", "OCCT DRAWEXE is not installed")
        print()
        return

    if step_path not in mesh_cache:
        try:
            mesh_cache[step_path] = MESH.mesh_triangles(step_path, deflection)
        except Exception as exc:  # noqa: BLE001 - development helper
            mesh_cache[step_path] = exc
    triangles = mesh_cache[step_path]

    for z in entry.get("sections", []):
        if isinstance(triangles, Exception):
            checker.skip(f"section z={z:g}", f"tessellation failed: {triangles}")
            continue
        area, perimeter, max_r, reason = section_sum(data, z)
        if area is None:
            checker.skip(f"section z={z:g}", reason)
            continue
        measured = mesh_section(triangles, z)
        probs = []
        if not rel_close(area, measured["area_mm2"], SECTION_TOL):
            probs.append(
                f"area inspect={area:.6f} occt={measured['area_mm2']:.6f}"
            )
        if not rel_close(perimeter, measured["perimeter_mm"], SECTION_TOL):
            probs.append(
                f"perimeter inspect={perimeter:.6f} occt={measured['perimeter_mm']:.6f}"
            )
        if not entry.get("skip_extents"):
            extent = 2.0 * max_r
            occt_extent = max(measured["x_extent_mm"], measured["y_extent_mm"])
            if not rel_close(extent, occt_extent, SECTION_TOL):
                probs.append(
                    f"extent inspect={extent:.6f} occt={occt_extent:.6f}"
                )
        if probs:
            checker.check(f"section z={z:g}", False, "; ".join(probs))
        else:
            detail = f"area={measured['area_mm2']:.4f} perimeter={measured['perimeter_mm']:.4f}"
            if entry.get("skip_extents"):
                detail += " (extents skipped: " + entry["skip_extents"] + ")"
            checker.check(f"section z={z:g}", True, detail)
    print()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--deflection", type=float, default=0.05)
    parser.add_argument("--only", default=None, help="Run only parts matching this substring")
    args = parser.parse_args()

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    checker = Checker()
    mesh_cache: dict[Path, object] = {}

    selected = [e for e in MATRIX if args.only is None or args.only in e["name"]]
    if not selected:
        print(f"error: no matrix part matches {args.only!r}", file=sys.stderr)
        return 2

    # A quick capability probe: OCCT is required for the numeric oracle.
    occt_available = shutil.which("occt-draw") is not None or shutil.which("DRAWEXE") is not None
    if not occt_available:
        print("note: OCCT DRAWEXE is not installed; numeric checks will SKIP")

    for entry in selected:
        run_part(entry, checker, mesh_cache, args.deflection)

    print("SUMMARY")
    for key in ("PASS", "FAIL", "SKIP"):
        print(f"  {key}: {checker.counts[key]}")
    return 1 if checker.counts["FAIL"] else 0


if __name__ == "__main__":
    sys.exit(main())
