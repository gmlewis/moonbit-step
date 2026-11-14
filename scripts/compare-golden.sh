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
#   ./scripts/compare-golden.sh 5 --detail simplified
#   ./scripts/compare-golden.sh 5 --headless
#
# Options:
#   --list              list the numbered golden files and their equivalents
#   --all               select every golden that has a parametric equivalent
#   --detail LEVEL      simplified | detailed (default) | full
#   --threads REP       none | helical | cosmetic (fasteners only)
#   --batch N           open N pairs at a time, waiting between batches
#   --reuse             reuse an existing generated file instead of rebuilding
#   --headless          generate only; print the paths (agent/automation mode;
#                       never opens a tab or drives the running SolidCraft)
#   --no-open           alias of --headless, kept for compatibility
#   --no-connectors     do not write connector sidecars or add SolidCraft
#                       joint origins (connectors are shown by default)
#   --no-helper         open with `open -a` instead of the SolidCraft GUI helper
#   --helper            open through the running SolidCraft GUI helper with
#                       --up z (the default when the helper answers)
#   --foreground        bring SolidCraft to the front after opening
#                       (default: true for the owner's visual comparison)
#   --no-foreground     add tabs without raising the SolidCraft window
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
  ./scripts/compare-golden.sh 5 --headless
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
  --headless        generate only; print the paths (agent/automation mode;
                    never opens a tab or drives the running SolidCraft)
  --no-open         alias of --headless, kept for compatibility
  --commands        print the exact `moon run` command for each selection
  --inspect         also run tools/inspect on each generated counterpart
  --no-connectors   do not write connector sidecars or add SolidCraft joint
                    origins (connectors are shown by default)
  --no-helper       open with `open -a` instead of the running SolidCraft GUI
  --helper          open through the running SolidCraft GUI helper (default
                    when the helper is installed and its control port answers)
  --foreground      bring the SolidCraft window to the front after opening
                    (default: true)
  --no-foreground   add tabs without raising the SolidCraft window
  --app NAME        macOS app name for `open -a` (default SolidCraft)
  --out DIR         output directory (default target/golden-compare)

Connectors: by default each parametric part is generated with a
`<file>.connectors.tsv` sidecar and, when the running SolidCraft GUI is
reachable through the helper, a named SolidCraft `joint.origin` is added at
every connector frame. The STEP file itself stays connector-free. The window is
brought to the front by default; `--no-foreground` leaves it behind other
windows. Agents and background automation must use `--headless`.
"""


def fail(message, code=2, hint=True):
    print("error: " + message, file=sys.stderr)
    if hint:
        print("Run with --help for usage.", file=sys.stderr)
    sys.exit(code)


def failure_diagnostic_lines(text, limit=10):
    """Keep the lines that carry the actual failure, not the panic tail.

    MoonBit aborts print their message first and then a "PanicError" stack
    trace, while compiler diagnostics start with "Error:". Stack frames are
    noise here, so return the leading message block and drop the trace.
    """
    lines = [line.rstrip() for line in (text or "").splitlines() if line.strip()]
    if not lines:
        return []
    for i, line in enumerate(lines):
        if line.strip().startswith("PanicError"):
            head = lines[:i]
            return (head or [lines[0]])[:limit]
    for i, line in enumerate(lines):
        low = line.strip().lower()
        if low.startswith("error:") or low.startswith("error ["):
            return lines[i:i + limit]
    return lines[:limit]


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
    m = re.match(r"^thin_jam_nut_m(\d+(?:p\d+)?)_simple\.step$", name)
    if m:
        return fastener("iso4035", m.group(1), None, detail)
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
        # The references are one closed solid (shank + head); use the unified
        # representation.
        tool, gen_args = fastener("iso4017", m.group(1), m.group(2), detail)
        return (tool, gen_args + ["--unified"])
    m = re.match(
        r"^iso4017_hex_head_cap_screw_m(\d+(?:p\d+)?)x(\d+)\.step$", name
    )
    if m:
        # This reference is the single-solid representation: shank, under-head
        # washer face and hexagon head in one shell (see --unified).
        tool, gen_args = fastener("iso4017", m.group(1), m.group(2), detail)
        return (tool, gen_args + ["--unified"])
    m = re.match(r"^iso_2338_dowel_pin_d(\d+)_l(\d+)\.step$", name)
    if m:
        return fastener(
            "iso2338", str(int(m.group(1))), str(int(m.group(2))), detail
        )
    m = re.match(r"^iso7090_m(\d+(?:[p_]\d+)?)_flat_washer\.step$", name)
    if m:
        return fastener("iso7090", m.group(1).replace("_", "p"), None, detail)
    m = re.match(
        r"^iso7091(?:_class_c_|din126_class_c_)m(\d+(?:[p_]\d+)?)(?:flatwasher|_flat_washer)?\.step$",
        name,
    )
    if m:
        return fastener("iso7091", m.group(1).replace("_", "p"), None, detail)
    m = re.match(
        r"^iso7092(?:_?din433_)?m(\d+(?:[p_]\d+)?)(?:flatwasher|_flat_washer)?\.step$",
        name,
    )
    if m:
        return fastener("iso7092", m.group(1).replace("_", "p"), None, detail)
    m = re.match(
        r"^iso7093(?:_?din9021_)?m(\d+(?:[p_]\d+)?)(?:flatwasher|_flat_washer)?\.step$",
        name,
    )
    if m:
        return fastener("iso7093", m.group(1).replace("_", "p"), None, detail)
    m = re.match(r"^din125_flat_washer_m(\d+(?:p\d+)?)(?:_simple)?\.step$", name)
    if m:
        return fastener("din125", m.group(1), None, detail)
    m = re.match(r"^din127_spring_washer_m(\d+(?:p\d+)?)(?:_simple)?\.step$", name)
    if m:
        return fastener("din127", m.group(1), None, detail)
    m = re.match(r"^din440_large_washer_m(\d+(?:p\d+)?)(?:_simple)?\.step$", name)
    if m:
        return fastener("din440", m.group(1), None, detail)
    m = re.match(r"^din7349_m(\d+(?:p\d+)?)flatwasher\.step$", name)
    if m:
        return fastener("din7349", m.group(1), None, detail)
    m = re.match(r"^din913_set_screw_m(\d+(?:p\d+)?)x(\d+)\.step$", name)
    if m:
        return fastener("din913", m.group(1), m.group(2), detail)
    m = re.match(r"^din93_m(\d+(?:p\d+)?)tabwasher\.step$", name)
    if m:
        return fastener("din93", m.group(1), None, detail)
    m = re.match(r"^iso_metric_square_nut_m(\d+(?:p\d+)?)_simple\.step$", name)
    if m:
        return fastener("din557", m.group(1), None, detail)
    m = re.match(r"^set_screw_m(\d+(?:p\d+)?)_l(\d+)_cup_point_simple\.step$", name)
    if m:
        tool, gen_args = fastener("din916", m.group(1), m.group(2), detail)
        return (tool, gen_args + ["--orient-to-reference"])
    m = re.match(r"^profile_2020_b_slot6_a_l(\d+)\.step$", name)
    if m:
        return (
            "components/examples/profile_extrusion",
            ["--profile", "2020-b-slot6-a", "--length", str(int(m.group(1))),
             "--detail", detail, "--orient-to-reference"],
        )
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
                "--envelope",
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
    if (
        tool.endswith("/fasteners")
        and arg_value(args, "--standard") == "iso4762"
        and not name.endswith("_simple.step")
    ):
        # The canonical ISO 4762 references come from two sources: the simple
        # representation (flat hex socket, rounded head-top edge torus,
        # pitch-sized tip break, under-head relief) and the detailed one
        # (conical socket rim and drill point). A torus in the golden identifies
        # the simple source unambiguously.
        path = os.path.join(GOLDEN_DIR, name)
        try:
            with open(path, errors="replace") as handle:
                text = handle.read()
        except OSError:
            text = ""
        if "TOROIDAL_SURFACE" in text and "--simple-reference" not in args:
            args.append("--simple-reference")
    if tool.endswith("/fasteners") and arg_value(args, "--standard") == "din557":
        note = (
            "reference cuts each vertical corner with a 0.0014 mm coaxial arc "
            "(4 extra cylindrical faces); the parametric model keeps sharp "
            "standard corners"
        )
    if tool.endswith("/fasteners") and arg_value(args, "--standard") == "iso4035":
        note = (
            "reference rounds each vertical corner by about 0.001 mm "
            "(6 extra cylindrical faces); the parametric model keeps sharp "
            "standard corners"
        )
    if tool.endswith("/fasteners") and name.endswith("_simple.step"):
        # The catalogue's "_simple" models are the unthreaded/sharp-feature
        # representation. Whether that is the library's Simplified or Detailed
        # level is family-dependent: the button, countersunk, hex-head,
        # socket-head, rod and plain-washer references match Simplified, while
        # the ISO 4032 nut references still carry the conical washer-face cones
        # that only Detailed emits, so nuts stay Detailed.
        simple_family = (
            arg_value(args, "--standard")
            in ("iso7380", "iso10642", "iso4762", "din976",
                "din125", "din127", "din440", "din7349")
            or name.startswith("hex_head_bolt_")
        )
        if simple_family and not detail_explicit:
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
    if tool.endswith("/profile_extrusion"):
        return "PROFILE {} x {} [{}]".format(
            arg_value(args, "--profile") or "?",
            arg_value(args, "--length") or "?",
            arg_value(args, "--detail") or "detailed",
        )
    if tool.endswith("/stepper_motor"):
        return "{} stepper body {} mm".format(
            arg_value(args, "--frame") or "NEMA17",
            arg_value(args, "--bodyLength") or "40",
        )
    if tool.endswith("/linear_bearing"):
        text = "linear bearing {}".format(arg_value(args, "--bearing") or "LM8UU")
        if "--flanged" in args:
            text += " flanged"
        return text
    if tool.endswith("/extrusion_hardware"):
        part = arg_value(args, "--part") or "tnut"
        if part == "heat-set":
            return "heat-set insert M3 {}".format(
                arg_value(args, "--length") or "short"
            )
        return "extrusion T-nut {} slot {}".format(
            arg_value(args, "--thread") or "M3",
            arg_value(args, "--slot") or "5",
        )
    if tool.endswith("/stock_primitive"):
        part = arg_value(args, "--part") or "angle"
        if part == "plate":
            return "plate {}x{}x{}".format(
                arg_value(args, "--width") or "?",
                arg_value(args, "--height") or "?",
                arg_value(args, "--plateThickness") or "?",
            )
        return "angle {}x{}x{} L={}".format(
            arg_value(args, "--legA") or "?",
            arg_value(args, "--legB") or "?",
            arg_value(args, "--thickness") or "?",
            arg_value(args, "--length") or "?",
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
        if name.endswith("_simple.step"):
            # The bracket in `describe` is the parametric generation detail, not
            # the golden's catalogue class; mark the simple references so the
            # two are not confused.
            label += " (simple golden)"
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
    return ["moon", "run", tool, "--"] + args


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
                reason = (probe.stderr or probe.stdout).strip()
                print(
                    "note: no usable SolidCraft GUI control port"
                    + (": " + reason if reason else "")
                    + "; falling back to `open -a " + app + "`"
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


def activate_app(app):
    """Bring the SolidCraft window to the front after helper-driven opens.

    `sc_mcp.py open` adds tabs through the app's control port but does not
    activate the app, so the old `open -a` foreground behavior would be lost.
    """
    if shutil.which("open"):
        proc = subprocess.run(
            ["open", "-a", app], capture_output=True, text=True
        )
        if proc.returncode == 0:
            return True
    if shutil.which("osascript"):
        proc = subprocess.run(
            [
                "osascript",
                "-e",
                'tell application "{}" to activate'.format(app),
            ],
            capture_output=True,
            text=True,
        )
        return proc.returncode == 0
    return False


def helper_path():
    return os.path.expanduser(
        "~/.claude/skills/solidcraft-app/scripts/sc_mcp.py"
    )


# Why `helper_available` last said no; shown with the fallback note.
_HELPER_ERROR = ""


def helper_available():
    """Return the helper path when the running GUI control port answers.

    The helper reports a port only after verifying it against the app's token
    file, so a port another program holds (or an app that failed to bind its
    control port) counts as unavailable and the caller falls back to `open -a`.
    """
    global _HELPER_ERROR
    _HELPER_ERROR = ""
    helper = helper_path()
    if not os.path.exists(helper):
        _HELPER_ERROR = "helper not found at " + helper
        return None
    probe = subprocess.run(
        [sys.executable, "-I", helper, "port"],
        capture_output=True,
        text=True,
    )
    if probe.returncode != 0:
        _HELPER_ERROR = (probe.stderr or probe.stdout).strip()
        return None
    return helper


def helper_open_one(helper, path):
    """Open one file as a GUI tab and return (component_name, error)."""
    proc = subprocess.run(
        [sys.executable, "-I", helper, "open", path, "--up", "z"],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        return None, (proc.stderr or proc.stdout).strip()
    out = proc.stdout.strip()
    if not out:
        return None, "the helper returned no component"
    try:
        data = json.loads(out.splitlines()[-1])
    except (ValueError, IndexError):
        return None, out
    return data.get("component"), None


def add_connector_origins(helper, step_path, component):
    """Add a named SolidCraft joint origin for every sidecar connector row."""
    sidecar = step_path + ".connectors.tsv"
    if not os.path.exists(sidecar):
        print(
            "  note: no connector sidecar for {}; rebuild without --reuse "
            "to add joint origins".format(os.path.basename(step_path))
        )
        return 0
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
            name = cols[0]
            try:
                origin = [float(cols[1]), float(cols[2]), float(cols[3])]
                axis = [float(cols[4]), float(cols[5]), float(cols[6])]
                secondary = [float(cols[7]), float(cols[8]), float(cols[9])]
            except ValueError:
                continue
            payload = json.dumps(
                {
                    "name": "connector/" + name,
                    "occurrence": component,
                    "point": origin,
                    "z": axis,
                    "x": secondary,
                }
            )
            proc = subprocess.run(
                [sys.executable, "-I", helper, "exec", "joint.origin", payload],
                capture_output=True,
                text=True,
            )
            if proc.returncode == 0:
                added += 1
            else:
                failed += 1
                detail = (proc.stderr or proc.stdout).strip().splitlines()
                if detail:
                    print(
                        "  note: joint origin {} failed: {}".format(
                            name, detail[-1][:200]
                        )
                    )
    if added:
        print(
            "  connectors: {} joint origin(s){}".format(
                added, "" if not failed else " ({} failed)".format(failed)
            )
        )
    return added


def open_pairs_with_connectors(pairs, batch):
    """Open each pair parametric-first, add joint origins, then open the golden.

    The parametric tab must be active while its origins are added, so the pair
    cannot be opened as one flat list.
    """
    helper = helper_available()
    if helper is None:
        print(
            "note: the SolidCraft GUI helper is unavailable"
            + (": " + _HELPER_ERROR if _HELPER_ERROR else "")
            + "; connectors are not shown. Start SolidCraft (with its control "
            "port) or use --no-connectors."
        )
        return None
    if batch and batch > 0:
        chunks = [pairs[i:i + batch] for i in range(0, len(pairs), batch)]
    else:
        chunks = [pairs]
    status = 0
    for index, chunk in enumerate(chunks, 1):
        for row, out_path in chunk:
            print(
                "[{:03d}] opening pair with connectors".format(row["index"])
            )
            # Open the golden first, then the parametric part, so the
            # parametric tab is active when its joint origins are added and
            # stays in front for the visual comparison.
            golden_component, golden_error = helper_open_one(helper, row["path"])
            if golden_component is None:
                print("  note: golden open failed: " + (golden_error or "unknown"))
                status = 1
            component, error = helper_open_one(helper, out_path)
            if component is None:
                print("  note: parametric open failed: " + (error or "unknown"))
                status = 1
                continue
            add_connector_origins(helper, out_path, component)
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


def inspect_command(args):
    """Return a tools/inspect command for a generated counterpart, if the
    example's flags map onto the analysis tool's family flags."""
    filtered = []
    i = 0
    while i < len(args):
        a = args[i]
        if a in ("-o", "--out"):
            i += 2
            continue
        if a.startswith("-o=") or a.startswith("--out="):
            i += 1
            continue
        filtered.append(a)
        i += 1
    return ["moon", "run", "tools/inspect", "--"] + filtered + ["--json"]


def main():
    mode_list = False
    mode_commands = False
    select_all = False
    no_open = False
    use_helper = True
    connectors = True
    foreground = True
    reuse = False
    inspect = False
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
        elif arg == "--no-open" or arg == "--headless":
            # Generate only. `--no-open` is a compatibility alias for
            # `--headless`; both never open a tab or drive the owner's app.
            no_open = True
            use_helper = False
            foreground = False
        elif arg == "--helper":
            use_helper = True
        elif arg == "--no-helper":
            use_helper = False
        elif arg == "--connectors":
            connectors = True
        elif arg == "--no-connectors":
            connectors = False
        elif arg == "--foreground":
            foreground = True
        elif arg == "--no-foreground":
            foreground = False
        elif arg == "--reuse":
            reuse = True
        elif arg == "--inspect":
            inspect = True
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
        print("{:<4} {:<{w}}  {}".format("idx", "golden file", "parametric counterpart [generation detail]", w=width))
        print("{:<4} {:<{w}}  {}".format("---", "-" * width, "-" * 44, w=width))
        for row in rows:
            print("{:03d}  {:<{w}}  {}".format(row["index"], row["name"], row["label"], w=width))
        print()
        print(
            "{} golden STEP file(s); {} have a parametric equivalent.".format(
                count, supported
            )
        )
        print(
            "The bracketed value is the parametric generation detail, not the "
            "golden's class. `(simple golden)` marks the catalogue's simple "
            "models; the script uses Simplified where that reproduces their "
            "feature set and Detailed where the golden still has features our "
            "Simplified level omits (e.g. the nut washer-face cones)."
        )
        print(
            "Example: ./scripts/compare-golden.sh 1 3   "
            "(or --all, --detail simplified, --headless)"
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
    generation_env = dict(os.environ)
    if connectors:
        generation_env["STEP_CONNECTOR_SIDECAR"] = "1"
    pairs = []
    failures = 0
    for row in chosen_supported:
        out_path = os.path.join(out_dir, "parametric-" + row["name"])
        if reuse and os.path.exists(out_path):
            print("[{:03d}] reuse {}".format(row["index"], os.path.relpath(out_path, ROOT)))
            if connectors and not os.path.exists(out_path + ".connectors.tsv"):
                print(
                    "  note: no connector sidecar; rebuild without --reuse "
                    "to add joint origins"
                )
            pairs.append((row, out_path))
            continue
        if os.path.exists(out_path):
            try:
                os.remove(out_path)
            except OSError as exc:
                print("  warning: cannot remove {} ({})".format(out_path, exc))
        sidecar_path = out_path + ".connectors.tsv"
        if os.path.exists(sidecar_path):
            try:
                os.remove(sidecar_path)
            except OSError as exc:
                print(
                    "  warning: cannot remove {} ({})".format(
                        sidecar_path, exc
                    )
                )
        cmd = generation_command(row, threads, out_path)
        print("[{:03d}] generating {}".format(row["index"], row["label"]))
        if row.get("note"):
            print("  note: " + row["note"])
        proc = subprocess.run(
            cmd, cwd=ROOT, capture_output=True, text=True, env=generation_env
        )
        if proc.returncode != 0 or not os.path.exists(out_path):
            failures += 1
            # Keep both streams: the real diagnostic may be written to either
            # one, and the panic stack must not hide it.
            detail_text = ((proc.stderr or "") + "\n" + (proc.stdout or "")).strip()
            print("  FAILED: " + " ".join(cmd))
            for line in failure_diagnostic_lines(detail_text):
                print("  " + line)
            continue
        pairs.append((row, out_path))
        if inspect:
            mapped = (
                row["tool"].endswith("/fasteners")
                or row["tool"].endswith("/bearing")
                or row["tool"].endswith("/gear_pair")
            )
            if not mapped:
                print("  inspect: unavailable (no analysis-tool family mapping)")
            else:
                icmd = inspect_command(row["args"])
                iproc = subprocess.run(icmd, cwd=ROOT, capture_output=True, text=True)
                if iproc.returncode == 0 and iproc.stdout.strip():
                    summary = iproc.stdout.strip().splitlines()[-1]
                    print("  inspect: " + summary)
                else:
                    detail_text = (
                        (iproc.stderr or "") + "\n" + (iproc.stdout or "")
                    ).strip()
                    diag = failure_diagnostic_lines(detail_text)
                    print(
                        "  inspect: unavailable ("
                        + (diag[0] if diag else "no output")
                        + ")"
                    )

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

    if batch == 0 and len(pairs) * 2 > 32:
        print()
        print(
            "note: SolidCraft caps open designs at 32. {} pairs need {} tabs; "
            "use --batch 8 or select fewer indices if tabs are refused.".format(
                len(pairs), len(pairs) * 2
            )
        )

    if connectors and use_helper:
        status = open_pairs_with_connectors(pairs, batch)
        if status is None:
            status = open_paths(paths, app, batch, use_helper)
    else:
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
    # The helper adds tabs without activating the app. The owner's default is
    # to raise the window after opening; --no-foreground keeps it behind other
    # windows, and --headless never opens a tab at all.
    if foreground:
        activate_app(app)
    return 0 if status == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
PY
