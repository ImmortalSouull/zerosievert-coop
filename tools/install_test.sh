#!/usr/bin/env bash
# Put the built co-op data.win into the game folder for a test run (vanilla copy stays in work/vanilla).
set -euo pipefail
G="/c/Program Files (x86)/Steam/steamapps/common/ZERO Sievert"
WORK=/c/Users/pasha/zerosievert-coop-work
cp "$WORK/build/data.win" "$G/data.win"
sha256sum "$G/data.win" | cut -c1-16
