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

cd "$ROOT_DIR"

# Runs the example module by folder name. Any extra args are forwarded to the example's main.
cd "$EXAMPLE_PATH_REL"
moon run --quiet --target native . -- "$@" || exit 1
