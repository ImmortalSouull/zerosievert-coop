// ZERO Sievert co-op: status line, notifications, down/revive UI and F7 panel.
// Everything is drawn in the game's 480x270 GUI space with the current language font (Cyrillic etc.).

function coop_draw_gui()
{
    var _c = coop();
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
        var _txt = coop_t("CO-OP ", "КООП ") + ((_c.role == "host") ? coop_t("host", "хост") : coop_t("guest", "гость")) + " [" + _c.transport + "] ";
        if (_c.connected)
        {
            _txt += "- " + _c.peer_name + "  " + string(round(_c.ping)) + coop_t(" ms", " мс");
        }
        else
        {
            _txt += (_c.role == "guest") ? coop_t("- connecting...", "- подключение...") : coop_t("- waiting for partner", "- ждём напарника");
        }
        coop_text_outlined(_x, _y, _txt, c_lime);
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
        coop_down_draw_gui();
    }
    else if (_c.role == "none" && (room == r_hub || room == r_menu) && !(variable_struct_exists(_c, "panel") && _c.panel))
    {
        draw_set_halign(fa_right);
        coop_text_outlined(474, 4, coop_t("[F7] Co-op", "[F7] Кооператив"), c_lime);
        draw_set_halign(fa_left);
    }
    coop_panel_draw();
    draw_set_font(-1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    display_set_gui_size(1920, 1080);
}
