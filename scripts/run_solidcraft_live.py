#!/usr/bin/env python3
"""Stream a MoonBit-generated SolidCraft JSON command script live into the
running SolidCraft desktop app (sub-second popup, watch every body and boolean
materialize in real time with a full editable feature tree!).

Works on both macOS and Linux, checking `${HOME}/tools/bin/solidcraft-cli`
first and `$PATH` second. Falls back cleanly to headless `solidcraft-cli run`
when `--headless` is passed or when exporting `--out-step` / `--out-3mf`.

Usage:
    python3 scripts/run_solidcraft_live.py script.json
    python3 scripts/run_solidcraft_live.py script.json --headless --out-step out.step
"""

from __future__ import annotations

import argparse
import json
import os
import platform
import select
import shutil
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path


def find_solidcraft_cli() -> str | None:
    home_bin = Path.home() / "tools" / "bin" / "solidcraft-cli"
    if home_bin.is_file() and os.access(home_bin, os.X_OK):
        return str(home_bin)
    return shutil.which("solidcraft-cli")


def _control_dirs() -> list[Path]:
    home = Path.home()
    dirs = [
        home / "Library" / "Application Support" / "SolidCraft" / "control",
        home / ".config" / "SolidCraft" / "control",
        home / ".local" / "share" / "SolidCraft" / "control",
    ]
    return [d for d in dirs if d.is_dir()]


def _port_open(port: int) -> bool:
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=0.4):
            return True
    except OSError:
        return False


def discover_control_port() -> int | None:
    """Find an active SolidCraft GUI control port from `<control>/<port>.token`."""
    candidates: list[tuple[float, int]] = []
    for d in _control_dirs():
        for tok in d.glob("*.token"):
            if tok.stem.isdigit():
                try:
                    mtime = tok.stat().st_mtime
                except OSError:
                    mtime = 0.0
                candidates.append((mtime, int(tok.stem)))
    # Most recently touched token first.
    candidates.sort(reverse=True)
    for _mtime, port in candidates:
        if _port_open(port):
            return port
    return None


def launch_solidcraft_gui() -> None:
    """Launch SolidCraft GUI if it is not already running."""
    sys_name = platform.system()
    if sys_name == "Darwin":
        subprocess.run(
            ["open", "-a", "SolidCraft"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
    else:
        for name in ("solidcraft", "SolidCraft"):
            exe = (
                Path.home() / "tools" / "bin" / name
                if (Path.home() / "tools" / "bin" / name).is_file()
                else shutil.which(name)
            )
            if exe:
                subprocess.Popen(
                    [str(exe)],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    start_new_session=True,
                )
                return


def activate_solidcraft_gui() -> None:
    if platform.system() == "Darwin" and shutil.which("osascript"):
        subprocess.run(
            ["osascript", "-e", 'tell application "SolidCraft" to activate'],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )


class LiveMcpClient:
    """Minimal stdlib JSON-RPC 2.0 client over `solidcraft-cli mcp --connect`."""

    def __init__(
        self, cli: str, port: int, allow_paths: list[str], timeout: float = 600.0
    ) -> None:
        args = [cli, "mcp", "--connect", f"127.0.0.1:{port}"]
        for p in allow_paths:
            args += ["--allow-path", p]
        self.proc = subprocess.Popen(
            args,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
        )
        self.timeout = timeout
        self.next_id = 0
        self._rpc(
            "initialize",
            {
                "protocolVersion": "2025-06-18",
                "capabilities": {},
                "clientInfo": {"name": "moonbit-solidcraft-live", "version": "1.0"},
            },
        )
        self._send({"jsonrpc": "2.0", "method": "notifications/initialized"})

    def close(self) -> None:
        try:
            if self.proc.stdin:
                self.proc.stdin.close()
        except Exception:
            pass
        try:
            self.proc.wait(timeout=5)
        except Exception:
            self.proc.kill()

    def _send(self, msg: dict) -> None:
        assert self.proc.stdin is not None
        self.proc.stdin.write(json.dumps(msg) + "\n")
        self.proc.stdin.flush()

    def _read(self, want_id: int) -> dict:
        assert self.proc.stdout is not None
        deadline = time.monotonic() + self.timeout
        while True:
            rem = deadline - time.monotonic()
            if rem <= 0:
                raise TimeoutError(f"timed out waiting for MCP response {want_id}")
            ready, _, _ = select.select([self.proc.stdout], [], [], rem)
            if not ready:
                raise TimeoutError(f"timed out waiting for MCP response {want_id}")
            line = self.proc.stdout.readline()
            if not line:
                err = self.proc.stderr.read() if self.proc.stderr else ""
                raise RuntimeError(f"MCP proxy exited unexpectedly: {err[:1000]}")
            try:
                msg = json.loads(line)
            except json.JSONDecodeError:
                continue
            if msg.get("id") == want_id:
                return msg

    def _rpc(self, method: str, params: dict | None = None) -> dict:
        self.next_id += 1
        want = self.next_id
        msg: dict = {"jsonrpc": "2.0", "id": want, "method": method}
        if params is not None:
            msg["params"] = params
        self._send(msg)
        resp = self._read(want)
        if "error" in resp:
            raise RuntimeError(f"{method}: {json.dumps(resp['error'])[:1000]}")
        return resp.get("result", {})

    def execute(self, command: str, params: dict) -> dict:
        res = self._rpc(
            "tools/call",
            {"name": "execute", "arguments": {"command": command, "params": params}},
        )
        if res.get("isError"):
            text = "".join(
                b.get("text", "")
                for b in res.get("content", [])
                if b.get("type") == "text"
            )
            raise RuntimeError(f"{command}: {text or json.dumps(res)[:1000]}")
        return res


def collect_allow_paths(script_path: Path, commands: list[dict]) -> list[str]:
    dirs: list[str] = []
    seen: set[str] = set()

    def add_dir(p: Path) -> None:
        s = str(p.resolve())
        if s not in seen and p.exists():
            seen.add(s)
            dirs.append(s)

    add_dir(script_path.parent)
    for step in commands:
        params = step.get("params") or {}
        if isinstance(params, dict) and isinstance(params.get("path"), str):
            add_dir(Path(params["path"]).parent)
    return dirs


def _create_empty_sc_file(cli: str, title: str) -> Path | None:
    """Create a fresh, uniquely named empty `.sc` design in /tmp so `doc.open`
    opens a brand-new tab in SolidCraft without disturbing existing tabs."""
    safe = "".join(c if (c.isalnum() or c in "-_") else "_" for c in title).strip("_") or "design"
    stamp = int(time.time() * 1000) % 1000000
    sc_path = Path(tempfile.gettempdir()) / f"{safe}-{stamp}.sc"
    script = [{"command": "file.save_as", "params": {"path": str(sc_path)}}]
    with tempfile.TemporaryDirectory(prefix="sc-empty-") as td:
        sp = Path(td) / "new.json"
        sp.write_text(json.dumps(script), encoding="utf-8")
        proc = subprocess.run(
            [cli, "run", str(sp), "--validation", "off", "--quiet"],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if proc.returncode == 0 and sc_path.is_file():
            return sc_path
    return None


def run_live(cli: str, script_path: Path, commands: list[dict]) -> int:
    port = discover_control_port()
    if port is None:
        print("Launching SolidCraft...", file=sys.stderr)
        launch_solidcraft_gui()
        for _ in range(30):
            time.sleep(0.4)
            port = discover_control_port()
            if port is not None:
                break
    if port is None:
        print(
            "Error: SolidCraft GUI control port did not become ready.",
            file=sys.stderr,
        )
        return 1

    activate_solidcraft_gui()

    # Replace leading `file.new` (which wipes the active tab!) with `doc.open`
    # on a fresh empty `.sc` file so every `--view` run opens a brand-new tab.
    stream_cmds = list(commands)
    title = script_path.stem
    if stream_cmds and stream_cmds[0].get("command") == "file.new":
        title = (stream_cmds[0].get("params") or {}).get("name") or title
        stream_cmds = stream_cmds[1:]
    fresh_sc = _create_empty_sc_file(cli, title)
    if fresh_sc is not None:
        stream_cmds.insert(
            0, {"command": "doc.open", "params": {"path": str(fresh_sc)}}
        )
    else:
        stream_cmds.insert(
            0, {"command": "file.new", "params": {"name": title}}
        )

    allow = collect_allow_paths(script_path, stream_cmds)
    total = len(stream_cmds)
    print(
        f"Streaming {total} commands live into SolidCraft (port {port})...",
        file=sys.stderr,
    )
    client = LiveMcpClient(cli, port, allow)
    prev_validation: str | None = None
    try:
        try:
            vres = client.execute("diagnostics.validation", {"mode": "off"})
            vtext = "".join(
                b.get("text", "")
                for b in vres.get("content", [])
                if b.get("type") == "text"
            )
            if vtext:
                vdata = json.loads(vtext)
                prev_validation = vdata.get("previous")
        except Exception:
            prev_validation = None

        for idx, step in enumerate(stream_cmds, 1):
            cmd = step["command"]
            params = step.get("params") or {}
            label = (
                params.get("name")
                or params.get("body_name")
                or params.get("target")
                or ""
            )
            suffix = f" ({label})" if label else ""
            print(f"  [{idx}/{total}] {cmd}{suffix}", file=sys.stderr)
            client.execute(cmd, params)
    finally:
        if prev_validation:
            try:
                client.execute(
                    "diagnostics.validation", {"mode": prev_validation}
                )
            except Exception:
                pass
        client.close()
    print("Live SolidCraft build complete.", file=sys.stderr)
    return 0


def run_headless(
    cli: str,
    commands: list[dict],
    out_step: Path | None,
    out_3mf: Path | None,
    timeout: float,
) -> int:
    run_cmds = [c for c in commands if c.get("command") != "file.new"]
    if out_step is not None:
        out_step.parent.mkdir(parents=True, exist_ok=True)
        run_cmds.append(
            {
                "command": "file.export_step",
                "params": {"path": str(out_step.resolve())},
            }
        )
    if out_3mf is not None:
        out_3mf.parent.mkdir(parents=True, exist_ok=True)
        run_cmds.append(
            {
                "command": "file.export_3mf",
                "params": {
                    "path": str(out_3mf.resolve()),
                    "lay_on_print_faces": False,
                    "quality": "fine",
                },
            }
        )
    with tempfile.TemporaryDirectory(prefix="sc-run-") as tmp:
        sp = Path(tmp) / "script.json"
        sp.write_text(json.dumps(run_cmds, indent=2), encoding="utf-8")
        proc = subprocess.run(
            [cli, "run", str(sp), "--validation", "off", "--quiet"],
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        if proc.returncode != 0:
            print(
                f"Error: solidcraft-cli failed:\n{proc.stderr or proc.stdout}",
                file=sys.stderr,
            )
            return proc.returncode
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Stream a MoonBit SolidCraft script live into SolidCraft GUI (or run headless)."
    )
    parser.add_argument("script", type=Path, help="Input SolidCraft script.json")
    parser.add_argument(
        "--headless",
        action="store_true",
        help="Run headless via solidcraft-cli instead of streaming to the GUI",
    )
    parser.add_argument("--out-step", type=Path, help="Export STEP in headless mode")
    parser.add_argument("--out-3mf", type=Path, help="Export 3MF in headless mode")
    parser.add_argument("--timeout", type=float, default=600.0)
    args = parser.parse_args(argv)

    cli = find_solidcraft_cli()
    if not cli:
        print(
            "Error: solidcraft-cli not found (checked ~/tools/bin and PATH).",
            file=sys.stderr,
        )
        return 1

    commands = json.loads(args.script.read_text(encoding="utf-8"))
    if args.headless or args.out_step or args.out_3mf:
        return run_headless(cli, commands, args.out_step, args.out_3mf, args.timeout)
    return run_live(cli, args.script, commands)


if __name__ == "__main__":
    raise SystemExit(main())
