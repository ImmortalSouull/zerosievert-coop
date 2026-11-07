// ZERO Sievert co-op: save protection (2.0.0 item 18).
// Before a co-op session touches a save slot, the slot file (save_shared_<n>.dat, the whole slot since 1.4) is
// copied to <save root>/coop_backups/. The newest COOP_BACKUP_KEEP copies per slot are kept. The co-op panel
// lists them in the main menu; "Restore" puts a copy back (the current file is backed up first) and, with Steam
// Cloud on, pushes it to the cloud too, otherwise the next start would pull the newer cloud copy over it.

#macro COOP_BACKUP_KEEP 10
#macro COOP_BACKUP_DIR "coop_backups/"

function coop_backup_root()
{
    return variable_global_exists("database_savedata_root") ? global.database_savedata_root : "";
}

function coop_backup_slot_file(_slot)
{
    return "save_shared_" + string(_slot) + ".dat";
}

function coop_backup_stamp()
{
    var _d = date_current_datetime();
    var _f = function(_v, _n) { var _s = string(_v); while (string_length(_s) < _n) _s = "0" + _s; return _s; };
    return _f(date_get_year(_d), 4) + _f(date_get_month(_d), 2) + _f(date_get_day(_d), 2) + "-"
        + _f(date_get_hour(_d), 2) + _f(date_get_minute(_d), 2) + _f(date_get_second(_d), 2);
}

// Backups of one slot, newest first: [{ file, stamp, reason }].
function coop_backup_list(_slot)
{
    var _root = coop_backup_root() + COOP_BACKUP_DIR;
    var _pre = "slot" + string(_slot) + "_";
    var _out = [];
    var _f = file_find_first(_root + _pre + "*.dat", 0);
    while (_f != "")
    {
        // slot1_20261107-091500_coop.dat
        var _rest = string_delete(string_replace(_f, ".dat", ""), 1, string_length(_pre));
        var _stamp = string_copy(_rest, 1, 15);
        var _reason = string_delete(_rest, 1, 16);
        array_push(_out, { file: _f, stamp: _stamp, reason: _reason });
        _f = file_find_next();
    }
    file_find_close();
    array_sort(_out, function(_a, _b) { return (_a.stamp < _b.stamp) ? 1 : ((_a.stamp > _b.stamp) ? -1 : 0); });
    return _out;
}

// Copies the slot file into the backup folder. _reason: "coop" (session start) or "restore" (before a restore).
function coop_backup_make(_slot, _reason)
{
    var _root = coop_backup_root();
    var _src = _root + coop_backup_slot_file(_slot);
    if (!file_exists(_src))
    {
        return false;
    }
    if (!directory_exists(_root + COOP_BACKUP_DIR))
    {
        directory_create(_root + COOP_BACKUP_DIR);
    }
    var _name = "slot" + string(_slot) + "_" + coop_backup_stamp() + "_" + _reason + ".dat";
    file_copy(_src, _root + COOP_BACKUP_DIR + _name);
    var _ok = file_exists(_root + COOP_BACKUP_DIR + _name);
    coop_log("save backup slot ", _slot, " (", _reason, "): ", _ok ? _name : "FAILED");
    // keep the newest COOP_BACKUP_KEEP
    var _l = coop_backup_list(_slot);
    for (var _i = COOP_BACKUP_KEEP; _i < array_length(_l); _i++)
    {
        file_delete(_root + COOP_BACKUP_DIR + _l[_i].file);
    }
    return _ok;
}

// obj_coop Step: one backup per slot and game start, as soon as a co-op session and a chosen slot meet.
function coop_backup_step()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "backup_done"))
    {
        _c.backup_done = [false, false, false, false];
    }
    if (_c.role == "none" || !variable_global_exists("slot_selected"))
    {
        exit;
    }
    var _s = global.slot_selected;
    if (!is_real(_s) || _s < 1 || _s > 3 || _c.backup_done[_s])
    {
        exit;
    }
    // only once the player is past the main menu with this slot (browsing slots there must not count)
    if (room == r_menu || room == r_logo_screen)
    {
        exit;
    }
    _c.backup_done[_s] = true;
    coop_backup_make(_s, "coop");
}

// Puts a backup back. Main menu only (no slot is loaded there).
function coop_backup_restore(_slot, _file)
{
    var _root = coop_backup_root();
    var _src = _root + COOP_BACKUP_DIR + _file;
    var _dst = _root + coop_backup_slot_file(_slot);
    if (!file_exists(_src) || room != r_menu)
    {
        return false;
    }
    coop_backup_make(_slot, "restore");
    if (file_exists(_dst))
    {
        file_delete(_dst);
    }
    file_copy(_src, _dst);
    if (!file_exists(_dst))
    {
        coop_log("save restore FAILED: ", _file);
        return false;
    }
    // Steam Cloud: the start-up sync would pull the cloud copy over the restored file
    try
    {
        if (db_cloud_enabled())
        {
            var _buf = buffer_load(_dst);
            var _text = buffer_read(_buf, buffer_string);
            buffer_delete(_buf);
            platform_cloud_write(coop_backup_slot_file(_slot), _text);
        }
    }
    catch (_e)
    {
        coop_report_error(_e);
    }
    // databases reading this file load it again
    var _names = variable_struct_get_names(global.database_struct);
    for (var _i = 0; _i < array_length(_names); _i++)
    {
        var _db = variable_struct_get(global.database_struct, _names[_i]);
        if (is_struct(_db) && variable_struct_exists(_db, "filename") && _db.filename == coop_backup_slot_file(_slot))
        {
            _db.loaded = false;
        }
    }
    // the main menu shows the slot's play time from its metadata
    try
    {
        with (obj_main_menu)
        {
            mm_init_slot_metadata();
        }
    }
    catch (_e2)
    {
        coop_report_error(_e2);
    }
    coop_log("save restored slot ", _slot, " from ", _file);
    return true;
}

// "2026-11-07 09:15" from a stamp
function coop_backup_label(_e)
{
    var _s = _e.stamp;
    var _t = string_copy(_s, 1, 4) + "-" + string_copy(_s, 5, 2) + "-" + string_copy(_s, 7, 2) + " " + string_copy(_s, 10, 2) + ":" + string_copy(_s, 12, 2);
    if (_e.reason == "restore")
    {
        _t += coop_t(" (before a restore)", " (перед восстановлением)");
    }
    return _t;
}
