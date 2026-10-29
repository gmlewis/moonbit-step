#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
run-example.sh — run an example and optionally export a mesh or preview image.

Usage:
  ./examples/run-example.sh <example> [options...]
  ./examples/run-example.sh <number>  [options...]     e.g. 01, 1, 39

Wrapper options:
  -h, --help             Show this help and exit.
  -stl[=<path>]         Also write a binary STL (default: <step>.stl).
  --png[=<path>]        Also render a four-view PNG preview (default: <step>.png).
  -o, --out <path>      Write the STEP file to <path> (default: stdout).
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
  glTF (.gltf, .glb)     NOT implemented yet; planned as Task 2 in
                         perfect-prompt.md.

Examples:
  ./examples/run-example.sh 01 -o cube.step
  ./examples/run-example.sh 39 -o fits.step -stl
  ./examples/run-example.sh 39 -o fits.step --png=preview.png
  ./examples/run-example.sh 03 --name Susan --emboss -o tag.step
  ./examples/run-example.sh 01 -- --help      # example-specific options
  ./examples/run-example.sh 01 > cube.step    # STEP to stdout

Notes:
  - Options other than the wrapper options above are forwarded to the example.
  - --blend, --bpy, and --nostep suppress STEP output, so they cannot be
    combined with -stl or --png.
  - -stl and --png may be used together; both derive from the same STEP file.
  - STL/PNG previews need OCCT ('occt-draw' or 'DRAWEXE') on PATH.
EOF
}

if [[ $# -gt 0 ]]; then
  case "$1" in
    -h | --help | help)
      usage
      exit 0
      ;;
  esac
fi

if [[ $# -lt 1 ]]; then
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

# Allow users to pass a bare folder name ("01-hello-cube") or a path
# ("./01-hello-cube", "01-hello-cube/", "examples/01-hello-cube/").
EXAMPLE_ARG_STRIPPED="${EXAMPLE_ARG%/}"
EXAMPLE_BASENAME="$(basename "$EXAMPLE_ARG_STRIPPED")"

# Get the absolute path of the script, resolving symlinks.
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Resolve the example folder relative to the project root.
# If a path is provided (e.g. examples/01-hello-cube), respect it; otherwise assume examples/<name>.
if [[ "$EXAMPLE_ARG_STRIPPED" == *"/"* ]]; then
  EXAMPLE_PATH_REL="$EXAMPLE_ARG_STRIPPED"
else
  # If it's a number, try to find the full folder name (e.g. "1" or "01" -> "01-hello-cube").
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
  echo "Error: example folder not found: $EXAMPLE_ARG" >&2
  echo "Looked in: $ROOT_DIR/$EXAMPLE_PATH_REL" >&2
  exit 1
fi

# The resolved folder name (e.g. "01-hello-cube"), used for default file names.
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
    --blend | --blend=* | --bpy | --bpy=* | --nostep)
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

# --- Checked derived outputs ------------------------------------------------
if (( STL_REQUESTED || PNG_REQUESTED )); then
  if (( NO_STEP_OUTPUT )); then
    echo "Error: -stl and --png cannot be combined with --blend, --bpy, or --nostep" >&2
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
if (( ${#FORWARD_ARGS[@]} )); then
  MOONBIT_STEP_ROOT="$ROOT_DIR" \
    moon run --quiet --target native "$ROOT_DIR/$EXAMPLE_PATH_REL" -- "${FORWARD_ARGS[@]}"
else
  MOONBIT_STEP_ROOT="$ROOT_DIR" \
    moon run --quiet --target native "$ROOT_DIR/$EXAMPLE_PATH_REL"
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
