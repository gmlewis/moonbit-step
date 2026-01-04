#!/usr/bin/env python3
"""Parse FastHenry `Zc.mat` for a 1-port BFEM deck and derive R/L.

FastHenry dumps impedance matrices to `Zc.mat`. For the BFEM deck we generate,
there is exactly 1 conductor -> a 1x1 complex impedance Z(f).

This script extracts the first (and only) Z entry at each frequency, and prints:
- f (Hz)
- R (ohms) = Re(Z)
- L (henries) = Im(Z) / (2*pi*f)

It is intentionally tolerant to different `Zc.mat` textual formats.

Usage:
  ./scripts/bfem_parse_fasthenry_zc.py examples/12-bifilar-electromagnet/Zc.mat

Then estimate SRF with an effective capacitance (e.g. air-only estimate):
  ./scripts/bfem_resonance.py --L-h <L> --C-pF <C>
"""

from __future__ import annotations

import argparse
import math
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List, Optional, Tuple


@dataclass(frozen=True)
class ZPoint:
    f_hz: float
    r_ohm: float
    x_ohm: float


_FLOAT_RE = re.compile(r"[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?")


def _floats_in_line(line: str) -> List[float]:
    return [float(m.group(0)) for m in _FLOAT_RE.finditer(line)]


def _looks_like_freq_line(line: str) -> Optional[float]:
    # Common patterns: "Frequency = 1" or "freq 1".
    if "freq" not in line.lower():
        return None
    nums = _floats_in_line(line)
    if not nums:
        return None
    # Prefer the last number on the line.
    return float(nums[-1])


def _iter_zpoints(lines: Iterable[str]) -> Iterable[ZPoint]:
    """Heuristic parser for 1x1 Zc.mat.

    Strategy:
    - Track current frequency when we see a freq-ish line.
    - After a frequency is set, look for the first line that contains at least
      two floats; interpret them as (Re, Im) for Z.
    - Yield a ZPoint and then clear frequency so we don't accidentally consume
      subsequent metadata.

    We intentionally do *not* use a pre-frequency fallback because the header
    often contains integers like "Row 1 ... 0 ... 10823" which can be misread
    as numeric data.
    """

    cur_f: Optional[float] = None
    for raw in lines:
        line = raw.strip()
        if not line:
            continue

        f = _looks_like_freq_line(line)
        if f is not None:
            cur_f = f
            continue

        nums = _floats_in_line(line)
        if cur_f is not None:
            if len(nums) >= 2:
                r, x = float(nums[0]), float(nums[1])
                yield ZPoint(f_hz=cur_f, r_ohm=r, x_ohm=x)
                cur_f = None
            continue

        # No fallback parsing before a frequency line.


def parse_zc(path: Path) -> List[ZPoint]:
    txt = path.read_text(encoding="utf-8", errors="replace").splitlines()
    points = list(_iter_zpoints(txt))
    if not points:
        raise ValueError("Could not find any (freq, Re, Im) data in Zc.mat")
    return points


def main() -> None:
    ap = argparse.ArgumentParser(description="Parse FastHenry Zc.mat and compute R/L.")
    ap.add_argument("zc", type=Path, help="Path to Zc.mat")
    args = ap.parse_args()

    pts = parse_zc(args.zc)

    print("f_Hz\tR_ohm\tX_ohm\tL_H")
    for p in pts:
        if p.f_hz <= 0:
            L = float("nan")
        else:
            L = p.x_ohm / (2.0 * math.pi * p.f_hz)
        print(f"{p.f_hz:.12g}\t{p.r_ohm:.12g}\t{p.x_ohm:.12g}\t{L:.12g}")


if __name__ == "__main__":
    main()
