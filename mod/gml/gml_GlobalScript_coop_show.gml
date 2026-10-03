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
    var _c = coop();
    _c.sc_moving = false;
    if (!variable_struct_exists(_c, "sc_home"))
    {
        _c.sc_home = [obj_player.x, obj_player.y];
    }
    var _hx = _c.sc_home[0];
    var _hy = _c.sc_home[1];
    if (_c.role == "guest")
    {
        if (!coop_down_is_down())
        {
            // stroll: right, down, back
            if (_t > 60 && _t < 160) coop_show_walk_to(_hx + 60, _hy, 1.2);
            if (_t >= 160 && _t < 260) coop_show_walk_to(_hx + 60, _hy + 40, 1.2);
            if (_t >= 330 && _t < 420) coop_show_walk_to(_hx + 20, _hy + 50, 1.2);
            if (_t >= 260 && _t < 330 && _t mod 14 == 0) coop_show_shoot_nearest();
            if (_t >= 900 && _t < 1100) coop_show_walk_to(_hx + 120, _hy + 30, 1.2);
            if (_t >= 1000 && _t < 1100 && _t mod 16 == 0) coop_show_shoot_nearest();
        }
        else
        {
            coop_show_walk_to(_hx + 40, _hy + 60, 0.3); // crawl
        }
        if (_t == 440)
        {
            coop_log("show: guest down");
            obj_player.hp = 0;
        }
    }
    else
    {
        if (_t > 80 && _t < 180) coop_show_walk_to(_hx - 30, _hy + 20, 1.2);
        if (_t >= 200 && _t < 300 && _t mod 12 == 0) coop_show_shoot_nearest();
        var _p = coop_partner();
        if (coop_partner_is_down() && instance_exists(_p))
        {
            if (!variable_struct_exists(_c, "sc_rev_t"))
            {
                _c.sc_rev_t = -1;
            }
            if (_c.sc_rev_t < 0)
            {
                if (coop_show_walk_to(_p.x + 14, _p.y, 1.4))
                {
                    _c.sc_rev_t = _t;
                }
            }
            else
            {
                var _k = _t - _c.sc_rev_t;
                var _r = coop_revive();
                if (_k == 30) _c.sim_e = true;
                if (_r.menu && (_k == 70 || _k == 95 || _k == 120)) _r.sel = max(0, _r.sel - 1);
                if (_r.menu && (_k == 160 || _k == 180 || _k == 200)) _r.sel = min(array_length(_r.options) - 1, _r.sel + 1);
                if (_k == 240) _c.sim_e = true;
            }
        }
        if (variable_struct_exists(_c, "sc_rev_t") && _c.sc_rev_t >= 0 && !coop_partner_is_down())
        {
            if (_t >= 900 && _t < 1100) coop_show_walk_to(_hx + 100, _hy + 10, 1.2);
            if (_t >= 1000 && _t < 1100 && _t mod 12 == 0) coop_show_shoot_nearest();
        }
    }
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
