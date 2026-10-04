ZERO Sievert CO-OP (неофициальный мод) — версия см. mod_info.json
English version: see the ENGLISH section below.

ОБНОВЛЕНИЕ: просто запустите install.bat новой версии поверх старой (у всех игроков одна версия!).
=====================================================================

Совместные рейды до 4 игроков + ранения/поднятие + расширенная настройка сложности.
Мод сделан с помощью ИИ (Claude) по заказу и дизайну игрока. Не связан с разработчиками игры.

УСТАНОВКА (каждому игроку)
1. Закройте игру.
2. Распакуйте архив в любую папку и запустите install.bat.
   Установщик сам найдёт игру, сделает резервную копию (папка coop_backup в папке игры)
   и применит патч к ВАШИМ файлам игры. Файлы игры в архиве не распространяются.
3. Удаление: uninstall.bat (или Steam > Свойства > Проверить целостность файлов).
Мод собран под ZERO Sievert 1.3.3 (Steam build 25269476). После обновления игры
установщик откажется работать, пока не выйдет новая версия мода (мод сам сообщит о ней в меню).

КАК ИГРАТЬ
- Главное меню или меню паузы > "Кооператив" (или клавиша F7) — панель кооператива.
- Хост: "Создать игру в Steam" -> откроется оверлей Steam -> пригласите до 3 друзей.
  Друзья принимают приглашение в Steam или жмут "Присоединиться к игре" у хоста в списке друзей.
- Запасной вариант: "Создать игру по IP" у хоста (UDP-порт 47777) и
  "Подключиться по IP" у друзей (через Radmin VPN / ZeroTier / проброс порта).
- Каждый загружает СВОЁ сохранение. Когда хост отправляется в рейд, игроки в бункере
  автоматически едут за ним на ту же карту (тот же сид — одинаковая карта).
- У каждого свой инвентарь, бункер и прогресс.
- Панель: мышь, стрелки + Enter, геймпад (крестовина + A, B — закрыть).

БУНКЕР КАК ЛОББИ И "В ГОСТИ"
- Пока вы в хабе, вы видите напарников, которые тоже в своём хабе: они ходят рядом с вами, видны
  ники. Торговцы, схрон и квесты у каждого свои.
- Панель кооператива > "В гости к <ник>": вы окажетесь в комнате бункера друга - его модули,
  кровать, кухня, станки. Схрон, вещи и сохранение остаются вашими; ставить или улучшать модули
  друга нельзя. Вернуться: панель > "Вернуться в свой бункер" или просто выйти из бункера.

В РЕЙДЕ
- Метка: средняя кнопка мыши (на геймпаде — нажатие правого стика) ставит метку под прицелом,
  её видят все с ником и расстоянием 10 секунд.
- Передать предмет: подойдите к напарнику и нажмите X, выберите предмет из инвентаря —
  он окажется в мешке у ног напарника.
- Ник и HP напарников видны всегда; если напарник за краем экрана — стрелка с расстоянием;
  на карте КПК напарники отмечены цветными метками.
- Видны анимации напарников (лечение, еда, граната, осмотр оружия), их фонари и лазеры,
  слышны их шаги, перезарядка, затвор.

РАНЕНИЕ И ПОДНЯТИЕ
- Смертельный урон, пока в рейде есть стоящий на ногах напарник, роняет вас вместо смерти.
- 1-е ранение: таймер N секунд, можно стрелять из пистолета, можно медленно ползти.
- 2-е ранение: таймер N/2, стрелять нельзя, HP после поднятия x0.6.
- 3-е ранение — смерть. Счётчик сбрасывается в начале каждого рейда.
- Поднять: подойдите к раненому, нажмите E (на геймпаде — кнопка взаимодействия), выберите
  иконку предмета (крестик - без предметов, бинт, аптечка; под иконкой - сколько HP и секунд)
  колесом мыши или стрелками и снова E. Время зависит от категории (10 / 7 / 5 с по
  умолчанию), количество HP — от конкретного предмета. Пока вас поднимают, таймер стоит.
- Если ранены все — все погибают. Если погиб один, остальных раненых ещё могут поднять.
- Лежащего не добивают: пока вы ранены, урон не проходит, а враги переключаются на других.

НАСТРОЙКИ СЛОЖНОСТИ
Пауза > Настройки > Difficulty:
- вкладка "Co-op": ранение вместо смерти, таймер, множитель HP, время поднятия, огонь по союзнику,
  дополнительные враги и здоровье врагов за каждого игрока сверх одного;
- вкладка "Enemies": добавлены "Количество врагов" и "Количество аномалий".
В рейде правила кооператива берутся у хоста.

ЧТО СИНХРОНИЗИРУЕТСЯ
- Карта: здания, декор, машины, аномалии и артефакты одинаковые у всех при любых настройках
  графики; мир строится по настройкам сложности хоста. Мод сам сверяет карты и предупредит,
  если они вдруг различаются.
- Время суток, погода и выбросы.
- Враги, выстрелы, плевки гулей и прочие снаряды мутантов, гранаты, трупы, аирдропы.
- Убийства, опыт, прогресс квестов и репутация засчитываются тому, кто убил.
- Лут в ящиках и трупах — общий и в реальном времени.
- Выброшенные на землю предметы, открытые ключом двери.

ВХОД В ИДУЩИЙ РЕЙД, ВЫХОД И ПОТЕРЯ СВЯЗИ
- Если хост уже в рейде, игрок в бункере выбирает в панели "Присоединиться к рейду".
- Если хост эвакуировался, а остальные остались, мир рейда продолжает жить общим: его
  подхватывает следующий игрок. К такому рейду тоже можно присоединиться из бункера
  (игроку, который подключился к сессии позже того, кто держит рейд).
- Если связь пропала, мод сам переподключится и вернёт вас в тот же рейд.

ЧАСТОТА КАДРОВ
- Игра не ограничена 60 FPS: кадры идут с частотой монитора, скорость игры не меняется.
  Переключить: панель кооператива > "Частота кадров" или Ctrl+Alt+U. Работает и в одиночной игре.

ПАУЗА
- В совместном рейде пауза не останавливает мир для остальных: ваш персонаж "отходит"
  (его не видят враги и не могут ранить), а мир продолжает жить.

ИЗВЕСТНЫЕ ОГРАНИЧЕНИЯ
- Если хост полностью вышел из игры, сессия заканчивается: остальные доигрывают рейд каждый сам.
- Версии мода у всех должны совпадать (мод предупредит).
- При ошибке игры лог: %LOCALAPPDATA%\ZERO_Sievert\coop_solo.log - пришлите его автору.

---------------------------------------------------------------------
ENGLISH
ZERO Sievert CO-OP (unofficial mod) - version: see mod_info.json

UPDATE: just run install.bat of the new version over the old one (all players need the same version!).

Joint raids for up to 4 players + down/revive system + extended difficulty settings.
Made with AI (Claude) to the player's design. Not affiliated with the game's developers.
The mod's UI follows the game language (Russian or English).

INSTALLATION (every player)
1. Close the game.
2. Unpack the archive anywhere and run install.bat.
   The installer finds the game, makes a backup (coop_backup folder in the game folder) and patches
   YOUR game files. No game files are distributed in the archive.
3. Uninstall: uninstall.bat (or Steam > Properties > Verify integrity of game files).
Built for ZERO Sievert 1.3.3 (Steam build 25269476). After a game update the installer refuses to
work until a new mod version is out (the mod tells you about it in the menu).

HOW TO PLAY
- Main menu or pause menu > "Co-op" (or the F7 key) - the co-op panel.
- Host: "Host via Steam" -> the Steam overlay opens -> invite up to 3 friends.
  Friends accept the invite in Steam or use "Join game" on the host in the Steam friends list.
- Fallback: "Host by IP" for the host (UDP port 47777) and "Join by IP" for the friends
  (via Radmin VPN / ZeroTier / port forwarding).
- Everyone loads THEIR OWN save. When the host goes into a raid, players waiting in the bunker
  follow automatically to the same map (same seed - identical map).
- Everyone keeps their own inventory, bunker and progress.
- Panel: mouse, arrows + Enter, gamepad (d-pad + A, B closes).

THE BUNKER AS A LOBBY AND VISITS
- While you are in the hub you see the teammates who are in their hub too: they walk around next to
  you with their names shown. Traders, stash and quests stay your own.
- Co-op panel > "Visit <name>'s bunker": you are taken to your friend's bunker room - their modules,
  bed, kitchen, benches. Your stash, items and save stay yours; you can't install or upgrade the
  friend's modules. Go back: panel > "Go back to your bunker", or just leave the bunker.

IN A RAID
- Ping: the middle mouse button (gamepad: right stick click) marks the spot under your aim for
  everybody for 10 seconds, with your name and the distance.
- Give an item: stand next to a teammate, press X and pick an item from your inventory - it appears
  in a bag at the teammate's feet.
- Teammates' names and HP are always visible; an arrow with the distance points at teammates off
  screen; the PDA map shows them with coloured markers.
- You see your teammates' animations (healing, eating, grenades, weapon inspection), their flashlights
  and lasers, and hear their footsteps, reloads and bolts.

DOWN AND REVIVE
- Lethal damage while a teammate on their feet is in the raid downs you instead of killing you.
- 1st down: N-second timer, you can shoot a pistol and crawl slowly.
- 2nd down: N/2 timer, no shooting, HP after revive x0.6.
- 3rd down - death. The counter resets at the start of every raid.
- Revive: walk up to a downed teammate, press E (gamepad: interact), pick an item icon (a cross for
  "no items", bandage, medkit; the HP and seconds are shown under each) with the mouse wheel or the
  arrows and press E again. The time depends on the category (10 / 7 / 5 s by default), the HP on the
  exact item. The timer stops while you are being revived.
- If everybody is down, everybody dies. If one player dies, the others can still revive each other.
- A downed player is not finished off: damage doesn't go through and enemies switch to the others.

DIFFICULTY SETTINGS
Pause > Settings > Difficulty:
- "Co-op" tab: down instead of death, timer, HP multiplier, revive time, friendly fire, extra enemies and
  extra enemy health for every player beyond the first;
- "Enemies" tab: added "Enemy count" and "Anomaly count".
In a raid the co-op rules come from the host.

WHAT IS SYNCHRONIZED
- Map: buildings, decor, cars, anomalies and artifacts are identical for everybody with any graphics
  settings; the world uses the host's difficulty settings. The mod compares the maps and warns if
  they differ.
- Time of day, weather and emissions.
- Enemies, shots, ghoul spit and other mutant projectiles, grenades, corpses, airdrops.
- Kills, XP, quest progress and reputation go to whoever made the kill.
- Loot in containers and corpses is shared and live.
- Items dropped on the ground, doors opened with a key.

JOINING, LEAVING, LOST CONNECTION
- If the host is already in a raid, a player in the bunker picks "Join raid" in the panel.
- If the host extracts while the others stay, the raid keeps one shared world: the next player
  takes it over. Such a raid can be joined from the bunker too (by a player who joined the session
  later than the one holding the raid).
- If the connection drops, the mod reconnects by itself and puts you back into the same raid.

FRAME RATE
- No 60 FPS cap: the game runs at your monitor's refresh rate, the game speed doesn't change.
  Switch: co-op panel > "Frame rate" or Ctrl+Alt+U. Works in single player too.

PAUSE
- In a shared raid the pause doesn't stop the world for the others: your character "steps out"
  (enemies don't see it and can't hurt it), and the world goes on.

KNOWN LIMITATIONS
- If the host quits the game completely, the session ends: everyone finishes the raid on their own.
- Everybody must use the same mod version (the mod will tell you).
- On a game error the log is in %LOCALAPPDATA%\ZERO_Sievert\coop_solo.log - send it to the author.

Credits: game by CABO Studio / Modern Wolf; UndertaleModTool (Underminers) used to build the patch;
xdelta3 (GPL) to apply it.
