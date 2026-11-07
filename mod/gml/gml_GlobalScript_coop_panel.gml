// ZERO Sievert co-op: the co-op panel (host / join / leave / frame rate), opened from the main or pause menu
// or with F7, drawn in the game's UI style (coop_style.gml).

// see-through, so the world stays visible when the panel is opened in a raid
#macro COOP_PANEL_ALPHA 0.72

function coop_panel_buttons()
{
    var _c = coop();
    var _b = [];
    if (!variable_struct_exists(_c, "panel_page")) _c.panel_page = "main";
    if (_c.panel_page == "backups")
    {
        return coop_panel_backup_buttons();
    }
    if (_c.panel_page == "lobby")
    {
        return coop_panel_lobby_buttons();
    }
    if (_c.panel_page == "browser")
    {
        return coop_panel_browser_buttons();
    }
    if (_c.panel_page == "welcome")
    {
        return [
            { id: "none", label: coop_tf("Welcome to ZERO Sievert CO-OP v{0}!", "Добро пожаловать в ZERO Sievert CO-OP v{0}!", COOP_MOD_VERSION) },
            { id: "none", label: coop_t("Raid together with up to 8 friends. F7 opens this panel any time.", "Ходите в рейды вместе, до 8 друзей. F7 открывает эту панель в любой момент.") },
            { id: "help", label: coop_t("Show the tutorial", "Показать обучение") },
            { id: "welcome_later", label: coop_t("Close (show again next time)", "Закрыть (показать при следующем запуске)") },
            { id: "welcome_never", label: coop_t("Close and don't show again", "Закрыть и больше не показывать") }
        ];
    }
    if (_c.panel_page == "help" || _c.panel_page == "help2")
    {
        return coop_panel_help_buttons(_c.panel_page == "help2");
    }
    if (_c.panel_page == "partners")
    {
        return coop_panel_partner_buttons();
    }
    if (_c.panel_page == "settings")
    {
        return coop_panel_settings_buttons();
    }
    if (_c.panel_page == "visits")
    {
        var _vl = coop_panel_visit_buttons();
        array_push(_vl, { id: "page_main", label: coop_t("Back", "Назад") });
        return _vl;
    }
    if (_c.role == "none")
    {
        if (is_struct(coop_rejoin_offer()))
        {
            array_push(_b, { id: "rejoin", label: coop_rejoin_label() });
        }
        array_push(_b, { id: "steam_host", label: coop_t("Host via Steam (invite a friend)", "Создать игру в Steam (пригласить друга)") });
        array_push(_b, { id: "ip_host", label: coop_t("Host by IP (UDP port 47777)", "Создать игру по IP (UDP порт 47777)") });
        array_push(_b, { id: "ip_join", label: coop_t("Join by IP...", "Подключиться по IP...") });
        array_push(_b, { id: "browser", label: coop_t("Find open games...", "Найти открытые игры...") });
    }
    else
    {
        if (coop_can_join_host_raid())
        {
            var _jn = coop_peer_name(coop_join_target());
            array_push(_b, { id: "join_raid", label: coop_tf("Join {0}'s raid", "Присоединиться к рейду {0}", _jn) });
        }
        // visits: the bunker of a friend who sent theirs (lobby in the hub)
        if (coop_visit_active())
        {
            array_push(_b, { id: "visit_end", label: coop_t("Go back to your bunker", "Вернуться в свой бункер") });
        }
        else if (coop_hub_ready())
        {
            // one friend: a direct button; more (up to 7): a page of their own
            var _vb = coop_panel_visit_buttons();
            if (array_length(_vb) == 1)
            {
                array_push(_b, _vb[0]);
            }
            else if (array_length(_vb) > 1)
            {
                array_push(_b, { id: "visits", label: coop_t("Visit a friend's bunker...", "В гости к другу...") });
            }
        }
        if (_c.role == "host" && _c.transport == "steam")
        {
            array_push(_b, { id: "steam_invite", label: coop_t("Invite friend", "Пригласить друга") });
        }
        if (_c.role == "host")
        {
            array_push(_b, { id: "lobby", label: coop_t("Players and lobby...", "Игроки и лобби...") });
        }
        array_push(_b, { id: "leave", label: coop_t("Leave co-op", "Выйти из кооператива") });
    }
    array_push(_b, { id: "settings", label: coop_t("Settings...", "Настройки...") });
    array_push(_b, { id: "partners", label: coop_t("Raids with friends...", "Рейды с друзьями...") });
    array_push(_b, { id: "help", label: coop_t("How co-op works...", "Как играть вместе...") });
    array_push(_b, { id: "report", label: coop_t("Collect logs for a bug report", "Собрать логи для отчёта о баге") });
    if (room == r_menu)
    {
        var _pend = variable_struct_exists(_c, "profile_off_pending") && _c.profile_off_pending;
        array_push(_b, { id: "profile", label: _pend ? coop_t("Characters: usual saves after a game restart", "Персонажи: обычные сохранения после перезапуска игры")
            : (coop_profile_on() ? coop_t("Characters: separate co-op saves", "Персонажи: отдельные кооп-сохранения")
            : coop_t("Characters: your usual saves", "Персонажи: ваши обычные сохранения")) });
        array_push(_b, { id: "backups", label: coop_t("Save backups...", "Резервные копии сохранений...") });
    }
    array_push(_b, { id: "close", label: coop_t("Close [F7]", "Закрыть [F7]") });
    return _b;
}

function coop_panel_visit_buttons()
{
    var _out = [];
    var _ps = coop_peers();
    for (var _k = 0; _k < COOP_MAX_PLAYERS; _k++)
    {
        if (coop_visit_can(_k))
        {
            array_push(_out, { id: "visit_" + string(_k), label: coop_tf("Visit {0}'s bunker", "В гости к {0}", coop_peer_name(_k)) });
        }
    }
    return _out;
}

// Page "settings": the local options.
function coop_panel_settings_buttons()
{
    var _b = [];
    array_push(_b, { id: "fps", label: coop_t("Frame rate: ", "Частота кадров: ") + zs_fps_mode_label(zs_fps().mode) });
    array_push(_b, { id: "conn", label: coop_t("Connection indicator: ", "Индикатор связи: ") + coop_conn_mode_label() });
    array_push(_b, { id: "streamer", label: coop_t("Streamer mode (hide names): ", "Режим стримера (скрыть ники): ") + (coop_streamer() ? coop_t("on", "вкл") : coop_t("off", "выкл")) });
    array_push(_b, { id: "group", label: coop_t("Group panel: ", "Панель группы: ") + (coop_group_mode() ? coop_t("on", "вкл") : coop_t("off", "выкл")) });
    array_push(_b, { id: "page_main", label: coop_t("Back", "Назад") });
    return _b;
}

// Page "partners": lifetime stats per partner, most raids first (read only).
function coop_panel_partner_buttons()
{
    var _all = coop_partners_load();
    var _names = variable_struct_get_names(_all);
    array_sort(_names, function(_a, _b) { return variable_struct_get(coop_partners_load(), _b).raids - variable_struct_get(coop_partners_load(), _a).raids; });
    var _b = [];
    for (var _i = 0; _i < array_length(_names) && _i < 10; _i++)
    {
        var _e = variable_struct_get(_all, _names[_i]);
        var _nm = coop_streamer() ? coop_tf("Friend {0}", "Друг {0}", _i + 1) : coop_ui_fit(_names[_i], 220);
        array_push(_b, { id: "none", label: coop_tf("{0}: raids {1}, revived {2}, kills {3}, made {4}", "{0}: рейдов {1}, подняли {2}, убил {3}, заработали {4}",
            _nm, _e.raids, _e.revived, _e.kills, _e.value) });
    }
    if (array_length(_b) == 0)
    {
        array_push(_b, { id: "none", label: coop_t("No raids with friends yet", "Рейдов с друзьями пока нет") });
    }
    array_push(_b, { id: "page_main", label: coop_t("Back", "Назад") });
    return _b;
}

// Pages "help"/"help2": the short tutorial (opened by itself once, on the first start with the mod).
function coop_panel_help_buttons(_second)
{
    var _b = [];
    if (!_second)
    {
        array_push(_b, { id: "none", label: coop_t("F7 - this panel: host a game, invite, join, settings", "F7 - эта панель: создать игру, пригласить, подключиться, настройки") });
        array_push(_b, { id: "none", label: coop_t("Enter - chat,  Z (hold) - command wheel", "Enter - чат,  Z (удерживать) - колесо команд") });
        array_push(_b, { id: "none", label: coop_t("Middle mouse button - mark a spot (again - remove it)", "Средняя кнопка мыши - метка (ещё раз - убрать)") });
        array_push(_b, { id: "none", label: coop_t("X - give an item to the nearest teammate", "X - передать предмет ближайшему напарнику") });
        array_push(_b, { id: "none", label: coop_t("I - look at the nearest teammate's gear", "I - посмотреть снаряжение ближайшего напарника") });
        array_push(_b, { id: "help2", label: coop_t("Next", "Дальше") });
    }
    else
    {
        array_push(_b, { id: "none", label: coop_t("Raid: the host takes the train, a zone appears next to it", "Рейд: хост садится в поезд, рядом появляется зона") });
        array_push(_b, { id: "none", label: coop_t("Who stands in the zone when the timer ends goes along", "Кто стоит в зоне, когда кончится таймер, - едет с ним") });
        array_push(_b, { id: "none", label: coop_t("The others can join the running raid any time", "Остальные могут присоединиться к рейду в любой момент") });
        array_push(_b, { id: "none", label: coop_t("Lethal damage downs you: a teammate revives you with E", "Смертельный урон - вы ранены: напарник поднимает вас на E") });
        array_push(_b, { id: "none", label: coop_t("Extraction waits for the group (10 s), alone also works", "Эвакуация ждёт группу (10 с), уйти одному тоже можно") });
        array_push(_b, { id: "help", label: coop_t("Back", "Назад") });
    }
    array_push(_b, { id: "page_main", label: coop_t("Close tutorial", "Закрыть обучение") });
    return _b;
}

function coop_panel_title()
{
    switch (coop().panel_page)
    {
        case "backups": return coop_t("SAVE BACKUPS", "РЕЗЕРВНЫЕ КОПИИ");
        case "lobby": return coop_t("PLAYERS AND LOBBY", "ИГРОКИ И ЛОББИ");
        case "settings": return coop_t("CO-OP SETTINGS", "НАСТРОЙКИ КООПЕРАТИВА");
        case "partners": return coop_t("RAIDS WITH FRIENDS", "РЕЙДЫ С ДРУЗЬЯМИ");
        case "welcome": return coop_t("CO-OP MOD", "КООП-МОД");
        case "help": return coop_t("HOW CO-OP WORKS (1/2)", "КАК ИГРАТЬ ВМЕСТЕ (1/2)");
        case "help2": return coop_t("HOW CO-OP WORKS (2/2)", "КАК ИГРАТЬ ВМЕСТЕ (2/2)");
        case "browser": return coop_t("OPEN GAMES", "ОТКРЫТЫЕ ИГРЫ");
    }
    return coop_t("CO-OP", "КООПЕРАТИВ");
}

// Page "lobby" (host): lobby type (Steam), one Kick button per player (click twice).
function coop_panel_lobby_buttons()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "kick_confirm")) _c.kick_confirm = -1;
    var _b = [];
    if (_c.transport == "steam")
    {
        array_push(_b, { id: "lobby_type", label: coop_t("Lobby: ", "Лобби: ") + coop_lobby_type_label() });
    }
    var _ps = coop_peers();
    for (var _k = 1; _k < COOP_MAX_PLAYERS; _k++)
    {
        if (is_struct(_ps[_k]) && _ps[_k].connected)
        {
            var _lab = (_c.kick_confirm == _k) ? coop_tf("Remove {0}? Click again", "Удалить {0}? Нажмите ещё раз", coop_peer_name(_k))
                : coop_tf("Remove {0} from the session", "Удалить {0} из сессии", coop_peer_name(_k));
            array_push(_b, { id: "kick_" + string(_k), label: _lab });
        }
    }
    array_push(_b, { id: "page_main", label: coop_t("Back", "Назад") });
    return _b;
}

// Page "browser": public lobbies of this mod version.
function coop_panel_browser_buttons()
{
    var _c = coop();
    var _b = [];
    if (!steam_initialised())
    {
        array_push(_b, { id: "none", label: coop_t("Steam is not running", "Steam не запущен") });
    }
    else if (variable_struct_exists(_c, "browser") && is_struct(_c.browser) && variable_struct_exists(_c.browser, "friends") && array_length(_c.browser.friends) > 0)
    {
        // friends first (item 29), then the public games
        var _fr = _c.browser.friends;
        for (var _i = 0; _i < array_length(_fr); _i++)
        {
            if (_fr[_i].lobby != 0)
            {
                array_push(_b, { id: "fjoin_" + string(_i), label: coop_tf("Join friend {0}", "Присоединиться к другу {0}", coop_ui_fit(coop_streamer() ? coop_tf("Friend {0}", "Друг {0}", _i + 1) : _fr[_i].name, 300)) });
            }
            else
            {
                array_push(_b, { id: "none", label: coop_tf("{0} plays solo (no co-op lobby)", "{0} играет один (нет кооп-лобби)", coop_ui_fit(coop_streamer() ? coop_tf("Friend {0}", "Друг {0}", _i + 1) : _fr[_i].name, 300)) });
            }
        }
    }
    if (!steam_initialised())
    {
    }
    else if (!variable_struct_exists(_c, "browser") || !is_struct(_c.browser) || _c.browser.loading)
    {
        array_push(_b, { id: "none", label: coop_t("Searching...", "Поиск...") });
    }
    else if (array_length(_c.browser.list) == 0)
    {
        array_push(_b, { id: "none", label: coop_t("No open games right now", "Сейчас нет открытых игр") });
    }
    else
    {
        for (var _i = 0; _i < array_length(_c.browser.list); _i++)
        {
            array_push(_b, { id: "bjoin_" + string(_i), label: coop_lobby_browser_label(_c.browser.list[_i]) });
        }
    }
    array_push(_b, { id: "browser", label: coop_t("Refresh", "Обновить") });
    array_push(_b, { id: "page_main", label: coop_t("Back", "Назад") });
    return _b;
}

// Page "backups": the slot, its backups (newest first), back.
function coop_panel_backup_buttons()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "bk_slot")) _c.bk_slot = 1;
    if (!variable_struct_exists(_c, "bk_confirm")) _c.bk_confirm = "";
    var _b = [];
    array_push(_b, { id: "bk_slot", label: coop_tf("Save slot {0} (click to change)", "Слот сохранения {0} (нажмите, чтобы сменить)", _c.bk_slot) });
    var _l = coop_backup_list(_c.bk_slot);
    if (array_length(_l) == 0)
    {
        array_push(_b, { id: "bk_none", label: coop_t("No backups yet (made when a co-op session starts)", "Копий пока нет (делаются при начале кооп-сессии)") });
    }
    for (var _i = 0; _i < array_length(_l); _i++)
    {
        var _id = "bk_f_" + _l[_i].file;
        var _lab = coop_backup_label(_l[_i]);
        if (_c.bk_confirm == _id)
        {
            _lab = coop_tf("Restore {0}? Click again", "Восстановить {0}? Нажмите ещё раз", _lab);
        }
        array_push(_b, { id: _id, label: _lab });
    }
    array_push(_b, { id: "bk_back", label: coop_t("Back", "Назад") });
    return _b;
}

function coop_panel_step()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "panel"))
    {
        _c.panel = false;
        _c.ip_edit = false;
        _c.last_ip = "127.0.0.1";
    }
    if (keyboard_check_pressed(vk_f7))
    {
        _c.panel = !_c.panel;
        _c.ip_edit = false;
        _c.panel_page = "main";
    }
    if (!_c.panel)
    {
        _c.panel_page = "main";
        exit;
    }
    if (_c.ip_edit)
    {
        _c.last_ip = string_copy(string_lettersdigits(string_replace_all(keyboard_string, ".", "x")), 1, 40);
        _c.last_ip = string_replace_all(_c.last_ip, "x", ".");
        if (keyboard_check_pressed(vk_enter))
        {
            _c.ip_edit = false;
            _c.panel = false;
            coop_net_stop();
            _c.role = "guest";
            _c.transport = "udp";
            _c.peer_ip = _c.last_ip;
            _c.peer_port = COOP_PORT;
            coop_net_start();
            coop_notify(coop_tf("Connecting to {0}", "Подключение к {0}", _c.peer_ip));
        }
        if (keyboard_check_pressed(vk_escape))
        {
            _c.ip_edit = false;
            keyboard_clear(vk_escape); // do not open the pause menu too
        }
        exit;
    }
    if (keyboard_check_pressed(vk_escape) || coop_pad_pressed(gp_face2))
    {
        _c.panel = (_c.panel_page != "main");
        _c.panel_page = "main";
        keyboard_clear(vk_escape);
        exit;
    }
    var _btns = coop_panel_buttons();
    var _nb = array_length(_btns);
    if (!variable_struct_exists(_c, "panel_sel")) _c.panel_sel = 0;
    _c.panel_sel = clamp(_c.panel_sel, 0, _nb - 1);
    if (keyboard_check_pressed(vk_up) || coop_pad_pressed(gp_padu)) _c.panel_sel = (_c.panel_sel - 1 + _nb) mod _nb;
    if (keyboard_check_pressed(vk_down) || coop_pad_pressed(gp_padd)) _c.panel_sel = (_c.panel_sel + 1) mod _nb;
    if (keyboard_check_pressed(vk_enter) || coop_pad_pressed(gp_face1))
    {
        coop_panel_click(_btns[_c.panel_sel].id);
        exit;
    }
    if (!mouse_check_button_pressed(mb_left))
    {
        exit;
    }
    var _hit = coop_panel_hit(coop_ui_mouse_x(), coop_ui_mouse_y());
    if (_hit >= 0)
    {
        coop_panel_click(_btns[_hit].id);
    }
}

function coop_panel_click(_id)
{
    var _c = coop();
    if (_id == "visit_end")
    {
        coop_visit_end("panel");
        _c.panel = false;
        exit;
    }
    if (_id == "welcome_later" || _id == "welcome_never")
    {
        if (_id == "welcome_never" && !_c.test_mode)
        {
            ini_open("coop_local.ini");
            ini_write_real("coop", "welcome_never", 1);
            ini_close();
        }
        coop_log("welcome: ", _id);
        _c.panel_page = "main";
        _c.panel = false;
        exit;
    }
    if (_id == "help" || _id == "help2")
    {
        _c.panel_page = _id;
        _c.panel_sel = 0;
        exit;
    }
    if (_id == "partners")
    {
        _c.panel_page = "partners";
        _c.panel_sel = 0;
        exit;
    }
    if (_id == "settings")
    {
        _c.panel_page = "settings";
        _c.panel_sel = 0;
        exit;
    }
    if (_id == "visits")
    {
        _c.panel_page = "visits";
        _c.panel_sel = 0;
        exit;
    }
    if (_id == "lobby" || _id == "page_main")
    {
        _c.panel_page = (_id == "lobby") ? "lobby" : "main";
        _c.kick_confirm = -1;
        _c.panel_sel = 0;
        exit;
    }
    if (_id == "browser")
    {
        _c.panel_page = "browser";
        _c.panel_sel = 0;
        coop_lobby_browser_open();
        exit;
    }
    if (_id == "none")
    {
        exit;
    }
    if (_id == "lobby_type")
    {
        coop_lobby_type_cycle();
        exit;
    }
    if (string_copy(_id, 1, 5) == "kick_")
    {
        var _ks = real(string_delete(_id, 1, 5));
        if (_c.kick_confirm != _ks)
        {
            _c.kick_confirm = _ks;
            exit;
        }
        _c.kick_confirm = -1;
        coop_kick(_ks);
        exit;
    }
    if (string_copy(_id, 1, 6) == "fjoin_")
    {
        var _fi = real(string_delete(_id, 1, 6));
        if (variable_struct_exists(_c, "browser") && is_struct(_c.browser) && _fi < array_length(_c.browser.friends))
        {
            coop_steam_join_lobby(_c.browser.friends[_fi].lobby);
            _c.panel = false;
        }
        exit;
    }
    if (string_copy(_id, 1, 6) == "bjoin_")
    {
        var _bi = real(string_delete(_id, 1, 6));
        if (variable_struct_exists(_c, "browser") && is_struct(_c.browser) && _bi < array_length(_c.browser.list))
        {
            coop_steam_join_lobby(_c.browser.list[_bi].id);
            _c.panel = false;
        }
        exit;
    }
    if (_id == "backups" || _id == "bk_back")
    {
        _c.panel_page = (_id == "backups") ? "backups" : "main";
        _c.bk_confirm = "";
        _c.panel_sel = 0;
        exit;
    }
    if (_id == "bk_slot")
    {
        _c.bk_slot = (_c.bk_slot mod 3) + 1;
        _c.bk_confirm = "";
        exit;
    }
    if (_id == "bk_none")
    {
        exit;
    }
    if (string_copy(_id, 1, 5) == "bk_f_")
    {
        if (_c.bk_confirm != _id)
        {
            _c.bk_confirm = _id;
            exit;
        }
        _c.bk_confirm = "";
        if (coop_backup_restore(_c.bk_slot, string_delete(_id, 1, 5)))
        {
            coop_notify(coop_tf("Save slot {0} restored", "Слот сохранения {0} восстановлен", _c.bk_slot));
        }
        else
        {
            coop_notify(coop_t("Restore failed (main menu only)", "Не удалось восстановить (только в главном меню)"));
        }
        exit;
    }
    if (string_copy(_id, 1, 6) == "visit_")
    {
        coop_visit_start(real(string_delete(_id, 1, 6)));
        _c.panel = false;
        exit;
    }
    switch (_id)
    {
        case "steam_host":
            coop_steam_host();
            _c.panel = false;
            break;
        case "steam_invite":
            steam_lobby_activate_invite_overlay();
            break;
        case "ip_host":
            coop_net_stop();
            _c.kicked = [];
            _c.role = "host";
            _c.transport = "udp";
            coop_net_start();
            coop_notify(coop_t("Hosting on UDP port 47777", "Игра создана, UDP порт 47777"));
            _c.panel = false;
            break;
        case "ip_join":
            _c.ip_edit = true;
            keyboard_string = _c.last_ip;
            break;
        case "join_raid":
            coop_request_join();
            _c.panel = false;
            break;
        case "leave":
            coop_rejoin_forget();
            coop_on_disconnected();
            coop_net_stop();
            coop_notify(coop_t("Left co-op", "Вы вышли из кооператива"));
            _c.panel = false;
            break;
        case "fps":
            zs_fps_cycle();
            break;
        case "streamer":
            coop_streamer_toggle();
            break;
        case "group":
            coop_group_toggle();
            break;
        case "conn":
            coop_conn_cycle();
            break;
        case "rejoin":
            coop_rejoin_go();
            _c.panel = false;
            break;
        case "profile":
            coop_profile_toggle();
            break;
        case "report":
            coop_report_collect();
            _c.panel = false;
            break;
        case "close":
            _c.panel = false;
            break;
    }
}

// Panel geometry in the 1920x1080 UI space (shared by drawing and mouse hit tests).
function coop_panel_layout()
{
    var _c = coop();
    var _lines = 1 + (_c.connected ? coop_player_count() : 0) + ((!variable_struct_exists(_c, "panel_page") || _c.panel_page == "main") ? array_length(coop_files_state().diffs) : 0);
    var _nb = array_length(coop_panel_buttons());
    // the tutorial lines are long (and longer in other languages)
    var _w = (variable_struct_exists(_c, "panel_page") && (string_copy(_c.panel_page, 1, 4) == "help" || _c.panel_page == "welcome")) ? 1300 : 760;
    var _x1 = COOP_GW / 2 - _w / 2;
    var _btn_h = 46;
    var _h = 66 + _lines * 34 + 16 + _nb * (_btn_h + 8) + ((coop_update_text() != "") ? 50 : 10);
    var _y1 = max(80, COOP_GH / 2 - _h / 2);
    return { x1: _x1, x2: _x1 + _w, y1: _y1, y2: _y1 + _h, lines: _lines, btn_y0: _y1 + 66 + _lines * 34 + 16, btn_h: _btn_h, nb: _nb };
}

// Index of the button under (_mx, _my) in UI space, or -1.
function coop_panel_hit(_mx, _my)
{
    var _l = coop_panel_layout();
    for (var _i = 0; _i < _l.nb; _i++)
    {
        var _y = _l.btn_y0 + _i * (_l.btn_h + 8);
        if (_mx > _l.x1 + 24 && _mx < _l.x2 - 24 && _my > _y && _my < _y + _l.btn_h)
        {
            return _i;
        }
    }
    return -1;
}

function coop_panel_draw()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "panel") || !_c.panel)
    {
        exit;
    }
    coop_ui_begin(COOP_F_BODY);
    var _l = coop_panel_layout();
    var _y = coop_ui_panel(_l.x1, _l.y1, _l.x2, _l.y2, coop_panel_title(), COOP_PANEL_ALPHA);
    var _cx = (_l.x1 + _l.x2) / 2;
    var _status = (_c.role == "none") ? coop_t("Not connected", "Не подключено")
        : (_c.connected ? (coop_t("Players: ", "Игроков: ") + string(coop_player_count()) + "/" + string(COOP_MAX_PLAYERS) + "   " + ((_c.role == "host") ? coop_t("you are the host", "вы хост") : coop_t("you are a guest", "вы гость")))
        : ((_c.role == "host") ? coop_t("Waiting for players...", "Ждём игроков...") : coop_t("Connecting...", "Подключение...")));
    draw_set_halign(fa_center);
    coop_ui_text(_cx, _y, _status, COOP_C_DIM);
    _y += 34;
    if (_c.connected)
    {
        // everybody in the session, each in their marker colour, with ping
        var _ps = coop_peers();
        for (var _k = 0; _k < COOP_MAX_PLAYERS; _k++)
        {
            var _pp = _ps[_k];
            var _me = (_k == _c.slot);
            if (!_me && !(is_struct(_pp) && _pp.connected))
            {
                continue;
            }
            var _nm = coop_ui_fit(_me ? coop_my_shown_name() : coop_peer_name(_k), 300) + (_me ? coop_t(" (you)", " (вы)") : "");
            if (_k == 0)
            {
                _nm += coop_t("  - host", "  - хост");
            }
            var _where = _me ? (coop_in_raid() ? 2 : (coop_hub_ready() ? 1 : 0)) : _pp.loc;
            if (_where == 1)
            {
                _nm += coop_t("  · in the hub", "  · в бункере");
            }
            else if (_where == 2)
            {
                _nm += coop_t("  · in a raid", "  · в рейде");
            }
            if (!_me && is_struct(_pp) && (_c.role == "host" || _k == 0))
            {
                _nm += "   " + string(round(_pp.ping)) + coop_t(" ms", " мс");
            }
            coop_ui_rect(_cx - string_width(_nm) / 2 - 22, _y + 11, _cx - string_width(_nm) / 2 - 12, _y + 21, coop_slot_colour(_k));
            coop_ui_text(_cx, _y, _nm, COOP_C_TEXT);
            _y += 34;
        }
    }
    if (_c.panel_page == "main")
    {
        // different game files / mods (coop_files.gml)
        var _df = coop_files_state().diffs;
        for (var _i = 0; _i < array_length(_df); _i++)
        {
            coop_ui_text(_cx, _y, coop_ui_fit(_df[_i].text, _l.x2 - _l.x1 - 60), COOP_C_KEY);
            _y += 34;
        }
    }
    draw_set_halign(fa_left);
    if (_c.ip_edit)
    {
        var _by = _l.btn_y0;
        draw_set_halign(fa_center);
        coop_ui_text(_cx, _by, coop_t("Host IP address", "IP-адрес хоста"), COOP_C_DIM);
        coop_ui_slot(_l.x1 + 60, _by + 40, _l.x2 - 60, _by + 40 + _l.btn_h, true);
        draw_set_valign(fa_middle);
        // streamer mode: the typed address stays hidden
        var _ipt = coop_streamer() ? string_repeat("*", string_length(_c.last_ip)) : _c.last_ip;
        coop_ui_text(_cx, _by + 40 + _l.btn_h / 2, _ipt + ((current_time div 400) mod 2 ? "_" : " "), COOP_C_KEY);
        draw_set_valign(fa_top);
        draw_set_halign(fa_left);
        coop_ui_prompt(_cx, _l.y2 - 48, "Enter", coop_t("connect   [Esc] back", "подключиться   [Esc] назад"));
        coop_ui_end();
        exit;
    }
    var _mx = coop_ui_mouse_x();
    var _my = coop_ui_mouse_y();
    var _btn = coop_panel_buttons();
    var _hit = coop_panel_hit(_mx, _my);
    var _moved = !variable_struct_exists(_c, "panel_mx") || abs(_c.panel_mx - _mx) + abs(_c.panel_my - _my) > 2;
    if (_hit >= 0 && _moved)
    {
        _c.panel_sel = _hit; // the mouse wins only when it actually moved
    }
    _c.panel_mx = _mx;
    _c.panel_my = _my;
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    for (var _i = 0; _i < array_length(_btn); _i++)
    {
        var _by = _l.btn_y0 + _i * (_l.btn_h + 8);
        var _sel = variable_struct_exists(_c, "panel_sel") && _c.panel_sel == _i;
        if (_btn[_i].id == "none")
        {
            // an information line, not a button
            coop_ui_text(_cx, _by + _l.btn_h / 2, coop_ui_fit(_btn[_i].label, _l.x2 - _l.x1 - 60), COOP_C_TEXT);
            continue;
        }
        coop_ui_slot(_l.x1 + 24, _by, _l.x2 - 24, _by + _l.btn_h, _sel, 0.85);
        coop_ui_text(_cx, _by + _l.btn_h / 2, coop_ui_fit(_btn[_i].label, _l.x2 - _l.x1 - 80), _sel ? COOP_C_KEY : COOP_C_TEXT);
    }
    draw_set_valign(fa_top);
    var _upd = coop_update_text();
    if (_upd != "")
    {
        coop_ui_text(_cx, _l.y2 - 42, _upd, COOP_C_KEY);
    }
    coop_ui_end();
}

// Mouse in the panel's 480x270 GUI space. The GUI layer always covers the whole window, but the game
// draws the application surface itself (letterboxing/zoom), which makes device_mouse_x_to_gui wrong
// in the bunker and in raids - so map from window pixels directly.
// With a player on the map the game locks the OS mouse to the window centre every frame and moves its
// own virtual cursor (obj_cursor, room coordinates) instead - use that, mapped through the camera.
function coop_gui_mouse_x()
{
    if (instance_exists(obj_player) && instance_exists(obj_cursor))
    {
        var _cam = view_camera[0];
        return (obj_cursor.x - camera_get_view_x(_cam)) / max(1, camera_get_view_width(_cam)) * 480;
    }
    return window_mouse_get_x() / max(1, window_get_width()) * 480;
}

function coop_gui_mouse_y()
{
    if (instance_exists(obj_player) && instance_exists(obj_cursor))
    {
        var _cam = view_camera[0];
        return (obj_cursor.y - camera_get_view_y(_cam)) / max(1, camera_get_view_height(_cam)) * 270;
    }
    return window_mouse_get_y() / max(1, window_get_height()) * 270;
}

// obj_coop Begin Step: while the panel is open, clicks belong to it, not to the gun.
function coop_panel_begin_step()
{
    var _c = coop();
    if (variable_struct_exists(_c, "panel") && _c.panel && instance_exists(obj_player))
    {
        obj_player.shooting = true;
    }
}

// A gamepad button pressed this step on any connected gamepad.
function coop_pad_pressed(_btn)
{
    var _n = gamepad_get_device_count();
    for (var _d = 0; _d < _n; _d++)
    {
        if (gamepad_is_connected(_d) && gamepad_button_check_pressed(_d, _btn))
        {
            return true;
        }
    }
    return false;
}

// True while the F7 panel is open: the game's own input (hooks in update_keyboard_input, obj_gamepad Begin Step
// and ui_handle_input) is muted, so clicks and keys meant for the panel don't shoot, walk, move inventory items
// or press the menu buttons behind it. The panel reads the keyboard, mouse and gamepad directly.
function coop_panel_blocks_game()
{
    if (!variable_global_exists("coop_state"))
    {
        return false;
    }
    var _c = global.coop_state;
    // the F7 panel or the chat line (coop_chat.gml) has the keyboard
    return (variable_struct_exists(_c, "panel") && _c.panel) || (variable_struct_exists(_c, "chat") && _c.chat.open);
}

// obj_coop Step: the welcome window (main menu) - tutorial / later / never.
function coop_tutorial_step()
{
    var _c = coop();
    if (variable_struct_exists(_c, "tutorial_checked") || room != r_menu || (_c.test_mode && _c.scenario != "tutorial"))
    {
        exit;
    }
    _c.tutorial_checked = true;
    ini_open("coop_local.ini");
    var _never = ini_read_real("coop", "welcome_never", 0);
    ini_close();
    // the welcome window comes back on every start until "don't show again"
    if (!_never || (_c.test_mode && _c.scenario == "tutorial"))
    {
        _c.panel = true;
        _c.panel_page = "welcome";
        _c.panel_sel = 0;
        coop_log("welcome opened");
    }
}
