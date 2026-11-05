#!/usr/bin/env bash
# Build the co-op data.win from the pristine copy. Output: zerosievert-coop-work/build/data.win
set -euo pipefail
source "$(dirname "$0")/env.sh"
mkdir -p "$WORK/build"
# texts of the mod in every game language: mod/lang/strings.tsv -> mod/gml/gml_GlobalScript_coop_lang.gml
python "$ROOT/tools/make_lang.py"
# stdin must be closed or the CLI waits for interactive input
COOP_ROOT=$(cygpath -w "$ROOT") "$CLI" load "$WORK/vanilla/data.win" -s "$(cygpath -w "$ROOT/tools/utmt/build.csx")" -o "$WORK/build/data.win" -f < /dev/null 2>&1 | tee "$WORK/build/build.log" | tail -25
grep -q "COOP BUILD OK" "$WORK/build/build.log"
ls -la "$WORK/build/data.win"
