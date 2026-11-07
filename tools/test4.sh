#!/usr/bin/env bash
# 3 to 8 local instances: host coopA + guests coopB..coopH (UDP 127.0.0.1).
# Up to 4: windows in a 2x2 grid; 5 to 8: a 4x2 grid of smaller windows (each instance takes ~2.4 GB of RAM).
# usage: tools/test4.sh <minutes> "<note>" [host args] [guest args (all guests)] [guest D args]
# env COOP_PLAYERS=3..8 (default 4); COOP_BYSTAND_FROM/COOP_BYSTAND_ARGS give the last windows other args.
set -euo pipefail
source "$(dirname "$0")/env.sh"
MIN=$1; NOTE=$2; HX=${3:-}; GX=${4:-}; DX=${5:-$GX}
N=${COOP_PLAYERS:-4}
rm -f "$LOCALAPPDATA"/ZERO_Sievert/coop_*.log
BASE="-no_gpu_pref -coop_slot 1"
LETTERS=(A B C D E F G H)
if [ "$N" -le 4 ]; then
  WINS=("$WIN_A" "$WIN_B" "$WIN_C" "$WIN_D")
else
  WINS=("${ZS_WIN8_A:-620,8,700,394}" "${ZS_WIN8_B:-1325,8,700,394}" "${ZS_WIN8_C:-2030,8,700,394}" "${ZS_WIN8_D:-2735,8,700,394}"
        "${ZS_WIN8_E:-620,430,700,394}" "${ZS_WIN8_F:-1325,430,700,394}" "${ZS_WIN8_G:-2030,430,700,394}" "${ZS_WIN8_H:-2735,430,700,394}")
fi
ARGS=(--launch "$BASE -coop_root coopA -coop_host -coop_expect $N -coop_window ${WINS[0]} $HX")
for ((i = 1; i < N; i++)); do
  L=${LETTERS[$i]}
  X="$GX"; [ "$L" = "D" ] && X="$DX"
  # extra players of a "name@N" regress run (env COOP_BYSTAND_FROM = first bystander index, COOP_BYSTAND_ARGS)
  if [ -n "${COOP_BYSTAND_FROM:-}" ] && [ "$i" -ge "$COOP_BYSTAND_FROM" ]; then X="${COOP_BYSTAND_ARGS:-}"; fi
  ARGS+=(--launch "$BASE -coop_root coop$L -coop_join 127.0.0.1 -coop_window ${WINS[$i]} $X")
done
python "$ROOT/tools/game_guard.py" run --max-minutes "$MIN" --note "$NOTE" --stagger 2 "${ARGS[@]}"
