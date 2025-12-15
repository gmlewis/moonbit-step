#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") <example-folder> [args...]" >&2
  echo "Example: ./examples/$(basename "$0") examples/01-hello-cube --size 20" >&2
  echo "Example (stdout redirect): ./examples/$(basename "$0") examples/01-hello-cube > my-file.stp" >&2
  echo "  (Tip: redirections like '> my-file.stp' write to a file in your current directory.)" >&2
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Resolve the example folder relative to the project root.
# If a path is provided (e.g. examples/01-hello-cube), respect it; otherwise assume examples/<name>.
if [[ "$EXAMPLE_ARG_STRIPPED" == *"/"* ]]; then
  EXAMPLE_PATH_REL="$EXAMPLE_ARG_STRIPPED"
else
  EXAMPLE_PATH_REL="examples/$EXAMPLE_BASENAME"
fi

if [[ ! -d "$ROOT_DIR/$EXAMPLE_PATH_REL" ]]; then
  echo "Error: example folder not found: $EXAMPLE_ARG" >&2
  echo "Looked in: $ROOT_DIR/$EXAMPLE_PATH_REL" >&2
  exit 1
fi

cd "$ROOT_DIR"

# Runs the example module by folder name. Any extra args are forwarded to the example's main.
moon run --target native "$EXAMPLE_PATH_REL" -- "$@"
