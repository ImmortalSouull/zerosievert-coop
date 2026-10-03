// ZERO Sievert co-op: kill credit / reputation for the guest.
// NPC damage is computed on the host, where the guest's bullets belong to the puppet - so the game itself
// credits nobody. The host reports hits and kills by the partner; the guest applies the same rewards the game
// gives the local player (faction reputation, quest progress + kill XP via kill_check_quest, stats).

#macro COOP_MSG_CREDIT 64

// Hook: bullet_hit_npc, inside with(bullet), right after the local-player credit block.
function coop_partner_hit_credit_inner(_bull, _npc)
{
    var _c = coop();
    if (_c.role != "host" || !coop_shared_ready() || !instance_exists(_npc))
    {
        exit;
    }
    var _p = coop_partner();
    if (_c.test_mode)
    {
        coop_log("hit dbg: npc=", object_get_name(_npc.object_index), " hp=", _npc.hp, " shooter=", _bull.shooter_id, " partner=", instance_exists(_p) ? _p.id : -4);
    }
    if (!instance_exists(_p) || _bull.shooter_id != _p.id)
    {
        exit;
    }
    var _first = false;
    var _killed = false;
    with (_npc)
    {
        if (!variable_instance_exists(id, "coop_partner_first_shot"))
        {
            coop_partner_first_shot = true;
            _first = true;
        }
        if (hp <= 0 && !variable_instance_exists(id, "coop_partner_killed"))
        {
            coop_partner_killed = true;
            _killed = true;
        }
    }
    if (_killed)
    {
        coop_log("partner killed ", _npc.npc_id, " - credit sent");
    }
    coop_msg_begin(COOP_MSG_CREDIT);
    buffer_write(_c.send_buf, buffer_string, string(_npc.npc_id));
    buffer_write(_c.send_buf, buffer_string, object_get_name(_npc.object_index));
    buffer_write(_c.send_buf, buffer_u8, _first);
    buffer_write(_c.send_buf, buffer_u8, _killed);
    coop_msg_send(true);
}

function coop_credit_on_message(_b)
{
    var _npc_id = buffer_read(_b, buffer_string);
    var _obj_name = buffer_read(_b, buffer_string);
    var _first = buffer_read(_b, buffer_u8);
    var _killed = buffer_read(_b, buffer_u8);
    if (!coop_in_raid())
    {
        exit;
    }
    var _faction = npc_get_faction(_npc_id);
    if (_faction != "All Friend" && variable_struct_exists(global.struct_faction, _faction))
    {
        faction_set_rep_temp(_faction, "Player", 0);
        var _amount = variable_struct_get(global.struct_faction, _faction).rep_hit;
        if (_first)
        {
            faction_add_rep(_faction, "Player", _amount);
        }
        if (_killed)
        {
            faction_add_rep(_faction, "Player", _amount);
        }
    }
    if (_killed)
    {
        kill_check_quest(_npc_id);
        var _obj = asset_get_index(_obj_name);
        if (_obj != -1)
        {
            kill_add_stat(_obj);
        }
        coop_log("kill credited: ", _npc_id);
    }
}

// Called from game code: never let a co-op error escape into it.
function coop_partner_hit_credit(_bull, _npc)
{
    try
    {
        coop_partner_hit_credit_inner(_bull, _npc);
    }
    catch (_e)
    {
        coop_report_error(_e);
    }
}
