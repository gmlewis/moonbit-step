#!/usr/bin/env bash
#
# compare-golden.sh — generate the parametric counterpart of one or more
# downloaded golden STEP files and open both side by side in SolidCraft.
#
# The golden files in components/testdata/golden/external/ are sorted by file
# name and numbered from 1. The manifest's generation block is used when it
# exists; otherwise the file name is mapped to the equivalent parametric
# example (ISO 4762/4017/4032/7089/7380/10642/DIN 976, bearings, spur gears).
#
# Usage:
#   ./scripts/compare-golden.sh --list
#   ./scripts/compare-golden.sh 1 3
#   ./scripts/compare-golden.sh 01-03 07
#   ./scripts/compare-golden.sh --all
#   ./scripts/compare-golden.sh --all --batch 8
#   ./scripts/compare-golden.sh 5 --detail simplified
#   ./scripts/compare-golden.sh 5 --no-open
#
# Options:
#   --list              list the numbered golden files and their equivalents
#   --all               select every golden that has a parametric equivalent
#   --detail LEVEL      simplified | detailed (default) | full
#   --threads REP       none | helical | cosmetic (fasteners only)
#   --batch N           open N pairs at a time, waiting between batches
#   --reuse             reuse an existing generated file instead of rebuilding
#   --no-open           generate only; print the paths
#   --helper            open through the running SolidCraft GUI helper with
#                       --up z (no up-axis dialog), if it is installed
#   --app NAME          macOS app name for `open -a` (default SolidCraft)
#   --out DIR           output directory (default target/golden-compare)
#
# Golden-specific: step.parts "*_open_simple" bearings are two-ring envelopes
# with no rolling elements, so they are generated as rings-only at Simplified
# detail by default. Pass --detail explicitly to override that choice.
#
# Output files are written under target/golden-compare/ as
# `parametric-<golden file name>` so the pair is easy to identify.
#
set -euo pipefail

# Resolve the script's real location, following symlinks. A git-ignored
# ./compare-golden.sh symlink at the repository root must locate the same
# repository as scripts/compare-golden.sh, so use the resolved target's
# directory rather than the symlink's directory.
SOURCE="${BASH_SOURCE[0]:-$0}"
while [ -h "${SOURCE}" ]; do
  SOURCE_DIR="$(cd -P "$(dirname "${SOURCE}")" && pwd)"
  SOURCE="$(readlink "${SOURCE}")"
  case "${SOURCE}" in
    /*) ;;
    *) SOURCE="${SOURCE_DIR}/${SOURCE}" ;;
  esac
done
SCRIPT_DIR="$(cd -P "$(dirname "${SOURCE}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

exec python3 -I - "${ROOT}" "$@" <<'PY'
import glob
import json
import os
import re
import shlex
import shutil
import subprocess
import sys

ROOT = sys.argv[1]
USER = sys.argv[2:]
GOLDEN_DIR = os.path.join(ROOT, "components", "testdata", "golden", "external")
MANIFEST = os.path.join(ROOT, "components", "testdata", "golden", "manifest.json")
DEFAULT_OUT = os.path.join(ROOT, "target", "golden-compare")

# Downloaded goldens whose catalog geometry contradicts the designation in the
# file name. Generate the closest standard envelope for shape review and record
# the contradiction in the label and in the generation output. The library's
# own size table stays standard-correct; the golden is not copied.
GOLDEN_OVERRIDES = {
    "bearing_6003_open_simple.step": {
        "bearing": "628",
        "note": "golden measures 8x24x8 (628-like); ISO 15 6003 is 17x35x10",
    },
}

USAGE = """\
compare-golden.sh — generate and open parametric/golden STEP pairs.

Golden files are sorted by name and numbered from 1.
  ./scripts/compare-golden.sh --list
  ./scripts/compare-golden.sh 1 3
  ./scripts/compare-golden.sh 01-03 07
  ./scripts/compare-golden.sh --all
  ./scripts/compare-golden.sh --all --batch 8
  ./scripts/compare-golden.sh 5 --detail simplified
  ./scripts/compare-golden.sh 5 --no-open
  ./scripts/compare-golden.sh --commands --all
  ./scripts/compare-golden.sh --commands 1 3

Options:
  --list            list the numbered golden files and their equivalents
  --all             select every golden that has a parametric equivalent
  --detail LEVEL    simplified | detailed (default) | full
                    (*_open_simple bearings default to simplified, rings-only)
  --threads REP     none | helical | cosmetic (fasteners only)
  --batch N         open N pairs at a time, waiting between batches
  --reuse           reuse an existing generated file instead of rebuilding
  --no-open         generate only; print the paths
  --commands        print the exact `moon run` command for each selection
  --helper          open through the running SolidCraft GUI helper with
                    --up z (no up-axis dialog), if it is installed
  --app NAME        macOS app name for `open -a` (default SolidCraft)
  --out DIR         output directory (default target/golden-compare)
"""


def fail(message, code=2, hint=True):
    print("error: " + message, file=sys.stderr)
    if hint:
        print("Run with --help for usage.", file=sys.stderr)
    sys.exit(code)


def normalize_detail(text):
    t = text.strip().lower()
    if t in ("simplified", "simple", "simp", "1"):
        return "simplified"
    if t in ("detailed", "detail", "2"):
        return "detailed"
    if t in ("full", "fully-modeled", "fully_modeled", "fullymodeled", "3"):
        return "full"
    fail("unknown detail level {!r} (use simplified, detailed, or full)".format(text))


def normalize_threads(text):
    t = text.strip().lower()
    if t in ("none", "helical", "modeled", "cosmetic"):
        return "helical" if t == "modeled" else t
    fail("unknown thread representation {!r} (use none, helical, or cosmetic)".format(text))


def arg_value(args, key):
    if key in args:
        i = args.index(key)
        if i + 1 < len(args):
            return args[i + 1]
    return None


def size_symbol(token):
    return "M" + token.replace("p", ".")


def fastener(standard, size, length, detail):
    args = ["--standard", standard, "--size", size_symbol(size)]
    if length is not None:
        args += ["--length", str(int(length))]
    args += ["--detail", detail]
    return ("components/examples/fasteners", args)


# File-name inference for the downloaded corpus. The manifest wins when it
# carries a generation block; this covers the rest of the standardized corpus.
def infer(name, detail):
    m = re.match(r"^iso4762_socket_head_cap_screw_m(\d+(?:p\d+)?)x(\d+)\.step$", name)
    if m:
        return fastener("iso4762", m.group(1), m.group(2), detail)
    m = re.match(r"^socket_head_cap_screw_m(\d+(?:p\d+)?)_l(\d+)_simple\.step$", name)
    if m:
        return fastener("iso4762", m.group(1), m.group(2), detail)
    m = re.match(r"^iso4032_hex_nut_m(\d+(?:p\d+)?)\.step$", name)
    if m:
        return fastener("iso4032", m.group(1), None, detail)
    m = re.match(r"^hex_nut_m(\d+(?:p\d+)?)_simple\.step$", name)
    if m:
        return fastener("iso4032", m.group(1), None, detail)
    m = re.match(r"^iso10642_socket_countersunk_screw_m(\d+(?:p\d+)?)x(\d+)\.step$", name)
    if m:
        return fastener("iso10642", m.group(1), m.group(2), detail)
    m = re.match(r"^countersunk_socket_screw_m(\d+(?:p\d+)?)_l(\d+)_simple\.step$", name)
    if m:
        return fastener("iso10642", m.group(1), m.group(2), detail)
    m = re.match(r"^button_head_screw_m(\d+(?:p\d+)?)_l(\d+)_simple\.step$", name)
    if m:
        return fastener("iso7380", m.group(1), m.group(2), detail)
    m = re.match(r"^hex_head_bolt_m(\d+(?:p\d+)?)_l(\d+)_simple\.step$", name)
    if m:
        return fastener("iso4017", m.group(1), m.group(2), detail)
    m = re.match(r"^flat_washer_normal_m(\d+(?:p\d+)?)_simple\.step$", name)
    if m:
        return fastener("iso7089", m.group(1), None, detail)
    m = re.match(r"^iso_metric_threaded_rod_m(\d+(?:p\d+)?)_l(\d+)_simple\.step$", name)
    if m:
        return fastener("din976", m.group(1), m.group(2), detail)
    m = re.match(r"^bearing_(\d{3,4})(?:zz)?(?:_.*)?\.step$", name)
    if m:
        return (
            "components/examples/bearing",
            ["--bearing", m.group(1), "--detail", detail],
        )
    m = re.match(r"^spur_gear_m(\d+)_0_(\d+)t_bore(\d+)\.step$", name)
    if m:
        return (
            "components/examples/gear_pair",
            [
                "--module", m.group(1),
                "--teeth", m.group(2),
                "--faceWidth", "16",
                "--bore", m.group(3),
                "--single",
            ],
        )
    return None


def set_option(args, key, value):
    if key in args:
        i = args.index(key)
        if i + 1 < len(args):
            args[i + 1] = value
        else:
            args.append(value)
    else:
        args += [key, value]


def adjust_for_golden(name, tool, args, detail, detail_explicit):
    """Pick the representation the golden declares, where the family varies.

    The step.parts "*_open_simple" bearings are two-ring envelopes with no
    rolling elements and sharp ring edges, so generate the matching rings-only
    simplified parametric model (the builder accepts --rollers 0). If the user
    passed --detail explicitly, honour it and only drop the rolling elements.
    """
    if tool is None:
        return tool, args, None
    args = list(args)
    note = None
    override = GOLDEN_OVERRIDES.get(name)
    if override and tool.endswith("/bearing"):
        designation = override.get("bearing")
        if designation:
            set_option(args, "--bearing", designation)
        note = override.get("note")
    if tool.endswith("/bearing") and name.endswith("zz.step"):
        # A ZZ golden is a shielded bearing: one solid, recessed face shield
        # grooves, no rolling elements.
        if "--shielded" not in args:
            args.append("--shielded")
        set_option(args, "--detail", "simplified")
        note = (
            "golden is a shielded 608ZZ: one solid with recessed face shield "
            "grooves and no balls"
        )
    if tool.endswith("/bearing") and name.endswith("_open_simple.step"):
        set_option(args, "--rollers", "0")
        if not detail_explicit:
            set_option(args, "--detail", "simplified")
    if detail_explicit and (
        tool.endswith("/fasteners") or tool.endswith("/bearing")
    ):
        set_option(args, "--detail", detail)
    return tool, args, note


def describe(tool, args):
    if tool.endswith("/fasteners"):
        standard = arg_value(args, "--standard") or "?"
        size = arg_value(args, "--size") or "?"
        length = arg_value(args, "--length")
        detail = arg_value(args, "--detail") or "detailed"
        text = "{} {}".format(standard.upper(), size)
        if length is not None:
            text += " x " + length
        return "{} [{}]".format(text, detail)
    if tool.endswith("/bearing"):
        if "--shielded" in args:
            return "bearing {} shielded (face grooves, no balls)".format(
                arg_value(args, "--bearing") or "?"
            )
        text = "bearing {} [{}]".format(
            arg_value(args, "--bearing") or "?", arg_value(args, "--detail") or "detailed"
        )
        if arg_value(args, "--rollers") == "0":
            text += " rings-only"
        return text
    if tool.endswith("/gear_pair"):
        return "spur gear m{} z{} bore {}".format(
            arg_value(args, "--module") or "?",
            arg_value(args, "--teeth") or "?",
            arg_value(args, "--bore") or "0",
        )
    return " ".join(args)


def load_manifest_generations():
    table = {}
    try:
        with open(MANIFEST, "r", encoding="utf-8") as fh:
            manifest = json.load(fh)
    except OSError as exc:
        print("note: cannot read {} ({})".format(MANIFEST, exc))
        return table
    except ValueError as exc:
        print("note: cannot parse {} ({})".format(MANIFEST, exc))
        return table
    for entry in manifest.get("external_references", []):
        local = entry.get("local_filename")
        generation = entry.get("generation")
        if not local or not generation:
            continue
        tool = generation.get("tool")
        args = generation.get("args")
        if tool and isinstance(args, list):
            table[os.path.basename(local)] = (tool, list(args))
    return table


def build_rows(detail, detail_explicit):
    files = sorted(
        glob.glob(os.path.join(GOLDEN_DIR, "*.step")), key=os.path.basename
    )
    if not files:
        fail(
            "no golden STEP files in {}. Run the fetch script first:\n"
            "  python3 scripts/fetch_golden_references.py "
            "--out components/testdata/golden/external".format(GOLDEN_DIR)
        )
    manifest = load_manifest_generations()
    rows = []
    for index, path in enumerate(files, 1):
        name = os.path.basename(path)
        tool = None
        args = None
        if name in manifest:
            tool, args = manifest[name]
        else:
            inferred = infer(name, detail)
            if inferred:
                tool, args = inferred
        tool, args, note = adjust_for_golden(
            name, tool, args, detail, detail_explicit
        )
        label = describe(tool, args) if tool else "no parametric equivalent"
        if note:
            label += " — " + note
        rows.append(
            {
                "index": index,
                "name": name,
                "path": path,
                "tool": tool,
                "args": args,
                "label": label,
                "note": note,
            }
        )
    return rows


def parse_selection(tokens, count):
    selected = []
    for token in tokens:
        for part in token.split(","):
            part = part.strip()
            if not part:
                continue
            if ".." in part:
                lo, hi = part.split("..", 1)
            elif "-" in part and not part.startswith("-"):
                lo, hi = part.split("-", 1)
            else:
                lo = hi = part
            try:
                lo_i = int(lo)
                hi_i = int(hi)
            except ValueError:
                fail("cannot parse index/range {!r}".format(part))
            if lo_i < 1 or hi_i > count or lo_i > hi_i:
                fail(
                    "index/range {!r} is outside 1..{}".format(part, count)
                )
            selected.extend(range(lo_i, hi_i + 1))
    return sorted(set(selected))


def generation_command(row, threads, out_path):
    tool = row["tool"]
    # The row's args already carry the effective detail level (the manifest
    # value, the inferred value, or the user's explicit --detail, adjusted for
    # the golden's declared representation).
    args = list(row["args"])
    if threads and tool.endswith("/fasteners"):
        if "--threads" in args:
            i = args.index("--threads")
            if i + 1 < len(args):
                args[i + 1] = threads
            else:
                args.append(threads)
        else:
            args += ["--threads", threads]
    if "-o" in args:
        i = args.index("-o")
        if i + 1 < len(args):
            args[i + 1] = out_path
        else:
            args.append(out_path)
    else:
        args += ["-o", out_path]
    return ["moon", "run", "--target", "native", tool, "--"] + args


def wait_for_enter(message):
    """Wait on the controlling terminal.

    The script's stdin is the heredoc that carries this Python program, so
    sys.stdin is already at EOF and is never a TTY. /dev/tty is the terminal
    the user actually ran the script from.
    """
    try:
        fd = os.open("/dev/tty", os.O_RDWR)
    except OSError:
        return False
    try:
        os.write(fd, message.encode("utf-8", "replace"))
        while True:
            chunk = os.read(fd, 1)
            if not chunk or chunk in (b"\n", b"\r"):
                break
        return True
    except OSError:
        return False
    finally:
        try:
            os.close(fd)
        except OSError:
            pass


def split_batches(paths, batch):
    if batch and batch > 0:
        size = 2 * batch  # two files (golden + parametric) per pair
    else:
        size = len(paths)
    return [paths[start:start + size] for start in range(0, len(paths), size)]


def open_paths(paths, app, batch, use_helper):
    if not paths:
        return 0

    helper_cmd = None
    if use_helper:
        helper = os.path.expanduser(
            "~/.claude/skills/solidcraft-app/scripts/sc_mcp.py"
        )
        if not os.path.exists(helper):
            print(
                "note: SolidCraft helper not found at {}; falling back to "
                "`open -a {}`".format(helper, app)
            )
        else:
            probe = subprocess.run(
                [sys.executable, "-I", helper, "port"],
                capture_output=True,
                text=True,
            )
            if probe.returncode != 0:
                print(
                    "note: no running SolidCraft GUI control port; falling "
                    "back to `open -a {}`".format(app)
                )
            else:
                helper_cmd = [sys.executable, "-I", helper, "open"]

    if helper_cmd is None and not shutil.which("open"):
        print("`open` is not available; generated files:")
        for path in paths:
            print("  " + path)
        return 0

    chunks = split_batches(paths, batch)
    status = 0
    for index, chunk in enumerate(chunks, 1):
        if helper_cmd is not None:
            cmd = helper_cmd + chunk + ["--up", "z", "--continue-on-error"]
            print(
                "opening {}/{} file(s) through the SolidCraft GUI helper".format(
                    len(chunk), len(paths)
                )
            )
            proc = subprocess.run(cmd, capture_output=True, text=True)
            if proc.stdout.strip():
                print(proc.stdout.strip())
            if proc.returncode != 0:
                status = proc.returncode
                if proc.stderr.strip():
                    print(proc.stderr.strip())
        else:
            print(
                "opening {}/{} file(s) with `open -a {}`".format(
                    len(chunk), len(paths), app
                )
            )
            proc = subprocess.run(["open", "-a", app, *chunk])
            if proc.returncode != 0:
                status = proc.returncode
                print(
                    "warning: `open -a {}` returned {}. The paths are:".format(
                        app, proc.returncode
                    )
                )
                for path in chunk:
                    print("  " + path)
        if index < len(chunks):
            if not wait_for_enter(
                "Batch {}/{} opened. Close some SolidCraft tabs, then press "
                "Enter for the next batch (Ctrl-C to stop)... ".format(
                    index, len(chunks)
                )
            ):
                print(
                    "note: no controlling terminal; continuing without waiting."
                )
    return status


def main():
    mode_list = False
    mode_commands = False
    select_all = False
    no_open = False
    use_helper = False
    reuse = False
    detail = "detailed"
    detail_explicit = False
    threads = None
    app = os.environ.get("SOLIDCRAFT_APP", "SolidCraft")
    out_dir = DEFAULT_OUT
    batch = 0
    index_tokens = []

    i = 0
    while i < len(USER):
        arg = USER[i]
        if arg in ("-h", "--help"):
            print(USAGE)
            return 0
        if arg == "--list":
            mode_list = True
        elif arg == "--commands":
            mode_commands = True
        elif arg == "--all":
            select_all = True
        elif arg == "--no-open":
            no_open = True
        elif arg == "--helper":
            use_helper = True
        elif arg == "--reuse":
            reuse = True
        elif arg in ("--detail", "-d"):
            i += 1
            if i >= len(USER):
                fail("--detail needs a value")
            detail = normalize_detail(USER[i])
            detail_explicit = True
        elif arg.startswith("--detail="):
            detail = normalize_detail(arg.split("=", 1)[1])
            detail_explicit = True
        elif arg in ("--threads", "-t"):
            i += 1
            if i >= len(USER):
                fail("--threads needs a value")
            threads = normalize_threads(USER[i])
        elif arg.startswith("--threads="):
            threads = normalize_threads(arg.split("=", 1)[1])
        elif arg == "--app":
            i += 1
            if i >= len(USER):
                fail("--app needs a value")
            app = USER[i]
        elif arg.startswith("--app="):
            app = arg.split("=", 1)[1]
        elif arg == "--out":
            i += 1
            if i >= len(USER):
                fail("--out needs a value")
            out_dir = USER[i]
        elif arg.startswith("--out="):
            out_dir = arg.split("=", 1)[1]
        elif arg == "--batch":
            i += 1
            if i >= len(USER):
                fail("--batch needs a value")
            try:
                batch = int(USER[i])
            except ValueError:
                fail("--batch needs a positive integer")
        elif arg.startswith("--batch="):
            try:
                batch = int(arg.split("=", 1)[1])
            except ValueError:
                fail("--batch needs a positive integer")
        elif arg.startswith("-"):
            fail("unknown option {!r}".format(arg))
        else:
            index_tokens.append(arg)
        i += 1

    if batch < 0:
        fail("--batch must be positive")

    rows = build_rows(detail, detail_explicit)
    count = len(rows)
    supported = sum(1 for row in rows if row["tool"])

    if mode_list:
        width = max(len(row["name"]) for row in rows)
        print("{:<4} {:<{w}}  {}".format("idx", "golden file", "parametric equivalent", w=width))
        print("{:<4} {:<{w}}  {}".format("---", "-" * width, "-" * 30, w=width))
        for row in rows:
            print("{:03d}  {:<{w}}  {}".format(row["index"], row["name"], row["label"], w=width))
        print()
        print(
            "{} golden STEP file(s); {} have a parametric equivalent.".format(
                count, supported
            )
        )
        print(
            "Example: ./scripts/compare-golden.sh 1 3   "
            "(or --all, --detail simplified, --no-open)"
        )
        return 0

    if mode_commands:
        if select_all or not index_tokens:
            selected = list(range(1, count + 1))
        else:
            selected = parse_selection(index_tokens, count)
        rows_by_index = {row["index"]: row for row in rows}
        for index in selected:
            row = rows_by_index[index]
            if not row["tool"]:
                print("# no parametric equivalent: " + row["name"])
                continue
            out_path = os.path.join(out_dir, "parametric-" + row["name"])
            print(shlex.join(generation_command(row, threads, out_path)))
        return 0

    if select_all:
        selected = list(range(1, count + 1))
    elif index_tokens:
        selected = parse_selection(index_tokens, count)
    else:
        print(USAGE)
        return 0

    rows_by_index = {row["index"]: row for row in rows}
    chosen = [rows_by_index[index] for index in selected]
    unsupported = [row for row in chosen if not row["tool"]]
    chosen_supported = [row for row in chosen if row["tool"]]

    print(
        "selected {} golden file(s); {} with a parametric equivalent, "
        "{} without.".format(len(chosen), len(chosen_supported), len(unsupported))
    )
    if unsupported and not select_all:
        for row in unsupported:
            print("  skip {:03d}: {} — no parametric equivalent".format(row["index"], row["name"]))
    elif unsupported:
        print(
            "  ({} selected goldens have no parametric equivalent; use --list "
            "to see them)".format(len(unsupported))
        )

    if chosen_supported and not shutil.which("moon"):
        fail(
            "`moon` is not on PATH; run this from a shell where the MoonBit "
            "toolchain is available",
            hint=False,
        )

    os.makedirs(out_dir, exist_ok=True)
    pairs = []
    failures = 0
    for row in chosen_supported:
        out_path = os.path.join(out_dir, "parametric-" + row["name"])
        if reuse and os.path.exists(out_path):
            print("[{:03d}] reuse {}".format(row["index"], os.path.relpath(out_path, ROOT)))
            pairs.append((row, out_path))
            continue
        if os.path.exists(out_path):
            try:
                os.remove(out_path)
            except OSError as exc:
                print("  warning: cannot remove {} ({})".format(out_path, exc))
        cmd = generation_command(row, threads, out_path)
        print("[{:03d}] generating {}".format(row["index"], row["label"]))
        if row.get("note"):
            print("  note: " + row["note"])
        proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
        if proc.returncode != 0 or not os.path.exists(out_path):
            failures += 1
            detail_text = (proc.stderr or proc.stdout or "").strip()
            print("  FAILED: " + " ".join(cmd))
            if detail_text:
                for line in detail_text.splitlines()[-4:]:
                    print("  " + line)
            continue
        pairs.append((row, out_path))

    # Explicitly selected goldens without an equivalent can still be opened on
    # their own; --all stays focused on the pairs that can actually be generated.
    extra_goldens = [] if select_all else [row["path"] for row in unsupported]
    print()
    print(
        "generated {} pair(s) in {} ({} failure(s)).".format(
            len(pairs), os.path.relpath(out_dir, ROOT), failures
        )
    )
    if not pairs:
        if extra_goldens and not no_open:
            print()
            print(
                "No parametric equivalents in the selection; opening the "
                "golden file(s) only."
            )
            open_paths(extra_goldens, app, batch, use_helper)
            return 0
        if extra_goldens and no_open:
            print()
            print("Golden file(s) with no parametric equivalent:")
            for path in extra_goldens:
                print("  " + path)
            return 0
        return 1

    paths = []
    for row, out_path in pairs:
        paths.append(row["path"])
        paths.append(out_path)
        print("  {:03d}  {}  <->  {}".format(
            row["index"], row["name"], os.path.basename(out_path)
        ))

    if no_open:
        print()
        print("Generated files (open them yourself with `open -a {}`):".format(app))
        for row, out_path in pairs:
            print("  " + row["path"])
            print("  " + out_path)
        if extra_goldens:
            print()
            print("Selected golden file(s) with no parametric equivalent:")
            for path in extra_goldens:
                print("  " + path)
        return 0

    if not use_helper and batch == 0 and len(pairs) * 2 > 32:
        print()
        print(
            "note: SolidCraft caps open designs at 32. {} pairs need {} tabs; "
            "use --batch 8 or select fewer indices if tabs are refused.".format(
                len(pairs), len(pairs) * 2
            )
        )

    status = open_paths(paths, app, batch, use_helper)
    print()
    print("Opened {} golden/parametric pair(s).".format(len(pairs)))
    if extra_goldens:
        print()
        print(
            "Opening {} golden file(s) with no parametric equivalent.".format(
                len(extra_goldens)
            )
        )
        extra_status = open_paths(extra_goldens, app, batch, use_helper)
        if extra_status != 0:
            status = extra_status
    return 0 if status == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
PY
