#!/usr/bin/env python3
"""Generate and validate every component example's STEP output.

This is a lightweight CI counterpart to ``components/examples/generate_all.sh``:
it runs each example with a plain ``-o`` and checks the resulting STEP with
``validate_step.py --no-mesh``. Unlike the generator it writes only to a
temporary directory and does not produce catalog, SVG, PNG, STL, or
OCCT-evaluated artifacts, so it is cheap enough to run on every push.

Examples whose only output is the OCCT-evaluated solid (``write_step_evaluated``
with no flat fallback) are skipped with a notice when Open CASCADE is not
installed, exactly as ``generate_all.sh`` does. The scheduled deep job installs
Open CASCADE and therefore validates them too.

Usage:
    python3 scripts/validate_component_examples.py
    python3 scripts/validate_component_examples.py --only bearing,pvc
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXAMPLES = ROOT / "components" / "examples"
VALIDATOR = ROOT / "scripts" / "validate_step.py"

# Backtrace lines printed after an abort: "    at fn (path:line)" or "    ...".
STACK_FRAME = re.compile(r"^\s{4}(?:at |\.\.\.$)")

# Examples whose main always exports the OCCT-evaluated compound, with no
# nominal flat fallback. Without Open CASCADE they cannot generate. Add an
# example here when its main calls `write_step_evaluated` unconditionally.
OCCT_ONLY_EXAMPLES = frozenset(
    {
        "clamp_shaft_collar",
        "set_screw_collar",
        "tire_mount",
    }
)


def find_occt() -> str | None:
    for bin_name in ["occt-draw", "DRAWEXE"]:
        if shutil.which(bin_name):
            return bin_name
    return None


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


def diagnose(text: str, limit: int = 6) -> str:
    """Last few lines of a failed run, without the async stack frames.

    A MoonBit abort prints its message and then a long backtrace; keeping only
    the last lines hides the message, so drop the frames first.
    """
    lines = [
        line
        for line in text.strip().splitlines()
        if line.strip() and not STACK_FRAME.match(line)
    ]
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

    occt = find_occt()
    skipped: list[str] = []
    failures: list[str] = []
    with tempfile.TemporaryDirectory(prefix="component-examples-") as tmp:
        for d in dirs:
            if occt is None and d.name in OCCT_ONLY_EXAMPLES:
                skipped.append(d.name)
                print(f"SKIP {d.name} (needs OCCT; validated in the deep job)")
                continue
            out = Path(tmp) / f"{d.name}.step"
            gen = subprocess.run(
                ["moon", "run", f"components/examples/{d.name}", "--", "-o", str(out)],
                cwd=ROOT,
                capture_output=True,
                text=True,
            )
            if gen.returncode != 0:
                failures.append(f"{d.name}: generation failed\n{diagnose(gen.stderr + gen.stdout)}")
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
    summary = f"\nall {len(dirs) - len(skipped)} component examples generated and validated"
    if skipped:
        summary += f" ({len(skipped)} skipped: no OCCT)"
    print(summary)
    return 0


if __name__ == "__main__":
    sys.exit(main())
