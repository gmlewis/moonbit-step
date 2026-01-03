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

    return BfemReport(
        wire_width_mm=float(kv["wire_width_mm"]),
        area_mm2=float(kv["area_mm2"]),
        area_m2=float(kv["area_m2"]),
        helix_length_mm=float(kv["helix_length_mm"]),
        helix_length_m=float(kv["helix_length_m"]),
        rho_ohm_m=float(kv["rho_ohm_m"]),
        rdc_est_ohm=float(kv["rdc_est_ohm"]),
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

    return p


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    report = run_bfem_report(args)

    print("bfem_analyze: helix-only geometry")
    print(f"  helix length: {report.helix_length_mm:.6g} mm ({fmt_si(report.helix_length_m, 'm')})")
    print(f"  cross-section area: {report.area_mm2:.6g} mm^2 ({fmt_si(report.area_m2, 'm^2')})")
    print(f"  rho: {report.rho_ohm_m:.6g} ohm*m")
    print(f"  Rdc (helix-only): {report.rdc_est_ohm:.6g} ohm")

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
