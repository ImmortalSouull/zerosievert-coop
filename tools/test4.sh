#!/usr/bin/env bash
# Three or four local instances: host coopA + guests coopB/coopC[/coopD] (UDP 127.0.0.1), windows in a 2x2 grid.
# usage: tools/test4.sh <minutes> "<note>" [host args] [guest args (all guests)] [guest D args]
# env COOP_PLAYERS=3 runs without coopD (each instance takes ~2.4 GB of RAM).
set -euo pipefail
MIN=$1; NOTE=$2; HX=${3:-}; GX=${4:-}; DX=${5:-$GX}
N=${COOP_PLAYERS:-4}
rm -f "$LOCALAPPDATA"/ZERO_Sievert/coop_*.log
BASE="-no_gpu_pref -coop_slot 1"
ARGS=(--launch "$BASE -coop_root coopA -coop_host -coop_expect $N -coop_window 0,30,1280,700 $HX"
      --launch "$BASE -coop_root coopB -coop_join 127.0.0.1 -coop_window 1290,30,1280,700 $GX"
      --launch "$BASE -coop_root coopC -coop_join 127.0.0.1 -coop_window 0,740,1280,700 $GX")
if [ "$N" -ge 4 ]; then
  ARGS+=(--launch "$BASE -coop_root coopD -coop_join 127.0.0.1 -coop_window 1290,740,1280,700 $DX")
fi
python /c/Users/pasha/zerosievert-coop/tools/game_guard.py run --max-minutes "$MIN" --note "$NOTE" --stagger 2 "${ARGS[@]}"
