#!/usr/bin/env bash
# Tail both co-op logs.
for f in "$LOCALAPPDATA"/ZERO_Sievert/coop_*.log; do echo "== $(basename "$f")"; tail -n "${1:-25}" "$f"; done
tasklist | grep -i "zero sievert" || echo "(no game running)"
