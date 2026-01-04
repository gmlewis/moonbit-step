#!/usr/bin/env python3
"""Compute BFEM resonant frequency from equivalent L and C.

This is intentionally solver-agnostic:
- Get L (and optionally R(f)) from FastHenry / FEM / measurement.
- Get an *effective* C from a capacitance extraction workflow.

Then estimate the (lumped) resonance:
  f0 = 1 / (2*pi*sqrt(L*C))

It also prints the required C for a target f0 given L.

Examples:
  # If you have L and C already:
  ./scripts/bfem_resonance.py --L-uH 120 --C-pF 800

  # If you have L and want required C for a target f0:
  ./scripts/bfem_resonance.py --L-mH 1.0 --target-f0-hz 10000
"""

from __future__ import annotations

import argparse
import math
from dataclasses import dataclass


@dataclass(frozen=True)
class LC:
    L_h: float
    C_f: float


def _f0_hz(lc: LC) -> float:
    if lc.L_h <= 0 or lc.C_f <= 0:
        raise ValueError("L and C must be > 0")
    return 1.0 / (2.0 * math.pi * math.sqrt(lc.L_h * lc.C_f))


def _required_c_f(L_h: float, target_f0_hz: float) -> float:
    if L_h <= 0 or target_f0_hz <= 0:
        raise ValueError("L and target f0 must be > 0")
    w = 2.0 * math.pi * target_f0_hz
    return 1.0 / (w * w * L_h)


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Estimate resonant frequency from L and C.")

    # Inductance inputs (pick one).
    gL = p.add_mutually_exclusive_group(required=True)
    gL.add_argument("--L-h", type=float, help="Inductance in henries")
    gL.add_argument("--L-mH", type=float, help="Inductance in millihenries")
    gL.add_argument("--L-uH", type=float, help="Inductance in microhenries")

    # Capacitance inputs (optional if target-f0 is provided).
    gC = p.add_mutually_exclusive_group(required=False)
    gC.add_argument("--C-f", type=float, help="Capacitance in farads")
    gC.add_argument("--C-nF", type=float, help="Capacitance in nanofarads")
    gC.add_argument("--C-pF", type=float, help="Capacitance in picofarads")

    p.add_argument(
        "--target-f0-hz",
        type=float,
        default=None,
        help="If set, also print required C for this target f0 (given L)",
    )

    return p


def main() -> None:
    args = build_parser().parse_args()

    if args.L_h is not None:
        L_h = float(args.L_h)
    elif args.L_mH is not None:
        L_h = float(args.L_mH) * 1e-3
    else:
        L_h = float(args.L_uH) * 1e-6

    C_f = None
    if args.C_f is not None:
        C_f = float(args.C_f)
    elif args.C_nF is not None:
        C_f = float(args.C_nF) * 1e-9
    elif args.C_pF is not None:
        C_f = float(args.C_pF) * 1e-12

    print(f"L = {L_h:.6g} H")

    if C_f is not None:
        print(f"C = {C_f:.6g} F")
        f0 = _f0_hz(LC(L_h=L_h, C_f=C_f))
        print(f"f0 = {f0:.6g} Hz")

    if args.target_f0_hz is not None:
        C_req = _required_c_f(L_h, float(args.target_f0_hz))
        print(f"C_required_for_f0({args.target_f0_hz:.6g} Hz) = {C_req:.6g} F")
        print(f"  = {C_req*1e12:.6g} pF")

    if C_f is None and args.target_f0_hz is None:
        raise SystemExit("Provide capacitance (--C-*) and/or --target-f0-hz")


if __name__ == "__main__":
    main()
