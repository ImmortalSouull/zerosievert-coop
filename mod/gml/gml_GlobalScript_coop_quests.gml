// ZERO Sievert co-op: shared quest progress (2.0.0 item 8).
// A kill that counts for a quest (kill_check_quest, hook [145]) is told to the teammates in the same raid; each of
// them who has a quest with a matching kill objective gets the progress too. Every machine counts the work per
// quest: its own increments and the teammates'. When a quest is turned in (hook [146]), money, experience and the
// reward item's amount are multiplied by our share of the work (equal work of two players: half each), so playing
// together never multiplies the rewards. coop_quest_work.json in the save folder keeps the counts between raids.

#macro COOP_MSG_QKILL 84

function coop_qwork()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "qwork") || _c.qwork_root != global.database_savedata_root)
    {
        _c.qwork_root = global.database_savedata_root;
        _c.qwork = {};
        var _f = global.database_savedata_root + "coop_quest_work.json";
        if (file_exists(_f))
        {
            try
            {
                var _b = buffer_load(_f);
                _c.qwork = json_parse(buffer_read(_b, buffer_text));
                buffer_delete(_b);
            }
            catch (_e)
            {
                _c.qwork = {};
            }
        }
    }
    return _c.qwork;
}

function coop_qwork_save()
{
    var _t = json_stringify(coop_qwork());
    var _b = buffer_create(string_byte_length(_t) + 1, buffer_fixed, 1);
    buffer_write(_b, buffer_text, _t);
    buffer_save(_b, global.database_savedata_root + "coop_quest_work.json");
    buffer_delete(_b);
}

function coop_qwork_add(_quest, _mine)
{
    var _w = coop_qwork();
    if (!variable_struct_exists(_w, _quest)) variable_struct_set(_w, _quest, { me: 0, others: 0 });
    var _e = variable_struct_get(_w, _quest);
    if (_mine) _e.me++; else _e.others++;
    coop_qwork_save();
}

// Our share of a quest's work (1 when nobody else helped).
function coop_quest_share(_quest)
{
    var _w = coop_qwork();
    if (!variable_struct_exists(_w, _quest)) return 1;
    var _e = variable_struct_get(_w, _quest);
    var _all = _e.me + _e.others;
    return (_all <= 0 || _e.others <= 0) ? 1 : _e.me / _all;
}

// Apply a kill to our own quests: returns how many objectives moved. (_mine: our own kill)
function coop_quest_apply_kill(_npc_id, _mine)
{
    var _moved = 0;
    for (var i = 0; i < 30; i++)
    {
        var _q = global.quest_state[i].id;
        if (_q == "") continue;
        var _data = variable_struct_get(global.quest_database, _q);
        for (var j = 0; j < array_length(_data.objective); j++)
        {
            var _o = _data.objective[j];
            if (_o.type != "kill" || !(_o.map == -1 || _o.map == obj_map_generator.area)) continue;
            if (!array_contains(_o.array_kill, _npc_id)) continue;
            if (global.quest_state[i].amount_now[j] >= _o.amount_max) continue; // done already: no work
            if (!_mine)
            {
                global.quest_state[i].amount_now[j] += 1; // (our own kill: the game adds it right after)
            }
            coop_qwork_add(_q, _mine);
            _moved++;
        }
    }
    return _moved;
}

// Hook [145]: start of kill_check_quest's quest loop (our own kill, the game moves our objectives itself).
function coop_quest_on_kill(_npc_id)
{
    try
    {
        var _c = coop();
        if (!_c.connected || !coop_in_raid())
        {
            return;
        }
        coop_quest_apply_kill(_npc_id, true);
        var _b = coop_msg_begin(COOP_MSG_QKILL);
        buffer_write(_b, buffer_string, string(_npc_id));
        coop_msg_send(true);
    }
    catch (_e)
    {
        coop_report_error(_e);
    }
}

function coop_quest_on_msg(_b)
{
    var _c = coop();
    var _npc = buffer_read(_b, buffer_string);
    if (!coop_in_raid() || !instance_exists(obj_map_generator))
    {
        exit;
    }
    // only a teammate in our raid
    var _p = coop_peer(_c.msg_from);
    if (!is_struct(_p) || !_p.in_raid || _p.raid_seed != coop_raid_seed_mine())
    {
        exit;
    }
    var _n = coop_quest_apply_kill(_npc, false);
    if (_n > 0)
    {
        coop_log("quest: ", coop_peer_name(_c.msg_from), "'s kill of ", _npc, " counted for ", _n, " objective(s)");
        coop_notify(coop_tf("{0}'s kill counts for your task", "Убийство {0} засчитано в ваше задание", coop_peer_name(_c.msg_from)));
    }
}

// Hook [146]: the turn-in's money / experience / item amount, times our share of the work.
function coop_quest_reward(_quest, _value)
{
    try
    {
        var _s = coop_quest_share(_quest);
        if (_s < 1)
        {
            coop_log("quest: ", _quest, " reward share ", _s);
        }
        return round(_value * _s);
    }
    catch (_e)
    {
        coop_report_error(_e);
    }
    return _value;
}

// After the turn-in the counts of that quest are done with.
function coop_quest_turned_in(_quest)
{
    var _w = coop_qwork();
    if (variable_struct_exists(_w, _quest))
    {
        variable_struct_remove(_w, _quest);
        coop_qwork_save();
    }
}
