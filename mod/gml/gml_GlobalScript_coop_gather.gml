// ZERO Sievert co-op: raid start with a gathering circle at the train.
// The host's train ride does not drag the whole bunker along any more: a circle with a countdown appears where the
// host stands (at the train). Whoever stands in it when the countdown ends goes with the host; the others stay in
// the bunker and can join the raid later (train or F7 - coop_hook_go_to_map turns that into a late join).

#macro COOP_MSG_GATHER 67
#macro COOP_GATHER_RADIUS 160
#macro COOP_GATHER_SECONDS 15

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
    _c.gather = { map: _map, x: obj_player.x, y: obj_player.y, end_time: current_time + _secs * 1000 };
    coop_gather_send(_map, _secs);
    __uiGlobal().__defaultOnion.Clear(); // the train dialogue
    coop_notify(coop_tf("Raid in {0} s - players in the circle go with you", "Рейд через {0} с - кто в круге, едет с вами", _secs));
    coop_log("gather: map ", _map, " ", _secs, " s at ", floor(obj_player.x), ",", floor(obj_player.y));
    return true;
}

function coop_gather_send(_map, _secs)
{
    var _c = coop();
    var _b = coop_msg_begin(COOP_MSG_GATHER);
    buffer_write(_b, buffer_u8, _map);
    buffer_write(_b, buffer_f32, _c.gather == undefined ? 0 : _c.gather.x);
    buffer_write(_b, buffer_f32, _c.gather == undefined ? 0 : _c.gather.y);
    buffer_write(_b, buffer_u16, _secs); // 0 = cancelled
    coop_msg_send(true);
}

// Guest: the host opened (or cancelled) a gathering circle.
function coop_gather_on_msg(_b)
{
    var _c = coop();
    var _map = buffer_read(_b, buffer_u8);
    var _x = buffer_read(_b, buffer_f32);
    var _y = buffer_read(_b, buffer_f32);
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
    _c.gather = { map: _map, x: _x, y: _y, end_time: current_time + _secs * 1000 };
    coop_log("gather: host starts a raid in ", _secs, " s");
    if (is_in_hub())
    {
        coop_notify(coop_tf("{0} is starting a raid - stand in the circle at the train ({1} s)", "{0} начинает рейд - встаньте в круг у поезда ({1} с)", _c.peer_name, _secs));
    }
}

// Guest, on the host's RAID_START: go along only from inside the circle.
function coop_gather_inside()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "gather") || _c.gather == undefined)
    {
        return true; // no circle (old flow, nobody else was in the bunker): follow as before
    }
    var _g = _c.gather;
    _c.gather = undefined;
    return instance_exists(obj_player) && point_distance(obj_player.x, obj_player.y, _g.x, _g.y) <= COOP_GATHER_RADIUS;
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

// Draw GUI (bunker): the circle and the seconds left.
function coop_gather_draw()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "gather") || _c.gather == undefined || !is_in_hub())
    {
        exit;
    }
    var _g = _c.gather;
    var _cam = view_camera[0];
    var _gx = coop_ui_world_x(_g.x);
    var _gy = coop_ui_world_y(_g.y);
    var _r = COOP_GATHER_RADIUS / max(1, camera_get_view_width(_cam)) * COOP_GW;
    var _in = instance_exists(obj_player) && point_distance(obj_player.x, obj_player.y, _g.x, _g.y) <= COOP_GATHER_RADIUS;
    var _col = _in ? c_lime : c_yellow;
    draw_set_alpha(0.12);
    draw_circle_colour(_gx, _gy, _r, _col, _col, false);
    draw_set_alpha(0.9);
    for (var _w = 0; _w < 3; _w++)
    {
        draw_circle_colour(_gx, _gy, _r - _w, _col, _col, true);
    }
    draw_set_alpha(1);
    var _left = max(0, ceil((_g.end_time - current_time) / 1000));
    draw_set_halign(fa_center);
    coop_ui_text_ol(_gx, _gy - _r - 64, coop_tf("Raid in {0} s", "Рейд через {0} с", _left), _col);
    coop_ui_text_ol(_gx, _gy - _r - 36, _in ? coop_t("You are going", "Вы едете") : coop_t("You are staying", "Вы остаётесь"), _col);
    draw_set_halign(fa_left);
}
