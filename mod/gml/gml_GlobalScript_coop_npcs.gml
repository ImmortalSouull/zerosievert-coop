// ZERO Sievert co-op: NPCs simulated once (on the raid owner) and replicated to everyone else.
// Owner: real NPCs; each gets a network id (nid) and is streamed: a spawn (object, position, key variables as
// JSON), then batched snapshots (position, aim, facing, HP, state, human state) - every 4 ticks near another
// player, every 30 ticks elsewhere. State strings are sent once and then referred to by a short id.
// Replicas: every NPC a replica machine generated itself is removed; replicas are spawned from the owner's data
// and run no AI (their Step and movement alarms exit, see hooks.txt). End Step still runs, so walk/idle
// animation, facing and footsteps come for free from the replicated position and state.
// Ownership moves (the owner extracted): the new owner turns its replicas into real NPCs with the same ids;
// the 1.4 behaviour-tree AI then prepares itself on the first Step (ai_human_before_step, "resumed_after_gap").
// Also here: callout bubbles (1.4 AI barks), the 30 s consistency check (missing / extra replicas).

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
    if (!coop_is_world_owner())
    {
        exit;
    }
    // NPCs near any other player are streamed often, the rest a few times per second
    var _pts = [];
    with (obj_player_puppet)
    {
        array_push(_pts, x, y);
    }
    if (array_length(_pts) == 0 && instance_exists(obj_player))
    {
        array_push(_pts, obj_player.x, obj_player.y);
    }
    var _npts = array_length(_pts);
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
            // (an NPC that got its id as a replica and became ours when the owner left has no flag yet: a spawn
            // the others already know is ignored by them)
            if (!variable_instance_exists(id, "coop_spawn_sent") || !coop_spawn_sent)
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
        var _near = false;
        for (var _k = 0; _k < _npts; _k += 2)
        {
            if (point_distance(x, y, _pts[_k], _pts[_k + 1]) < 720)
            {
                _near = true;
                break;
            }
        }
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
    // Pass 3 (far tick): NPCs deactivated on this machine (outside the culling regions) still walk and fight
    // off screen (1.4 roaming moves deactivated instances). Without their positions the replicas stayed where the
    // NPC was last seen: a "ghost" the others could shoot at while the real one stood somewhere else.
    if (_far_tick)
    {
        var _map = _c.npc_by_nid;
        var _k = ds_map_find_first(_map);
        while (_k != undefined)
        {
            var _inst = ds_map_find_value(_map, _k);
            _k = ds_map_find_next(_map, _k);
            if (instance_exists(_inst))
            {
                continue;
            }
            var _row = undefined;
            try
            {
                if (_inst.hp > 0)
                {
                    var _hsn = variable_instance_exists(_inst, "human_state_now") ? _inst.human_state_now : -1;
                    var _flags = (variable_instance_exists(_inst, "damage_on_hit") && _inst.damage_on_hit) ? 1 : 0;
                    _row = [_inst.coop_nid, _inst.x, _inst.y, _inst.weapon_pointing_direction, _inst.target_for_image_scale,
                        _inst.hp, coop_npc_state_id(_inst.state), _hsn, _flags];
                }
            }
            catch (_e)
            {
                _row = undefined; // destroyed, not deactivated
            }
            if (_row == undefined)
            {
                continue;
            }
            if (_count == 0)
            {
                coop_msg_begin(COOP_MSG_NPC_SNAP);
                _count_pos = buffer_tell(_b);
                buffer_write(_b, buffer_u16, 0);
            }
            buffer_write(_b, buffer_u32, _row[0]);
            buffer_write(_b, buffer_f32, _row[1]);
            buffer_write(_b, buffer_f32, _row[2]);
            buffer_write(_b, buffer_f32, _row[3]);
            buffer_write(_b, buffer_f32, _row[4]);
            buffer_write(_b, buffer_f32, _row[5]);
            buffer_write(_b, buffer_u16, _row[6]);
            buffer_write(_b, buffer_s16, _row[7]);
            buffer_write(_b, buffer_u8, _row[8]);
            _count++;
            if (_count >= 36)
            {
                buffer_poke(_b, _count_pos, buffer_u16, _count);
                coop_msg_send(false);
                _count = 0;
            }
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
    if (!coop_is_world_owner() || !variable_instance_exists(id, "coop_nid"))
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
    instance_activate_object(obj_npc_parent);
    with (obj_npc_parent)
    {
        if (coop_npc_is_replica())
        {
            coop_replica = false; // AI takes over again, purge leaves it alone (variable still exists)
            // a state the replica never learned the name of would crash the NPC's state machine
            if ((is_string(state) && state == "") || is_undefined(state))
            {
                state = variable_instance_exists(id, "coop_init_state") ? coop_init_state : state;
            }
        }
    }
}

// Guest: the host is back (reconnected to the same raid): NPCs that ran on our AI meanwhile follow the host
// again (known ids get its snapshots; ones the host no longer has are removed by NPC_GONE/purge).
function coop_npc_guest_readopt()
{
    var _n = 0;
    instance_activate_object(obj_npc_parent);
    with (obj_npc_parent)
    {
        if (variable_instance_exists(id, "coop_replica") && !coop_replica && variable_instance_exists(id, "coop_nid"))
        {
            coop_replica = true;
            coop_tx = x;
            coop_ty = y;
            _n++;
        }
    }
    if (_n > 0)
    {
        coop_log("re-adopted ", _n, " NPCs after reconnecting");
    }
}

// We became the raid owner: replicas run on our AI now and keep their ids, so the others' replicas follow us.
function coop_npc_take_over()
{
    var _c = coop();
    var _max = 0;
    var _n = 0;
    instance_activate_object(obj_npc_parent);
    with (obj_npc_parent)
    {
        if (variable_instance_exists(id, "coop_nid"))
        {
            _max = max(_max, coop_nid);
            coop_spawn_sent = true; // the others already know it
            if (variable_instance_exists(id, "coop_replica") && coop_replica)
            {
                coop_replica = false;
                if ((is_string(state) && state == "") || is_undefined(state))
                {
                    state = variable_instance_exists(id, "coop_init_state") ? coop_init_state : state;
                }
                _n++;
            }
        }
    }
    _c.npc_next_nid = max(_c.npc_next_nid, _max + 1);
    coop_log("took over ", _n, " NPCs, next id ", _c.npc_next_nid);
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
        coop_init_state = state; // the AI's own starting state, used if the host leaves
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
        var _inst = ds_map_find_value(_c.npc_by_nid, _nid);
        if (_inst == undefined)
        {
            continue;
        }
        if (!instance_exists(_inst))
        {
            // deactivated here (off our screen): move it anyway, so our culling and the next activation see
            // the NPC where the owner has it
            try
            {
                _inst.x = _x;
                _inst.y = _y;
                _inst.coop_tx = _x;
                _inst.coop_ty = _y;
                _inst.hp = max(_hp, 1);
            }
            catch (_e) { }
            continue;
        }
        with (_inst)
        {
            coop_tx = _x;
            coop_ty = _y;
            weapon_pointing_direction = _wpd;
            target_for_image_scale = _tfis;
            hp = max(_hp, 1);
            if (_sid < array_length(_c.npc_state_names) && _c.npc_state_names[_sid] != "")
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
        if (coop().test_mode && hp <= 0)
        {
            coop().kills_seen = (variable_struct_exists(coop(), "kills_seen") ? coop().kills_seen : 0) + 1;
        }
        coop_npc_on_destroyed_inner();
    }
    catch (_e)
    {
        coop_report_error(_e);
    }
}

// ---- callouts ("Contact!", "Reloading!", "Grenade!"): text bubbles over enemies ----
// WORKAROUND (no source access): the 1.4 AI shows its callouts as obj_npc_draw_text bubbles created inside the
// AI, which only runs on the raid owner, so nobody else saw them. The natural hook point (ai_compat) can't be
// patched: its decompiled code uses a field named `until`, a reserved word for UTMT's compiler. So the owner
// scans for new callout bubbles every tick and sends them; receivers create the same bubble on their replica.
// Behaviour-tree barks carry the language key (npc.ai_bark_last_line), so every player reads it in their own
// language; legacy callouts carry the game's text id.

#macro COOP_MSG_NPC_BARK 38
#macro COOP_BARK_LEGACY_TEXTS [6, 8, 12, 16, 17]

// Owner, every tick in a shared raid.
function coop_npc_bark_scan()
{
    if (!coop_shared_ready() || !coop_is_world_owner())
    {
        exit;
    }
    var _legacy = COOP_BARK_LEGACY_TEXTS;
    with (obj_npc_draw_text)
    {
        if (variable_instance_exists(id, "coop_bark_sent") || !variable_instance_exists(id, "id_npc") || !instance_exists(id_npc) || !variable_instance_exists(id_npc, "coop_nid"))
        {
            continue;
        }
        var _kind = variable_instance_exists(id, "bark_kind") ? bark_kind : "";
        var _text = -1;
        var _line = "";
        if (_kind != "")
        {
            _line = variable_instance_exists(id_npc, "ai_bark_last_line") ? string(id_npc.ai_bark_last_line) : "";
            if (_line == "") continue; // set by the game right after the bubble: try again next tick
        }
        else if (array_contains(_legacy, text_id))
        {
            _text = text_id;
        }
        coop_bark_sent = true;
        if (_kind == "" && _text < 0) continue; // dialogue, not a callout
        var _b = coop_msg_begin(COOP_MSG_NPC_BARK);
        buffer_write(_b, buffer_u32, id_npc.coop_nid);
        buffer_write(_b, buffer_s16, _text);
        buffer_write(_b, buffer_string, _kind);
        buffer_write(_b, buffer_string, _line);
        buffer_write(_b, buffer_string, variable_instance_exists(id_npc, "faction") ? string(id_npc.faction) : "");
        coop_msg_send(true);
    }
}

function coop_npc_on_bark(_b)
{
    var _nid = buffer_read(_b, buffer_u32);
    var _text = buffer_read(_b, buffer_s16);
    var _kind = buffer_read(_b, buffer_string);
    var _line = buffer_read(_b, buffer_string);
    var _faction = buffer_read(_b, buffer_string);
    if (!coop_is_world_replica())
    {
        exit;
    }
    var _npc = coop_npc_find(_nid);
    if (!instance_exists(_npc) || _npc.hp <= 0)
    {
        exit;
    }
    if (_text >= 0)
    {
        scr_draw_npc_text(_npc, _text);
    }
    else
    {
        // same steps as the game's __ai_compat_show_bark
        scr_draw_npc_text(_npc, 6);
        var _shout = ai_barks_is_heard_through_walls(_faction, _kind);
        var _radius = ai_barks_speaking_rule(_faction, "hearing_radius_px");
        var _alpha = ai_barks_speaking_rule(_faction, "unseen_alpha");
        with (obj_npc_draw_text)
        {
            if (!variable_instance_exists(id, "id_npc") || id_npc != _npc) continue;
            alarm[1] = -1;
            t = language_get_string(_line);
            bark_kind = _kind;
            x = _npc.x;
            y = _npc.y;
            bark_heard_through_walls = _shout;
            bark_hearing_radius_px = _radius;
            bark_unseen_alpha = _alpha;
        }
    }
    if (coop().test_mode)
    {
        coop().barks_in = (variable_struct_exists(coop(), "barks_in") ? coop().barks_in : 0) + 1;
        coop_log("npc bark from owner: ", _kind, " ", _line, " ", _text);
    }
}

// ---- consistency check (every 30 s): the owner's list of live NPC ids vs every replica's ----

#macro COOP_MSG_NPC_CHECK 36
#macro COOP_MSG_NPC_MISSING 37

function coop_npc_check_step()
{
    var _c = coop();
    if (!coop_is_world_owner() || _c.frame mod (_c.test_mode ? 600 : 1800) != 300)
    {
        exit;
    }
    var _map = _c.npc_by_nid;
    var _n = ds_map_size(_map);
    var _b = coop_msg_begin(COOP_MSG_NPC_CHECK);
    buffer_write(_b, buffer_u16, _n);
    var _k = ds_map_find_first(_map);
    while (_k != undefined)
    {
        // nid + where the owner has it (also deactivated NPCs): the replica measures its drift
        var _px = -1;
        var _py = -1;
        var _inst = ds_map_find_value(_map, _k);
        try
        {
            _px = _inst.x;
            _py = _inst.y;
        }
        catch (_e) { }
        buffer_write(_b, buffer_u32, _k);
        buffer_write(_b, buffer_f32, _px);
        buffer_write(_b, buffer_f32, _py);
        _k = ds_map_find_next(_map, _k);
    }
    coop_msg_send(true);
}

function coop_npc_on_check(_b)
{
    var _c = coop();
    var _n = buffer_read(_b, buffer_u16);
    if (!coop_is_world_replica() || _c.msg_from != coop_raid_owner())
    {
        exit;
    }
    var _owner = ds_map_create();
    var _map = _c.npc_by_nid;
    var _drift_max = 0;
    var _drift_n = 0;
    var _drift_now = {}; // nids far off in this check; a ghost stays off in the next one too (a running NPC does not)
    var _drift_prev = variable_struct_exists(_c, "drift_prev") ? _c.drift_prev : {};
    var _drift_brief = 0;
    for (var _i = 0; _i < _n; _i++)
    {
        var _nid = buffer_read(_b, buffer_u32);
        var _ox = buffer_read(_b, buffer_f32);
        var _oy = buffer_read(_b, buffer_f32);
        ds_map_set(_owner, _nid, true);
        var _rep = ds_map_find_value(_map, _nid);
        if (_rep != undefined && _ox >= 0)
        {
            try
            {
                var _d = point_distance(_rep.x, _rep.y, _ox, _oy);
                _drift_max = max(_drift_max, _d);
                if (_d > 160)
                {
                    variable_struct_set(_drift_now, string(_nid), true);
                    if (variable_struct_exists(_drift_prev, string(_nid))) _drift_n++; else _drift_brief++;
                }
            }
            catch (_e) { }
        }
    }
    // a replica far from the owner's NPC is a ghost (shots at it hit nothing on the owner)
    if (_drift_n > 0)
    {
        coop_log("NPC DRIFT: ", _drift_n, " replicas > 160 px from the owner's NPC, max ", floor(_drift_max));
    }
    else if (_c.test_mode)
    {
        coop_log("npc drift ok: max ", floor(_drift_max), (_drift_brief > 0) ? " (" + string(_drift_brief) + " off for one check)" : "");
    }
    _c.drift_prev = _drift_now;
    // extras: replicas the owner no longer has (a missed NPC_DIE/GONE)
    var _extra = 0;
    var _k = ds_map_find_first(_map);
    var _drop = [];
    while (_k != undefined)
    {
        if (!ds_map_exists(_owner, _k))
        {
            array_push(_drop, _k);
        }
        _k = ds_map_find_next(_map, _k);
    }
    for (var _i = 0; _i < array_length(_drop); _i++)
    {
        var _inst = ds_map_find_value(_map, _drop[_i]);
        ds_map_delete(_map, _drop[_i]);
        instance_activate_object(_inst);
        if (instance_exists(_inst))
        {
            instance_destroy(_inst, false);
        }
        _extra++;
    }
    // missing: NPCs the owner has and we never got (ask for them)
    var _missing = [];
    _k = ds_map_find_first(_owner);
    while (_k != undefined)
    {
        if (!ds_map_exists(_map, _k))
        {
            array_push(_missing, _k);
        }
        _k = ds_map_find_next(_owner, _k);
    }
    ds_map_destroy(_owner);
    if (_extra == 0 && array_length(_missing) == 0)
    {
        if (_c.test_mode)
        {
            coop_log("npc check ok: ", _n);
        }
        exit;
    }
    coop_log("NPC DESYNC fixed: owner ", _n, ", removed ", _extra, ", missing ", array_length(_missing));
    if (array_length(_missing) > 0)
    {
        var _mb = coop_msg_begin(COOP_MSG_NPC_MISSING);
        buffer_write(_mb, buffer_u16, array_length(_missing));
        for (var _i = 0; _i < array_length(_missing); _i++)
        {
            buffer_write(_mb, buffer_u32, _missing[_i]);
        }
        coop_msg_send_to(coop_raid_owner(), true);
    }
}

// Owner: a replica asks for NPCs it never got.
function coop_npc_on_missing(_b)
{
    var _c = coop();
    var _n = buffer_read(_b, buffer_u16);
    if (!coop_is_world_owner())
    {
        exit;
    }
    _c.msg_dest = _c.msg_from;
    for (var _i = 0; _i < _n; _i++)
    {
        var _inst = ds_map_find_value(_c.npc_by_nid, buffer_read(_b, buffer_u32));
        if (_inst != undefined)
        {
            instance_activate_object(_inst);
            if (instance_exists(_inst))
            {
                coop_npc_send_spawn(_inst);
            }
        }
    }
    _c.msg_dest = COOP_ALL;
}
