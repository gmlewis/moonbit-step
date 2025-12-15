#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") <file.step> [shape-name]" >&2
  echo "Example: $(basename "$0") /tmp/hello-cube.step" >&2
  echo "Example: $(basename "$0") tests/fixtures/simple-box.step a" >&2
  exit 2
fi

STEP_PATH="$1"
SHAPE_NAME="${2:-a}"

if ! command -v occt-draw >/dev/null 2>&1; then
  echo "Error: 'occt-draw' not found on PATH." >&2
  echo "Install Open CASCADE DRAWEXE tools (package name varies by distro)." >&2
  exit 1
fi

if [[ ! -f "$STEP_PATH" ]]; then
  echo "Error: STEP file not found: $STEP_PATH" >&2
  exit 1
fi

# Escape quotes so paths with quotes don't break the occt command string.
STEP_PATH_ESCAPED="${STEP_PATH//\"/\\\"}"

DRAW_CMD="pload ALL; testreadstep \"${STEP_PATH_ESCAPED}\" ${SHAPE_NAME}; nbshapes ${SHAPE_NAME}; checkshape ${SHAPE_NAME};"

OUTPUT="$(occt-draw -b -c "$DRAW_CMD")"
printf '%s\n' "$OUTPUT"

if grep -q "This shape seems to be valid" <<<"$OUTPUT"; then
  exit 0
fi

echo "Validation failed: OCCT checkshape did not report a valid shape." >&2
exit 1
