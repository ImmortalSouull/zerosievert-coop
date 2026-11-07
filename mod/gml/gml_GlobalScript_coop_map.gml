// ZERO Sievert co-op: markers of the other players on the PDA map (pda_map.ui is patched by the installer to
// call these; CoopMate*(i) for i = 0..2, the older CoopPartner* = the nearest one).

// The co-op entry in the game's Mods menu (mm_mods.ui, patched by the installer).
function coop_mod_version_label()
{
    var _upd = coop_update_text();
    return "v" + COOP_MOD_VERSION + ((_upd != "") ? coop_t("  (update available)", "  (есть обновление)") : "");
}

function coop_mod_subheader()
{
    return coop_t("ImmortalSouull, co-op for up to 4 players", "ImmortalSouull, кооператив до 4 игроков");
}

function coop_ui_register()
{
    var _c = coop();
    if (variable_struct_exists(_c, "ui_registered") && _c.ui_registered)
    {
        exit;
    }
    if (room == r_logo_screen)
    {
        exit;
    }
    uiCatspeakGetEnvironment().addGlobalFunction("CoopPartnerOnMap", coop_minimap_partner_on_map, "CoopPartnerX", coop_minimap_partner_x, "CoopPartnerY", coop_minimap_partner_y,
        "CoopMateOnMap", coop_minimap_mate_on_map, "CoopMateX", coop_minimap_mate_x, "CoopMateY", coop_minimap_mate_y,
        "CoopOpenPanel", coop_panel_open_from_menu);
    // (one call takes at most 16 arguments)
    uiCatspeakGetEnvironment().addGlobalFunction("CoopModVersion", coop_mod_version_label, "CoopModSubHeader", coop_mod_subheader);
    // PDA map (2.0.0 item 7): teammates in their colours, ping marks
    uiCatspeakGetEnvironment().addGlobalFunction("CoopMateColor", coop_minimap_mate_color, "CoopMarkCount", coop_minimap_mark_count,
        "CoopMarkX", coop_minimap_mark_x, "CoopMarkY", coop_minimap_mark_y, "CoopMarkColor", coop_minimap_mark_color);
    uiAddBoxType("UiCoopMark", class_ui_coop_mark);
    _c.ui_registered = true;
    coop_log("ui functions registered");
}

function coop_minimap_partner_on_map()
{
    return coop_in_raid() && instance_exists(coop_partner());
}

function coop_minimap_partner_x()
{
    var _p = coop_partner();
    return instance_exists(_p) ? ((4 * _p.x) div 16) : -infinity;
}

function coop_minimap_partner_y()
{
    var _p = coop_partner();
    return instance_exists(_p) ? ((4 * _p.y) div 16) : -infinity;
}

// i-th other player (0..6) in our raid, ordered by slot.
function coop_minimap_mate(_i)
{
    var _l = coop_puppets();
    array_sort(_l, function(_a, _b) { return _a.coop_slot - _b.coop_slot; });
    return (_i >= 0 && _i < array_length(_l)) ? _l[_i] : -4;
}

function coop_minimap_mate_on_map(_i)
{
    return coop_in_raid() && instance_exists(coop_minimap_mate(_i));
}

function coop_minimap_mate_x(_i)
{
    var _p = coop_minimap_mate(_i);
    return instance_exists(_p) ? ((4 * _p.x) div 16) : -infinity;
}

function coop_minimap_mate_y(_i)
{
    var _p = coop_minimap_mate(_i);
    return instance_exists(_p) ? ((4 * _p.y) div 16) : -infinity;
}

// "Co-op" button of the main menu / pause menu (patched in by the installer).
function coop_panel_open_from_menu()
{
    var _c = coop();
    _c.panel = true;
    _c.ip_edit = false;
    _c.panel_sel = 0;
}

function coop_minimap_mate_color(_i)
{
    var _p = coop_minimap_mate(_i);
    return instance_exists(_p) ? coop_slot_colour(_p.coop_slot) : c_white;
}

// Ping marks (coop_ping.gml) on the PDA map, minimap units (4 per 16 px tile).
// (the raid event's SOS point comes after the players' marks, in red)
function coop_minimap_event_on()
{
    var _e = coop_ev();
    return _e.state == "offered" || _e.state == "active";
}

function coop_minimap_mark_count()
{
    return coop_in_raid() ? array_length(coop_marks()) + (coop_minimap_event_on() ? 1 : 0) : 0;
}

function coop_minimap_mark_x(_i)
{
    var _m = coop_marks();
    if (_i == array_length(_m) && coop_minimap_event_on()) return (4 * coop_ev().x) div 16;
    return (_i < array_length(_m)) ? ((4 * _m[_i].x) div 16) : -infinity;
}

function coop_minimap_mark_y(_i)
{
    var _m = coop_marks();
    if (_i == array_length(_m) && coop_minimap_event_on()) return (4 * coop_ev().y) div 16;
    return (_i < array_length(_m)) ? ((4 * _m[_i].y) div 16) : -infinity;
}

function coop_minimap_mark_color(_i)
{
    var _m = coop_marks();
    if (_i == array_length(_m) && coop_minimap_event_on()) return c_red;
    return (_i < array_length(_m)) ? coop_slot_colour(_m[_i].slot) : c_white;
}

// UI box for a ping mark on the PDA map: a small pin in the player's colour.
function class_ui_coop_mark() : uiClassButton() constructor
{
    markColor = c_white;
    Set("size", [1, 1]);
    CallbackSetButtonStart(undefined);
    CallbackSetButtonEnd(undefined);
    CallbackSetDraw(function()
    {
        // a small pin: black outline, the player's colour, a dark centre
        var _x = 0.5 * (__drawLeft + __drawRight);
        var _y = 0.5 * (__drawTop + __drawBottom);
        draw_set_alpha(alpha * animAlpha);
        draw_circle_colour(_x, _y, 13, c_black, c_black, false);
        draw_circle_colour(_x, _y, 10, markColor, markColor, false);
        draw_circle_colour(_x, _y, 4, c_black, c_black, false);
        draw_set_alpha(1);
    });
}

// ---- air drop markers for everybody (item 7) ----
// The air drop is rolled by the raid owner only (hook [66]); its crate reaches the others as a container, its PDA
// marker did not. The owner sends its air drop markers (ids 3 and 6 of the game's interesting markers); the others
// add the ones they lack.
#macro COOP_MSG_MARKERS 77

function coop_markers_step()
{
    var _c = coop();
    if (!_c.connected || !coop_in_raid() || !coop_is_world_owner() || !variable_global_exists("list_intresting_id"))
    {
        exit;
    }
    var _n = ds_list_size(global.list_intresting_id);
    if (variable_struct_exists(_c, "markers_n") && _c.markers_n == _n && _c.frame mod 600 != 0)
    {
        exit;
    }
    _c.markers_n = _n;
    var _out = [];
    for (var _i = 0; _i < _n; _i++)
    {
        var _id = ds_list_find_value(global.list_intresting_id, _i);
        if (_id == 3 || _id == 6)
        {
            array_push(_out, [_id, ds_list_find_value(global.list_intresting_x, _i), ds_list_find_value(global.list_intresting_y, _i)]);
        }
    }
    if (array_length(_out) == 0)
    {
        exit;
    }
    var _b = coop_msg_begin(COOP_MSG_MARKERS);
    buffer_write(_b, buffer_string, json_stringify(_out));
    coop_msg_send(true);
}

function coop_markers_on_msg(_b)
{
    var _l = json_parse(buffer_read(_b, buffer_string));
    if (!coop_in_raid() || !is_array(_l) || !variable_global_exists("list_intresting_id") || coop_is_world_owner())
    {
        exit;
    }
    var _added = 0;
    for (var _i = 0; _i < array_length(_l); _i++)
    {
        var _have = false;
        for (var _k = 0; _k < ds_list_size(global.list_intresting_id); _k++)
        {
            if (ds_list_find_value(global.list_intresting_x, _k) == _l[_i][1] && ds_list_find_value(global.list_intresting_y, _k) == _l[_i][2])
            {
                _have = true;
                break;
            }
        }
        if (!_have)
        {
            minimap_add_interesting_marker(_l[_i][1], _l[_i][2], _l[_i][0]);
            _added++;
        }
    }
    if (_added > 0)
    {
        coop_log("air drop markers added: ", _added);
        coop_notify(coop_t("Air drop marked on the PDA map", "Аирдроп отмечен на карте КПК"));
    }
}
