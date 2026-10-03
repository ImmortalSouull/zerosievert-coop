#!/usr/bin/env bash
# Put the game folder back exactly as Steam installed it.
set -euo pipefail
G="/c/Program Files (x86)/Steam/steamapps/common/ZERO Sievert"
WORK=/c/Users/pasha/zerosievert-coop-work
cp "$WORK/vanilla/data.win" "$G/data.win"
rm -f "$G/steam_appid.txt"
H=$(sha256sum "$G/data.win" | cut -d' ' -f1)
[ "$H" = "1c4f2cd1db84cc7b6178ae410639c593cfc50edf6fc9f7548c348fbeb3824d8f" ] && echo "vanilla restored OK" || { echo "HASH MISMATCH $H"; exit 1; }
