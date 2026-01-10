#!/bin/bash -ex
moon add --no-update moonbitlang/async
moon add --no-update moonbitlang/x
moon add --no-update TheWaWaR/clap
moon add --no-update gmlewis/fonts
moon install
moon check --target native
