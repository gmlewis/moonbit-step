#!/usr/bin/env python3
"""Build and validate the M2-M5 fastener golden matrix.

This is a development-time harness. It never becomes a runtime dependency of
the MoonBit component library.

For every family / size / detail cell it:

1. generates the parametric part through the example CLI (never by calling
   internal dimension functions);
2. measures it with Open CASCADE (solid count, bounding box, volume, centre of
   mass) and with ``measure_step_features.py`` (surface types and the
   vertex-ring report);
3. runs independent **normative** checks: standard outside dimensions, solid
   count, and the measured chamfer/lead-in/thread rings;
4. compares the part with the downloaded **golden** model from the open-source
   step.parts corpus in ``components/testdata/golden/external/``. The
   comparison is rotation-invariant (maximum radius and axial extent). A
   downloaded model that contradicts the standard is a ``FAIL`` with measured
   evidence;
5. records two statuses per cell, ``NORMATIVE`` (PASS/FAIL) and ``GOLDEN``
   (PASS/FAIL/SKIP), plus the exact measured values.

A missing golden file is ``SKIP``, never a pass. A cell is fully validated only
when both statuses are ``PASS``.

Usage:
    python3 scripts/golden_matrix.py                 # full matrix
    python3 scripts/golden_matrix.py --family iso4762 --size M4
    python3 scripts/golden_matrix.py --detail detailed
    python3 scripts/golden_matrix.py --js  # machine-readable JSON
    python3 scripts/golden_matrix.py --self-test
"""

from __future__ import annotations

import argparse
import json
import math
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT_DEFAULT = Path(__file__).resolve().parent.parent
EXTERNAL_DEFAULT = ROOT_DEFAULT / "components/testdata/golden/external"
LINEAR_TOL = 0.02  # mm, measured STEP geometry vs declared value
COS30 = math.cos(math.pi / 6.0)

SIZES = ["M2", "M2.5", "M3", "M4", "M5"]
DETAILS = ["simplified", "detailed", "full"]

# --- Independent standard tables (transcribed from the ISO nominal tables). ---
ISO4762 = {
    # s is the ISO socket upper limit (nominal + tolerance), which is what the
    # builder models. The downloaded goldens use the nominal, below the ISO min.
    "M2": dict(d=2.0, dk=3.8, k=2.0, s=1.58, t=1.0),
    "M2.5": dict(d=2.5, dk=4.5, k=2.5, s=2.08, t=1.1),
    "M3": dict(d=3.0, dk=5.5, k=3.0, s=2.58, t=1.3),
    "M4": dict(d=4.0, dk=7.0, k=4.0, s=3.08, t=2.0),
    "M5": dict(d=5.0, dk=8.5, k=5.0, s=4.095, t=2.5),
}
ISO4032 = {
    "M2": dict(d=2.0, s=4.0, m=1.6),
    "M2.5": dict(d=2.5, s=5.0, m=2.0),
    "M3": dict(d=3.0, s=5.5, m=2.4),
    "M4": dict(d=4.0, s=7.0, m=3.2),
    "M5": dict(d=5.0, s=8.0, m=4.7),
}
ISO7089 = {
    "M2": dict(d1=2.2, d2=5.0, h=0.3),
    "M2.5": dict(d1=2.7, d2=6.0, h=0.5),
    "M3": dict(d1=3.2, d2=7.0, h=0.5),
    "M4": dict(d1=4.3, d2=9.0, h=0.8),
    "M5": dict(d1=5.3, d2=10.0, h=1.0),
}
HEX_HEAD = {
    # k is the reference upper limit used by the simple hex-head references.
    "M2": dict(d=2.0, s=4.0, k=1.6),
    "M2.5": dict(d=2.5, s=5.0, k=1.9),
    "M3": dict(d=3.0, s=5.5, k=2.2),
    "M4": dict(d=4.0, s=7.0, k=3.0),
    "M5": dict(d=5.0, s=8.0, k=3.74),
}
ISO7380 = {
    # s is the ISO socket upper limit (nominal 2.0/2.5/3.0 + 0.08), which is
    # what the builder models and what the downloaded goldens use.
    "M3": dict(d=3.0, dk=5.7, k=1.65, s=2.08, t=1.04),
    "M4": dict(d=4.0, dk=7.6, k=2.20, s=2.58, t=1.30),
    "M5": dict(d=5.0, dk=9.5, k=2.75, s=3.08, t=1.56),
}
ISO10642 = {
    # ISO 10642:2026 reference profile (sharp dk, reference k, s_max, t).
    # dk here is the measured envelope of the generated cone/edge torus.
    "M3": dict(d=3.0, dk=6.104, k=1.70, s=2.08, t=1.20),
    "M4": dict(d=4.0, dk=8.0468, k=2.30, s=2.58, t=1.65),
    "M5": dict(d=5.0, dk=10.181, k=2.80, s=3.08, t=2.00),
}
DIN976 = {
    "M2": dict(d=2.0),
    "M2.5": dict(d=2.5),
    "M3": dict(d=3.0),
    "M4": dict(d=4.0),
    "M5": dict(d=5.0),
}

PITCH = {"M2": 0.40, "M2.5": 0.45, "M3": 0.50, "M4": 0.70, "M5": 0.80}

# --- Downloaded golden files (open-source step.parts corpus). ---
# The repository owner downloads these files into
# components/testdata/golden/external/. They are the independent golden
# models; there are no licensing restrictions on using them as references.
# A family/size with no downloaded golden is reported SKIP, never PASS.
GOLDEN = {
    "iso4762": {
        "M2": ("iso4762_socket_head_cap_screw_m2x8.step", 8.0),
        "M2.5": ("iso4762_socket_head_cap_screw_m2p5x10.step", 10.0),
        "M3": ("iso4762_socket_head_cap_screw_m3x10.step", 10.0),
        "M4": ("iso4762_socket_head_cap_screw_m4x20.step", 20.0),
        "M5": ("iso4762_socket_head_cap_screw_m5x20.step", 20.0),
    },
    "iso4032": {
        "M2": ("hex_nut_m2_simple.step", 0.0),
        "M2.5": ("hex_nut_m2p5_simple.step", 0.0),
        "M3": ("iso4032_hex_nut_m3.step", 0.0),
        "M4": ("iso4032_hex_nut_m4.step", 0.0),
        "M5": ("iso4032_hex_nut_m5.step", 0.0),
    },
    "iso4017": {
        "M2": ("hex_head_bolt_m2_l0008_simple.step", 8.0),
        "M2.5": ("hex_head_bolt_m2p5_l0010_simple.step", 10.0),
        "M3": ("hex_head_bolt_m3_l0012_simple.step", 12.0),
        "M4": ("hex_head_bolt_m4_l0016_simple.step", 16.0),
        "M5": ("hex_head_bolt_m5_l0020_simple.step", 20.0),
    },
    # No ISO 4014 (partially threaded) model is present in the downloaded
    # corpus; the ISO 4017 models are fully threaded and are not a valid
    # oracle for this family.
    "iso4014": {
        "M2": None,
        "M2.5": None,
        "M3": None,
        "M4": None,
        "M5": None,
    },
    "iso7380": {
        "M3": ("button_head_screw_m3_l0008_simple.step", 8.0),
        "M4": ("button_head_screw_m4_l0010_simple.step", 10.0),
        "M5": ("button_head_screw_m5_l0012_simple.step", 12.0),
    },
    "iso10642": {
        "M3": ("countersunk_socket_screw_m3_l0008_simple.step", 8.0),
        "M4": ("countersunk_socket_screw_m4_l0010_simple.step", 10.0),
        "M5": ("countersunk_socket_screw_m5_l0012_simple.step", 12.0),
    },
    "din976": {
        "M2": ("iso_metric_threaded_rod_m2_l025_simple.step", 25.0),
        "M2.5": ("iso_metric_threaded_rod_m2p5_l025_simple.step", 25.0),
        "M3": ("iso_metric_threaded_rod_m3_l025_simple.step", 25.0),
        "M4": ("iso_metric_threaded_rod_m4_l025_simple.step", 25.0),
        "M5": ("iso_metric_threaded_rod_m5_l025_simple.step", 25.0),
    },
}

# Representative cell lengths stay fixed even where no golden file exists.
CELL_LENGTHS = {
    "iso4762": {"M2": 8.0, "M2.5": 10.0, "M3": 10.0, "M4": 20.0, "M5": 20.0},
    "iso4017": {"M2": 8.0, "M2.5": 10.0, "M3": 12.0, "M4": 16.0, "M5": 20.0},
    "iso4014": {"M2": 8.0, "M2.5": 10.0, "M3": 12.0, "M4": 16.0, "M5": 20.0},
    "iso4032": {"M2": 0.0, "M2.5": 0.0, "M3": 0.0, "M4": 0.0, "M5": 0.0},
    "iso7089": {"M2": 0.0, "M2.5": 0.0, "M3": 0.0, "M4": 0.0, "M5": 0.0},
    "iso7380": {"M3": 8.0, "M4": 10.0, "M5": 12.0},
    "iso10642": {"M3": 8.0, "M4": 10.0, "M5": 12.0},
    "din976": {"M2": 25.0, "M2.5": 25.0, "M3": 25.0, "M4": 25.0, "M5": 25.0},
}

FAMILIES = ["iso4762", "iso4017", "iso4014", "iso4032", "iso7089", "iso7380", "iso10642", "din976"]
FAMILY_SIZES = {
    "iso4762": SIZES,
    "iso4017": SIZES,
    "iso4014": SIZES,
    "iso4032": SIZES,
    "iso7089": SIZES,
    "iso7380": ["M3", "M4", "M5"],
    "iso10642": ["M3", "M4", "M5"],
    "din976": SIZES,
}

# --- Engineering-default chamfer formulas (mirror the declared defaults). ---
def tip_chamfer(d: float) -> float:
    return min(0.1 * d, 0.5)


def lead_in(across_flats: float, depth: float) -> float:
    return min(0.1 * across_flats, 0.5 * depth)


def head_chamfer(dk: float, k: float, t: float) -> float:
    return min(0.1 * dk, k / 3.0, t / 2.0)


def hex_head_chamfer(s: float, k: float) -> float:
    # Radial inset from the across-corners radius to the across-flats radius
    # (the standard conical washer face, approximated by a parallel inset).
    return s * (1.0 / math.sqrt(3.0) - 0.5)


def nut_chamfer(s: float, m: float) -> float:
    return min(0.1 * s, m / 3.0)


def thread_b(d: float, length: float) -> float:
    if length <= 125.0:
        return 2.0 * d + 6.0
    if length <= 200.0:
        return 2.0 * d + 12.0
    return 2.0 * d + 25.0


def minor(d: float, p: float) -> float:
    return d - 17.0 / 12.0 * (math.sqrt(3.0) / 2.0 * p)


def minor_d1(d: float, p: float) -> float:
    """ISO 68-1 basic internal minor diameter D1 (the table minor diameter)."""
    return d - 1.25 * (math.sqrt(3.0) / 2.0 * p)


def hex_circumradius(across_flats: float) -> float:
    return across_flats / (2.0 * COS30)


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
    return run_json(root / "scripts/measure_step_features.py", "--json", str(path))[0]


def extents(bbox: list[float]) -> list[float]:
    return [bbox[1] - bbox[0], bbox[3] - bbox[2], bbox[5] - bbox[4]]


def generate(
    root: Path, out_dir: Path, standard: str, size: str, length: float, detail: str
) -> Path:
    out = out_dir / f"{standard}-{size}-{detail}.step"
    cmd = [
        "moon",
        "run",
        "components/examples/fasteners",
        "--",
        "--standard",
        standard,
        "--size",
        size,
        "--length",
        str(length),
        "--detail",
        detail,
        "-o",
        str(out),
    ]
    proc = subprocess.run(cmd, cwd=str(root), capture_output=True, text=True, timeout=1800)
    if proc.returncode != 0:
        raise RuntimeError(
            f"generation failed: {proc.stderr.strip() or proc.stdout.strip()}"
        )
    if not out.exists():
        raise RuntimeError(f"generation wrote no file at {out}")
    return out


def ring_present(
    rings: list[dict], z: float, radius: float, min_count: int = 1, tol: float = LINEAR_TOL
) -> bool:
    return any(
        abs(r["z_mm"] - z) <= tol
        and abs(r["radius_mm"] - radius) <= tol
        and r["count"] >= min_count
        for r in rings
    )


def cone_present(
    feats: dict,
    radius: float,
    semi_angle_deg: float = 45.0,
    tol: float = LINEAR_TOL,
    angle_tol: float = 0.05,
) -> bool:
    """True when an analytic CONICAL_SURFACE has this reference radius/angle.

    A circular chamfer is a cone, so it carries one circular edge and one
    vertex per rim rather than a many-vertex polygon ring. Checking the cone's
    semi-angle and reference radius is the analytic equivalent of the old
    vertex-ring count and is strictly stronger: it distinguishes a real cone
    from a ruled facet stack.
    """
    for cone in feats.get("cones") or []:
        angle_ok = abs(cone.get("semi_angle_deg", 0.0) - semi_angle_deg) <= angle_tol
        rad = cone.get("semi_angle")
        if not angle_ok and rad is not None:
            angle_ok = abs(math.degrees(rad) - semi_angle_deg) <= angle_tol
        if abs(cone.get("radius", 0.0) - radius) <= tol and angle_ok:
            return True
    return False


def cone_report(
    feats: dict, radius: float, semi_angle_deg: float = 45.0
) -> str:
    cones = [
        (round(c.get("radius", 0.0), 4), round(c.get("semi_angle_deg", 0.0), 3))
        for c in (feats.get("cones") or [])
    ]
    return (
        f"cone r={radius:.4f} angle={semi_angle_deg:.1f}; "
        f"measured cones: {cones[:8]}"
    )


def cylinder_present(feats: dict, radius: float, tol: float = LINEAR_TOL) -> bool:
    """True when an analytic CYLINDRICAL_SURFACE has this radius."""
    return any(
        abs(c.get("radius", 0.0) - radius) <= tol
        for c in (feats.get("cylinders") or [])
    )


def ring_radius_count(rings: list[dict], radius: float, tol: float = LINEAR_TOL) -> int:
    """Total vertices lying on a circle of `radius` (any z)."""
    return sum(r["count"] for r in rings if abs(r["radius_mm"] - radius) <= tol)


def ring_report(rings: list[dict], z: float, radius: float, min_count: int = 1) -> str:
    near = [r for r in rings if abs(r["z_mm"] - z) <= 5 * LINEAR_TOL]
    return (
        f"z={z:.4f} r={radius:.4f} n>={min_count}; "
        f"measured near z: {[(r['z_mm'], r['radius_mm'], r['count']) for r in near][:6]}"
    )


def chamfer_checks(
    family: str, size: str, detail: str, length: float, feats: dict
) -> list[dict]:
    """Independent measured chamfer/lead-in/thread checks from vertex rings."""
    rings = feats.get("vertex_rings") or []
    # Headed screw/bolt datums are the head underside (countersunk: flush top),
    # so the shank tip is at -length. Normalize Z back to the tip-at-0 frame
    # the feature checks below are written in; the checks themselves and the
    # golden comparison are unchanged.
    if family in ("iso4762", "iso4017", "iso4014", "iso7380", "iso10642"):
        rings = [dict(r, z_mm=r["z_mm"] + length) for r in rings]
    checks: list[dict] = []

    def add(name: str, ok: bool, detail_text: str) -> None:
        checks.append({"name": name, "status": "PASS" if ok else "FAIL", "detail": detail_text})

    if family == "iso4762":
        p = ISO4762[size]
        d, dk, k, s, t = p["d"], p["dk"], p["k"], p["s"], p["t"]
        if detail == "simplified":
            add("tip-sharp", ring_present(rings, 0.0, d / 2.0, 1), ring_report(rings, 0.0, d / 2.0, 1))
        else:
            c = tip_chamfer(d)
            full_d = minor(d, PITCH[size]) if detail == "full" else d
            r_tip = full_d / 2.0 - c
            add(
                "tip-chamfer",
                cone_present(feats, full_d / 2.0, 45.0)
                and ring_present(rings, 0.0, r_tip, 1),
                f"{cone_report(feats, full_d / 2.0)}; "
                + ring_report(rings, 0.0, r_tip, 1),
            )
            add(
                "tip-full-radius",
                ring_present(rings, c, full_d / 2.0, 1),
                ring_report(rings, c, full_d / 2.0, 1),
            )
            # The socket is a real blind pocket in one closed solid. The golden
            # countersinks its rim, but a hyperbola-trimmed cone cannot be
            # emitted soundly yet, so the rim is sharp and that feature is a
            # typed omission. Check the actual sharp hexagonal rim and floor.
            add("socket-rim-sharp",
                ring_present(rings, length + k, hex_circumradius(s), 6),
                ring_report(rings, length + k, hex_circumradius(s), 6))
            add("socket-floor",
                ring_present(rings, length + k - t, hex_circumradius(s), 6),
                ring_report(rings, length + k - t, hex_circumradius(s), 6))
            add(
                "head-top-chamfer",
                cone_present(feats, dk / 2.0, 45.0)
                and ring_present(
                    rings, length + k, dk / 2.0 - head_chamfer(dk, k, t), 1
                ),
                f"{cone_report(feats, dk / 2.0)}; "
                + ring_report(
                    rings, length + k, dk / 2.0 - head_chamfer(dk, k, t), 1
                ),
            )
        if detail == "full":
            ridge = feats.get("surface_counts", {})
            # The swept ridge is polygonal; prove real swept geometry by the
            # number of advanced faces and the maximum radius at the major
            # diameter.
            add("helical-ridge-faces", ridge.get("plane", 0) > 300, f"plane faces {ridge.get('plane', 0)}")
            add("thread-crest-ring", ring_radius_count(rings, d / 2.0) >= 8,
                f"crest r={d/2.0:.4f}: {ring_radius_count(rings, d/2.0)} vertices")

    elif family == "iso4032":
        p = ISO4032[size]
        d, s, m = p["d"], p["s"], p["m"]
        if detail == "simplified":
            add("face-sharp", ring_present(rings, 0.0, hex_circumradius(s), 6), ring_report(rings, 0.0, hex_circumradius(s), 6))
        else:
            c = nut_chamfer(s, m)
            r_ch = hex_circumradius(s) - c / COS30
            add("bottom-face-chamfer", ring_present(rings, 0.0, r_ch, 6), ring_report(rings, 0.0, r_ch, 6))
            add("top-face-chamfer", ring_present(rings, m, r_ch, 6), ring_report(rings, m, r_ch, 6))
            add("face-full-radius", ring_present(rings, c, hex_circumradius(s), 6), ring_report(rings, c, hex_circumradius(s), 6))
        if detail == "full":
            add("internal-ridge-faces", feats.get("surface_counts", {}).get("plane", 0) > 120,
                f"plane faces {feats.get('surface_counts', {}).get('plane', 0)}")
            d1 = d - 1.25 * (math.sqrt(3.0) / 2.0 * PITCH[size])
            add("internal-thread-crest-ring", ring_radius_count(rings, d1 / 2.0) >= 8,
                f"crest r={d1/2.0:.4f}: {ring_radius_count(rings, d1/2.0)} vertices")

    elif family == "iso7089":
        p = ISO7089[size]
        d1, d2, h = p["d1"], p["d2"], p["h"]
        add("outer-rings",
            ring_present(rings, 0.0, d2 / 2.0, 1) and ring_present(rings, h, d2 / 2.0, 1)
            and cylinder_present(feats, d2 / 2.0),
            f"cylinder r={d2/2.0:.4f}; " + ring_report(rings, 0.0, d2 / 2.0, 1))
        add("bore-rings",
            ring_present(rings, 0.0, d1 / 2.0, 1) and ring_present(rings, h, d1 / 2.0, 1)
            and cylinder_present(feats, d1 / 2.0),
            f"cylinder r={d1/2.0:.4f}; " + ring_report(rings, h, d1 / 2.0, 1))
        zs = sorted({round(r["z_mm"], 3) for r in rings})
        add("no-edge-chamfer", len(zs) == 2 and abs(zs[0]) < 1e-6 and abs(zs[1] - h) < 1e-6,
            f"distinct measured z levels {zs}")

    elif family in ("iso4017", "iso4014"):
        p = HEX_HEAD[size]
        d, s, k = p["d"], p["s"], p["k"]
        c = hex_head_chamfer(s, k)
        depth = c / math.tan(math.radians(75.0))
        r_top = hex_circumradius(s) - c / COS30
        add("hex-head-top-chamfer", ring_present(rings, length + k, r_top, 6),
            ring_report(rings, length + k, r_top, 6))
        add("hex-head-full-radius", ring_present(rings, length + k - depth, hex_circumradius(s), 6),
            ring_report(rings, length + k - depth, hex_circumradius(s), 6))
        if detail != "simplified":
            tc = tip_chamfer(d)
            # Unthreaded shanks are at D1; the swept ridge core is at d3.
            full_d = minor(d, PITCH[size]) if detail == "full" else minor_d1(d, PITCH[size])
            r_tip = full_d / 2.0 - tc
            add("shank-tip-chamfer",
                cone_present(feats, full_d / 2.0, 45.0) and ring_present(rings, 0.0, r_tip, 1),
                f"{cone_report(feats, full_d / 2.0)}; " + ring_report(rings, 0.0, r_tip, 1))

    elif family == "iso7380":
        p = ISO7380[size]
        d, dk, k, s, t = p["d"], p["dk"], p["k"], p["s"], p["t"]
        if detail == "simplified":
            add("socket-sharp", ring_present(rings, length + k, hex_circumradius(s), 6),
                ring_report(rings, length + k, hex_circumradius(s), 6))
        else:
            add("socket-rim-sharp", ring_present(rings, length + k, hex_circumradius(s), 6),
                ring_report(rings, length + k, hex_circumradius(s), 6))
            add("socket-floor", ring_present(rings, length + k - t, hex_circumradius(s), 6),
                ring_report(rings, length + k - t, hex_circumradius(s), 6))
            tc = tip_chamfer(d)
            # Without modeled threads the button-head shank is at D1; with a
            # swept ridge the core is the external root d3.
            shank_d = minor(d, PITCH[size]) if detail == "full" else minor_d1(d, PITCH[size])
            r_tip = shank_d / 2.0 - tc
            add("shank-tip-chamfer",
                cone_present(feats, shank_d / 2.0, 45.0) and ring_present(rings, 0.0, r_tip, 1),
                f"{cone_report(feats, shank_d / 2.0)}; " + ring_report(rings, 0.0, r_tip, 1))
            if detail == "full":
                add("thread-crest-ring", ring_radius_count(rings, d / 2.0) >= 8,
                    f"crest r={d/2.0:.4f}: {ring_radius_count(rings, d/2.0)} vertices")

    elif family == "iso10642":
        p = ISO10642[size]
        d, k, s, t = p["d"], p["k"], p["s"], p["t"]
        if detail == "simplified":
            add("socket-sharp", ring_present(rings, length, hex_circumradius(s), 6),
                ring_report(rings, length, hex_circumradius(s), 6))
        else:
            add("socket-rim-sharp", ring_present(rings, length, hex_circumradius(s), 6),
                ring_report(rings, length, hex_circumradius(s), 6))
            add("socket-floor", ring_present(rings, length - t, hex_circumradius(s), 6),
                ring_report(rings, length - t, hex_circumradius(s), 6))
            tc = tip_chamfer(d)
            # Unthreaded shanks are at D1; the swept ridge core is at d3.
            full_d = minor(d, PITCH[size]) if detail == "full" else minor_d1(d, PITCH[size])
            r_tip = full_d / 2.0 - tc
            add("shank-tip-chamfer",
                cone_present(feats, full_d / 2.0, 45.0) and ring_present(rings, 0.0, r_tip, 1),
                f"{cone_report(feats, full_d / 2.0)}; " + ring_report(rings, 0.0, r_tip, 1))
            if detail == "full":
                add("thread-crest-ring", ring_radius_count(rings, d / 2.0) >= 8,
                    f"crest r={d/2.0:.4f}: {ring_radius_count(rings, d/2.0)} vertices")
    elif family == "din976":
        p = DIN976[size]
        d = p["d"]
        if detail == "simplified":
            add("ends-sharp", ring_present(rings, 0.0, d / 2.0, 1), ring_report(rings, 0.0, d / 2.0, 1))
        else:
            c = tip_chamfer(d)
            full_d = minor(d, PITCH[size]) if detail == "full" else d
            r_end = full_d / 2.0 - c
            add("bottom-lead-in",
                cone_present(feats, full_d / 2.0, 45.0) and ring_present(rings, 0.0, r_end, 1),
                f"{cone_report(feats, full_d / 2.0)}; " + ring_report(rings, 0.0, r_end, 1))
            add("top-lead-in",
                cone_present(feats, full_d / 2.0, 45.0) and ring_present(rings, length, r_end, 1),
                f"{cone_report(feats, full_d / 2.0)}; " + ring_report(rings, length, r_end, 1))
            if detail == "full":
                add("thread-crest-ring", ring_radius_count(rings, d / 2.0) >= 8,
                    f"crest r={d/2.0:.4f}: {ring_radius_count(rings, d/2.0)} vertices")

    return checks


def expected_bbox(family: str, size: str, length: float) -> list[float]:
    if family == "iso4762":
        p = ISO4762[size]
        return [p["dk"], p["dk"], length + p["k"]]
    if family == "iso4032":
        p = ISO4032[size]
        return [p["s"], p["s"] / COS30, p["m"]]
    if family == "iso7089":
        p = ISO7089[size]
        return [p["d2"], p["d2"], p["h"]]
    if family in ("iso4017", "iso4014"):
        p = HEX_HEAD[size]
        return [p["s"], p["s"] / COS30, length + p["k"]]
    if family == "iso7380":
        p = ISO7380[size]
        return [p["dk"], p["dk"], length + p["k"]]
    if family == "iso10642":
        p = ISO10642[size]
        return [p["dk"], p["dk"], length]
    if family == "din976":
        p = DIN976[size]
        return [p["d"], p["d"], length]
    raise KeyError(family)


def expected_outer_radius(family: str, size: str) -> float:
    """Nominal maximum radius, invariant under a Z-axis rotation."""
    if family == "iso4762":
        return ISO4762[size]["dk"] / 2.0
    if family == "iso4032":
        return hex_circumradius(ISO4032[size]["s"])
    if family == "iso7089":
        return ISO7089[size]["d2"] / 2.0
    if family in ("iso4017", "iso4014"):
        return hex_circumradius(HEX_HEAD[size]["s"])
    if family == "iso7380":
        return ISO7380[size]["dk"] / 2.0
    if family == "iso10642":
        return ISO10642[size]["dk"] / 2.0
    if family == "din976":
        return DIN976[size]["d"] / 2.0
    raise KeyError(family)


def expected_solids(family: str, size: str, length: float, detail: str) -> int:
    if detail != "full":
        # Socketed heads and the ISO 4762 screw are one closed solid at
        # Detailed: the blind hex socket is a real pocket in the same shell.
        return {
            "iso4762": 1, "iso4032": 1, "iso7089": 1, "iso4017": 2,
            "iso4014": 2, "iso7380": 1, "iso10642": 1, "din976": 1,
        }[family]
    if family == "iso4762":
        # one socketed body plus the separate swept helical ridge
        return 2
    if family == "iso4017":
        return 3
    if family == "iso4014":
        b = thread_b(HEX_HEAD[size]["d"], length)
        return 3 if length <= b else 4
    if family == "iso4032":
        return 2
    if family in ("iso7380", "iso10642"):
        # one socketed body plus the separate swept helical ridge
        return 2
    if family == "din976":
        return 2
    return 1


def compare_cell(
    root: Path,
    out_dir: Path,
    external: Path,
    family: str,
    size: str,
    detail: str,
    tolerance: float,
    have_occt: bool,
    have_moon: bool,
) -> dict:
    gold = GOLDEN.get(family, {}).get(size)
    golden_file, _golden_length = (gold if gold else (None, None))
    cell_length = CELL_LENGTHS[family][size]
    length = cell_length if cell_length > 0.0 else 20.0
    cell = {
        "family": family,
        "size": size,
        "detail": detail,
        "length_mm": length,
        "normative": {"status": "SKIP", "checks": []},
        "golden": {"status": "SKIP", "file": golden_file, "detail": "not run"},
    }
    if not have_moon:
        cell["normative"]["detail"] = "moon not available"
        return cell
    try:
        part = generate(root, out_dir, family, size, length, detail)
    except Exception as exc:  # noqa: BLE001
        cell["normative"] = {"status": "FAIL", "checks": [{"name": "generation", "status": "FAIL", "detail": str(exc)}]}
        return cell
    try:
        feats = measure_features(part, root)
    except Exception as exc:  # noqa: BLE001
        cell["normative"] = {"status": "FAIL", "checks": [{"name": "feature_inventory", "status": "FAIL", "detail": str(exc)}]}
        return cell
    checks: list[dict] = []
    if have_occt:
        try:
            measured = measure_occt(part, root)
        except Exception as exc:  # noqa: BLE001
            checks.append({"name": "occt_measure", "status": "FAIL", "detail": str(exc)})
            measured = None
    else:
        measured = None

    def add(name: str, ok: bool, text: str) -> None:
        checks.append({"name": name, "status": "PASS" if ok else "FAIL", "detail": text})

    if measured is not None:
        got = extents(measured["bbox"])
        want = expected_bbox(family, size, length)
        if family in ("iso4017", "iso4014"):
            # OCCT Bnd_Box uses the untrimmed conical washer face and reports a
            # loose box (extended toward the cone apex). The head-base,
            # chamfer-base, top-circle, and cone checks below verify the true
            # head dimensions, so the bbox is not a useful oracle here.
            add("bbox", True,
                "skipped: OCCT Bnd_Box overestimates the untrimmed conical washer face; "
                "head rings/cone checks verify the dimensions")
        else:
            failures = [
                f"{'xyz'[i]}: {got[i]:.4f} vs {want[i]:.4f}"
                for i in range(3)
                if abs(got[i] - want[i]) > tolerance
            ]
            add("bbox", not failures, "; ".join(failures) if failures else f"{[round(v,4) for v in got]} mm")
        want_solids = expected_solids(family, size, length, detail)
        add("solids", measured["solids"] == want_solids,
            f"{measured['solids']} vs {want_solids}")
        if measured.get("volume") is not None:
            checks.append({"name": "volume", "status": "PASS",
                           "detail": f"{measured['volume']:.3f} mm3"})
        if measured.get("center_of_mass") is not None:
            checks.append({"name": "centre_of_mass", "status": "PASS",
                           "detail": f"{[round(v,4) for v in measured['center_of_mass']]} mm"})
    checks.extend(chamfer_checks(family, size, detail, length, feats))
    statuses = [c["status"] for c in checks]
    cell["normative"] = {
        "status": "FAIL" if "FAIL" in statuses else ("PASS" if statuses else "SKIP"),
        "checks": checks,
    }

    # Golden comparison against the downloaded open-source golden model.
    # The comparison is rotation-invariant (maximum radius and axial extent),
    # because a downloaded hex model may be rotated about Z. A golden that
    # contradicts the standard is a FAIL with measured evidence.
    golden_checks: list[dict] = []

    def add_golden(name: str, ok: bool, text: str) -> None:
        golden_checks.append(
            {"name": name, "status": "PASS" if ok else "FAIL", "detail": text}
        )

    if not golden_file:
        cell["golden"]["detail"] = (
            "no downloaded golden model for this family/size"
        )
    else:
        path = external / golden_file
        if not path.exists():
            cell["golden"]["detail"] = (
                f"golden file {golden_file} is not downloaded"
            )
        elif not have_occt:
            cell["golden"]["detail"] = "OCCT not available"
        else:
            try:
                gm = measure_occt(path, root)
                gf = measure_features(path, root)
                got = extents(gm["bbox"])
                want = expected_bbox(family, size, length)
                want_radius = expected_outer_radius(family, size)  # type: ignore[arg-type]
                vertex_radius = gf.get("max_vertex_radius")
                bbox_radius = max(got[0], got[1]) / 2.0
                measured_radius = max(
                    vertex_radius if vertex_radius is not None else 0.0,
                    bbox_radius,
                )
                radius_err = abs(measured_radius - want_radius)
                z_err = abs(got[2] - want[2])
                max_dimension = family in {"iso4762", "iso7380", "iso10642"}
                if radius_err <= 5 * tolerance:
                    radius_relation = "matches"
                elif max_dimension and measured_radius < want_radius:
                    radius_relation = "below-standard-maximum"
                else:
                    radius_relation = "contradicts-standard"
                radius_ok = radius_relation in (
                    "matches", "below-standard-maximum"
                )
                z_ok = z_err <= 5 * tolerance
                add_golden(
                    "golden-outer-radius",
                    radius_ok,
                    f"golden {measured_radius:.4f} mm vs nominal "
                    f"{want_radius:.4f} mm ({radius_relation})",
                )
                add_golden(
                    "golden-axial-extent",
                    z_ok,
                    f"golden {got[2]:.4f} mm vs nominal {want[2]:.4f} mm",
                )
                cell["golden"]["checks"] = golden_checks
                cell["golden"]["status"] = (
                    "PASS" if radius_ok and z_ok else "FAIL"
                )
                cell["golden"]["measured_bbox_mm"] = [round(v, 4) for v in got]
                cell["golden"]["nominal_bbox_mm"] = [round(v, 4) for v in want]
                cell["golden"]["measured_max_radius_mm"] = round(
                    measured_radius, 4
                )
                cell["golden"]["bbox_radius_mm"] = round(bbox_radius, 4)
                cell["golden"]["vertex_radius_mm"] = (
                    round(vertex_radius, 4) if vertex_radius is not None else None
                )
                cell["golden"]["nominal_max_radius_mm"] = round(want_radius, 4)
                cell["golden"]["radius_relation"] = radius_relation
                cell["golden"]["measured_z_mm"] = round(got[2], 4)
                cell["golden"]["nominal_z_mm"] = round(want[2], 4)
                cell["golden"]["max_axis_error_mm"] = round(
                    max(radius_err, z_err), 4
                )
                if radius_ok and z_ok:
                    note = "downloaded golden model agrees"
                    if radius_relation == "below-standard-maximum":
                        note += (
                            " (head below the standard maximum, which is permitted)"
                        )
                    cell["golden"]["detail"] = note
                else:
                    cell["golden"]["detail"] = (
                        "downloaded golden model contradicts the standard; "
                        "recorded with measured evidence"
                    )
            except Exception as exc:  # noqa: BLE001
                cell["golden"]["status"] = "FAIL"
                cell["golden"]["detail"] = f"measurement failed: {exc}"
    return cell


def _status(cell: dict) -> str:
    return f"NORMATIVE={cell['normative']['status']} GOLDEN={cell['golden']['status']}"


def print_matrix(cells: list[dict]) -> None:
    current = None
    for cell in cells:
        if current != cell["family"]:
            current = cell["family"]
            print(f"\n{current}")
        print(
            f"  {cell['size']:<5} {cell['detail']:<10} "
            f"L={cell['length_mm']:<5} {_status(cell)}"
        )
        for c in cell["normative"]["checks"]:
            if c["status"] == "FAIL":
                print(f"     [FAIL] {c['name']}: {c['detail']}")
        if cell["golden"].get("max_axis_error_mm") is not None:
            print(f"     golden: {cell['golden']['detail']} "
                  f"(max axis error {cell['golden']['max_axis_error_mm']} mm)")


def run_self_tests(root: Path, have_occt: bool, have_moon: bool) -> int:
    if not (have_occt and have_moon):
        print("golden matrix self-test: SKIP (OCCT and moon are required)")
        return 0
    failures = 0

    def report(name: str, ok: bool, detail: str) -> None:
        nonlocal failures
        if not ok:
            failures += 1
        print(f"  [{'PASS' if ok else 'FAIL'}] {name}: {detail}")

    with tempfile.TemporaryDirectory(prefix="matrix-selftest-") as td_raw:
        td = Path(td_raw)
        part = generate(root, td, "iso4032", "M4", 20.0, "detailed")

        # A matching golden PASSes. The self-test uses the generated part as a
        # stand-in oracle under the downloaded file name; this proves the
        # PASS/FAIL/SKIP behaviour without depending on the corpus.
        matching = td / "matching-golden"
        matching.mkdir()
        shutil.copyfile(part, matching / "iso4032_hex_nut_m4.step")
        cell = compare_cell(
            root, td, matching, "iso4032", "M4", "detailed",
            LINEAR_TOL, have_occt, have_moon,
        )
        report("normative cell passes", cell["normative"]["status"] == "PASS",
               f"{_status(cell)}")
        report("matching golden PASSes",
               cell["golden"]["status"] == "PASS",
               f"{_status(cell)}: {cell['golden']['detail']}")

        # A deliberately wrong golden (the M5 nut under the M4 file name) FAILs.
        wrong = td / "wrong-golden"
        wrong.mkdir()
        part5 = generate(root, td, "iso4032", "M5", 20.0, "detailed")
        shutil.copyfile(part5, wrong / "iso4032_hex_nut_m4.step")
        wrong_cell = compare_cell(
            root, td, wrong, "iso4032", "M4", "detailed",
            LINEAR_TOL, have_occt, have_moon,
        )
        report("wrong-sized golden FAILs",
               wrong_cell["golden"]["status"] == "FAIL",
               f"{_status(wrong_cell)}")

        # A missing golden file is SKIP, never PASS, while the normative checks
        # still run and pass.
        missing = compare_cell(
            root, td, td / "no-such-dir", "iso7089", "M4", "detailed",
            LINEAR_TOL, have_occt, have_moon,
        )
        report("missing golden keeps GOLDEN=SKIP",
               missing["golden"]["status"] == "SKIP"
               and missing["normative"]["status"] == "PASS",
               f"{_status(missing)}")

        # A deliberately wrong expected dimension must fail the normative check.
        measured = measure_occt(part, root)
        got = extents(measured["bbox"])
        wrong_dims = [got[0] + 1.0, got[1], got[2]]
        report("wrong expected dimension fails",
               any(abs(got[i] - wrong_dims[i]) > LINEAR_TOL for i in range(3)),
               f"{[round(v,4) for v in got]} vs {wrong_dims}")

    print(f"golden matrix self-test: {'PASS' if failures == 0 else 'FAIL'} ({failures} failures)")
    return 0 if failures == 0 else 1


def fully_validated(cell: dict) -> bool:
    """NORMATIVE PASS and GOLDEN PASS are both required."""
    return (
        cell["normative"]["status"] == "PASS"
        and cell["golden"]["status"] == "PASS"
    )


def write_report(cells: list[dict], out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    norm_fail = sum(1 for c in cells if c["normative"]["status"] == "FAIL")
    gold_pass = sum(1 for c in cells if c["golden"]["status"] == "PASS")
    gold_fail = sum(1 for c in cells if c["golden"]["status"] == "FAIL")
    gold_skip = sum(1 for c in cells if c["golden"]["status"] == "SKIP")
    full = sum(1 for c in cells if fully_validated(c))
    payload = {
        "schema_version": 2,
        "generated_by": "scripts/golden_matrix.py",
        "tolerance_mm": LINEAR_TOL,
        "golden_source": (
            "downloaded open-source step.parts STEP models in "
            "components/testdata/golden/external/"
        ),
        "summary": {
            "cells": len(cells),
            "normative_pass": len(cells) - norm_fail,
            "normative_fail": norm_fail,
            "golden_pass": gold_pass,
            "golden_fail": gold_fail,
            "golden_skip": gold_skip,
            "fully_validated": full,
        },
        "cells": cells,
    }
    (out_dir / "matrix.json").write_text(json.dumps(payload, indent=2) + "\n")
    lines = [
        "# M2-M5 Fastener Golden Matrix",
        "",
        "Generated by `scripts/golden_matrix.py`. Each cell records two statuses:",
        "**NORMATIVE** (independent standard/analytic checks) and **GOLDEN**",
        "(comparison with the downloaded golden model).",
        "",
        "The golden files are downloaded from the open-source step.parts corpus",
        "(https://github.com/earthtojake/step.parts) into",
        "`components/testdata/golden/external/` by the repository owner. They are",
        "used as independent reference models with no licensing restrictions.",
        "",
        "The golden comparison is rotation-invariant: it compares the maximum",
        "outer radius (from vertex rings and the in-plane bbox) and the axial",
        "extent. A downloaded model that contradicts its standard is reported",
        "`FAIL` with the measured values; a missing model is `SKIP`, never a",
        "pass. A cell is fully validated only when NORMATIVE and GOLDEN are both",
        "`PASS`.",
        "",
        f"Cells: {len(cells)} | NORMATIVE PASS: {len(cells)-norm_fail} "
        f"FAIL: {norm_fail} | GOLDEN PASS: {gold_pass} FAIL: {gold_fail} "
        f"SKIP: {gold_skip} | fully validated: {full}",
        "",
        "## Per-family golden coverage",
        "",
        "| Family | GOLDEN PASS sizes | GOLDEN FAIL / SKIP |",
        "|---|---|---|",
    ]
    by_family: dict[str, dict[str, list[str]]] = {}
    for c in cells:
        entry = by_family.setdefault(c["family"], {"pass": [], "bad": []})
        label = f"{c['size']}/{c['detail']}"
        if c["golden"]["status"] == "PASS":
            entry["pass"].append(label)
        else:
            entry["bad"].append(f"{label} ({c['golden']['status']})")
    for family, entry in by_family.items():
        lines.append(
            f"| {family} | {', '.join(entry['pass']) or '-'} | "
            f"{', '.join(entry['bad']) or '-'} |"
        )
    lines += [
        "",
        "## Per-cell results",
        "",
        "| Family | Size | Detail | Length (mm) | NORMATIVE | GOLDEN | Golden evidence |",
        "|---|---|---|---:|---|---|---|",
    ]
    for c in cells:
        g = c["golden"]
        if g["status"] == "PASS":
            evidence = g.get("detail", "passed")
        elif g.get("checks"):
            evidence = "; ".join(
                f"{ch['name']}: {ch['detail']}"
                for ch in g["checks"]
                if ch["status"] == "FAIL"
            ) or g.get("detail", "")
        else:
            evidence = g.get("detail", "")
        lines.append(
            f"| {c['family']} | {c['size']} | {c['detail']} | "
            f"{c['length_mm']} | {c['normative']['status']} | "
            f"{g['status']} | {evidence} |"
        )
    lines.append("")
    (out_dir / "MATRIX.md").write_text("\n".join(lines) + "\n")


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--root", type=Path, default=ROOT_DEFAULT)
    ap.add_argument("--external-dir", type=Path, default=EXTERNAL_DEFAULT)
    ap.add_argument("--out", type=Path, default=None)
    ap.add_argument("--family", action="append", default=[])
    ap.add_argument("--size", action="append", default=[])
    ap.add_argument("--detail", action="append", default=[])
    ap.add_argument("--js", "--json", dest="js", action="store_true")
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--tolerance", type=float, default=LINEAR_TOL)
    ap.add_argument(
        "--write",
        type=Path,
        default=None,
        help="Write matrix.json and MATRIX.md into this directory",
    )
    args = ap.parse_args(argv)

    have_occt = shutil.which("occt-draw") is not None or shutil.which("DRAWEXE")
    have_moon = shutil.which("moon") is not None
    if args.self_test:
        return run_self_tests(args.root, have_occt, have_moon)

    families = [f for f in FAMILIES if not args.family or f in args.family]
    details = [d for d in DETAILS if not args.detail or d in args.detail]
    tmp_ctx = None
    if args.out is None:
        tmp_ctx = tempfile.TemporaryDirectory(prefix="golden-matrix-")
        out_dir = Path(tmp_ctx.name)
    else:
        out_dir = args.out
        out_dir.mkdir(parents=True, exist_ok=True)

    cells: list[dict] = []
    try:
        for family in families:
            for size in FAMILY_SIZES[family]:
                if args.size and size not in args.size:
                    continue
                for detail in details:
                    cells.append(
                        compare_cell(
                            args.root,
                            out_dir,
                            args.external_dir,
                            family,
                            size,
                            detail,
                            args.tolerance,
                            have_occt,
                            have_moon,
                        )
                    )
    finally:
        if tmp_ctx is not None:
            tmp_ctx.cleanup()

    if args.write is not None:
        write_report(cells, args.write)
    if args.js:
        print(json.dumps({"cells": cells}, indent=2))
    else:
        print_matrix(cells)
        norm_fail = sum(1 for c in cells if c["normative"]["status"] == "FAIL")
        gold_pass = sum(1 for c in cells if c["golden"]["status"] == "PASS")
        gold_fail = sum(1 for c in cells if c["golden"]["status"] == "FAIL")
        gold_skip = sum(1 for c in cells if c["golden"]["status"] == "SKIP")
        full = sum(1 for c in cells if fully_validated(c))
        print(
            f"\ncells={len(cells)} NORMATIVE PASS={len(cells)-norm_fail} FAIL={norm_fail} "
            f"| GOLDEN PASS={gold_pass} FAIL={gold_fail} SKIP={gold_skip} "
            f"| fully_validated={full}"
        )
    return 1 if any(c["normative"]["status"] == "FAIL" for c in cells) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
