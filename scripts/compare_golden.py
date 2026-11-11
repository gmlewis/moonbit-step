#!/usr/bin/env python3
"""Compare parametric components against golden-reference fixtures.

This is a development-time harness. It never becomes a runtime dependency of
the MoonBit component library.

For every manifest fixture that carries a ``generation`` block it:

1. verifies the golden file record and checksum;
2. verifies the external fixture's SHA-256 and byte size when the file is
   present;
3. re-measures the downloaded golden file with Open CASCADE when it is present
   (otherwise the external comparison is ``SKIP``);
4. generates the corresponding parametric part through the example CLI (never
   by calling internal dimension functions);
5. normalises to millimetres and the repository's Z-up frame;
6. measures the parametric part with Open CASCADE (solid count, bounding box,
   volume) and the STEP text (surface types, cone/sphere/torus parameters,
   vertex radii);
7. checks the manifest's normative dimensions and feature expectations;
8. prints ``PASS`` / ``FAIL`` / ``SKIP`` per check and per fixture.

A skipped check is never reported as a pass. When OCCT is unavailable the
essential geometric checks are ``SKIP`` and the fixture verdict is ``SKIP``.

Usage:
    python3 scripts/compare_golden.py                     # all fixtures
    python3 scripts/compare_golden.py --fixture bearings/608zz
    python3 scripts/compare_golden.py --json
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import measure_step_mesh as msm  # noqa: E402

ROOT_DEFAULT = Path(__file__).resolve().parent.parent
MANIFEST_DEFAULT = ROOT_DEFAULT / "components/testdata/golden/manifest.json"
EXTERNAL_DEFAULT = ROOT_DEFAULT / "components/testdata/golden/external"
TOLERANCE_DEFAULT = {
    "linear_mm": 0.01,
    "volume_relative": 0.05,
    "contact_mm": 0.001,
    "surface_deviation_mm": 0.01,
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def run_json(script: Path, *args: str) -> dict | list:
    proc = subprocess.run(
        [sys.executable, str(script), *args],
        capture_output=True,
        text=True,
        timeout=1800,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or proc.stdout.strip())
    return json.loads(proc.stdout)


def measure_occt(path: Path, root: Path) -> dict:
    result = run_json(root / "scripts/measure_step_occt.py", str(path))
    if isinstance(result, dict) and "error" in result:
        raise RuntimeError(result["error"])
    return result  # type: ignore[return-value]


def measure_features(path: Path, root: Path) -> dict:
    result = run_json(
        root / "scripts/measure_step_features.py", "--json", str(path)
    )
    return result[0]  # type: ignore[index]


def bbox_extents(bbox: list[float]) -> list[float]:
    return [bbox[1] - bbox[0], bbox[3] - bbox[2], bbox[5] - bbox[4]]


_UNIT_TO_MM = {"mm": 1.0, "millimetre": 1.0, "millimeter": 1.0,
               "cm": 10.0, "m": 1000.0, "inch": 25.4, "in": 25.4}


def normalize_extents(bbox: list[float], frame: dict | None) -> list[float]:
    """Normalize a measured bbox to the repository frame (mm, Z-up).

    `frame` is an optional manifest record:
    ``{"units": "mm", "up_axis": "z"}``. Lengths are scaled to millimetres and,
    for a Y-up reference, the measured Y and Z extents are swapped. This is a
    declared-frame conversion, not a heuristic: an unknown unit or axis raises.
    """
    extents = bbox_extents(bbox)
    if not frame:
        return extents
    units = str(frame.get("units", "mm")).lower()
    if units not in _UNIT_TO_MM:
        raise RuntimeError(f"unknown reference units {units!r}")
    scale = _UNIT_TO_MM[units]
    extents = [e * scale for e in extents]
    up = str(frame.get("up_axis", "z")).lower()
    if up == "y":
        # Y-up -> Z-up: the reference (X, Y, Z) maps to (X, Z, Y).
        extents = [extents[0], extents[2], extents[1]]
    elif up != "z":
        raise RuntimeError(f"unknown reference up axis {up!r}")
    return extents


def check(condition: bool, detail: str, skipped: bool = False) -> dict:
    if skipped:
        return {"status": "SKIP", "detail": detail}
    return {"status": "PASS" if condition else "FAIL", "detail": detail}


def generate_part(
    manifest_fixture: dict,
    out_dir: Path,
    root: Path,
    override_args: list[str] | None = None,
    override_output: str | None = None,
) -> Path:
    generation = manifest_fixture.get("generation") or {}
    tool = generation.get("tool")
    if not tool:
        raise RuntimeError("fixture has no generation tool")
    output = override_output or generation.get("output")
    if not output:
        raise RuntimeError("fixture generation has no output name")
    out_path = out_dir / output
    args = [
        arg.replace("{out}", str(out_path))
        for arg in (override_args or generation.get("args", []))
    ]
    cmd = ["moon", "run", "--target", "native", tool, "--", *args]
    proc = subprocess.run(
        cmd, cwd=str(root), capture_output=True, text=True, timeout=1800
    )
    if proc.returncode != 0:
        raise RuntimeError(
            f"generation failed ({' '.join(cmd)}): "
            f"{proc.stderr.strip() or proc.stdout.strip()}"
        )
    if not out_path.exists():
        raise RuntimeError(f"generation wrote no file at {out_path}")
    return out_path


def check_recorded_reference(
    fixture: dict, measured: dict, tolerance: dict
) -> dict:
    """Compare the recorded external measurements with a fresh OCCT measurement."""
    recorded = fixture.get("measured_dimensions") or {}
    recorded_bbox = recorded.get("bbox_mm")
    if not recorded_bbox:
        return check(True, "no recorded bbox", skipped=True)
    try:
        extents = normalize_extents(measured["bbox"], fixture.get("reference_frame"))
    except RuntimeError as exc:
        return check(False, str(exc))
    failures = [
        f"axis {i}: {extents[i]:.4f} vs {recorded_bbox[i]:.4f} mm"
        for i in range(3)
        if abs(extents[i] - recorded_bbox[i]) > tolerance["linear_mm"]
    ]
    solids_ok = measured["solids"] == recorded.get("solids")
    volume_ok = True
    if measured.get("volume") is not None and recorded.get("volume_mm3"):
        rel = abs(measured["volume"] - recorded["volume_mm3"]) / max(
            recorded["volume_mm3"], 1e-9
        )
        volume_ok = rel <= tolerance["volume_relative"]
        if not volume_ok:
            failures.append(f"volume rel {rel:.4f}")
    if not solids_ok:
        failures.append(f"solids {measured['solids']} vs {recorded.get('solids')}")
    detail = "recorded reference matches" if not failures else "; ".join(failures)
    return check(not failures, detail)


def check_feature_spec(
    spec: dict, features: dict, tolerance: dict
) -> dict:
    kind = spec.get("kind")
    if kind == "vertex_ring":
        rings = features.get("vertex_rings") or []
        tol = spec.get("tol_mm", tolerance["linear_mm"])
        min_count = spec.get("min_count", 1)
        ok = any(
            abs(r["z_mm"] - spec["z_mm"]) <= tol
            and abs(r["radius_mm"] - spec["radius_mm"]) <= tol
            and r["count"] >= min_count
            for r in rings
        )
        return check(
            ok,
            f"ring at z={spec['z_mm']} r={spec['radius_mm']} n>={min_count}",
        )
    if kind == "sphere_radius_present_mm":
        spheres = features.get("spheres") or []
        tol = spec.get("tol_mm", tolerance["linear_mm"])
        radii = [
            s["radius"] for s in spheres if s.get("radius") is not None
        ]
        ok = any(abs(r - spec["expected"]) <= tol for r in radii)
        return check(
            ok,
            f"sphere radius {spec['expected']:.4f} present among "
            f"{len(radii)} spheres {[round(r, 4) for r in radii[:4]]}",
        )
    if kind == "surface_min":
        surface = spec["surface"]
        count = (features.get("surface_counts") or {}).get(surface, 0)
        return check(
            count >= spec["min_count"],
            f"{surface} count {count} >= {spec['min_count']}",
        )
    if kind == "cylinder_radius_present_mm":
        cylinders = features.get("cylinders") or []
        tol = spec.get("tol_mm", tolerance["linear_mm"])
        radii = [c["radius"] for c in cylinders if c.get("radius") is not None]
        ok = any(abs(r - spec["expected"]) <= tol for r in radii)
        return check(
            ok,
            f"cylinder radius {spec['expected']:.4f} present among "
            f"{len(radii)} cylinders {[round(r, 4) for r in radii[:6]]}",
        )
    if kind == "min_vertex_radius_mm":
        value = features.get("min_vertex_radius")
        tol = spec.get("tol_mm", tolerance["linear_mm"])
        if value is None:
            return check(False, "no vertex radii")
        return check(
            abs(value - spec["expected"]) <= tol,
            f"min vertex radius {value:.4f} vs {spec['expected']:.4f} mm",
        )
    if kind == "max_vertex_radius_mm":
        value = features.get("max_vertex_radius")
        tol = spec.get("tol_mm", tolerance["linear_mm"])
        if value is None:
            return check(False, "no vertex radii")
        return check(
            abs(value - spec["expected"]) <= tol,
            f"max vertex radius {value:.4f} vs {spec['expected']:.4f} mm",
        )
    if kind == "cone_semi_angle_deg":
        cones = features.get("cones") or []
        angles = [
            c.get("semi_angle_deg")
            for c in cones
            if c.get("semi_angle_deg") is not None
        ]
        tol = spec.get("tol_deg", 0.5)
        ok = any(abs(a - spec["expected"]) <= tol for a in angles)
        return check(
            ok,
            f"cone half-angles {[round(a, 4) for a in angles]} vs {spec['expected']} deg",
        )
    if kind == "cone_min_count":
        cones = features.get("cones") or []
        return check(
            len(cones) >= spec["min_count"],
            f"cone count {len(cones)} >= {spec['min_count']}",
        )
    if kind == "vertex_radius_present_mm":
        clusters = features.get("vertex_radius_clusters") or []
        tol = spec.get("tol_mm", tolerance["linear_mm"])
        ok = any(abs(c["radius_mm"] - spec["expected"]) <= tol for c in clusters)
        nearest = sorted(
            (abs(c["radius_mm"] - spec["expected"]), c["radius_mm"])
            for c in clusters
        )[:3]
        return check(
            ok,
            f"radius {spec['expected']:.3f} present; nearest "
            f"{[round(r, 3) for _d, r in nearest]}",
        )
    return check(False, f"unknown feature check kind {kind!r}")


def compare_fixture(
    fixture: dict,
    root: Path,
    external_dir: Path,
    out_dir: Path,
    tolerance: dict,
    have_occt: bool,
    have_moon: bool,
) -> dict:
    fixture_id = fixture.get("fixture_id", "?")
    checks: dict[str, dict] = {}
    notes: list[str] = []

    # 1. External golden file: checksum.
    local = fixture.get("local_filename")
    external_path = external_dir.parent / local if local else None
    present = bool(external_path and external_path.exists())
    if present and external_path is not None:
        actual_hash = sha256_file(external_path)
        expected_hash = fixture.get("sha256")
        size_ok = external_path.stat().st_size == fixture.get("byte_size")
        checksum_ok = actual_hash == expected_hash and size_ok
        checks["checksum"] = check(
            checksum_ok,
            f"sha256 {'match' if actual_hash == expected_hash else 'MISMATCH'}, "
            f"size {'match' if size_ok else 'MISMATCH'}",
        )
    else:
        checks["checksum"] = check(True, "external file absent", skipped=True)

    # 2. External geometry comparison against the downloaded golden model.
    if not present:
        checks["external_geometry"] = check(
            True, "external file absent", skipped=True
        )
    elif not have_occt:
        checks["external_geometry"] = check(
            True, "OCCT not available", skipped=True
        )
    else:
        try:
            measured = measure_occt(external_path, root)
            checks["external_geometry"] = check_recorded_reference(
                fixture, measured, tolerance
            )
        except Exception as exc:  # noqa: BLE001 - development harness
            checks["external_geometry"] = check(False, str(exc))

    # 3. Generation of the parametric part.
    if "generation" not in fixture:
        checks["generation"] = check(
            True, "fixture has no generation recipe", skipped=True
        )
        return {
            "fixture_id": fixture_id,
            "checks": checks,
            "verdict": _verdict(checks),
            "notes": notes,
        }
    if not have_moon:
        checks["generation"] = check(True, "moon not available", skipped=True)
        return {
            "fixture_id": fixture_id,
            "checks": checks,
            "verdict": _verdict(checks),
            "notes": notes,
        }
    try:
        part_path = generate_part(fixture, out_dir, root)
        checks["generation"] = check(True, f"generated {part_path.name}")
    except Exception as exc:  # noqa: BLE001
        checks["generation"] = check(False, str(exc))
        return {
            "fixture_id": fixture_id,
            "checks": checks,
            "verdict": _verdict(checks),
            "notes": notes,
        }

    # 4. Measurements of the parametric part.
    features: dict | None = None
    try:
        features = measure_features(part_path, root)
    except Exception as exc:  # noqa: BLE001
        checks["feature_inventory"] = check(False, str(exc))
    measured_part: dict | None = None
    if have_occt:
        try:
            measured_part = measure_occt(part_path, root)
        except Exception as exc:  # noqa: BLE001
            checks["occt_measure"] = check(False, str(exc))
    else:
        checks["occt_measure"] = check(True, "OCCT not available", skipped=True)

    spec = fixture.get("comparison") or {}

    # 5. Normative bounding box.
    if "bbox_axes" in spec:
        if measured_part is None:
            checks["bbox"] = check(True, "OCCT not available", skipped=True)
        else:
            extents = bbox_extents(measured_part["bbox"])
            failures = []
            for item in spec["bbox_axes"]:
                axis = item["axis"]
                expected = item["expected_mm"]
                tol = item.get("tol_mm", tolerance["linear_mm"])
                got = extents[axis]
                if abs(got - expected) > tol:
                    failures.append(
                        f"{item.get('label', f'axis {axis}')}: "
                        f"{got:.4f} vs {expected:.4f} mm"
                    )
            checks["bbox"] = check(
                not failures,
                "; ".join(failures) if failures else "all bbox extents match",
            )

    # 6. Solid count (the component is layered, so this is exact).
    if "solids" in spec:
        if measured_part is None:
            checks["solids"] = check(True, "OCCT not available", skipped=True)
        else:
            got = measured_part["solids"]
            checks["solids"] = check(
                got == spec["solids"], f"{got} vs {spec['solids']} solids"
            )

    # 6b. Mass property: volume of the parametric part against a normative or
    #     analytic value. Only meaningful where the internal geometry is
    #     comparable; layered fasteners usually leave this out.
    if "volume_mm3" in spec:
        if measured_part is None or measured_part.get("volume") is None:
            checks["volume"] = check(True, "OCCT volume unavailable", skipped=True)
        else:
            expected = spec["volume_mm3"]
            got = measured_part["volume"]
            rel = abs(got - expected) / max(abs(expected), 1.0e-9)
            tol = spec.get("volume_relative_tol", tolerance["volume_relative"])
            checks["volume"] = check(
                rel <= tol,
                f"volume {got:.3f} vs {expected:.3f} mm3 (rel {rel:.4f}, tol {tol})",
            )

    # 6c. Mass properties: volume and centre of mass.
    mp = spec.get("mass_properties")
    if mp:
        if measured_part is None:
            checks["mass_properties"] = check(
                True, "OCCT not available", skipped=True
            )
        else:
            failures = []
            if "volume_mm3" in mp and measured_part.get("volume") is not None:
                expected = mp["volume_mm3"]
                got = measured_part["volume"]
                rel = abs(got - expected) / max(abs(expected), 1.0e-9)
                tol = mp.get("volume_relative_tol", tolerance["volume_relative"])
                if rel > tol:
                    failures.append(
                        f"volume {got:.3f} vs {expected:.3f} (rel {rel:.4f})"
                    )
            if "center_of_mass_mm" in mp:
                got = measured_part.get("center_of_mass")
                if got is None:
                    failures.append("centre of mass unavailable")
                else:
                    tol = mp.get("center_of_mass_tol_mm", tolerance["linear_mm"])
                    want = mp["center_of_mass_mm"]
                    for i in range(3):
                        if abs(got[i] - want[i]) > tol:
                            failures.append(
                                f"com[{i}] {got[i]:.4f} vs {want[i]:.4f}"
                            )
            checks["mass_properties"] = check(
                not failures,
                "; ".join(failures) if failures else "mass properties match",
            )

    # 6d. Cross-section slices at declared planes. Measured by tessellating the
    #     parametric part and slicing the mesh, independently of the builder.
    sections = spec.get("sections")
    if sections:
        try:
            tris = msm.mesh_triangles(
                part_path, spec.get("section_deflection_mm", 0.01)
            )
            failures = []
            for s in sections:
                sec = msm.section_at(tris, s["z_mm"])
                rel_tol = s.get("area_relative_tol", 0.02)
                if "area_mm2" in s:
                    expected = s["area_mm2"]
                    rel = abs(sec["area_mm2"] - expected) / max(abs(expected), 1e-9)
                    if rel > rel_tol:
                        failures.append(
                            f"z={s['z_mm']}: area {sec['area_mm2']:.3f} vs "
                            f"{expected:.3f} (rel {rel:.4f})"
                        )
                if "perimeter_mm" in s:
                    expected = s["perimeter_mm"]
                    rel = abs(sec["perimeter_mm"] - expected) / max(abs(expected), 1e-9)
                    if rel > s.get("perimeter_relative_tol", 0.02):
                        failures.append(
                            f"z={s['z_mm']}: perimeter {sec['perimeter_mm']:.3f} vs "
                            f"{expected:.3f}"
                        )
                if "x_extent_mm" in s:
                    tol = s.get("extent_tol_mm", 5 * tolerance["linear_mm"])
                    if abs(sec["x_extent_mm"] - s["x_extent_mm"]) > tol:
                        failures.append(
                            f"z={s['z_mm']}: x {sec['x_extent_mm']:.3f} vs "
                            f"{s['x_extent_mm']:.3f}"
                        )
            checks["sections"] = check(
                not failures,
                "; ".join(failures) if failures else "section areas match",
            )
        except Exception as exc:  # noqa: BLE001
            checks["sections"] = check(False, str(exc))

    # 6e. Sampled bidirectional surface deviation against the downloaded golden
    #     model or a generated contrast part.
    sd = spec.get("surface_deviation")
    if sd:
        ref = sd.get("reference", "external")
        tol = sd.get("max_mm", tolerance["surface_deviation_mm"])
        try:
            if ref == "external":
                if not present or external_path is None:
                    checks["surface_deviation"] = check(
                        True, "external file absent", skipped=True
                    )
                elif not have_occt:
                    checks["surface_deviation"] = check(
                        True, "OCCT not available", skipped=True
                    )
                else:
                    dev = msm.surface_deviation(
                        part_path,
                        external_path,
                        sd.get("deflection_mm", 0.02),
                        sd.get("samples", 2000),
                    )
                    checks["surface_deviation"] = check(
                        dev["max_mm"] <= tol,
                        f"max deviation {dev['max_mm']:.4f} mm (tol {tol})",
                    )
            elif ref == "contrast":
                contrast_fixture = {
                    **fixture,
                    "generation": {
                        "tool": fixture["generation"]["tool"],
                        "args": sd.get("args", []),
                        "output": sd.get("output", "deviation-reference.step"),
                    },
                }
                ref_path = generate_part(contrast_fixture, out_dir, root)
                dev = msm.surface_deviation(
                    part_path,
                    ref_path,
                    sd.get("deflection_mm", 0.02),
                    sd.get("samples", 2000),
                )
                checks["surface_deviation"] = check(
                    dev["max_mm"] <= tol,
                    f"max deviation {dev['max_mm']:.4f} mm (tol {tol})",
                )
            else:
                checks["surface_deviation"] = check(
                    False, f"unknown surface-deviation reference {ref!r}"
                )
        except Exception as exc:  # noqa: BLE001
            checks["surface_deviation"] = check(False, str(exc))

    # 7. Feature expectations from STEP text.
    if spec.get("features"):
        if features is None:
            checks["features"] = check(False, "feature inventory unavailable")
        else:
            results = [
                check_feature_spec(f, features, tolerance)
                for f in spec["features"]
            ]
            failures = [r["detail"] for r in results if r["status"] == "FAIL"]
            checks["features"] = check(
                not failures,
                "; ".join(failures) if failures else "all feature checks match",
            )

    # 8. Optional contrast: a lower-detail build must have fewer faces, which
    #    proves that the detailed build really adds (e.g.) chamfer geometry.
    contrast = spec.get("contrast")
    if contrast and features is not None:
        try:
            contrast_fixture = {
                **fixture,
                "generation": {
                    "tool": fixture["generation"]["tool"],
                    "args": contrast.get("args", []),
                    "output": contrast.get("output", "contrast.step"),
                },
            }
            contrast_path = generate_part(contrast_fixture, out_dir, root)
            contrast_features = measure_features(contrast_path, root)
            extra = (
                features.get("advanced_faces", 0)
                - contrast_features.get("advanced_faces", 0)
            )
            checks["feature_contrast"] = check(
                extra >= contrast.get("expect_more_advanced_faces", 1),
                f"detailed build has {extra} more advanced faces",
            )
        except Exception as exc:  # noqa: BLE001
            checks["feature_contrast"] = check(False, str(exc))

    return {
        "fixture_id": fixture_id,
        "checks": checks,
        "verdict": _verdict(checks),
        "notes": notes,
    }


ESSENTIAL = {"generation", "bbox", "solids", "features"}


def _verdict(checks: dict[str, dict]) -> str:
    statuses = [c["status"] for c in checks.values()]
    if "FAIL" in statuses:
        return "FAIL"
    essential = [checks[k]["status"] for k in checks if k in ESSENTIAL]
    if essential and all(s == "SKIP" for s in essential):
        return "SKIP"
    if "PASS" in statuses:
        return "PASS"
    return "SKIP"


def print_result(result: dict) -> None:
    print(f"fixture: {result['fixture_id']}")
    for name, c in result["checks"].items():
        print(f"  [{c['status']:4}] {name}: {c['detail']}")
    for note in result.get("notes", []):
        print(f"  note: {note}")
    print(f"  => {result['verdict']}")


def _fixture_check_status(result: dict, name: str) -> str:
    return (result["checks"].get(name) or {}).get("status", "MISSING")


def run_self_tests(root: Path, tolerance: dict, have_occt: bool, have_moon: bool) -> int:
    """Prove the harness's PASS/FAIL/SKIP and normalization behaviour.

    A generated parametric part stands in for the external oracle, so the
    self-test needs no downloaded file. It proves that a matching fixture
    reports PASS, a deliberately wrong expected dimension reports FAIL, a
    missing golden file reports SKIP while the normative checks still pass, and
    a checksum mismatch reports FAIL.
    """
    if not (have_occt and have_moon):
        print("golden harness self-test: SKIP (OCCT and moon are required)")
        return 0

    manifest = json.loads(MANIFEST_DEFAULT.read_text())
    base = next(
        (
            f
            for f in manifest.get("external_references", [])
            if f.get("fixture_id") == "fasteners/iso4762-m3x10"
        ),
        None,
    )
    if base is None:
        print("golden harness self-test: FAIL (base fixture missing)")
        return 1

    failures = 0

    def report(name: str, ok: bool, detail: str) -> None:
        nonlocal failures
        if not ok:
            failures += 1
        print(f"  [{'PASS' if ok else 'FAIL'}] {name}: {detail}")

    with tempfile.TemporaryDirectory(prefix="golden-selftest-") as td_raw:
        td = Path(td_raw)
        external = td / "external"
        external.mkdir()
        oracle = external / "self-test-oracle.step"
        gen = generate_part(base, td, root)
        shutil.copyfile(gen, oracle)
        measured = measure_occt(oracle, root)
        recorded = {
            "bbox_mm": bbox_extents(measured["bbox"]),
            "volume_mm3": measured.get("volume"),
            "solids": measured["solids"],
        }

        def synthetic(**over) -> dict:
            fixture = json.loads(json.dumps(base))
            fixture["fixture_id"] = "self-test/fixture"
            fixture["local_filename"] = "external/self-test-oracle.step"
            fixture["license_status"] = "open-source"
            fixture["sha256"] = sha256_file(oracle)
            fixture["byte_size"] = oracle.stat().st_size
            fixture["measured_dimensions"] = recorded
            fixture.update(over)
            return fixture

        def compare(fixture: dict) -> dict:
            return compare_fixture(
                fixture, root, external, td, tolerance, have_occt, have_moon
            )

        a = compare(synthetic())
        report(
            "matching fixture",
            a["verdict"] == "PASS"
            and _fixture_check_status(a, "external_geometry") == "PASS",
            f"verdict {a['verdict']}, external "
            f"{_fixture_check_status(a, 'external_geometry')}",
        )

        bfix = synthetic()
        bfix["comparison"]["bbox_axes"][0]["expected_mm"] += 1.0
        b = compare(bfix)
        report(
            "mismatched expected dimension",
            b["verdict"] == "FAIL",
            f"verdict {b['verdict']}",
        )

        cfix = synthetic()
        cfix["local_filename"] = "external/missing-oracle.step"
        c = compare(cfix)
        report(
            "missing golden file",
            c["verdict"] == "PASS"
            and _fixture_check_status(c, "external_geometry") == "SKIP",
            f"verdict {c['verdict']}, external "
            f"{_fixture_check_status(c, 'external_geometry')}",
        )

        dfix = synthetic()
        dfix["sha256"] = "0" * 64
        d = compare(dfix)
        report(
            "checksum mismatch",
            d["verdict"] == "FAIL"
            and _fixture_check_status(d, "checksum") == "FAIL",
            f"verdict {d['verdict']}, checksum "
            f"{_fixture_check_status(d, 'checksum')}",
        )

        ex = [26.0 / 25.4, 8.0 / 25.4, 26.0 / 25.4]
        bbox = [0.0, ex[0], 0.0, ex[1], 0.0, ex[2]]
        norm = normalize_extents(bbox, {"units": "inch", "up_axis": "y"})
        report(
            "units/frame normalization",
            all(abs(norm[i] - v) < 1.0e-6 for i, v in enumerate([26.0, 26.0, 8.0])),
            f"{[round(v, 6) for v in norm]} -> mm Z-up",
        )
        try:
            normalize_extents(bbox, {"units": "furlong"})
            report("unknown units rejected", False, "no exception")
        except RuntimeError:
            report("unknown units rejected", True, "RuntimeError")

        features = {
            "surface_counts": {"plane": 3},
            "cones": [{"semi_angle_deg": 45.0}],
            "vertex_radius_clusters": [{"radius_mm": 37.5, "count": 40}],
        }
        report(
            "feature kind PASS",
            check_feature_spec(
                {"kind": "vertex_radius_present_mm", "expected": 37.5},
                features,
                tolerance,
            )["status"]
            == "PASS",
            "radius present",
        )
        report(
            "feature kind FAIL",
            check_feature_spec(
                {"kind": "vertex_radius_present_mm", "expected": 12.0},
                features,
                tolerance,
            )["status"]
            == "FAIL",
            "radius absent",
        )

        # Independent mass, section, and surface-deviation measurements.
        washer = {
            "fixture_id": "self-test/washer",
            "generation": {
                "tool": "components/examples/fasteners",
                "args": [
                    "--standard", "iso7089", "--size", "M4",
                    "--detail", "detailed", "-o", "{out}",
                ],
                "output": "self-washer-m4.step",
            },
        }
        washer5 = json.loads(json.dumps(washer))
        washer5["generation"]["args"] = [
            "--standard", "iso7089", "--size", "M5",
            "--detail", "detailed", "-o", "{out}",
        ]
        washer5["generation"]["output"] = "self-washer-m5.step"
        try:
            w4 = generate_part(washer, td, root)
            w5 = generate_part(washer5, td, root)
            wm = measure_occt(w4, root)
            expected_volume = math.pi * (4.5 ** 2 - 2.15 ** 2) * 0.8
            report(
                "mass properties (volume, centre of mass)",
                wm.get("volume") is not None
                and abs(wm["volume"] - expected_volume) / expected_volume < 0.01
                and wm.get("center_of_mass") is not None
                and abs(wm["center_of_mass"][2] - 0.4) < 0.01,
                f"volume {wm.get('volume')} vs {expected_volume:.3f}, "
                f"com {wm.get('center_of_mass')}",
            )
            tris = msm.mesh_triangles(w4, 0.01)
            sec = msm.section_at(tris, 0.4)
            expected_area = math.pi * (4.5 ** 2 - 2.15 ** 2)
            report(
                "section area at z=0.4",
                abs(sec["area_mm2"] - expected_area) / expected_area < 0.02,
                f"{sec['area_mm2']:.3f} vs {expected_area:.3f} mm2",
            )
            dev_self = msm.surface_deviation(w4, w4, 0.02, 500)
            report(
                "surface deviation of identical shapes",
                dev_self["max_mm"] < 1.0e-6,
                f"max {dev_self['max_mm']:.6f} mm",
            )
            dev_diff = msm.surface_deviation(w4, w5, 0.02, 500)
            report(
                "surface deviation detects a different size",
                dev_diff["max_mm"] > 0.1,
                f"max {dev_diff['max_mm']:.4f} mm",
            )
            wf = measure_features(w4, root)
            report(
                "vertex_ring feature PASS",
                check_feature_spec(
                    {
                        "kind": "vertex_ring",
                        "z_mm": 0.0,
                        "radius_mm": 4.5,
                        "min_count": 32,
                    },
                    wf,
                    tolerance,
                )["status"]
                == "PASS",
                "outer rim ring present",
            )
            report(
                "vertex_ring feature FAIL",
                check_feature_spec(
                    {
                        "kind": "vertex_ring",
                        "z_mm": 0.0,
                        "radius_mm": 12.0,
                        "min_count": 1,
                    },
                    wf,
                    tolerance,
                )["status"]
                == "FAIL",
                "absent radius fails",
            )
        except Exception as exc:  # noqa: BLE001
            report("mass/section/surface self-tests", False, str(exc))

    print(
        f"golden harness self-test: {'PASS' if failures == 0 else 'FAIL'} "
        f"({failures} failures)"
    )
    return 0 if failures == 0 else 1


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--manifest", type=Path, default=MANIFEST_DEFAULT)
    ap.add_argument("--external-dir", type=Path, default=EXTERNAL_DEFAULT)
    ap.add_argument("--root", type=Path, default=ROOT_DEFAULT)
    ap.add_argument("--fixture", action="append", default=[])
    ap.add_argument("--out", type=Path, default=None)
    ap.add_argument("--json", action="store_true")
    ap.add_argument(
        "--self-test",
        action="store_true",
        help="Prove the harness PASS/FAIL/SKIP and normalization behaviour",
    )
    args = ap.parse_args(argv)

    manifest = json.loads(args.manifest.read_text())
    tolerance = {**TOLERANCE_DEFAULT, **(manifest.get("tolerance") or {})}
    have_occt = shutil.which("occt-draw") is not None or shutil.which("DRAWEXE")
    have_moon = shutil.which("moon") is not None

    if args.self_test:
        return run_self_tests(args.root, tolerance, have_occt, have_moon)

    fixtures = manifest.get("external_references", [])
    if args.fixture:
        wanted = set(args.fixture)
        fixtures = [f for f in fixtures if f.get("fixture_id") in wanted]
        missing = wanted - {f.get("fixture_id") for f in fixtures}
        if missing:
            print(f"unknown fixture(s): {', '.join(sorted(missing))}", file=sys.stderr)
            return 2

    tmp_ctx = None
    if args.out is None:
        tmp_ctx = tempfile.TemporaryDirectory(prefix="golden-compare-")
        out_dir = Path(tmp_ctx.name)
    else:
        out_dir = args.out
        out_dir.mkdir(parents=True, exist_ok=True)

    results = []
    try:
        for fixture in fixtures:
            if "generation" not in fixture and not args.fixture:
                continue
            results.append(
                compare_fixture(
                    fixture,
                    args.root,
                    args.external_dir,
                    out_dir,
                    tolerance,
                    have_occt,
                    have_moon,
                )
            )
    finally:
        if tmp_ctx is not None:
            tmp_ctx.cleanup()

    if args.json:
        print(json.dumps(results, indent=2))
    else:
        for result in results:
            print_result(result)

    verdicts = [r["verdict"] for r in results]
    if "FAIL" in verdicts:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
