#!/usr/bin/env python3
"""Open a STEP file in SolidCraft and restore its mate-connector joint origins.

`Component::write_step` writes a sibling `<step>.connectors.tsv` sidecar when
`STEP_CONNECTOR_SIDECAR` is set. This helper opens the STEP through the
SolidCraft GUI helper (when the helper's control port answers) and adds one
named `joint.origin` per sidecar row, so every named mate connector is visible
by default. When the helper is unavailable it falls back to `open -a SolidCraft`
and the sidecar is left for a later inspection.

Usage:
    python3 scripts/open_with_connectors.py <file.step> [--app SolidCraft]

Environment:
    SOLIDCRAFT_HELPER  override the SolidCraft GUI helper path.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys

DEFAULT_HELPER = "~/.claude/skills/solidcraft-app/scripts/sc_mcp.py"


def helper_path() -> str:
    return os.path.expanduser(os.environ.get("SOLIDCRAFT_HELPER", DEFAULT_HELPER))


def helper_available(helper: str) -> bool:
    if not os.path.exists(helper):
        return False
    try:
        probe = subprocess.run(
            [sys.executable, "-I", helper, "port"],
            capture_output=True,
            text=True,
            timeout=15,
        )
    except (OSError, subprocess.TimeoutExpired):
        return False
    return probe.returncode == 0


def open_with_helper(helper: str, step_path: str) -> tuple[str | None, str]:
    # The GUI helper only reads files under its allowed roots (its cwd and
    # /Users/glenn/src/github.com by default). --view writes to /tmp, so allow
    # the STEP's own directory explicitly.
    allow = os.path.dirname(os.path.abspath(step_path))
    proc = subprocess.run(
        [
            sys.executable,
            "-I",
            helper,
            "--allow-path",
            allow,
            "open",
            step_path,
            "--up",
            "z",
        ],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        return None, (proc.stderr or proc.stdout).strip()
    lines = proc.stdout.strip().splitlines()
    if not lines:
        return None, "the helper returned no component"
    try:
        return json.loads(lines[-1]).get("component"), ""
    except (ValueError, IndexError):
        return None, "\n".join(lines[-3:])


def add_connector_origins(helper: str, step_path: str, component: str) -> tuple[int, int]:
    sidecar = step_path + ".connectors.tsv"
    if not os.path.exists(sidecar):
        return 0, 0
    added = 0
    failed = 0
    with open(sidecar, "r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            cols = line.split("\t")
            if len(cols) < 10:
                continue
            try:
                payload = json.dumps(
                    {
                        "name": "connector/" + cols[0],
                        "occurrence": component,
                        "point": [float(cols[1]), float(cols[2]), float(cols[3])],
                        "z": [float(cols[4]), float(cols[5]), float(cols[6])],
                        "x": [float(cols[7]), float(cols[8]), float(cols[9])],
                    }
                )
            except ValueError:
                continue
            proc = subprocess.run(
                [sys.executable, "-I", helper, "exec", "joint.origin", payload],
                capture_output=True,
                text=True,
            )
            if proc.returncode == 0:
                added += 1
            else:
                detail = (proc.stderr or proc.stdout).strip()
                if "already a joint origin" in detail:
                    # Rerunning against an already-open tab is idempotent.
                    added += 1
                else:
                    failed += 1
    return added, failed


def activate_app(app: str) -> bool:
    """Bring the app window to the front after a helper-driven open.

    `sc_mcp.py open` adds tabs through the app's control port but does not
    activate the app, so restore the old `open -a` foreground behavior.
    """
    if shutil.which("open"):
        proc = subprocess.run(["open", "-a", app], capture_output=True, text=True)
        if proc.returncode == 0:
            return True
    if shutil.which("osascript"):
        proc = subprocess.run(
            ["osascript", "-e", f'tell application "{app}" to activate'],
            capture_output=True,
            text=True,
        )
        return proc.returncode == 0
    return False


def fallback_open(step_path: str, app: str) -> bool:
    if not shutil.which("open"):
        return False
    return subprocess.run(["open", "-a", app, step_path]).returncode == 0


def main(argv: list[str]) -> int:
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__.strip(), file=sys.stderr)
        return 2
    step_path = argv[0]
    app = "SolidCraft"
    for i, arg in enumerate(argv[1:], start=1):
        if arg == "--app" and i + 1 < len(argv):
            app = argv[i + 1]
    if not os.path.exists(step_path):
        print(f"error: no STEP file at {step_path}", file=sys.stderr)
        return 1

    helper = helper_path()
    if helper_available(helper):
        component, error = open_with_helper(helper, step_path)
        if component:
            added, failed = add_connector_origins(helper, step_path, component)
            if added or failed:
                suffix = "" if not failed else f" ({failed} failed)"
                print(
                    f"Opening {step_path} in {app} with {added} connector origin(s){suffix}"
                )
            else:
                print(f"Opening {step_path} in {app}")
            activate_app(app)
            return 0
        print(
            "note: the SolidCraft helper could not open the STEP"
            + (": " + error if error else "")
            + "; falling back to 'open -a'.",
            file=sys.stderr,
        )

    if fallback_open(step_path, app):
        sidecar = step_path + ".connectors.tsv"
        if os.path.exists(sidecar):
            print(
                f"Opening {step_path} in {app}; connector sidecar is at {sidecar}",
                file=sys.stderr,
            )
        else:
            print(f"Opening {step_path} in {app}", file=sys.stderr)
        return 0
    print(f"error: could not open {step_path} in {app}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
