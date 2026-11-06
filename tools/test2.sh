#!/usr/bin/env bash
# Two local instances (host coopA left, guest coopB right) under the playtime guard.
# usage: tools/test2.sh <minutes> "<note>" [extra host args] [extra guest args]
set -euo pipefail
source "$(dirname "$0")/env.sh"
MIN=$1; NOTE=$2; HX=${3:-}; GX=${4:-}
rm -f "$LOCALAPPDATA"/ZERO_Sievert/coop_*.log
BASE="-no_gpu_pref -coop_slot 1"
python "$ROOT/tools/game_guard.py" run --max-minutes "$MIN" --note "$NOTE" \
  --launch "$BASE -coop_root coopA -coop_host -coop_window $WIN_A $HX" \
  --launch "$BASE -coop_root coopB -coop_join 127.0.0.1 -coop_window $WIN_B $GX"
