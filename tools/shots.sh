#!/usr/bin/env bash
# Screenshot every game window (scaled copies end in _small.png).
W=/c/Users/pasha/zerosievert-coop-work/shots; rm -f $W/r_${1:-}*
for p in $(tasklist | grep -i "zero sievert" | awk '{print $3}'); do
  h=$(powershell -NoProfile -Command "(Get-Process -Id $p).MainWindowHandle")
  um win shot --hwnd $h "$(cygpath -w $W)\r_${1:-}$p.png" --scale ${2:-0.5} > /dev/null 2>&1 &
done; wait; ls $W | grep small
