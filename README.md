# ZERO Sievert CO-OP

**English** · [Русский](README.ru.md) · [Polski](README.pl.md)

An unofficial mod that adds co-op for **up to 8 players** to **ZERO Sievert**: joint raids via Steam or by
IP, a shared world, getting downed and reviving teammates, extended difficulty settings.

> The mod was made with AI (Claude) to the player's design. It is not affiliated with the game's developers
> (CABO Studio / Modern Wolf). No game files are stored or distributed here: a release contains a patch and
> an installer that are applied to your own copy of the game.

**Current version: v2.0.1** — download it from [Releases](../../releases). Notes for every version (what's
new, fixes, known bugs) are in [docs/releases](docs/releases).

## Features
- A "Co-op" button in the main menu and pause menu (or F7): play via Steam (invite up to 7 friends) or by IP.
- Joint raids: a gathering zone with a countdown along the host's train — whoever stands in it goes along;
  the others join the running raid later (by train or from the panel). Never two separate raids.
- Identical map for everybody; enemies, shots, grenades, corpses, live loot, dropped items, doors,
  time of day, weather and emissions are synchronized. The new enemy AI (game 1.4) sees, hears and fights
  every player.
- The bunker as a lobby: players see each other in their hubs, and "Visit" shows a friend's bunker (their
  modules and benches) while your stash, items and save stay yours. The bunker's weather is the host's.
- Down instead of death and reviving teammates: pick the item by its icon (no items / bandage / medkit)
  with the HP and seconds shown under it.
- [X] gives an item to a teammate, in a raid and in the bunker; trading between players (U), a teammate's gear (I).
- The session survives the host leaving: another player takes it over. Back into the session after a crash.
- Proximity voice chat and a radio item with channels; text chat (Enter) and a command wheel (Z).
- Group panel, group extraction with a raid summary, spectating after the final death, crawling and dragging
  a downed teammate.
- Shared quest progress with the reward split by work, group tasks at the barman, raid events, an arena in the
  bunker, personal loot and friendly fire settings, appearance synced to teammates.
- Lobby management (kick, friends / invite / public), a list of open games and friends hosting, mod/file check.
- Save backups, separate co-op characters, one-click update, "Collect logs", streamer mode, a co-op tutorial.
- Ping markers with the middle mouse button (a second click on the same spot removes yours), teammates on the
  PDA map.
- XP, quests and reputation go to whoever made the kill.
- Teammates' animations, flashlights, lasers and sounds are visible/audible.
- If the host extracts, the next player takes the raid's world over and others can still join that raid;
  after a connection drop the mod reconnects by itself.
- Group balance: more enemies and (optionally) tougher enemies for every extra player.
- No 60 FPS cap: smooth picture at your monitor's refresh rate with unchanged game speed.
- The mod speaks every language of the game (13) and follows the language set in the game.
- Co-op interface in the game's style; gamepad support in the co-op menu and when reviving; mod update check.

## Installation
1. ZERO Sievert 1.4.13 (Steam build 26535665) is required. Close the game.
2. Download `ZS-Coop-v<version>.zip` from the latest [release](../../releases/latest), unpack it and run
   `install.bat` — it finds the game by itself, makes a backup and patches your own copy of the game.
3. Uninstall: `uninstall.bat` or Steam → "Verify integrity of game files".
4. In game: "Co-op" in the main menu (or F7). Everybody must use the same mod version. The main menu shows the
   mod version in its corner.

Full instructions: `README.txt` in the release archive.

## For developers
- `mod/gml` — mod code (GML), `mod/hooks.txt` — patch points in the game's code.
- Build: UndertaleModTool CLI (`tools/build.sh`, `tools/utmt/build.csx`) from your own copy of
  `data.win`; a release is an xdelta patch (`tools/make_dist.sh`).
- Tests: `python tools/regress.py all` (scenarios on 1–8 game windows, every map), `python tools/soak.py`.
- Development log and every engine quirk found — `MODLOG.md`.

Third-party tools: UndertaleModTool (Underminers), xdelta3 (GPL v2, see THIRD_PARTY.txt in the release).

## License
The mod's code is released under the [MIT License](LICENSE): you may use, modify and distribute it freely, keeping the copyright notice.
The license covers this mod's code only. ZERO Sievert itself and the fragments of its code in `mod/hooks.txt` (anchors for the patches) belong to their owners; xdelta3 shipped in releases keeps its own GPL v2 license.
