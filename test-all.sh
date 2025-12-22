#!/bin/bash -ex
export NEW_MOON=1
moon fmt
moon info --target native
moon test --target native

# Test subdirs that have their own moon.mod.json
DIRS_NEEDING_TESTING=$(find examples -name target -prune -o -name .mooncakes -prune -o -type f -name "moon.mod.json" -exec dirname {} \;)
for dir in $DIRS_NEEDING_TESTING; do
	pushd "$dir" \
		&& moon fmt \
		&& moon info --target native \
		&& moon test --target native \
		&& popd
done
