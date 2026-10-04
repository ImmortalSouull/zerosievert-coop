// ZERO Sievert co-op: status line, notifications, down/revive UI and F7 panel.
// Everything is drawn in the game's 480x270 GUI space with the current language font (Cyrillic etc.).

function coop_draw_gui()
{
    var _c = coop();
    // nothing to draw (solo play, no notifications): leave the GUI state alone
    if (_c.role == "none" && array_length(_c.notes) == 0 && !(_c.test_mode && _c.overlay) && room != r_hub && room != r_menu && !coop_in_raid())
    {
        exit;
    }
    if (_c.role == "none" && array_length(_c.notes) == 0 && !(_c.test_mode && _c.overlay) && coop_in_raid() && !coop_down_is_down())
    {
        exit;
    }
    var _fonts = variable_global_exists("language_fonts") && is_array(global.language_fonts) && font_exists(global.language_fonts[1]);
    display_set_gui_size(480, 270);
    if (_fonts)
    {
        language_set_font(1);
    }
    else
    {
        draw_set_font(-1);
    }
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    var _x = 4;
    var _y = 30;
    var _lh = 11;
    if (_c.role != "none")
    {
        // rebuilt only when something in it changes (this runs every frame)
        var _key = _c.role + _c.transport + string(_c.connected) + _c.peer_name + string(round(_c.ping));
        if (!variable_struct_exists(_c, "hud_key") || _c.hud_key != _key)
        {
            var _txt = coop_t("CO-OP ", "КООП ") + ((_c.role == "host") ? coop_t("host", "хост") : coop_t("guest", "гость")) + " [" + _c.transport + "] ";
            if (_c.connected)
            {
                _txt += "- " + _c.peer_name + "  " + string(round(_c.ping)) + coop_t(" ms", " мс");
            }
            else
            {
                _txt += (_c.role == "guest") ? coop_t("- connecting...", "- подключение...") : coop_t("- waiting for partner", "- ждём напарника");
            }
            _c.hud_key = _key;
            _c.hud_txt = _txt;
        }
        coop_text_outlined(_x, _y, _c.hud_txt, c_lime);
        _y += _lh;
    }
    var _i = 0;
    while (_i < array_length(_c.notes))
    {
        var _n = _c.notes[_i];
        if (current_time > _n.t_end)
        {
            array_delete(_c.notes, _i, 1);
            continue;
        }
        coop_text_outlined(_x, _y, _n.text, c_yellow);
        _y += _lh;
        _i++;
    }
    if (_c.test_mode && _c.overlay)
    {
        draw_set_font(-1);
        display_set_gui_size(960, 540);
        var _ty = _y * 2 + 4;
        for (var _j = 0; _j < array_length(_c.log_lines); _j++)
        {
            draw_text_colour(8, _ty, _c.log_lines[_j], c_white, c_white, c_white, c_white, 0.8);
            _ty += 13;
        }
        display_set_gui_size(480, 270);
        if (_fonts)
        {
            language_set_font(1);
        }
    }
    if (coop_in_raid())
    {
        if (instance_exists(obj_player))
        {
            coop_puppet_draw_tag_gui();
        }
        coop_down_draw_gui();
    }
    else if (_c.role == "none" && (room == r_hub || room == r_menu) && !(variable_struct_exists(_c, "panel") && _c.panel))
    {
        draw_set_halign(fa_right);
        coop_text_outlined(474, 4, coop_t("[F7] Co-op", "[F7] Кооператив"), c_lime);
        draw_set_halign(fa_left);
    }
    draw_set_font(-1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    display_set_gui_size(1920, 1080);
}

// Draw GUI End: the F7 panel goes over everything the game draws in its GUI (interaction prompts...).
function coop_draw_gui_end()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "panel") || !_c.panel)
    {
        exit;
    }
    display_set_gui_size(480, 270);
    if (variable_global_exists("language_fonts") && is_array(global.language_fonts) && font_exists(global.language_fonts[1]))
    {
        language_set_font(1);
    }
    else
    {
        draw_set_font(-1);
    }
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    coop_panel_draw();
    draw_set_font(-1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    display_set_gui_size(1920, 1080);
}
