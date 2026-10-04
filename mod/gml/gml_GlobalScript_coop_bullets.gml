// ZERO Sievert co-op: bullet replication.
// Every bullet exists on both machines. Damage to a player is applied only by that player's own
// machine (the game already gates bullet_hit_player on the local index). Damage to NPCs is applied
// only on the host, where NPCs are real; on the guest NPCs are replicas and hits are cosmetic.

// Hook: end of bullet_spawn_add_data(bullet), i.e. every scr_shoot() bullet.
function coop_on_bullet_spawned_inner(_bull)
{
    var _c = coop();
    if (!coop_shared_ready())
    {
        exit;
    }
    if (!instance_exists(_bull) || variable_instance_exists(_bull, "coop_remote") || variable_instance_exists(_bull, "coop_sent"))
    {
        exit;
    }
    _bull.coop_sent = true;
    var _shooter = _bull.shooter_id;
    var _kind = -1;
    var _ref = 0;
    if (instance_exists(_shooter))
    {
        if (_shooter.object_index == obj_player)
        {
            _kind = 0;
        }
        else if (_c.role == "host" && object_is_ancestor(_shooter.object_index, obj_npc_parent))
        {
            _kind = 1;
            _ref = coop_npc_get_nid(_shooter);
        }
    }
    if (_kind < 0)
    {
        exit;
    }
    var _b = coop_msg_begin(COOP_MSG_BULLET);
    with (_bull)
    {
        buffer_write(_b, buffer_s32, real(object_index));
        buffer_write(_b, buffer_f32, x);
        buffer_write(_b, buffer_f32, y);
        buffer_write(_b, buffer_f32, direction);
        buffer_write(_b, buffer_f32, hspd);
        buffer_write(_b, buffer_f32, vspd);
        buffer_write(_b, buffer_f32, coop_var(id, "damage", 0));
        buffer_write(_b, buffer_f32, coop_var(id, "timer", 0));
        buffer_write(_b, buffer_f32, coop_var(id, "penetration", 0));
        buffer_write(_b, buffer_string, string(coop_var(id, "shooter_faction", "")));
        buffer_write(_b, buffer_string, string(coop_var(id, "weapon_used", "no_item")));
        buffer_write(_b, buffer_string, string(coop_var(id, "ammo_id_used", "no_item")));
        buffer_write(_b, buffer_f32, coop_var(id, "fin_x", x));
        buffer_write(_b, buffer_f32, coop_var(id, "fin_y", y));
        buffer_write(_b, buffer_u8, _kind);
        buffer_write(_b, buffer_u32, _ref);
        buffer_write(_b, buffer_string, variable_instance_exists(id, "npc_id") ? string(npc_id) : "");
        buffer_write(_b, buffer_string, variable_instance_exists(id, "shooter_npc_name") ? string(shooter_npc_name) : "");
        buffer_write(_b, buffer_u8, (variable_instance_exists(id, "scoped") && scoped) ? 1 : 0);
        buffer_write(_b, buffer_f32, variable_instance_exists(id, "skill_improvised_sniper_range_max_multiplier") ? skill_improvised_sniper_range_max_multiplier : 1);
        var _tk = 255; // homing target: the slot of the targeted player, 255 none
        if (variable_instance_exists(id, "target") && instance_exists(target))
        {
            if (target.object_index == obj_player) _tk = max(0, _c.slot);
            else if (target.object_index == obj_player_puppet && variable_instance_exists(target, "coop_slot")) _tk = target.coop_slot;
        }
        buffer_write(_b, buffer_u8, _tk);
    }
    coop_msg_send(true);
}

function coop_bullet_on_message(_b)
{
    var _obj = buffer_read(_b, buffer_s32);
    var _x = buffer_read(_b, buffer_f32);
    var _y = buffer_read(_b, buffer_f32);
    var _dir = buffer_read(_b, buffer_f32);
    var _hs = buffer_read(_b, buffer_f32);
    var _vs = buffer_read(_b, buffer_f32);
    var _dmg = buffer_read(_b, buffer_f32);
    var _timer = buffer_read(_b, buffer_f32);
    var _pen = buffer_read(_b, buffer_f32);
    var _fac = buffer_read(_b, buffer_string);
    var _weapon = buffer_read(_b, buffer_string);
    var _ammo = buffer_read(_b, buffer_string);
    var _fx = buffer_read(_b, buffer_f32);
    var _fy = buffer_read(_b, buffer_f32);
    var _kind = buffer_read(_b, buffer_u8);
    var _ref = buffer_read(_b, buffer_u32);
    var _npc_id = buffer_read(_b, buffer_string);
    var _npc_name = buffer_read(_b, buffer_string);
    var _scoped = buffer_read(_b, buffer_u8);
    var _sniper = buffer_read(_b, buffer_f32);
    var _tk = buffer_read(_b, buffer_u8);
    var _cc = coop();
    _cc.bullets_recv = (variable_struct_exists(_cc, "bullets_recv") ? _cc.bullets_recv : 0) + 1;
    if (!coop_in_raid() || !object_exists(_obj))
    {
        exit;
    }
    var _shooter = -4;
    if (_kind == 0)
    {
        _shooter = coop_puppet_of(_cc.msg_from);
    }
    else
    {
        _shooter = coop_npc_find(_ref);
    }
    if (_cc.test_mode && _kind == 0 && _cc.bullets_recv mod 6 == 1)
    {
        var _near = instance_nearest(_x + _hs * 15, _y + _vs * 15, obj_npc_parent);
        coop_log("bullet dbg: from ", floor(_x), ",", floor(_y), " dir ", floor(_dir), " shooter_ok=", instance_exists(_shooter),
            " nearest npc ", instance_exists(_near) ? (object_get_name(_near.object_index) + " at " + string(floor(_near.x)) + "," + string(floor(_near.y))) : "none");
    }
    var _bull = instance_create_depth(_x, _y, -_y, _obj);
    with (_bull)
    {
        coop_remote = true;
        direction = _dir;
        image_angle = _dir;
        hspd = _hs;
        vspd = _vs;
        damage = _dmg;
        timer = _timer;
        penetration = _pen;
        shooter_faction = _fac;
        shooter_id = instance_exists(_shooter) ? _shooter : -4;
        weapon_used = _weapon;
        ammo_id_used = _ammo;
        fin_x = _fx;
        fin_y = _fy;
        skill_improvised_sniper_range_max_multiplier = _sniper;
        if (_scoped)
        {
            scoped = true;
        }
        if (_kind == 1)
        {
            npc_id = _npc_id;
            shooter_npc_name = _npc_name;
        }
        if (_tk != 255)
        {
            var _tgt = coop_puppet_of(_tk);
            if (instance_exists(_tgt))
            {
                target = _tgt;
            }
        }
    }
    // Muzzle flash + gunshot at the remote shooter.
    if (item_exists(_weapon))
    {
        var _muzzle = instance_create_depth(_x, _y, -_y - 10, obj_muzzle_fire);
        _muzzle.image_angle = _dir;
    }
    if (instance_exists(_shooter) && item_exists(_weapon))
    {
        with (_shooter)
        {
            if (variable_instance_exists(id, "emitter_shoot"))
            {
                audio_emitter_position(emitter_shoot, x, y, 0);
                audio_play_sound_on(emitter_shoot, item_weapon_get_sound(_weapon), false, 10, 1, 0, random_range(0.95, 1.05));
            }
        }
    }
}

// Hook: top of bullet_hit_npc(bullet, npc). Returns true when the hit was handled (guest replicas).
function coop_bullet_hit_npc_inner(_bull, _npc)
{
    if (!coop_guest_in_raid())
    {
        return false;
    }
    // Guest: cosmetic only. The host computes the real damage from its copy of this bullet.
    with (_npc)
    {
        shader_hit = "BULLET_HIT_SHADER_NORMAL";
    }
    with (_bull)
    {
        if (object_is_player(shooter_id))
        {
            scr_sound_bullet_hit_flesh();
        }
        instance_destroy();
    }
    return true;
}

function coop_var(_inst, _name, _default)
{
    return variable_instance_exists(_inst, _name) ? variable_instance_get(_inst, _name) : _default;
}

// Mutant projectiles (ghoul spit, wraith fire, violet crystal) are created directly in the NPC Step, not via
// scr_shoot - pick them up here (host only; on the guest NPCs never shoot).
function coop_bullets_scan_step()
{
    var _c = coop();
    if (_c.role != "host" || !coop_shared_ready())
    {
        exit;
    }
    with (obj_bullet_parent)
    {
        if (!variable_instance_exists(id, "coop_sent") && !variable_instance_exists(id, "coop_remote"))
        {
            if (object_index == obj_bullet_ghoul || object_index == obj_bullet_wraith_fire || object_index == obj_bullet_crystal_violet)
            {
                coop_on_bullet_spawned(id);
            }
            else
            {
                coop_sent = true; // regular bullets were already handled in bullet_spawn_add_data
            }
        }
    }
}

// Called from game code: never let a co-op error escape into it.
function coop_on_bullet_spawned(_bull)
{
    try
    {
        coop_on_bullet_spawned_inner(_bull);
    }
    catch (_e)
    {
        coop_report_error(_e);
    }
}

// Called from game code: never let a co-op error escape into it.
function coop_bullet_hit_npc(_bull, _npc)
{
    try
    {
        return coop_bullet_hit_npc_inner(_bull, _npc);
    }
    catch (_e)
    {
        coop_report_error(_e);
    }
    return false;
}
