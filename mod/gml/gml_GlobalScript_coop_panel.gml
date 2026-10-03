// ZERO Sievert co-op: F7 panel (host / join / leave), drawn in 480x270 GUI space with the game font.

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
        if (_c.role == "host" && _c.transport == "steam")
        {
            array_push(_b, { id: "steam_invite", label: coop_t("Invite friend again", "Пригласить друга ещё раз") });
        }
        array_push(_b, { id: "leave", label: coop_t("Leave co-op", "Выйти из кооператива") });
    }
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
        }
        exit;
    }
    if (!mouse_check_button_pressed(mb_left))
    {
        exit;
    }
    display_set_gui_size(480, 270);
    var _mx = device_mouse_x_to_gui(0);
    var _my = device_mouse_y_to_gui(0);
    display_set_gui_size(1920, 1080);
    var _btn = coop_panel_buttons();
    for (var _i = 0; _i < array_length(_btn); _i++)
    {
        var _y = 96 + _i * 16;
        if (_mx > 120 && _mx < 360 && _my > _y - 7 && _my < _y + 7)
        {
            coop_panel_click(_btn[_i].id);
            break;
        }
    }
}

function coop_panel_click(_id)
{
    var _c = coop();
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
        case "leave":
            coop_on_disconnected();
            coop_net_stop();
            coop_notify(coop_t("Left co-op", "Вы вышли из кооператива"));
            _c.panel = false;
            break;
        case "close":
            _c.panel = false;
            break;
    }
}

function coop_panel_draw()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "panel") || !_c.panel)
    {
        exit;
    }
    draw_set_alpha(0.85);
    draw_rectangle_colour(110, 60, 370, 200, c_black, c_black, c_black, c_black, false);
    draw_set_alpha(1);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    coop_text_outlined(240, 72, "ZERO Sievert CO-OP", c_lime);
    var _status = (_c.role == "none") ? coop_t("Not connected", "Не подключено") : (_c.connected ? (coop_t("Playing with ", "Игра с ") + _c.peer_name) : coop_t("Waiting for partner...", "Ждём напарника..."));
    coop_text_outlined(240, 84, _status, c_ltgray);
    if (_c.ip_edit)
    {
        coop_text_outlined(240, 110, coop_t("Host IP (Enter to connect, Esc back):", "IP хоста (Enter - подключиться, Esc - назад):"), c_white);
        coop_text_outlined(240, 126, _c.last_ip + ((current_time div 400) mod 2 ? "_" : " "), c_yellow);
    }
    else
    {
        display_set_gui_size(480, 270);
        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);
        var _btn = coop_panel_buttons();
        for (var _i = 0; _i < array_length(_btn); _i++)
        {
            var _y = 96 + _i * 16;
            var _hover = _mx > 120 && _mx < 360 && _my > _y - 7 && _my < _y + 7;
            coop_text_outlined(240, _y, _btn[_i].label, _hover ? c_yellow : c_white);
        }
    }
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}
