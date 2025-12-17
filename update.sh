#!/bin/bash -ex
moon update && moon install && rm -rf target .mooncakes
moon add moonbitlang/async
moon add moonbitlang/x
moon add TheWaWaR/clap
moon add gmlewis/fonts
pushd examples/03-engraved-name-tag/ \
    && moon update \
    && moon install \
    && rm -rf target .mooncakes \
    && moon add moonbitlang/async \
    && moon add moonbitlang/x \
    && moon add TheWaWaR/clap \
    && moon add gmlewis/fonts \
    && moon add gmlewis/fonts-b \
    && popd
./test-all.sh
