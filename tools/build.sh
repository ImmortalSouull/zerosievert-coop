#!/usr/bin/env bash
# Build the co-op data.win from the pristine copy. Output: zerosievert-coop-work/build/data.win
set -euo pipefail
WORK=/c/Users/pasha/zerosievert-coop-work
CLI=$WORK/tools/utmt_cli/UndertaleModCli.exe
mkdir -p "$WORK/build"
# stdin must be closed or the CLI waits for interactive input
"$CLI" load "$WORK/vanilla/data.win" -s 'C:\Users\pasha\zerosievert-coop\tools\utmt\build.csx' -o "$WORK/build/data.win" -f < /dev/null 2>&1 | tee "$WORK/build/build.log" | tail -25
grep -q "COOP BUILD OK" "$WORK/build/build.log"
ls -la "$WORK/build/data.win"
