// ZERO Sievert co-op: a fallen teammate's things go back to them (2.0.0 item 41).
// When a player dies for real while teammates are still in the raid, their machine drops everything they carried in
// a bag where they fell (a "discard" container: shared like any dropped bag) and tells everybody whose it is. Taking
// things out of that bag is counted per item; when the taker's raid ends with an extraction, the taken things leave
// the taker's inventory and go to the owner (into their inventory in the bunker, like a bunker gift). Open, the bag
// says whose things these are.

#macro COOP_MSG_FALLEN 79
#macro COOP_MSG_RETURN 80

function coop_fallen()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "fallen"))
    {
        _c.fallen = { done: false, bags: {}, taken: [] };
    }
    return _c.fallen;
}

// coop_summary_reset (raid start)
function coop_fallen_reset()
{
    var _f = coop_fallen();
    _f.done = false;
    _f.bags = {};
    _f.taken = [];
}

// obj_coop Step: our own death -> the bag.
function coop_fallen_step()
{
    var _c = coop();
    var _f = coop_fallen();
    if (_f.done || !_c.connected || !coop_in_raid() || !instance_exists(obj_player))
    {
        exit;
    }
    if (!player_state_is(0, scr_player_state_dead) || coop_others_standing() == 0)
    {
        exit;
    }
    _f.done = true;
    var _arr = db_read_ext(inventory_target_db(), "Inventory", "items", []);
    var _items = [];
    var _grid = new class_loot_grid(10, 16);
    for (var _i = 0; _i < array_length(_arr); _i++)
    {
        var _l = _arr[_i];
        if (!is_struct(_l) || !variable_struct_exists(_l, "item") || !item_exists(_l.item) || (variable_struct_exists(_l, "quantity") && _l.quantity <= 0))
        {
            continue;
        }
        var _n = coop_loot_to_struct(_l);
        var _pos = _grid.TryPlace(_n.item);
        _n.x = is_struct(_pos) ? _pos.x * 16 : 0;
        _n.y = is_struct(_pos) ? _pos.y * 16 : 0;
        _n.rotation = is_struct(_pos) ? _pos.rot : 0;
        _n.placement = "other inventory";
        array_push(_items, coop_struct_to_loot(_n));
    }
    _grid.Destroy();
    if (array_length(_items) == 0)
    {
        exit;
    }
    var _bag = instance_create_depth(obj_player.x, obj_player.y + 2, -obj_player.y, obj_chest_general);
    _bag.tipo = "discard";
    db_open("all loot");
    db_write("chest_" + string(_bag.id), "chest_x", _bag.x);
    db_write("chest_" + string(_bag.id), "chest_y", _bag.y);
    db_write("chest_" + string(_bag.id), "items", _items);
    db_close();
    var _key = coop_chest_key(_bag);
    var _b = coop_msg_begin(COOP_MSG_FALLEN);
    buffer_write(_b, buffer_string, _key);
    coop_msg_send(true);
    coop_log("fallen: our things in a bag ", _key, " (", array_length(_items), " stacks)");
}

function coop_fallen_on_msg(_b)
{
    var _c = coop();
    var _key = buffer_read(_b, buffer_string);
    variable_struct_set(coop_fallen().bags, _key, _c.msg_from);
    coop_log("fallen: bag ", _key, " holds the things of slot ", _c.msg_from);
    coop_notify(coop_tf("{0} died - their things are in a bag where they fell", "{0} погиб - его вещи в мешке на месте гибели", coop_peer_name(_c.msg_from)));
}

// Whose bag is this container (slot) or -1.
function coop_fallen_owner(_inst)
{
    var _bags = coop_fallen().bags;
    var _k = coop_chest_key(_inst);
    return variable_struct_exists(_bags, _k) ? variable_struct_get(_bags, _k) : -1;
}

// item -> amount
function coop_fallen_counts(_items)
{
    var _out = {};
    if (!is_array(_items)) return _out;
    for (var _i = 0; _i < array_length(_items); _i++)
    {
        var _l = _items[_i];
        if (is_struct(_l))
        {
            var _q = variable_struct_exists(_l, "quantity") ? _l.quantity : 1;
            variable_struct_set(_out, _l.item, (variable_struct_exists(_out, _l.item) ? variable_struct_get(_out, _l.item) : 0) + _q);
        }
    }
    return _out;
}

// coop_chest_step, a local change of an open container: what left a fallen teammate's bag we took.
function coop_fallen_track(_inst, _before, _now)
{
    var _owner = coop_fallen_owner(_inst);
    if (_owner < 0)
    {
        exit;
    }
    var _a = coop_fallen_counts(_before);
    var _b = coop_fallen_counts(_now);
    var _f = coop_fallen();
    var _names = variable_struct_get_names(_a);
    for (var _i = 0; _i < array_length(_names); _i++)
    {
        var _it = _names[_i];
        var _d = variable_struct_get(_a, _it) - (variable_struct_exists(_b, _it) ? variable_struct_get(_b, _it) : 0);
        if (_d != 0)
        {
            coop_fallen_take(_owner, _it, _d);
        }
    }
    // put back things that were not in it before (rare: a different item)
    _names = variable_struct_get_names(_b);
    for (var _i = 0; _i < array_length(_names); _i++)
    {
        if (!variable_struct_exists(_a, _names[_i])) coop_fallen_take(_owner, _names[_i], -variable_struct_get(_b, _names[_i]));
    }
}

function coop_fallen_take(_owner, _item, _amount)
{
    var _f = coop_fallen();
    for (var _i = 0; _i < array_length(_f.taken); _i++)
    {
        var _e = _f.taken[_i];
        if (_e.owner == _owner && _e.item == _item)
        {
            _e.qty += _amount;
            if (_e.qty <= 0) array_delete(_f.taken, _i, 1);
            coop_log("fallen: taken from slot ", _owner, " ", _item, " now ", max(0, _e.qty));
            return;
        }
    }
    if (_amount > 0)
    {
        array_push(_f.taken, { owner: _owner, item: _item, qty: _amount });
        coop_log("fallen: taken from slot ", _owner, " ", _item, " x", _amount);
    }
}

// Our raid ended (coop_summary_step): extracted -> the taken things go back to their owners.
function coop_fallen_on_raid_end(_survived)
{
    var _f = coop_fallen();
    if (!_survived || array_length(_f.taken) == 0)
    {
        exit;
    }
    var _sent = 0;
    for (var _i = 0; _i < array_length(_f.taken); _i++)
    {
        var _e = _f.taken[_i];
        var _have = 0;
        try
        {
            _have = inventory_item_exists(_e.item) ? _e.qty : 0;
        }
        catch (_ex) { }
        if (_have <= 0)
        {
            continue; // used up or left behind
        }
        inventory_remove_item(_e.item, _e.qty);
        var _b = coop_msg_begin(COOP_MSG_RETURN);
        buffer_write(_b, buffer_string, json_stringify({ item: _e.item, quantity: _e.qty, durability: 100 }));
        coop_msg_send_to(_e.owner, true);
        _sent++;
        coop_log("fallen: returned ", _e.item, " x", _e.qty, " to slot ", _e.owner);
    }
    _f.taken = [];
    if (_sent > 0)
    {
        coop_notify(coop_t("Your fallen teammate's things went back to them", "Вещи погибшего напарника вернулись к нему"));
    }
}

// The owner: our things are back (into the inventory once we are in the bunker, coop_give_receive_pending).
function coop_fallen_on_return(_b)
{
    var _c = coop();
    var _json = buffer_read(_b, buffer_string);
    if (!variable_struct_exists(_c, "give_in")) _c.give_in = [];
    array_push(_c.give_in, _json);
    var _d = json_parse(_json);
    coop_log("fallen: got back ", _d.item, " x", _d.quantity, " from slot ", _c.msg_from);
    coop_notify(coop_tf("{0} brought back your {1}", "{0} вернул вам: {1}", coop_peer_name(_c.msg_from), item_get_name(_d.item)));
}

// Draw GUI: over an open fallen teammate's bag, whose things these are.
function coop_fallen_draw()
{
    var _open = coop_chest_open_target();
    if (!instance_exists(_open))
    {
        exit;
    }
    var _owner = coop_fallen_owner(_open);
    if (_owner < 0)
    {
        exit;
    }
    coop_ui_font(COOP_F_SMALL);
    draw_set_halign(fa_center);
    var _t = coop_tf("{0}'s things - what you take goes back to {0} when you extract", "Вещи {0} - всё, что возьмёте, вернётся к {0} после эвакуации", coop_peer_name(_owner));
    var _w = string_width(_t) / 2 + 16;
    coop_ui_rect(COOP_GW / 2 - _w, 70, COOP_GW / 2 + _w, 106, c_black, 0.75);
    coop_ui_rect(COOP_GW / 2 - _w, 103, COOP_GW / 2 + _w, 106, coop_slot_colour(_owner));
    coop_ui_text(COOP_GW / 2, 78, _t, COOP_C_KEY);
    draw_set_halign(fa_left);
}
