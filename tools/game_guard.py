"""Playtime guard: every game launch goes through here so Steam playtime stays under budget.

The owner must stay refund-eligible on Steam (< 2 h playtime), so agent testing gets a hard cap
well below that. Each run is recorded in playtime_ledger.json *before* the game starts, and the
process tree is killed at the deadline even if nobody is watching.

  python tools/game_guard.py status
  python tools/game_guard.py run --max-minutes 5 --note "net skeleton test" -- "<exe>" [args...]
"""
import argparse
import datetime as dt
import json
import math
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LEDGER = ROOT / "playtime_ledger.json"
CAP_MINUTES = 60          # agent budget; the rest of the 2 h is left for the owner's own playtests
APP_ID = "1782120"
STEAM_LOCALCONFIG = Path(r"C:\Program Files (x86)\Steam\userdata\976250676\config\localconfig.vdf")
EXE_NAME = "ZERO Sievert.exe"


def load():
    if LEDGER.exists():
        return json.loads(LEDGER.read_text(encoding="utf-8"))
    return {"cap_minutes": CAP_MINUTES, "sessions": []}


def save(led):
    LEDGER.write_text(json.dumps(led, indent=2, ensure_ascii=False), encoding="utf-8")


def used_minutes(led, now=None):
    """Wall-clock union of all sessions (Steam counts overlapping instances once), rounded up."""
    now = now or time.time()
    spans = sorted((s["start"], s.get("end") or min(now, s["deadline"])) for s in led["sessions"])
    total, cur_s, cur_e = 0.0, None, None
    for s, e in spans:
        if cur_e is None or s > cur_e:
            if cur_e is not None:
                total += cur_e - cur_s
            cur_s, cur_e = s, e
        else:
            cur_e = max(cur_e, e)
    if cur_e is not None:
        total += cur_e - cur_s
    return math.ceil(total / 60)


def steam_playtime():
    """Minutes Steam has recorded locally for the app (None = no Playtime key yet)."""
    try:
        text = STEAM_LOCALCONFIG.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return "unreadable"
    m = re.search(r'"%s"\s*\{(.*?)\n\t{5}\}' % APP_ID, text, re.S)
    if not m:
        return None
    p = re.search(r'"Playtime"\s+"(\d+)"', m.group(1))
    return int(p.group(1)) if p else None


def running_game_pids():
    out = subprocess.run(["tasklist", "/FI", f"IMAGENAME eq {EXE_NAME}", "/FO", "CSV", "/NH"],
                         capture_output=True, text=True).stdout
    return [int(line.split('","')[1]) for line in out.splitlines() if line.startswith(f'"{EXE_NAME}"')]


def cmd_status(_):
    led = load()
    used = used_minutes(led)
    print(f"agent budget: {used}/{led['cap_minutes']} min used, {led['cap_minutes'] - used} left")
    print(f"steam local playtime: {steam_playtime()} min")
    print(f"running game pids: {running_game_pids()}")


def cmd_run(a):
    led = load()
    used = used_minutes(led)
    left = led["cap_minutes"] - used
    if a.max_minutes > left:
        sys.exit(f"REFUSED: run needs {a.max_minutes} min, only {left} min of budget left")
    if running_game_pids() and not a.allow_concurrent:
        sys.exit(f"REFUSED: game already running {running_game_pids()}")
    start = time.time()
    session = {"start": start, "deadline": start + a.max_minutes * 60, "end": None,
               "note": a.note, "started": dt.datetime.now().isoformat(timespec="seconds")}
    led["sessions"].append(session)
    save(led)  # recorded before launch: a crash of this script still counts the time
    cmd = a.command[1:] if a.command and a.command[0] == "--" else a.command
    proc = subprocess.Popen(cmd, cwd=a.cwd or str(Path(cmd[0]).parent))
    print(f"launched pid {proc.pid}, hard stop in {a.max_minutes} min", flush=True)
    try:
        proc.wait(timeout=a.max_minutes * 60)
        reason = f"exited code {proc.returncode}"
    except subprocess.TimeoutExpired:
        subprocess.run(["taskkill", "/PID", str(proc.pid), "/T", "/F"], capture_output=True)
        reason = "killed at deadline"
    session["end"] = time.time()
    session["minutes"] = round((session["end"] - start) / 60, 2)
    session["result"] = reason
    save(led)
    print(f"{reason}; session {session['minutes']} min; budget used {used_minutes(led)}/{led['cap_minutes']}")


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("status").set_defaults(fn=cmd_status)
    r = sub.add_parser("run")
    r.add_argument("--max-minutes", type=float, required=True)
    r.add_argument("--note", default="")
    r.add_argument("--cwd")
    r.add_argument("--allow-concurrent", action="store_true")
    r.add_argument("command", nargs=argparse.REMAINDER)
    r.set_defaults(fn=cmd_run)
    a = p.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
