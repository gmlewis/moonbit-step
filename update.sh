#!/bin/bash -ex
find . -depth -name target -type d -exec rm -rf {} \;
find . -depth -name .mooncakes -type d -exec rm -rf {} \;
moon add --no-update moonbitlang/async
moon add --no-update moonbitlang/x
moon add --no-update TheWaWaR/clap
moon add --no-update gmlewis/fonts
./scripts/sync-fonts-versions.py
DIRS_NEEDING_UPDATE=$(find examples -name target -prune -o -name .mooncakes -prune -o -type f -name "moon.mod.json" -exec dirname {} \;)
for dir in $DIRS_NEEDING_UPDATE; do
  pushd "$dir"
  ./update.sh
  popd
done
moon update
moon install
./test-all.sh
