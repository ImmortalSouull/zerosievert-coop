// ZERO Sievert co-op: partner marker on the PDA map (pda_map.ui is patched by the installer to call these).

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
    uiCatspeakGetEnvironment().addGlobalFunction("CoopPartnerOnMap", coop_minimap_partner_on_map, "CoopPartnerX", coop_minimap_partner_x, "CoopPartnerY", coop_minimap_partner_y);
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
