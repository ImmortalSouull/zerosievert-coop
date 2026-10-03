// ZERO Sievert co-op: diagnostics for tests (map fingerprint, periodic status line).

function coop_diag_step()
{
    var _c = coop();
    if (!coop_in_raid() || !instance_exists(obj_player))
    {
        _c.diag_fp_done = false;
        exit;
    }
    if (!variable_struct_exists(_c, "diag_fp_done"))
    {
        _c.diag_fp_done = false;
    }
    if (!_c.diag_fp_done && obj_map_generator.state == 21)
    {
        _c.diag_fp_done = true;
        instance_activate_all();
        var _n = 0;
        var _h = 0;
        with (obj_solid)
        {
            _n++;
            _h = (_h + floor(x) * 31 + floor(y) * 17) mod 1000000007;
        }
        var _chests = instance_number(obj_chest_general);
        coop_log("map fingerprint: solids=", _n, " hash=", _h, " chests=", _chests, " player=", floor(obj_player.x), ",", floor(obj_player.y));
    }
    if (_c.frame mod 180 == 0)
    {
        var _p = coop_partner();
        var _replicas = 0;
        var _npcs = 0;
        with (obj_npc_parent)
        {
            _npcs++;
            if (variable_instance_exists(id, "coop_replica")) _replicas++;
        }
        coop_log("status: me=", floor(obj_player.x), ",", floor(obj_player.y),
            " partner=", instance_exists(_p) ? (string(floor(_p.x)) + "," + string(floor(_p.y))) : "none",
            " npcs(active)=", _npcs, " replicas=", _replicas, " known=", ds_map_size(_c.npc_by_nid),
            " sent=", _c.stats_sent, " recv=", _c.stats_recv, " ping=", _c.ping);
    }
}
