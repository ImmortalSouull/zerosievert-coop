#!/usr/bin/env bash
# Every scenario in the order of the session size: 1 player, 2, 3 ... 8 (user's rule 2026-11-08).
#   1: single player with the mod;  2: every two-player scenario and every map;
#   3..8: the native group scenarios for that size (quadN/handoffN, the three-player ones) plus every two- and
#   three-player scenario again with extra players ("name@N", scenario bystand) so each feature runs in a full session.
# usage: bash tools/regress_players.sh [from N, default 1] [to N, default 8]
# Each phase prints its own summary; logs are in work/regress/<timestamp>/.
source "$(dirname "$0")/env.sh"
cd "$ROOT"
FROM=${1:-1}
TO=${2:-8}
P=(python tools/regress.py)
list() { python tools/regress.py --players "$1" | tr -d '\r'; }
TWO=$(for s in $(list 2); do case "$s" in map[0-9]*_*|aiguest[0-9]*_*) ;; *) echo "$s";; esac; done)
THREE=$(list 3)
for ((n = FROM; n <= TO; n++)); do
  echo "######## $n PLAYER(S)"
  case $n in
    1) "${P[@]}" $(list 1) ;;
    2) "${P[@]}" $(list 2) ;;
    *)
      NATIVE="quad$n handoff$n"
      [ "$n" = 3 ] && NATIVE="$THREE"
      [ "$n" = 4 ] && NATIVE="quad handoff"
      [ "$n" = 8 ] && NATIVE="octo handoff8"
      VAR=""
      for s in $TWO; do VAR="$VAR $s@$n"; done
      if [ "$n" -gt 3 ]; then for s in $THREE; do VAR="$VAR $s@$n"; done; fi
      "${P[@]}" $NATIVE $VAR ;;
  esac
done
echo "######## PLAYERS RUN FINISHED"
