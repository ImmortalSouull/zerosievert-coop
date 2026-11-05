#!/usr/bin/env bash
# Put the built co-op data.win into the game folder for a test run (vanilla copy stays in work/vanilla).
set -euo pipefail
source "$(dirname "$0")/env.sh"
cp "$WORK/build/data.win" "$G/data.win"
sha256sum "$G/data.win" | cut -c1-16
