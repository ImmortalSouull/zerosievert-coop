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

## 2026-10-04: v0.4.0 work (protocol 4) - high refresh rate, partner animations, freeze fix
High refresh rate (coop_fps.gml, build.csx):
- The game is frame based (all speeds/timers/alarms tuned for 60 steps/s). Runner now goes at the monitor
  rate (game_set_speed), the simulation stays at 60 ticks/s: every frame is classified (zs_rf_q, first
  guarded event of the frame) as a logic tick or render-only. build.csx prepends
  `if (global.zs_rfq && zs_rf_q()) exit;` to every Step/Collision/Keyboard/Mouse/Other(outside view) event
  of the game (174). Alarms can't be skipped (would be lost): obj_coop Begin Step adds +1 to every running
  alarm on render-only frames, using a table generated by build.csx (objects with alarm events, top
  ancestors). NPC paths/speed and shell casings' built-in motion are held Begin->End Step. Particles: auto
  update off on render-only frames. A fresh key/mouse/gamepad press or release forces a logic tick.
- Drawing: Pre-Draw moves every instance that moved during the last tick to lerp(xprevious, x, alpha) and
  the camera likewise; GUI End restores. Player weapon (class_player_weapon struct, own x/y) is shifted
  with the body. Draw-time counters (cursor blink, scope dot, NPC typewriter text, radiation overlay, PDA
  marker lerp, indoor darkness) advance only on logic ticks.
- Clock: obj_light_controller used delta_time -> zs_logic_dt(). room_speed/game_get_speed timers -> 60.
- All sprites are "frames per second" type (checked: 1843/758/397 sprites), so auto animation is right.
- obj_coop is the LAST object index: its events run after every other object's of the same type.
- A generated function is only visible to code compiled after it: generated GlobalScripts go first.
- Verified: 300 ticks walk = 218.26 px at both 60 and 165 fps; ~5.2 s real for 300 ticks in both modes;
  165 frames/s, 60 ticks/s with two instances. F7 panel + Ctrl+Alt+U cycle: monitor/60/120/144/165/240/360.
Partner animations (protocol 4):
- Using meds/food/drinks/cigarettes/grenades = class_player_arms in player.arms_holder (hands sprite drawn
  over the body, weapon hidden). Never synced before -> partner looked AFK. PSTATE now carries arms
  sprite/image + weapon pose (x/y offset, angle, xscale, draw order) + torch/laser switches. Puppet gets a
  display-only arms struct; item sound via reliable ARMS msg.
- Puppet weapon pose came from the LOCAL camera (weapon inspection animated the partner's gun too):
  class_player_weapon func_end_step hook takes the pose from the network for the puppet.
- Partner torch (open item since v0.1): light controller drew torch/laser only `with (player_get_local())`
  -> `with (obj_player_parent)`; puppet runs player_update_weapon_torch/laser on its own synced mods.
- obj_player_parent End Step set audio_listener_position for the puppet too (sounds heard from the
  partner's position) -> local player only.
- Partner sounds: coop_psound() replaces local audio_play_sound in reload/bolt/unjam/torch/laser/chest/
  grenade pin and sends PSND; puppet footsteps via scr_choose_footstep_sound (rattle only for obj_player).
Freeze (also in v0.3.0 and probably vanilla): obj_fog_setup Alarm_1 vertex_freeze() on an EMPTY vertex
  buffer spins forever. Found via teleport stress test (-coop_scenario tele) and in-memory phase marker:
  COOP_TRACE_EVENTS=<regex> bash tools/build.sh instruments game events; run with -coop_phase; log prints
  the buffer address; `python tools/peek.py <pid> <addr>` shows the event a frozen process is stuck in.
  (show_debug_message does not reach OutputDebugString; per-line file logging is far too slow.)
Test hygiene: ALWAYS `python tools/game_guard.py stop` before a new tools/test2.sh, or the new run does
  not start and the old instances keep writing the (deleted) logs.

## 2026-10-04 evening: road to v1.0 (protocol 5) - up to 4 players
Regression: `python tools/regress.py [names|maps|all]` runs scenarios on two (test2.sh) or four (test4.sh)
instances, checks logs, keeps them in work/regress/<ts>/. COOP_REGRESS_ARGS adds args to every launch
(e.g. "-coop_netsim 150,3,40"). Baseline on v0.4.0 found a real crash: when the host leaves, guest replicas
with an empty state string ("" placeholder before NPC_STATESTR arrived) crashed obj_npc_parent's state machine.
Net core rewrite (coop_net.gml):
- Packet = [u8 kind][u16 seq][u8 from][u8 to][u8 0] + payload. kind 0 unreliable, 1 reliable (UDP only:
  per-peer seq, cumulative acks, resend with RTO ~1.5*ping, in-order delivery with a reorder buffer),
  2 ack. Steam uses its own reliable mode (always kind 0). UDP previously had NO reliability at all.
- Slots 0..3 (host 0). Star topology: guests talk to the host; the host relays guest broadcasts (and any
  targeted message) to the other guests. coop().msg_from = sender slot; coop_msg_send_to(slot) / msg_dest.
- Puppet of slot s = mp_index (s - my_slot + 4) mod 4 (game's player API supports any index).
- UTMT compiler: no `f()[i]` (index on a call result) and no `struct[$ key]` - use a temp var / variable_struct_*.
- Group rules: down possible while another player stands; everyone down -> all die; a death only kills
  downed players nobody can revive. Revive targets the nearest downed player.
- Raid owner = lowest slot among players in that raid (host while there). Owner runs NPC AI, world
  time/weather/emissions, kill credit, late-joiner sync; on owner change the new owner takes the replicas
  over (keeps nids). The session host keeps relaying from the bunker.
- Reconnect: host answers packets from a dropped endpoint with REJOIN; guest resets and says hello again,
  re-adopts its locally released NPCs when the owner's map is ready. -coop_netsim lat,loss,jitter[,at,dur].
- Map fingerprint per peer, without dynamic containers (corpses arrive at different moments -> false mismatch).
Also: ping markers (middle mouse / right stick), group scaling (coop_group_enemies/hp, fixed by the host
at raid start and sent with the settings), update check (GitHub API, silent), Co-op button in main/pause
menu, installer restores UI/lang files from backups before patching (updates used to skip new UI rows),
gamepad in the F7 panel and the revive menu (game interact = action 6, default key F; revive stays on E).
Results: 10/10 core scenarios, quad (4 players) and all 6 other maps (camp, industrial, swamp, mall, Zakov,
CNPP) pass; reconnect after a 20 s blackout passes.
Later the same evening (v1.0 hardening):
- Raid owner handoff verified with 4 instances (scenario handoff): the new owner must also keep the regions
  around the other players active (coop_after_culling) or NPCs near them sleep on its machine.
- tools/soak.py: 21 min, 4 players, 0 errors, 44 NPC checks ok per replica, +7..20 MB per process.
- NPC consistency check every 30 s (owner sends its live nid list; replicas drop extras, request missing).
- Bad network (-coop_netsim 120,3,40) found two real bugs:
  * live chest ping-pong: after a UI rebuild the next read of the grid differs (layout/fields), each side
    re-sent its view, and with lag an old echo restored an item already taken (duplication). Fix: content
    revisions (apply only newer; tie -> lower slot) + change detection on normalized content.
  * PSTATE before PLOADOUT: a puppet with an unknown weapon crashed class_player_weapon.func_draw
    (outline_start with an undefined sprite). Puppet weapon hidden until arma_now is a real weapon.
- Give item (X): the stack leaves the giver's inventory db and appears in a "discard" bag at the
  receiver's feet (existing bag sync); no direct insertion into another player's inventory grid.
- regress.py: extra args go first so a scenario's own args (e.g. its blackout netsim) win.
- Bad network also found: a raid the host started ALONE generated with group scaling for 1 player, but a
  guest joining later got the scaling recomputed for 2 -> different map. Group scaling is now fixed in
  coop_hook_go_to_map (coop_group_fix) and never recomputed during the raid. Test: latejoin
  (-coop_delay_join 25 keeps the guest offline until the host is in its raid).
- The installer now patches mm_sidebar_main.ui / mm_sidebar_pause.ui ("Co-op" button -> Catspeak
  CoopOpenPanel) and blanks the game's hard-placed "New" tag (fixed y next to "Mods"). Verified live:
  screenshot of both menus, a real mouse click via `um win drive --proc "ZERO Sievert" "focus" "click x y"`
  opened the panel; reinstall is idempotent; update path restores UI/lang files from coop_backup first.
- PC freeze during a long 4-instance regression: 15 GB RAM, ~2.4 GB per instance -> swap. 3-instance
  variants (trio, handoff3) cover the same group logic.
- v1.0.0 released 2026-10-04 (protocol 5): final dist = build d77d504..., regression green on 2/3/4 instances,
  bad network, all maps, 21-min soak.

## 2026-10-05 - v1.1.0: high-FPS flicker, game-style UI, hub lobby and visits
- Repo made public (update check works without a token). Request to remove a "license check": there is
  none in the mod (the installer only compares data.win hashes to know the game version); declined to add
  anything aimed at cracked copies.
- High-FPS enemy flicker: NPC facing compared target x with the *interpolated* x on render frames, mutants
  compared xprevious (stale between ticks). Pre-Draw now stores live/previous x (zs_live_x/zs_prev_x) and
  the draw code uses them (hooks in obj_npc_human_parent/obj_enemy_mutant_parent Draw).
- Tree fade flicker: shd_tree dithers with a screen-space Bayer pattern, so moving the camera by
  sub-pixels re-rolled the pattern. Replacement pixel shader (mod/shaders/shd_tree_ps.hlsl, same cbuffer
  and outputs) anchors the pattern to world coordinates. tools/make_shaders.py compiles it (d3dcompiler_47,
  ps_4_0); build.csx splices the DXBC into GM's container: header u32 at +24 = DXBC size, string-table
  offsets after the DXBC are absolute and shift by the size delta.
- Video capture here composes at ~55 Hz (frames looked duplicated); -coop_seq_dump N copies 30 frames of
  application_surface to GPU surfaces and saves them afterwards (saving per frame took ~70 ms).
- UI restyle (coop_style.gml): everything in the 1920x1080 UI space with the game's language fonts
  (index 3 = small, 4 = body; index 2 is too small at 1080), panels/slots/key prompts like the inventory.
  Revive picker = item icons (item_get_sprite_inv) with +HP / seconds under them; give menu rows with icons.
  #macro values must not carry trailing // comments (build.csx pastes the whole rest of the line).
- Hub lobby: players in their own hubs see each other (pstate also sent in the hub, puppets only in a
  settled hub: creating a character during go_to_map failed half way in Create (save db open) and the
  CleanUp of the half-built puppet crashed the game -> obj_player_parent CleanUp guard + hub_frames>=30).
- Visits: bunker modules are global arrays (base_lvl, sl_base_id, sl_free) rebuilt by obj_base_parent
  Alarm 0 at fixed slots (player room around obj_player_room_spawn 352,880; bunker = y < 1146). A visit
  applies the friend's arrays and rebuilds; saves go through coop_visit_save_guard (writes ours); module
  install/upgrade/production blocked. Gotchas: obj_player_parent Create calls lista_base() -> base_load()
  (every puppet creation reloads the arrays from the save!); the game deactivates off-screen instances and
  with() skips them, so old furniture survived -> activate the bunker region and event_perform(ev_alarm, 0)
  synchronously; obj_vertex_props bakes decor after 8 hub frames -> module furniture is excluded.
- Joining a raid whose owner is a guest (host extracted): JOIN_REQ goes to the owner (lowest slot in the
  raid), which answers with the settings the raid was generated with (raid_settings_json snapshot at
  room1 start) + RAID_START. Only higher slots may join (ownership never moves to a fresh map copy).
  A new owner's NPCs taken over from replicas may lack coop_spawn_sent (fixed read).
- Down: the last two going down at the same moment each saw the other standing -> both waited 60 s.
  Now 1.5 s with nobody standing = everyone down.
- New tests: lobby, lobby2, ownerjoin (3), chest3, both3, grouphp (-coop_diff key=val overrides difficulty
  without touching the save), solo (one instance: game_guard run with -coop_autoraid 1 -coop_scenario solo),
  -coop_name for long names. Protocol 6.
