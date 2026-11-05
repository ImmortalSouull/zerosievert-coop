#!/usr/bin/env bash
# After a game update: refresh work/vanilla from the game folder, decompile it and check mod/hooks.txt.
# usage: tools/decompile.sh [--refresh]   (--refresh copies the game's current data.win into work/vanilla first;
#                                          only do that while the game folder holds an untouched Steam install)
set -euo pipefail
source "$(dirname "$0")/env.sh"
if [ "${1:-}" = "--refresh" ]; then
  mkdir -p "$WORK/vanilla"
  cp "$G/data.win" "$G/options.ini" "$G/gamedata_order.json" "$WORK/vanilla/"
  B=$(grep -h '"buildid"' "$G/../../appmanifest_1782120.acf" 2>/dev/null | tr -dc '0-9')
  echo "Steam build ${B:-unknown}" > "$WORK/vanilla/game_version.txt"
fi
sha256sum "$WORK/vanilla/data.win"
rm -rf "$WORK/decomp/CodeEntries"; mkdir -p "$WORK/decomp/CodeEntries"
COOP_DECOMP=$(cygpath -w "$WORK/decomp/CodeEntries") "$CLI" load "$WORK/vanilla/data.win" -s "$(cygpath -w "$ROOT/tools/utmt/decompile.csx")" < /dev/null 2>&1 | tail -3
python "$ROOT/tools/check_hooks.py"
