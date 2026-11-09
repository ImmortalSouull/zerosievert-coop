// ZERO Sievert co-op: one check per game launch for a newer mod release on GitHub (shown in the main menu,
// the bunker and the F7 panel). Silent on any error.
// 2.0.0 (item 19): "Update now" on the co-op panel downloads the release zip into the save area, unpacks it and
// starts a small update.cmd (through the shell, url_open) that waits until the game is closed and then runs the
// release's installer. The game itself cannot start programs any other way.

#macro COOP_MOD_VERSION "2.0.1"
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
    coop_update_on_download();
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
    // the release zip (for the one-click update)
    _c.upd_zip_url = "";
    if (variable_struct_exists(_res, "assets") && is_array(_res.assets))
    {
        for (var _i = 0; _i < array_length(_res.assets); _i++)
        {
            var _a = _res.assets[_i];
            if (is_struct(_a) && string_pos("ZS-Coop-v", _a.name) == 1 && string_pos(".zip", _a.name) > 0)
            {
                _c.upd_zip_url = _a.browser_download_url;
            }
        }
    }
    if (coop_version_newer(_tag, COOP_MOD_VERSION))
    {
        _c.upd_latest = _tag;
        coop_log("update available: ", _tag, " (have ", COOP_MOD_VERSION, ")");
        coop_notify(coop_tf("Co-op mod update available: v{0}", "Доступна новая версия кооп-мода: v{0}", _tag));
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
    return coop_tf("Update v{0}: {1}", "Обновление v{0}: {1}", _c.upd_latest, COOP_RELEASES_PAGE);
}

// ---- one-click update ----

function coop_update_can_install()
{
    var _c = coop();
    return variable_struct_exists(_c, "upd_latest") && _c.upd_latest != "" && variable_struct_exists(_c, "upd_zip_url") && _c.upd_zip_url != "";
}

function coop_update_state()
{
    var _c = coop();
    return variable_struct_exists(_c, "upd_state") ? _c.upd_state : "";
}

// Panel button: download the zip.
function coop_update_start()
{
    var _c = coop();
    if (!coop_update_can_install() || coop_update_state() == "downloading")
    {
        exit;
    }
    _c.upd_dir = "coop_update/";
    if (!directory_exists(_c.upd_dir)) directory_create(_c.upd_dir);
    _c.upd_zip = _c.upd_dir + "ZS-Coop-v" + _c.upd_latest + ".zip";
    if (file_exists(_c.upd_zip)) file_delete(_c.upd_zip);
    _c.upd_dl = http_get_file(_c.upd_zip_url, _c.upd_zip);
    _c.upd_state = "downloading";
    coop_log("update: downloading ", _c.upd_zip_url);
    coop_notify(coop_t("Downloading the update...", "Скачиваем обновление..."));
}

function coop_update_on_download()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "upd_dl") || ds_map_find_value(async_load, "id") != _c.upd_dl)
    {
        exit;
    }
    var _st = ds_map_find_value(async_load, "status");
    if (_st == 1)
    {
        exit; // in progress
    }
    _c.upd_dl = -1;
    if (_st != 0 || ds_map_find_value(async_load, "http_status") != 200 || !file_exists(_c.upd_zip))
    {
        _c.upd_state = "failed";
        coop_log("update: download failed, status ", _st, " http ", ds_map_find_value(async_load, "http_status"));
        coop_notify(coop_t("Update download failed - get it from GitHub", "Не удалось скачать обновление - скачайте его с GitHub"));
        exit;
    }
    coop_update_prepare();
}

// Unpack, find the installer, write update.cmd and start it.
function coop_update_prepare()
{
    var _c = coop();
    var _dest = _c.upd_dir + "v" + _c.upd_latest + "/";
    var _n = zip_unzip(_c.upd_zip, _dest);
    var _inst = "";
    var _f = file_find_first(_dest + "*", 16);
    var _dirs = [];
    while (_f != "")
    {
        if (_f != "." && _f != "..") array_push(_dirs, _f);
        _f = file_find_next();
    }
    file_find_close();
    if (file_exists(_dest + "installer.ps1")) _inst = _dest + "installer.ps1";
    for (var _i = 0; _i < array_length(_dirs) && _inst == ""; _i++)
    {
        if (file_exists(_dest + _dirs[_i] + "/installer.ps1")) _inst = _dest + _dirs[_i] + "/installer.ps1";
    }
    if (_n <= 0 || _inst == "")
    {
        _c.upd_state = "failed";
        coop_log("update: unpack failed (", _n, " files, installer ", _inst, ")");
        coop_notify(coop_t("Update download failed - get it from GitHub", "Не удалось скачать обновление - скачайте его с GitHub"));
        exit;
    }
    var _full = string_replace_all(game_save_id + _inst, "/", "\\");
    // cmd.exe reads the script in the OEM code page: a non-ASCII user folder (a Cyrillic Windows user name) breaks a
    // full path, so the script starts in its own folder and names the installer relative to it
    var _rel = string_replace_all(string_delete(_inst, 1, string_length(_c.upd_dir)), "/", "\\");
    var _cmd = _c.upd_dir + "update.cmd";
    var _t = file_text_open_write(_cmd);
    var _lines = [
        "@echo off",
        "title ZERO Sievert co-op update",
        "cd /d \"%~dp0\"",
        "echo Close ZERO Sievert - the co-op mod v" + _c.upd_latest + " installs right after.",
        ":wait",
        "tasklist /FI \"IMAGENAME eq ZERO Sievert.exe\" | find /I \"ZERO Sievert.exe\" >nul",
        "if not errorlevel 1 ( timeout /t 2 /nobreak >nul & goto wait )",
        "powershell -NoProfile -ExecutionPolicy Bypass -File \".\\" + _rel + "\" install",
        "pause"
    ];
    for (var _i = 0; _i < array_length(_lines); _i++)
    {
        file_text_write_string(_t, _lines[_i]);
        file_text_writeln(_t);
    }
    file_text_close(_t);
    _c.upd_state = "ready";
    coop_log("update: ready, ", _n, " files, installer ", _full);
    if (!_c.test_mode)
    {
        url_open(string_replace_all(game_save_id + _cmd, "/", "\\"));
    }
    coop_notify(coop_t("Update ready - close the game, it installs itself", "Обновление готово - закройте игру, оно установится само"));
}
