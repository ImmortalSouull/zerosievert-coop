# ZERO Sievert CO-OP mod — project guide for Claude

Talk to the user in Russian. The user (pasha) playtests with a friend (Steam name "Ondrey") and may ask
you to send Steam invites to him for live tests — that is allowed. No Steam playtime limit anymore.

## Read first
- `MODLOG.md` — full journal: every engine fact, gotcha, decision and test result. Read it before changing code.
- Current release: **v0.4.0**, network protocol `COOP_VERSION 4` (both players must match).

## Layout
- `mod/gml/*.gml` — all mod code (GML). `gml_GlobalScript_coop_*` = modules, `gml_Object_obj_coop_*` = controller events.
- `mod/hooks.txt` — patches into the game's own code (`### findreplace|prepend|append <code entry>`).
  NEVER `append` to a `gml_GlobalScript_*` (code lands outside the function) — use findreplace.
- `mod/ui/` — text inserted into the game's .ui / language files by the installer.
- `dist_src/` — installer.ps1, README.txt (Russian, for players), THIRD_PARTY.txt.
- `tools/` — build/test/release scripts (below). `tools/utmt/build.csx` = UTMT build script.
- Outside the repo (never commit game data): `C:\Users\pasha\zerosievert-coop-work\`
  - `vanilla/data.win` pristine copy (sha256 1c4f2cd1...), `decomp/CodeEntries/` decompiled game GML
  - `tools/utmt_cli/` UndertaleModCli 0.9.2.0, `tools/xdelta/`, `build/`, `dist/`, `caps/` (videos)
- Game: `C:\Program Files (x86)\Steam\steamapps\common\ZERO Sievert` (GameMaker 2024.14, VM, data.win).

## Commands (Git Bash)
- Build: `bash tools/build.sh` → `zerosievert-coop-work/build/data.win` (check "COOP BUILD OK").
- Quick test install (data.win only): `bash tools/install_test.sh`.
- Release: `bash tools/make_dist.sh <ver>` then run `dist/ZS-Coop-v<ver>/installer.ps1 install`
  (`powershell -NoProfile -ExecutionPolicy Bypass -File ...`). Copy the zip into the repo root for the user.
- Two-instance local test (host coopA left, guest coopB right, UDP 127.0.0.1):
  `bash tools/test2.sh <minutes> "<note>" "<host args>" "<guest args>"`, e.g.
  `bash tools/test2.sh 3 "x" "-coop_autoraid 1 -coop_scenario livechest" "-coop_scenario livechest"`.
  Then `bash tools/wait.sh "<regex>|CRASH" <sec>`, `bash tools/logs.sh`, `bash tools/shots.sh <prefix>`,
  and ALWAYS `python tools/game_guard.py stop` at the end. Every game launch goes through `tools/game_guard.py`.
- Logs: `%LOCALAPPDATA%\ZERO_Sievert\coop_<tag>.log` (tag coopA/coopB in tests, `solo` in normal play).
  In-game screenshots: `screen_save()` from GML → same folder.
- Test scenarios (test mode only, see coop_raid/coop_tests/coop_show): revive, both, chest, livechest, v3,
  join, show, panel, difficulty, steamhost, fps (walk speed at -coop_fps N), anim (partner animations/torch/
  sounds), tele (long-teleport stress), leave (host extracts). ALWAYS `game_guard.py stop` before test2.sh.
- Debug: `-coop_prof` (subsystem us/s every 5 s), `-coop_trace`; freeze hunting: build with
  `COOP_TRACE_EVENTS='<regex of code entries>' bash tools/build.sh`, run with `-coop_phase`, then
  `python tools/peek.py <pid> <addr from log>` shows the game event a frozen process is stuck in. Test save roots `coopA`/`coopB` (copies of an old save, Russian UI,
  coopB has grass 0.25 + low spec to catch determinism bugs). The user's real saves are never touched.

## GitHub (private repo https://github.com/ImmortalSouull/zerosievert-coop)
- gh CLI: `"/c/Program Files/GitHub CLI/gh.exe"` (logged in as ImmortalSouull). Ask the user before publishing.
- Every release: write `docs/releases/v<ver>.md` in Russian AND English (title "RU / EN", a
  "**Русский** · [English](#english)" line, Russian part, then `<a name="english"></a>` + full English
  translation incl. install steps; README.md and dist_src/README.txt are bilingual too): what's new, "Исправлено (относительно v<prev>)",
  "Известные баги" — carry over the previous list, move fixed bugs into "Исправлено", add newly found ones.
  Also update the bug list of the previous release notes if a bug is found later. Then tag the release commit,
  `git push origin main --tags`, and `gh release create v<ver> <zip> README_v<ver>.md --title "<first line>"
  --notes-file docs/releases/v<ver>.md --latest` (README_v<ver>.md = copy of the notes). Update README.md
  "Текущая версия". Run `um publish check . --game "<game dir>"` and on the dist folder first (no game files).

## Hard-won rules (details in MODLOG)
- UTMT CLI needs stdin closed (`< /dev/null`); `#macro` is expanded by build.csx; `async_load[? k]` miscompiles
  (use ds_map_find_value); extension functions the game never calls must be declared (build.csx does it);
  `until` is reserved; depth must be within ±16000; no raw newlines in GML strings (use chr(10)).
- Launch needs env SteamAppId/SteamGameId + `-no_gpu_pref` (guard handles it).
- The game deactivates instances outside the camera and on pause — keep obj_coop alive (coop_ensure_alive).
- With a player on the map the OS mouse is locked; use obj_cursor (virtual cursor) for GUI hit tests.
- Shared maps rely on re-seeding RNG per generation step and per object (coop_gen_reseed, coop_pos_reseed,
  grass reseed, host world settings). Any new generation-time randomness must be made deterministic too.
- High refresh rate (coop_fps.gml): logic runs 60 ticks/s, rendering at monitor rate. Game logic events get a
  guard prepended by build.csx; alarms are held via generated scan/hold tables. New mod code in obj_coop
  Step events must stay after the `if (global.zs_rf) exit;` line; draw-time counters must be tick-gated.
- The UTMT compiler also miscompiles `struct[$ key]` - use variable_struct_get/set.
- Wrap new code called from game events in try/catch (see wrapped functions) and new controller
  subsystems via `coop_try(...)` in obj_coop Step.
- Commit after each working step; end commit messages with
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Open items / ideas
- If the host leaves the raid, the guest continues alone on local AI; far-away NPCs don't patrol (replicas
  were removed from the off-screen patrol list).
- Untested: launching the game straight from a Steam invite (+connect_lobby) — needs two accounts.
- Ideas: shared bunker, 3–4 players, PDA airdrop markers for the guest, publishing.
