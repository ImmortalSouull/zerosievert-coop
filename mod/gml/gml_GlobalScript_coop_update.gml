// ZERO Sievert co-op: one check per game launch for a newer mod release on GitHub (shown in the main menu,
// the bunker and the F7 panel). Silent on any error.

#macro COOP_MOD_VERSION "1.1.0"
#macro COOP_RELEASES_API "https://api.github.com/repos/ImmortalSouull/zerosievert-coop/releases/latest"
#macro COOP_RELEASES_PAGE "github.com/ImmortalSouull/zerosievert-coop/releases"

function coop_update_step()
{
    var _c = coop();
    if (_c.test_mode || (variable_struct_exists(_c, "upd_req") && _c.upd_req != -2) || room == r_logo_screen)
    {
        exit;
    }
    var _h = ds_map_create();
    ds_map_add(_h, "User-Agent", "zs-coop-mod");
    ds_map_add(_h, "Accept", "application/vnd.github+json");
    _c.upd_req = http_request(COOP_RELEASES_API, "GET", _h, "");
    ds_map_destroy(_h);
    _c.upd_latest = "";
}

// obj_coop Async - HTTP.
function coop_update_on_http()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "upd_req") || ds_map_find_value(async_load, "id") != _c.upd_req)
    {
        exit;
    }
    _c.upd_req = -1;
    if (ds_map_find_value(async_load, "status") != 0 || ds_map_find_value(async_load, "http_status") != 200)
    {
        exit;
    }
    var _res = json_parse(ds_map_find_value(async_load, "result"));
    if (!is_struct(_res) || !variable_struct_exists(_res, "tag_name"))
    {
        exit;
    }
    var _tag = string_replace(_res.tag_name, "v", "");
    if (coop_version_newer(_tag, COOP_MOD_VERSION))
    {
        _c.upd_latest = _tag;
        coop_log("update available: ", _tag, " (have ", COOP_MOD_VERSION, ")");
        coop_notify(coop_t("Co-op mod update available: v", "Доступна новая версия кооп-мода: v") + _tag);
    }
}

// "1.2.10" > "1.2.9"
function coop_version_newer(_a, _b)
{
    var _pa = string_split(_a, ".");
    var _pb = string_split(_b, ".");
    for (var _i = 0; _i < 3; _i++)
    {
        var _x = (_i < array_length(_pa)) ? real(string_digits(_pa[_i])) : 0;
        var _y = (_i < array_length(_pb)) ? real(string_digits(_pb[_i])) : 0;
        if (_x != _y)
        {
            return _x > _y;
        }
    }
    return false;
}

// Line under the "[F7] Co-op" hint and in the panel.
function coop_update_text()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "upd_latest") || _c.upd_latest == "")
    {
        return "";
    }
    return coop_t("Update v", "Обновление v") + _c.upd_latest + ": " + COOP_RELEASES_PAGE;
}
