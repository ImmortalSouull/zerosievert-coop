// ZERO Sievert co-op: what teammates are doing (2.0.0 items 35 and 23).
// Status (item 35): every player sends a small reliable PSTATUS when it changes (and every 5 s): 0 playing,
// 1 inventory open, 2 in a menu (pause, the co-op panel, another game window), 3 away (no input for 60 s). It is a
// message of its own because the pause deactivates obj_player and stops the PSTATE stream. Shown under the name tag.
// Group panel (item 23): a small table at the left edge - per teammate: colour, name, HP bar (or DOWN), distance,
// the weapon in hand and the item being used (bandage, medkit, food...) as micro icons, or where the teammate is.

#macro COOP_MSG_PSTATUS 69
#macro COOP_AFK_MS 60000

function coop_status_local()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "afk_last")) { _c.afk_last = current_time; _c.afk_mx = 0; _c.afk_my = 0; }
    // any input resets the away timer
    var _mx = window_mouse_get_x();
    var _my = window_mouse_get_y();
    var _pad = false;
    try
    {
        if (instance_exists(obj_gamepad))
        {
            for (var _i = 0; _i < 8; _i++)
            {
                if (abs(obj_gamepad.action[_i].value) > 0.2) { _pad = true; break; }
            }
        }
    }
    catch (_e) { }
    if (keyboard_check(vk_anykey) || mouse_check_button(mb_any) || _mx != _c.afk_mx || _my != _c.afk_my || _pad)
    {
        _c.afk_last = current_time;
    }
    _c.afk_mx = _mx;
    _c.afk_my = _my;
    if ((variable_struct_exists(_c, "panel") && _c.panel) || (instance_exists(obj_main_menu) && room != r_menu))
    {
        return 2;
    }
    var _inv = false;
    try
    {
        _inv = __uiGlobal().__defaultOnion.LayerExists("inventory layer");
    }
    catch (_e2) { }
    if (_inv)
    {
        return 1;
    }
    if (current_time - _c.afk_last > ((_c.test_mode && variable_struct_exists(_c, "afk_test_ms")) ? _c.afk_test_ms : COOP_AFK_MS))
    {
        return 3;
    }
    return 0;
}

// obj_coop Step
function coop_status_step()
{
    var _c = coop();
    var _st = coop_status_local();
    if (!_c.connected)
    {
        _c.status_sent = -1;
        exit;
    }
    if (!variable_struct_exists(_c, "status_sent")) _c.status_sent = -1;
    if (_st != _c.status_sent || _c.frame mod 300 == 0)
    {
        if (_st != _c.status_sent && _c.test_mode) coop_log("status: mine ", _st);
        _c.status_sent = _st;
        var _b = coop_msg_begin(COOP_MSG_PSTATUS);
        buffer_write(_b, buffer_u8, _st);
        coop_msg_send(true);
    }
}

function coop_status_on_msg(_b)
{
    var _c = coop();
    var _st = buffer_read(_b, buffer_u8);
    var _p = coop_peer(_c.msg_from);
    if (is_struct(_p))
    {
        if (_c.test_mode && (!variable_struct_exists(_p, "status") || _p.status != _st)) coop_log("status: slot ", _c.msg_from, " is ", _st);
        _p.status = _st;
    }
}

function coop_status_of(_slot)
{
    var _p = coop_peer(_slot);
    return (is_struct(_p) && variable_struct_exists(_p, "status")) ? _p.status : 0;
}

function coop_status_text(_st)
{
    switch (_st)
    {
        case 1: return coop_t("in the inventory", "в инвентаре");
        case 2: return coop_t("in a menu", "в меню");
        case 3: return coop_t("away", "отошёл");
    }
    return "";
}

// ---- group panel ----

function coop_group_mode()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "group_on"))
    {
        ini_open("coop_local.ini");
        _c.group_on = ini_read_real("coop", "group_panel", 1);
        ini_close();
    }
    return _c.group_on;
}

function coop_group_toggle()
{
    var _c = coop();
    _c.group_on = 1 - coop_group_mode();
    ini_open("coop_local.ini");
    ini_write_real("coop", "group_panel", _c.group_on);
    ini_close();
}

// Draw GUI (raid and hub). Left edge, under the game's status icons.
function coop_group_draw()
{
    var _c = coop();
    if (!_c.connected || !coop_group_mode() || !instance_exists(obj_player))
    {
        exit;
    }
    var _ps = coop_peers();
    var _rows = [];
    for (var _k = 0; _k < COOP_MAX_PLAYERS; _k++)
    {
        if (_k != _c.slot && is_struct(_ps[_k]) && _ps[_k].connected)
        {
            array_push(_rows, _k);
        }
    }
    if (array_length(_rows) == 0)
    {
        exit;
    }
    coop_ui_font(COOP_F_SMALL);
    var _x = 16;
    var _y = 420;
    var _rh = 44;
    var _w = 470;
    coop_ui_rect(_x - 4, _y - 4, _x + _w, _y + array_length(_rows) * _rh, c_black, 0.55);
    for (var _i = 0; _i < array_length(_rows); _i++)
    {
        var _k = _rows[_i];
        var _pp = _ps[_k];
        var _ry = _y + _i * _rh;
        var _mid = _ry + _rh / 2 - 2;
        coop_ui_rect(_x + 4, _mid - 5, _x + 13, _mid + 4, coop_slot_colour(_k));
        draw_set_valign(fa_middle);
        coop_ui_text(_x + 20, _mid, coop_ui_fit(_pp.name, 130), COOP_C_TEXT);
        var _pup = coop_puppet_of(_k);
        var _st = coop_status_of(_k);
        if (instance_exists(_pup) && variable_instance_exists(_pup, "coop_hp"))
        {
            var _down = (_pup.coop_flags & 2) != 0;
            if (_down)
            {
                coop_ui_text(_x + 156, _mid, coop_t("DOWN", "РАНЕН"), COOP_C_RED);
            }
            else
            {
                coop_ui_bar(_x + 156, _mid - 4, 80, 8, clamp(_pup.coop_hp / max(1, _pup.coop_hp_max), 0, 1), COOP_C_GREEN);
            }
            var _m = floor(point_distance(obj_player.x, obj_player.y, _pup.x, _pup.y) / 16);
            coop_ui_text(_x + 246, _mid, string(_m) + coop_t("m", "м"), COOP_C_DIM);
            // weapon in hand, then the item being used
            // inventory-like cells, so dark item sprites stay readable
            coop_ui_slot(_x + 294, _mid - 17, _x + 394, _mid + 17, false, 0.8);
            if (variable_instance_exists(_pup, "arma_now") && item_exists(_pup.arma_now))
            {
                coop_ui_item_icon_wh(_pup.arma_now, _x + 344, _mid, 94, 30);
            }
            var _using = variable_instance_exists(_pup, "coop_arms_item") && _pup.coop_arms_item != "" && item_exists(_pup.coop_arms_item);
            coop_ui_slot(_x + 404, _mid - 17, _x + 442, _mid + 17, _using, 0.8);
            if (_using)
            {
                coop_ui_item_icon_wh(_pup.coop_arms_item, _x + 423, _mid, 32, 30);
            }
        }
        else
        {
            var _where = (_pp.loc == 2) ? coop_t("in a raid", "в рейде") : ((_pp.loc == 1) ? coop_t("in the bunker", "в бункере") : coop_t("in the menu", "в меню"));
            if (_st != 0) _where += " · " + coop_status_text(_st);
            coop_ui_text(_x + 156, _mid, _where, COOP_C_DIM);
        }
        draw_set_valign(fa_top);
    }
}
