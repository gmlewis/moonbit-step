#!/usr/bin/env python3
"""Compare parametric components against golden-reference fixtures.

This is a development-time harness. It never becomes a runtime dependency of
the MoonBit component library.

For every manifest fixture that carries a ``generation`` block it:

1. verifies the provenance and licence record;
2. verifies the external fixture's SHA-256 and byte size when the file is
   present;
3. re-measures the external file with Open CASCADE when it is present and its
   licence is verified (otherwise the external comparison is ``SKIP``);
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
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

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
    extents = bbox_extents(measured["bbox"])
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
    if kind == "surface_min":
        surface = spec["surface"]
        count = (features.get("surface_counts") or {}).get(surface, 0)
        return check(
            count >= spec["min_count"],
            f"{surface} count {count} >= {spec['min_count']}",
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

    # 1. External fixture: checksum and licence.
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

    # 2. External geometry comparison (needs file, verified licence, OCCT).
    license_status = fixture.get("license_status", "unverified-per-file")
    if not present:
        checks["external_geometry"] = check(
            True, "external file absent", skipped=True
        )
    elif not str(license_status).startswith("verified"):
        checks["external_geometry"] = check(
            True,
            f"licence status {license_status!r} is not verified; "
            "external model not used as an oracle",
            skipped=True,
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


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--manifest", type=Path, default=MANIFEST_DEFAULT)
    ap.add_argument("--external-dir", type=Path, default=EXTERNAL_DEFAULT)
    ap.add_argument("--root", type=Path, default=ROOT_DEFAULT)
    ap.add_argument("--fixture", action="append", default=[])
    ap.add_argument("--out", type=Path, default=None)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)

    manifest = json.loads(args.manifest.read_text())
    tolerance = {**TOLERANCE_DEFAULT, **(manifest.get("tolerance") or {})}
    have_occt = shutil.which("occt-draw") is not None or shutil.which("DRAWEXE")
    have_moon = shutil.which("moon") is not None

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
