#!/usr/bin/env python3
"""Quick electrical estimation helper for Example 12 (bifilar electromagnet).

This script is intentionally lightweight: it leverages the MoonBit example’s
`--report` output so you can sweep parameters quickly without parsing STEP/STL.

It currently reports:
- helix-only conductor length (mm, m)
- square cross-section area (mm^2, m^2)
- simple Rdc estimate (requires resistivity rho)
- optional: required capacitance for a target resonance given an assumed L

Notes / limitations
- Length is for the helix geometry only (not cage/connectors/exit wires).
- Self-resonance in real coils is distributed; the required-C estimate is a
  rough feasibility calculator: f0 ≈ 1 / (2π sqrt(L C)).

Example:
  ./scripts/bfem_analyze.py --numPairs 10 --vertTurns 15 --wireWidth 1.0 --wireGap 0.2 \
    --innerDiam 6.0 --rho 1.724e-8 --target-f0-hz 10000 --assumed-L-h 1e-3
"""

from __future__ import annotations

import argparse
import math
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Optional


_REPORT_RE = re.compile(r"^bfem:report:(?P<key>[^=]+)=(?P<value>.*)$")


@dataclass(frozen=True)
class BfemReport:
    wire_width_mm: float
    area_mm2: float
    area_m2: float
    helix_length_mm: float
    helix_length_m: float
    rho_ohm_m: float
    rdc_est_ohm: float
    cage_length_mm: Optional[float] = None
    cage_volume_mm3: Optional[float] = None
    cage_segments: Optional[int] = None
    cage_rdc_est_ohm: Optional[float] = None
    exit_length_mm: Optional[float] = None
    exit_volume_mm3: Optional[float] = None
    exit_segments: Optional[int] = None
    exit_rdc_est_ohm: Optional[float] = None


def _repo_root() -> Path:
    # scripts/ -> repo root
    return Path(__file__).resolve().parents[1]


def run_bfem_report(args: argparse.Namespace) -> BfemReport:
    repo = _repo_root()

    cmd = [
        "moon",
        "run",
        "--target",
        "native",
        "examples/12-bifilar-electromagnet",
        "--",
        "--report",
        "--nocoil" if args.nocoil else "",
        "--nocage" if args.nocage else "",
        "--nowires" if args.nowires else "",
        "--nosupport" if args.nosupport else "",
        "--numPairs",
        str(args.numPairs),
        "--vertTurns",
        str(args.vertTurns),
        "--wireWidth",
        str(args.wireWidth),
        "--wireGap",
        str(args.wireGap),
        "--innerDiam",
        str(args.innerDiam),
        "--numSegs",
        str(args.numSegs),
        "--rho",
        str(args.rho),
        "-o",
        "/dev/null",
    ]
    cmd = [c for c in cmd if c]

    proc = subprocess.run(
        cmd,
        cwd=str(repo),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        sys.stderr.write(proc.stderr)
        raise SystemExit(proc.returncode)

    kv: Dict[str, str] = {}
    for line in proc.stderr.splitlines():
        m = _REPORT_RE.match(line.strip())
        if not m:
            continue
        kv[m.group("key")] = m.group("value")

    missing = [
        k
        for k in [
            "wire_width_mm",
            "area_mm2",
            "area_m2",
            "helix_length_mm",
            "helix_length_m",
            "rho_ohm_m",
            "rdc_est_ohm",
        ]
        if k not in kv
    ]
    if missing:
        raise RuntimeError(f"Missing report keys: {missing}. Got keys={sorted(kv.keys())}")

    def fopt(key: str) -> Optional[float]:
        return float(kv[key]) if key in kv else None

    def iopt(key: str) -> Optional[int]:
        return int(float(kv[key])) if key in kv else None

    return BfemReport(
        wire_width_mm=float(kv["wire_width_mm"]),
        area_mm2=float(kv["area_mm2"]),
        area_m2=float(kv["area_m2"]),
        helix_length_mm=float(kv["helix_length_mm"]),
        helix_length_m=float(kv["helix_length_m"]),
        rho_ohm_m=float(kv["rho_ohm_m"]),
        rdc_est_ohm=float(kv["rdc_est_ohm"]),
        cage_length_mm=fopt("cage_length_mm"),
        cage_volume_mm3=fopt("cage_volume_mm3"),
        cage_segments=iopt("cage_segments"),
        cage_rdc_est_ohm=fopt("cage_rdc_est_ohm"),
        exit_length_mm=fopt("exit_length_mm"),
        exit_volume_mm3=fopt("exit_volume_mm3"),
        exit_segments=iopt("exit_segments"),
        exit_rdc_est_ohm=fopt("exit_rdc_est_ohm"),
    )


def required_capacitance_f0(assumed_L_h: float, target_f0_hz: float) -> float:
    # C = 1 / ((2π f)^2 L)
    return 1.0 / (((2.0 * math.pi * target_f0_hz) ** 2) * assumed_L_h)


def fmt_si(value: float, unit: str) -> str:
    # Simple SI-ish formatting (no dependencies).
    prefixes = [
        (1e-12, "p"),
        (1e-9, "n"),
        (1e-6, "µ"),
        (1e-3, "m"),
        (1.0, ""),
        (1e3, "k"),
        (1e6, "M"),
        (1e9, "G"),
    ]
    if value == 0.0:
        return f"0 {unit}"

    abs_v = abs(value)
    best_scale, best_prefix = 1.0, ""
    for scale, prefix in prefixes:
        if abs_v >= scale:
            best_scale, best_prefix = scale, prefix
    return f"{value / best_scale:.6g} {best_prefix}{unit}"


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Quick estimator for Example 12 electrical geometry.")

    # Mirror the key MoonBit args we care about.
    p.add_argument("--innerDiam", type=float, default=6.0)
    p.add_argument("--numPairs", type=int, default=10)
    p.add_argument("--numSegs", type=int, default=36)
    p.add_argument("--vertTurns", type=float, default=15.0)
    p.add_argument("--wireWidth", type=float, default=1.0)
    p.add_argument("--wireGap", type=float, default=0.2)
    p.add_argument("--rho", type=float, default=1.724e-8, help="Resistivity (ohm*m)")

    p.add_argument("--nocoil", action="store_true")
    p.add_argument("--nocage", action="store_true")
    p.add_argument("--nowires", action="store_true")
    p.add_argument("--nosupport", action="store_true")

    p.add_argument(
        "--target-f0-hz",
        type=float,
        default=None,
        help="If set, compute required C for this target resonance.",
    )
    p.add_argument(
        "--assumed-L-h",
        type=float,
        default=None,
        help="Assumed inductance (Henries) for required-C estimate.",
    )

    p.add_argument(
        "--sweep",
        action="store_true",
        help="Run a parameter sweep (Cartesian product of sweep lists) and rank results.",
    )
    p.add_argument(
        "--sweep-numPairs",
        type=str,
        default=None,
        help="Comma-separated list, e.g. '6,8,10'. Defaults to current --numPairs.",
    )
    p.add_argument(
        "--sweep-vertTurns",
        type=str,
        default=None,
        help="Comma-separated list, e.g. '10,12.5,15'. Defaults to current --vertTurns.",
    )
    p.add_argument(
        "--sweep-wireWidth",
        type=str,
        default=None,
        help="Comma-separated list (mm), e.g. '0.8,1.0,1.2'. Defaults to current --wireWidth.",
    )
    p.add_argument(
        "--sweep-wireGap",
        type=str,
        default=None,
        help="Comma-separated list (mm), e.g. '0.1,0.2,0.3'. Defaults to current --wireGap.",
    )
    p.add_argument(
        "--top",
        type=int,
        default=10,
        help="Show top N sweep results (default: 10).",
    )

    return p


def _parse_csv_ints(s: Optional[str], default: int) -> list[int]:
    if not s:
        return [default]
    return [int(x.strip()) for x in s.split(",") if x.strip()]


def _parse_csv_floats(s: Optional[str], default: float) -> list[float]:
    if not s:
        return [default]
    return [float(x.strip()) for x in s.split(",") if x.strip()]


def capacitance_proxy(helix_length_mm: float, wire_width_mm: float, wire_gap_mm: float) -> float:
    # Very rough: C per-unit-length scales ~ (w / gap) for closely spaced prismatic conductors.
    # Total C then scales with length.
    eps = 1e-9
    return helix_length_mm * wire_width_mm / max(wire_gap_mm, eps)


def print_sweep_results(rows: list[dict], top_n: int) -> None:
    if not rows:
        print("no sweep results")
        return

    rows_sorted = sorted(
        rows,
        key=lambda r: (
            -r["c_proxy"],
            r["rdc_ohm"],
            r["helix_length_m"],
        ),
    )
    print("\nsweep ranking (higher C_proxy better; lower Rdc better)")
    header = (
        "  numPairs vertTurns wireWidth wireGap | helix_m  Rdc_ohm  C_proxy | cage_Rdc exit_Rdc"
    )
    print(header)
    print("  " + "-" * (len(header) - 2))
    for r in rows_sorted[: max(1, top_n)]:
        print(
            "  "
            f"{r['numPairs']:>7} {r['vertTurns']:>8.3g} {r['wireWidth']:>8.3g} {r['wireGap']:>7.3g}"
            " | "
            f"{r['helix_length_m']:>6.3f} {r['rdc_ohm']:>8.4f} {r['c_proxy']:>7.3g}"
            " | "
            f"{r['cage_rdc_ohm']:>7.4f} {r['exit_rdc_ohm']:>7.4f}"
        )


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    if args.sweep:
        num_pairs_list = _parse_csv_ints(args.sweep_numPairs, args.numPairs)
        vert_turns_list = _parse_csv_floats(args.sweep_vertTurns, args.vertTurns)
        wire_width_list = _parse_csv_floats(args.sweep_wireWidth, args.wireWidth)
        wire_gap_list = _parse_csv_floats(args.sweep_wireGap, args.wireGap)

        rows: list[dict] = []
        total = (
            len(num_pairs_list)
            * len(vert_turns_list)
            * len(wire_width_list)
            * len(wire_gap_list)
        )
        print(
            f"bfem_analyze: sweep variants={total} (this runs moon for each variant; first run may be slower)"
        )

        # Reuse the same argparse.Namespace object to avoid re-building.
        for np in num_pairs_list:
            for vt in vert_turns_list:
                for ww in wire_width_list:
                    for wg in wire_gap_list:
                        args.numPairs = np
                        args.vertTurns = vt
                        args.wireWidth = ww
                        args.wireGap = wg
                        report = run_bfem_report(args)
                        c_proxy = capacitance_proxy(
                            report.helix_length_mm, report.wire_width_mm, wg
                        )
                        rows.append(
                            {
                                "numPairs": np,
                                "vertTurns": vt,
                                "wireWidth": ww,
                                "wireGap": wg,
                                "helix_length_m": report.helix_length_m,
                                "rdc_ohm": report.rdc_est_ohm,
                                "c_proxy": c_proxy,
                                "cage_rdc_ohm": float(report.cage_rdc_est_ohm or 0.0),
                                "exit_rdc_ohm": float(report.exit_rdc_est_ohm or 0.0),
                            }
                        )

        print_sweep_results(rows, args.top)
        return 0

    report = run_bfem_report(args)

    print("bfem_analyze: helix-only geometry")
    print(f"  helix length: {report.helix_length_mm:.6g} mm ({fmt_si(report.helix_length_m, 'm')})")
    # Avoid SI-prefix formatting for squared units ("m^2") to prevent confusion (e.g. µm^2).
    print(f"  cross-section area: {report.area_mm2:.6g} mm^2 ({report.area_m2:.6g} m^2)")
    print(f"  rho: {report.rho_ohm_m:.6g} ohm*m")
    print(f"  Rdc (helix-only): {report.rdc_est_ohm:.6g} ohm")

    if report.cage_length_mm is not None:
        print("\nadditional conductors (rough, extrusion-axis assumption)")
        print(
            f"  cage: length {report.cage_length_mm:.6g} mm, volume {report.cage_volume_mm3:.6g} mm^3, "
            f"segments {report.cage_segments}, Rdc {report.cage_rdc_est_ohm:.6g} ohm"
        )
        print(
            f"  exit wires: length {report.exit_length_mm:.6g} mm, volume {report.exit_volume_mm3:.6g} mm^3, "
            f"segments {report.exit_segments}, Rdc {report.exit_rdc_est_ohm:.6g} ohm"
        )

    if (args.target_f0_hz is None) ^ (args.assumed_L_h is None):
        print("\nerror: provide both --target-f0-hz and --assumed-L-h (or neither)", file=sys.stderr)
        return 2

    if args.target_f0_hz is not None and args.assumed_L_h is not None:
        c_req = required_capacitance_f0(args.assumed_L_h, args.target_f0_hz)
        print("\nresonance feasibility (simple LC)")
        print(f"  assumed L: {fmt_si(args.assumed_L_h, 'H')}")
        print(f"  target f0: {fmt_si(args.target_f0_hz, 'Hz')}")
        print(f"  required C: {fmt_si(c_req, 'F')}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
