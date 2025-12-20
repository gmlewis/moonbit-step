#!/usr/bin/env bash
#
# validate-all-examples.sh
#
# Runs all implemented examples with various arguments and validates
# the resulting STEP files using OCCT (Open CASCADE).
#
# This is a slower, heavy-duty integration suite designed to ensure
# that we always produce mathematically and topologically valid STEP solids.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VALIDATOR="$SCRIPT_DIR/validate_with_occt.sh"
RUN_EXAMPLE="$ROOT_DIR/run-example.sh"

# Ensure validator is executable
chmod +x "$VALIDATOR"

TEMP_DIR=$(mktemp -d)
echo "Using temporary directory: $TEMP_DIR"

# Track results
FAILED=()
PASSED_COUNT=0

validate_example() {
  local num="$1"
  local args="${*:2}"
  local step_file="$TEMP_DIR/example-${num}-${PASSED_COUNT}.step"
  
  echo "--------------------------------------------------------"
  echo "TESTING: Example $num with args: $args"
  echo "--------------------------------------------------------"

  # Run the example
  if ! "$RUN_EXAMPLE" "$num" $args > "$step_file"; then
    echo "FAILED: Example $num failed to run"
    FAILED+=("Example $num (Run failure) [Args: $args]")
    return 1
  fi

  # Validate the STEP file
  if ! "$VALIDATOR" "$step_file"; then
    echo "FAILED: Example $num produced an invalid STEP file"
    FAILED+=("Example $num (Validation failure) [Args: $args]")
    return 1
  fi

  echo "SUCCESS: Example $num is valid"
  PASSED_COUNT=$((PASSED_COUNT + 1))
  return 0
}

# --- TEST SUITE ---

# 01-hello-cube
validate_example "01" "--edge 10"
validate_example "01" "--edge 25 --tx 5 --ty 5 --tz 5"

# 02-calibration-chamfer-block
validate_example "02" "--length 20 --width 20 --height 5"
validate_example "02" "--chamferSize 2"
validate_example "02" "--filletRadius 1.5"

# 03-engraved-name-tag
validate_example "03" "--name gmlewis"
validate_example "03" "--name MoonBit --embossDepth 2 --length 60"

# 04-parametric-washer-kit
validate_example "04" "--id 5 --od 15 --thickness 2"
validate_example "04" "--id 10 --od 12 --thickness 0.5 --segments 32"

# 05-gridfinity-compatible-bin
validate_example "05" "--rows 1 --cols 1 --height 20"
validate_example "05" "--rows 2 --cols 1 --text Gemini"

# 06-stackable-spacer-tower
validate_example "06" "--count 1"
validate_example "06" "--count 3 --height 10 --clickHeight 1"

# --- SUMMARY ---

echo ""
echo "========================================================"
echo "VALIDATION SUMMARY"
echo "========================================================"
echo "Passed: $PASSED_COUNT"
echo "Failed: ${#FAILED[@]}"

if [ ${#FAILED[@]} -ne 0 ]; then
  echo ""
  echo "Failure Details:"
  for f in "${FAILED[@]}"; do
    echo "  - $f"
  done
  exit 1
fi

echo ""
echo "All examples produced valid STEP files!"
rm -rf "$TEMP_DIR"
exit 0
