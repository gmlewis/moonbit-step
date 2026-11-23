#!/usr/bin/env python3
"""Generate and validate every component example's STEP output.

This is a lightweight CI counterpart to ``components/examples/generate_all.sh``:
it runs each example with a plain ``-o`` and checks the resulting STEP with
``validate_step.py --no-mesh``. Unlike the generator it writes only to a
temporary directory and does not produce catalog, SVG, PNG, STL, or
OCCT-evaluated artifacts, so it is cheap enough to run on every push.

Usage:
    python3 scripts/validate_component_examples.py
    python3 scripts/validate_component_examples.py --only bearing,pvc
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXAMPLES = ROOT / "components" / "examples"
VALIDATOR = ROOT / "scripts" / "validate_step.py"


def example_dirs(only: str | None) -> list[Path]:
    dirs = sorted(p for p in EXAMPLES.iterdir() if (p / "main.mbt").is_file())
    if only:
        wanted = {name.strip() for name in only.split(",") if name.strip()}
        unknown = wanted - {p.name for p in dirs}
        if unknown:
            raise SystemExit(f"error: unknown example(s): {', '.join(sorted(unknown))}")
        dirs = [p for p in dirs if p.name in wanted]
    return dirs


def tail(text: str, limit: int = 8) -> str:
    lines = [line for line in text.strip().splitlines() if line.strip()]
    return "\n".join(lines[-limit:]) or "(no output)"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--only",
        help="comma-separated example names to validate (default: all)",
    )
    args = parser.parse_args()
    dirs = example_dirs(args.only)
    if not dirs:
        print("error: no component examples found", file=sys.stderr)
        return 1

    failures: list[str] = []
    with tempfile.TemporaryDirectory(prefix="component-examples-") as tmp:
        for d in dirs:
            out = Path(tmp) / f"{d.name}.step"
            gen = subprocess.run(
                ["moon", "run", f"components/examples/{d.name}", "--", "-o", str(out)],
                cwd=ROOT,
                capture_output=True,
                text=True,
            )
            if gen.returncode != 0:
                failures.append(f"{d.name}: generation failed\n{tail(gen.stderr + gen.stdout)}")
                continue
            val = subprocess.run(
                [sys.executable, str(VALIDATOR), "--no-mesh", str(out)],
                cwd=ROOT,
                capture_output=True,
                text=True,
            )
            if val.returncode != 0:
                failures.append(f"{d.name}: STEP validation failed\n{tail(val.stdout + val.stderr)}")
                continue
            print(f"OK   {d.name}")

    if failures:
        print(f"\n{len(failures)} of {len(dirs)} component examples failed:", file=sys.stderr)
        for failure in failures:
            print(f"FAIL {failure}", file=sys.stderr)
        return 1
    print(f"\nall {len(dirs)} component examples generated and validated")
    return 0


if __name__ == "__main__":
    sys.exit(main())
