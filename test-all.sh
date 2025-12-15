#!/bin/bash -ex
# export NEW_MOON=0
moon fmt
moon info --target native
moon test --target native

# Test subdirs that have their own moon.mod.json
pushd examples/03-engraved-name-tag \
	&& moon fmt \
	&& moon info --target native \
	&& moon test --target native \
	&& popd
