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
- Regression (2/3 instances, 17 scenarios): one v3 run ended with the host's game gone right after
  "raid start sent", no GML error logged. The only new code on that path destroyed the hub puppets inside
  go_to_map (which then runs the game's save code over the players) -> puppets are no longer destroyed
  there (hub_leaving blocks new ones; they are pruned at the next room start).
- Friend's report (after the 1.1.0 build): Russian UI showed English tooltips on the Co-op difficulty tab
  (game descriptions are plain strings - vanilla ones too; ours are now keys translated in a
  difficulty_get_description hook) and "Co-op" as the tab label (vanilla labels are translated through
  language_alias by their English text; ours uses Translate). Wish: the mod in the Mods menu - the menu
  lists workshop/installed mods only, so the installer inserts a static row into mm_mods.ui. It must go
  before `data.modding_menu_current = UiModMapIDtoOrder(0)`: with no mods that call fails and nothing
  below it in the scroll box is built. Catspeak addGlobalFunction takes at most 16 arguments (a third
  pair -> "Invalid callv target #2" and none of the functions registered).
- Raid owner's obj_controller "dynamic NPC" sim walks NPCs outside ITS view along patrol paths and rolls
  abstract fights between them - also NPCs next to another player (live there). Hooks skip NPCs within
  480x270 of any puppet (coop_near_other_player).
- Clicking real UI in tests: `um win drive --proc "ZERO Sievert" "focus" "click x y"` (window coords of
  the 1280x720 test window); Mods = 895,541 in the main menu.

## 2026-11-05 - new PC + game 1.4.13 ("Completely New Enemy AI" + "Improved Enemy AI")
- New PC (user `PC`): repo C:\Users\PC\zerosievert-coop, work folder next to it. Installed Git, gh, Python 3.12,
  UTMT CLI 0.9.2.0 (still the latest release), xdelta 3.1.0. Tools take paths from tools/env.sh.
- Game: 1.4.13, Steam build 26317366, data.win sha256 96c3df3a..., 9427 code entries (was 8003), 1557 objects,
  5 extensions (Epic Online Services added). Tools: tools/decompile.sh, tools/check_hooks.py.
- 7 of 126 hooks no longer matched:
  * __db_init / db_cloud_enabled / logo screen: new platform layer (platform_user_id(),
    platform_cloud_available(), dev_launch_requested()).
  * FPS unlock left obj_controller Step for the debug menu (debug_menu_entries "Unlock framerate").
  * obj_controller off-screen sim rewritten: legacy patrol paths only with !global.roaming_enabled (debug
    toggle, on by default); NPCs on the new AI use ai_routes_offscreen; roaming moves/fights only
    deactivated NPCs (instance_exists false), so the regions coop_after_culling keeps active are safe.
- New AI: obj_controller Alarm_4 calls ai_human_before_cull before deactivating: every migrated NPC outside the
  LOCAL camera gets ai_human_suspend (routes, commands, cover and its target dropped). On the raid owner that hit
  the NPCs fighting the other players every 20 frames -> hook keeps them awake (coop_keep_ai_awake).
  Perception: player_nearest_instance (already hooked). AI time = ticks (now += 1/60), ai_world_begin_step in
  obj_controller Begin Step (guarded on render-only frames) -> high refresh rate safe.
- Saves since 1.4: one file per slot (save_shared_<n>.dat), in Steam Cloud. Test roots coopA..coopD = copies.
- GitHub issue #1 (crash "Unable to find instance for object index 369" in player_collect_interactables,
  coop_solo.log): 369 = obj_controller in 1.3.x. A normal pause deactivates the room incl. obj_controller; the
  coop_after_culling() call at the end of game_pause woke obj_player_parent when connected (hub lobby) -> the
  player's Step read obj_controller.marked_object_id. Fixed: players are only woken while obj_controller exists.

## 2026-11-05 (later) - 1.4 AI in co-op: hearing, callouts, roaming; tests; comments for the devs
- Hearing: ai_hearing_emit() is only called by scr_player_movement (local player). The owner now emits puppets'
  footsteps (coop_puppet_hearing_step: network movement, 28-tick cadence, running = PSTATE flag 16). Hearing only
  refreshes a KNOWN target (__ai_hearing_eligible needs knowledge/withdrawal); first contact is by sight.
- Callouts: barks are obj_npc_draw_text bubbles made inside the AI (owner only). ai_compat AND ai_commands can't be
  recompiled by UTMT (struct field `until`, reserved word) -> no hooks there. The owner scans new bubbles every
  tick (coop_npc_bark_scan; bark key = npc.ai_bark_last_line, legacy text ids 6/8/12/16/17), receivers rebuild
  the bubble like __ai_compat_show_bark (message 38 NPC_BARK).
- Roaming: spawn distance check covers every player (coop_other_player_within); ai_roaming_step runs on the world
  owner only (obj_controller Step_2 hook); despawn needs !instance_exists, so the owner's active regions are safe.
- Not changeable: ai_commands_camera_step (NPC may fire at the LOCAL player only once inside that player's camera,
  after an opening delay) is off for other targets -> enemies off a guest's screen can fire at them at once.
- Checked, no change needed: takeover of replicas - ai_equipment_ready is set in every NPC Create
  (npc_setup_weapon), the BT prepares itself on the first Step, "resumed_after_gap" resets stale state.
- Replica Alarm 8 (patrol state re-roll for non-BT NPCs) skipped.
- Tests: solo (1 window, regress players=1: AI engages, kills, pause) and aiguest (guest jumps to experienced
  bandits >= 700 px from the host: owner logs targeting/hearing, guest logs callouts), both on every map too.
  Gotchas: rookie/novice bandits WITHDRAW when surprised at close range (barks "retreat"); view distance ~250 px
  at dusk; trees around a far target are deactivated on the teleporting machine, so the open-spot search must
  wait for the next culling pass (~20 ticks). tools/regress_full.sh = solo > duo > trio > squad > soak > bad net.
- Comments: every hook in hooks.txt has a "// [n]" line; WORKAROUND (no source access) tags (79). Dead NPC_HIT (34)
  removed. Mixed line endings in the repo: keep each file's own (some .gml are CRLF).

## 2026-11-05 (night) - every game language; fixes from the full run
- Game 1.4.13 offers 13 languages (gamedata/languages.json; folder chinese_traditional exists but is not listed).
  global.language_current = folder name (english, russian, polish, german, french, italian, spanish_es,
  spanish_latam, pt_br, turkish, japanese, korean, chinese_simplified); the game sets it from Steam/Epic locale
  at first start, language_set_new_language() switches (reloads CSV + fonts; fonts render CJK/hangul fine).
- Mod texts: mod/lang/strings.tsv (English key column + 13 columns, also Traditional Chinese) ->
  tools/make_lang.py (run by build.sh) -> gml_GlobalScript_coop_lang.gml (coop_t, coop_tf, data). Texts with
  names/values use coop_tf("{0} joined", "{0} подключился", name) - word order differs per language.
  tools/lang_extract.py lists texts in code that the table lacks. Difficulty tab rows: mod/lang/difficulty_rows.tsv
  (key + column per language) -> installer writes each language's CSV (quotes texts with commas).
- Installer talks in the Windows UI language (Get-UICulture), English in brackets.
- xdelta3 reads an XDELTA environment variable as extra options: never export XDELTA (env.sh uses XDELTA_EXE).
- Test lang (1 window): every game language through language_set_new_language, all texts from the table,
  screenshot lang_<language>.png of the co-op panel.
- Full-run fixes: host crashed (invalid ds_map in coop_net_on_packet) when a message delivered from the reorder
  buffer freed its own peer (guest quit) -> peer.freed flag. Test fixes: livechest picks map containers only
  (1.4 roaming fights leave bodies = dynamic containers), quad credit check accepts any guest (slot order =
  connection order), fps walks toward the map centre (edge spawns), aiguest retries a new enemy every 10 s.
- Full run 2026-11-06 (after the fixes): lang+solo 8/8, duo 28/28 (all maps + aiguest per map), trio 5/5,
  squad 2/2, squad soak 21 min (0 errors, 0 desync fixes, RAM flat +-2 MB), bad net 18/19. The one failure: v3
  on bad net, guest shot a green_army_soldier1 replica for 6 s with no hit; on the host instance_nearest from
  the bullet found no NPC near it (the soldier was not active there) although the guest's replica kept moving.
  3 reruns on bad net passed. Open: log the host-side position/active state of the target NPC (by nid) when a
  partner bullet finds nothing near, to tell a stale replica from a deactivation race.

## 2026-11-06/07 - live test with Ondrey (v1.2.0 build) and fixes (protocol COOP_VERSION 8)
Live: Steam invite launch (+connect_lobby) works. Found:
- Separate raids: the guest took the train alone (no shared seed), the host later started a fresh raid. Now every
  connected player's raid has a known seed (RAID_STATE carries it + a 'late' flag); a train ride while any partner
  is in a raid goes into that raid (coop_hook_go_to_map returns the map, hook [5] `arg0 = ...; if (arg0 < 0) exit`).
  Raid owner = lowest slot among the players who STARTED the raid, before late joiners (coop_raid_owner), so a lower
  slot (the host) can join a guest's raid without taking a fresh map copy's world over. Panel "Join raid" is the same
  train ride now (no JOIN_REQ round trip; the owner's raid_settings_json snapshot is no longer sent - only matters if
  the host changed difficulty mid-raid).
- User design: the host's train opens a gathering circle (coop_gather.gml, msg 67, radius 160, 15 s, 4 s in tests)
  where the host stands; guests inside when RAID_START arrives follow, the rest stay (log "gather: stays in the
  bunker"). Hub guests of a host who JOINED a running raid get RAID_START with late=1.
- Crash "Unable to find instance ... is_inside_bunker" on Continue/New game after leaving a raid: player_get caches the
  last instance and only forgets it in obj_player_parent CleanUp, which does not run for an instance removed while
  deactivated -> hook [131] checks instance_exists(last_player).
- Crash in the Mods menu after a translation mod was deleted: mods_perform_event read .file_path of an undefined
  context (vanilla bug) -> hook [132] skips entries without a struct.
- Enemy callouts shown as keys (npc.bark.*) on a guest with a full-Russian translation mod: that mod replaces the
  language files (English master too), the game's own fallback can't help. Not ours (vanilla barks show the same).
- Stale Steam lobby: the host quit, Steam made the remaining guest the owner, an invite to it hung 30 s. The host
  writes lobby data zs_host; a guest whose lobby owner != zs_host leaves with a message; a guest leaves when the host
  leaves the lobby; the host drops members that left the lobby (their BYE is often lost: the P2P session closes right
  after sending it -> the puppet stood "breathing fast" until the timeout).
- F7 panel: drawn at Draw GUI End over the game's cursor -> the arrow is drawn again on top. Game input muted while
  it is open: update_keyboard_input (like the Steam overlay case), obj_gamepad actions reset (like the radial menu),
  ui_handle_input gets no pointer (hooks 133-135).
- Bunker weather differed between players: the session host's bunker sends time + weather (every 5 s too); a guest
  in its bunker while the host is in the hub follows it (coop_world_hub_slave), applies only changed JSON.
- [X] give in the bunker: the item travels as JSON and is placed with class_loot_grid(8,11).TryPlace like
  inventory_add_item (bag at the feet when full); waits while the receiver's inventory layer is open.
- "Invite friend again" -> "Invite friend"; mod version in the main menu corner.
Tests: hostjoin (guest raids alone, host's train to map 3 lands in map 1, owner stays slot 1), gather (3 players,
slot 2 walks out of the circle and stays), lobby checks bunker weather + bunker give. regress.py does NOT install the
build: run tools/install_test.sh first (a test once ran on the installer's old build). Test windows: a 2x2 grid right
of the Claude window (tools/env.sh WIN_A..D).

## 2026-11-07 - v2.0.0 (protocol COOP_VERSION 9, up to 8 players, hooks up to [149])
Branch dev-2.0.0; built and tested locally, the user publishes it. Every feature of the approved roadmap
(memory coop-roadmap-2026-11, items 1-48 except 15 = delta snapshots, left out) has its own regress scenario.
- COOP_MAX_PLAYERS 8 (slots 0..7); tools/test4.sh runs 3-8 instances, regress.py windows A..H (octo = 8 windows,
  ~2.4 GB each). New modules: backup, report, files, conn, group, lobby, chat, wheel, extract, spectate, fallen,
  trade, gear, voice (+ radio item), rejoin, events, quests, barquests, arena, migrate, look. New events:
  obj_coop Other_73 (audio recording), Other_74 (audio playback).
- New messages 68 FILES .. 85 ARENA (82 VOICE is unreliable). The roster carries every player's address (IP or
  Steam id) so the session can move: on host BYE/timeout every guest picks the same successor (Steam lobby owner,
  else the lowest remaining slot). After a TIMEOUT the hand-over waits 30 s for the old host first - a timeout may
  be our own link (the reconnect blackout test used to split the session). Tests migrate, migrate_crash.
- "Ghost" enemies on a bad net (item 1): the owner deactivates off-screen NPCs and stopped streaming them while
  1.4 roaming kept moving them -> deactivated owner NPCs' positions are streamed too; test check "NPC DRIFT".
- Hooks [136]/[137]: safe read of mods_enabled.json (a cut file crashed obj_mods "read from outside the buffer" -
  vanilla bug, user saw it). [138] friendly-fire damage share, [139]/[140] group extraction, [141]/[142] spectate,
  [143] coop_radio_inject after the game data loads, [144] quick-slot use toggles the radio in hand, [145]-[147]
  shared quest kills and reward split, [148] db_force_save -> coop_arena_before_save (the own weapon is back
  before any save), [149] player_damage: lethal hit in the arena (the bunker clamps hp at 10, so nobody died).
- Radio (user design: never found, no "easy mode"): own category coop_radio, in no loot table; the barman sells it
  from trader item level 400 (= Loners reputation, not character level) for 12 000; workshop recipe (module 12,
  level 1) via global.__Mods_Crafting_Recipes + lista_craft. Quick slots accept it because the installer adds
  "coop_radio" to the categories in inventory_exec_player_gear.ui. Talk on the radio only while it is in hand,
  hearing needs one in the inventory; otherwise proximity voice. The microphone is opened only while needed.
- Quests: global.quest_database + quest_create_kill; the barman's quest_array (speaker "bar"); Alarm_10 reads back
  only quest_max saved slots, so the group tasks pushed after them are never saved. Trader item "level" is faction
  reputation. NPCs set hp in Create (no hp_max): apply hp buffs at creation.
- Raid events: the survivor quest giver must carry coop_replica on guests (its AI walked on the host only); the
  event area is activated (instance_activate_region) and enemies beyond 1440 px don't block the wave end.
- Shooting range = hub x >= 1278 (box 1278-1930 x 690-835): no ammo is used there - the arena lives in it.
- UTMT compiler: no trailing commas in array/struct literals, no accessor on a call result (f()[i]), fa_none /
  fa_directory unknown (use 0 / 16), a #macro line must not end with a comment. Bash heredocs mangle backslashes in
  Python helpers - write them with the Write tool.
- Test windows share coop_local.ini with real play: tests restore what they change; the rejoin and tutorial
  writes are off in test mode.
- UI: compact group panel top right, aiming hides the HUD (HP returns for a few seconds after a hit), welcome
  window (tutorial / later / never), F7 panel 0.72 alpha. 201 new texts translated (tools/lang_extract.py: 0).
- tools/regress_full.sh got a "2.0.0 FEATURES" phase (and trade/extract/migrate on the bad network).
- Ordered run by session size (tools/regress_players.sh, 2026-11-08): every scenario with 1..8 players; a two- or
  three-player scenario runs as "name@N" with extra players (scenario bystand: follows the host, extracts with it,
  leaves the extraction screen; -coop_wait_slots N makes it say hello only after slots 1..N-1 are taken - files
  coop_conn_<slot>.flag). Found and fixed:
  * Group scaling was recomputed for the host's train joining a guest's raid (and resent while other players
    connected), so with 4 players the latecomers generated another map than the guest who started alone. Now
    coop_take_seed freezes it (_c.raid_group), RAID_STATE carries it (2 x f32), coop_group_factor uses it in room1.
  * Windows UDP: every packet sent to a closed port (crashed player) comes back as an error that stalls the socket's
    receiving - 5 players, one killed: 20 s pings and 90 % loss for the rest until ~25 s after its timeout. A peer
    silent for COOP_QUIET_MS (3 s) gets one packet a second; when it answers the queued reliable packets go at once.
  * An NPC killed while deactivated on the owner (roaming fights) keeps existing with hp <= 0 until activation: no
    snapshot (hp > 0 only) and no death message (sent in Destroy) -> a live ghost on every replica. The far tick now
    sends NPC_DIE for those and drops them from npc_by_nid.
  * Test lessons: test clocks of two windows start when each one's map is ready - seconds apart with 5+ windows, keep
    steps 300+ ticks apart; the game moves the host's spawn once its map is in, so guests must follow the host again;
    "nearest teammate" picks a bystander - tests use coop_test_partner() / sim_give_to; NPC DRIFT only counts a
    replica off in two checks in a row (a running NPC was 164 px off once under load).
- Code review of the 2.0.0 modules (2026-11-08 night, after soak 31 min / 4 players clean: 0 errors, +3 MB). Fixed:
  * Trade: a side committed as soon as it was ready on matching signatures - a stale view (the other changed its
    offer at the same moment) handed its stacks over and got nothing back. Now two-phase: op 6 "lock" = both
    signature + how many offer/ready messages (op 2/3) it has seen from us; hand-over only when locked AND holding a
    lock of the other that saw all of ours. Locked = no input, no Esc (10 s escape). Offered stacks that left the
    inventory are pruned; crossing requests (both pressed U) open the trade. Test trade_race.
  * Fallen teammate's things went back as { item, quantity, durability 100 } - weapons lost their data/attachments
    and the full count was sent even when the taker had fewer (inventory_remove_item returns nothing). Now
    coop_fallen_pull takes the real stacks (loot_duplicate, split, equipment event).
  * Host migration (UDP): the successor is picked once; if it was gone too the others said hello to it forever.
    pick() returns the whole order (rest), coop_migrate_step tries the next after 15 s. Test migrate_two (4 players:
    host + slot 1 crash together). Steam migration also refreshes the lobby's zs_name.
  * Raid event + world handoff: the new owner's replica of the survivor became an AI NPC (take_over) and its wave
    counter was 0 (the event finished at once). coop_event_giver / coop_event_npc go with the NPC spawn data,
    take_over keeps the survivor a replica, coop_events_on_take_over adopts the wave. Test event_handoff (3 players).
  * Voice: turning voice off / the session ending left the microphone recording; a speaker's queue over 8 packets
    (~0.8 s) drops new packets (a lag burst delayed the voice for good).
  * Quest items in containers: one we took and put back stayed in coop_q_taken -> a teammate's next change deleted it.
  * One-click update: update.cmd had the full installer path - cmd.exe reads .cmd in the OEM code page, a Cyrillic
    Windows user name broke it. It now does cd /d "%~dp0" and a relative path.
  * Mods menu line said "co-op for up to 4 players".
  * Trade, later finds: no input once our stacks went (prune after the hand-over sent op 2, which could un-ready the
    other side in the same packet batch as our lock -> it never handed its part over); the hand-over waits for the
    inventory screen to be closed (it writes its own copy back on close = duplicated stacks); an offered stack moved
    in the inventory is found by item + amount. trade_race needs latency (-coop_netsim 150 on the host): on
    localhost the whole ready exchange fits in 3 frames.
  * Saves without the mod: vanilla reads every active quest's definition on each kill (kill_check_quest) and in the
    quest log - an accepted barman group task in the quest slots crashed the game without the mod / with v1.2.0
    (trace_error = show_error fatal). Hooks [150] quest_save (coop_quest_state_for_save: an empty slot; the tasks
    under db "general" key "coop"/"barq") and [151] quest_load (coop_barq_define first, then the saved tasks into
    free slots). Unknown ITEMS are fine: saveslot_reload -> loot_array_update_to_zs32 deletes items missing from
    item_data in the inventory and every stash chest (so the radio just disappears without the mod); difficulty
    load reads known keys only; quest_line_progress is only looked up by id.
