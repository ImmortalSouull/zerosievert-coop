// ZERO Sievert co-op: markers of the other players on the PDA map (pda_map.ui is patched by the installer to
// call these; CoopMate*(i) for i = 0..2, the older CoopPartner* = the nearest one).

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

// i-th other player (0..2) in our raid, ordered by slot.
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
