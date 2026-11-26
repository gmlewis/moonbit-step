#!/usr/bin/env bash
set -euo pipefail

ORIG_CMD="./run-example.sh $*"

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
  -stl [<path>]          Also write a binary STL (default: <step>.stl).
  --3mf [<path>]         Also write an OrcaSlicer-ready 3MF (default: <step>.3mf).
  --png [<path>]         Also render a four-view PNG preview (default: <step>.png).
  -o, --out <path>       Write the output named by <path>'s extension:
                        .step/.stp (or none) = STEP file (the default, stdout
                        when no path is given), .stl = binary STL, .3mf =
                        OrcaSlicer 3MF, .png = four-view preview, and
                        .gltf/.blend/.py = that format instead of STEP.
  --step <path>          Explicit STEP path; refuses a path whose extension
                        names another kind (= -o <path> for STEP).
  --eval [<path>]        Evaluate booleans with OCCT and write a real, trimmed
                        STEP file (default: <example>.step). Requires
                        occt-draw or DRAWEXE; overrides nominal STEP output.
  --view [<path>]        Open the model in SolidCraft. For boolean examples that
                        support --scScript (e.g. 39, 40), streams a native
                        SolidCraft script live into the open GUI (sub-second
                        popup, full editable feature tree); for pure STEP
                        examples (or when a path / -o is given), writes STEP
                        and opens it in SolidCraft with mate connectors.
  --view-with-preprocess [<path>]
                        Force the classic pre-evaluated STEP file path
                        (/tmp/<example>.step or <path>) and open in SolidCraft.
  --headless            Generate only; never open SolidCraft. Writes to
                        /tmp/<example>.step (or the -o path) and prints it.
                        Agents should always pass this instead of --view.
  --                     Optional separator (ignored).

Every option that takes a path accepts it either as the next argument
(`--3mf out.3mf`) or inline after "=" (`--3mf=out.3mf`); both forms are
equivalent. A following argument is used as the path only when it does not
start with "-", and, before the example name, only when it has that option's
file extension (.3mf, .stl, .png, .step/.stp, .blend, .py, .gltf), so
`./examples/run-example.sh --view 12` still reads 12 as the example number.

-o/--out picks the output kind from the file extension, so `-o coil.stl`
writes an STL and `-o scene.gltf` asks the example for glTF. `--step` is the
explicit STEP spelling and rejects another kind's extension. It may be
repeated for different kinds (`-o part.step -o part.stl -o part.3mf`), but
naming one kind twice with different paths is an error. A STEP or derived
output cannot be combined with .gltf/.blend/.py, because an example writes one
output format per run.

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
  ./examples/run-example.sh 12 --step coil.step   # explicit STEP spelling
  ./examples/run-example.sh 12 -o coil.stl        # STL, chosen by extension
  ./examples/run-example.sh 12 --out coil.3mf     # 3MF, chosen by extension
  ./examples/run-example.sh 12 -o coil.gltf       # glTF, chosen by extension
  ./examples/run-example.sh 12 -o coil.step -stl
  ./examples/run-example.sh 12 -o coil.step --png preview.png
  ./examples/run-example.sh 12 --numPairs 6 -o coil.step
  ./examples/run-example.sh 38 --3mf out.3mf
  ./examples/run-example.sh --3mf out.3mf 38   # same; options may come first
  ./examples/run-example.sh --view 12          # write /tmp/12-*.step and open it
  ./examples/run-example.sh 12 --help          # example-specific options
  ./examples/run-example.sh 12 > coil.step     # STEP to stdout
  ./examples/run-example.sh components/vslot --part wheel --view
  ./examples/run-example.sh clamp_shaft_collar --view
  ./examples/run-example.sh --headless bearing   # generate only (agents)
  ./examples/run-example.sh --no-connectors bearing --view

Notes:
  - Options other than the wrapper options above are forwarded to the example.
  - --blend, --bpy, --gltf, and --nostep suppress STEP output, so they cannot
    be combined with -stl, --3mf, or --png.
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

# Expand a leading "~" / "~/" (shells do not tilde-expand after "=" in flags
# like `--3mf=~/Downloads/foo.3mf`) and strip a leading "./".
expand_tilde() {
  local p="$1"
  if [[ "$p" == "~" ]]; then
    printf '%s' "$HOME"
  elif [[ "$p" == "~/"* ]]; then
    printf '%s' "$HOME/${p#\~/}"
  else
    printf '%s' "$p"
  fi
}

normalize_path() {
  local p
  p="$(expand_tilde "$1")"
  while [[ "$p" == ./* ]]; do p="${p#./}"; done
  printf '%s' "$p"
}

# --- Argument parsing -------------------------------------------------------
# Wrapper options may come before or after the example, and every option that
# takes a path accepts it either inline ("--3mf=out.3mf") or as the next
# argument ("--3mf out.3mf"). An option given without a value keeps its
# default. Everything the wrapper does not own is forwarded to the example
# unchanged (example options take space-separated values too).
wrapper_value_exts() {
  case "$1" in
    -o | --out | --step) printf '*' ;;
    -eval | --eval | --view | --view-with-preprocess) printf 'step stp' ;;
    -stl | --stl) printf 'stl' ;;
    -3mf | --3mf) printf '3mf' ;;
    -png | --png) printf 'png' ;;
    --blend) printf 'blend' ;;
    --bpy) printf 'py' ;;
    --gltf) printf 'gltf' ;;
    *) printf '' ;;
  esac
}

# takes_next_value OPTION TOKEN EXAMPLE_KNOWN succeeds when TOKEN is OPTION's
# space-separated value. Value-less and unknown options never take one, so the
# next option, the example name, or a forwarded argument stays where it is.
takes_next_value() {
  local opt="$1" token="${2:-}" example_known="${3:-0}" exts tok_ext ext
  [[ -n "$token" && "$token" != -* ]] || return 1
  exts="$(wrapper_value_exts "$opt")"
  [[ -n "$exts" ]] || return 1
  [[ "$exts" == "*" ]] && return 0
  # Once the example is known this option cannot be confused with it, so any
  # bare token is its value. Before that, require the option's own file
  # extension so `--view 12` and `--3mf 38` keep reading the example number.
  (( example_known )) && return 0
  [[ "$token" == *.* ]] || return 1
  tok_ext="$(printf '%s' "${token##*.}" | tr '[:upper:]' '[:lower:]')"
  for ext in $exts; do
    [[ "$tok_ext" == "$ext" ]] && return 0
  done
  return 1
}

# path_ext PATH prints PATH's lower-case extension without the dot (empty when
# there is none). Only the final path component counts.
path_ext() {
  local base="${1##*/}"
  case "$base" in
    *.*) printf '%s' "${base##*.}" | tr '[:upper:]' '[:lower:]' ;;
    *) return 0 ;;
  esac
}

# repeat_or_fail LABEL CURRENT NEW reports an error when NEW names a different
# path for an output kind that already has one (CURRENT), returns 1 when it is
# the same path (a harmless repeat), and 0 when the kind has no path yet.
repeat_or_fail() {
  local label="$1" current="$2" new="$3"
  [[ -n "$current" ]] || return 0
  if [[ "$(normalize_path "$current")" == "$(normalize_path "$new")" ]]; then
    return 1
  fi
  echo "Error: $label output already requested as $current (got $new)." >&2
  echo "       Give each output kind at most one path." >&2
  exit 2
}

# note_native KIND PATH records an example-native output (gltf, blend, or py)
# and reports conflicts, since an example writes one output format per run.
# Returns 0 when PATH is new (forward it) and 1 when it repeats one already
# recorded.
note_native() {
  local kind="$1" path="$2"
  if [[ -n "$STEP_OUT" ]]; then
    echo "Error: $path asks for .$kind, but STEP output is already requested ($STEP_OUT)." >&2
    echo "       An example writes one output format per run." >&2
    exit 2
  fi
  if [[ -n "$NATIVE_OUT_KIND" && "$NATIVE_OUT_KIND" != "$kind" ]]; then
    echo "Error: cannot combine .$NATIVE_OUT_KIND and .$kind outputs." >&2
    echo "       An example writes one output format per run." >&2
    exit 2
  fi
  if repeat_or_fail ".$kind" "$NATIVE_OUT_ARG" "$path"; then
    NATIVE_OUT_KIND="$kind"
    NATIVE_OUT_ARG="$path"
    NO_STEP_OUTPUT=1
    return 0
  fi
  return 1
}

# route_output OPTION PATH FORCE_STEP sends an -o/--out/--step path to the
# output kind named by its extension: .step/.stp (or no extension) writes STEP,
# .stl/.3mf/.png derive that file from the STEP, and .gltf/.blend/.py ask the
# example for that format instead of STEP. FORCE_STEP is 1 for --step, which
# rejects a path whose extension names another kind. Repeating a kind with a
# different path is an error; different kinds combine.
route_output() {
  local opt="$1" path="$2" force="$3" ext
  path="$(expand_tilde "$path")"
  ext="$(path_ext "$path")"
  if (( force )); then
    case "$ext" in
      stl | 3mf | png | gltf | blend | py)
        echo "Error: $opt wants a STEP file, but $path ends in .$ext." >&2
        echo "       Use -o $path to let the extension choose the output." >&2
        exit 2
        ;;
    esac
  fi
  case "$ext" in
    stl)
      if repeat_or_fail STL "$STL_OUT_ARG" "$path"; then
        STL_REQUESTED=1
        STL_OUT_ARG="$path"
      fi
      ;;
    3mf)
      if repeat_or_fail 3MF "$THREEMF_OUT_ARG" "$path"; then
        THREEMF_REQUESTED=1
        THREEMF_OUT_ARG="$path"
      fi
      ;;
    png)
      if repeat_or_fail PNG "$PNG_OUT_ARG" "$path"; then
        PNG_REQUESTED=1
        PNG_OUT_ARG="$path"
      fi
      ;;
    gltf | blend | py)
      # The example writes these instead of STEP; one format per run.
      NO_STEP_OUTPUT=1
      if note_native "$ext" "$path"; then
        case "$ext" in
          gltf) FORWARD_ARGS+=(--gltf "$path") ;;
          blend) FORWARD_ARGS+=(--blend "$path") ;;
          py) FORWARD_ARGS+=(--bpy "$path") ;;
        esac
      fi
      ;;
    *)
      if [[ -n "$NATIVE_OUT_KIND" ]]; then
        echo "Error: cannot write STEP to $path together with a .$NATIVE_OUT_KIND output." >&2
        echo "       An example writes one output format per run." >&2
        exit 2
      fi
      if (( NO_STEP_OUTPUT )); then
        echo "Error: cannot write STEP to $path; another option suppresses STEP output." >&2
        exit 2
      fi
      if repeat_or_fail STEP "$STEP_OUT" "$path"; then
        STEP_OUT="$path"
        FORWARD_ARGS+=(-o "$path")
      fi
      ;;
  esac
}

STL_REQUESTED=0
STL_OUT_ARG=""
STL_OUT=""
THREEMF_REQUESTED=0
THREEMF_OUT_ARG=""
THREEMF_OUT=""
PNG_REQUESTED=0
PNG_OUT_ARG=""
PNG_OUT=""
STEP_OUT=""
EVAL_OUT=""
NATIVE_OUT_KIND=""
NATIVE_OUT_ARG=""
VIEW_REQUESTED=0
VIEW_PREPROCESS_REQUESTED=0
VIEW_PATH_ARG=""
VIEW_STEP=""
LIVE_REQUESTED=0
LIVE_SCRIPT=""
HEADLESS_REQUESTED=0
CONNECTORS_REQUESTED=1
NO_STEP_OUTPUT=0
EXAMPLE_ARG=""
FORWARD_ARGS=()

ARGS=("$@")
i=0
while (( i < ${#ARGS[@]} )); do
  arg="${ARGS[$i]}"
  i=$((i + 1))
  opt="$arg"
  value=""
  inline=0
  if [[ "$arg" == -* && "$arg" == *=* ]]; then
    opt="${arg%%=*}"
    value="${arg#*=}"
    inline=1
  fi
  # "--" is a documented no-op separator; never forward it.
  [[ "$opt" == "--" ]] && continue
  # The first bare token names the example.
  if [[ -z "$EXAMPLE_ARG" && "$opt" != -* ]]; then
    EXAMPLE_ARG="$arg"
    continue
  fi
  example_known=0
  if [[ -n "$EXAMPLE_ARG" ]]; then example_known=1; fi
  if (( ! inline )) && takes_next_value "$opt" "${ARGS[$i]:-}" "$example_known"; then
    value="${ARGS[$i]}"
    i=$((i + 1))
  fi
  case "$opt" in
    -stl | --stl)
      STL_REQUESTED=1
      if [[ -n "$value" ]]; then
        value="$(expand_tilde "$value")"
        if repeat_or_fail STL "$STL_OUT_ARG" "$value"; then
          STL_OUT_ARG="$value"
        fi
      fi
      ;;
    -3mf | --3mf)
      THREEMF_REQUESTED=1
      if [[ -n "$value" ]]; then
        value="$(expand_tilde "$value")"
        if repeat_or_fail 3MF "$THREEMF_OUT_ARG" "$value"; then
          THREEMF_OUT_ARG="$value"
        fi
      fi
      ;;
    -png | --png)
      PNG_REQUESTED=1
      if [[ -n "$value" ]]; then
        value="$(expand_tilde "$value")"
        if repeat_or_fail PNG "$PNG_OUT_ARG" "$value"; then
          PNG_OUT_ARG="$value"
        fi
      fi
      ;;
    -o | --out | --step)
      if [[ -z "$value" ]]; then
        echo "Error: $opt needs a path, e.g. $opt out.step." >&2
        exit 2
      fi
      if [[ "$opt" == "--step" ]]; then
        route_output "$opt" "$value" 1
      else
        route_output "$opt" "$value" 0
      fi
      ;;
    -eval | --eval)
      EVAL_OUT="$value"
      # Examples register eval as a long option only.
      if [[ -n "$value" ]]; then
        FORWARD_ARGS+=(--eval "$value")
      else
        FORWARD_ARGS+=(--eval)
      fi
      ;;
    --view)
      VIEW_REQUESTED=1
      if (( inline )) || [[ -n "$value" ]]; then
        # An explicit path means the classic pre-evaluated STEP route.
        VIEW_PREPROCESS_REQUESTED=1
        VIEW_PATH_ARG="$value"
      fi
      ;;
    --view-with-preprocess)
      VIEW_REQUESTED=1
      VIEW_PREPROCESS_REQUESTED=1
      VIEW_PATH_ARG="$value"
      ;;
    --live)
      LIVE_REQUESTED=1
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
    --blend | --bpy | --gltf)
      # The example handles these itself; they only mean no STEP is written.
      NO_STEP_OUTPUT=1
      case "$opt" in
        --gltf) native_kind=gltf ;;
        --blend) native_kind=blend ;;
        --bpy) native_kind=py ;;
      esac
      if [[ -n "$value" ]]; then
        value="$(expand_tilde "$value")"
        if note_native "$native_kind" "$value"; then
          FORWARD_ARGS+=("$opt" "$value")
        fi
      else
        FORWARD_ARGS+=("$opt")
      fi
      ;;
    --nostep)
      NO_STEP_OUTPUT=1
      FORWARD_ARGS+=(--nostep)
      ;;
    *)
      FORWARD_ARGS+=("$arg")
      ;;
  esac
done

if [[ -z "$EXAMPLE_ARG" ]]; then
  echo "Error: example name or number is missing." >&2
  usage >&2
  exit 2
fi

# An example writes one output format per run, so a STEP path cannot ride along
# with an option that replaces STEP.
if (( NO_STEP_OUTPUT )) && [[ -n "$STEP_OUT" ]]; then
  echo "Error: cannot write STEP to $STEP_OUT together with --blend, --bpy, --gltf, or --nostep." >&2
  exit 2
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

# An evaluated export replaces the nominal STEP file, so derive previews from it.
if [[ -n "$EVAL_OUT" ]]; then
  STEP_OUT="$EVAL_OUT"
fi

# Auto-promote `--view` to instant live SolidCraft streaming when the example
# supports `--scScript` and no explicit STEP output / preprocess was requested.
if (( VIEW_REQUESTED )) && (( ! VIEW_PREPROCESS_REQUESTED )) && (( ! HEADLESS_REQUESTED )) &&
  (( ! STL_REQUESTED )) && (( ! THREEMF_REQUESTED )) && (( ! PNG_REQUESTED )) &&
  [[ -z "$STEP_OUT" ]] &&
  grep -q "scScript" "$ROOT_DIR/$EXAMPLE_PATH_REL"/*.mbt 2>/dev/null; then
  LIVE_REQUESTED=1
  VIEW_REQUESTED=0
fi

# --- View in SolidCraft -----------------------------------------------------
if (( VIEW_REQUESTED )); then
  if (( NO_STEP_OUTPUT )); then
    echo "Error: --view cannot be combined with --blend, --bpy, --gltf, or --nostep" >&2
    echo "       because those options suppress the STEP output." >&2
    exit 1
  fi
  if [[ -n "$VIEW_PATH_ARG" ]] && [[ -n "$STEP_OUT" ]]; then
    echo "Error: use either --view <path> or -o <path>, not both." >&2
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

# --- Live SolidCraft streaming ----------------------------------------------
if (( LIVE_REQUESTED )); then
  LIVE_SCRIPT="/tmp/${EXAMPLE_NAME}.sc.json"
  rm -rf "$LIVE_SCRIPT" "${LIVE_SCRIPT}.leaves"
  FORWARD_ARGS+=(--scScript "$LIVE_SCRIPT")
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
if (( STL_REQUESTED || THREEMF_REQUESTED || PNG_REQUESTED )); then
  if (( NO_STEP_OUTPUT )); then
    echo "Error: -stl, --3mf, and --png cannot be combined with --blend, --bpy, --gltf, or --nostep" >&2
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
  if (( THREEMF_REQUESTED )); then
    if [[ -n "$THREEMF_OUT_ARG" ]]; then
      THREEMF_OUT="$THREEMF_OUT_ARG"
    else
      THREEMF_OUT="$(sibling_output 3mf)"
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
      echo "       Pass the STL path explicitly with -stl <path>." >&2
      exit 1
    fi
    if (( THREEMF_REQUESTED )) && [[ "$(normalize_path "$THREEMF_OUT")" == "$step_cmp" ]]; then
      echo "Error: 3MF path must differ from the STEP path: $THREEMF_OUT" >&2
      echo "       Pass the 3MF path explicitly with --3mf <path>." >&2
      exit 1
    fi
    if (( PNG_REQUESTED )) && [[ "$(normalize_path "$PNG_OUT")" == "$step_cmp" ]]; then
      echo "Error: PNG path must differ from the STEP path: $PNG_OUT" >&2
      echo "       Pass the PNG path explicitly with --png <path>." >&2
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
  if (( THREEMF_REQUESTED )) && [[ ! -d "$(dirname "$THREEMF_OUT")" ]]; then
    echo "Error: 3MF output directory does not exist: $(dirname "$THREEMF_OUT")" >&2
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

find_solidcraft() {
  if [[ -x "$HOME/tools/bin/solidcraft-cli" ]]; then
    printf '%s' "$HOME/tools/bin/solidcraft-cli"
    return 0
  fi
  command -v solidcraft-cli 2>/dev/null || true
}

step_to_stl() {
  local step_path="$1"
  local stl_path="$2"
  local deflection="${STL_DEFLECTION:-0.05}"
  local sc occt log

  sc="$(find_solidcraft)"
  if [[ -n "$sc" ]] && command -v python3 >/dev/null 2>&1; then
    if python3 - "$sc" "$step_path" "$stl_path" <<'PY'
import json, subprocess, sys, tempfile
from pathlib import Path
sc, step_p, stl_p = sys.argv[1], Path(sys.argv[2]).resolve(), Path(sys.argv[3]).resolve()
script = [
    {"command": "file.insert_step", "params": {"path": str(step_p), "flatten": True}},
    {"command": "file.export_stl", "params": {"path": str(stl_p), "quality": "fine"}},
]
with tempfile.TemporaryDirectory() as td:
    sp = Path(td) / "s.json"
    sp.write_text(json.dumps(script))
    r = subprocess.run([sc, "run", str(sp), "--validation", "off", "--quiet"], capture_output=True, text=True, timeout=180)
    sys.exit(0 if r.returncode == 0 and stl_p.is_file() and stl_p.stat().st_size > 84 else 1)
PY
    then
      return 0
    fi
  fi

  occt="$(find_occt)"
  if [[ -z "$occt" ]]; then
    echo "Error: neither solidcraft-cli nor occt-draw/DRAWEXE found (checked ~/tools/bin and PATH)." >&2
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

if (( LIVE_REQUESTED )) && (( ! HEADLESS_REQUESTED )); then
  if [[ ! -s "$LIVE_SCRIPT" ]]; then
    echo "Error: example did not write SolidCraft script at $LIVE_SCRIPT (does it support --scScript?)." >&2
    exit 1
  fi
  if ! python3 "$ROOT_DIR/scripts/run_solidcraft_live.py" "$LIVE_SCRIPT"; then
    echo "Error: failed to stream $LIVE_SCRIPT into SolidCraft." >&2
    exit 1
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

if (( THREEMF_REQUESTED )); then
  if ! "$ROOT_DIR/scripts/step_to_3mf.py" "$STEP_OUT" "$THREEMF_OUT" --command "$ORIG_CMD" --repo-dir "$ROOT_DIR"; then
    echo "Error: failed to export 3MF from $STEP_OUT." >&2
    exit 1
  fi
  echo "Wrote $THREEMF_OUT" >&2
fi

if (( PNG_REQUESTED )); then
  if ! python3 "$ROOT_DIR/scripts/render_step.py" "$STEP_OUT" "$PNG_OUT"; then
    echo "Error: failed to render a PNG preview of $STEP_OUT." >&2
    exit 1
  fi
  echo "Wrote $PNG_OUT" >&2
fi
