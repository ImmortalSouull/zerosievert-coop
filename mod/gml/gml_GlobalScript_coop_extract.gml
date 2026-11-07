// ZERO Sievert co-op: group extraction (2.0.0 item 21) and the raid summary (item 24).
//
// Extraction (hook [139] in obj_extraction_point Step, every tick a player stands in the zone): every player in a
// zone tells the others (EXTRACT: in zone, timer, the point). While a living teammate in the raid is not in that
// zone, the local timer runs to 10 s instead of 5 ("Extraction in 7 s - waiting for X"): leaving alone still works,
// it just gives the others time. When every living raid player is in the same zone the timers follow the highest
// one, so the group leaves together.
//
// Summary: each player counts its own raid (kills and damage - the raid owner reports them for remote shooters
// through the credit message, revives, downs) and at the end of its raid (the extraction / death screen) sends them
// with the value it made. The extraction screen shows everybody of that raid; players still in it show as such.

#macro COOP_MSG_EXTRACT 74
#macro COOP_MSG_SUMMARY 73
#macro COOP_EXTRACT_SOLO_TICKS 300
#macro COOP_EXTRACT_WAIT_TICKS 600

// ---- extraction ----

function coop_extract()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "extract"))
    {
        _c.extract = { mine: { in_zone: false, timer: 0, px: 0, py: 0 }, sent_t: 0, others: array_create(COOP_MAX_PLAYERS, undefined), waiting: [], group_max: 0, sent_sig: "" };
    }
    return _c.extract;
}

// Hook [139]: inside obj_extraction_point Step (self = the point), right after timer_exit++ / the reset.
function coop_extract_tick(_point, _in_zone)
{
    try
    {
        coop_extract_tick_inner(_point, _in_zone);
    }
    catch (_e)
    {
        coop_report_error(_e);
    }
}

function coop_extract_tick_inner(_point, _in_zone)
{
    var _c = coop();
    var _x = coop_extract();
    var _m = _x.mine;
    if (!_c.connected || !coop_in_raid())
    {
        _point.timer_exit_max = COOP_EXTRACT_SOLO_TICKS;
        exit;
    }
    // several points: only the one we stand at (or the one we last reported) speaks for us
    if (!_in_zone && (!_m.in_zone || _m.px != _point.x || _m.py != _point.y))
    {
        exit;
    }
    _m.in_zone = _in_zone;
    _m.timer = _point.timer_exit;
    _m.px = _point.x;
    _m.py = _point.y;
    if (!_in_zone)
    {
        _point.timer_exit_max = COOP_EXTRACT_SOLO_TICKS;
        _x.waiting = [];
        coop_extract_send();
        exit;
    }
    // who of the living raid players is not at this point
    var _waiting = [];
    var _max_t = _point.timer_exit;
    var _ps = coop_peers();
    for (var _k = 0; _k < COOP_MAX_PLAYERS; _k++)
    {
        var _p = _ps[_k];
        if (_k == _c.slot || !is_struct(_p) || !_p.connected || !_p.in_raid)
        {
            continue;
        }
        if (_p.raid_seed != coop_raid_seed_mine())
        {
            continue; // another raid
        }
        var _pup = coop_puppet_of(_k);
        if (instance_exists(_pup) && variable_instance_exists(_pup, "coop_hp") && _pup.coop_hp <= 0)
        {
            continue; // dead
        }
        var _o = _x.others[_k];
        if (is_struct(_o) && _o.in_zone && _o.px == _point.x && _o.py == _point.y)
        {
            _max_t = max(_max_t, _o.timer);
        }
        else
        {
            array_push(_waiting, _k);
        }
    }
    _x.waiting = _waiting;
    _point.timer_exit_max = (array_length(_waiting) > 0) ? COOP_EXTRACT_WAIT_TICKS : COOP_EXTRACT_SOLO_TICKS;
    if (array_length(_waiting) == 0)
    {
        // everybody here: follow the furthest timer, so the group leaves together
        _point.timer_exit = max(_point.timer_exit, min(_max_t, _point.timer_exit_max - 1));
    }
    _x.group_max = _point.timer_exit_max;
    _m.timer = _point.timer_exit;
    coop_extract_send();
}

// The seed of the raid we are in (peers in another raid don't wait for us).
function coop_raid_seed_mine()
{
    var _c = coop();
    return variable_struct_exists(_c, "gen_seed") && _c.gen_seed != undefined ? _c.gen_seed : -1;
}

function coop_extract_send()
{
    var _c = coop();
    var _x = coop_extract();
    var _m = _x.mine;
    // on change of zone at once, the timer 4 times a second
    var _sig = string(_m.in_zone) + string(_m.px) + string(_m.py);
    if (_x.sent_sig == _sig && current_time - _x.sent_t < 250)
    {
        exit;
    }
    _x.sent_sig = _sig;
    _x.sent_t = current_time;
    var _b = coop_msg_begin(COOP_MSG_EXTRACT);
    buffer_write(_b, buffer_u8, _m.in_zone);
    buffer_write(_b, buffer_f32, _m.timer);
    buffer_write(_b, buffer_f32, _m.px);
    buffer_write(_b, buffer_f32, _m.py);
    coop_msg_send(true);
}

function coop_extract_on_msg(_b)
{
    var _c = coop();
    var _x = coop_extract();
    var _in = buffer_read(_b, buffer_u8);
    var _t = buffer_read(_b, buffer_f32);
    var _px = buffer_read(_b, buffer_f32);
    var _py = buffer_read(_b, buffer_f32);
    if (_c.msg_from >= 0 && _c.msg_from < COOP_MAX_PLAYERS)
    {
        var _was = is_struct(_x.others[_c.msg_from]) && _x.others[_c.msg_from].in_zone;
        _x.others[_c.msg_from] = { in_zone: _in, timer: _t, px: _px, py: _py, t: current_time };
        if (_in && !_was && coop_in_raid())
        {
            coop_log("extract: slot ", _c.msg_from, " is extracting at ", _px, ",", _py);
        }
    }
}

// Draw GUI (raid): the group banner at the top centre.
function coop_extract_draw()
{
    var _c = coop();
    if (!_c.connected || !coop_in_raid() || instance_exists(obj_exit_screen))
    {
        exit;
    }
    var _x = coop_extract();
    var _text = "";
    var _col = COOP_C_KEY;
    if (_x.mine.in_zone)
    {
        var _left = max(0, ceil((_x.group_max - _x.mine.timer) / 60));
        if (array_length(_x.waiting) > 0)
        {
            var _names = "";
            for (var _i = 0; _i < array_length(_x.waiting); _i++) _names += ((_i > 0) ? ", " : "") + coop_peer_name(_x.waiting[_i]);
            _text = coop_tf("Extraction in {0} s - waiting for {1}", "Эвакуация через {0} с - ждём: {1}", _left, _names);
        }
        else
        {
            _text = coop_tf("Group extraction in {0} s", "Группа уходит через {0} с", _left);
            _col = COOP_C_GREEN;
        }
    }
    else
    {
        // a teammate is extracting somewhere
        for (var _k = 0; _k < COOP_MAX_PLAYERS; _k++)
        {
            var _o = _x.others[_k];
            if (is_struct(_o) && _o.in_zone && current_time - _o.t < 1500)
            {
                var _who = coop_puppet_of(_k);
                var _dist = instance_exists(_who) && instance_exists(obj_player) ? floor(point_distance(obj_player.x, obj_player.y, _o.px, _o.py) / 16) : -1;
                _text = coop_tf("{0} is extracting ({1} m away)", "{0} уходит из рейда ({1} м от вас)", coop_peer_name(_k), _dist);
                break;
            }
        }
    }
    if (_text == "")
    {
        exit;
    }
    coop_ui_font(COOP_F_BODY);
    draw_set_halign(fa_center);
    var _w = string_width(_text) / 2 + 20;
    coop_ui_rect(COOP_GW / 2 - _w, 150, COOP_GW / 2 + _w, 196, c_black, 0.65);
    coop_ui_rect(COOP_GW / 2 - _w, 193, COOP_GW / 2 + _w, 196, _col);
    coop_ui_text(COOP_GW / 2, 158, _text, _col);
    draw_set_halign(fa_left);
}

// ---- raid summary ----

function coop_summary_reset()
{
    var _c = coop();
    _c.my_stats = { kills: 0, damage: 0, revives: 0, downs: 0 };
    _c.summary = array_create(COOP_MAX_PLAYERS, undefined);
    _c.summary_sent = false;
    _c.summary_raid = []; // slots that were in this raid with us
    var _x = coop_extract();
    _x.mine = { in_zone: false, timer: 0, px: 0, py: 0 };
    _x.others = array_create(COOP_MAX_PLAYERS, undefined);
    _x.waiting = [];
}

function coop_stat_add(_key, _amount)
{
    var _c = coop();
    if (!variable_struct_exists(_c, "my_stats")) coop_summary_reset();
    variable_struct_set(_c.my_stats, _key, variable_struct_get(_c.my_stats, _key) + _amount);
}

// obj_coop Step: remember who shares the raid; send ours once our raid is over (exit screen).
function coop_summary_step()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "my_stats"))
    {
        coop_summary_reset();
    }
    if (coop_in_raid() && _c.connected)
    {
        var _ps = coop_peers();
        for (var _k = 0; _k < COOP_MAX_PLAYERS; _k++)
        {
            if (_k != _c.slot && is_struct(_ps[_k]) && _ps[_k].connected && _ps[_k].in_raid && _ps[_k].raid_seed == coop_raid_seed_mine()
                && !array_contains(_c.summary_raid, _k))
            {
                array_push(_c.summary_raid, _k);
            }
        }
    }
    if (!_c.summary_sent && instance_exists(obj_exit_screen) && _c.connected)
    {
        _c.summary_sent = true;
        var _value = variable_instance_exists(obj_exit_screen, "value_made") ? obj_exit_screen.value_made : 0;
        var _surv = variable_instance_exists(obj_exit_screen, "survived") && obj_exit_screen.survived;
        var _s = _c.my_stats;
        var _me = { slot: max(0, _c.slot), name: coop_my_name(), survived: _surv, kills: _s.kills, damage: round(_s.damage), revives: _s.revives, downs: _s.downs, value: _value };
        _c.summary[_me.slot] = _me;
        var _b = coop_msg_begin(COOP_MSG_SUMMARY);
        buffer_write(_b, buffer_string, json_stringify(_me));
        coop_msg_send(true);
        coop_log("summary sent: ", json_stringify(_me));
        coop_partners_on_raid_end(_value);
    }
}

function coop_summary_on_msg(_b)
{
    var _c = coop();
    var _d = json_parse(buffer_read(_b, buffer_string));
    if (!variable_struct_exists(_c, "summary")) coop_summary_reset();
    if (_c.msg_from >= 0 && _c.msg_from < COOP_MAX_PLAYERS && is_struct(_d))
    {
        _d.slot = _c.msg_from;
        var _was = is_struct(_c.summary[_c.msg_from]);
        _c.summary[_c.msg_from] = _d;
        if (!_was) coop_partners_on_summary(_c.msg_from, _d);
        coop_log("summary from slot ", _c.msg_from, ": kills ", _d.kills, " damage ", _d.damage, " revives ", _d.revives, " value ", _d.value);
    }
}

// Draw GUI over the extraction / death screen: one row per raid player.
function coop_summary_draw()
{
    var _c = coop();
    if (!_c.connected || !instance_exists(obj_exit_screen) || !variable_struct_exists(_c, "summary"))
    {
        exit;
    }
    var _rows = [max(0, _c.slot)];
    for (var _i = 0; _i < array_length(_c.summary_raid); _i++) array_push(_rows, _c.summary_raid[_i]);
    coop_ui_font(COOP_F_SMALL);
    // right side, below the title and the experience bar of the exit screen
    var _x1 = COOP_GW - 700;
    var _y1 = 600;
    var _rh = 34;
    var _y = coop_ui_panel(_x1, _y1, COOP_GW - 40, _y1 + 110 + array_length(_rows) * _rh, coop_t("RAID SUMMARY", "ИТОГИ РЕЙДА"), 0.9);
    var _cols = [_x1 + 20, _x1 + 230, _x1 + 320, _x1 + 410, _x1 + 500, _x1 + 570];
    coop_ui_text(_cols[0], _y, coop_t("Player", "Игрок"), COOP_C_DIM);
    coop_ui_text(_cols[1], _y, coop_t("Kills", "Убийства"), COOP_C_DIM);
    coop_ui_text(_cols[2], _y, coop_t("Damage", "Урон"), COOP_C_DIM);
    coop_ui_text(_cols[3], _y, coop_t("Revives", "Подъёмы"), COOP_C_DIM);
    coop_ui_text(_cols[4], _y, coop_t("Downs", "Ранен"), COOP_C_DIM);
    coop_ui_text(_cols[5], _y, coop_t("Value", "Добыча"), COOP_C_DIM);
    _y += _rh;
    for (var _i = 0; _i < array_length(_rows); _i++)
    {
        var _k = _rows[_i];
        var _e = _c.summary[_k];
        var _nm = (_k == max(0, _c.slot)) ? coop_my_shown_name() : coop_peer_name(_k);
        coop_ui_rect(_cols[0], _y + 8, _cols[0] + 9, _y + 17, coop_slot_colour(_k));
        coop_ui_text(_cols[0] + 16, _y, coop_ui_fit(_nm, 200), COOP_C_TEXT);
        if (!is_struct(_e))
        {
            coop_ui_text(_cols[1], _y, coop_t("still in the raid", "ещё в рейде"), COOP_C_DIM);
        }
        else
        {
            coop_ui_text(_cols[1], _y, string(_e.kills), COOP_C_TEXT);
            coop_ui_text(_cols[2], _y, string(_e.damage), COOP_C_TEXT);
            coop_ui_text(_cols[3], _y, string(_e.revives), COOP_C_TEXT);
            coop_ui_text(_cols[4], _y, string(_e.downs), COOP_C_TEXT);
            coop_ui_text(_cols[5], _y, _e.survived ? string(_e.value) : coop_t("died", "погиб"), (_e.survived && _e.value >= 0) ? COOP_C_GREEN : COOP_C_RED);
        }
        _y += _rh;
    }
}

// ---- lifetime stats per partner (2.0.0 item 45) ----
// coop_partners.json in the save area: per partner name { raids, revived (by us), kills (theirs, in raids with us),
// value (made together: ours + theirs) , last }. Updated when our raid ends and when a partner's summary arrives.

function coop_partners_load()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "partners"))
    {
        _c.partners = {};
        if (file_exists("coop_partners.json"))
        {
            try
            {
                var _b = buffer_load("coop_partners.json");
                _c.partners = json_parse(buffer_read(_b, buffer_text));
                buffer_delete(_b);
            }
            catch (_e)
            {
                _c.partners = {};
            }
        }
    }
    return _c.partners;
}

function coop_partners_save()
{
    var _t = json_stringify(coop_partners_load());
    var _b = buffer_create(string_byte_length(_t) + 1, buffer_fixed, 1);
    buffer_write(_b, buffer_text, _t);
    buffer_save(_b, "coop_partners.json");
    buffer_delete(_b);
}

function coop_partner_entry(_name)
{
    var _all = coop_partners_load();
    if (!variable_struct_exists(_all, _name))
    {
        variable_struct_set(_all, _name, { raids: 0, revived: 0, kills: 0, value: 0, last: "" });
    }
    return variable_struct_get(_all, _name);
}

// Our raid ended (coop_summary_step): one raid more with everybody who shared it; our revives per partner.
function coop_partners_on_raid_end(_my_value)
{
    var _c = coop();
    for (var _i = 0; _i < array_length(_c.summary_raid); _i++)
    {
        var _k = _c.summary_raid[_i];
        var _p = coop_peer(_k);
        if (!is_struct(_p)) continue;
        var _e = coop_partner_entry(_p.name);
        _e.raids++;
        _e.value += max(0, _my_value);
        var _rk = "rev" + string(_k);
        if (variable_struct_exists(_c.my_stats, _rk)) _e.revived += variable_struct_get(_c.my_stats, _rk);
        _e.last = date_date_string(date_current_datetime());
    }
    coop_partners_save();
}

// A partner's summary of a raid we shared.
function coop_partners_on_summary(_slot, _d)
{
    var _c = coop();
    if (!array_contains(_c.summary_raid, _slot)) exit;
    var _p = coop_peer(_slot);
    if (!is_struct(_p)) exit;
    var _e = coop_partner_entry(_p.name);
    _e.kills += _d.kills;
    _e.value += max(0, _d.value);
    coop_partners_save();
}
