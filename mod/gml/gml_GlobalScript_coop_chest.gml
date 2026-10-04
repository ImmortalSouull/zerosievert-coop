// ZERO Sievert co-op: shared containers.
// 1. Contents are rolled from a seed derived from the raid seed + container position, so both players get
//    the same loot in the same box (map containers and NPC corpses alike).
// 2. Live sync: while a container is open, its content is read from the UI every few frames (the game only
//    writes it back to the database on close); changes are sent, and an open copy on the partner's side is
//    rebuilt in place.
// 3. Containers created during the raid by a player (dropped items = "discard" bags) are spawned on the
//    partner's side; destroyed containers (emptied bags) disappear on both sides.
// 4. For a guest joining a raid in progress the host sends every changed / dynamic container.
// Containers are matched by object + position. Every content message carries a revision: a machine applies
// only a newer one (equal: the lower slot wins), so a late echo of an older state can never bring back an
// item somebody already took. Changes are detected on the normalized content (item, amount, durability),
// not on the grid layout, which differs between machines.

#macro COOP_MSG_CHEST_SPAWN 52
#macro COOP_MSG_CHEST_GONE 53

function coop_chest_seed()
{
    var _c = coop();
    if (!coop_in_raid() || _c.gen_seed == undefined)
    {
        exit;
    }
    var _h = (_c.gen_seed + floor(x) * 73856093 + floor(y) * 19349663 + real(object_index) * 83492791) mod 2147483647;
    random_set_seed(abs(_h));
}

// Hook: top of obj_chest_general Alarm_0. A container spawned from the network already has its content:
// write it instead of rolling loot. Returns true to skip the roll.
function coop_chest_alarm_hook_inner()
{
    if (variable_instance_exists(id, "coop_pending_items"))
    {
        depth = -y + 6;
        chest_sprite = chest_sprite ?? chest_get_sprite(tipo);
        sprite_index = chest_sprite;
        db_open("all loot");
        db_write("chest_" + string(id), "chest_x", x);
        db_write("chest_" + string(id), "chest_y", y);
        db_write("chest_" + string(id), "items", coop_chest_items_from_json(coop_pending_items));
        db_close();
        coop_sig = coop_chest_norm(coop_chest_read(id));
        coop_pending_items = undefined;
        variable_instance_set(id, "coop_pending_items", undefined);
        return true;
    }
    coop_chest_seed();
    return false;
}

function coop_chest_key(_inst)
{
    return string(real(_inst.object_index)) + "_" + string(floor(_inst.x)) + "_" + string(floor(_inst.y));
}

function coop_chest_read(_inst)
{
    db_open("all loot");
    var _items = db_read("chest_" + string(_inst.id), "items", undefined);
    db_close();
    return _items;
}

function coop_chest_items_from_json(_json)
{
    var _items = is_string(_json) ? json_parse(_json) : _json;
    for (var _i = 0; _i < array_length(_items); _i++)
    {
        _items[_i] = coop_struct_to_loot(_items[_i]);
    }
    return _items;
}

function coop_chest_find(_key)
{
    var _parts = string_split(_key, "_");
    var _obj = real(_parts[0]);
    var _x = real(_parts[1]);
    var _y = real(_parts[2]);
    instance_activate_region(_x - 8, _y - 8, 16, 16, true);
    var _found = -4;
    with (obj_chest_general)
    {
        if (real(object_index) == _obj && abs(floor(x) - _x) <= 1 && abs(floor(y) - _y) <= 1)
        {
            _found = id;
            break;
        }
    }
    return _found;
}

// What counts as a change: items with amounts and durability, in any grid order.
function coop_chest_norm(_items)
{
    if (!is_array(_items))
    {
        return "";
    }
    var _out = [];
    for (var _i = 0; _i < array_length(_items); _i++)
    {
        var _l = _items[_i];
        if (is_struct(_l))
        {
            array_push(_out, string(_l.item) + "*" + string(variable_struct_exists(_l, "quantity") ? _l.quantity : 1) + "@" + string(floor(variable_struct_exists(_l, "durability") ? _l.durability : 100)));
        }
    }
    array_sort(_out, true);
    return string_join_ext(",", _out);
}

function coop_chest_rev(_inst)
{
    return variable_instance_exists(_inst, "coop_rev") ? _inst.coop_rev : 0;
}

// Registry (the owner keeps it for late joiners): key -> latest content json; key + "#rev" -> its revision.
function coop_chest_registry()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "chest_reg"))
    {
        _c.chest_reg = ds_map_create();
    }
    return _c.chest_reg;
}

// A local change of container _inst: next revision, remember, send.
function coop_chest_send_content(_key, _json, _inst = -4)
{
    var _c = coop();
    var _rev = 1;
    if (instance_exists(_inst))
    {
        _rev = coop_chest_rev(_inst) + 1;
        _inst.coop_rev = _rev;
    }
    var _reg = coop_chest_registry();
    ds_map_set(_reg, _key, _json);
    ds_map_set(_reg, _key + "#rev", _rev);
    if (!coop_shared_ready())
    {
        exit;
    }
    coop_msg_begin(COOP_MSG_CHEST);
    buffer_write(_c.send_buf, buffer_string, _key);
    buffer_write(_c.send_buf, buffer_u32, _rev);
    buffer_write(_c.send_buf, buffer_string, _json);
    coop_msg_send(true);
}

// ---- UI side ----

// Content of the container currently open in the inventory UI, as plain data (or undefined).
function coop_chest_ui_items()
{
    var _root = uiLayerGetRoot("inventory layer");
    if (_root == undefined)
    {
        return undefined;
    }
    var _loot_ui_array = uiFindAllType(_root, "class_ui_item");
    var _out = [];
    for (var _i = 0; _i < array_length(_loot_ui_array); _i++)
    {
        var _loot_ui = _loot_ui_array[_i];
        if (_loot_ui.Get("parent").identifier == "other inventory")
        {
            array_push(_out, coop_loot_to_struct(ui_convert_element_to_loot(_loot_ui)));
        }
    }
    return _out;
}

function coop_chest_open_target()
{
    var _d = uiGetData();
    if (!_d.chest_using || _d.chest_target == undefined || !instance_exists(_d.chest_target))
    {
        return -4;
    }
    return _d.chest_target;
}

// Partner changed a container we have open: rebuild the "other inventory" grid from the database.
function coop_chest_ui_refresh(_target)
{
    if (instance_exists(obj_mouse) && variable_instance_exists(obj_mouse, "dragging") && obj_mouse.dragging)
    {
        _target.coop_refresh_pending = true; // never pull an item out from under the cursor
        exit;
    }
    var _root = uiLayerGetRoot("inventory layer");
    if (_root == undefined)
    {
        exit;
    }
    var _loot_ui_array = uiFindAllType(_root, "class_ui_item");
    for (var _i = 0; _i < array_length(_loot_ui_array); _i++)
    {
        if (_loot_ui_array[_i].Get("parent").identifier == "other inventory")
        {
            _loot_ui_array[_i].Destroy();
        }
    }
    ui_chest_populate(_target);
    _target.coop_ui_sig = coop_chest_norm(coop_chest_ui_items());
    _target.coop_refresh_pending = false;
}

function coop_chest_step()
{
    var _c = coop();
    if (!coop_raid_ready() || !instance_exists(obj_player))
    {
        exit;
    }
    // Live: the open container.
    var _open = coop_chest_open_target();
    if (instance_exists(_open) && _c.frame mod 6 == 0)
    {
        with (_open)
        {
            if (variable_instance_exists(id, "coop_refresh_pending") && coop_refresh_pending)
            {
                coop_chest_ui_refresh(id);
            }
            var _items = coop_chest_ui_items();
            if (_items != undefined)
            {
                var _json = json_stringify(_items);
                var _norm = coop_chest_norm(_items);
                if (!variable_instance_exists(id, "coop_ui_sig") || coop_ui_sig == undefined)
                {
                    coop_ui_sig = _norm;
                }
                else if (coop_ui_sig != _norm)
                {
                    coop_ui_sig = _norm;
                    coop_sig = _norm;
                    db_open("all loot");
                    db_write("chest_" + string(id), "items", coop_chest_items_from_json(_json));
                    db_close();
                    coop_chest_send_content(coop_chest_key(id), _json, id);
                    coop_log("chest live change sent ", coop_chest_key(id), " rev ", coop_rev);
                }
            }
        }
    }
    if (variable_struct_exists(_c, "chest_last_open") && _c.chest_last_open != _open && instance_exists(_c.chest_last_open))
    {
        // closed: the next open starts from a fresh UI snapshot
        variable_instance_set(_c.chest_last_open, "coop_ui_sig", undefined);
    }
    _c.chest_last_open = _open;
    // Dynamic containers (dropped bags) waiting to be announced.
    if (_c.frame mod 10 == 0)
    {
        coop_chest_announce_pending();
    }
    // Closed containers near us (writes made on close, scripted changes).
    if (_c.frame mod 20 != 0)
    {
        exit;
    }
    var _px = obj_player.x;
    var _py = obj_player.y;
    with (obj_chest_general)
    {
        if (point_distance(x, y, _px, _py) > 72 || id == _open)
        {
            continue;
        }
        var _items = coop_chest_read(id);
        if (_items == undefined)
        {
            continue;
        }
        var _norm = coop_chest_norm(_items);
        if (!variable_instance_exists(id, "coop_sig") || coop_sig == undefined)
        {
            coop_sig = _norm;
            continue;
        }
        if (coop_sig != _norm)
        {
            coop_sig = _norm;
            coop_chest_send_content(coop_chest_key(id), json_stringify(_items), id);
            coop_log("chest changed, sent ", coop_chest_key(id), " rev ", coop_rev);
        }
    }
}

function coop_chest_on_message(_b)
{
    var _key = buffer_read(_b, buffer_string);
    var _rev = buffer_read(_b, buffer_u32);
    var _json = buffer_read(_b, buffer_string);
    var _c = coop();
    if (!coop_in_raid())
    {
        exit;
    }
    var _reg = coop_chest_registry();
    var _found = coop_chest_find(_key);
    var _local = instance_exists(_found) ? coop_chest_rev(_found) : (ds_map_exists(_reg, _key + "#rev") ? ds_map_find_value(_reg, _key + "#rev") : 0);
    // only newer content wins (same revision: the lower slot's)
    if (_rev < _local || (_rev == _local && _c.msg_from > max(0, _c.slot)))
    {
        if (_c.test_mode)
        {
            coop_log("chest update ignored (old rev ", _rev, " < ", _local, ") ", _key);
        }
        exit;
    }
    ds_map_set(_reg, _key, _json);
    ds_map_set(_reg, _key + "#rev", _rev);
    if (!instance_exists(_found))
    {
        coop_log("chest update for unknown container ", _key);
        exit;
    }
    _found.coop_rev = _rev;
    db_open("all loot");
    db_write("chest_" + string(_found.id), "chest_x", _found.x);
    db_write("chest_" + string(_found.id), "chest_y", _found.y);
    db_write("chest_" + string(_found.id), "items", coop_chest_items_from_json(_json));
    db_close();
    _found.coop_sig = coop_chest_norm(coop_chest_read(_found));
    if (coop_chest_open_target() == _found)
    {
        coop_chest_ui_refresh(_found);
    }
    coop_log("chest updated from partner ", _key);
}

function coop_chest_on_request(_b)
{
}

// ---- dynamic containers ----

// Hook: top of obj_chest_general Create.
function coop_chest_on_create_inner()
{
    if (variable_instance_exists(id, "coop_net_spawned") || !coop_raid_ready())
    {
        exit;
    }
    // Created after the map was generated: a corpse, an air drop or a dropped bag.
    coop_dynamic = true;
    var _c = coop();
    if (!variable_struct_exists(_c, "chest_dyn"))
    {
        _c.chest_dyn = [];
    }
    array_push(_c.chest_dyn, id);
}

// Dropped bags ("discard") are created only on the dropping player's machine: announce them once their
// content has been written (ui_chest_close writes right after creating the bag).
function coop_chest_announce_pending()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "chest_dyn"))
    {
        exit;
    }
    for (var _i = 0; _i < array_length(_c.chest_dyn); _i++)
    {
        var _inst = _c.chest_dyn[_i];
        if (!instance_exists(_inst) || variable_instance_exists(_inst, "coop_announced"))
        {
            continue;
        }
        // Dropped bags exist only on the dropper's side: both announce them. Corpses and air drops are created on
        // both sides (or only on the host): the host's content is the truth.
        if (_inst.tipo != "discard" && !coop_is_world_owner())
        {
            continue;
        }
        if (_inst.alarm[0] > 0)
        {
            continue; // content not rolled yet
        }
        var _items = coop_chest_read(_inst);
        if (_items == undefined)
        {
            continue;
        }
        _inst.coop_announced = true;
        coop_chest_send_spawn(_inst, json_stringify(_items));
    }
}

function coop_chest_send_spawn(_inst, _json)
{
    var _c = coop();
    ds_map_set(coop_chest_registry(), coop_chest_key(_inst), _json);
    if (!coop_shared_ready())
    {
        exit;
    }
    coop_msg_begin(COOP_MSG_CHEST_SPAWN);
    buffer_write(_c.send_buf, buffer_s32, real(_inst.object_index));
    buffer_write(_c.send_buf, buffer_f32, _inst.x);
    buffer_write(_c.send_buf, buffer_f32, _inst.y);
    buffer_write(_c.send_buf, buffer_string, string(_inst.tipo));
    buffer_write(_c.send_buf, buffer_string, is_string(_inst.name_chest) ? _inst.name_chest : "");
    buffer_write(_c.send_buf, buffer_s32, sprite_exists(_inst.sprite_index) ? real(_inst.sprite_index) : -1);
    buffer_write(_c.send_buf, buffer_string, _json);
    coop_msg_send(true);
    coop_log("container spawn sent ", coop_chest_key(_inst), " tipo ", _inst.tipo);
}

function coop_chest_on_spawn(_b)
{
    var _obj = buffer_read(_b, buffer_s32);
    var _x = buffer_read(_b, buffer_f32);
    var _y = buffer_read(_b, buffer_f32);
    var _tipo = buffer_read(_b, buffer_string);
    var _name = buffer_read(_b, buffer_string);
    var _spr = buffer_read(_b, buffer_s32);
    var _json = buffer_read(_b, buffer_string);
    if (!coop_in_raid() || !object_exists(_obj))
    {
        exit;
    }
    var _key = string(_obj) + "_" + string(floor(_x)) + "_" + string(floor(_y));
    var _old = coop_chest_find(_key);
    if (instance_exists(_old))
    {
        // Already there (e.g. both created the same corpse): just take the content.
        db_open("all loot");
        db_write("chest_" + string(_old.id), "items", coop_chest_items_from_json(_json));
        db_close();
        _old.coop_sig = coop_chest_norm(coop_chest_read(_old));
        if (_spr >= 0 && sprite_exists(_spr))
        {
            _old.chest_sprite = _spr;
            _old.sprite_index = _spr;
        }
        if (coop_chest_open_target() == _old)
        {
            coop_chest_ui_refresh(_old);
        }
        exit;
    }
    var _inst = instance_create_depth(_x, _y, -_y, _obj, { coop_net_spawned: true });
    with (_inst)
    {
        tipo = _tipo;
        if (_name != "")
        {
            name_chest = _name;
        }
        coop_pending_items = _json;
        coop_announced = true;
        if (_spr >= 0 && sprite_exists(_spr))
        {
            chest_sprite = _spr;
        }
        alarm[0] = 1;
    }
    coop_log("container spawned from partner ", _key, " tipo ", _tipo);
}

// Hook: obj_chest_general Destroy (an emptied bag / container removed by the game).
function coop_chest_on_destroy_inner()
{
    if (!coop_shared_ready() || variable_instance_exists(id, "coop_net_gone"))
    {
        exit;
    }
    var _c = coop();
    var _key = coop_chest_key(id);
    ds_map_delete(coop_chest_registry(), _key);
    coop_msg_begin(COOP_MSG_CHEST_GONE);
    buffer_write(_c.send_buf, buffer_string, _key);
    coop_msg_send(true);
}

function coop_chest_on_gone(_b)
{
    var _key = buffer_read(_b, buffer_string);
    if (!coop_in_raid())
    {
        exit;
    }
    ds_map_delete(coop_chest_registry(), _key);
    var _found = coop_chest_find(_key);
    if (instance_exists(_found))
    {
        if (coop_chest_open_target() == _found)
        {
            ui_chest_close();
        }
        _found.coop_net_gone = true;
        db_open("all loot");
        db_section_delete("chest_" + string(_found.id));
        db_close();
        with (_found)
        {
            instance_destroy();
        }
    }
}

// Host: a guest just finished loading into our raid - send every dynamic container and every change.
function coop_chest_sync_late_joiner()
{
    var _c = coop();
    var _sent = 0;
    if (variable_struct_exists(_c, "chest_dyn"))
    {
        for (var _i = 0; _i < array_length(_c.chest_dyn); _i++)
        {
            var _inst = _c.chest_dyn[_i];
            instance_activate_object(_inst);
            if (!instance_exists(_inst))
            {
                continue;
            }
            var _items = coop_chest_read(_inst);
            if (_items != undefined)
            {
                coop_chest_send_spawn(_inst, json_stringify(_items));
                _sent++;
            }
        }
    }
    var _reg = coop_chest_registry();
    var _k = ds_map_find_first(_reg);
    while (_k != undefined)
    {
        if (string_pos("#rev", _k) == 0)
        {
            coop_msg_begin(COOP_MSG_CHEST);
            buffer_write(_c.send_buf, buffer_string, _k);
            buffer_write(_c.send_buf, buffer_u32, ds_map_exists(_reg, _k + "#rev") ? ds_map_find_value(_reg, _k + "#rev") : 1);
            buffer_write(_c.send_buf, buffer_string, ds_map_find_value(_reg, _k));
            coop_msg_send(true);
            _sent++;
        }
        _k = ds_map_find_next(_reg, _k);
    }
    coop_log("late joiner: sent ", _sent, " container messages");
}

function coop_chest_reset_room()
{
    var _c = coop();
    _c.chest_dyn = [];
    ds_map_clear(coop_chest_registry());
}

// Called from game code: never let a co-op error escape into it.
function coop_chest_alarm_hook()
{
    try
    {
        return coop_chest_alarm_hook_inner();
    }
    catch (_e)
    {
        coop_report_error(_e);
    }
    return false;
}

// Called from game code: never let a co-op error escape into it.
function coop_chest_on_create()
{
    try
    {
        coop_chest_on_create_inner();
    }
    catch (_e)
    {
        coop_report_error(_e);
    }
}

// Called from game code: never let a co-op error escape into it.
function coop_chest_on_destroy()
{
    try
    {
        coop_chest_on_destroy_inner();
    }
    catch (_e)
    {
        coop_report_error(_e);
    }
}
