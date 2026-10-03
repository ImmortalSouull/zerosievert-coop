// ZERO Sievert co-op: grenade replication (players and NPCs).
// The thrower's machine sends the throw; the partner spawns the same grenade. Each machine applies the
// explosion to its own player only (the game already does that); NPC damage counts on the host.

#macro COOP_MSG_GRENADE 21

// Hook: end of obj_grenade_parent Create. Faction / thrown_by_player are set right after creation, so the
// throw is sent from the next obj_coop step.
function coop_grenade_on_create_inner()
{
    // Only real throws: map-placed mines (child objects, created by the generator on both sides) stay local.
    if (!variable_instance_exists(id, "coop_remote") && object_index == obj_grenade_parent && coop_raid_ready())
    {
        coop_grenade_pending = true;
    }
}

function coop_grenade_step()
{
    var _c = coop();
    if (!coop_shared_ready())
    {
        exit;
    }
    with (obj_grenade_parent)
    {
        if (!variable_instance_exists(id, "coop_grenade_pending") || !coop_grenade_pending)
        {
            continue;
        }
        coop_grenade_pending = false;
        // Guest only sends its own throws; NPC grenades come from the host.
        if (_c.role == "guest" && !thrown_by_player)
        {
            continue;
        }
        coop_msg_begin(COOP_MSG_GRENADE);
        buffer_write(_c.send_buf, buffer_s32, real(object_index));
        buffer_write(_c.send_buf, buffer_f32, xstart);
        buffer_write(_c.send_buf, buffer_f32, ystart);
        buffer_write(_c.send_buf, buffer_string, string(grenade_id));
        buffer_write(_c.send_buf, buffer_f32, throw_direction);
        buffer_write(_c.send_buf, buffer_f32, detonation_point);
        buffer_write(_c.send_buf, buffer_f32, throw_speed);
        buffer_write(_c.send_buf, buffer_string, string(faction));
        buffer_write(_c.send_buf, buffer_u8, thrown_by_player ? 1 : 0);
        coop_msg_send(true);
        coop_log("grenade sent ", grenade_id);
    }
}

function coop_grenade_on_message(_b)
{
    var _obj = buffer_read(_b, buffer_s32);
    var _x = buffer_read(_b, buffer_f32);
    var _y = buffer_read(_b, buffer_f32);
    var _gid = buffer_read(_b, buffer_string);
    var _dir = buffer_read(_b, buffer_f32);
    var _det = buffer_read(_b, buffer_f32);
    var _spd = buffer_read(_b, buffer_f32);
    var _fac = buffer_read(_b, buffer_string);
    var _by_player = buffer_read(_b, buffer_u8);
    if (!coop_in_raid() || !object_exists(_obj) || !item_exists(_gid))
    {
        exit;
    }
    var _g = instance_create_depth(_x, _y, 0, _obj,
    {
        grenade_id: _gid,
        throw_min: item_grenade_get_throw_min(_gid),
        throw_max: item_grenade_get_throw_max(_gid),
        fuse_time: item_grenade_get_fuse_time(_gid),
        throw_type: item_grenade_get_throw_type(_gid),
        damage_max: item_grenade_get_damage_max(_gid),
        damage_min: item_grenade_get_damage_min(_gid),
        detonation_type: item_grenade_get_detonation_type(_gid),
        detonation_duration: item_grenade_get_detonation_duration(_gid),
        radius_max_damage: item_grenade_get_radius_max_damage(_gid),
        radius_min_damage: item_grenade_get_radius_min_damage(_gid),
        throw_direction: _dir,
        throw_speed: _spd,
        detonation_point: _det,
        sprite_index: item_get_sprite_ingame(_gid),
        coop_remote: true,
        coop_remote_player: (_by_player == 1)
    });
    _g.faction = _fac;
    _g.thrown_by_player = false; // reputation / quest credit stays with the thrower
    coop_log("grenade received ", _gid);
}

// Used in the explosion: does a grenade affect the local player?
function coop_grenade_hurts_me(_g)
{
    if (variable_instance_exists(_g, "coop_remote_player") && _g.coop_remote_player)
    {
        return coop_setting("friendly_fire");
    }
    return true;
}

// Called from game code: never let a co-op error escape into it.
function coop_grenade_on_create()
{
    try
    {
        coop_grenade_on_create_inner();
    }
    catch (_e)
    {
        coop_report_error(_e);
    }
}
