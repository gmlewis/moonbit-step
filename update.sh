#!/bin/bash -ex
moon update && moon install && rm -rf target
moon add moonbitlang/async
moon add moonbitlang/x
moon add TheWaWaR/clap
moon add gmlewis/fonts
./test-all.sh
