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
        if (_c.connected)
        {
            coop_send_raid_state();
        }
        instance_activate_all();
        _c.my_fp = coop_diag_fingerprint();
        coop_log("map fingerprint: ", json_stringify(_c.my_fp), " player=", floor(obj_player.x), ",", floor(obj_player.y));
        if (_c.connected)
        {
            coop_msg_begin(COOP_MSG_FP);
            buffer_write(_c.send_buf, buffer_string, json_stringify(_c.my_fp));
            buffer_write(_c.send_buf, buffer_f64, (_c.gen_seed == undefined) ? -1 : _c.gen_seed);
            coop_msg_send(true);
        }
        coop_diag_compare();
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
            " players=", coop_player_count(), " sent=", _c.stats_sent, " recv=", _c.stats_recv, " ping=", _c.ping, " bullets_in=", variable_struct_exists(_c, "bullets_recv") ? _c.bullets_recv : 0);
    }
}

function coop_diag_hash(_obj)
{
    var _n = 0;
    var _h = 0;
    with (_obj)
    {
        _n++;
        _h = (_h + floor(x) * 31 + floor(y) * 17 + real(object_index) * 7) mod 1000000007;
    }
    return [_n, _h];
}

function coop_diag_fingerprint()
{
    var _s = coop_diag_hash(obj_solid);
    var _d = coop_diag_hash(obj_decor_parent);
    // generated containers only: corpses, air drops and dropped bags appear at different moments
    var _n = 0;
    var _h = 0;
    with (obj_chest_general)
    {
        if (!variable_instance_exists(id, "coop_dynamic") && !variable_instance_exists(id, "coop_net_spawned"))
        {
            _n++;
            _h = (_h + floor(x) * 31 + floor(y) * 17 + real(object_index) * 7) mod 1000000007;
        }
    }
    var _ch = [_n, _h];
    var _af = coop_diag_hash(obj_anomaly_emitter_parent);
    return { solids: _s, decor: _d, chests: _ch, anomalies: _af };
}

function coop_diag_on_fp(_b)
{
    var _json = buffer_read(_b, buffer_string);
    var _seed = buffer_read(_b, buffer_f64);
    var _c = coop();
    if (_c.gen_seed == undefined || _seed != _c.gen_seed)
    {
        exit; // different raid
    }
    var _p = coop_peer(_c.msg_from);
    if (!is_struct(_p))
    {
        exit;
    }
    _p.fp = json_parse(_json);
    if (_c.role == "host" && variable_struct_exists(_c, "my_fp") && _c.my_fp != undefined)
    {
        // a late joiner never got ours: answer so both sides can compare
        coop_msg_begin(COOP_MSG_FP);
        buffer_write(_c.send_buf, buffer_string, json_stringify(_c.my_fp));
        buffer_write(_c.send_buf, buffer_f64, _c.gen_seed);
        coop_msg_send_to(_c.msg_from, true);
    }
    coop_diag_compare();
}

// Compare our map fingerprint with every fingerprint received so far (each one once).
function coop_diag_compare()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "my_fp") || _c.my_fp == undefined)
    {
        exit;
    }
    var _ps = coop_peers();
    for (var _s = 0; _s < COOP_MAX_PLAYERS; _s++)
    {
        var _p = _ps[_s];
        if (!is_struct(_p) || _p.fp == undefined)
        {
            continue;
        }
        var _bad = "";
        var _keys = ["solids", "decor", "chests", "anomalies"];
        for (var _i = 0; _i < 4; _i++)
        {
            var _a = variable_struct_get(_c.my_fp, _keys[_i]);
            var _o = variable_struct_get(_p.fp, _keys[_i]);
            if (_a[0] != _o[0] || _a[1] != _o[1])
            {
                _bad += _keys[_i] + " " + string(_a[0]) + "/" + string(_o[0]) + " ";
            }
        }
        if (_bad == "")
        {
            coop_log("maps identical with partner ", _p.name, " (slot ", _s, ")");
        }
        else
        {
            coop_log("MAP MISMATCH with partner ", _p.name, " (slot ", _s, "): ", _bad);
            coop_notify(coop_t("Warning: your map differs from " + _p.name + "'s (send the coop log)", "Внимание: карта отличается от карты " + _p.name + " (пришлите coop-лог)"));
        }
        _p.fp = undefined;
    }
}
