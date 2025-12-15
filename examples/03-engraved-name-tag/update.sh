#!/bin/bash -ex
moon update && moon install && rm -rf target
moon add moonbitlang/async
moon add moonbitlang/x
moon add TheWaWaR/clap
moon add gmlewis/fonts
moon add gmlewis/fonts-b
moon test --target native
