#!/usr/bin/env bash
#
# manage-examples.sh
#
# A central tool to validate, render, and document examples.
#
# Usage:
#   ./scripts/manage-examples.sh [example-num] [flags]
#
# Flags:
#   --validate      Run OCCT topological validation (default)
#   --render        Generate a PNG preview using OCCT
#   --readme        Update README.md with the preview image
#   --all           Process all implemented examples
#
# Examples:
#   ./scripts/manage-examples.sh 01 --render --readme
#   ./scripts/manage-examples.sh --all --validate

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUN_EXAMPLE="$ROOT_DIR/run-example.sh"

# Detect OCCT binary
if command -v occt-draw >/dev/null 2>&1; then
  OCCT_BIN="occt-draw"
elif command -v DRAWEXE >/dev/null 2>&1; then
  OCCT_BIN="DRAWEXE"
else
  echo "Error: 'occt-draw' or 'DRAWEXE' not found." >&2
  exit 1
fi

# Default actions
DO_VALIDATE=false
DO_RENDER=false
DO_README=false
TARGET_FILTER=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --render) DO_RENDER=true ;;
    --readme) DO_README=true ;;
    --validate) DO_VALIDATE=true ;;
    --all) TARGET_FILTER="all" ;;
    [0-9][0-9]) TARGET_FILTER="$1" ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
  shift
done

if [[ -z "$TARGET_FILTER" ]]; then
  echo "Usage: $0 <example-num|--all> [--validate] [--render] [--readme]"
  exit 1
fi

# If no action specified, default to validate
if [[ "$DO_VALIDATE" == "false" && "$DO_RENDER" == "false" && "$DO_README" == "false" ]]; then
  DO_VALIDATE=true
fi

process_example() {
  local num="$1"
  local args="$2"
  local example_dir
  
  # Find the directory
  example_dir=$(ls -d "$ROOT_DIR/examples/$num"-* 2>/dev/null | head -n 1)
  if [[ ! -d "$example_dir" ]]; then
    echo "Skipping Example $num: Directory not found"
    return
  fi

  local name=$(basename "$example_dir")
  local step_file="/tmp/${name}.step"
  local png_file="$example_dir/preview.png"

  echo "--------------------------------------------------------"
  echo "PROCESSING: $name"
  echo "--------------------------------------------------------"

  # 1. Generate the STEP file
  if ! "$RUN_EXAMPLE" "$num" $args > "$step_file"; then
    echo "FAILED: Could not generate STEP for $num"
    return 1
  fi

  # 2. Validate
  if [[ "$DO_VALIDATE" == "true" ]]; then
    echo "Validating topology..."
    DRAW_CMD="pload MODELING; pload XDE; testreadstep \"$step_file\" s; checkshape s;"
    if ! $OCCT_BIN -b -c "$DRAW_CMD" 2>/dev/null | grep -q "This shape seems to be valid"; then
      echo "FAILED: $num produced invalid topology"
      return 1
    fi
    echo "Topological validation: OK"
  fi

  # 3. Render
  if [[ "$DO_RENDER" == "true" ]]; then
    echo "Rendering preview to $png_file..."
    # pload VISUALIZATION needs a display. 
    # We use vinit; vdisplay; vsetdispmode (1=shaded); vfit; vdump
    # Note: vsetdispmode 1 makes it look like a solid instead of wireframe.
    RENDER_CMD="pload MODELING; pload VISUALIZATION; testreadstep \"$step_file\" s; vinit; vdisplay s; vsetdispmode s 1; vfit; vdump \"$png_file\"; vclose ALL;"
    
    # We run DRAWEXE. On macOS it might pop up a window briefly.
    $OCCT_BIN -b -c "$RENDER_CMD" > /dev/null 2>&1 || true
    
    if [[ -f "$png_file" ]]; then
      echo "Render: SUCCESS"
    else
      echo "Render: FAILED (Check if X11/OpenGL context is available)"
    fi
  fi

  # 4. Update README
  if [[ "$DO_README" == "true" ]]; then
    local readme="$example_dir/README.md"
    if ! grep -q "preview.png" "$readme"; then
      echo "Updating $readme with preview link..."
      # Use perl for portable in-place insertion after the first line
      perl -i -pe 'print "\n![Preview](preview.png)\n" if $. == 2' "$readme"
    fi
  fi
}

get_args() {
  case $1 in
    "01") echo "--edge 20" ;; 
    "02") echo "--length 40 --width 20 --height 10 --filletRadius 2" ;; 
    "03") echo "--name Gemini" ;; 
    "04") echo "--id 10 --od 25 --thickness 3" ;; 
    "05") echo "--rows 2 --cols 2 --text Grid" ;; 
    "06") echo "--count 3" ;; 
    *) echo "" ;; 
  esac
}

if [[ "$TARGET_FILTER" == "all" ]]; then
  for num in "01" "02" "03" "04" "05" "06"; do
    process_example "$num" "$(get_args "$num")"
  done
else
  process_example "$TARGET_FILTER" "$(get_args "$TARGET_FILTER")"
fi

echo "Done."