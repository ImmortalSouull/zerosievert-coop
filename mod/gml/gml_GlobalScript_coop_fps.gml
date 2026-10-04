// ZERO Sievert co-op: high refresh rate without changing the game's speed.
//
// The game's simulation is frame based: every speed, timer and alarm is tuned for 60 steps per second, so
// simply raising the game speed would make everything run faster. Instead the runner goes at the monitor's
// rate and the simulation stays at exactly 60 logic ticks per second:
//  - every frame is classified as a logic frame or a render-only frame (zs_rf_q, first call of the frame);
//  - on render-only frames every Step / Collision / held-input event of the game exits at once (a guard is
//    prepended to those events by build.csx), alarms are held, paths and built-in motion are frozen and
//    particle systems are not advanced;
//  - a frame that brings a fresh key/mouse/gamepad press or release is always a logic frame, so no input
//    is lost;
//  - moving instances and the camera are drawn interpolated between the last two logic ticks (one tick of
//    visual delay, the usual fixed-timestep technique), then restored before the next logic runs.

#macro ZS_TICK_US 16666.6667

global.zs_rfq = false; // frame not classified yet (only while the feature is on)
global.zs_rf = false;  // this frame is render-only

function zs_fps()
{
    if (!variable_global_exists("zs_fps_state"))
    {
        global.zs_fps_state = {
            on: false,
            mode: 0,            // index into zs_fps_modes()
            target: 60,
            acc: 0,
            last_us: get_timer(),
            decided: true,
            decided_us: 0,
            tick_us: get_timer(),
            tick_prev_us: get_timer(),
            logic_dt: ZS_TICK_US,
            was_rf: false,
            moved: [],
            held_alarm: [],
            held_motion: [],
            swapped: [],
            wh: [],
            nswapped: 0,
            cam_ok: false,
            cam_px: 0, cam_py: 0, cam_cx: 0, cam_cy: 0, cam_live_x: 0, cam_live_y: 0, cam_swapped: false,
            parts_paused: false,
            stat_frames: 0, stat_ticks: 0, stat_t0: get_timer(), stat_hold_us: 0, stat_scan_us: 0, stat_interp_us: 0,
            stat_moved: 0, stat_inst: 0, stat_held: 0
        };
        zs_fps_load();
    }
    return global.zs_fps_state;
}

// 0 = monitor refresh rate, then fixed caps. 60 = vanilla behaviour (feature off).
function zs_fps_modes()
{
    return [0, 60, 120, 144, 165, 240, 360];
}

function zs_fps_mode_label(_mode)
{
    var _modes = zs_fps_modes();
    var _v = _modes[_mode];
    if (_v == 0)
    {
        return coop_t("monitor (", "как монитор (") + string(zs_fps_monitor_hz()) + ")";
    }
    if (_v == 60)
    {
        return coop_t("60 (original)", "60 (как в оригинале)");
    }
    return string(_v);
}

function zs_fps_monitor_hz()
{
    var _hz = display_get_frequency();
    if (_hz < 30 || _hz > 1000)
    {
        _hz = 60;
    }
    return _hz;
}

function zs_fps_load()
{
    var _f = global.zs_fps_state;
    ini_open("coop_local.ini");
    _f.mode = clamp(ini_read_real("video", "fps_mode", 0), 0, array_length(zs_fps_modes()) - 1);
    ini_close();
}

function zs_fps_save()
{
    var _f = zs_fps();
    ini_open("coop_local.ini");
    ini_write_real("video", "fps_mode", _f.mode);
    ini_close();
}

function zs_fps_cycle()
{
    var _f = zs_fps();
    _f.mode = (_f.mode + 1) mod array_length(zs_fps_modes());
    zs_fps_save();
    zs_fps_apply();
}

// Called on boot and whenever the mode changes.
function zs_fps_apply()
{
    var _f = zs_fps();
    var _modes = zs_fps_modes();
    var _v = _modes[_f.mode];
    var _target = (_v == 0) ? zs_fps_monitor_hz() : _v;
    var _c = coop();
    if (variable_struct_exists(_c, "fps_force"))
    {
        _target = _c.fps_force; // test mode
    }
    _f.target = _target;
    var _on = _target > 60;
    if (_on != _f.on)
    {
        _f.on = _on;
        _f.acc = 0;
        _f.last_us = get_timer();
        _f.decided = true;
        global.zs_rf = false;
        global.zs_rfq = false;
        zs_fps_particles(true);
        if (_on)
        {
            _f.decided = false;
            global.zs_rfq = true;
        }
    }
    game_set_speed(_target, gamespeed_fps);
    coop_log("fps: target ", _target, " (mode ", _f.mode, "), decoupled=", _on, " monitor=", zs_fps_monitor_hz());
}

// Guard prepended to the game's logic events: true = this is a render-only frame, skip the event.
function zs_rf_q()
{
    var _f = global.zs_fps_state;
    if (_f.decided)
    {
        return global.zs_rf;
    }
    _f.decided = true;
    var _now = get_timer();
    _f.decided_us = _now;
    _f.acc += _now - _f.last_us;
    _f.last_us = _now;
    if (_f.acc >= ZS_TICK_US || zs_fps_input_event())
    {
        // logic frame
        _f.acc -= ZS_TICK_US;
        // behind (frame rate under 60): drop the debt like the vanilla game slows down instead of
        // fast-forwarding; ahead (input forced an early tick): never more than one tick early
        _f.acc = clamp(_f.acc, -ZS_TICK_US, ZS_TICK_US);
        global.zs_rf = false;
        global.zs_rfq = false;
        _f.tick_prev_us = _f.tick_us;
        _f.tick_us = _now;
        _f.logic_dt = clamp(_now - _f.tick_prev_us, 1000, 100000);
        _f.stat_ticks++;
        if (_f.was_rf)
        {
            _f.was_rf = false;
            zs_fps_particles(true);
        }
        return false;
    }
    global.zs_rf = true;
    if (!_f.was_rf)
    {
        _f.was_rf = true;
        zs_fps_particles(false);
    }
    return true;
}

// A fresh press/release must reach the game's logic in the very frame it happens.
function zs_fps_input_event()
{
    if (keyboard_check_pressed(vk_anykey) || keyboard_check_released(vk_anykey))
    {
        return true;
    }
    if (mouse_check_button_pressed(mb_any) || mouse_check_button_released(mb_any) || mouse_wheel_up() || mouse_wheel_down())
    {
        return true;
    }
    var _n = gamepad_get_device_count();
    for (var _d = 0; _d < _n; _d++)
    {
        if (gamepad_is_connected(_d))
        {
            for (var _b = gp_face1; _b <= gp_padr; _b++)
            {
                if (gamepad_button_check_pressed(_d, _b) || gamepad_button_check_released(_d, _b))
                {
                    return true;
                }
            }
        }
    }
    return false;
}

// Microseconds of game time one logic tick represents (replaces delta_time in the game's clock code).
function zs_logic_dt()
{
    var _f = zs_fps();
    return _f.on ? _f.logic_dt : delta_time;
}

// Particle systems advance once per runner frame: pause them on render-only frames.
function zs_fps_particles(_run)
{
    var _f = zs_fps();
    if (_f.parts_paused == !_run)
    {
        exit;
    }
    _f.parts_paused = !_run;
    for (var _i = 0; _i < 512; _i++)
    {
        if (part_system_exists(_i))
        {
            part_system_automatic_update(_i, _run);
        }
    }
}

// obj_coop Begin Step (first thing). On render-only frames hold alarms, paths and built-in motion.
function zs_fps_begin_step()
{
    var _f = zs_fps();
    if (!_f.on)
    {
        exit;
    }
    // safety net: a frame without our draw events (minimised window...) never re-armed the classifier
    if (!global.zs_rfq && _f.decided && !global.zs_rf && get_timer() - _f.decided_us > 50000)
    {
        _f.decided = false;
        global.zs_rfq = true;
    }
    if (global.zs_rfq)
    {
        zs_rf_q();
    }
    if (!global.zs_rf)
    {
        exit;
    }
    var _t0 = get_timer();
    // alarms count down every runner frame: add the frame back on render-only frames
    var _tab = zs_fps_alarm_table();
    var _n = array_length(_tab);
    for (var _i = 0; _i < _n; _i++)
    {
        var _idx = _tab[_i][1];
        var _ni = array_length(_idx);
        with (_tab[_i][0])
        {
            for (var _k = 0; _k < _ni; _k++)
            {
                var _a = _idx[_k];
                if (alarm[_a] > 0)
                {
                    alarm[_a] += 1;
                }
            }
        }
    }
    // paths and built-in motion (speed/hspeed/vspeed): freeze until End Step
    var _held = _f.held_motion;
    array_resize(_held, 0);
    with (obj_npc_parent)
    {
        if (path_index != -1 && path_speed != 0)
        {
            array_push(_held, [id, 0, path_speed, 0]);
            path_speed = 0;
        }
        else if (speed != 0)
        {
            array_push(_held, [id, 1, hspeed, vspeed]);
            speed = 0;
        }
    }
    with (obj_bullet_shell)
    {
        if (speed != 0)
        {
            array_push(_held, [id, 1, hspeed, vspeed]);
            speed = 0;
        }
    }
    _f.stat_hold_us += get_timer() - _t0;
    _f.stat_held += array_length(_held);
}

// obj_coop End Step (first thing): give back what Begin Step froze.
function zs_fps_end_step()
{
    var _f = zs_fps();
    var _held = _f.held_motion;
    var _n = array_length(_held);
    if (_n == 0)
    {
        exit;
    }
    for (var _i = 0; _i < _n; _i++)
    {
        var _e = _held[_i];
        var _inst = _e[0];
        if (instance_exists(_inst))
        {
            if (_e[1] == 0)
            {
                _inst.path_speed = _e[2];
            }
            else
            {
                _inst.hspeed = _e[2];
                _inst.vspeed = _e[3];
            }
        }
    }
    array_resize(_held, 0);
}

// obj_coop Pre-Draw: after a logic tick remember who moved; every frame draw them interpolated.
function zs_fps_pre_draw()
{
    var _f = zs_fps();
    if (!_f.on)
    {
        exit;
    }
    _f.stat_frames++;
    var _t0 = get_timer();
    var _cam = view_camera[0];
    if (!global.zs_rf)
    {
        // logic frame: xprevious/yprevious hold the position before this tick's logic
        var _moved = _f.moved;
        array_resize(_moved, 0);
        var _cnt = 0;
        with (all)
        {
            _cnt++;
            if (x != xprevious || y != yprevious)
            {
                array_push(_moved, id, xprevious, yprevious);
            }
        }
        _f.stat_inst = _cnt;
        _f.stat_moved += array_length(_moved) / 3;
        var _cx = camera_get_view_x(_cam);
        var _cy = camera_get_view_y(_cam);
        if (_f.cam_ok)
        {
            _f.cam_px = _f.cam_cx;
            _f.cam_py = _f.cam_cy;
        }
        else
        {
            _f.cam_px = _cx;
            _f.cam_py = _cy;
            _f.cam_ok = true;
        }
        _f.cam_cx = _cx;
        _f.cam_cy = _cy;
        if (abs(_f.cam_cx - _f.cam_px) + abs(_f.cam_cy - _f.cam_py) > 160)
        {
            _f.cam_px = _f.cam_cx;
            _f.cam_py = _f.cam_cy;
        }
        _f.stat_scan_us += get_timer() - _t0;
    }
    var _t1 = get_timer();
    var _alpha = clamp((get_timer() - _f.tick_us) / ZS_TICK_US, 0, 1);
    // the swap list: [inst, live x, live y] for every instance drawn somewhere else this frame
    var _sw = _f.swapped;
    var _ns = 0;
    var _m = _f.moved;
    var _nm = array_length(_m);
    if (_alpha < 1)
    {
        for (var _i = 0; _i < _nm; _i += 3)
        {
            var _inst = _m[_i];
            if (!instance_exists(_inst))
            {
                continue;
            }
            var _px = _m[_i + 1];
            var _py = _m[_i + 2];
            var _lx = _inst.x;
            var _ly = _inst.y;
            if (abs(_lx - _px) + abs(_ly - _py) > 128)
            {
                continue; // teleport / spawn jump: draw where it is
            }
            _sw[_ns] = _inst;
            _sw[_ns + 1] = _lx;
            _sw[_ns + 2] = _ly;
            _ns += 3;
            _inst.x = _px + (_lx - _px) * _alpha;
            _inst.y = _py + (_ly - _py) * _alpha;
        }
    }
    _f.nswapped = _ns;
    // the player's weapon is a struct positioned in Step from the player: move it with the drawn body
    var _wh = _f.wh;
    array_resize(_wh, 0);
    if (_ns > 0)
    {
        for (var _i = 0; _i < _ns; _i += 3)
        {
            var _inst = _sw[_i];
            if (_inst.object_index == obj_player || _inst.object_index == obj_player_puppet)
            {
                var _w = _inst.weapon_holder;
                if (is_struct(_w))
                {
                    var _dx = _inst.x - _sw[_i + 1];
                    var _dy = _inst.y - _sw[_i + 2];
                    _w.x += _dx;
                    _w.y += _dy;
                    array_push(_wh, _w, _dx, _dy);
                }
            }
        }
    }
    // camera: only when nothing else moved it since the last tick (pause menu, cutscenes set it directly)
    _f.cam_swapped = false;
    var _lx = camera_get_view_x(_cam);
    var _ly = camera_get_view_y(_cam);
    if (_f.cam_ok && _lx == _f.cam_cx && _ly == _f.cam_cy && _alpha < 1)
    {
        _f.cam_swapped = true;
        _f.cam_live_x = _lx;
        _f.cam_live_y = _ly;
        camera_set_view_pos(_cam, _f.cam_px + (_lx - _f.cam_px) * _alpha, _f.cam_py + (_ly - _f.cam_py) * _alpha);
    }
    _f.stat_interp_us += get_timer() - _t1;
}

// obj_coop Draw GUI End: put live positions back, arm the classifier for the next frame.
function zs_fps_post_draw()
{
    var _f = zs_fps();
    var _sw = _f.swapped;
    var _ns = _f.nswapped;
    for (var _i = 0; _i < _ns; _i += 3)
    {
        var _inst = _sw[_i];
        if (instance_exists(_inst))
        {
            _inst.x = _sw[_i + 1];
            _inst.y = _sw[_i + 2];
        }
    }
    _f.nswapped = 0;
    var _wh = _f.wh;
    var _nw = array_length(_wh);
    for (var _i = 0; _i < _nw; _i += 3)
    {
        _wh[_i].x -= _wh[_i + 1];
        _wh[_i].y -= _wh[_i + 2];
    }
    array_resize(_wh, 0);
    if (_f.cam_swapped)
    {
        _f.cam_swapped = false;
        camera_set_view_pos(view_camera[0], _f.cam_live_x, _f.cam_live_y);
    }
    if (_f.on)
    {
        _f.decided = false;
        global.zs_rf = false;
        global.zs_rfq = true;
        var _now = get_timer();
        if (_now - _f.stat_t0 > 5000000)
        {
            var _secs = (_now - _f.stat_t0) / 1000000;
            var _fr = max(1, _f.stat_frames);
            var _tk = max(1, _f.stat_ticks);
            coop_log("fps: frames/s=", round(_f.stat_frames / _secs), " ticks/s=", round(_f.stat_ticks / _secs),
                " fps_real=", round(fps_real), " inst=", _f.stat_inst, " moved/tick=", round(_f.stat_moved / _tk),
                " held/rframe=", round(_f.stat_held / max(1, _f.stat_frames - _f.stat_ticks)),
                " us: hold=", round(_f.stat_hold_us / max(1, _f.stat_frames - _f.stat_ticks)),
                " scan=", round(_f.stat_scan_us / _tk), " interp=", round(_f.stat_interp_us / _fr));
            _f.stat_t0 = _now;
            _f.stat_frames = 0;
            _f.stat_ticks = 0;
            _f.stat_hold_us = 0;
            _f.stat_scan_us = 0;
            _f.stat_interp_us = 0;
            _f.stat_moved = 0;
            _f.stat_held = 0;
        }
    }
}
