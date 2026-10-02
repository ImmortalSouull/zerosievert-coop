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
