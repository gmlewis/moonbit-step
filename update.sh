#!/bin/bash -ex
find . -depth -name target -type d -exec rm -rf {} \;
find . -depth -name .mooncakes -type d -exec rm -rf {} \;
moon add --no-update moonbitlang/async
moon add --no-update moonbitlang/x
moon add --no-update TheWaWaR/clap
moon add --no-update gmlewis/fonts
moon update
moon install
./test-all.sh
