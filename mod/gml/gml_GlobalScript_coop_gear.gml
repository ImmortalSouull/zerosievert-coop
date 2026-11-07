// ZERO Sievert co-op: look at a teammate's gear, read only (2.0.0 item 44).
// Press I next to a teammate (or "View gear" on the co-op panel's players page): we ask, the teammate answers with
// what it wears (weapons, armor, backpack, headset) and what its inventory holds. A window shows the item icons
// with their counts; I / Esc closes it. Nothing can be taken from it.

#macro COOP_MSG_GEAR_REQ 75
#macro COOP_MSG_GEAR 76
// the key: I
#macro COOP_GEAR_KEY 73

function coop_gear()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "gear"))
    {
        _c.gear = { open: false, slot: -1, data: undefined, asked_t: 0 };
    }
    return _c.gear;
}

function coop_gear_request(_slot)
{
    var _g = coop_gear();
    _g.open = true;
    _g.slot = _slot;
    _g.data = undefined;
    _g.asked_t = current_time;
    coop_msg_begin(COOP_MSG_GEAR_REQ);
    coop_msg_send_to(_slot, true);
    coop_log("gear: asked slot ", _slot);
}

// obj_coop Step
function coop_gear_step()
{
    var _c = coop();
    var _g = coop_gear();
    if (!_c.connected)
    {
        _g.open = false;
        exit;
    }
    if (_g.open)
    {
        if (keyboard_check_pressed(vk_escape) || keyboard_check_pressed(COOP_GEAR_KEY))
        {
            _g.open = false;
            keyboard_clear(vk_escape);
        }
        exit;
    }
    if (!keyboard_check_pressed(COOP_GEAR_KEY) || !instance_exists(obj_player) || coop_chat_is_open() || (variable_struct_exists(_c, "panel") && _c.panel))
    {
        exit;
    }
    // the nearest teammate within reach
    var _best = -1;
    var _bd = 120;
    var _l = coop_puppets();
    for (var _i = 0; _i < array_length(_l); _i++)
    {
        var _d = point_distance(obj_player.x, obj_player.y, _l[_i].x, _l[_i].y);
        if (_d < _bd) { _bd = _d; _best = _l[_i].coop_slot; }
    }
    if (_best >= 0)
    {
        coop_gear_request(_best);
    }
}

// The teammate asked: answer with our gear.
function coop_gear_on_request()
{
    var _c = coop();
    var _out = { equip: [], items: [] };
    if (instance_exists(obj_player))
    {
        with (obj_player)
        {
            var _eq = [player_loadout_get_loot(id, "weapon slot 1", false), player_loadout_get_loot(id, "weapon slot 2", false)];
            for (var _i = 0; _i < array_length(_eq); _i++)
            {
                if (is_struct(_eq[_i]) && item_exists(_eq[_i].item)) array_push(_out.equip, _eq[_i].item);
            }
            if (item_exists(armor_now)) array_push(_out.equip, armor_now);
            if (item_exists(backpack_now)) array_push(_out.equip, backpack_now);
            if (item_exists(headset_now)) array_push(_out.equip, headset_now);
        }
    }
    var _arr = db_read_ext(inventory_target_db(), "Inventory", "items", []);
    for (var _i = 0; _i < array_length(_arr); _i++)
    {
        var _e = _arr[_i];
        if (is_struct(_e) && variable_struct_exists(_e, "placement") && _e.placement == "player inventory" && _e.quantity > 0 && item_exists(_e.item))
        {
            array_push(_out.items, [_e.item, _e.quantity]);
        }
    }
    var _b = coop_msg_begin(COOP_MSG_GEAR);
    buffer_write(_b, buffer_string, json_stringify(_out));
    coop_msg_send_to(_c.msg_from, true);
    coop_log("gear: sent to slot ", _c.msg_from, " equip ", array_length(_out.equip), " items ", array_length(_out.items));
}

function coop_gear_on_msg(_b)
{
    var _c = coop();
    var _g = coop_gear();
    var _d = json_parse(buffer_read(_b, buffer_string));
    if (_g.slot == _c.msg_from && is_struct(_d))
    {
        _g.data = _d;
        coop_log("gear: got slot ", _c.msg_from, " equip ", array_length(_d.equip), " items ", array_length(_d.items));
    }
}

// Draw GUI
function coop_gear_draw()
{
    var _g = coop_gear();
    if (!_g.open)
    {
        exit;
    }
    coop_ui_font(COOP_F_BODY);
    var _x1 = COOP_GW / 2 - 420;
    var _x2 = COOP_GW / 2 + 420;
    var _y1 = 200;
    var _y2 = 860;
    var _y = coop_ui_panel(_x1, _y1, _x2, _y2, coop_tf("{0}'S GEAR", "СНАРЯЖЕНИЕ: {0}", string_upper(coop_peer_name(_g.slot))), COOP_PANEL_ALPHA);
    coop_ui_font(COOP_F_SMALL);
    draw_set_halign(fa_center);
    if (!is_struct(_g.data))
    {
        coop_ui_text((_x1 + _x2) / 2, _y + 40, (current_time - _g.asked_t > 4000) ? coop_t("No answer", "Нет ответа") : coop_t("Asking...", "Запрос..."), COOP_C_DIM);
        draw_set_halign(fa_left);
        exit;
    }
    coop_ui_text((_x1 + _x2) / 2, _y, coop_t("Equipped", "Надето"), COOP_C_DIM);
    _y += 30;
    var _eq = _g.data.equip;
    var _cw = 150;
    var _sx = (_x1 + _x2) / 2 - array_length(_eq) * _cw / 2;
    for (var _i = 0; _i < array_length(_eq); _i++)
    {
        var _cx = _sx + _i * _cw + _cw / 2;
        coop_ui_slot(_cx - 68, _y, _cx + 68, _y + 70, false, 0.9);
        coop_ui_item_icon_wh(_eq[_i], _cx, _y + 35, 128, 60);
    }
    _y += 96;
    coop_ui_text((_x1 + _x2) / 2, _y, coop_t("Inventory", "Инвентарь"), COOP_C_DIM);
    _y += 30;
    var _it = _g.data.items;
    var _cell = 76;
    var _per = 10;
    var _gx = (_x1 + _x2) / 2 - _per * _cell / 2;
    for (var _i = 0; _i < array_length(_it) && _i < 60; _i++)
    {
        var _cx = _gx + (_i mod _per) * _cell;
        var _cy = _y + (_i div _per) * _cell;
        coop_ui_slot(_cx + 2, _cy + 2, _cx + _cell - 2, _cy + _cell - 2, false, 0.9);
        coop_ui_item_icon_wh(_it[_i][0], _cx + _cell / 2, _cy + _cell / 2, _cell - 14, _cell - 14);
        if (_it[_i][1] > 1)
        {
            draw_set_halign(fa_right);
            coop_ui_text_ol(_cx + _cell - 6, _cy + _cell - 24, string(_it[_i][1]), COOP_C_TEXT);
            draw_set_halign(fa_center);
        }
    }
    if (array_length(_it) == 0)
    {
        coop_ui_text((_x1 + _x2) / 2, _y + 10, coop_t("empty", "пусто"), COOP_C_DIM);
    }
    coop_ui_text((_x1 + _x2) / 2, _y2 - 40, coop_t("I / Esc - close", "I / Esc - закрыть"), COOP_C_DIM);
    draw_set_halign(fa_left);
}
