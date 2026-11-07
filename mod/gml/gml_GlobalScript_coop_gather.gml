// ZERO Sievert co-op: raid start with a gathering zone at the train.
// The host's train ride does not drag the whole bunker along any more: a rectangle with a countdown appears on the
// platform along the train. Whoever stands in it when the countdown ends goes with the host; the others stay in
// the bunker and can join the raid later (train or F7 - coop_hook_go_to_map turns that into a late join).

#macro COOP_MSG_GATHER 67
#macro COOP_GATHER_SECONDS 15
// the platform zone: from COOP_GATHER_DEPTH above the train sprite's top edge down to COOP_GATHER_ROOF above it
// (the cars' roofs start a little below the bbox top; no comment on a #macro line: build.csx pastes it)
#macro COOP_GATHER_DEPTH 80
#macro COOP_GATHER_ROOF 12

// The zone [x1, y1, x2, y2] in room coordinates: the strip of platform along the train (the user's sketch), or a
// band around the host if the hub has no train instance.
function coop_gather_rect()
{
    // the bunker's train is obj_train_hub (obj_train is the raid train); culling may have deactivated it
    instance_activate_object(obj_train_hub);
    with (obj_train_hub)
    {
        if (bbox_right - bbox_left > 64)
        {
            return [bbox_left, bbox_top - COOP_GATHER_DEPTH, bbox_right, bbox_top - COOP_GATHER_ROOF];
        }
    }
    if (instance_exists(obj_player))
    {
        return [obj_player.x - 160, obj_player.y - 48, obj_player.x + 160, obj_player.y + 48];
    }
    return [0, 0, 0, 0];
}

function coop_gather_in(_g, _x, _y)
{
    return point_in_rectangle(_x, _y, _g.x1, _g.y1, _g.x2, _g.y2);
}

// Host, from coop_hook_go_to_map: true = the ride waits for the countdown (go_to_map must stop).
function coop_gather_begin(_map)
{
    var _c = coop();
    if (_c.role != "host" || !_c.connected || !is_in_hub() || !instance_exists(obj_player))
    {
        return false;
    }
    if (variable_struct_exists(_c, "gather_go") && _c.gather_go)
    {
        _c.gather_go = false; // the countdown is over: this is the real ride
        return false;
    }
    if (variable_struct_exists(_c, "gather") && _c.gather != undefined)
    {
        return true; // already counting down
    }
    var _others = false;
    var _ps = coop_peers();
    for (var _k = 0; _k < COOP_MAX_PLAYERS; _k++)
    {
        var _p = _ps[_k];
        if (_k != _c.slot && is_struct(_p) && _p.connected && _p.loc == 1)
        {
            _others = true;
        }
    }
    if (!_others)
    {
        return false; // nobody in the bunker to wait for
    }
    var _secs = _c.test_mode ? 4 : COOP_GATHER_SECONDS;
    var _r = coop_gather_rect();
    _c.gather = { map: _map, x1: _r[0], y1: _r[1], x2: _r[2], y2: _r[3], end_time: current_time + _secs * 1000 };
    coop_gather_send(_map, _secs);
    __uiGlobal().__defaultOnion.Clear(); // the train dialogue
    coop_notify(coop_tf("Raid in {0} s - players in the zone at the train go with you", "Рейд через {0} с - кто в зоне у поезда, едет с вами", _secs));
    coop_log("gather: map ", _map, " ", _secs, " s zone ", floor(_r[0]), ",", floor(_r[1]), " - ", floor(_r[2]), ",", floor(_r[3]), " train=", instance_exists(obj_train_hub));
    return true;
}

function coop_gather_send(_map, _secs)
{
    var _c = coop();
    var _b = coop_msg_begin(COOP_MSG_GATHER);
    buffer_write(_b, buffer_u8, _map);
    var _g = _c.gather;
    buffer_write(_b, buffer_f32, _g == undefined ? 0 : _g.x1);
    buffer_write(_b, buffer_f32, _g == undefined ? 0 : _g.y1);
    buffer_write(_b, buffer_f32, _g == undefined ? 0 : _g.x2);
    buffer_write(_b, buffer_f32, _g == undefined ? 0 : _g.y2);
    buffer_write(_b, buffer_u16, _secs); // 0 = cancelled
    coop_msg_send(true);
}

// Guest: the host opened (or cancelled) a gathering circle.
function coop_gather_on_msg(_b)
{
    var _c = coop();
    var _map = buffer_read(_b, buffer_u8);
    var _x1 = buffer_read(_b, buffer_f32);
    var _y1 = buffer_read(_b, buffer_f32);
    var _x2 = buffer_read(_b, buffer_f32);
    var _y2 = buffer_read(_b, buffer_f32);
    var _secs = buffer_read(_b, buffer_u16);
    if (_c.role != "guest" || coop().msg_from != 0)
    {
        exit;
    }
    if (_secs == 0)
    {
        _c.gather = undefined;
        coop_log("gather: cancelled by the host");
        exit;
    }
    _c.gather = { map: _map, x1: _x1, y1: _y1, x2: _x2, y2: _y2, end_time: current_time + _secs * 1000 };
    coop_log("gather: host starts a raid in ", _secs, " s");
    if (is_in_hub())
    {
        coop_notify(coop_tf("{0} is starting a raid - stand in the zone at the train ({1} s)", "{0} начинает рейд - встаньте в зону у поезда ({1} с)", _c.peer_name, _secs));
    }
}

// Guest, on the host's RAID_START: go along only from inside the zone.
function coop_gather_inside()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "gather") || _c.gather == undefined)
    {
        return true; // no circle (old flow, nobody else was in the bunker): follow as before
    }
    var _g = _c.gather;
    _c.gather = undefined;
    return instance_exists(obj_player) && coop_gather_in(_g, obj_player.x, obj_player.y);
}

// obj_coop Step: the host's countdown; stale circles are dropped.
function coop_gather_step()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "gather") || _c.gather == undefined)
    {
        exit;
    }
    var _g = _c.gather;
    if (_c.role != "host")
    {
        if (!_c.connected || current_time > _g.end_time + 15000)
        {
            _c.gather = undefined;
        }
        exit;
    }
    if (!_c.connected || !is_in_hub() || !instance_exists(obj_player))
    {
        _c.gather = undefined;
        if (_c.connected)
        {
            coop_gather_send(0, 0);
        }
        exit;
    }
    if (current_time < _g.end_time || !player_state_is(0, scr_player_state_move))
    {
        exit; // (a menu open at the end: leave when it is closed)
    }
    _c.gather = undefined;
    _c.gather_go = true;
    coop_log("gather: countdown over, leaving for map ", _g.map);
    __uiGlobal().__defaultOnion.Clear();
    go_to_map(_g.map);
}

// Draw GUI (bunker): the zone and the seconds left.
function coop_gather_draw()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "gather") || _c.gather == undefined || !is_in_hub())
    {
        exit;
    }
    var _g = _c.gather;
    var _x1 = coop_ui_world_x(_g.x1);
    var _y1 = coop_ui_world_y(_g.y1);
    var _x2 = coop_ui_world_x(_g.x2);
    var _y2 = coop_ui_world_y(_g.y2);
    var _in = instance_exists(obj_player) && coop_gather_in(_g, obj_player.x, obj_player.y);
    var _col = _in ? c_lime : c_yellow;
    draw_set_alpha(0.12);
    draw_rectangle_colour(_x1, _y1, _x2, _y2, _col, _col, _col, _col, false);
    draw_set_alpha(0.9);
    for (var _w = 0; _w < 3; _w++)
    {
        draw_rectangle_colour(_x1 + _w, _y1 + _w, _x2 - _w, _y2 - _w, _col, _col, _col, _col, true);
    }
    draw_set_alpha(1);
    var _left = max(0, ceil((_g.end_time - current_time) / 1000));
    // the label sits over the zone, kept on screen
    var _lx = clamp((max(_x1, 0) + min(_x2, COOP_GW)) / 2, 200, COOP_GW - 200);
    var _ly = clamp(_y1 - 90, 140, COOP_GH - 120);
    coop_ui_font(COOP_F_BODY);
    draw_set_halign(fa_center);
    coop_ui_text_ol(_lx, _ly, coop_tf("Raid in {0} s", "Рейд через {0} с", _left), _col);
    coop_ui_text_ol(_lx, _ly + 40, _in ? coop_t("You are going", "Вы едете") : coop_t("You are staying", "Вы остаётесь"), _col);
    draw_set_halign(fa_left);
    coop_ui_font(COOP_F_SMALL);
}
