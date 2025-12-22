#!/bin/bash -ex
find . -depth -name target -type d -exec rm -rf {} \;
find . -depth -name .mooncakes -type d -exec rm -rf {} \;
moon add moonbitlang/async
moon add moonbitlang/x
moon add TheWaWaR/clap
moon add gmlewis/fonts
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
