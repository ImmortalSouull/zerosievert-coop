// ZERO Sievert co-op: down / revive.
// - Lethal damage while the partner is in the raid puts you down instead of killing you.
// - Down #1: timer N s, may shoot a pistol. Down #2: timer N/2, no shooting. Down #3: death.
// - The timer pauses while the partner is reviving you. Counter resets at raid start.
// - Reviver picks: nothing / a bandage / a medkit. Time depends only on the category,
//   HP after revive depends on the exact item. Second down: HP x0.6.
// - Both players down at once: both die and the raid ends.

#macro COOP_DOWN_REVIVE_RANGE 30

function coop_t(_en, _ru)
{
    if (variable_global_exists("language_current") && global.language_current == "russian")
    {
        return _ru;
    }
    return _en;
}

function coop_down()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "down"))
    {
        _c.down = { active: false, count: 0, timer: 0, timer_max: 0, ping_time: -10000, force_death: false };
        _c.revive = { menu: false, sel: 0, options: [], active: false, t: 0, tmax: 0, opt: undefined, opened_frame: -1 };
    }
    return _c.down;
}

function coop_revive()
{
    coop_down();
    return coop().revive;
}

function coop_down_reset()
{
    var _d = coop_down();
    _d.active = false;
    _d.count = 0;
    _d.force_death = false;
    var _r = coop_revive();
    _r.menu = false;
    _r.active = false;
}

function coop_down_is_down()
{
    return coop_down().active;
}

function coop_partner_is_down()
{
    var _c = coop();
    if (variable_struct_exists(_c, "revived_at") && current_time - _c.revived_at < 1500)
    {
        return false; // we just revived them; their state packet may still say "down"
    }
    var _p = coop_partner();
    return instance_exists(_p) && variable_instance_exists(_p, "coop_flags") && (_p.coop_flags & 2) != 0;
}

function coop_down_can_happen()
{
    var _c = coop();
    return _c.connected && _c.peer_in_raid && coop_in_raid() && instance_exists(coop_partner()) && coop_setting("revive_enabled");
}

// Hook: top of player_step_grim_reaper() (runs in obj_player). true = death intercepted.
function coop_down_grim_reaper()
{
    if (hp > 0 || player_state_is(mp_index, scr_player_state_dead))
    {
        return false;
    }
    var _d = coop_down();
    if (_d.force_death)
    {
        _d.force_death = false;
        _d.active = false;
        return false;
    }
    if (_d.active)
    {
        hp = 1;
        return true;
    }
    if (!coop_down_can_happen())
    {
        return false;
    }
    if (_d.count >= 2)
    {
        coop_down_send(COOP_MSG_DEAD, 0);
        coop_log("third down: death");
        return false;
    }
    if (coop_partner_is_down())
    {
        coop_down_send(COOP_MSG_DEAD, 1);
        coop_notify(coop_t("Both of you are down - the raid is over", "Вы оба ранены - рейд окончен"));
        coop_log("both down: death for both");
        return false;
    }
    _d.count++;
    _d.active = true;
    var _n = coop_setting("down_seconds") * 60;
    _d.timer_max = (_d.count >= 2) ? round(_n / 2) : _n;
    _d.timer = _d.timer_max;
    hp = 1;
    bleed = 0;
    aiming = false;
    coop_down_send(COOP_MSG_DOWN, _d.count);
    coop_log("down #", _d.count, " timer ", _d.timer_max / 60, "s");
    return true;
}

function coop_down_send(_type, _arg)
{
    var _c = coop();
    if (!_c.connected)
    {
        exit;
    }
    coop_msg_begin(_type);
    buffer_write(_c.send_buf, buffer_u8, _arg);
    buffer_write(_c.send_buf, buffer_f32, 0);
    coop_msg_send(true);
}

function coop_down_on_message(_type, _b)
{
    var _arg = buffer_read(_b, buffer_u8);
    var _val = buffer_read(_b, buffer_f32);
    var _d = coop_down();
    switch (_type)
    {
        case COOP_MSG_DOWN:
            coop_notify(coop_t(coop().peer_name + " is down! Go to them and press [E]", coop().peer_name + " ранен! Подойдите и нажмите [E]"));
            break;
        case COOP_MSG_DEAD:
            coop_log("partner death message, both=", _arg);
            if (_arg == 1)
            {
                // Partner went down while we were down: both die.
                coop_down_force_death("both down");
                coop_notify(coop_t("Both of you are down - the raid is over", "Вы оба ранены - рейд окончен"));
            }
            else
            {
                coop_notify(coop_t(coop().peer_name + " died", coop().peer_name + " погиб"));
                coop_down_force_death("partner died, nobody can revive");
            }
            break;
        case COOP_MSG_REVIVE:
            if (_arg == 0)
            {
                _d.ping_time = current_time;
            }
            else if (_arg == 1 && _d.active && instance_exists(obj_player))
            {
                var _hp = _val * ((_d.count >= 2) ? coop_setting("second_down_hp_mult") : 1);
                _d.active = false;
                with (obj_player)
                {
                    hp = clamp(round(_hp), 1, hp_max);
                    shooting = false;
                    image_angle = 0;
                }
                coop_log("revived with ", round(_hp), " hp");
                coop_notify(coop_t("You were revived", "Вас подняли"));
            }
            break;
    }
}

// obj_coop Begin Step (before the player's own Step).
function coop_down_begin_step()
{
    var _d = coop_down();
    if (!_d.active || !instance_exists(obj_player))
    {
        exit;
    }
    with (obj_player)
    {
        var _pistol = item_exists(arma_now) && item_weapon_get_type(arma_now) == "pistol";
        if (!(_d.count == 1 && _pistol))
        {
            shooting = true; // blocks scr_shoot this frame
        }
        hp = max(hp, 1);
    }
}

// obj_coop Step.
function coop_down_step()
{
    var _d = coop_down();
    if (_d.active)
    {
        if (!instance_exists(obj_player) || !coop_in_raid())
        {
            _d.active = false;
            exit;
        }
        if (current_time - _d.ping_time > 400)
        {
            _d.timer--;
        }
        if (_d.timer <= 0)
        {
            coop_down_send(COOP_MSG_DEAD, 0);
            coop_down_force_death("down timer expired");
        }
        else if (!coop().peer_in_raid || !coop().connected)
        {
            coop_down_force_death("partner left the raid");
        }
    }
    coop_revive_step();
}

// obj_coop End Step: crawl (slow movement) and lying pose.
function coop_down_end_step()
{
    var _d = coop_down();
    if (instance_exists(obj_player))
    {
        with (obj_player)
        {
            if (_d.active)
            {
                x = xprevious + (x - xprevious) * 0.3;
                y = yprevious + (y - yprevious) * 0.3;
                image_angle = 90;
            }
            else if (image_angle == 90)
            {
                image_angle = 0;
            }
        }
    }
    var _p = coop_partner();
    if (instance_exists(_p) && variable_instance_exists(_p, "coop_flags"))
    {
        _p.image_angle = ((_p.coop_flags & 2) != 0) ? 90 : 0;
    }
}

// ---- reviver side ----

function coop_revive_options()
{
    var _out = [{ name: coop_t("No items", "Без предметов"), item: "", time: coop_setting("revive_time_none"), hp: 10 }];
    var _bandages = [["bandage", 20], ["anti_bleed_gel", 20], ["bandage_military", 25], ["bandage_sterilizzata", 30]];
    var _medkits = [["medikit_1", 35], ["med_wound_1", 35], ["medikit_long", 40], ["medikit_2", 45], ["med_wound_2", 45], ["medikit_3", 55]];
    for (var _i = 0; _i < array_length(_bandages); _i++)
    {
        if (inventory_item_exists(_bandages[_i][0]))
        {
            array_push(_out, { name: item_get_name(_bandages[_i][0]), item: _bandages[_i][0], time: coop_setting("revive_time_bandage"), hp: _bandages[_i][1] });
        }
    }
    for (var _i = 0; _i < array_length(_medkits); _i++)
    {
        if (inventory_item_exists(_medkits[_i][0]))
        {
            array_push(_out, { name: item_get_name(_medkits[_i][0]), item: _medkits[_i][0], time: coop_setting("revive_time_medkit"), hp: _medkits[_i][1] });
        }
    }
    return _out;
}

function coop_revive_in_range()
{
    var _p = coop_partner();
    if (!instance_exists(obj_player) || !instance_exists(_p) || coop_down_is_down())
    {
        return false;
    }
    if (!coop_partner_is_down() || !player_state_is(0, scr_player_state_move))
    {
        return false;
    }
    return point_distance(obj_player.x, obj_player.y, _p.x, _p.y) < COOP_DOWN_REVIVE_RANGE;
}

function coop_revive_step()
{
    var _r = coop_revive();
    var _c = coop();
    if (!coop_revive_in_range())
    {
        if (_r.active)
        {
            coop_down_send(COOP_MSG_REVIVE, 2);
            coop_notify(coop_t("Revive interrupted", "Поднятие прервано"));
        }
        _r.active = false;
        _r.menu = false;
        exit;
    }
    var _e = keyboard_check_pressed(ord("E"));
    if (variable_struct_exists(_c, "sim_e") && _c.sim_e)
    {
        _c.sim_e = false; // test scenario input
        _e = true;
    }
    if (!_r.menu && !_r.active && _e)
    {
        _r.options = coop_revive_options();
        _r.sel = array_length(_r.options) - 1; // best item preselected
        _r.menu = true;
        _r.opened_frame = _c.frame;
        exit;
    }
    if (_r.menu)
    {
        var _n = array_length(_r.options);
        if (mouse_wheel_up() || keyboard_check_pressed(vk_up)) _r.sel = (_r.sel - 1 + _n) mod _n;
        if (mouse_wheel_down() || keyboard_check_pressed(vk_down)) _r.sel = (_r.sel + 1) mod _n;
        if (keyboard_check_pressed(vk_backspace) || keyboard_check_pressed(vk_escape))
        {
            _r.menu = false;
            exit;
        }
        if (_e && _c.frame != _r.opened_frame)
        {
            _r.opt = _r.options[_r.sel];
            _r.menu = false;
            _r.active = true;
            _r.t = 0;
            _r.tmax = max(1, _r.opt.time * 60);
            coop_down_send(COOP_MSG_REVIVE, 0);
        }
        exit;
    }
    if (_r.active)
    {
        _r.t++;
        if (_r.t mod 10 == 0)
        {
            coop_down_send(COOP_MSG_REVIVE, 0);
        }
        if (_r.t >= _r.tmax)
        {
            _r.active = false;
            var _item = _r.opt.item;
            if (_item != "")
            {
                if (!inventory_item_exists(_item))
                {
                    coop_notify(coop_t("Item is gone", "Предмет пропал"));
                    exit;
                }
                inventory_remove_item(_item, 1);
            }
            _c.revived_at = current_time;
            var _pp = coop_partner();
            if (instance_exists(_pp))
            {
                _pp.coop_flags = _pp.coop_flags & ~2;
            }
            coop_msg_begin(COOP_MSG_REVIVE);
            buffer_write(_c.send_buf, buffer_u8, 1);
            buffer_write(_c.send_buf, buffer_f32, _r.opt.hp);
            coop_msg_send(true);
            coop_log("revived partner with ", _r.opt.name, " (", _r.opt.hp, " hp)");
            coop_notify(coop_t("Partner revived", "Напарник поднят"));
        }
    }
}

// Draw GUI. Drawn in an 800x450 GUI space so the game font comes out ~60% of the HUD size,
// keeping the middle of the screen (the player) free.
function coop_down_draw_gui()
{
    var _d = coop_down();
    var _r = coop_revive();
    var _W = 800;
    var _H = 450;
    display_set_gui_size(_W, _H);
    draw_set_valign(fa_middle);
    if (_d.active)
    {
        draw_set_alpha(0.15);
        draw_rectangle_colour(0, 0, _W, _H, c_maroon, c_maroon, c_maroon, c_maroon, false);
        draw_set_alpha(1);
        draw_set_halign(fa_center);
        var _sec = ceil(_d.timer / 60);
        coop_text_outlined(_W / 2, 330, coop_t("YOU ARE DOWN", "ВЫ ТЯЖЕЛО РАНЕНЫ") + "  " + string(_sec) + coop_t(" s", " с"), c_red);
        var _k = clamp(_d.timer / max(1, _d.timer_max), 0, 1);
        draw_set_alpha(0.7);
        draw_rectangle_colour(_W / 2 - 70, 342, _W / 2 + 70, 345, c_black, c_black, c_black, c_black, false);
        draw_set_alpha(1);
        draw_rectangle_colour(_W / 2 - 70, 342, _W / 2 - 70 + 140 * _k, 345, c_red, c_red, c_red, c_red, false);
        var _being = current_time - _d.ping_time < 400;
        var _line = _being ? coop_t("Your partner is helping you...", "Напарник поднимает вас...") : coop_t("Wait for your partner", "Ждите напарника");
        if (_d.count == 1 && !_being)
        {
            _line += coop_t(" · pistol only", " · можно стрелять из пистолета");
        }
        coop_text_outlined(_W / 2, 356, _line, _being ? c_lime : c_ltgray);
    }
    // Partner position on screen: the prompt / menu / progress sit next to them.
    var _p = coop_partner();
    var _gx = _W / 2;
    var _gy = _H / 2;
    if (instance_exists(_p))
    {
        var _cam = view_camera[0];
        _gx = (_p.x - camera_get_view_x(_cam)) / camera_get_view_width(_cam) * _W;
        _gy = (_p.y - camera_get_view_y(_cam)) / camera_get_view_height(_cam) * _H;
    }
    if (coop_revive_in_range() && !_r.menu && !_r.active)
    {
        draw_set_halign(fa_center);
        coop_text_outlined(_gx, _gy - 48, coop_t("[E] Revive", "[E] Поднять"), c_yellow);
    }
    if (_r.menu)
    {
        var _n = array_length(_r.options);
        var _rows = [];
        var _w = string_width(coop_t("Wheel/arrows, [E] - pick", "Колесо/стрелки, [E] - выбрать"));
        for (var _i = 0; _i < _n; _i++)
        {
            var _o = _r.options[_i];
            _rows[_i] = _o.name + "   " + string(_o.time) + coop_t(" s · ", " с · ") + string(_o.hp) + " HP";
            _w = max(_w, string_width(_rows[_i]) + 10);
        }
        var _lh = 13;
        var _bw = _w + 12;
        var _bh = (_n + 2) * _lh + 8;
        var _bx = clamp(_gx + 20, 4, _W - _bw - 4);
        var _by = clamp(_gy - _bh / 2, 4, _H - _bh - 60);
        draw_set_alpha(0.8);
        draw_rectangle_colour(_bx, _by, _bx + _bw, _by + _bh, c_black, c_black, c_black, c_black, false);
        draw_set_alpha(1);
        draw_rectangle_colour(_bx, _by, _bx + _bw, _by + _bh, c_dkgray, c_dkgray, c_dkgray, c_dkgray, true);
        draw_set_halign(fa_left);
        var _y = _by + 4 + _lh / 2;
        coop_text_outlined(_bx + 6, _y, coop_t("Revive with", "Чем поднять"), c_white);
        _y += _lh;
        for (var _i = 0; _i < _n; _i++)
        {
            var _sel = (_i == _r.sel);
            if (_sel)
            {
                draw_set_alpha(0.35);
                draw_rectangle_colour(_bx + 2, _y - _lh / 2, _bx + _bw - 2, _y + _lh / 2 - 1, c_olive, c_olive, c_olive, c_olive, false);
                draw_set_alpha(1);
            }
            coop_text_outlined(_bx + 6, _y, _rows[_i], _sel ? c_yellow : c_ltgray);
            _y += _lh;
        }
        coop_text_outlined(_bx + 6, _y, coop_t("Wheel/arrows, [E] - pick", "Колесо/стрелки, [E] - выбрать"), c_gray);
    }
    if (_r.active)
    {
        var _k2 = _r.t / _r.tmax;
        draw_set_halign(fa_center);
        coop_text_outlined(_gx, _gy - 54, coop_t("Reviving...", "Поднимаем..."), c_lime);
        draw_rectangle_colour(_gx - 30, _gy - 45, _gx + 30, _gy - 42, c_black, c_black, c_black, c_black, false);
        draw_rectangle_colour(_gx - 30, _gy - 45, _gx - 30 + 60 * _k2, _gy - 42, c_lime, c_lime, c_lime, c_lime, false);
    }
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    display_set_gui_size(480, 270);
}

function coop_text_outlined(_x, _y, _s, _col)
{
    draw_text_colour(_x + 1, _y + 1, _s, c_black, c_black, c_black, c_black, 1);
    draw_text_colour(_x, _y, _s, _col, _col, _col, _col, 1);
}

// AI targeting (replaces player_nearest_instance): downed players are ignored.
function coop_nearest_standing_player(_x, _y)
{
    var _best = -4;
    var _bd = infinity;
    with (obj_player_parent)
    {
        var _down = (object_index == obj_player) ? coop_down_is_down() : (variable_instance_exists(id, "coop_flags") && (coop_flags & 2) != 0);
        if (_down)
        {
            continue;
        }
        var _d = point_distance(_x, _y, x, y);
        if (_d < _bd)
        {
            _bd = _d;
            _best = id;
        }
    }
    return _best;
}

// Friendly fire between the two players (host rule).
function coop_friendly_fire_hit(_bull, _target)
{
    if (!coop_active() || !coop_setting("friendly_fire"))
    {
        return false;
    }
    return object_is_player(_bull.shooter_id) && _bull.shooter_id != _target.id;
}

// Kill the local player for real while down (the down clamp must stop first).
function coop_down_force_death(_why)
{
    var _d = coop_down();
    if (!_d.active || !instance_exists(obj_player))
    {
        exit;
    }
    coop_log("forced death: ", _why);
    _d.active = false;
    _d.force_death = true;
    with (obj_player)
    {
        image_angle = 0;
        hp = 0;
    }
}
