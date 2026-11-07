// ZERO Sievert co-op: quick-command wheel (2.0.0 item 10).
// Hold Z (gamepad: hold the left stick button): a wheel of 8 commands around the screen centre; point at one with
// the mouse (or the right stick) and release Z to send it. Mouse wheel / Q switches between the two pages:
// text commands and icon commands (the game's own item icons: ammo, medkit, bandage, food, water, grenade,
// weapon, key). Teammates see the command over the sender's head for 5 s; text ones also go to the chat log.

#macro COOP_MSG_CMD 72
#macro COOP_CMD_SHOW_MS 5000
// the wheel key: Z
#macro COOP_WHEEL_KEY 90

function coop_wheel_texts()
{
    return [
        coop_t("Follow me", "За мной"),
        coop_t("Wait here", "Ждите тут"),
        coop_t("Help!", "Помогите!"),
        coop_t("Enemy spotted", "Вижу врага"),
        coop_t("Loot here", "Тут лут"),
        coop_t("Let's go", "Идём"),
        coop_t("Fall back!", "Отходим!"),
        coop_t("Thanks!", "Спасибо!")
    ];
}

// Icon page: [item id, text for the chat log]
function coop_wheel_icons()
{
    return [
        ["ammo_9x18", coop_t("Need ammo", "Нужны патроны")],
        ["medikit_1", coop_t("Need a medkit", "Нужна аптечка")],
        ["bandage", coop_t("Need a bandage", "Нужен бинт")],
        ["bread", coop_t("Need food", "Нужна еда")],
        ["water_bottle", coop_t("Need water", "Нужна вода")],
        ["grenade_rgd5", coop_t("Throwing a grenade!", "Кидаю гранату!")],
        ["ak_74", coop_t("Need a weapon", "Нужно оружие")],
        ["key_gears", coop_t("Found a key", "Нашёл ключ")]
    ];
}

function coop_wheel()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "wheel"))
    {
        _c.wheel = { open: false, page: 0, sel: -1, cmds: [] }; // cmds: shown over heads { slot, page, index, t }
    }
    return _c.wheel;
}

function coop_wheel_held()
{
    var _pad = false;
    try
    {
        for (var _d = 0; _d < 4; _d++)
        {
            if (gamepad_is_connected(_d) && gamepad_button_check(_d, gp_stickl)) _pad = true;
        }
    }
    catch (_e) { }
    return keyboard_check(COOP_WHEEL_KEY) || _pad;
}

// obj_coop Step
function coop_wheel_step()
{
    var _c = coop();
    var _w = coop_wheel();
    if (!_c.connected || !instance_exists(obj_player) || !(coop_in_raid() || is_in_hub()) || coop_chat_is_open()
        || (variable_struct_exists(_c, "panel") && _c.panel))
    {
        _w.open = false;
        exit;
    }
    var _held = coop_wheel_held() || (_c.test_mode && variable_struct_exists(_c, "sim_wheel") && _c.sim_wheel);
    if (!_w.open)
    {
        if (_held)
        {
            _w.open = true;
            _w.sel = -1;
        }
        exit;
    }
    if (mouse_wheel_up() || mouse_wheel_down() || keyboard_check_pressed(ord("Q")))
    {
        _w.page = 1 - _w.page;
    }
    // pointed command: direction from the screen centre (mouse in UI space, or the right stick)
    var _dx = coop_ui_mouse_x() - COOP_GW / 2;
    var _dy = coop_ui_mouse_y() - COOP_GH / 2;
    try
    {
        for (var _d = 0; _d < 4; _d++)
        {
            if (gamepad_is_connected(_d))
            {
                var _ax = gamepad_axis_value(_d, gp_axisrh);
                var _ay = gamepad_axis_value(_d, gp_axisrv);
                if (point_distance(0, 0, _ax, _ay) > 0.5) { _dx = _ax * 200; _dy = _ay * 200; }
            }
        }
    }
    catch (_e) { }
    if (_c.test_mode && variable_struct_exists(_c, "sim_wheel_dir"))
    {
        _dx = lengthdir_x(200, _c.sim_wheel_dir);
        _dy = lengthdir_y(200, _c.sim_wheel_dir);
    }
    _w.sel = (point_distance(0, 0, _dx, _dy) > 60) ? coop_wheel_index_at(point_direction(0, 0, _dx, _dy)) : -1;
    if (!_held)
    {
        _w.open = false;
        if (_w.sel >= 0)
        {
            coop_wheel_send(_w.page, _w.sel);
        }
    }
}

// 8 sectors, the first one straight up, clockwise.
function coop_wheel_index_at(_dir)
{
    var _a = (90 - _dir + 360 + 22.5) mod 360;
    return floor(_a / 45) mod 8;
}

function coop_wheel_send(_page, _index)
{
    var _c = coop();
    var _b = coop_msg_begin(COOP_MSG_CMD);
    buffer_write(_b, buffer_u8, _page);
    buffer_write(_b, buffer_u8, _index);
    coop_msg_send(true);
    coop_wheel_show(max(0, _c.slot), _page, _index);
}

function coop_wheel_on_msg(_b)
{
    var _c = coop();
    var _page = buffer_read(_b, buffer_u8);
    var _index = buffer_read(_b, buffer_u8);
    if (_page > 1 || _index > 7)
    {
        exit;
    }
    coop_wheel_show(_c.msg_from, _page, _index);
}

function coop_wheel_show(_slot, _page, _index)
{
    var _w = coop_wheel();
    // one command per player at a time
    for (var _i = array_length(_w.cmds) - 1; _i >= 0; _i--)
    {
        if (_w.cmds[_i].slot == _slot) array_delete(_w.cmds, _i, 1);
    }
    array_push(_w.cmds, { slot: _slot, page: _page, index: _index, t: current_time });
    var _tx = coop_wheel_texts();
    var _ic = coop_wheel_icons();
    var _text = (_page == 0) ? _tx[_index] : _ic[_index][1];
    var _name = (_slot == max(0, coop().slot)) ? coop_my_name() : coop_peer_name(_slot);
    coop_chat_add(_slot, _name, "[" + _text + "]");
}

// Draw GUI: the wheel while open, and every live command over its sender's head.
function coop_wheel_draw()
{
    var _c = coop();
    var _w = coop_wheel();
    coop_ui_font(COOP_F_SMALL);
    var _tx = coop_wheel_texts(); // (the UTMT compiler miscompiles f()[i])
    var _ic = coop_wheel_icons();
    // commands over heads
    for (var _i = array_length(_w.cmds) - 1; _i >= 0; _i--)
    {
        var _e = _w.cmds[_i];
        if (current_time - _e.t > COOP_CMD_SHOW_MS)
        {
            array_delete(_w.cmds, _i, 1);
            continue;
        }
        var _who = (_e.slot == max(0, _c.slot)) ? (instance_exists(obj_player) ? obj_player.id : -4) : coop_puppet_of(_e.slot);
        if (!instance_exists(_who))
        {
            continue;
        }
        var _gx = coop_ui_world_x(_who.x);
        var _gy = coop_ui_world_y(_who.y) - 112;
        var _a = clamp((COOP_CMD_SHOW_MS - (current_time - _e.t)) / 500, 0, 1);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        if (_e.page == 0)
        {
            var _t = _tx[_e.index];
            var _bw = string_width(_t) / 2 + 12;
            coop_ui_rect(_gx - _bw, _gy - 16, _gx + _bw, _gy + 16, c_black, 0.7 * _a);
            coop_ui_rect(_gx - _bw, _gy + 14, _gx + _bw, _gy + 16, coop_slot_colour(_e.slot), _a);
            draw_text_colour(_gx, _gy, _t, COOP_C_TEXT, COOP_C_TEXT, COOP_C_TEXT, COOP_C_TEXT, _a);
        }
        else
        {
            // icon commands (page 1) and "I need this" (page 2: any item)
            coop_ui_rect(_gx - 30, _gy - 26, _gx + 30, _gy + 26, COOP_C_SLOT_HI, 0.85 * _a);
            coop_ui_rect(_gx - 30, _gy + 24, _gx + 30, _gy + 26, coop_slot_colour(_e.slot), _a);
            draw_set_alpha(_a);
            coop_ui_item_icon_wh((_e.page == 2) ? _e.item : _ic[_e.index][0], _gx, _gy, 52, 44);
            draw_set_alpha(1);
            if (_e.page == 2)
            {
                coop_ui_text_ol(_gx, _gy - 40, coop_t("Need", "Нужно"), COOP_C_KEY);
            }
        }
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
    }
    if (!_w.open)
    {
        exit;
    }
    var _cx = COOP_GW / 2;
    var _cy = COOP_GH / 2;
    var _r = 250;
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    coop_ui_text_ol(_cx, _cy - 16, (_w.page == 0) ? coop_t("Commands", "Команды") : coop_t("Requests", "Просьбы"), COOP_C_KEY);
    coop_ui_text_ol(_cx, _cy + 16, coop_t("wheel / Q: next page", "колесо / Q: другая страница"), COOP_C_DIM);
    for (var _i = 0; _i < 8; _i++)
    {
        var _dir = 90 - _i * 45;
        var _x = _cx + lengthdir_x(_r, _dir);
        var _y = _cy + lengthdir_y(_r * 0.8, _dir);
        var _sel = (_i == _w.sel);
        if (_w.page == 0)
        {
            var _t = _tx[_i];
            var _bw = max(90, string_width(_t) / 2 + 16);
            coop_ui_slot(_x - _bw, _y - 24, _x + _bw, _y + 24, _sel, 0.85);
            coop_ui_text(_x, _y, _t, _sel ? COOP_C_KEY : COOP_C_TEXT);
        }
        else
        {
            // light cells: dark item sprites (rifles, grenades) stay readable
            coop_ui_rect(_x - 54, _y - 42, _x + 54, _y + 42, COOP_C_EDGE, 0.9);
            coop_ui_rect(_x - 52, _y - 40, _x + 52, _y + 40, _sel ? make_colour_rgb(120, 116, 100) : COOP_C_SLOT_HI, 0.9);
            if (_sel)
            {
                draw_set_colour(COOP_C_KEY);
                draw_rectangle(_x - 52, _y - 40, _x + 52, _y + 40, true);
                draw_rectangle(_x - 51, _y - 39, _x + 51, _y + 39, true);
            }
            coop_ui_item_icon_wh(_ic[_i][0], _x, _y - 6, 80, 48);
            if (_sel)
            {
                coop_ui_text_ol(_x, _y + 58, _ic[_i][1], COOP_C_KEY);
            }
        }
    }
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}

// ---- "I need this" (2.0.0 item 28) ----
// In the inventory (or any loot window): hover an item and press the middle mouse button (gamepad: the right stick
// button): everybody sees that item's icon over your head and "[Need: item]" in the chat log.
#macro COOP_MSG_NEED 78

function coop_need_step()
{
    var _c = coop();
    var _w = coop_wheel();
    if (!_c.connected || !(coop_in_raid() || is_in_hub()))
    {
        exit;
    }
    // the hovered item (the game sets its tooltip loot while the pointer rests on an item)
    try
    {
        if (uiGetData().tooltip_open && is_struct(uiGetData().tooltip_loot) && item_exists(uiGetData().tooltip_loot.item))
        {
            _w.need_item = uiGetData().tooltip_loot.item;
            _w.need_frame = _c.frame;
        }
    }
    catch (_e) { }
    var _press = mouse_check_button_pressed(mb_middle);
    try
    {
        for (var _d = 0; _d < 4; _d++) if (gamepad_is_connected(_d) && gamepad_button_check_pressed(_d, gp_stickr)) _press = true;
    }
    catch (_e2) { }
    if (_c.test_mode && variable_struct_exists(_c, "sim_need"))
    {
        _w.need_item = _c.sim_need;
        _w.need_frame = _c.frame;
        variable_struct_remove(_c, "sim_need");
        _press = true;
    }
    if (!_press || !variable_struct_exists(_w, "need_frame") || _c.frame - _w.need_frame > 3)
    {
        exit;
    }
    var _b = coop_msg_begin(COOP_MSG_NEED);
    buffer_write(_b, buffer_string, _w.need_item);
    coop_msg_send(true);
    coop_need_show(max(0, _c.slot), _w.need_item);
    _w.need_frame = -100;
}

function coop_need_on_msg(_b)
{
    var _item = buffer_read(_b, buffer_string);
    if (item_exists(_item))
    {
        coop_need_show(coop().msg_from, _item);
    }
}

function coop_need_show(_slot, _item)
{
    var _w = coop_wheel();
    for (var _i = array_length(_w.cmds) - 1; _i >= 0; _i--)
    {
        if (_w.cmds[_i].slot == _slot) array_delete(_w.cmds, _i, 1);
    }
    array_push(_w.cmds, { slot: _slot, page: 2, index: 0, item: _item, t: current_time });
    var _name = (_slot == max(0, coop().slot)) ? coop_my_name() : coop_peer_name(_slot);
    coop_chat_add(_slot, _name, coop_tf("[Need: {0}]", "[Нужно: {0}]", item_get_name(_item)));
}
