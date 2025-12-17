#!/bin/bash -ex
moon update && moon install && rm -rf target
moon add moonbitlang/async
moon add moonbitlang/x
moon add TheWaWaR/clap
moon add gmlewis/fonts
pushd examples/03-engraved-name-tag/ && moon update && moon install && rm -rf target && popd
./test-all.sh
