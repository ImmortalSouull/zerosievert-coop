# ZERO Sievert CO-OP

**Русский** · [English](#english)

Неофициальный мод, который добавляет в **ZERO Sievert** кооператив вдвоём: совместные рейды через Steam
или по IP, общий мир, ранения и поднятие напарника, расширенную настройку сложности.

> Мод сделан с помощью ИИ (Claude) по дизайну игрока. Он не связан с разработчиками игры
> (CABO Studio / Modern Wolf). Файлы игры здесь не хранятся и не распространяются: релиз содержит
> патч и установщик, которые применяются к вашей собственной копии игры.

**Текущая версия: v0.4.0** — скачать в разделе [Releases](../../releases). Описания всех версий,
списки исправлений и известных багов — в [docs/releases](docs/releases).

## Возможности
- F7 в меню или бункере: создать игру в Steam (приглашение друга) или по IP (UDP 47777).
- Совместные рейды: гость едет за хостом на ту же карту или присоединяется к уже идущему рейду.
- Одинаковая карта у обоих; враги, выстрелы, гранаты, трупы, лут в реальном времени, выброшенные
  предметы, двери, время суток, погода и выбросы синхронизированы.
- Ранение вместо смерти и поднятие напарника (без предметов / бинтом / аптечкой).
- Опыт, квесты и репутация засчитываются тому, кто убил.
- Напарник на карте КПК, его ник и HP видны всегда.
- Новые параметры сложности: вкладка «Co-op», количество врагов и аномалий.
- Без ограничения 60 FPS: плавная картинка с частотой монитора (165 Гц и т.д.) при той же скорости игры.
- Анимации, фонарик, лазер и звуки напарника видны и слышны другому игроку.

## Установка
1. Нужна ZERO Sievert 1.3.3 (Steam build 25269476). Закройте игру.
2. Скачайте `ZS-Coop-v<версия>.zip` из последнего [релиза](../../releases/latest), распакуйте и запустите
   `install.bat` — он сам найдёт игру, сделает резервную копию и пропатчит вашу копию игры.
3. Удаление: `uninstall.bat` или Steam → «Проверить целостность файлов».
4. В игре — F7 в главном меню или бункере. Версии мода у обоих игроков должны совпадать.

## Для разработчиков
- `mod/gml` — код мода (GML), `mod/hooks.txt` — точки встраивания в код игры.
- Сборка: UndertaleModTool CLI (`tools/build.sh`, `tools/utmt/build.csx`) из вашей собственной копии
  `data.win`; релиз — xdelta-патч (`tools/make_dist.sh`).
- Журнал разработки и все найденные особенности движка — `MODLOG.md`.

Сторонние инструменты: UndertaleModTool (Underminers), xdelta3 (GPL v2, см. THIRD_PARTY.txt в релизе).

---

<a name="english"></a>
# ZERO Sievert CO-OP (English)

An unofficial mod that adds two-player co-op to **ZERO Sievert**: joint raids via Steam or by IP, a shared
world, getting downed and reviving your partner, extended difficulty settings.

> The mod was made with AI (Claude) to the player's design. It is not affiliated with the game's developers
> (CABO Studio / Modern Wolf). No game files are stored or distributed here: a release contains a patch and
> an installer that are applied to your own copy of the game.

**Current version: v0.4.0** — download it from [Releases](../../releases). Notes for every version (what's
new, fixes, known bugs; Russian and English) are in [docs/releases](docs/releases).

## Features
- F7 in the main menu or bunker: host via Steam (invite a friend) or by IP (UDP 47777).
- Joint raids: the guest follows the host to the same map or joins a raid already in progress.
- Identical map for both players; enemies, shots, grenades, corpses, live loot, dropped items, doors,
  time of day, weather and emissions are synchronized.
- Down instead of death and reviving the partner (no items / bandage / medkit).
- XP, quests and reputation go to whoever made the kill.
- Partner on the PDA map; their name and HP are always visible.
- New difficulty options: a "Co-op" tab, enemy count and anomaly count.
- No 60 FPS cap: smooth picture at your monitor's refresh rate (165 Hz etc.) with unchanged game speed.
- The partner's animations, flashlight, laser and sounds are visible/audible to the other player.

## Installation
1. ZERO Sievert 1.3.3 (Steam build 25269476) is required. Close the game.
2. Download `ZS-Coop-v<version>.zip` from the latest [release](../../releases/latest), unpack it and run
   `install.bat` — it finds the game by itself, makes a backup and patches your own copy of the game.
3. Uninstall: `uninstall.bat` or Steam → "Verify integrity of game files".
4. In game: press F7 in the main menu or bunker. Both players must use the same mod version.

## How to play
- Host: F7 → "Host via Steam" → the Steam overlay opens → invite your friend. The friend accepts the
  invite (or uses "Join game" in the Steam friends list).
- Fallback: host "Host by IP" (UDP port 47777), friend "Join by IP" (Radmin VPN / ZeroTier / port forwarding).
- Each player loads their own save. When the host goes into a raid, a guest waiting in the bunker
  follows automatically; a guest can also join a running raid via F7 → "Join raid".
- Down: lethal damage while your partner is in the raid downs you. Revive: walk up to the partner,
  press E, pick no items / bandage / medkit, press E again.
- Settings: Pause → Settings → Difficulty → "Co-op" tab. Frame rate: F7 → "Frame rate" or Ctrl+Alt+U.
- The mod's UI follows the game language (Russian or English).

## For developers
- `mod/gml` — mod code (GML), `mod/hooks.txt` — patch points in the game's code.
- Build: UndertaleModTool CLI (`tools/build.sh`, `tools/utmt/build.csx`) from your own copy of
  `data.win`; a release is an xdelta patch (`tools/make_dist.sh`).
- Development log and every engine quirk found — `MODLOG.md` (English).

Third-party tools: UndertaleModTool (Underminers), xdelta3 (GPL v2, see THIRD_PARTY.txt in the release).
