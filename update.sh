#!/bin/bash
set -euo pipefail

# Configuration - use available CPUs
MAX_JOBS=${MAX_JOBS:-4}

# Fast update: only update registry once at the start
echo "Updating registry..."
moon update || true

# Clean build artifacts quickly
echo "Cleaning build artifacts..."
find . -type d \( -name .mooncakes -o -name _build \) -not -path './.git/*' -exec rm -rf {} + 2>/dev/null || true

# Root package setup
echo "Setting up root package..."
moon add --no-update moonbitlang/async || true
moon add --no-update moonbitlang/x || true
moon add --no-update TheWaWaR/clap || true
moon add --no-update gmlewis/fonts || true

moon fmt || true
moon info --target native || true

# Run tests
echo "Running tests..."
./test-all.sh

# Collect all sub-package update scripts (excluding root)
scripts=()
while IFS= read -r line; do
    scripts+=("$line")
done < <(find . -type d \( -name .mooncakes -o -name _build \) -prune -o -type f -name update.sh -print 2>/dev/null | grep -v '^\./update\.sh$' | sort)

total=${#scripts[@]}
if [[ $total -eq 0 ]]; then
    echo "No sub-package update scripts found."
    exit 0
fi

echo "Processing ${total} sub-packages with ${MAX_JOBS} parallel jobs..."

# Process sub-packages in parallel
pids=()
for script in "${scripts[@]}"; do
    script_dir="${script%/*}"
    pkg_name="${script_dir#./}"
    
    (
        cd "$script_dir"
        if ./update.sh >/dev/null 2>&1; then
            echo "✓ ${pkg_name}"
        else
            echo "✗ ${pkg_name} FAILED" >&2
            exit 1
        fi
    ) &
    pids+=($!)
    
    # Limit concurrent jobs
    while [[ ${#pids[@]} -ge $MAX_JOBS ]]; do
        new_pids=()
        for pid in "${pids[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                new_pids+=("$pid")
            else
                wait "$pid" || true
            fi
        done
        pids=("${new_pids[@]}")
        [[ ${#pids[@]} -ge $MAX_JOBS ]] && sleep 0.1
    done
done

# Wait for all remaining jobs
for pid in "${pids[@]}"; do
    wait "$pid" || exit 1
done

echo "Completed ${total} sub-package updates."
