#!/usr/bin/env bash
# Screenshot every game window (scaled copies end in _small.png). usage: tools/shots.sh [prefix] [scale]
source "$(dirname "$0")/env.sh"
W=$WORK/shots; mkdir -p "$W"; rm -f "$W"/r_${1:-}*
for p in $(tasklist | grep -i "zero sievert" | awk '{print $3}'); do
  powershell -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$ROOT/tools/winshot.ps1")" "$p" "$(cygpath -w "$W")\\r_${1:-}$p.png" "${2:-0.5}" &
done; wait; ls "$W" | grep small
