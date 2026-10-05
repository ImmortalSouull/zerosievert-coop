// ZERO Sievert co-op: status line, notifications, down/revive UI and the co-op panel, in the game's UI style
// (coop_style.gml, 1920x1080 UI space).

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
    coop_ui_begin(COOP_F_SMALL);
    _c.frame_draw = (variable_struct_exists(_c, "frame_draw") ? _c.frame_draw : 0) + 1; // one per drawn frame
    var _x = 16;
    var _y = 128;
    if (_c.role != "none")
    {
        // rebuilt only when something in it changes (this runs every frame)
        var _key = _c.role + _c.transport + string(_c.connected) + _c.peer_name + string(round(_c.ping)) + string(coop_player_count()) + coop_t("en", "ru");
        if (!variable_struct_exists(_c, "hud_key") || _c.hud_key != _key)
        {
            var _txt = coop_t("CO-OP", "КООП") + " · " + ((_c.role == "host") ? coop_t("host", "хост") : coop_t("guest", "гость"));
            if (_c.transport != "steam")
            {
                _txt += " · IP";
            }
            if (_c.connected && _c.role == "guest")
            {
                _txt += " · " + string(round(_c.ping)) + coop_t(" ms", " мс");
            }
            else if (!_c.connected)
            {
                _txt += (_c.role == "guest") ? coop_t(" · connecting...", " · подключение...") : coop_t(" · waiting for players", " · ждём игроков");
            }
            _c.hud_key = _key;
            _c.hud_txt = _txt;
        }
        // one coloured square per player in the session, then the text
        var _ps = coop_peers();
        var _sq = 0;
        for (var _k = 0; _k < COOP_MAX_PLAYERS; _k++)
        {
            if (_k == _c.slot || (is_struct(_ps[_k]) && _ps[_k].connected))
            {
                _sq++;
            }
        }
        var _h = string_height("A") + 8;
        var _w = string_width(_c.hud_txt) + 20 + _sq * 16;
        coop_ui_rect(_x, _y, _x + _w, _y + _h, c_black, 0.6);
        var _sx = _x + 8;
        for (var _k = 0; _k < COOP_MAX_PLAYERS; _k++)
        {
            if (_k == _c.slot || (is_struct(_ps[_k]) && _ps[_k].connected))
            {
                coop_ui_rect(_sx, _y + _h / 2 - 5, _sx + 9, _y + _h / 2 + 4, coop_slot_colour(_k));
                _sx += 16;
            }
        }
        coop_ui_text(_sx + 4, _y + 4, _c.hud_txt, COOP_C_TEXT);
        _y += _h + 6;
    }
    coop_ui_font(COOP_F_BODY);
    var _i = 0;
    while (_i < array_length(_c.notes))
    {
        var _n = _c.notes[_i];
        if (current_time > _n.t_end)
        {
            array_delete(_c.notes, _i, 1);
            continue;
        }
        var _nh = string_height("A") + 8;
        var _a = clamp((_n.t_end - current_time) / 400, 0, 1);
        coop_ui_rect(_x, _y, _x + string_width(_n.text) + 20, _y + _nh, c_black, 0.7 * _a);
        coop_ui_rect(_x, _y, _x + 3, _y + _nh, COOP_C_KEY, _a);
        draw_text_colour(_x + 12, _y + 4, _n.text, COOP_C_KEY, COOP_C_KEY, COOP_C_KEY, COOP_C_KEY, _a);
        _y += _nh + 4;
        _i++;
    }
    if (_c.test_mode && _c.overlay)
    {
        draw_set_font(-1);
        display_set_gui_size(960, 540);
        var _ty = _y / 2 + 4;
        for (var _j = 0; _j < array_length(_c.log_lines); _j++)
        {
            draw_text_colour(8, _ty, _c.log_lines[_j], c_white, c_white, c_white, c_white, 0.8);
            _ty += 13;
        }
        coop_ui_begin(COOP_F_SMALL);
    }
    if (instance_exists(obj_player) && (coop_in_raid() || is_in_hub()))
    {
        coop_puppet_draw_tag_gui();
    }
    if (is_in_hub())
    {
        coop_hub_draw_gui();
    }
    if (coop_in_raid())
    {
        coop_ping_draw_gui();
        coop_give_draw_gui();
        coop_down_draw_gui();
    }
    else if (_c.role == "none" && (room == r_hub || room == r_menu) && !(variable_struct_exists(_c, "panel") && _c.panel))
    {
        coop_ui_font(COOP_F_SMALL);
        var _ph = coop_ui_prompt(COOP_GW - 16, 16, "F7", coop_t("Co-op", "Кооператив"), 2);
        var _upd = coop_update_text();
        if (_upd != "")
        {
            draw_set_halign(fa_right);
            coop_ui_text_ol(COOP_GW - 16, 16 + _ph + 8, _upd, COOP_C_KEY);
        }
    }
    coop_ui_end();
}

// Draw GUI End: the F7 panel goes over everything the game draws in its GUI (interaction prompts...).
function coop_draw_gui_end()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "panel") || !_c.panel)
    {
        exit;
    }
    coop_panel_draw();
    display_set_gui_size(1920, 1080);
}

