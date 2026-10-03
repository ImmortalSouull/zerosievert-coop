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
2026-10-03 afternoon: user lifted the limit (no refund). Guard still used for clean launches/kills; cap set to 100000.
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
- Showcase: tools/make_showcase.py -> ZS_Coop_TikTok.mp4 (1080x1920, 32 s, silent - add a sound in TikTok).
  Takes recorded with `um win record --hwnd` (no audio with --hwnd); scenario -coop_scenario show / panel.
- Final state 2026-10-03 ~03:00: dist v0.1.0 (ZS-Coop-v0.1.0.zip) installed into the game via installer.
  Agent playtime used 29/80 min, Steam local playtime 26 min. Test save roots coopA/coopB (Russian UI)
  remain in %LOCALAPPDATA%/ZERO_Sievert for future tests; the user's real saves were never touched.

## Next steps
1. First real playtest with the friend over Steam (P2P path untested with two accounts).
2. Kill credit / XP / quest progress for guest kills (Destroy event on host decides).
3. Joining a raid already in progress; host extraction rules; grenades/explosions replication check.
4. Remove the 1-solid map drift risk entirely (seen once before per-step reseed; equal since).

## 2026-10-03 afternoon: first live test + v0.1.1
- LIVE Steam test with the user's friend (Ondrey, v0.1.0): invite overlay -> lobby -> P2P connected,
  guest followed into raid, puppet + bullets + NPC stream OK, ping ~117 ms. Steam path confirmed.
- Bug: F7 panel clicks offset in bunker/raid. Cause: with a player present the game locks the OS mouse
  to the window centre every frame and moves its own virtual cursor (obj_cursor, room coords);
  device_mouse_x_to_gui is meaningless there. Fix: map obj_cursor through the camera; window coords in
  menus. Also keyboard nav (up/down/Enter), Esc closes panel without opening pause, clicks don't shoot.
- Bug: F7 dead after Exit to menu -> New game -> bunker. Root cause not reproduced; fix: coop_ensure_alive()
  at top of obj_controller/obj_main_menu Step re-activates or recreates obj_coop (logs which happened).
- Smaller down screen (bottom line + timer bar) and compact revive context menu next to the partner.
- Steam rich presence "connect" -> friends can use "Join game" in the friends list.
- Installer upgrades an older co-op install (restores vanilla from coop_backup first).
- Protocol unchanged (COOP_VERSION 1): v0.1.0 and v0.1.1 can still play together.
- Agent playtime 39/80 min after this session.

## 2026-10-03 evening: v0.2.0 (protocol 2) - fixes from the first real session
User report (OBS video 16-10-05): no join-in-progress, no partner on PDA map, chest loot not live,
map divergence (2 cars on host only), dropped items local only, grenades local only.
- Map divergence causes: obj_vertex_grass is created during generation and its density follows each
  player's "amount grass" setting -> different number of random() calls; fixed by re-seeding right after
  grass Create. Also world-shaping difficulty keys (loot_*, armor_class_*, enemy_count_mult, anomaly_mult,
  enemy_*_hp) now come from the host on a connected guest (difficulty_get hook). Verified identical
  fingerprints with grass 1.0 vs 0.25.
- Chest UI keeps content in UI elements until close (ui_chest_close writes db). Live sync: read UI items
  every 6 frames (uiFindAllType(... "class_ui_item") parent "other inventory"), send; on receive rebuild open
  grid (Destroy items + ui_chest_populate). Verified both open same chest, host takes item -> guest UI 8->7.
- Dropped items = obj_chest_general tipo "discard" created in ui_chest_close -> CHEST_SPAWN to partner;
  emptied/destroyed containers -> CHEST_GONE. Spawned containers skip the loot roll (Alarm_0 hook).
- Grenades: obj_grenade_parent Create -> next step send GRENADE (id, start, dir, detonation point, speed,
  faction, by_player); explosion already hurts only the local player; partner grenades respect friendly fire.
  Map-placed mines are not replicated.
- PDA map: Catspeak functions CoopPartnerOnMap/X/Y registered; installer inserts a green
  UiMinimapPlayerMarker into pda_map.ui (backed up). Verified screenshot.
- Join in progress: F7 "Join host's raid" -> JOIN_REQ -> host resends settings + RAID_START(map, seed);
  host always seeds its raids while hosting. On peer ready the host resends all NPC spawns and all dynamic
  containers (corpses) + changed chests. Verified: guest joined 30 s late, identical map, 3 corpses synced.
- Bug fixed: bullets/mutants hitting the partner's puppet closed YOUR inventory/PDA (scr_autoclose_inventory).
- Test mode: game_in_focus() true (inventory UI closes when the window loses focus).

## 2026-10-03 night 2: v0.3.0 (protocol 3) - time/XP + proactive bug hunt
Requested: time-of-day/weather for late joiners, kill XP for the guest.
- Time: each save has its own clock (obj_light_controller.game_time_played) -> host sends it every 5 s.
  Weather: global.weather struct sent on each host hour change / peer ready; guest's hourly weather
  generation is disabled while slaved (meteo Step hook). Emissions (blowouts, deadly): guest never rolls
  (meteo Alarm_2 hook), host's start is mirrored (meteo Alarm_1 hook). Air drops: guest never rolls
  (controller Alarm_3); host's drop/guards/containers are replicated.
- Kill credit: bullet_hit_npc only credits shooter == local player, so guest kills credited nobody. Host now
  reports partner hits/kills (CREDIT); guest applies rep + kill_check_quest (XP + quests) + kill_add_stat.
  Verified: 4 kills credited.
Found & fixed proactively:
- More map divergence sources: obj_decor_parent Alarm_0 (jitter/variant/destroy - cars are decor),
  obj_deserialize_parent Alarm_0 (random building templates!), anomaly Alarm_0 (hazard fields + crystal
  artifacts) -> per-object reseed (seed, xstart, ystart, object). Verified identical with grass 1.0 vs 0.25 and
  low spec on/off. Map fingerprint exchange: both compare and warn on mismatch.
- Mutant projectiles (ghoul spit, wraith fire, violet crystal) bypass scr_shoot -> host scans and replicates
  (homing target remapped).
- Key doors (obj_door_parent) open on both; late joiners get all open doors.
- Corpses/air drops: host content is authoritative (CHEST_SPAWN incl. sprite).
- Pause in a shared raid no longer freezes the world (only our player deactivated); RAID_STATE and down
  state survive pause (pause used to clear down = free revive).
- Downed players cannot extract. Guest follows a raid only when not busy (pending raid used to work only
  in test mode). Version mismatch refused. BYE on game end. Partner name/hp drawn in GUI (visible at
  night/under roofs) + off-screen edge marker with distance.
- My old bug: "append" hooks on GlobalScripts put code OUTSIDE the function (game_pause) - now findreplace.
- Robustness: every obj_coop subsystem runs under coop_try; all mod functions called from game code are
  try/catch wrapped; crash handler logs to coop_<tag>.log in normal play too.
- Bug: bullets/mutants hitting the partner's puppet closed YOUR inventory - fixed.
