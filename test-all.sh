#!/bin/bash -ex
export NEW_MOON=1
moon fmt
moon info --target native
moon test --target native

# Test subdirs that have their own moon.mod.json
for dir in examples/03-engraved-name-tag examples/05-gridfinity-compatible-bin examples/07-cable-label-clip; do
	pushd "$dir" \
		&& moon fmt \
		&& moon info --target native \
		&& moon test --target native \
		&& popd
done
