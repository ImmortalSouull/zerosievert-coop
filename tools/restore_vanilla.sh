#!/usr/bin/env bash
# Put the game folder back exactly as Steam installed it.
set -euo pipefail
source "$(dirname "$0")/env.sh"
cp "$WORK/vanilla/data.win" "$G/data.win"
rm -f "$G/steam_appid.txt"
H=$(sha256sum "$G/data.win" | cut -d' ' -f1)
V=$(sha256sum "$WORK/vanilla/data.win" | cut -d' ' -f1)
[ "$H" = "$V" ] && echo "vanilla restored OK ($H)" || { echo "HASH MISMATCH $H"; exit 1; }
