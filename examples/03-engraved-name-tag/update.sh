#!/bin/bash -ex
moon add moonbitlang/async
moon add moonbitlang/x
moon add TheWaWaR/clap
moon add gmlewis/fonts
moon add gmlewis/fonts-b
moon update && moon install
moon check --target native
