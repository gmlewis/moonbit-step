#!/bin/bash -ex
rm -rf ./{_build,.mooncakes} \
    examples/*/{_build,.mooncakes}
moon add --no-update moonbitlang/async
moon add --no-update moonbitlang/x
moon add --no-update TheWaWaR/clap
moon add --no-update gmlewis/fonts
moon update
./test-all.sh
