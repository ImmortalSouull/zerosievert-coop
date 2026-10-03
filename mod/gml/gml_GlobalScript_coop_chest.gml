// ZERO Sievert co-op: shared containers.
// 1. Contents are rolled from a seed derived from the raid seed + container position, so both players
//    get the same loot in the same box (map containers and NPC corpses alike).
// 2. Whenever a container near the local player changes (items taken/added), its full content is sent;
//    the partner overwrites its copy. Containers are matched by object + position.

// Hook: top of obj_chest_general Alarm_0 (content roll).
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

function coop_chest_step()
{
    var _c = coop();
    if (!coop_shared_ready() || !instance_exists(obj_player) || _c.frame mod 20 != 0)
    {
        exit;
    }
    var _px = obj_player.x;
    var _py = obj_player.y;
    with (obj_chest_general)
    {
        if (point_distance(x, y, _px, _py) > 72)
        {
            continue;
        }
        var _items = coop_chest_read(id);
        if (_items == undefined)
        {
            continue;
        }
        var _json = json_stringify(_items);
        if (!variable_instance_exists(id, "coop_sig"))
        {
            coop_sig = _json; // first sight: remember, nothing to send
            continue;
        }
        if (coop_sig != _json)
        {
            coop_sig = _json;
            coop_msg_begin(COOP_MSG_CHEST);
            buffer_write(_c.send_buf, buffer_string, coop_chest_key(id));
            buffer_write(_c.send_buf, buffer_string, _json);
            coop_msg_send(true);
            coop_log("chest changed, sent ", coop_chest_key(id));
        }
    }
}

function coop_chest_on_message(_b)
{
    var _key = buffer_read(_b, buffer_string);
    var _json = buffer_read(_b, buffer_string);
    if (!coop_in_raid())
    {
        exit;
    }
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
    if (!instance_exists(_found))
    {
        coop_log("chest update for unknown container ", _key);
        exit;
    }
    var _items = json_parse(_json);
    // Rebuild class_loot structs so the inventory code gets the methods it expects.
    for (var _i = 0; _i < array_length(_items); _i++)
    {
        _items[_i] = coop_struct_to_loot(_items[_i]);
    }
    db_open("all loot");
    db_write("chest_" + string(_found.id), "items", _items);
    db_close();
    _found.coop_sig = json_stringify(coop_chest_read(_found));
    coop_log("chest updated from partner ", _key);
}

function coop_chest_on_request(_b)
{
}
