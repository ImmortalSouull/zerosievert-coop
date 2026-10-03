// ZERO Sievert co-op: status overlay and notifications.

function coop_draw_gui()
{
    var _c = coop();
    display_set_gui_size(960, 540);
    draw_set_font(-1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    var _x = 8;
    var _y = 58;
    if (_c.role != "none")
    {
        var _txt = "CO-OP " + string_upper(_c.role) + " [" + _c.transport + "] ";
        if (_c.connected)
        {
            _txt += "- " + _c.peer_name + "  ping " + string(round(_c.ping)) + "ms";
            if (_c.peer_in_raid) _txt += "  (in raid)";
        }
        else
        {
            _txt += (_c.role == "guest") ? "- connecting..." : "- waiting for partner";
        }
        draw_set_alpha(0.55);
        draw_rectangle_colour(_x - 4, _y - 2, _x + string_width(_txt) + 4, _y + string_height(_txt) + 2, c_black, c_black, c_black, c_black, false);
        draw_set_alpha(1);
        draw_text_colour(_x, _y, _txt, c_lime, c_lime, c_lime, c_lime, 1);
        _y += string_height(_txt) + 6;
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
        draw_text_colour(_x, _y, _n.text, c_yellow, c_yellow, c_yellow, c_yellow, 1);
        _y += string_height(_n.text) + 2;
        _i++;
    }
    if (_c.test_mode)
    {
        for (var _j = 0; _j < array_length(_c.log_lines); _j++)
        {
            draw_text_colour(_x, _y, _c.log_lines[_j], c_white, c_white, c_white, c_white, 0.8);
            _y += string_height(_c.log_lines[_j]);
        }
    }
    if (coop_in_raid() && variable_global_exists("language_fonts") && is_array(global.language_fonts) && font_exists(global.language_fonts[1]))
    {
        display_set_gui_size(480, 270);
        language_set_font(1);
        coop_down_draw_gui();
        draw_set_font(-1);
    }
    display_set_gui_size(1920, 1080);
}
