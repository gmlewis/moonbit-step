#!/usr/bin/env python3
"""One-command proof: export BFEM conductor network and verify connectivity.

This runs the MoonBit Example 12 generator with:
  --nostep
  --export_conductor_network <tmp.json>

Then runs the connectivity verifier on that JSON.

Example:
  ./scripts/bfem_prove_single_wire.py
  ./scripts/bfem_prove_single_wire.py --numPairs 10 --vertTurns 15
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import tempfile
from pathlib import Path


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Export BFEM conductor network and prove single-wire connectivity.")

    # Mirror key MoonBit args.
    p.add_argument("--innerDiam", type=float, default=6.0)
    p.add_argument("--numPairs", type=int, default=10)
    p.add_argument("--numSegs", type=int, default=36)
    p.add_argument("--vertTurns", type=float, default=15.0)
    p.add_argument("--wireWidth", type=float, default=1.0)
    p.add_argument("--wireGap", type=float, default=0.2)

    p.add_argument("--nocage", action="store_true")
    p.add_argument("--nocoil", action="store_true")
    p.add_argument("--nowires", action="store_true")
    p.add_argument("--nosupport", action="store_true")

    p.add_argument("--tol-mm", type=float, default=1e-3, help="Quantization tolerance for node matching")

    return p


def _run(cmd: list[str], cwd: Path) -> None:
    proc = subprocess.run(cmd, cwd=str(cwd), text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.stdout:
        sys.stdout.write(proc.stdout)
    if proc.stderr:
        sys.stderr.write(proc.stderr)
    if proc.returncode != 0:
        raise SystemExit(proc.returncode)


def main() -> None:
    args = build_parser().parse_args()
    repo = _repo_root()

    with tempfile.TemporaryDirectory(prefix="bfem_single_wire_") as td:
        json_path = Path(td) / "bfem_conductor_network.json"

        export_cmd = [
            "moon",
            "run",
            "--target",
            "native",
            "examples/12-bifilar-electromagnet",
            "--",
            "--nostep",
            "--export_conductor_network",
            str(json_path),
            "--innerDiam",
            str(args.innerDiam),
            "--numPairs",
            str(args.numPairs),
            "--numSegs",
            str(args.numSegs),
            "--vertTurns",
            str(args.vertTurns),
            "--wireWidth",
            str(args.wireWidth),
            "--wireGap",
            str(args.wireGap),
        ]
        if args.nocage:
            export_cmd.append("--nocage")
        if args.nocoil:
            export_cmd.append("--nocoil")
        if args.nowires:
            export_cmd.append("--nowires")
        if args.nosupport:
            export_cmd.append("--nosupport")

        sys.stdout.write(f"Exporting conductor network: {json_path}\n")
        _run(export_cmd, cwd=repo)

        verify_cmd = [
            sys.executable,
            str(repo / "scripts" / "bfem_verify_connectivity.py"),
            str(json_path),
            "--tol-mm",
            str(args.tol_mm),
        ]
        sys.stdout.write("\nVerifying connectivity...\n")
        _run(verify_cmd, cwd=repo)


if __name__ == "__main__":
    main()
