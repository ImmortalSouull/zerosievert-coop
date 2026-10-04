# ZERO Sievert CO-OP

**Русский** · [English](#english)

Неофициальный мод, который добавляет в **ZERO Sievert** кооператив **до 4 игроков**: совместные рейды через
Steam или по IP, общий мир, ранения и поднятие напарников, расширенную настройку сложности.

> Мод сделан с помощью ИИ (Claude) по дизайну игрока. Он не связан с разработчиками игры
> (CABO Studio / Modern Wolf). Файлы игры здесь не хранятся и не распространяются: релиз содержит
> патч и установщик, которые применяются к вашей собственной копии игры.

**Текущая версия: v1.0.0** — скачать в разделе [Releases](../../releases). Описания всех версий,
списки исправлений и известных багов — в [docs/releases](docs/releases).

## Возможности
- Кнопка «Кооператив» в главном меню и меню паузы (или F7): игра в Steam (приглашение до 3 друзей) или по IP.
- Совместные рейды: игроки едут за хостом на ту же карту или присоединяются к уже идущему рейду.
- Одинаковая карта у всех; враги, выстрелы, гранаты, трупы, лут в реальном времени, выброшенные
  предметы, двери, время суток, погода и выбросы синхронизированы.
- Ранение вместо смерти и поднятие напарника (без предметов / бинтом / аптечкой).
- Опыт, квесты и репутация засчитываются тому, кто убил.
- Метки (средняя кнопка мыши), передача предметов напарнику (X), напарники на карте КПК.
- Анимации, фонари, лазеры и звуки напарников видны и слышны.
- Если хост эвакуировался — мир рейда подхватывает следующий игрок; после обрыва связи мод
  переподключается сам.
- Баланс под группу: больше врагов и (по желанию) больше здоровья врагов за каждого игрока.
- Без ограничения 60 FPS: плавная картинка с частотой монитора при той же скорости игры.
- Геймпад в меню кооператива и при поднятии; проверка обновлений мода.

## Установка
1. Нужна ZERO Sievert 1.3.3 (Steam build 25269476). Закройте игру.
2. Скачайте `ZS-Coop-v<версия>.zip` из последнего [релиза](../../releases/latest), распакуйте и запустите
   `install.bat` — он сам найдёт игру, сделает резервную копию и пропатчит вашу копию игры.
3. Удаление: `uninstall.bat` или Steam → «Проверить целостность файлов».
4. В игре — «Кооператив» в главном меню (или F7). Версии мода у всех игроков должны совпадать.

Подробная инструкция — `README.txt` в архиве релиза.

## Для разработчиков
- `mod/gml` — код мода (GML), `mod/hooks.txt` — точки встраивания в код игры.
- Сборка: UndertaleModTool CLI (`tools/build.sh`, `tools/utmt/build.csx`) из вашей собственной копии
  `data.win`; релиз — xdelta-патч (`tools/make_dist.sh`).
- Тесты: `python tools/regress.py all` (сценарии на 2 и 4 окнах игры, все карты), `python tools/soak.py`.
- Журнал разработки и все найденные особенности движка — `MODLOG.md`.

Сторонние инструменты: UndertaleModTool (Underminers), xdelta3 (GPL v2, см. THIRD_PARTY.txt в релизе).

---

<a name="english"></a>
# ZERO Sievert CO-OP (English)

An unofficial mod that adds co-op for **up to 4 players** to **ZERO Sievert**: joint raids via Steam or by
IP, a shared world, getting downed and reviving teammates, extended difficulty settings.

> The mod was made with AI (Claude) to the player's design. It is not affiliated with the game's developers
> (CABO Studio / Modern Wolf). No game files are stored or distributed here: a release contains a patch and
> an installer that are applied to your own copy of the game.

**Current version: v1.0.0** — download it from [Releases](../../releases). Notes for every version (what's
new, fixes, known bugs; Russian and English) are in [docs/releases](docs/releases).

## Features
- A "Co-op" button in the main menu and pause menu (or F7): play via Steam (invite up to 3 friends) or by IP.
- Joint raids: players follow the host to the same map or join a raid already in progress.
- Identical map for everybody; enemies, shots, grenades, corpses, live loot, dropped items, doors,
  time of day, weather and emissions are synchronized.
- Down instead of death and reviving teammates (no items / bandage / medkit).
- XP, quests and reputation go to whoever made the kill.
- Ping markers (middle mouse), giving items to a teammate (X), teammates on the PDA map.
- Teammates' animations, flashlights, lasers and sounds are visible/audible.
- If the host extracts, the next player takes the raid's world over; after a connection drop the mod
  reconnects by itself.
- Group balance: more enemies and (optionally) tougher enemies for every extra player.
- No 60 FPS cap: smooth picture at your monitor's refresh rate with unchanged game speed.
- Gamepad support in the co-op menu and when reviving; mod update check.

## Installation
1. ZERO Sievert 1.3.3 (Steam build 25269476) is required. Close the game.
2. Download `ZS-Coop-v<version>.zip` from the latest [release](../../releases/latest), unpack it and run
   `install.bat` — it finds the game by itself, makes a backup and patches your own copy of the game.
3. Uninstall: `uninstall.bat` or Steam → "Verify integrity of game files".
4. In game: "Co-op" in the main menu (or F7). Everybody must use the same mod version.

Full instructions: `README.txt` in the release archive.

## For developers
- `mod/gml` — mod code (GML), `mod/hooks.txt` — patch points in the game's code.
- Build: UndertaleModTool CLI (`tools/build.sh`, `tools/utmt/build.csx`) from your own copy of
  `data.win`; a release is an xdelta patch (`tools/make_dist.sh`).
- Tests: `python tools/regress.py all` (scenarios on 2 and 4 game windows, every map), `python tools/soak.py`.
- Development log and every engine quirk found — `MODLOG.md` (English).

Third-party tools: UndertaleModTool (Underminers), xdelta3 (GPL v2, see THIRD_PARTY.txt in the release).
