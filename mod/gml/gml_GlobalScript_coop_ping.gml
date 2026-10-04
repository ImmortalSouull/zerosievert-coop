// ZERO Sievert co-op: ping markers. Middle mouse button (or the gamepad's right stick click) marks the spot under
// the aim cursor for every player: a marker with the name and distance for 10 seconds, at the screen edge when
// off screen, plus a short sound.

#macro COOP_MSG_MARK 15
#macro COOP_MARK_LIFE 10000

function coop_marks()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "marks"))
    {
        _c.marks = [];
    }
    return _c.marks;
}

function coop_mark_add(_slot, _x, _y)
{
    var _m = coop_marks();
    // one marker per player: a new ping replaces the old one
    for (var _i = array_length(_m) - 1; _i >= 0; _i--)
    {
        if (_m[_i].slot == _slot)
        {
            array_delete(_m, _i, 1);
        }
    }
    array_push(_m, { slot: _slot, x: _x, y: _y, t_end: current_time + COOP_MARK_LIFE, t0: current_time });
    if (audio_exists(snd_ui_click_text_npc))
    {
        audio_play_sound(snd_ui_click_text_npc, 9, false);
    }
}

// obj_coop Step.
function coop_ping_step()
{
    var _c = coop();
    if (!_c.connected || !coop_in_raid() || !instance_exists(obj_player) || !instance_exists(obj_cursor))
    {
        exit;
    }
    if (!player_state_is(0, scr_player_state_move) || (variable_struct_exists(_c, "panel") && _c.panel))
    {
        exit;
    }
    var _press = mouse_check_button_pressed(mb_middle);
    if (!_press && instance_exists(obj_gamepad))
    {
        for (var _d = 0; _d < 4; _d++)
        {
            if (gamepad_is_connected(_d) && gamepad_button_check_pressed(_d, gp_stickr))
            {
                _press = true;
            }
        }
    }
    if (variable_struct_exists(_c, "sim_ping") && _c.sim_ping)
    {
        _c.sim_ping = false; // test input
        _press = true;
    }
    if (!_press)
    {
        exit;
    }
    var _x = obj_cursor.aa_x;
    var _y = obj_cursor.aa_y;
    coop_mark_add(max(0, _c.slot), _x, _y);
    coop_msg_begin(COOP_MSG_MARK);
    buffer_write(_c.send_buf, buffer_f32, _x);
    buffer_write(_c.send_buf, buffer_f32, _y);
    coop_msg_send(true);
    coop_log("ping mark at ", floor(_x), ",", floor(_y));
}

function coop_mark_on_message(_b)
{
    var _x = buffer_read(_b, buffer_f32);
    var _y = buffer_read(_b, buffer_f32);
    if (!coop_in_raid())
    {
        exit;
    }
    var _c = coop();
    coop_mark_add(_c.msg_from, _x, _y);
    if (_c.test_mode)
    {
        coop_log("ping mark from slot ", _c.msg_from, " at ", floor(_x), ",", floor(_y));
    }
}

// Colour of a player's marker, the same as on the PDA map.
function coop_slot_colour(_slot)
{
    static _cols = [c_lime, c_aqua, c_yellow, c_orange];
    return _cols[clamp(_slot, 0, 3)];
}

// Draw GUI (480x270 space, set by coop_draw_gui).
function coop_ping_draw_gui()
{
    var _m = coop_marks();
    var _n = array_length(_m);
    if (_n == 0)
    {
        exit;
    }
    var _cam = view_camera[0];
    var _vx = camera_get_view_x(_cam);
    var _vy = camera_get_view_y(_cam);
    var _vw = max(1, camera_get_view_width(_cam));
    var _vh = max(1, camera_get_view_height(_cam));
    draw_set_halign(fa_center);
    draw_set_valign(fa_bottom);
    for (var _i = _n - 1; _i >= 0; _i--)
    {
        var _k = _m[_i];
        if (current_time > _k.t_end || !coop_in_raid())
        {
            array_delete(_m, _i, 1);
            continue;
        }
        var _col = coop_slot_colour(_k.slot);
        var _gx = (_k.x - _vx) / _vw * 480;
        var _gy = (_k.y - _vy) / _vh * 270;
        var _dist = instance_exists(obj_player) ? floor(point_distance(obj_player.x, obj_player.y, _k.x, _k.y) / 16) : 0;
        var _name = (_k.slot == coop().slot) ? coop_t("You", "Вы") : coop_peer_name(_k.slot);
        var _label = _name + " " + string(_dist) + coop_t("m", "м");
        // a short pulse when it appears
        var _age = current_time - _k.t0;
        var _r = 4 + ((_age < 600) ? (1 - _age / 600) * 6 : 0);
        if (_gx >= 8 && _gx <= 472 && _gy >= 16 && _gy <= 262)
        {
            draw_triangle_colour(_gx, _gy + _r, _gx - _r, _gy, _gx + _r, _gy, _col, _col, _col, false);
            draw_triangle_colour(_gx, _gy - _r, _gx - _r, _gy, _gx + _r, _gy, _col, _col, _col, false);
            coop_text_outlined(_gx, _gy - _r - 1, _label, _col);
        }
        else
        {
            var _cx = clamp(_gx, 14, 466);
            var _cy = clamp(_gy, 24, 252);
            var _dir = point_direction(240, 135, _gx, _gy);
            draw_triangle_colour(_cx + lengthdir_x(6, _dir), _cy + lengthdir_y(6, _dir), _cx + lengthdir_x(4, _dir + 140), _cy + lengthdir_y(4, _dir + 140), _cx + lengthdir_x(4, _dir - 140), _cy + lengthdir_y(4, _dir - 140), _col, _col, _col, false);
            draw_set_valign(fa_middle);
            coop_text_outlined(clamp(_cx - lengthdir_x(14, _dir), 30, 450), _cy - lengthdir_y(10, _dir), _label, _col);
            draw_set_valign(fa_bottom);
        }
    }
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}
