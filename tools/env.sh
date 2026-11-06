#!/usr/bin/env bash
# Shared paths for the tools (sourced by the other scripts). Nothing is tied to a user name:
#   ROOT = this repo, WORK = ../zerosievert-coop-work next to it, G = game folder (override with ZS_GAME_DIR).
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WORK=$(dirname "$ROOT")/zerosievert-coop-work
G=${ZS_GAME_DIR:-"/c/Program Files (x86)/Steam/steamapps/common/ZERO Sievert"}
CLI=$WORK/tools/utmt_cli/UndertaleModCli.exe
# (not XDELTA: xdelta3 reads an XDELTA environment variable as extra command-line options)
XDELTA_EXE=$WORK/tools/xdelta/xdelta3-3.1.0-x86_64.exe
# Prefer a real Python over the Microsoft Store alias (python.exe in WindowsApps only opens the Store).
for _p in "$LOCALAPPDATA"/Programs/Python/Python3*/; do
  [ -x "$_p/python.exe" ] && PATH="$(cygpath -u "$_p"):$PATH"
done
export ROOT WORK G CLI XDELTA_EXE PATH
# Keep the Claude window above the game windows (the user watches the tests). ZS_NO_ONTOP=1 skips it.
claude_on_top() {
  [ -n "${ZS_NO_ONTOP:-}" ] || powershell -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$ROOT/tools/claude_on_top.ps1")" > /dev/null 2>&1 || true
}

# Test windows (x,y,w,h): a 2x2 grid right of the Claude window (which keeps x < 615 free).
# Tuned for 3440x1440; override with ZS_WIN_A..ZS_WIN_D.
WIN_A="${ZS_WIN_A:-830,8,1180,664}"
WIN_B="${ZS_WIN_B:-2030,8,1180,664}"
WIN_C="${ZS_WIN_C:-830,700,1180,664}"
WIN_D="${ZS_WIN_D:-2030,700,1180,664}"
