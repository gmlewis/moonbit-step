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

# On Linux (Mint/Debian), it is often 'occt-draw'.
# On macOS (Homebrew), it is 'DRAWEXE'.
if command -v occt-draw >/dev/null 2>&1; then
  OCCT_BIN="occt-draw"
elif command -v DRAWEXE >/dev/null 2>&1; then
  OCCT_BIN="DRAWEXE"
else
  echo "Error: 'occt-draw' or 'DRAWEXE' not found on PATH." >&2
  echo "Install Open CASCADE (e.g. 'brew install opencascade' on macOS)." >&2
  exit 1
fi

if [[ ! -f "$STEP_PATH" ]]; then
  echo "Error: STEP file not found: $STEP_PATH" >&2
  exit 1
fi

# Escape quotes so paths with quotes don't break the occt command string.
STEP_PATH_ESCAPED="${STEP_PATH//\"/\\\"}"

DRAW_CMD="pload ALL; testreadstep \"${STEP_PATH_ESCAPED}\" ${SHAPE_NAME}; nbshapes ${SHAPE_NAME}; checkshape ${SHAPE_NAME};"

OUTPUT="$($OCCT_BIN -b -c "$DRAW_CMD")"
printf '%s\n' "$OUTPUT"

NBSHAPES_LINE="$(grep -E "NbShapes" <<<"$OUTPUT" | head -n1 || true)"
if [[ -n "$NBSHAPES_LINE" ]]; then
  NBSHAPES_SUM="$(printf '%s' "$NBSHAPES_LINE" | tr -cd '0-9 ' | tr ' ' '\n' | awk '{s+=$1} END {print s+0}')"
  if [[ "$NBSHAPES_SUM" -eq 0 ]]; then
    echo "Validation failed: OCCT reported zero topology (nbshapes=0)." >&2
    exit 1
  fi
fi

if grep -q "This shape seems to be valid" <<<"$OUTPUT"; then
  exit 0
fi

echo "Validation failed: OCCT checkshape did not report a valid shape." >&2
exit 1
