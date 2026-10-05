// ZERO Sievert co-op: extra difficulty settings (defined in the game's own difficulty system, so they
// are chosen per save when it is created and show up in the Difficulty menu "Co-op" tab), plus the
// host -> guest sync of raid-wide rules.

// Hook: in __difficulty_init, before the presets are built.
function coop_difficulty_define()
{
    __difficulty_define_toggle("coop_revive_enabled", true, "coop.difficulty.revive_enabled", "coop.desc.revive_enabled");
    __difficulty_define_range("coop_down_seconds", 60, 10, 180, "coop.difficulty.down_seconds", "coop.desc.down_seconds");
    __difficulty_define_range("coop_second_down_hp", 0.6, 0.1, 1, "coop.difficulty.second_down_hp", "coop.desc.second_down_hp");
    __difficulty_define_range("coop_revive_time_none", 10, 1, 30, "coop.difficulty.revive_time_none", "coop.desc.revive_time_none");
    __difficulty_define_range("coop_revive_time_bandage", 7, 1, 30, "coop.difficulty.revive_time_bandage", "coop.desc.revive_time_bandage");
    __difficulty_define_range("coop_revive_time_medkit", 5, 1, 30, "coop.difficulty.revive_time_medkit", "coop.desc.revive_time_medkit");
    __difficulty_define_toggle("coop_friendly_fire", false, "coop.difficulty.friendly_fire", "coop.desc.friendly_fire");
    __difficulty_define_range("coop_group_enemies", 0.25, 0, 1, "coop.difficulty.group_enemies", "coop.desc.group_enemies");
    __difficulty_define_range("coop_group_hp", 0, 0, 0.5, "coop.difficulty.group_hp", "coop.desc.group_hp");
    __difficulty_define_range("enemy_count_mult", 1, 0, 3, "coop.difficulty.enemy_count", "coop.desc.enemy_count");
    __difficulty_define_range("anomaly_mult", 1, 0, 3, "coop.difficulty.anomaly_amount", "coop.desc.anomaly_amount");
}

// Hook: difficulty_get_description. Our settings keep a translation key (coop.desc.*) as their description;
// the game shows descriptions as they are, so translate here (English if the language has no row).
function coop_difficulty_description(_d)
{
    if (!is_string(_d) || string_pos("coop.desc.", _d) != 1)
    {
        return _d;
    }
    var _t = language_get_string(_d);
    if (is_string(_t) && _t != "" && _t != _d)
    {
        return _t;
    }
    switch (_d)
    {
        case "coop.desc.revive_enabled": return "Lethal damage downs you instead of killing you while a teammate on their feet is in the raid.";
        case "coop.desc.down_seconds": return "Seconds a downed player waits for help before dying (half as long on the second down).";
        case "coop.desc.second_down_hp": return "Multiplier on the health you get back when revived from the second down.";
        case "coop.desc.revive_time_none": return "Seconds to revive a teammate without items.";
        case "coop.desc.revive_time_bandage": return "Seconds to revive a teammate with a bandage.";
        case "coop.desc.revive_time_medkit": return "Seconds to revive a teammate with a medkit.";
        case "coop.desc.friendly_fire": return "Your bullets can hurt your teammates.";
        case "coop.desc.group_enemies": return "Extra enemies for every player beyond the first (0.25 = +25% per player).";
        case "coop.desc.group_hp": return "Extra enemy health for every player beyond the first (0.1 = +10% per player).";
        case "coop.desc.enemy_count": return "Multiplier on how many enemies spawn in a raid.";
        case "coop.desc.anomaly_amount": return "Multiplier on how many anomalies are generated in a raid.";
    }
    return "";
}

// Raid-wide rules come from the host while connected.
#macro COOP_SHARED_SETTINGS ["coop_revive_enabled", "coop_down_seconds", "coop_second_down_hp", "coop_revive_time_none", "coop_revive_time_bandage", "coop_revive_time_medkit", "coop_friendly_fire", "coop_group_enemies", "coop_group_hp"]

// Group size scaling (enemies, enemy health), fixed by the host when it sends the settings at raid start, so
// every machine generates the raid with the same numbers.
// Host, when a raid starts (and in the bunker): the group scaling for the players present now.
function coop_group_fix()
{
    var _c = coop();
    var _extra = coop_player_count() - 1;
    _c.coop_group_enemy_mult = 1 + difficulty_get("coop_group_enemies") * _extra;
    _c.coop_group_hp_mult = 1 + difficulty_get("coop_group_hp") * _extra;
}

function coop_group_factor(_what)
{
    var _c = coop();
    var _key = (_what == "hp") ? "coop_group_hp_mult" : "coop_group_enemy_mult";
    if (_c.role == "guest" && _c.connected && variable_struct_exists(_c, "host_settings") && variable_struct_exists(_c.host_settings, _key))
    {
        return variable_struct_get(_c.host_settings, _key);
    }
    if (_c.role == "host" && variable_struct_exists(_c, _key))
    {
        return variable_struct_get(_c, _key);
    }
    return 1;
}

function coop_setting(_name)
{
    var _key = _name;
    switch (_name)
    {
        case "revive_enabled": _key = "coop_revive_enabled"; break;
        case "down_seconds": _key = "coop_down_seconds"; break;
        case "second_down_hp_mult": _key = "coop_second_down_hp"; break;
        case "revive_time_none": _key = "coop_revive_time_none"; break;
        case "revive_time_bandage": _key = "coop_revive_time_bandage"; break;
        case "revive_time_medkit": _key = "coop_revive_time_medkit"; break;
        case "friendly_fire": _key = "coop_friendly_fire"; break;
    }
    var _c = coop();
    if (_c.role == "guest" && _c.connected && variable_struct_exists(_c, "host_settings") && variable_struct_exists(_c.host_settings, _key))
    {
        return variable_struct_get(_c.host_settings, _key);
    }
    return difficulty_get(_key);
}

// Difficulty keys that shape the shared world (generation, loot rolls, enemy amounts): in a shared raid the
// guest must use the host's values or the two maps/containers diverge.
function coop_is_world_setting(_key)
{
    return string_pos("loot_", _key) == 1 || string_pos("armor_class_", _key) == 1 || _key == "enemy_count_mult"
        || _key == "anomaly_mult" || _key == "enemy_human_hp" || _key == "enemy_mutant_hp";
}

// Hook: top of difficulty_get(). Returns the host's value for world keys while we are a connected guest.
function coop_difficulty_override(_key)
{
    var _c = coop();
    if (variable_struct_exists(_c, "test_diff") && variable_struct_exists(_c.test_diff, _key))
    {
        return variable_struct_get(_c.test_diff, _key); // -coop_diff (tests)
    }
    if (variable_struct_exists(_c, "coop_hp_guard") && _c.coop_hp_guard)
    {
        return undefined;
    }
    if (room == room1 && (_key == "enemy_human_hp" || _key == "enemy_mutant_hp") && _c.connected)
    {
        var _f = coop_group_factor("hp");
        if (_f != 1)
        {
            var _base = (_c.role == "guest" && variable_struct_exists(_c, "host_settings") && variable_struct_exists(_c.host_settings, _key)) ? variable_struct_get(_c.host_settings, _key) : undefined;
            if (_base == undefined)
            {
                // our own value (host): read it without coming back here
                _c.coop_hp_guard = true;
                _base = difficulty_get(_key);
                _c.coop_hp_guard = false;
            }
            return _base * _f;
        }
    }
    if (_c.role != "guest" || !_c.connected || room != room1 || !variable_struct_exists(_c, "host_settings") || !coop_is_world_setting(_key))
    {
        return undefined;
    }
    if (variable_struct_exists(_c.host_settings, _key))
    {
        return variable_struct_get(_c.host_settings, _key);
    }
    return undefined;
}

function coop_settings_send()
{
    var _c = coop();
    if (_c.role != "host" || !_c.connected)
    {
        exit;
    }
    var _data = {};
    // group scaling is fixed when the raid starts (coop_group_fix): a player joining later must generate the
    // same raid, so it gets the numbers the raid was made with
    if (!variable_struct_exists(_c, "coop_group_enemy_mult") || !coop_in_raid())
    {
        coop_group_fix();
    }
    variable_struct_set(_data, "coop_group_enemy_mult", _c.coop_group_enemy_mult);
    variable_struct_set(_data, "coop_group_hp_mult", _c.coop_group_hp_mult);
    var _keys = COOP_SHARED_SETTINGS;
    for (var _i = 0; _i < array_length(_keys); _i++)
    {
        variable_struct_set(_data, _keys[_i], difficulty_get(_keys[_i]));
    }
    var _all = variable_struct_get_names(global.__difficulty_data);
    for (var _i = 0; _i < array_length(_all); _i++)
    {
        if (coop_is_world_setting(_all[_i]))
        {
            variable_struct_set(_data, _all[_i], difficulty_get(_all[_i]));
        }
    }
    coop_msg_begin(COOP_MSG_SETTINGS);
    buffer_write(_c.send_buf, buffer_string, json_stringify(_data));
    coop_msg_send(true);
}

function coop_settings_on_message(_b)
{
    var _json = buffer_read(_b, buffer_string);
    coop().host_settings = json_parse(_json);
    coop_log("host settings: ", _json);
}

// Replaces scr_spawner_spawn / scr_spawner_spawn_group chance rolls: enemies scale with enemy_count_mult.
function coop_spawn_count(_chance, _obj, _group)
{
    var _mult = 1;
    if (object_is_ancestor(_obj, obj_npc_parent))
    {
        _mult = difficulty_get("enemy_count_mult") * coop_group_factor("enemies");
    }
    var _c = _chance * _mult;
    var _n = floor(_c / 100);
    if (scr_chance(_c - _n * 100))
    {
        _n++;
    }
    return _n * _group;
}

// Hook: top of anomaly generator Create events. Thins out or multiplies anomaly fields.
function coop_anomaly_scale()
{
    if (variable_instance_exists(id, "coop_anomaly_clone"))
    {
        return false;
    }
    var _m = difficulty_get("anomaly_mult");
    if (_m == 1)
    {
        return false;
    }
    if (_m < 1)
    {
        if (random(1) > _m)
        {
            instance_destroy(id, false);
            return true;
        }
        return false;
    }
    var _extra = floor(_m - 1);
    if (random(1) < (_m - 1 - _extra))
    {
        _extra++;
    }
    repeat (_extra)
    {
        var _dir = irandom(359);
        var _dis = irandom_range(64, 160);
        instance_create_depth(x + lengthdir_x(_dis, _dir), y + lengthdir_y(_dis, _dir), depth, object_index, { coop_anomaly_clone: true });
    }
    return false;
}
