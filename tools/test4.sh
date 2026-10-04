#!/usr/bin/env bash
# Four local instances: host coopA + guests coopB/coopC/coopD (UDP 127.0.0.1), windows in a 2x2 grid.
# usage: tools/test4.sh <minutes> "<note>" [host args] [guest args (all guests)] [guest D args]
set -euo pipefail
MIN=$1; NOTE=$2; HX=${3:-}; GX=${4:-}; DX=${5:-$GX}
rm -f "$LOCALAPPDATA"/ZERO_Sievert/coop_*.log
BASE="-no_gpu_pref -coop_slot 1"
python /c/Users/pasha/zerosievert-coop/tools/game_guard.py run --max-minutes "$MIN" --note "$NOTE" --stagger 2 \
  --launch "$BASE -coop_root coopA -coop_host -coop_window 0,30,1280,700 $HX" \
  --launch "$BASE -coop_root coopB -coop_join 127.0.0.1 -coop_window 1290,30,1280,700 $GX" \
  --launch "$BASE -coop_root coopC -coop_join 127.0.0.1 -coop_window 0,740,1280,700 $GX" \
  --launch "$BASE -coop_root coopD -coop_join 127.0.0.1 -coop_window 1290,740,1280,700 $DX"
