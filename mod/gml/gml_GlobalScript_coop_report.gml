// ZERO Sievert co-op: bug report packages (2.0.0 item 12).
// "Collect logs" in the co-op panel and the crash handler both make a folder
// %LOCALAPPDATA%/ZERO_Sievert/coop_reports/report_<time>_<reason>/ with the co-op logs, the game's own logs, the
// enabled mods list and info.txt (versions, session, settings). The folder path goes to the clipboard and the
// folder opens in Explorer (not after a crash: the game is closing). The newest COOP_REPORT_KEEP are kept.

#macro COOP_REPORT_KEEP 5
#macro COOP_REPORT_DIR "coop_reports/"

// Returns the folder (relative to the save area) or "" on failure.
function coop_report_make(_reason, _extra)
{
    var _base = COOP_REPORT_DIR + "report_" + coop_backup_stamp() + "_" + _reason;
    var _dir = _base + "/";
    var _n = 2;
    while (directory_exists(_dir))
    {
        _dir = _base + "_" + string(_n) + "/";
        _n++;
    }
    if (!directory_exists(COOP_REPORT_DIR))
    {
        directory_create(COOP_REPORT_DIR);
    }
    directory_create(_dir);
    var _copied = 0;
    // every log in the save area (co-op logs of every tag, the game's platform log, ...)
    var _logs = [];
    var _f = file_find_first("*.log", 0);
    while (_f != "")
    {
        array_push(_logs, _f);
        _f = file_find_next();
    }
    file_find_close();
    for (var _i = 0; _i < array_length(_logs); _i++)
    {
        file_copy(_logs[_i], _dir + _logs[_i]);
        _copied++;
    }
    if (file_exists("mods_enabled.json"))
    {
        file_copy("mods_enabled.json", _dir + "mods_enabled.json");
        _copied++;
    }
    var _t = file_text_open_write(_dir + "info.txt");
    if (_t != -1)
    {
        var _c = coop();
        var _lines = [
            "ZERO Sievert CO-OP report (" + _reason + ")",
            "mod v" + COOP_MOD_VERSION + ", protocol " + string(COOP_VERSION),
            "game 1.4.13 (the version this mod build targets)",
            "os " + string(os_type) + " version " + string(os_version) + ", language " + string(os_get_language()),
            "time " + date_datetime_string(date_current_datetime()),
            "room " + room_get_name(room) + ", in raid " + string(coop_in_raid()),
            "role " + _c.role + ", transport " + _c.transport + ", slot " + string(_c.slot) + ", connected " + string(_c.connected),
            "players " + string(_c.connected ? coop_player_count() : 1),
        ];
        if (_c.connected)
        {
            var _ps = coop_peers();
            for (var _k = 0; _k < COOP_MAX_PLAYERS; _k++)
            {
                if (is_struct(_ps[_k]) && _ps[_k].connected)
                {
                    array_push(_lines, "  slot " + string(_k) + ": " + string(_ps[_k].name));
                }
            }
        }
        try
        {
            array_push(_lines, "settings " + json_stringify(_c.settings));
        }
        catch (_e) { }
        if (_extra != "")
        {
            array_push(_lines, "");
            array_push(_lines, _extra);
        }
        for (var _i = 0; _i < array_length(_lines); _i++)
        {
            file_text_write_string(_t, _lines[_i]);
            file_text_writeln(_t);
        }
        file_text_close(_t);
        _copied++;
    }
    coop_log("report saved: ", _dir, " files=", _copied);
    // keep the newest COOP_REPORT_KEEP
    var _all = [];
    _f = file_find_first(COOP_REPORT_DIR + "report_*", 16);
    while (_f != "")
    {
        array_push(_all, _f);
        _f = file_find_next();
    }
    file_find_close();
    array_sort(_all, false);
    for (var _i = COOP_REPORT_KEEP; _i < array_length(_all); _i++)
    {
        coop_report_delete_dir(COOP_REPORT_DIR + _all[_i] + "/");
    }
    return _dir;
}

function coop_report_delete_dir(_dir)
{
    var _files = [];
    var _f = file_find_first(_dir + "*", 0);
    while (_f != "")
    {
        array_push(_files, _f);
        _f = file_find_next();
    }
    file_find_close();
    for (var _i = 0; _i < array_length(_files); _i++)
    {
        file_delete(_dir + _files[_i]);
    }
    directory_destroy(_dir);
}

// Full Windows path of a folder in the save area.
function coop_report_full_path(_dir)
{
    return string_replace_all(game_save_id + _dir, "/", "\\");
}

// Panel button: make a report, copy its path, open the folder.
function coop_report_collect()
{
    var _dir = coop_report_make("manual", "");
    var _full = coop_report_full_path(_dir);
    clipboard_set_text(_full);
    if (!coop().test_mode)
    {
        url_open(_full);
    }
    coop_notify(coop_t("Logs collected, the folder path is copied - send the folder with your bug report",
        "Логи собраны, путь к папке скопирован - отправьте папку вместе с описанием бага"));
    return _dir;
}

// Called by the crash handler (coop_boot). Returns the full path or "".
function coop_report_on_crash(_e)
{
    try
    {
        var _dir = coop_report_make("crash", "CRASH: " + string(_e.longMessage) + chr(10) + string(_e.stacktrace));
        var _full = coop_report_full_path(_dir);
        clipboard_set_text(_full);
        return _full;
    }
    catch (_e2) { }
    return "";
}
