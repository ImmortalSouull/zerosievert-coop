ZERO Sievert CO-OP (неофициальный мод) — версия см. mod_info.json
English version: see the ENGLISH section below.

ОБНОВЛЕНИЕ: просто запустите install.bat новой версии поверх старой (у обоих игроков одна версия!).
=====================================================================

Совместные рейды вдвоём + система ранений/поднятия + расширенная настройка сложности.
Мод сделан с помощью ИИ (Claude) по заказу и дизайну игрока. Не связан с разработчиками игры.

УСТАНОВКА (каждому из двух игроков)
1. Закройте игру.
2. Распакуйте архив в любую папку и запустите install.bat.
   Установщик сам найдёт игру, сделает резервную копию (папка coop_backup в папке игры)
   и применит патч к ВАШИМ файлам игры. Файлы игры в архиве не распространяются.
3. Удаление: uninstall.bat (или Steam > Свойства > Проверить целостность файлов).
Мод собран под ZERO Sievert 1.3.3 (Steam build 25269476). После обновления игры
установщик откажется работать, пока мод не будет пересобран.

КАК ИГРАТЬ
- В главном меню или в бункере нажмите F7 — панель кооператива.
- Хост: "Создать игру в Steam" -> откроется оверлей Steam -> пригласите друга.
  Друг принимает приглашение в Steam (игра запустится/подключится сама).
- Запасной вариант: "Создать игру по IP" у хоста (UDP-порт 47777) и
  "Подключиться по IP" у друга (через Radmin VPN / ZeroTier / проброс порта).
- Оба загружают СВОИ сохранения. Когда хост отправляется в рейд, гость, стоящий в бункере,
  автоматически едет за ним на ту же карту (тот же сид — одинаковая карта).
- Враги управляются хостом; у каждого свой инвентарь, бункер и прогресс.

РАНЕНИЕ И ПОДНЯТИЕ
- Смертельный урон, пока напарник в рейде, роняет вас вместо смерти.
- 1-е ранение: таймер N секунд, можно стрелять из пистолета, можно медленно ползти.
- 2-е ранение: таймер N/2, стрелять нельзя, HP после поднятия x0.6.
- 3-е ранение — смерть. Счётчик сбрасывается в начале каждого рейда.
- Панель F7: мышью или стрелками вверх/вниз + Enter, Esc - закрыть.
- Steam: можно также нажать "Присоединиться к игре" на хосте в списке друзей Steam.
- Поднять: подойдите к напарнику, нажмите E, выберите колесом мыши/стрелками
  "без предметов" / бинт / аптечку и снова E. Время зависит от категории
  (10 / 7 / 5 с по умолчанию), количество HP — от конкретного предмета.
  Пока вас поднимают, таймер стоит.
- Если ранены оба — оба погибают, рейд окончен.
- Лежащего не добивают: пока вы ранены, урон не проходит, а враги переключаются на напарника.

НАСТРОЙКИ СЛОЖНОСТИ
Пауза > Настройки > Difficulty:
- вкладка "Co-op": ранение вместо смерти, таймер, множитель HP, время поднятия,
  огонь по союзнику;
- вкладка "Enemies": добавлены "Количество врагов" и "Количество аномалий".
Остальное (лут, урон и здоровье врагов, потеря вещей при смерти, перманентная смерть и т.д.)
уже есть в игре. В рейде правила кооператива берутся у хоста.

ЧТО СИНХРОНИЗИРУЕТСЯ
- Карта: здания, декор, машины, аномалии и артефакты одинаковые у обоих при любых настройках
  графики; мир строится по настройкам сложности хоста. После загрузки мод сам сверяет карты и
  предупредит, если они вдруг различаются.
- Время суток, погода и выбросы - как у хоста.
- Враги (управляет хост), выстрелы, плевки гулей и прочие снаряды мутантов, гранаты, трупы, аирдропы.
- Убийства, опыт, прогресс квестов и репутация засчитываются тому, кто убил.
- Лут в ящиках и трупах - общий и в реальном времени, даже если оба открыли один ящик.
- Выброшенные на землю предметы, открытые ключом двери.
- Напарник: зелёная метка на карте КПК; ник и HP видны даже ночью и за крышами, а если он за
  краем экрана - стрелка с расстоянием.
- Анимации напарника: лечение, еда, питьё, курение, бросок гранаты, осмотр оружия, отдача;
  его фонарик и лазер светят у вас; слышны его шаги, перезарядка, затвор и т.п.

ЧАСТОТА КАДРОВ (новое в v0.4)
- Игра больше не ограничена 60 FPS: по умолчанию кадры идут с частотой монитора (144, 165, 240 Гц...).
  Скорость игры при этом не меняется - логика по-прежнему считается 60 раз в секунду, а между её
  шагами картинка плавно дорисовывается.
- Переключить: F7 -> "Частота кадров" (как монитор / 60 как в оригинале / 120 / 144 / 165 / 240 / 360)
  или Ctrl+Alt+U. Работает и в одиночной игре.

ВХОД В ИДУЩИЙ РЕЙД
- Если хост уже в рейде, гость в бункере нажимает F7 -> "Присоединиться к рейду".

ПАУЗА
- В совместном рейде Esc не останавливает мир для напарника: на паузе ваш персонаж "отходит"
  (его не видят враги и не могут ранить), а мир продолжает жить.

ИЗВЕСТНЫЕ ОГРАНИЧЕНИЯ
- Если хост покидает рейд, гость доигрывает рейд один: враги переходят на его собственный ИИ
  (те, что далеко от гостя, стоят на месте, пока он не подойдёт).
- Версии мода у обоих должны совпадать (v0.4 несовместима с v0.3 и ниже - мод предупредит).
- При ошибке игры лог: %LOCALAPPDATA%\ZERO_Sievert\coop_solo.log - пришлите его автору.

---------------------------------------------------------------------
ENGLISH
ZERO Sievert CO-OP (unofficial mod) - version: see mod_info.json

UPDATE: just run install.bat of the new version over the old one (both players need the same version!).

Two-player joint raids + down/revive system + extended difficulty settings.
Made with AI (Claude) to the player's design. Not affiliated with the game's developers.
The mod's UI follows the game language (Russian or English).

INSTALLATION (each of the two players)
1. Close the game.
2. Unpack the archive anywhere and run install.bat.
   The installer finds the game, makes a backup (coop_backup folder in the game folder) and patches
   YOUR game files. No game files are distributed in the archive.
3. Uninstall: uninstall.bat (or Steam > Properties > Verify integrity of game files).
Built for ZERO Sievert 1.3.3 (Steam build 25269476). After a game update the installer refuses to
work until the mod is rebuilt.

HOW TO PLAY
- Press F7 in the main menu or in the bunker - the co-op panel (mouse, or Up/Down + Enter, Esc closes).
- Host: "Host via Steam" -> the Steam overlay opens -> invite your friend.
  The friend accepts the invite in Steam (or uses "Join game" on the host in the Steam friends list).
- Fallback: "Host by IP" for the host (UDP port 47777) and "Join by IP" for the friend
  (via Radmin VPN / ZeroTier / port forwarding).
- Both load THEIR OWN saves. When the host goes into a raid, a guest waiting in the bunker follows
  automatically to the same map (same seed - identical map).
- Enemies are run by the host; each player keeps their own inventory, bunker and progress.

DOWN AND REVIVE
- Lethal damage while your partner is in the raid downs you instead of killing you.
- 1st down: N-second timer, you can shoot a pistol and crawl slowly.
- 2nd down: N/2 timer, no shooting, HP after revive x0.6.
- 3rd down - death. The counter resets at the start of every raid.
- Revive: walk up to your partner, press E, pick "no items" / bandage / medkit with the mouse wheel or
  arrows and press E again. The time depends on the category (10 / 7 / 5 s by default), the HP on the
  exact item. The timer stops while you are being revived.
- If both players are down, both die and the raid is over.
- A downed player is not finished off: while down, damage doesn't go through and enemies switch to
  the partner.

DIFFICULTY SETTINGS
Pause > Settings > Difficulty:
- "Co-op" tab: down instead of death, timer, HP multiplier, revive time, friendly fire;
- "Enemies" tab: added "Enemy count" and "Anomaly count".
Everything else (loot, enemy damage and health, item loss on death, permadeath etc.) is already in the
game. In a raid the co-op rules come from the host.

FRAME RATE (new in v0.4)
- No more 60 FPS cap: by default the game runs at your monitor's refresh rate (144, 165, 240 Hz...).
  The game speed doesn't change - the logic still runs 60 times per second and the picture is
  smoothly interpolated between its steps.
- Switch: F7 -> "Frame rate" (monitor / 60 like the original / 120 / 144 / 165 / 240 / 360)
  or Ctrl+Alt+U. Works in single player too.

JOINING A RAID IN PROGRESS
- If the host is already in a raid, the guest in the bunker presses F7 -> "Join raid".

WHAT IS SYNCHRONIZED
- Map: buildings, decor, cars, anomalies and artifacts are identical for both with any graphics
  settings; the world is built with the host's difficulty settings. After loading, the mod compares
  the maps and warns if they differ.
- Time of day, weather and emissions follow the host.
- Enemies (run by the host), shots, ghoul spit and other mutant projectiles, grenades, corpses, airdrops.
- Kills, XP, quest progress and reputation go to whoever made the kill.
- Loot in containers and corpses is shared and live, even if both opened the same container.
- Items dropped on the ground, doors opened with a key.
- Partner: green marker on the PDA map; name and HP visible even at night and under roofs, and an
  arrow with the distance when the partner is off-screen.
- Partner animations: healing, eating, drinking, smoking, grenade throw, weapon inspection, recoil;
  the partner's flashlight and laser light up on your screen; you hear their footsteps, reloading,
  bolt and so on.

PAUSE
- In a shared raid Esc doesn't stop the world for your partner: while paused your character "steps
  out" (enemies don't see it and can't hurt it), and the world goes on.

KNOWN LIMITATIONS
- If the host leaves the raid, the guest finishes it alone: enemies switch to the guest's own AI
  (those far from the guest stand still until the guest comes closer).
- Both players must use the same mod version (v0.4 is not compatible with v0.3 and older - the mod
  will tell you).
- On a game error the log is in %LOCALAPPDATA%\ZERO_Sievert\coop_solo.log - send it to the author.

Credits: game by CABO Studio / Modern Wolf; UndertaleModTool (Underminers) used to build the patch;
xdelta3 (GPL) to apply it.
