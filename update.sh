#!/bin/bash -ex
find . -depth -name target -type d -exec rm -rf {} \;
find . -depth -name .mooncakes -type d -exec rm -rf {} \;
moon add moonbitlang/async
moon add moonbitlang/x
moon add TheWaWaR/clap
moon add gmlewis/fonts
pushd examples/03-engraved-name-tag/ && ./update.sh && popd
moon update
moon install
./test-all.sh
