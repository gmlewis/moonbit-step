#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") <example-folder> [args...]" >&2
  echo "Example: ./examples/$(basename "$0") examples/01-hello-cube --size 20" >&2
  echo "Example (stdout redirect): ./examples/$(basename "$0") examples/01-hello-cube > my-file.stp" >&2
  echo "  (Tip: redirections like '> my-file.stp' write to a file in your current directory.)" >&2
  echo "Example (STL output): ./examples/$(basename "$0") 01 -o cube.step -stl" >&2
  echo "  (-stl converts the generated STEP file to STL with OCCT; use" >&2
  echo "   '-stl=<path>' to choose the STL path, or STL_DEFLECTION=<mm> to set" >&2
  echo "   the tessellation tolerance, default 0.05.)" >&2
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

# --- Forwarded arguments ----------------------------------------------------
# `-stl` is handled by this wrapper; every other argument is forwarded to the
# example. `-o`/`--out` is picked out only to locate the generated STEP file.
STL_REQUESTED=0
STL_OUT_ARG=""
STL_OUT=""
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

if (( STL_REQUESTED )); then
  if (( NO_STEP_OUTPUT )); then
    echo "Error: -stl cannot be combined with --blend, --bpy, or --nostep" >&2
    echo "       because those options suppress the STEP output." >&2
    exit 1
  fi

  if [[ -n "$STL_OUT_ARG" ]]; then
    STL_OUT="$STL_OUT_ARG"
  elif [[ -n "$STEP_OUT" ]]; then
    step_dir="$(dirname "$STEP_OUT")"
    step_base="$(basename "$STEP_OUT")"
    case "$step_base" in
      *.*) step_base="${step_base%.*}" ;;
    esac
    STL_OUT="$step_dir/$step_base.stl"
  else
    STL_OUT="$EXAMPLE_NAME.stl"
  fi

  if [[ ! -d "$(dirname "$STL_OUT")" ]]; then
    echo "Error: STL output directory does not exist: $(dirname "$STL_OUT")" >&2
    exit 1
  fi

  # Without -o the example writes STEP to stdout. Capture it in a temporary
  # file so it does not end up in the terminal or mixed with STL output.
  if [[ -z "$STEP_OUT" ]]; then
    STEP_TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/step-stl.XXXXXX")"
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
