// ZERO Sievert co-op: give an item to a teammate. X next to a standing teammate opens a list of the items in
// your inventory grid (not the equipped ones); the chosen stack leaves your inventory and
// - in a raid: appears in a bag at the teammate's feet (the dropped-bag mechanics every machine already syncs);
// - in the bunker (no shared bags there): travels as data and goes straight into the teammate's inventory grid
//   (a bag at their feet if it is full). The teammate is told about it.

#macro COOP_MSG_GIVE 16
#macro COOP_GIVE_RANGE 48

function coop_give()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "give"))
    {
        _c.give = { menu: false, sel: 0, options: [], target: -4, opened_frame: -1 };
    }
    return _c.give;
}

// The nearest teammate on their feet within reach.
function coop_give_target()
{
    if (!instance_exists(obj_player) || coop_down_is_down() || !player_state_is(0, scr_player_state_move))
    {
        return -4;
    }
    var _best = -4;
    var _bd = COOP_GIVE_RANGE;
    var _px = obj_player.x;
    var _py = obj_player.y;
    with (obj_player_puppet)
    {
        if (variable_instance_exists(id, "coop_slot") && !coop_puppet_is_down(id))
        {
            var _d = point_distance(_px, _py, x, y);
            if (_d < _bd)
            {
                _bd = _d;
                _best = id;
            }
        }
    }
    return _best;
}

function coop_give_options()
{
    var _out = [];
    var _arr = db_read_ext(inventory_target_db(), "Inventory", "items", []);
    for (var _i = 0; _i < array_length(_arr); _i++)
    {
        var _l = _arr[_i];
        if (is_struct(_l) && variable_struct_exists(_l, "placement") && _l.placement == "player inventory" && _l.quantity > 0)
        {
            var _name = loot_get_name(_l);
            if (_l.quantity > 1)
            {
                _name += " x" + string(_l.quantity);
            }
            array_push(_out, { loot: _l, name: _name });
        }
    }
    return _out;
}

// obj_coop Step.
function coop_give_step()
{
    var _c = coop();
    var _g = coop_give();
    if (is_in_hub() || coop_in_raid())
    {
        coop_give_receive_pending(); // bunker gifts, trades, a fallen teammate's things
    }
    if (!_c.connected || !(coop_in_raid() || is_in_hub()) || !instance_exists(obj_player) || (variable_struct_exists(_c, "panel") && _c.panel))
    {
        _g.menu = false;
        exit;
    }
    var _key = keyboard_check_pressed(ord("X"));
    if (variable_struct_exists(_c, "sim_give") && _c.sim_give)
    {
        _c.sim_give = false; // test input
        _key = true;
    }
    if (!_g.menu)
    {
        if (!_key)
        {
            exit;
        }
        var _t = coop_give_target();
        if (!instance_exists(_t))
        {
            coop_notify(coop_t("Stand next to a teammate to give an item", "Подойдите к напарнику, чтобы передать предмет"));
            exit;
        }
        _g.options = coop_give_options();
        if (array_length(_g.options) == 0)
        {
            coop_notify(coop_t("Nothing to give: your inventory is empty", "Нечего передать: инвентарь пуст"));
            exit;
        }
        _g.target = _t;
        _g.sel = 0;
        _g.menu = true;
        _g.opened_frame = _c.frame;
        exit;
    }
    // menu open
    if (!instance_exists(_g.target) || point_distance(obj_player.x, obj_player.y, _g.target.x, _g.target.y) > COOP_GIVE_RANGE * 1.5 || !player_state_is(0, scr_player_state_move))
    {
        _g.menu = false;
        exit;
    }
    var _n = array_length(_g.options);
    if (mouse_wheel_up() || keyboard_check_pressed(vk_up) || coop_pad_pressed(gp_padu)) _g.sel = (_g.sel - 1 + _n) mod _n;
    if (mouse_wheel_down() || keyboard_check_pressed(vk_down) || coop_pad_pressed(gp_padd)) _g.sel = (_g.sel + 1) mod _n;
    if (keyboard_check_pressed(vk_backspace) || keyboard_check_pressed(vk_escape) || coop_pad_pressed(gp_face2))
    {
        _g.menu = false;
        keyboard_clear(vk_escape);
        exit;
    }
    var _ok = keyboard_check_pressed(vk_enter) || coop_pad_pressed(gp_face1) || (_key && _c.frame != _g.opened_frame);
    if (variable_struct_exists(_c, "sim_give_ok") && _c.sim_give_ok)
    {
        _c.sim_give_ok = false;
        _ok = true;
    }
    if (_ok)
    {
        _g.menu = false;
        coop_give_do(_g.options[_g.sel].loot, _g.target);
    }
}

function coop_give_do(_loot, _target)
{
    var _c = coop();
    // take the stack out of our inventory
    var _db = inventory_target_db();
    db_open(_db);
    var _arr = db_read("Inventory", "items", []);
    var _found = -1;
    for (var _i = 0; _i < array_length(_arr); _i++)
    {
        if (_arr[_i] == _loot)
        {
            _found = _i;
            break;
        }
    }
    if (_found < 0)
    {
        db_close();
        coop_notify(coop_t("The item is gone", "Предмет пропал"));
        exit;
    }
    var _copy = loot_duplicate(_loot);
    array_delete(_arr, _found, 1);
    db_write("Inventory", "items", _arr);
    db_close();
    if (is_in_hub())
    {
        var _hname = loot_get_name(_copy);
        coop_log("gave ", _copy.item, " x", _copy.quantity, " to slot ", _target.coop_slot, " (bunker)");
        coop_notify(coop_tf("Given to {0}: {1}", "Передано {0}: {1}", coop_peer_name(_target.coop_slot), _hname));
        coop_msg_begin(COOP_MSG_GIVE);
        buffer_write(_c.send_buf, buffer_string, _hname);
        buffer_write(_c.send_buf, buffer_string, json_stringify(_copy));
        coop_msg_send_to(_target.coop_slot, true);
        exit;
    }
    // the bag at the teammate's feet (synced to everybody like any dropped bag)
    _copy.x = 0;
    _copy.y = 0;
    _copy.rotation = 0;
    _copy.placement = "other inventory";
    var _bag = instance_create_depth(_target.x, _target.y + 2, -_target.y, obj_chest_general);
    _bag.tipo = "discard";
    db_open("all loot");
    var _key = "chest_" + string(_bag.id);
    db_write(_key, "chest_x", _bag.x);
    db_write(_key, "chest_y", _bag.y);
    db_write(_key, "items", [_copy]);
    db_close();
    var _name = loot_get_name(_copy);
    coop_log("gave ", _copy.item, " x", _copy.quantity, " to slot ", _target.coop_slot);
    coop_notify(coop_tf("Given to {0}: {1}", "Передано {0}: {1}", coop_peer_name(_target.coop_slot), _name));
    coop_msg_begin(COOP_MSG_GIVE);
    buffer_write(_c.send_buf, buffer_string, _name);
    buffer_write(_c.send_buf, buffer_string, ""); // the bag carries the item
    coop_msg_send_to(_target.coop_slot, true);
}

function coop_give_on_message(_b)
{
    var _name = buffer_read(_b, buffer_string);
    var _json = buffer_read(_b, buffer_string);
    var _c = coop();
    coop_log("received ", _name, " from slot ", _c.msg_from, (_json != "") ? " (bunker)" : "");
    if (_json == "")
    {
        coop_notify(coop_tf("{0} gave you: {1} (bag at your feet)", "{0} передал вам: {1} (мешок у ваших ног)", coop_peer_name(_c.msg_from), _name));
        exit;
    }
    // bunker: into the inventory as soon as it is safe (coop_give_receive_pending)
    if (!variable_struct_exists(_c, "give_in"))
    {
        _c.give_in = [];
    }
    array_push(_c.give_in, _json);
    coop_notify(coop_tf("{0} gave you: {1}", "{0} передал вам: {1}", coop_peer_name(_c.msg_from), _name));
}

// Bunker gifts go into the inventory grid. Not while the inventory screen is open: it keeps its own copy of the
// items and writes it back when it closes, which would drop the gift - wait until it is closed.
function coop_give_receive_pending()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "give_in") || array_length(_c.give_in) == 0 || !instance_exists(obj_player))
    {
        exit;
    }
    if (__uiGlobal().__defaultOnion.LayerExists("inventory layer"))
    {
        exit;
    }
    var _json = _c.give_in[0];
    array_delete(_c.give_in, 0, 1);
    var _loot = json_parse(_json);
    var _db = inventory_target_db();
    db_open(_db);
    var _arr = db_read("Inventory", "items", []);
    db_close();
    // same placement as the game's inventory_add_item (8x11 grid, 16 px cells)
    var _grid = new class_loot_grid(8, 11);
    _grid.PlaceFromInventoryLootArray(_arr);
    var _pos = _grid.TryPlace(_loot.item);
    _grid.Destroy();
    if (is_struct(_pos))
    {
        _loot.x = _pos.x * 16;
        _loot.y = _pos.y * 16;
        _loot.rotation = _pos.rot;
        _loot.placement = "player inventory";
        array_push(_arr, _loot);
        db_open(_db);
        db_write("Inventory", "items", _arr);
        db_close();
        coop_log("gift placed in the inventory: ", _loot.item, " x", _loot.quantity);
        exit;
    }
    // inventory full: a bag at our feet, like the game does when inventory_add_item finds no room
    _loot.x = 0;
    _loot.y = 0;
    _loot.rotation = 0;
    _loot.placement = "other inventory";
    var _bag = instance_create_depth(obj_player.x, obj_player.y + 2, -obj_player.y, obj_chest_general);
    _bag.tipo = "discard";
    db_open("all loot");
    var _key = "chest_" + string(_bag.id);
    db_write(_key, "chest_x", _bag.x);
    db_write(_key, "chest_y", _bag.y);
    db_write(_key, "items", [_loot]);
    db_close();
    coop_notify(coop_t("Inventory full - the gift is in a bag at your feet", "Инвентарь полон - подарок в мешке у ваших ног"));
    coop_log("gift dropped in a bag (inventory full): ", _loot.item);
}

// Draw GUI (UI space): the list next to the teammate, inventory-style rows with item icons.
function coop_give_draw_gui()
{
    var _g = coop_give();
    if (!_g.menu || !instance_exists(_g.target))
    {
        exit;
    }
    coop_ui_font(COOP_F_BODY);
    var _gx = coop_ui_world_x(_g.target.x);
    var _gy = coop_ui_world_y(_g.target.y);
    var _n = array_length(_g.options);
    var _show = min(_n, 8);
    var _first = clamp(_g.sel - 3, 0, max(0, _n - _show));
    var _rh = 52;
    var _w = 300;
    for (var _i = _first; _i < _first + _show; _i++)
    {
        _w = max(_w, string_width(_g.options[_i].name) + 104);
    }
    var _title = coop_tf("Give to {0}", "Передать: {0}", coop_peer_name(_g.target.coop_slot));
    _w = min(max(_w, string_width(_title) + 40), 640);
    var _h = 66 + _show * (_rh + 4) + 64;
    var _bx = clamp(_gx + 60, 16, COOP_GW - _w - 16);
    var _by = clamp(_gy - _h / 2, 140, COOP_GH - _h - 140);
    var _y = coop_ui_panel(_bx, _by, _bx + _w, _by + _h, _title);
    draw_set_valign(fa_middle);
    for (var _i = _first; _i < _first + _show; _i++)
    {
        var _sel = (_i == _g.sel);
        coop_ui_slot(_bx + 14, _y, _bx + _w - 14, _y + _rh, _sel);
        var _o = _g.options[_i];
        coop_ui_item_icon(_o.loot.item, _bx + 42, _y + _rh / 2, 42);
        var _nm = _o.name;
        while (string_length(_nm) > 4 && string_width(_nm) > _w - 104)
        {
            _nm = string_copy(_nm, 1, string_length(_nm) - 4) + "..";
        }
        coop_ui_text(_bx + 74, _y + _rh / 2, _nm, _sel ? COOP_C_KEY : COOP_C_TEXT);
        _y += _rh + 4;
    }
    draw_set_valign(fa_top);
    if (_n > _show)
    {
        draw_set_halign(fa_right);
        coop_ui_text(_bx + _w - 16, _y + 14, string(_g.sel + 1) + "/" + string(_n), COOP_C_DIM);
        draw_set_halign(fa_left);
    }
    coop_ui_font(COOP_F_SMALL);
    coop_ui_prompt(_bx + 14, _y + 8, "X", coop_t("give", "передать"), 0);
}
