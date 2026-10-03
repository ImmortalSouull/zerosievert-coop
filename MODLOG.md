# MODLOG — ZERO Sievert co-op

## Goal
Own 2-player co-op for ZERO Sievert: joint raids only (bunker stays per-player), Steam invites,
extended difficulty settings, down/revive system. Full spec: see "Spec" below.

## Environment (2026-10-03)
- Game: ZERO Sievert, Steam app 1782120, `C:\Program Files (x86)\Steam\steamapps\common\ZERO Sievert`
- Engine: GameMaker 2 (GMS2), VM (NOT YYC), bytecode 17, project name `ZERO_Sievert`
- data.win sha256 (vanilla): `1c4f2cd1db84cc7b6178ae410639c593cfc50edf6fc9f7548c348fbeb3824d8f`
- Stats: 6715 scripts, 8003 code entries, 1575 objects, 370 rooms, 4 extensions
- Anti-cheat: none. Official mod API (Catspeak, Workshop) has no networking.
- Steamworks extension already exposes `steam_net_packet_*`, `steam_lobby_*` to GML.
- Built-in sandbox difficulty: `difficulty_define_range/toggle`, `difficulty_get/set`,
  `difficulty_sandbox_save/load`, presets rookie/standard/survivor/hunter, `hardcore_lose_*`, perma death.
- Saves: `%LOCALAPPDATA%\ZERO_Sievert`

## Work layout (outside repo — never commit game files / decompiled code)
- `C:\Users\pasha\zerosievert-coop-work\tools\utmt_cli\` — UndertaleModCli 0.9.2.0
- `C:\Users\pasha\zerosievert-coop-work\vanilla\` — pristine data.win, options.ini, gamedata_order.json
- `C:\Users\pasha\zerosievert-coop-work\decomp\` — decompiled GML (to do)

## Backups / restore
- Saves: `C:\Users\pasha\.universal-modder\backups\zerosievert-saves\20261003-011746.zip`
  restore: `um backup restore zerosievert-saves`
- data.win: copy `zerosievert-coop-work\vanilla\data.win` back into the game folder
  (or Steam → Properties → Installed Files → Verify integrity).

## Route
GML injection into a copy of data.win via UndertaleModTool scripts (patch applied to the user's own
data.win; we ship only our code + patcher). Networking over Steam P2P (`steam_net_packet_*`) with
Steam lobby invites. Host-authoritative raid simulation. Consider GMLoader later for cleaner packaging.

## Spec (agreed with user)
- 2 players. Co-op in raids only; each player keeps own save, bunker, stash.
- Raid world uses host's settings (loot, enemies, anomalies); death penalty per own save.
- Difficulty menu additions: anomalies, enemy count/spawn rate, friendly fire, down timer N,
  revive time, revive-HP multiplier.
- Down state: slow crawl; timer N (default 60 s) on 1st down, N/2 on 2nd; 3rd down = final death.
  Pistol allowed only on 1st down. Timer pauses while being revived; resumes if interrupted.
  Down counter resets at raid start.
- Revive menu: plain / bandage / medkit, listing concrete items with HP preview; consumes 1 item.
  Time by category only: none 10 s, bandage 7 s, medkit 5 s.
  HP (1st down): none 10; bandage 20, anti-bleed gel 20, military 25, sterilised 30;
  improvised 35, first aid 35, T-000 40, standard 45, professional 45, modern 55.
  2nd down: x0.6.
- Both players down = both die, raid ends immediately.

## Plan
1. Network skeleton: see each other in raid + shooting (two windows locally).
2. Shared world: same map, host-owned enemies/loot, damage, extraction.
3. Down/revive.
4. Difficulty additions.
5. Playtests, fixes, patcher/installer.

## Log
- 2026-10-03: recon, backups, UTMT CLI 0.9.2.0 installed, `info` reads data.win OK. Ready to start.

## HARD RULE: Steam playtime budget
Owner must stay refund-eligible (< 2 h Steam playtime). Agent budget: 80 min total (incl. showcase recording; aim for less), enforced by
`tools/game_guard.py` (ledger in `playtime_ledger.json`, auto-kill at deadline). EVERY game launch
goes through the guard. Never launch the exe directly. Never try to hide time from Steam.
Steam local playtime at start (2026-10-03 01:25): no Playtime recorded (~0 min).

## Session log 2026-10-03 (night)
Findings (verified in game):
- Game has a dormant 2-player framework: obj_player_puppet, player_get(mp_index), player_get_local_index(),
  bullet_hit_player damages only the local index, NPC AI targets player_nearest_instance (all players).
- Launch: exe directly needs env SteamAppId/SteamGameId=1782120 (steam_appid.txt gets removed) and
  `-no_gpu_pref` (else gpu_pref_boot relaunches the exe and drops our args).
- UTMT CLI: close stdin (`< /dev/null`) or it hangs; `#macro` is not shared across code entries (build.csx
  expands macros textually); `async_load[? k]` miscompiles -> use ds_map_find_value; `until` is reserved.
- Instance depth must be within +-16000 or it is never drawn.
- obj_controller Alarm_4 deactivates everything outside a 960x540 region around the camera (and pause
  deactivates the room) -> coop_after_culling() re-activates obj_coop and, on the host, the partner's region.
- Map generation runs one state per obj_map_generator Alarm_2; other objects consume random() between
  steps. Re-seeding at every Alarm_2 (seed + step*7919) makes host and guest maps identical
  (fingerprint solids/hash/chests equal).
- Death goes through player_step_grim_reaper (single chokepoint) -> down/revive intercept there.
- Difficulty: __difficulty_define_range/toggle; menu tabs are Catspeak .ui files in ZS_vanilla/ui.
- screen_save("x.png") from GML = free in-game screenshot into %LOCALAPPDATA%/ZERO_Sievert.
Working (2 local instances, UDP): connect, host-led raid start w/ shared seed, identical maps, puppets,
  NPC replication (231 NPCs), bullets, down/revive end-to-end (Medikit T-000 -> 40 hp).
Test harness: tools/test2.sh, tools/wait.sh, tools/logs.sh, tools/shots.sh; test-mode flags
  -coop_root/-coop_slot/-coop_autoraid/-coop_bot/-coop_scenario revive.
- Shared containers: chest content rolled in obj_chest_general Alarm_0 -> reseed from raid seed + position
  => identical loot on both; changes synced (db "all loot", chest_<id>.items) by object+position key. Verified.
- Sync gated on both maps finished (obj_map_generator.state == 21 on both, RAID_STATE ready flag): purging
  guest NPCs during generation changed the map. Guest must also drop purged NPCs from global.list_n_id
  (obj_controller off-screen patrol sim) or it crashes.
- Down rules verified: 2nd down timer N/2, both down -> both die (fixed: down HP clamp blocked forced death;
  revive race: partner flag lags ~1 frame packet -> 1.5 s grace after reviving).
- Steam: lobby create + invite overlay verified (single account); P2P traffic untested (needs 2 accounts).
- Installer verified (vanilla -> install -> uninstall -> install), difficulty tabs verified in game.
