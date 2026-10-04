"""Long co-op session (4 players, scenario soak) with memory sampling.

usage: python tools/soak.py <minutes> [extra args for every launch, e.g. "-coop_netsim 100,2,30"]
Prints memory growth per process, errors, NPC desync repairs and crashes. The data.win under test must be
installed (tools/install_test.sh). Logs are kept in zerosievert-coop-work/soak/<timestamp>/.
"""
import os, re, sys, time, shutil, subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK = os.path.join(os.path.dirname(ROOT), "zerosievert-coop-work")
SAVES = os.path.join(os.environ["LOCALAPPDATA"], "ZERO_Sievert")
BASH = r"C:\Program Files\Git\bin\bash.exe"


def mem():
    """{pid: private MB} of the running game processes."""
    out = subprocess.run(["powershell", "-NoProfile", "-Command",
                          "Get-Process 'ZERO Sievert' -ErrorAction SilentlyContinue | ForEach-Object { \"$($_.Id) $([math]::Round($_.PrivateMemorySize64/1MB))\" }"],
                         capture_output=True, text=True).stdout
    res = {}
    for line in out.split():
        pass
    for line in out.strip().splitlines():
        p = line.split()
        if len(p) == 2:
            res[int(p[0])] = int(p[1])
    return res


def main():
    minutes = float(sys.argv[1]) if len(sys.argv) > 1 else 20
    extra = sys.argv[2] if len(sys.argv) > 2 else ""
    subprocess.run([sys.executable, os.path.join(ROOT, "tools", "game_guard.py"), "stop"], capture_output=True)
    cmd = (f'bash tools/test4.sh {int(minutes) + 3} "soak" "-coop_autoraid 1 -coop_scenario soak -coop_fps 60 {extra}" '
           f'"-coop_scenario soak -coop_fps 60 {extra}"')
    proc = subprocess.Popen([BASH, "-c", cmd], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    t0 = time.time()
    samples = []
    crashed = False
    while time.time() - t0 < (minutes + 1.5) * 60:
        time.sleep(60)
        m = mem()
        samples.append((round((time.time() - t0) / 60, 1), m))
        print(f"{samples[-1][0]:5} min  " + "  ".join(f"{pid}:{mb}MB" for pid, mb in sorted(m.items())), flush=True)
        logs = "".join(open(os.path.join(SAVES, f"coop_coop{k}.log"), encoding="utf-8", errors="replace").read()
                       for k in "ABCD" if os.path.exists(os.path.join(SAVES, f"coop_coop{k}.log")))
        if "CRASH" in logs or len(m) < 4:
            crashed = True
            print("!! crash or a game process is gone", flush=True)
            break
    subprocess.run([sys.executable, os.path.join(ROOT, "tools", "game_guard.py"), "stop"], capture_output=True)
    proc.wait(timeout=60)
    out = os.path.join(WORK, "soak", time.strftime("%Y%m%d-%H%M%S"))
    os.makedirs(out, exist_ok=True)
    report = []
    for k in "ABCD":
        p = os.path.join(SAVES, f"coop_coop{k}.log")
        if not os.path.exists(p):
            report.append(f"{k}: no log")
            continue
        shutil.copy(p, out)
        text = open(p, encoding="utf-8", errors="replace").read()
        errs = [l for l in text.splitlines() if "ERROR" in l or "CRASH" in l]
        desync = len(re.findall(r"NPC DESYNC", text))
        checks = len(re.findall(r"npc check ok", text))
        mins = re.findall(r"soak: minute (\d+)", text)
        mism = len(re.findall(r"MAP MISMATCH", text))
        report.append(f"{k}: minutes={mins[-1] if mins else 0} errors={len(errs)} desync_fixes={desync} checks_ok={checks} map_mismatch={mism}")
        for l in errs[:3]:
            report.append("    " + l[:200])
    if len(samples) >= 2:
        first, last = samples[0][1], samples[-1][1]
        for pid in sorted(last):
            if pid in first:
                report.append(f"pid {pid}: {first[pid]} MB -> {last[pid]} MB ({last[pid] - first[pid]:+d} MB over {samples[-1][0] - samples[0][0]:.0f} min)")
    report.append("CRASH" if crashed else "no crash")
    print("\n".join(report))
    open(os.path.join(out, "report.txt"), "w", encoding="utf-8").write("\n".join(report))
    return 1 if crashed else 0


if __name__ == "__main__":
    sys.exit(main())
