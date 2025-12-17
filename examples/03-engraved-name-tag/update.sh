#!/bin/bash -ex
find . -depth -name target -type d -exec rm -rf {} \;
find . -depth -name .mooncakes -type d -exec rm -rf {} \;
sed -i '/moonbitlang\/async/d' moon.mod.json
sed -i '/moonbitlang\/x/d' moon.mod.json
sed -i '/TheWaWaR\/clap/d' moon.mod.json
sed -i '/gmlewis\/fonts/d' moon.mod.json
sed -i '/gmlewis\/fonts-b/d' moon.mod.json
moon add moonbitlang/async
moon add moonbitlang/x
moon add TheWaWaR/clap
moon add gmlewis/fonts
moon add gmlewis/fonts-b
moon update && moon install
moon test --target native
