// ZERO Sievert co-op: watch teammates after the final death (2.0.0 item 9).
// Only after a real death (downs keep your own camera). On the death screen, while teammates are alive in the
// raid: F watches them - the death screen is hidden and paused (hooks [141]/[142]), the camera follows the chosen
// teammate (End Step, after the game's camera), A/D or the arrows switch, F or Esc goes back to the death screen
// (its Next button leads to the bunker as usual). Ends by itself when nobody is left to watch.

function coop_spec()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "spec"))
    {
        _c.spec = { on: false, slot: -1 };
    }
    return _c.spec;
}

function coop_spectating()
{
    if (!variable_global_exists("coop_state")) return false;
    var _c = global.coop_state;
    return variable_struct_exists(_c, "spec") && _c.spec.on;
}

// Teammates in our raid who are still alive, by slot.
function coop_spec_targets()
{
    var _out = [];
    var _l = coop_puppets();
    for (var _i = 0; _i < array_length(_l); _i++)
    {
        var _p = _l[_i];
        if (variable_instance_exists(_p, "coop_hp") && _p.coop_hp > 0)
        {
            array_push(_out, _p.coop_slot);
        }
    }
    array_sort(_out, true);
    return _out;
}

// Hook [141]: top of obj_exit_screen Step (self = the screen). true = skip the screen's Step this tick.
function coop_spectate_step(_screen)
{
    try
    {
        return coop_spectate_step_inner(_screen);
    }
    catch (_e)
    {
        coop_report_error(_e);
    }
    return false;
}

function coop_spectate_step_inner(_screen)
{
    var _c = coop();
    var _s = coop_spec();
    if (!_c.connected || _screen.survived || !coop_in_raid())
    {
        _s.on = false;
        return false;
    }
    var _t = coop_spec_targets();
    var _key = keyboard_check_pressed(ord("F")) || coop_pad_pressed(gp_face4) || (_c.test_mode && variable_struct_exists(_c, "sim_spec") && _c.sim_spec);
    if (_c.test_mode) _c.sim_spec = false;
    if (!_s.on)
    {
        if (_key && array_length(_t) > 0)
        {
            _s.on = true;
            _s.slot = _t[0];
            audio_master_gain(settings_get("master volume")); // the death screen faded the sound out
            coop_log("spectate: watching slot ", _s.slot);
        }
        return false;
    }
    if (_key || keyboard_check_pressed(vk_escape) || coop_pad_pressed(gp_face2) || array_length(_t) == 0)
    {
        _s.on = false;
        keyboard_clear(vk_escape);
        coop_log("spectate: back to the death screen");
        return false;
    }
    if (!array_contains(_t, _s.slot))
    {
        _s.slot = _t[0]; // the watched teammate died or left
    }
    var _dir = (keyboard_check_pressed(ord("D")) || keyboard_check_pressed(vk_right) || coop_pad_pressed(gp_padr) || coop_pad_pressed(gp_shoulderr))
        - (keyboard_check_pressed(ord("A")) || keyboard_check_pressed(vk_left) || coop_pad_pressed(gp_padl) || coop_pad_pressed(gp_shoulderl));
    if (_c.test_mode && variable_struct_exists(_c, "sim_spec_next") && _c.sim_spec_next) { _dir = 1; _c.sim_spec_next = false; }
    if (_dir != 0)
    {
        var _i = 0;
        for (var _k = 0; _k < array_length(_t); _k++) if (_t[_k] == _s.slot) _i = _k;
        _s.slot = _t[(_i + _dir + array_length(_t)) mod array_length(_t)];
        coop_log("spectate: switched to slot ", _s.slot);
    }
    return true;
}

// obj_coop End Step: the camera on the watched teammate (after obj_camera moved it).
function coop_spectate_end_step()
{
    var _s = coop_spec();
    if (!_s.on)
    {
        exit;
    }
    var _p = coop_puppet_of(_s.slot);
    if (!instance_exists(_p))
    {
        exit;
    }
    var _cam = view_camera[0];
    camera_set_view_size(_cam, 480, 270);
    camera_set_view_pos(_cam, _p.x - 240, _p.y - 135);
}

// Draw GUI: the prompt on the death screen / the spectator banner.
function coop_spectate_draw()
{
    var _c = coop();
    if (!_c.connected || !instance_exists(obj_exit_screen) || obj_exit_screen.survived)
    {
        exit;
    }
    var _s = coop_spec();
    coop_ui_font(COOP_F_BODY);
    draw_set_halign(fa_center);
    if (_s.on)
    {
        var _txt = coop_tf("Watching {0}  -  A / D: switch,  F: back", "Наблюдение: {0}  -  A / D: другой игрок,  F: назад", coop_peer_name(_s.slot));
        if (instance_exists(obj_gamepad) && !obj_gamepad.last_input_keyboard)
        {
            _txt = coop_tf("Watching {0}  -  LB / RB: switch,  B: back", "Наблюдение: {0}  -  LB / RB: другой игрок,  B: назад", coop_peer_name(_s.slot));
        }
        var _w = string_width(_txt) / 2 + 20;
        coop_ui_rect(COOP_GW / 2 - _w, 40, COOP_GW / 2 + _w, 88, c_black, 0.7);
        coop_ui_rect(COOP_GW / 2 - _w, 85, COOP_GW / 2 + _w, 88, coop_slot_colour(_s.slot));
        coop_ui_text(COOP_GW / 2, 50, _txt, COOP_C_TEXT);
    }
    else if (array_length(coop_spec_targets()) > 0)
    {
        var _pad = instance_exists(obj_gamepad) && !obj_gamepad.last_input_keyboard;
        coop_ui_text_ol(COOP_GW / 2, COOP_GH - 300, _pad ? coop_t("Y - watch your teammates", "Y - смотреть за напарниками") : coop_t("F - watch your teammates", "F - смотреть за напарниками"), COOP_C_KEY);
    }
    draw_set_halign(fa_left);
}
