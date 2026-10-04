// ZERO Sievert co-op: the co-op panel (host / join / leave / frame rate), opened from the main or pause menu
// or with F7, drawn in the game's UI style (coop_style.gml).

function coop_panel_buttons()
{
    var _c = coop();
    var _b = [];
    if (_c.role == "none")
    {
        array_push(_b, { id: "steam_host", label: coop_t("Host via Steam (invite a friend)", "Создать игру в Steam (пригласить друга)") });
        array_push(_b, { id: "ip_host", label: coop_t("Host by IP (UDP port 47777)", "Создать игру по IP (UDP порт 47777)") });
        array_push(_b, { id: "ip_join", label: coop_t("Join by IP...", "Подключиться по IP...") });
    }
    else
    {
        if (coop_can_join_host_raid())
        {
            var _jn = coop_peer_name(coop_join_target());
            array_push(_b, { id: "join_raid", label: coop_t("Join " + _jn + "'s raid", "Присоединиться к рейду " + _jn) });
        }
        // visits: the bunker of a friend who sent theirs (lobby in the hub)
        if (coop_visit_active())
        {
            array_push(_b, { id: "visit_end", label: coop_t("Go back to your bunker", "Вернуться в свой бункер") });
        }
        else if (coop_hub_ready())
        {
            var _ps = coop_peers();
            for (var _k = 0; _k < COOP_MAX_PLAYERS; _k++)
            {
                if (coop_visit_can(_k))
                {
                    array_push(_b, { id: "visit_" + string(_k), label: coop_t("Visit " + _ps[_k].name + "'s bunker", "В гости к " + _ps[_k].name) });
                }
            }
        }
        if (_c.role == "host" && _c.transport == "steam")
        {
            array_push(_b, { id: "steam_invite", label: coop_t("Invite friend again", "Пригласить друга ещё раз") });
        }
        array_push(_b, { id: "leave", label: coop_t("Leave co-op", "Выйти из кооператива") });
    }
    array_push(_b, { id: "fps", label: coop_t("Frame rate: ", "Частота кадров: ") + zs_fps_mode_label(zs_fps().mode) });
    array_push(_b, { id: "close", label: coop_t("Close [F7]", "Закрыть [F7]") });
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
    }
    if (!_c.panel)
    {
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
            coop_notify(coop_t("Connecting to ", "Подключение к ") + _c.peer_ip);
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
        _c.panel = false;
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
            coop_on_disconnected();
            coop_net_stop();
            coop_notify(coop_t("Left co-op", "Вы вышли из кооператива"));
            _c.panel = false;
            break;
        case "fps":
            zs_fps_cycle();
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
    var _lines = 1 + (_c.connected ? coop_player_count() : 0);
    var _nb = array_length(coop_panel_buttons());
    var _w = 760;
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
    var _y = coop_ui_panel(_l.x1, _l.y1, _l.x2, _l.y2, coop_t("CO-OP", "КООПЕРАТИВ"));
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
            var _nm = _me ? (coop_my_name() + coop_t(" (you)", " (вы)")) : _pp.name;
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
    draw_set_halign(fa_left);
    if (_c.ip_edit)
    {
        var _by = _l.btn_y0;
        draw_set_halign(fa_center);
        coop_ui_text(_cx, _by, coop_t("Host IP address", "IP-адрес хоста"), COOP_C_DIM);
        coop_ui_slot(_l.x1 + 60, _by + 40, _l.x2 - 60, _by + 40 + _l.btn_h, true);
        draw_set_valign(fa_middle);
        coop_ui_text(_cx, _by + 40 + _l.btn_h / 2, _c.last_ip + ((current_time div 400) mod 2 ? "_" : " "), COOP_C_KEY);
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
        coop_ui_slot(_l.x1 + 24, _by, _l.x2 - 24, _by + _l.btn_h, _sel);
        coop_ui_text(_cx, _by + _l.btn_h / 2, _btn[_i].label, _sel ? COOP_C_KEY : COOP_C_TEXT);
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
