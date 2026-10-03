// ZERO Sievert co-op: host-authoritative NPCs.
// Host: real NPCs, each gets a network id (nid) and is streamed to the guest.
// Guest: every locally generated NPC is removed; replicas are spawned from host data and their AI
// (Step + movement alarms) is switched off. End Step still runs, so walk/idle animation, facing
// and footsteps come for free from the replicated position and state.

#macro COOP_MSG_NPC_STATESTR 35
#macro COOP_NPC_SPAWN_VARS ["npc_id", "faction", "npc_name", "arma_now", "armor_id", "backpack_now", "sprite_idle", "sprite_move", "sprite_dead", "hp", "hp_max", "ammo_id_now", "npc_speaker_id", "can_be_damaged", "image_xscale"]

function coop_npc_reset_room()
{
    var _c = coop();
    ds_map_clear(_c.npc_by_nid);
    _c.npc_state_ids = {};
    _c.npc_state_names = [];
    _c.npc_state_next = 0;
}

function coop_npc_get_nid(_inst)
{
    with (_inst)
    {
        if (!variable_instance_exists(id, "coop_nid"))
        {
            var _c = coop();
            coop_nid = _c.npc_next_nid;
            _c.npc_next_nid++;
            ds_map_set(_c.npc_by_nid, coop_nid, id);
            coop_spawn_sent = false;
        }
        return coop_nid;
    }
    return 0;
}

function coop_npc_find(_nid)
{
    var _inst = ds_map_find_value(coop().npc_by_nid, _nid);
    return (_inst != undefined && instance_exists(_inst)) ? _inst : -4;
}

function coop_npc_is_replica()
{
    return variable_instance_exists(id, "coop_replica") && coop_replica == true;
}

// Prepended to every NPC Step event. Replicas skip their AI; the replica update runs once per frame.
function coop_npc_skip_step_inner()
{
    if (!coop_npc_is_replica())
    {
        return false;
    }
    if (coop_replica_frame != coop().frame)
    {
        coop_replica_frame = coop().frame;
        coop_npc_replica_step();
    }
    return true;
}

// Prepended to NPC alarms that move or re-target (3, 5, 6).
function coop_npc_skip_alarm()
{
    return coop_npc_is_replica();
}

// ---- host side ----

function coop_npc_host_step()
{
    var _c = coop();
    if (_c.role != "host" || !coop_shared_ready())
    {
        exit;
    }
    var _partner = coop_partner();
    var _px = instance_exists(_partner) ? _partner.x : obj_player.x;
    var _py = instance_exists(_partner) ? _partner.y : obj_player.y;
    var _far_tick = (_c.frame mod 30 == 0);
    var _near_tick = (_c.frame mod 4 == 0);
    if (!_near_tick && !_far_tick)
    {
        exit;
    }
    // Pass 1: make sure every NPC has an id and the guest knows about it.
    with (obj_npc_parent)
    {
        if (hp > 0)
        {
            coop_npc_get_nid(id);
            if (!coop_spawn_sent)
            {
                coop_npc_send_spawn(id);
                coop_spawn_sent = true;
            }
        }
    }
    // Pass 2: batched position/state snapshots.
    var _b = _c.send_buf;
    var _count = 0;
    var _count_pos = 0;
    with (obj_npc_parent)
    {
        if (hp <= 0 || !variable_instance_exists(id, "coop_nid"))
        {
            continue;
        }
        var _nid = coop_nid;
        var _near = point_distance(x, y, _px, _py) < 720;
        if (!(_near ? _near_tick : _far_tick))
        {
            continue;
        }
        var _sid = coop_npc_state_id(state);
        if (_count == 0)
        {
            coop_msg_begin(COOP_MSG_NPC_SNAP);
            _count_pos = buffer_tell(_b);
            buffer_write(_b, buffer_u16, 0);
        }
        buffer_write(_b, buffer_u32, _nid);
        buffer_write(_b, buffer_f32, x);
        buffer_write(_b, buffer_f32, y);
        buffer_write(_b, buffer_f32, weapon_pointing_direction);
        buffer_write(_b, buffer_f32, target_for_image_scale);
        buffer_write(_b, buffer_f32, hp);
        buffer_write(_b, buffer_u16, _sid);
        buffer_write(_b, buffer_s16, variable_instance_exists(id, "human_state_now") ? human_state_now : -1);
        var _flags = 0;
        if (variable_instance_exists(id, "damage_on_hit") && damage_on_hit) _flags |= 1;
        buffer_write(_b, buffer_u8, _flags);
        _count++;
        if (_count >= 36)
        {
            buffer_poke(_b, _count_pos, buffer_u16, _count);
            coop_msg_send(false);
            _count = 0;
        }
    }
    if (_count > 0)
    {
        buffer_poke(_b, _count_pos, buffer_u16, _count);
        coop_msg_send(false);
    }
}

function coop_npc_state_id(_state)
{
    var _c = coop();
    var _key = string(_state);
    if (variable_struct_exists(_c.npc_state_ids, _key))
    {
        return variable_struct_get(_c.npc_state_ids, _key);
    }
    var _id = _c.npc_state_next;
    _c.npc_state_next++;
    variable_struct_set(_c.npc_state_ids, _key, _id);
    // Announce the new string on its own reliable message, then resume the caller's buffer.
    var _save = buffer_create(max(1, buffer_tell(_c.send_buf)), buffer_fixed, 1);
    var _len = buffer_tell(_c.send_buf);
    buffer_copy(_c.send_buf, 0, _len, _save, 0);
    coop_msg_begin(COOP_MSG_NPC_STATESTR);
    buffer_write(_c.send_buf, buffer_u16, _id);
    buffer_write(_c.send_buf, buffer_string, _key);
    coop_msg_send(true);
    buffer_copy(_save, 0, _len, _c.send_buf, 0);
    buffer_seek(_c.send_buf, buffer_seek_start, _len);
    buffer_delete(_save);
    return _id;
}

function coop_npc_send_spawn(_inst)
{
    var _c = coop();
    var _data = {};
    var _vars = COOP_NPC_SPAWN_VARS;
    with (_inst)
    {
        for (var _i = 0; _i < array_length(_vars); _i++)
        {
            if (variable_instance_exists(id, _vars[_i]))
            {
                var _v = variable_instance_get(id, _vars[_i]);
                if (is_string(_v) || is_real(_v) || is_bool(_v) || is_int64(_v))
                {
                    variable_struct_set(_data, _vars[_i], _v);
                }
                else if (_vars[_i] == "sprite_idle" || _vars[_i] == "sprite_move" || _vars[_i] == "sprite_dead")
                {
                    variable_struct_set(_data, _vars[_i], real(_v));
                }
            }
        }
        coop_msg_begin(COOP_MSG_NPC_SPAWN);
        buffer_write(_c.send_buf, buffer_u32, coop_nid);
        buffer_write(_c.send_buf, buffer_s32, real(object_index));
        buffer_write(_c.send_buf, buffer_f32, x);
        buffer_write(_c.send_buf, buffer_f32, y);
        buffer_write(_c.send_buf, buffer_string, json_stringify(_data));
        coop_msg_send(true);
    }
}

// Hook: top of obj_npc_parent Destroy.
function coop_npc_on_destroyed_inner()
{
    var _c = coop();
    if (_c.role != "host" || !_c.connected || !variable_instance_exists(id, "coop_nid"))
    {
        exit;
    }
    coop_msg_begin((hp <= 0) ? COOP_MSG_NPC_DIE : COOP_MSG_NPC_GONE);
    buffer_write(_c.send_buf, buffer_u32, coop_nid);
    buffer_write(_c.send_buf, buffer_f32, x);
    buffer_write(_c.send_buf, buffer_f32, y);
    coop_msg_send(true);
    ds_map_delete(_c.npc_by_nid, coop_nid);
}

// ---- guest side ----

// obj_coop Begin Step: remove every NPC the guest generated itself.
function coop_npc_guest_purge()
{
    if (!coop_guest_in_raid())
    {
        exit;
    }
    with (obj_npc_parent)
    {
        if (!variable_instance_exists(id, "coop_replica"))
        {
            coop_npc_list_forget(id);
            instance_destroy(id, false);
        }
    }
}

// Disconnected mid-raid: replicas become normal NPCs again so the raid stays playable solo.
function coop_npc_guest_release()
{
    with (obj_npc_parent)
    {
        if (coop_npc_is_replica())
        {
            coop_replica = false; // AI takes over again, purge leaves it alone (variable still exists)
        }
    }
}

function coop_npc_on_spawn(_b)
{
    var _nid = buffer_read(_b, buffer_u32);
    var _obj = buffer_read(_b, buffer_s32);
    var _x = buffer_read(_b, buffer_f32);
    var _y = buffer_read(_b, buffer_f32);
    var _json = buffer_read(_b, buffer_string);
    if (!coop_guest_in_raid() || !object_exists(_obj))
    {
        exit;
    }
    if (ds_map_exists(coop().npc_by_nid, _nid))
    {
        exit; // known (possibly deactivated by camera culling)
    }
    var _data = json_parse(_json);
    var _inst = instance_create_depth(_x, _y, -_y, _obj, { coop_replica: true, coop_nid: _nid, coop_replica_frame: -1 });
    with (_inst)
    {
        var _names = variable_struct_get_names(_data);
        for (var _i = 0; _i < array_length(_names); _i++)
        {
            variable_instance_set(id, _names[_i], variable_struct_get(_data, _names[_i]));
        }
        hp_set = true;
        coop_npc_list_forget(id); // the off-screen patrol simulation must not move replicas
        coop_tx = _x;
        coop_ty = _y;
        coop_flash = 0;
    }
    ds_map_set(coop().npc_by_nid, _nid, _inst);
}

function coop_npc_on_snap(_b)
{
    var _n = buffer_read(_b, buffer_u16);
    var _c = coop();
    for (var _i = 0; _i < _n; _i++)
    {
        var _nid = buffer_read(_b, buffer_u32);
        var _x = buffer_read(_b, buffer_f32);
        var _y = buffer_read(_b, buffer_f32);
        var _wpd = buffer_read(_b, buffer_f32);
        var _tfis = buffer_read(_b, buffer_f32);
        var _hp = buffer_read(_b, buffer_f32);
        var _sid = buffer_read(_b, buffer_u16);
        var _hsn = buffer_read(_b, buffer_s16);
        var _flags = buffer_read(_b, buffer_u8);
        var _inst = coop_npc_find(_nid);
        if (!instance_exists(_inst))
        {
            continue;
        }
        with (_inst)
        {
            coop_tx = _x;
            coop_ty = _y;
            weapon_pointing_direction = _wpd;
            target_for_image_scale = _tfis;
            hp = max(_hp, 1);
            if (_sid < array_length(_c.npc_state_names))
            {
                state = _c.npc_state_names[_sid];
            }
            if (_hsn >= 0)
            {
                human_state_now = _hsn;
            }
            damage_on_hit = (_flags & 1) != 0;
        }
    }
}

function coop_npc_on_statestr(_b)
{
    var _id = buffer_read(_b, buffer_u16);
    var _s = buffer_read(_b, buffer_string);
    var _c = coop();
    while (array_length(_c.npc_state_names) <= _id)
    {
        array_push(_c.npc_state_names, "");
    }
    _c.npc_state_names[_id] = _s;
}

function coop_npc_replica_step()
{
    var _d = point_distance(x, y, coop_tx, coop_ty);
    if (_d > 80)
    {
        x = coop_tx;
        y = coop_ty;
    }
    else
    {
        x = lerp(x, coop_tx, 0.3);
        y = lerp(y, coop_ty, 0.3);
    }
    depth = -y;
    if (variable_instance_exists(id, "emitter_shoot"))
    {
        audio_emitter_position(emitter_shoot, x, y, 0);
    }
    // Fog of war, same rule as the NPC's own Step.
    var _vis = player_line_of_sight(x, y);
    if (_vis != undefined)
    {
        var _gain = variable_instance_exists(id, "a_gain") ? a_gain : 0.1;
        image_alpha = _vis ? min(1, image_alpha + _gain) : max(0, image_alpha - _gain / 2);
    }
}

function coop_npc_on_die(_b)
{
    var _nid = buffer_read(_b, buffer_u32);
    var _x = buffer_read(_b, buffer_f32);
    var _y = buffer_read(_b, buffer_f32);
    var _inst = ds_map_find_value(coop().npc_by_nid, _nid);
    ds_map_delete(coop().npc_by_nid, _nid);
    if (_inst == undefined)
    {
        exit;
    }
    instance_activate_object(_inst);
    if (!instance_exists(_inst))
    {
        exit;
    }
    with (_inst)
    {
        x = _x;
        y = _y;
        hp = -100;
        var _snd = -1;
        switch (object_index)
        {
            case obj_enemy_wolf_brown: _snd = snd_wolf_death; break;
            case obj_enemy_boar: _snd = snd_boar_death; break;
            case obj_enemy_boar_zombie: _snd = snd_boar_death; break;
            case obj_enemy_ghoul: _snd = snd_ghoul_death; break;
            case obj_enemy_spider: _snd = snd_spider_death; break;
            case obj_enemy_big: _snd = snd_big_death; break;
        }
        if (_snd != -1)
        {
            var _em = instance_create_depth(x, y, 0, obj_emitter_death_sound);
            _em.sound_ = _snd;
        }
        instance_destroy();
    }
}

function coop_npc_on_gone(_b)
{
    var _nid = buffer_read(_b, buffer_u32);
    var _x = buffer_read(_b, buffer_f32);
    var _y = buffer_read(_b, buffer_f32);
    var _inst = ds_map_find_value(coop().npc_by_nid, _nid);
    ds_map_delete(coop().npc_by_nid, _nid);
    if (_inst != undefined)
    {
        instance_activate_object(_inst);
    }
    if (_inst != undefined && instance_exists(_inst))
    {
        with (_inst)
        {
            delete_npc = true;
            instance_destroy(id, false);
        }
    }
}

function coop_npc_on_hit(_b)
{
}

// obj_controller simulates off-screen patrols through global.list_n_id; drop an NPC from it.
function coop_npc_list_forget(_inst)
{
    if (!variable_global_exists("list_n_id"))
    {
        exit;
    }
    var _n = array_length(global.list_n_id);
    for (var _i = 0; _i < _n; _i++)
    {
        if (global.list_n_id[_i] == _inst)
        {
            global.list_n_id[_i] = -4;
            global.list_n_hp[_i] = -10;
        }
    }
}

// Called from game code: never let a co-op error escape into it.
function coop_npc_skip_step()
{
    try
    {
        return coop_npc_skip_step_inner();
    }
    catch (_e)
    {
        coop_report_error(_e);
    }
    return true;
}

// Called from game code: never let a co-op error escape into it.
function coop_npc_on_destroyed()
{
    try
    {
        coop_npc_on_destroyed_inner();
    }
    catch (_e)
    {
        coop_report_error(_e);
    }
}
