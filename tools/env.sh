#!/usr/bin/env bash
# Shared paths for the tools (sourced by the other scripts). Nothing is tied to a user name:
#   ROOT = this repo, WORK = ../zerosievert-coop-work next to it, G = game folder (override with ZS_GAME_DIR).
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WORK=$(dirname "$ROOT")/zerosievert-coop-work
G=${ZS_GAME_DIR:-"/c/Program Files (x86)/Steam/steamapps/common/ZERO Sievert"}
CLI=$WORK/tools/utmt_cli/UndertaleModCli.exe
XDELTA=$WORK/tools/xdelta/xdelta3-3.1.0-x86_64.exe
# Prefer a real Python over the Microsoft Store alias (python.exe in WindowsApps only opens the Store).
for _p in "$LOCALAPPDATA"/Programs/Python/Python3*/; do
  [ -x "$_p/python.exe" ] && PATH="$(cygpath -u "$_p"):$PATH"
done
export ROOT WORK G CLI XDELTA PATH
