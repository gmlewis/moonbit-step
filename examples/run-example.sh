#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
run-example.sh — run an example and optionally export a mesh or preview image.

Usage:
  ./examples/run-example.sh <example> [options...]
  ./examples/run-example.sh <number>  [options...]     e.g. 12
  ./examples/run-example.sh components/<name> [options...]  e.g. components/vslot
  ./examples/run-example.sh <component-name> [options...]   e.g. vslot

Wrapper options:
  -h, --help             Show this help and exit.
  -l, --list             List the top-level and component examples and exit.
  --no-connectors        Do not write connector sidecars or add SolidCraft
                        joint origins (named mate connectors are shown by
                        default for every component example).
  -stl[=<path>]         Also write a binary STL (default: <step>.stl).
  --png[=<path>]        Also render a four-view PNG preview (default: <step>.png).
  -o, --out <path>      Write the STEP file to <path> (default: stdout).
  --eval[=<path>]       Evaluate booleans with OCCT and write a real, trimmed
                        STEP file (default: <example>.step). Requires
                        occt-draw or DRAWEXE; overrides nominal STEP output.
  --view[=<path>]       Write the STEP to /tmp/<example>.step (or <path>) and
                        open it in SolidCraft. With -o, opens that path instead.
                        Cannot be combined with --blend, --bpy, --gltf, or
                        --nostep, which suppress STEP output.
  --headless            Generate only; never open SolidCraft. Writes to
                        /tmp/<example>.step (or the -o path) and prints it.
                        Agents should always pass this instead of --view.
  --                     Optional separator (ignored).

Output formats for quick previewing:
  STEP (.step, .stp)     Default. Exact B-Rep; opens in CAD viewers and slicers.
  STL  (.stl)            Triangulated mesh for slicers/printers. Tessellated by
                         OCCT; set STL_DEFLECTION=<mm> (default 0.05).
  PNG  (.png)            Four views (iso/top/front/side) composited so you can
                         look without a CAD viewer. Requires OCCT DRAWEXE,
                         macOS 'sips', and Inkscape (falls back to one view
                         without Inkscape).
  Blender (.blend)       Editable Blender scene with real booleans. Pass
                         --blend <path> to the example (when supported).
  Python (.py)           Blender Python script instead of a .blend. Pass
                         --bpy <path> to the example (when supported).
  glTF (.gltf)           Preview mesh for web/three.js glTF viewers, written by
                         the example itself. Pass --gltf <path> to the example
                         (when supported). Coordinates are Z-up.

Examples:
  ./examples/run-example.sh --list
  ./examples/run-example.sh 12 -o coil.step
  ./examples/run-example.sh 12 -o coil.step -stl
  ./examples/run-example.sh 12 -o coil.step --png=preview.png
  ./examples/run-example.sh 12 --numPairs 6 -o coil.step
  ./examples/run-example.sh --view 12          # write /tmp/12-*.step and open it
  ./examples/run-example.sh 12 -- --help       # example-specific options
  ./examples/run-example.sh 12 > coil.step     # STEP to stdout
  ./examples/run-example.sh components/vslot --part wheel --view
  ./examples/run-example.sh clamp_shaft_collar --view
  ./examples/run-example.sh --headless bearing   # generate only (agents)
  ./examples/run-example.sh --no-connectors bearing --view

Notes:
  - Options other than the wrapper options above are forwarded to the example.
  - --blend, --bpy, --gltf, and --nostep suppress STEP output, so they cannot
    be combined with -stl or --png.
  - -stl and --png may be used together; both derive from the same STEP file.
  - STL/PNG previews need OCCT ('occt-draw' or 'DRAWEXE') on PATH.
EOF
}

# Resolve the script's real location once. Both the example list and the
# package path below need the repository root.
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# example_description prints the first prose line of an example's main.mbt
# doc block. The first doc line is the title, so skip it.
example_description() {
  local main="$1/main.mbt"
  [[ -f "$main" ]] || return 0
  sed -n -e 's#^/// ##p' -e 's#^///$##p' "$main" |
    sed -e '/^$/d' |
    sed -n '2p' |
    sed -e 's#:$##'
}

# readme_bullet and readme_row read the one-line catalogue descriptions that
# the two README tables keep, which are more useful than a wrapped source doc.
readme_bullet() {
  local name="$1" readme="$2"
  [[ -f "$readme" ]] || return 0
  sed -n "s#^- \[${name}\](.*) - \(.*\)#\1#p" "$readme" | head -n1
}

readme_row() {
  local name="$1" readme="$2"
  [[ -f "$readme" ]] || return 0
  sed -n "s#^| \`${name}\` | \(.*\) |#\1#p" "$readme" | head -n1
}

list_examples() {
  local dir name number rest desc
  echo "Examples (./run-example.sh <number> [options]):"
  for dir in "$SCRIPT_DIR"/[0-9][0-9]-*/; do
    [[ -d "$dir" ]] || continue
    name="$(basename "$dir")"
    number="${name%%-*}"
    rest="${name#*-}"
    desc="$(readme_bullet "$name" "$SCRIPT_DIR/README.md")"
    [[ -n "$desc" ]] || desc="$(example_description "$dir")"
    printf '  %-3s %-30s %s\n' "$number" "$rest" "$desc"
  done
  echo
  echo "Component examples (./run-example.sh components/<name> [options], or just <name>):"
  for dir in "$ROOT_DIR"/components/examples/*/; do
    [[ -d "$dir" ]] || continue
    name="$(basename "$dir")"
    [[ "$name" == "output" ]] && continue
    desc="$(readme_row "$name" "$ROOT_DIR/components/examples/README.md")"
    [[ -n "$desc" ]] || desc="$(example_description "$dir")"
    printf '  %-30s %s\n' "$name" "$desc"
  done
  echo
  echo "Add --view to open the STEP in SolidCraft, -o <path> to write it,"
  echo "or -stl / --png for mesh and image previews. Component examples take"
  echo "their own options; use '<example> -- --help' to see them."
}

if [[ $# -gt 0 ]]; then
  case "$1" in
    -h | --help | help)
      usage
      exit 0
      ;;
    -l | --list)
      list_examples
      exit 0
      ;;
  esac
fi

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 2
fi

# Wrapper options may precede the example (`./run-example.sh --view 2`).
# Collect a leading run of wrapper options, then take the first remaining
# argument as the example and forward the collected options after it.
PREFIX_ARGS=()
while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --view | --view=* | -stl | --stl | -stl=* | --stl=* | -png | --png | -png=* | --png=* | --nostep | --blend | --blend=* | --bpy | --bpy=* | --gltf | --gltf=* | --no-connectors | --connectors | --headless | --no-open)
      PREFIX_ARGS+=("$1")
      shift
      ;;
    -o | --out | -eval | --eval)
      PREFIX_ARGS+=("$1")
      if [[ $# -ge 2 ]]; then
        PREFIX_ARGS+=("$2")
        shift 2
      else
        shift
      fi
      ;;
    -o=* | --out=* | -eval=* | --eval=*)
      PREFIX_ARGS+=("$1")
      shift
      ;;
    *) break ;;
  esac
done
if [[ $# -lt 1 ]]; then
  echo "Error: example name or number is missing." >&2
  usage >&2
  exit 2
fi

EXAMPLE_ARG="$1"
shift

# Users sometimes include an extra "--" out of habit (because `moon run` uses it).
# This wrapper already inserts "--" before forwarded args, so strip one if present.
if [[ $# -gt 0 && "${1:-}" == "--" ]]; then
  shift
fi
if [[ ${#PREFIX_ARGS[@]} -gt 0 ]]; then
  set -- "${PREFIX_ARGS[@]}" "$@"
fi

# Allow users to pass a bare folder name ("12-bifilar-electromagnet") or a path
# ("./12-bifilar-electromagnet", "12-bifilar-electromagnet/", "examples/12-bifilar-electromagnet/").
EXAMPLE_ARG_STRIPPED="${EXAMPLE_ARG%/}"
EXAMPLE_BASENAME="$(basename "$EXAMPLE_ARG_STRIPPED")"

# Resolve the target folder relative to the project root. Accept a top-level
# example by number or folder name, or a component example by path or bare name
# (components/<name>, components/examples/<name>, or <name>).
if [[ "$EXAMPLE_ARG_STRIPPED" == components/examples/* ]]; then
  EXAMPLE_PATH_REL="$EXAMPLE_ARG_STRIPPED"
elif [[ "$EXAMPLE_ARG_STRIPPED" == components/* ]]; then
  EXAMPLE_PATH_REL="components/examples/${EXAMPLE_ARG_STRIPPED#components/}"
elif [[ "$EXAMPLE_ARG_STRIPPED" == *"/"* ]]; then
  EXAMPLE_PATH_REL="$EXAMPLE_ARG_STRIPPED"
else
  # If it's a number, try to find the full folder name (e.g. "1" or "01" -> "12-bifilar-electromagnet").
  if [[ "$EXAMPLE_BASENAME" =~ ^[0-9]+$ ]]; then
    SEARCH_NUM=$(printf "%02d" $((10#$EXAMPLE_BASENAME)) 2>/dev/null || echo "$EXAMPLE_BASENAME")
    MATCHES=("$ROOT_DIR"/examples/"$SEARCH_NUM"-*)
    if [[ -d "${MATCHES[0]}" ]]; then
      EXAMPLE_PATH_REL="examples/$(basename "${MATCHES[0]}")"
    else
      EXAMPLE_PATH_REL="examples/$EXAMPLE_BASENAME"
    fi
  else
    EXAMPLE_PATH_REL="examples/$EXAMPLE_BASENAME"
  fi
fi

if [[ ! -d "$ROOT_DIR/$EXAMPLE_PATH_REL" ]]; then
  # A bare component-example name falls back to components/examples/<name>.
  if [[ -d "$ROOT_DIR/components/examples/$EXAMPLE_BASENAME" ]]; then
    EXAMPLE_PATH_REL="components/examples/$EXAMPLE_BASENAME"
  else
    echo "Error: example folder not found: $EXAMPLE_ARG" >&2
    echo "Looked in: $ROOT_DIR/$EXAMPLE_PATH_REL" >&2
    echo "Run ./run-example.sh --list to see the available examples." >&2
    exit 1
  fi
fi

# The resolved folder name (e.g. "12-bifilar-electromagnet"), used for default file names.
EXAMPLE_NAME="$(basename "$EXAMPLE_PATH_REL")"

# Strip a leading "./" so a user-provided path and a derived path compare equal.
normalize_path() {
  local p="$1"
  while [[ "$p" == ./* ]]; do p="${p#./}"; done
  printf '%s' "$p"
}

# Derive "<step basename>.<ext>" next to the STEP output, or fall back to the
# example name in the current directory.
sibling_output() {
  local ext="$1"
  if [[ -n "$STEP_OUT" ]]; then
    local dir base
    dir="$(dirname "$STEP_OUT")"
    base="$(basename "$STEP_OUT")"
    case "$base" in
      *.*) base="${base%.*}" ;;
    esac
    printf '%s/%s.%s' "$dir" "$base" "$ext"
  else
    printf '%s.%s' "$EXAMPLE_NAME" "$ext"
  fi
}

# --- Forwarded arguments ----------------------------------------------------
# `-stl`, `--png`, and `-h`/`--help` are handled by this wrapper; every other
# argument is forwarded to the example. `-o`/`--out` is picked out only to
# locate the generated STEP file.
STL_REQUESTED=0
STL_OUT_ARG=""
STL_OUT=""
PNG_REQUESTED=0
PNG_OUT_ARG=""
PNG_OUT=""
STEP_OUT=""
EVAL_OUT=""
VIEW_REQUESTED=0
VIEW_PATH_ARG=""
VIEW_STEP=""
HEADLESS_REQUESTED=0
CONNECTORS_REQUESTED=1
NO_STEP_OUTPUT=0
FORWARD_ARGS=()
ARGS=("$@")
i=0
while (( i < ${#ARGS[@]} )); do
  arg="${ARGS[$i]}"
  case "$arg" in
    -stl | --stl)
      STL_REQUESTED=1
      ;;
    -stl=* | --stl=*)
      STL_REQUESTED=1
      STL_OUT_ARG="${arg#*=}"
      ;;
    -png | --png)
      PNG_REQUESTED=1
      ;;
    -png=* | --png=*)
      PNG_REQUESTED=1
      PNG_OUT_ARG="${arg#*=}"
      ;;
    -o | --out)
      FORWARD_ARGS+=("$arg")
      if (( i + 1 < ${#ARGS[@]} )); then
        STEP_OUT="${ARGS[$((i + 1))]}"
        FORWARD_ARGS+=("$STEP_OUT")
        i=$((i + 1))
      fi
      ;;
    -o=* | --out=*)
      STEP_OUT="${arg#*=}"
      FORWARD_ARGS+=("$arg")
      ;;
    -eval | --eval)
      FORWARD_ARGS+=("$arg")
      if (( i + 1 < ${#ARGS[@]} )); then
        EVAL_OUT="${ARGS[$((i + 1))]}"
        FORWARD_ARGS+=("$EVAL_OUT")
        i=$((i + 1))
      fi
      ;;
    -eval=* | --eval=*)
      EVAL_OUT="${arg#*=}"
      FORWARD_ARGS+=("$arg")
      ;;
    --view)
      VIEW_REQUESTED=1
      ;;
    --view=*)
      VIEW_REQUESTED=1
      VIEW_PATH_ARG="${arg#*=}"
      ;;
    --no-connectors)
      CONNECTORS_REQUESTED=0
      ;;
    --connectors)
      CONNECTORS_REQUESTED=1
      ;;
    --headless | --no-open)
      HEADLESS_REQUESTED=1
      ;;
    --blend | --blend=* | --bpy | --bpy=* | --gltf | --gltf=* | --nostep)
      # These options make the example skip STEP output entirely.
      NO_STEP_OUTPUT=1
      FORWARD_ARGS+=("$arg")
      ;;
    *)
      FORWARD_ARGS+=("$arg")
      ;;
  esac
  i=$((i + 1))
done

# An evaluated export replaces the nominal STEP file, so derive previews from it.
if [[ -n "$EVAL_OUT" ]]; then
  STEP_OUT="$EVAL_OUT"
fi

# --- View in SolidCraft -----------------------------------------------------
if (( VIEW_REQUESTED )); then
  if (( NO_STEP_OUTPUT )); then
    echo "Error: --view cannot be combined with --blend, --bpy, --gltf, or --nostep" >&2
    echo "       because those options suppress the STEP output." >&2
    exit 1
  fi
  if [[ -n "$VIEW_PATH_ARG" ]] && [[ -n "$STEP_OUT" ]]; then
    echo "Error: use either --view=<path> or -o <path>, not both." >&2
    exit 1
  fi
  if [[ -n "$VIEW_PATH_ARG" ]]; then
    VIEW_STEP="$VIEW_PATH_ARG"
    STEP_OUT="$VIEW_STEP"
    FORWARD_ARGS+=(-o "$VIEW_STEP")
  elif [[ -n "$STEP_OUT" ]]; then
    VIEW_STEP="$STEP_OUT"
  else
    VIEW_STEP="/tmp/$EXAMPLE_NAME.step"
    STEP_OUT="$VIEW_STEP"
    FORWARD_ARGS+=(-o "$VIEW_STEP")
  fi
  if [[ -z "$VIEW_STEP" || ! -d "$(dirname "$VIEW_STEP")" ]]; then
    echo "Error: view output directory does not exist: $(dirname "$VIEW_STEP")" >&2
    exit 1
  fi
fi

# --- Headless output --------------------------------------------------------
# Agents pass --headless so the run never opens the owner's SolidCraft window.
# Without -o the STEP still goes to a predictable /tmp path that is printed.
if (( HEADLESS_REQUESTED )) && (( ! VIEW_REQUESTED )) && [[ -z "$STEP_OUT" ]]; then
  if (( NO_STEP_OUTPUT )); then
    echo "Error: --headless cannot be combined with --blend, --bpy, --gltf, or --nostep" >&2
    echo "       because those options suppress the STEP output." >&2
    exit 1
  fi
  STEP_OUT="/tmp/$EXAMPLE_NAME.step"
  FORWARD_ARGS+=(-o "$STEP_OUT")
fi

# --- Checked derived outputs ------------------------------------------------
if (( STL_REQUESTED || PNG_REQUESTED )); then
  if (( NO_STEP_OUTPUT )); then
    echo "Error: -stl and --png cannot be combined with --blend, --bpy, --gltf, or --nostep" >&2
    echo "       because those options suppress the STEP output." >&2
    exit 1
  fi

  if (( STL_REQUESTED )); then
    if [[ -n "$STL_OUT_ARG" ]]; then
      STL_OUT="$STL_OUT_ARG"
    else
      STL_OUT="$(sibling_output stl)"
    fi
  fi
  if (( PNG_REQUESTED )); then
    if [[ -n "$PNG_OUT_ARG" ]]; then
      PNG_OUT="$PNG_OUT_ARG"
    else
      PNG_OUT="$(sibling_output png)"
    fi
  fi

  step_cmp="$(normalize_path "$STEP_OUT")"
  if [[ -n "$STEP_OUT" ]]; then
    if (( STL_REQUESTED )) && [[ "$(normalize_path "$STL_OUT")" == "$step_cmp" ]]; then
      echo "Error: STL path must differ from the STEP path: $STL_OUT" >&2
      echo "       Pass the STL path explicitly with -stl=<path>." >&2
      exit 1
    fi
    if (( PNG_REQUESTED )) && [[ "$(normalize_path "$PNG_OUT")" == "$step_cmp" ]]; then
      echo "Error: PNG path must differ from the STEP path: $PNG_OUT" >&2
      echo "       Pass the PNG path explicitly with --png=<path>." >&2
      exit 1
    fi
  fi
  if (( STL_REQUESTED )) && (( PNG_REQUESTED )) &&
    [[ "$(normalize_path "$STL_OUT")" == "$(normalize_path "$PNG_OUT")" ]]; then
    echo "Error: STL and PNG outputs must use different paths." >&2
    exit 1
  fi
  if (( STL_REQUESTED )) && [[ ! -d "$(dirname "$STL_OUT")" ]]; then
    echo "Error: STL output directory does not exist: $(dirname "$STL_OUT")" >&2
    exit 1
  fi
  if (( PNG_REQUESTED )) && [[ ! -d "$(dirname "$PNG_OUT")" ]]; then
    echo "Error: PNG output directory does not exist: $(dirname "$PNG_OUT")" >&2
    exit 1
  fi

  # Without -o the example writes STEP to stdout. Capture it in a temporary
  # file so it does not end up in the terminal or mixed with the derived output.
  if [[ -z "$STEP_OUT" ]]; then
    STEP_TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/step-out.XXXXXX")"
    trap 'rm -rf "$STEP_TMP_DIR"' EXIT
    STEP_OUT="$STEP_TMP_DIR/$EXAMPLE_NAME.step"
    FORWARD_ARGS+=(-o "$STEP_OUT")
  fi
fi

# --- STEP -> STL ------------------------------------------------------------
# Draw the script on stdin: on macOS OCCT's DRAWEXE initializes its event loop
# from stdin, and `-c` or a script file can fail before that setup completes.
find_occt() {
  local tool
  tool="$(command -v occt-draw 2>/dev/null || true)"
  if [[ -z "$tool" ]]; then
    tool="$(command -v DRAWEXE 2>/dev/null || true)"
  fi
  printf '%s' "$tool"
}

# open_in_solidcraft opens a STEP file in the SolidCraft desktop app.
open_in_solidcraft() {
  local step_path="$1"
  if [[ ! -s "$step_path" ]]; then
    echo "Error: no STEP was written at $step_path; cannot open it in SolidCraft." >&2
    exit 1
  fi
  if ! command -v open >/dev/null 2>&1; then
    echo "Error: the macOS 'open' command is unavailable." >&2
    exit 1
  fi
  # Show the named mate connectors by default: the opener adds a SolidCraft
  # joint origin for every row of the sidecar, and falls back to `open -a`
  # when the GUI helper is unavailable.
  if (( CONNECTORS_REQUESTED )) &&
    [[ -f "$ROOT_DIR/scripts/open_with_connectors.py" ]] &&
    command -v python3 >/dev/null 2>&1; then
    if python3 "$ROOT_DIR/scripts/open_with_connectors.py" "$step_path"; then
      return 0
    fi
    echo "note: connector opener failed; falling back to 'open -a SolidCraft'." >&2
  fi
  echo "Opening $step_path in SolidCraft" >&2
  if ! open -a SolidCraft "$step_path"; then
    echo "Error: could not open SolidCraft. Is the app installed?" >&2
    echo "The STEP file is at: $step_path" >&2
    exit 1
  fi
}

# Quote a string for a TCL command.
tcl_quote() {
  local s="${1//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '"%s"' "$s"
}

step_to_stl() {
  local step_path="$1"
  local stl_path="$2"
  local deflection="${STL_DEFLECTION:-0.05}"
  local occt log

  occt="$(find_occt)"
  if [[ -z "$occt" ]]; then
    echo "Error: neither occt-draw nor DRAWEXE is on PATH." >&2
    echo "       Install OpenCASCADE to use -stl." >&2
    return 1
  fi

  if ! log="$(
    printf 'pload ALL\ntestreadstep %s a\nincmesh a %s\nwritestl a %s\nexit\n' \
      "$(tcl_quote "$step_path")" "$deflection" "$(tcl_quote "$stl_path")" \
      | "$occt" 2>&1
  )"; then
    echo "Error: OCCT failed while converting $step_path to STL." >&2
    printf '%s\n' "$log" | tail -n 5 >&2
    return 1
  fi
  if [[ ! -s "$stl_path" ]]; then
    echo "Error: OCCT produced no STL for $step_path." >&2
    printf '%s\n' "$log" | tail -n 5 >&2
    return 1
  fi
}

# We want to run the example but keep the current working directory
# so that output files (via -o) are created where the user expects.
# We pass an absolute package path: moon discovers the project root from it,
# so no `-C` (which moon no longer supports) is needed.
if (( CONNECTORS_REQUESTED )); then
  export STEP_CONNECTOR_SIDECAR=1
else
  unset STEP_CONNECTOR_SIDECAR || true
fi
if (( ${#FORWARD_ARGS[@]} )); then
  MOONBIT_STEP_ROOT="$ROOT_DIR" \
    moon run --quiet "$ROOT_DIR/$EXAMPLE_PATH_REL" -- "${FORWARD_ARGS[@]}"
else
  MOONBIT_STEP_ROOT="$ROOT_DIR" \
    moon run --quiet "$ROOT_DIR/$EXAMPLE_PATH_REL"
fi

if (( HEADLESS_REQUESTED )); then
  if [[ -n "$STEP_OUT" && -f "$STEP_OUT" ]]; then
    echo "Generated $STEP_OUT"
    if [[ -f "$STEP_OUT.connectors.tsv" ]]; then
      echo "Connector sidecar: $STEP_OUT.connectors.tsv"
    fi
  fi
fi

if (( VIEW_REQUESTED )) && (( ! HEADLESS_REQUESTED )); then
  open_in_solidcraft "$VIEW_STEP"
fi

if (( STL_REQUESTED )); then
  step_to_stl "$STEP_OUT" "$STL_OUT"
  triangles="$(od -An -tu4 -j80 -N4 "$STL_OUT" 2>/dev/null | tr -d ' ')" || triangles=""
  if [[ "$triangles" =~ ^[0-9]+$ ]]; then
    echo "Wrote $STL_OUT ($triangles triangles)" >&2
  else
    echo "Wrote $STL_OUT" >&2
  fi
fi

if (( PNG_REQUESTED )); then
  if ! python3 "$ROOT_DIR/scripts/render_step.py" "$STEP_OUT" "$PNG_OUT"; then
    echo "Error: failed to render a PNG preview of $STEP_OUT." >&2
    exit 1
  fi
  echo "Wrote $PNG_OUT" >&2
fi
