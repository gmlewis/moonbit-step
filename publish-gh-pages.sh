#!/usr/bin/env bash
# publish-gh-pages.sh — Build and publish the static GitHub Pages catalog for
# gmlewis/moonbit-step onto an orphan `gh-pages` branch without touching the
# currently checked-out branch (`master`).
#
# Usage:
#   ./publish-gh-pages.sh                     # build all examples + components & force-push gh-pages
#   ./publish-gh-pages.sh --local-only        # build _site/ locally without pushing
#   ./publish-gh-pages.sh --only 38,bearing   # build only selected examples/components
#   ./publish-gh-pages.sh --skip-components   # build only top-level examples/
set -euo pipefail

cd "$(dirname "$0")"

die() { echo "error: $*" >&2; exit 1; }
note() { echo "==> $*"; }

LOCAL_ONLY=0
SKIP_COMPONENTS=0
STYLE_ONLY=0
ONLY=""

usage() {
  cat <<'EOF'
publish-gh-pages.sh — Build and publish the GitHub Pages catalog (`gh-pages`).

Usage:
  ./publish-gh-pages.sh [options]

Options:
  --local-only, --no-push  Build `_site/` locally without pushing to GitHub
  --style-only             Refresh HTML/CSS/JS only (no model/STEP/GLB rebuilds)
  --only LIST              Comma-separated example/component names (e.g. 38,bearing)
  --skip-components        Build only top-level `examples/` (skip `components/`)
  -h, --help               Show this help and exit
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help) usage; exit 0 ;;
    --local-only | --no-push) LOCAL_ONLY=1; shift ;;
    --skip-components) SKIP_COMPONENTS=1; shift ;;
    --style-only) STYLE_ONLY=1; shift ;;
    --only) ONLY="${2:-}"; shift 2 ;;
    --only=*) ONLY="${1#*=}"; shift ;;
    *) die "unknown option: $1" ;;
  esac
done

for cmd in git python3; do
  command -v "$cmd" >/dev/null 2>&1 || die "$cmd not found on PATH"
done

BUILD_ARGS=(--out _site)
if (( SKIP_COMPONENTS )); then
  BUILD_ARGS+=(--skip-components)
fi
if (( STYLE_ONLY )); then
  BUILD_ARGS+=(--style-only)
fi
if [[ -n "$ONLY" ]]; then
  BUILD_ARGS+=(--only "$ONLY")
fi

note "Generating GitHub Pages static site in _site/ ..."
./scripts/build_gh_pages.py "${BUILD_ARGS[@]}"

if (( LOCAL_ONLY )); then
  note "Local-only build complete. Preview with:"
  echo "  python3 -m http.server --directory _site 8080"
  echo "  open http://127.0.0.1:8080/"
  exit 0
fi

ORIGIN_URL="$(git remote get-url origin)"
VERSION="$(sed -n 's/^version *= *"\([^"]*\)".*/\1/p' moon.mod | head -n 1)"
MODULE="$(sed -n 's/^name *= *"\([^"]*\)".*/\1/p' moon.mod | head -n 1)"
REPO_SLUG="$(printf '%s' "$ORIGIN_URL" | sed -E 's#^(git@github\.com:|https://github\.com/)##; s/\.git$//')"

STAGE_DIR="$(mktemp -d /tmp/gh-pages-step-XXXXXX)"
trap 'rm -rf "$STAGE_DIR"' EXIT

note "Staging orphan gh-pages commit in $STAGE_DIR (leaving master untouched) ..."
cp -R _site/. "$STAGE_DIR/"
touch "$STAGE_DIR/.nojekyll"

(
  cd "$STAGE_DIR"
  git init -q
  git checkout -q -b gh-pages
  git add -A
  git commit -q -m "Publish GitHub Pages for ${MODULE}@${VERSION}"
  note "Force-pushing gh-pages to ${ORIGIN_URL} ..."
  git push --force "$ORIGIN_URL" HEAD:refs/heads/gh-pages
)

if command -v gh >/dev/null 2>&1 && [[ -n "$REPO_SLUG" ]]; then
  note "Ensuring GitHub Pages is enabled for ${REPO_SLUG} (branch: gh-pages) ..."
  if ! gh api "repos/${REPO_SLUG}/pages" >/dev/null 2>&1; then
    gh api -X POST "repos/${REPO_SLUG}/pages" \
      -f "source[branch]=gh-pages" \
      -f "source[path]=/" >/dev/null ||
      echo "warning: could not auto-enable GitHub Pages via gh api; enable gh-pages in repo Settings -> Pages." >&2
  fi
fi

OWNER="${REPO_SLUG%%/*}"
REPO_NAME="${REPO_SLUG#*/}"
note "Published! Site will be live shortly at: https://${OWNER}.github.io/${REPO_NAME}/"
