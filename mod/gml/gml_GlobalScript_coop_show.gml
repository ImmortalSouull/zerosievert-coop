// ZERO Sievert co-op: scripted showcase take (test mode, -coop_scenario show). Not used in normal play.

function coop_show_walk_to(_tx, _ty, _spd)
{
    with (obj_player)
    {
        var _d = point_distance(x, y, _tx, _ty);
        if (_d < 2)
        {
            return true;
        }
        var _dir = point_direction(x, y, _tx, _ty);
        var _nx = x + lengthdir_x(min(_spd, _d), _dir);
        var _ny = y + lengthdir_y(min(_spd, _d), _dir);
        if (!place_meeting(_nx, _ny, obj_solid))
        {
            x = _nx;
            y = _ny;
        }
        coop().sc_moving = true;
        aim_point_x = x + lengthdir_x(40, _dir);
        aim_point_y = y + lengthdir_y(40, _dir);
    }
    return false;
}

// Put the player on the nearest free spot around (x, y) (never inside a wall: the game shows "you are stuck").
function coop_show_place(_x, _y)
{
    with (obj_player)
    {
        for (var _r = 0; _r <= 96; _r += 6)
        {
            for (var _a = 0; _a < 360; _a += 30)
            {
                var _nx = _x + lengthdir_x(_r, _a);
                var _ny = _y + lengthdir_y(_r, _a);
                if (!place_meeting(_nx, _ny, obj_solid)) { x = _nx; y = _ny; return; }
                if (_r == 0) break;
            }
        }
    }
}

function coop_show_shoot_nearest()
{
    with (obj_player)
    {
        if (!item_exists(arma_now) || item_get_category(arma_now) != "weapon")
        {
            exit;
        }
        var _dir = (coop().role == "host") ? 0 : 180;
        var _e = instance_nearest(x, y, obj_npc_parent);
        if (instance_exists(_e) && point_distance(x, y, _e.x, _e.y) < 260)
        {
            _dir = point_direction(x, y, _e.x, _e.y);
        }
        aim_point_x = x + lengthdir_x(60, _dir);
        aim_point_y = y + lengthdir_y(60, _dir);
        weapon_pointing_direction = _dir;
        scr_shoot(_dir, 1, item_weapon_get_damage(arma_now), 2);
    }
}

function coop_show_hub_step(_t)
{
    var _c = coop();
    if (_c.role == "host")
    {
        if (_t == 20) { _c.panel = true; _c.ip_edit = false; _c.last_ip = "127.0.0.1"; }
        if (_t == 200) _c.panel = false;
        if (_t >= 230 && !_c.autoraid_done && _c.connected && _c.peer_hub_ready)
        {
            _c.autoraid_done = true;
            go_to_map(1);
        }
    }
}

function coop_show_raid_step(_t)
{
    // 2.0.0 showcase timeline (60 ticks = 1 s): ping, command wheel, chat, voice, down / crawl / revive, radio
    var _c = coop();
    _c.sc_moving = false;
    if (!variable_struct_exists(_c, "sc_home"))
    {
        _c.sc_home = [obj_player.x, obj_player.y];
        var _v = coop_voice();
        _v.mode = 1;
    }
    var _hx = _c.sc_home[0];
    var _hy = _c.sc_home[1];
    var _v = coop_voice();
    if (_c.role == "guest")
    {
        // start next to the host (its spawn may move once its map is in)
        if (_t == 30 || _t == 50)
        {
            var _h = coop_puppet_of(0);
            if (instance_exists(_h)) { coop_show_place(_h.x + 40, _h.y + 10); _c.sc_home = [obj_player.x, obj_player.y]; _hx = _c.sc_home[0]; _hy = _c.sc_home[1]; }
        }
        if (!coop_down_is_down())
        {
            if (_t > 60 && _t < 200) coop_show_walk_to(_hx + 70, _hy + 10, 1.2);
            if (_t >= 200 && _t < 300) coop_show_walk_to(_hx + 70, _hy + 50, 1.2);
            if (_t >= 560 && _t < 660 && _t mod 14 == 0) coop_show_shoot_nearest();
            if (_t >= 1500 && _t < 1700) coop_show_walk_to(_hx + 140, _hy + 30, 1.2);
        }
        else
        {
            if (_t < 1130) coop_show_walk_to(obj_player.x + 20, obj_player.y + 20, 0.3); // crawl a little, then wait for help
        }
        if (_t == 420) coop_chat_send("On my way!");
        // voice: a tone stands in for the microphone (the speaking mark over the name tag)
        if (_t == 700) _c.voice_test_tone = 0;
        if (_t == 940) variable_struct_remove(_c, "voice_test_tone");
        if (_t == 1000) { coop_log("show: guest down"); obj_player.hp = 0; }
        if (_t == 1780) { _c.sim_wheel = true; coop_wheel().page = 1; _c.sim_wheel_dir = 90; }
        if (_t == 1840) _c.sim_wheel = false;
        if (_t == 1900) { variable_struct_remove(_c, "sim_wheel_dir"); }
    }
    else
    {
        if (_t == 60) { _c.sc_home = [obj_player.x, obj_player.y]; _hx = obj_player.x; _hy = obj_player.y; }
        if (_t > 80 && _t < 180) coop_show_walk_to(_hx - 30, _hy + 20, 1.2);
        if (_t == 200) { _c.sim_ping_at = [_hx + 160, _hy - 40]; _c.sim_ping = true; }
        if (_t == 260) { _c.sim_wheel = true; coop_wheel().page = 0; _c.sim_wheel_dir = 90; }
        if (_t == 330) _c.sim_wheel = false;
        if (_t == 340) variable_struct_remove(_c, "sim_wheel_dir");
        if (_t == 380) coop_chat_send("Contact! Bandits to the east");
        if (_t >= 520 && _t < 640 && _t mod 12 == 0) coop_show_shoot_nearest();
        var _p = coop_test_partner();
        if (_t mod 120 == 0) coop_log("show: t=", _t, " partner down=", coop_partner_is_down(), " p=", instance_exists(_p), instance_exists(_p) ? " rev_t=" + string(variable_struct_exists(_c, "sc_rev_t") ? _c.sc_rev_t : -9) + " d=" + string(floor(point_distance(obj_player.x, obj_player.y, _p.x, _p.y))) : "");
        if (coop_partner_is_down() && instance_exists(_p))
        {
            if (!variable_struct_exists(_c, "sc_rev_t")) _c.sc_rev_t = -1;
            if (_c.sc_rev_t < 0)
            {
                if (!variable_struct_exists(_c, "sc_go_t")) _c.sc_go_t = _t;
                if (point_distance(obj_player.x, obj_player.y, _p.x, _p.y) > 140) coop_show_place(_p.x + 60, _p.y);
                // walk over; a wall in the way: step next to them after 1.5 s
                if (_t - _c.sc_go_t > 90) coop_show_place(_p.x + 12, _p.y);
                if (coop_show_walk_to(_p.x + 14, _p.y, 1.4) || point_distance(obj_player.x, obj_player.y, _p.x, _p.y) < 24) _c.sc_rev_t = _t;
            }
            else
            {
                var _k = _t - _c.sc_rev_t;
                var _r = coop_revive();
                if (_k == 30) { _c.sim_e = true; coop_log("show: host presses E, target ", coop_revive_target(), " state move ", player_state_is(0, scr_player_state_move)); }
                if (_k == 60) coop_log("show: menu ", _r.menu, " active ", _r.active);
                if (_r.menu && (_k == 60 || _k == 80)) _r.sel = max(0, _r.sel - 1);
                if (_r.menu && (_k == 100 || _k == 120)) _r.sel = min(array_length(_r.options) - 1, _r.sel + 1);
                if (_k == 140) _c.sim_e = true;
            }
        }
        // the radio: raised in hand, channel 3, talking
        if (_t == 1450) { if (!coop_radio_have()) inventory_add_item(COOP_RADIO_ITEM, 1); _v.channel = 3; _c.radio_hand = true; }
        if (_t == 1500) _c.voice_test_tone = 0;
        if (_t == 1800) variable_struct_remove(_c, "voice_test_tone");
        if (_t >= 1520 && _t < 1700) coop_show_walk_to(_hx + 120, _hy + 10, 1.2);
    }
    if (_t == 2000) coop_log("show: done");
}

// End Step: running animation while the scripted walk moves the player.
function coop_show_end_step()
{
    var _c = coop();
    if (_c.scenario != "show" || !instance_exists(obj_player))
    {
        exit;
    }
    if (variable_struct_exists(_c, "sc_moving") && _c.sc_moving)
    {
        with (obj_player)
        {
            if (!coop_down_is_down())
            {
                sprite_index = sprite_run;
            }
            image_index += 0.25;
        }
    }
}
