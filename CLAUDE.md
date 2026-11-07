# ZERO Sievert CO-OP mod — project guide for Claude

Talk to the user in Russian. The user (pasha) playtests with a friend (Steam name "Ondrey") and may ask
you to send Steam invites to him for live tests — that is allowed. No Steam playtime limit anymore.

## Read first
- `MODLOG.md` — full journal: every engine fact, gotcha, decision and test result. Read it before changing code.
- Current release: **v1.2.0** (game 1.4.13 / new enemy AI; up to 4 players, hub lobby + bunker visits,
  game-style UI), network protocol `COOP_VERSION 8` (all players must match). v1.2.0 is built locally but NOT
  published: the user said (2026-11-05) not to push/release on GitHub until they say so.
  `COOP_MOD_VERSION` in coop_update.gml must equal the release version (update check compares GitHub tags).

## Layout
- `mod/gml/*.gml` — all mod code (GML). `gml_GlobalScript_coop_*` = modules, `gml_Object_obj_coop_*` = controller events.
- `mod/hooks.txt` — patches into the game's own code (`### findreplace|prepend|append <code entry>`).
  NEVER `append` to a `gml_GlobalScript_*` (code lands outside the function) — use findreplace.
- `mod/ui/` — text inserted into the game's .ui / language files by the installer.
- `mod/shaders/*_ps.hlsl` — replacement D3D11 pixel shaders (shd_tree: world-anchored fade dither); compile
  with `python tools/make_shaders.py` (-> .dxbc, committed), build.csx splices them into the game's shaders.
- Texts: every text the player sees goes through coop_t("English", "Russian") / coop_tf("... {0}", "... {0}", args)
  and must be in `mod/lang/strings.tsv` (13 game languages + zh-Hant; `python tools/lang_extract.py` lists missing
  ones; build.sh generates coop_lang.gml). Difficulty tab rows: `mod/lang/difficulty_rows.tsv`.
- UI: draw co-op overlays with `coop_style.gml` helpers (1920x1080 UI space, game fonts COOP_F_SMALL/BODY,
  coop_ui_panel/slot/prompt/item_icon/fit). Hub lobby + visits live in `coop_hub.gml`.
- `dist_src/` — installer.ps1, README.txt (Russian, for players), THIRD_PARTY.txt.
- `tools/` — build/test/release scripts (below). `tools/utmt/build.csx` = UTMT build script.
- Outside the repo (never commit game data): `zerosievert-coop-work\` NEXT TO the repo (now
  `C:\Users\PC\zerosievert-coop-work\`; repo `C:\Users\PC\zerosievert-coop`, new PC since 2026-11-05).
  No script hardcodes a user folder: `tools/env.sh` derives ROOT/WORK/G (game dir, override ZS_GAME_DIR)/CLI.
  - `vanilla/data.win` pristine copy (game 1.4.13, Steam build 26317366, sha256 96c3df3a...),
    `decomp/CodeEntries/` decompiled game GML
  - `tools/utmt_cli/` UndertaleModCli 0.9.2.0, `tools/xdelta/`, `build/`, `dist/`, `caps/` (videos)
- Game: `C:\Program Files (x86)\Steam\steamapps\common\ZERO Sievert` (GameMaker, VM, data.win).
- After a game update: `bash tools/decompile.sh --refresh` (only while the game folder holds an untouched Steam
  install: copies data.win to work/vanilla, decompiles, runs `python tools/check_hooks.py` = hooks whose FIND
  text or target vanished). Then fix hooks.txt, build, regress.
- The user watches the tests: `tools/claude_on_top.ps1` keeps the Claude window above the game (game_guard.py
  calls it every 15 s while a game runs; `-Off` releases it, env ZS_NO_ONTOP=1 skips it).

## Commands (Git Bash)
- Build: `bash tools/build.sh` → `zerosievert-coop-work/build/data.win` (check "COOP BUILD OK").
- Quick test install (data.win only): `bash tools/install_test.sh`. regress.py does NOT install the build itself:
  run install_test.sh after every build before testing.
- Test windows open in a 2x2 grid right of the Claude window (tools/env.sh WIN_A..WIN_D, override ZS_WIN_A..D).
- Release: `bash tools/make_dist.sh <ver>` then run `dist/ZS-Coop-v<ver>/installer.ps1 install`
  (`powershell -NoProfile -ExecutionPolicy Bypass -File ...`). Copy the zip into the repo root for the user.
- Regression (use it before every release): `python tools/regress.py` (core), `python tools/regress.py all`
  (+ every map), `COOP_REGRESS_ARGS="-coop_netsim 120,3,40" python tools/regress.py` (bad network);
  4 players: `tools/test4.sh` (coopA..coopD; env COOP_PLAYERS=3 for three), soak: `python tools/soak.py <minutes>`.
  RAM: the new PC (Ryzen 7 9800X3D, 32 GB, RTX 5060 16 GB) runs 4 instances (~2.4 GB each) fine. (The old
  laptop had 15 GB and froze once with 4.)
  Multi-player scenarios: quad/trio (see each other, credit, revive, ping, give), handoff/handoff3 (host
  extracts, next slot owns the world), latejoin (-coop_delay_join), reconnect (blackout), menus (UI buttons),
  lobby/lobby2 (hub lobby + visits, bunker weather + bunker give), hostjoin (host's train joins a guest's raid),
  gather (3 players, train circle: inside goes, outside stays), ownerjoin/chest3/both3 (3 players), grouphp, aiguest (1.4 AI vs a guest far
  from the host), solo (1 window, players=1 in regress.py); per map: map*/solo*/aiguest* (tag maps).
  Everything in order: `bash tools/regress_full.sh [soak minutes]` (solo > duo > trio > squad > soak > bad net).
  Solo with the mod by hand:
  `python tools/game_guard.py run --max-minutes 3 --note solo --launch "-no_gpu_pref -coop_slot 1 -coop_root
  coopA -coop_autoraid 1 -coop_scenario solo"`. Test-only args: -coop_diff key=val,... (difficulty override,
  not saved), -coop_name <name>, -coop_seq_dump N (saves 30 consecutive frames, for flicker hunting).
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
  `python tools/peek.py <pid> <addr from log>` shows the game event a frozen process is stuck in. Test save roots
  `coopA`..`coopD` in %LOCALAPPDATA%\ZERO_Sievert (copies of the user's slot 1, English UI). Since 1.4 a whole
  slot is ONE file `save_shared_<slot>.dat`; the real save lives in Steam Cloud (folder = Steam account id,
  `using_cloud`), test mode turns cloud off. The user's real saves are never touched.
  Screenshots: `bash tools/shots.sh <prefix>` (tools/winshot.ps1, PrintWindow) - the old `um` tool is gone.

## GitHub (public repo https://github.com/ImmortalSouull/zerosievert-coop)
- gh CLI: `"/c/Program Files/GitHub CLI/gh.exe"` (logged in as ImmortalSouull on the new PC, `gh auth setup-git` done).
- License: MIT (LICENSE, since 2026-11-05; README "Лицензия / License" says it covers the mod's code only).
  All the user's other mod repos are MIT too.
  Ask the user before publishing. Git identity is set per repo (ImmortalSouull); core.autocrlf=false (CRLF breaks .sh).
- Every release: write `docs/releases/v<ver>.md` in English, Russian AND Polish (user's rule 2026-11-07): title
  "RU / EN / PL", a line "Выберите язык · Choose a language · Wybierz język:", then three collapsed blocks
  `<details><summary><b>English</b></summary>` ... `</details>`, the same for Русский and Polski (blank line after
  </summary>), each a full text incl. install steps. README: `README.md` (English) + `README.ru.md` + `README.pl.md`
  with a language bar at the top of each; dist_src/README.txt has RU/EN/PL sections. Content: what's new, "Исправлено (относительно v<prev>)",
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
- Game 1.4 (new enemy AI): humans run a behaviour tree (`ai_execution`, ai_*.gml, profile tree "human_basic");
  platform layer (scr_platform: Steam/Epic/none) replaces direct steam_* calls in the game's own code (the
  Steamworks extension is still there for our P2P). `ai_human_before_cull` suspends the AI of NPCs outside the
  local camera: the owner keeps it awake near other players (coop_keep_ai_awake hook). Off-screen "roaming"
  (global.roaming_enabled) only moves/fights deactivated NPCs, so the active regions around puppets are safe.
  Perception picks the player via player_nearest_instance (our hook -> nearest standing player).
- Never wake players while obj_controller is deactivated (vanilla pause): their Step reads obj_controller.
- ai_compat and ai_commands can't be recompiled (field `until`): no hooks there (callouts = owner-side scan).
- Comments: every hook gets a `// [n] why` line; tag hacks `WORKAROUND (no source access)` (the devs grep it).
- The game deactivates instances outside the camera and on pause — keep obj_coop alive (coop_ensure_alive).
- With a player on the map the OS mouse is locked; use obj_cursor (virtual cursor) for GUI hit tests.
- Networking (coop_net.gml): slots 0..3, star topology through the host, reliable UDP layer, raid owner =
  lowest slot in the raid runs NPC AI/world (coop_is_world_owner / coop_is_world_replica - never test
  `role == "host"` for world authority). Messages: coop_msg_begin + coop_msg_send / coop_msg_send_to(slot);
  handlers read coop().msg_from.
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
- A lower slot cannot join a raid a higher slot owns (by design, see MODLOG v1.1.0).
- Visits show the friend's modules only (furniture/benches); traders, stash and quests stay local.
- Ideas: PDA airdrop markers for the guest, shared stash/trading between players, publishing on mod sites.
