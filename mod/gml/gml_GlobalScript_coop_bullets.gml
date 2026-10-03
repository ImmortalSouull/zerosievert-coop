// ZERO Sievert co-op: bullet replication.
// Every bullet exists on both machines. Damage to a player is applied only by that player's own
// machine (the game already gates bullet_hit_player on the local index). Damage to NPCs is applied
// only on the host, where NPCs are real; on the guest NPCs are replicas and hits are cosmetic.

// Hook: end of bullet_spawn_add_data(bullet), i.e. every scr_shoot() bullet.
function coop_on_bullet_spawned(_bull)
{
    var _c = coop();
    if (!coop_shared_ready())
    {
        exit;
    }
    if (!instance_exists(_bull) || variable_instance_exists(_bull, "coop_remote"))
    {
        exit;
    }
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
        buffer_write(_b, buffer_f32, damage);
        buffer_write(_b, buffer_f32, timer);
        buffer_write(_b, buffer_f32, penetration);
        buffer_write(_b, buffer_string, string(shooter_faction));
        buffer_write(_b, buffer_string, string(weapon_used));
        buffer_write(_b, buffer_string, string(ammo_id_used));
        buffer_write(_b, buffer_f32, fin_x);
        buffer_write(_b, buffer_f32, fin_y);
        buffer_write(_b, buffer_u8, _kind);
        buffer_write(_b, buffer_u32, _ref);
        buffer_write(_b, buffer_string, variable_instance_exists(id, "npc_id") ? string(npc_id) : "");
        buffer_write(_b, buffer_string, variable_instance_exists(id, "shooter_npc_name") ? string(shooter_npc_name) : "");
        buffer_write(_b, buffer_u8, (variable_instance_exists(id, "scoped") && scoped) ? 1 : 0);
        buffer_write(_b, buffer_f32, variable_instance_exists(id, "skill_improvised_sniper_range_max_multiplier") ? skill_improvised_sniper_range_max_multiplier : 1);
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
    var _cc = coop();
    _cc.bullets_recv = (variable_struct_exists(_cc, "bullets_recv") ? _cc.bullets_recv : 0) + 1;
    if (!coop_in_raid() || !object_exists(_obj))
    {
        exit;
    }
    var _shooter = -4;
    if (_kind == 0)
    {
        _shooter = coop_partner();
    }
    else
    {
        _shooter = coop_npc_find(_ref);
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
    }
    // Muzzle flash + gunshot at the remote shooter.
    var _muzzle = instance_create_depth(_x, _y, -_y - 10, obj_muzzle_fire);
    _muzzle.image_angle = _dir;
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
function coop_bullet_hit_npc(_bull, _npc)
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
