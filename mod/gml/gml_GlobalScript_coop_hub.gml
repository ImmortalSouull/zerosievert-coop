// ZERO Sievert co-op: the hub as a lobby and visits.
// Lobby: everybody stays in their own hub (own traders, stash, bunker - all from their own save), but the
// other players who are in their hub too are shown walking around it (same room layout for everybody).
// Visit: the bunker modules (beds, kitchen, infirmary, forge...) are swapped for a friend's ones, sent by
// them as plain data. Only the look and the benches change; the stash, the items and the save stay ours:
// installing/upgrading modules and taking module production are blocked during a visit, and every save of
// the base writes our own modules (coop_visit_save_guard).

#macro COOP_MSG_BASE 17
#macro COOP_MSG_VISIT 18
#macro COOP_BUNKER_Y 1146

function coop_hub_ready()
{
    return is_in_hub() && instance_exists(obj_player);
}

// The player in _slot is in their hub while we are in ours: shown in the lobby.
function coop_hub_peer_here(_slot)
{
    if (!coop_hub_ready() || _slot == coop().slot)
    {
        return false;
    }
    var _p = coop_peer(_slot);
    return is_struct(_p) && _p.connected && _p.loc == 1;
}

function coop_hub_together()
{
    if (!coop_hub_ready())
    {
        return false;
    }
    var _r = coop_remote_peers();
    for (var _i = 0; _i < array_length(_r); _i++)
    {
        if (_r[_i].loc == 1)
        {
            return true;
        }
    }
    return false;
}

// Puppets of players who are neither in our raid nor in the lobby with us.
function coop_puppets_prune()
{
    var _l = coop_puppets();
    var _raid = coop_in_raid();
    for (var _i = 0; _i < array_length(_l); _i++)
    {
        var _s = _l[_i].coop_slot;
        var _p = coop_peer(_s);
        var _keep = is_struct(_p) && _p.connected && ((_raid && _p.in_raid) || coop_hub_peer_here(_s));
        if (!_keep)
        {
            coop_puppet_remove_slot(_s);
        }
    }
}

// ---- bunker modules as data ----

function coop_base_capture()
{
    var _lvl = [];
    var _sb = [];
    var _sf = [];
    array_copy(_lvl, 0, global.base_lvl, 0, array_length(global.base_lvl));
    array_copy(_sb, 0, global.sl_base_id, 0, array_length(global.sl_base_id));
    array_copy(_sf, 0, global.sl_free, 0, array_length(global.sl_free));
    return { lvl: _lvl, sb: _sb, sf: _sf };
}

function coop_base_apply(_d)
{
    var _n = min(array_length(global.base_lvl), array_length(_d.lvl));
    for (var _i = 0; _i < _n; _i++)
    {
        global.base_lvl[_i] = _d.lvl[_i];
    }
    _n = min(array_length(global.sl_base_id), array_length(_d.sb));
    for (var _i = 0; _i < _n; _i++)
    {
        global.sl_base_id[_i] = _d.sb[_i];
    }
    _n = min(array_length(global.sl_free), array_length(_d.sf));
    for (var _i = 0; _i < _n; _i++)
    {
        global.sl_free[_i] = _d.sf[_i];
    }
}

// Rebuild the module furniture from the current arrays, right now (obj_base_parent Alarm 0 does the work).
// The game deactivates everything off screen and with() skips deactivated instances, so the old furniture
// would survive next to the new one: the whole bunker is activated first (the game deactivates it again
// on its own).
function coop_base_rebuild()
{
    instance_activate_region(0, 560, 1300, COOP_BUNKER_Y - 560 + 120, true);
    with (obj_base_parent)
    {
        id_base = -1;
        lvl_before = -1;
        event_perform(ev_alarm, 0);
    }
}

// Our own modules, also while a visit has the friend's ones in the globals.
function coop_base_own()
{
    var _c = coop();
    if (variable_struct_exists(_c, "visit") && _c.visit.slot >= 0)
    {
        return _c.visit.own;
    }
    return coop_base_capture();
}

function coop_base_send()
{
    var _c = coop();
    var _b = coop_msg_begin(COOP_MSG_BASE);
    buffer_write(_b, buffer_string, json_stringify(coop_base_own()));
    coop_msg_send(true);
}

function coop_base_on_msg(_b)
{
    var _c = coop();
    var _p = coop_peer(_c.msg_from);
    var _s = buffer_read(_b, buffer_string);
    if (!is_struct(_p))
    {
        exit;
    }
    try
    {
        var _d = json_parse(_s);
        if (is_struct(_d) && is_array(_d.lvl) && is_array(_d.sb) && is_array(_d.sf))
        {
            _p.base = _d;
            // visiting them right now: show their changes too
            if (variable_struct_exists(_c, "visit") && _c.visit.slot == _c.msg_from && coop_hub_ready())
            {
                coop_base_apply(_d);
                coop_base_rebuild();
            }
        }
    }
    catch (_e)
    {
        coop_log("ERROR (recovered): base data ", _e.message);
    }
}

// ---- visits ----

function coop_visit()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "visit"))
    {
        _c.visit = { slot: -1, own: undefined, saving: false };
    }
    return _c.visit;
}

function coop_visit_active()
{
    return coop_visit().slot >= 0;
}

function coop_visit_can(_slot)
{
    var _p = coop_peer(_slot);
    return coop_hub_ready() && _slot != coop().slot && is_struct(_p) && _p.connected && variable_struct_exists(_p, "base");
}

// Into the player's room of the bunker (where the game puts the player after sleeping), also when a visit
// ends there: the new furniture may stand where the player is.
function coop_visit_place_player()
{
    if (!instance_exists(obj_player) || !instance_exists(obj_player_room_spawn))
    {
        exit;
    }
    obj_player.x = obj_player_room_spawn.x;
    obj_player.y = obj_player_room_spawn.y;
}

function coop_visit_start(_slot)
{
    var _v = coop_visit();
    if (!coop_visit_can(_slot))
    {
        exit;
    }
    if (_v.slot < 0)
    {
        _v.own = coop_base_capture();
    }
    _v.slot = _slot;
    var _p = coop_peer(_slot);
    coop_base_apply(_p.base);
    coop_base_rebuild();
    coop_visit_place_player();
    coop_notify(coop_t("You are visiting " + _p.name + ": their bunker, your stash and items", "Вы в гостях у " + _p.name + ": его бункер, ваши схрон и вещи"));
    coop_log("visit start: slot ", _slot);
    var _b = coop_msg_begin(COOP_MSG_VISIT);
    buffer_write(_b, buffer_u8, 1);
    coop_msg_send_to(_slot, true);
}

function coop_visit_end(_why)
{
    var _v = coop_visit();
    if (_v.slot < 0)
    {
        exit;
    }
    var _slot = _v.slot;
    _v.slot = -1;
    coop_base_apply(_v.own);
    _v.own = undefined;
    if (is_in_hub() && _why != "raid")
    {
        coop_base_rebuild();
        if (_why == "panel" && instance_exists(obj_player) && instance_exists(obj_player_room_spawn) && point_distance(obj_player.x, obj_player.y, obj_player_room_spawn.x, obj_player_room_spawn.y) < 240)
        {
            coop_visit_place_player();
        }
        coop_notify(coop_t("Back in your own bunker", "Вы вернулись в свой бункер"));
    }
    coop_log("visit end (", _why, ")");
    var _p = coop_peer(_slot);
    if (is_struct(_p) && _p.connected)
    {
        var _b = coop_msg_begin(COOP_MSG_VISIT);
        buffer_write(_b, buffer_u8, 0);
        coop_msg_send_to(_slot, true);
    }
}

function coop_visit_on_msg(_b)
{
    var _c = coop();
    var _in = buffer_read(_b, buffer_u8);
    var _name = coop_peer_name(_c.msg_from);
    if (_in)
    {
        coop_notify(coop_t(_name + " is visiting your bunker", _name + " зашёл к вам в гости"));
    }
    else
    {
        coop_notify(coop_t(_name + " went back home", _name + " вернулся к себе"));
    }
}

// Prepended to scr_save_skill_and_base: during a visit the save writes our own modules.
function coop_visit_save_guard()
{
    var _v = coop_visit();
    if (_v.slot < 0 || _v.saving)
    {
        return false;
    }
    _v.saving = true;
    var _theirs = coop_base_capture();
    coop_base_apply(_v.own);
    try
    {
        scr_save_skill_and_base();
    }
    catch (_e)
    {
        coop_log("ERROR (recovered): visit save ", _e.message);
    }
    coop_base_apply(_theirs);
    _v.saving = false;
    return true;
}

// Module install/upgrade/production during a visit: not ours to change.
function coop_visit_blocks()
{
    if (!coop_visit_active())
    {
        return false;
    }
    scr_draw_text_with_box(coop_t("This is your friend's bunker", "Это бункер друга"));
    return true;
}

// obj_coop Step.
function coop_hub_step()
{
    var _c = coop();
    var _v = coop_visit();
    if (_v.slot >= 0)
    {
        var _p = coop_peer(_v.slot);
        if (!is_in_hub())
        {
            coop_visit_end("left the hub");
        }
        else if (!is_struct(_p) || !_p.connected)
        {
            coop_visit_end("friend gone");
        }
        else if (instance_exists(obj_player) && obj_player.y > COOP_BUNKER_Y + 48)
        {
            coop_visit_end("walked out");
        }
    }
    if (!_c.connected || !coop_hub_ready() || _c.frame mod 60 != 0)
    {
        exit;
    }
    var _sig = json_stringify(coop_base_own());
    if (!variable_struct_exists(_c, "base_sig") || _c.base_sig != _sig)
    {
        _c.base_sig = _sig;
        coop_base_send();
    }
    if (_c.test_mode && !variable_struct_exists(_c, "hub_info_logged"))
    {
        _c.hub_info_logged = true;
        with (obj_hub_main_door)
        {
            coop_log("hub door at ", x, ",", y);
        }
        with (obj_base_parent)
        {
            coop_log("base slot ", slot, " at ", x, ",", y, " module ", id_base, " lvl ", lvl_now);
        }
        coop_log("player at ", obj_player.x, ",", obj_player.y);
    }
}

// Draw GUI (UI space): visiting label.
function coop_hub_draw_gui()
{
    var _v = coop_visit();
    if (_v.slot < 0)
    {
        exit;
    }
    coop_ui_font(COOP_F_SMALL);
    coop_ui_prompt(COOP_GW / 2, 16, "F7", coop_t("Visiting ", "В гостях у ") + coop_peer_name(_v.slot) + coop_t(" - go home", " - вернуться к себе"));
}

// obj_vertex_props (hub): the furniture of the bunker modules stays as instances instead of being baked into
// the static vertex buffer, so a visit (or installing a module) can replace it.
function coop_is_base_decor(_i)
{
    if (!is_in_hub())
    {
        return false;
    }
    var _r = false;
    with (obj_base_parent)
    {
        if (_i.x >= x && _i.x <= x + 48 && _i.y >= y && _i.y <= y + 48)
        {
            _r = true;
            break;
        }
    }
    return _r;
}
