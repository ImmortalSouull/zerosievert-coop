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

// Draw GUI (raid and hub): a compact list at the top right (where the raid HUD is empty). One 26 px row per
// teammate: colour, name, HP bar (or DOWN), distance, the weapon and the item being used as small icons.
#macro COOP_GROUP_X1 (COOP_GW - 330)
#macro COOP_GROUP_Y1 16
#macro COOP_GROUP_RH 26

function coop_group_rows()
{
    var _c = coop();
    var _rows = [];
    if (!_c.connected || !coop_group_mode() || !instance_exists(obj_player) || coop_hud_hidden())
    {
        return _rows;
    }
    var _ps = coop_peers();
    for (var _k = 0; _k < COOP_MAX_PLAYERS; _k++)
    {
        if (_k != _c.slot && is_struct(_ps[_k]) && _ps[_k].connected)
        {
            array_push(_rows, _k);
        }
    }
    return _rows;
}

// Lowest y the panel uses (edge arrows on the right stay below it).
function coop_group_bottom()
{
    var _n = array_length(coop_group_rows());
    return (_n == 0) ? 0 : COOP_GROUP_Y1 + _n * COOP_GROUP_RH + 8;
}

function coop_group_draw()
{
    var _rows = coop_group_rows();
    if (array_length(_rows) == 0)
    {
        exit;
    }
    var _ps = coop_peers();
    coop_ui_font(COOP_F_SMALL);
    var _x = COOP_GROUP_X1;
    var _y = COOP_GROUP_Y1;
    var _rh = COOP_GROUP_RH;
    coop_ui_rect(_x - 6, _y - 4, COOP_GW - 10, _y + array_length(_rows) * _rh + 2, c_black, 0.4);
    draw_set_valign(fa_middle);
    for (var _i = 0; _i < array_length(_rows); _i++)
    {
        var _k = _rows[_i];
        var _pp = _ps[_k];
        var _mid = _y + _i * _rh + _rh / 2;
        coop_ui_rect(_x, _mid - 4, _x + 7, _mid + 3, coop_slot_colour(_k));
        coop_ui_text(_x + 12, _mid, coop_ui_fit(coop_peer_name(_k), 104), COOP_C_TEXT);
        var _pup = coop_puppet_of(_k);
        var _st = coop_status_of(_k);
        if (instance_exists(_pup) && variable_instance_exists(_pup, "coop_hp"))
        {
            if ((_pup.coop_flags & 2) != 0)
            {
                coop_ui_text(_x + 122, _mid, coop_t("DOWN", "РАНЕН"), COOP_C_RED);
            }
            else
            {
                coop_ui_bar(_x + 122, _mid - 3, 50, 6, clamp(_pup.coop_hp / max(1, _pup.coop_hp_max), 0, 1), COOP_C_GREEN);
            }
            var _m = floor(point_distance(obj_player.x, obj_player.y, _pup.x, _pup.y) / 16);
            coop_ui_text(_x + 178, _mid, string(_m) + coop_t("m", "м"), COOP_C_DIM);
            if (variable_instance_exists(_pup, "arma_now") && item_exists(_pup.arma_now))
            {
                coop_ui_item_icon_wh(_pup.arma_now, _x + 248, _mid, 56, 20);
            }
            if (variable_instance_exists(_pup, "coop_arms_item") && _pup.coop_arms_item != "" && item_exists(_pup.coop_arms_item))
            {
                coop_ui_rect(_x + 280, _mid - 11, _x + 302, _mid + 11, COOP_C_KEY, 0.35);
                coop_ui_item_icon_wh(_pup.coop_arms_item, _x + 291, _mid, 20, 20);
            }
        }
        else
        {
            var _where = (_pp.loc == 2) ? coop_t("in a raid", "в рейде") : ((_pp.loc == 1) ? coop_t("in the bunker", "в бункере") : coop_t("in the menu", "в меню"));
            if (_st != 0) _where = coop_status_text(_st);
            coop_ui_text(_x + 122, _mid, coop_ui_fit(_where, 190), COOP_C_DIM);
        }
    }
    draw_set_valign(fa_top);
}

// ---- HUD while aiming (2.0.0, user's request) ----
// Aiming hides the co-op HUD (the game hides its own bars itself). Taking damage while aiming shows the health bar
// (the game's own sprites) for 3 s after the last hit, then it fades out again.
#macro COOP_HUD_HIT_MS 3000

function coop_hud_aiming()
{
    return instance_exists(obj_player) && variable_instance_exists(obj_player, "aiming") && obj_player.aiming;
}

// Co-op HUD hidden: aiming (the wheel, chat line, revive and down screens still show).
function coop_hud_hidden()
{
    return coop_hud_aiming();
}

// obj_coop Step: remember when we last lost health.
function coop_hud_step()
{
    var _c = coop();
    if (!instance_exists(obj_player))
    {
        exit;
    }
    var _hp = obj_player.hp;
    if (variable_struct_exists(_c, "hud_hp_last") && _hp < _c.hud_hp_last - 0.01)
    {
        _c.hud_hit_t = current_time;
    }
    _c.hud_hp_last = _hp;
}

// Draw GUI: the health bar while aiming and hit recently, drawn like the game's (480x270 GUI, s_hp_bar).
function coop_hud_hp_draw()
{
    var _c = coop();
    if (!coop_hud_aiming() || !variable_struct_exists(_c, "hud_hit_t"))
    {
        exit;
    }
    var _age = current_time - _c.hud_hit_t;
    if (_age > COOP_HUD_HIT_MS)
    {
        exit;
    }
    var _a = clamp((COOP_HUD_HIT_MS - _age) / 500, 0, 1);
    var _p = obj_player;
    var _hp = max(0, _p.hp);
    var _hpm = variable_instance_exists(_p, "hp_max_total") ? _p.hp_max_total : _p.hp_max;
    display_set_gui_size(480, 270);
    var _sx = 5;
    var _sy = 5;
    var _bw = (37 / max(1, _hpm)) * _hp;
    draw_set_alpha(_a);
    draw_rectangle_colour(_sx + 23, _sy + 2, _sx + 61, _sy + 13, 8421504, 8421504, 8421504, 8421504, false);
    draw_sprite_part_ext(s_hp_bar, 0, 0, 0, 23, 16, _sx, _sy, 1, 1, c_white, _a);
    draw_sprite_part_ext(s_hp_bar, 1, 24, 2, 1, 12, _sx + 24, _sy + 2, ceil(_bw), 1, c_white, _a);
    draw_set_alpha(1);
    display_set_gui_size(COOP_GW, COOP_GH);
}
