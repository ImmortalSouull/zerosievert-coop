// ZERO Sievert co-op: game files / mods check between players (2.0.0 item 34).
// After boot the mod hashes the game's data files (ZS_vanilla: languages, ui, gamedata...; the room .bin and .dat
// files next to the exe) a few files per tick, grouped by folder, and every enabled game mod (the ugc folder).
// On connect every player sends its fingerprint; a receiver answers once with its own and reports differences
// ("{0} has different game files: languages" / mods only one side has / a mod with different files).
// Live test: a translation mod had replaced the language files on one PC -> enemy callouts showed raw keys.

#macro COOP_MSG_FILES 68
#macro COOP_FILES_PER_TICK 24

function coop_files_state()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "files"))
    {
        _c.files = {
            queue: undefined,   // files still to hash: [{ path, group }]
            groups: {},         // group -> array of "name:md5"
            done: false,
            sig: [],            // [{ name, md5, n }] groups, then mods as "mod:<name>"
            sent_pending: false,
            answered: [false, false, false, false, false, false, false, false],
            diffs: [],          // texts for the panel
        };
    }
    return _c.files;
}

// Which files count, grouped. Skips the exe/dlls, videos, music, options and data.win (protocol + version check).
function coop_files_collect()
{
    var _out = [];
    var _wd = working_directory;
    // root: room layouts (.bin) and data files (.dat)
    var _f = file_find_first(_wd + "*", 0);
    while (_f != "")
    {
        var _ext = string_lower(filename_ext(_f));
        if (_ext == ".bin" || (_ext == ".dat" && _f != "data.win") || _f == "gamedata_order.json" || _f == "template_index.json")
        {
            array_push(_out, { path: _wd + _f, name: _f, group: (_ext == ".bin") ? "rooms" : "root data" });
        }
        _f = file_find_next();
    }
    file_find_close();
    // ZS_vanilla, recursively; the group is the first folder below it
    var _stack = [["ZS_vanilla/", ""]];
    while (array_length(_stack) > 0)
    {
        var _top = array_pop(_stack);
        var _rel = _top[0];
        var _grp = _top[1];
        var _dirs = [];
        _f = file_find_first(_wd + _rel + "*", 16);
        while (_f != "")
        {
            if (_f != "." && _f != ".." && directory_exists(_wd + _rel + _f))
            {
                array_push(_dirs, _f);
            }
            _f = file_find_next();
        }
        file_find_close();
        _f = file_find_first(_wd + _rel + "*", 0);
        while (_f != "")
        {
            var _e = string_lower(filename_ext(_f));
            if (_e != ".bak" && _e != ".orig" && !directory_exists(_wd + _rel + _f))
            {
                array_push(_out, { path: _wd + _rel + _f, name: _rel + _f, group: (_grp == "") ? "ZS_vanilla" : _grp });
            }
            _f = file_find_next();
        }
        file_find_close();
        for (var _i = 0; _i < array_length(_dirs); _i++)
        {
            array_push(_stack, [_rel + _dirs[_i] + "/", (_grp == "") ? _dirs[_i] : _grp]);
        }
    }
    // enabled game mods: every file of the mod's folder
    try
    {
        if (variable_global_exists("Mods_Order") && variable_global_exists("Mods_Data"))
        {
            for (var _m = 0; _m < array_length(global.Mods_Order); _m++)
            {
                var _name = global.Mods_Order[_m];
                var _md = variable_struct_get(global.Mods_Data, _name);
                var _root = ugc_get_folder() + "/" + _name + "/";
                var _ms = [_root];
                var _nfiles = 0;
                while (array_length(_ms) > 0 && _nfiles < 400)
                {
                    var _d = array_pop(_ms);
                    _f = file_find_first(_d + "*", 16);
                    var _sub = [];
                    while (_f != "")
                    {
                        if (_f != "." && _f != ".." && directory_exists(_d + _f)) array_push(_sub, _d + _f + "/");
                        _f = file_find_next();
                    }
                    file_find_close();
                    _f = file_find_first(_d + "*", 0);
                    while (_f != "")
                    {
                        if (!directory_exists(_d + _f))
                        {
                            array_push(_out, { path: _d + _f, name: string_replace(_d + _f, _root, ""), group: "mod:" + _name });
                            _nfiles++;
                        }
                        _f = file_find_next();
                    }
                    file_find_close();
                    for (var _i = 0; _i < array_length(_sub); _i++) array_push(_ms, _sub[_i]);
                }
                if (_nfiles == 0)
                {
                    // a mod with no readable files still counts by name
                    array_push(_out, { path: "", name: "(empty)", group: "mod:" + _name });
                }
            }
        }
    }
    catch (_e)
    {
        coop_report_error(_e);
    }
    return _out;
}

// obj_coop Step: hash a few files per tick once the game reached the main menu (mods are loaded by then).
function coop_files_step()
{
    var _s = coop_files_state();
    var _c = coop();
    if (_c.test_mode && _c.scenario == "files" && _c.connected)
    {
        _s.test_t = (variable_struct_exists(_s, "test_t") ? _s.test_t : 0) + 1;
        if (_s.test_t == 300) _c.panel = true;
        if (_s.test_t == 340) screen_save("files_panel_" + _c.tag + ".png");
        if (_s.test_t == 360) _c.panel = false;
        if (_s.test_t == 600) coop_log("files: test done");
    }
    if (_s.done)
    {
        if (_s.sent_pending && _c.connected)
        {
            _s.sent_pending = false;
            coop_files_send(COOP_ALL);
        }
        exit;
    }
    if (_s.queue == undefined)
    {
        if (room == r_logo_screen)
        {
            exit;
        }
        _s.queue = coop_files_collect();
        _s.t0 = current_time;
        coop_log("files: hashing ", array_length(_s.queue), " files");
    }
    repeat (COOP_FILES_PER_TICK)
    {
        if (array_length(_s.queue) == 0)
        {
            break;
        }
        var _e = array_pop(_s.queue);
        var _h = (_e.path != "" && file_exists(_e.path)) ? md5_file(_e.path) : "-";
        if (!variable_struct_exists(_s.groups, _e.group))
        {
            variable_struct_set(_s.groups, _e.group, []);
        }
        array_push(variable_struct_get(_s.groups, _e.group), _e.name + ":" + string(_h));
    }
    if (array_length(_s.queue) > 0)
    {
        exit;
    }
    var _names = variable_struct_get_names(_s.groups);
    array_sort(_names, true);
    _s.sig = [];
    for (var _i = 0; _i < array_length(_names); _i++)
    {
        var _l = variable_struct_get(_s.groups, _names[_i]);
        array_sort(_l, true);
        var _all = "";
        for (var _k = 0; _k < array_length(_l); _k++) _all += _l[_k] + "|";
        array_push(_s.sig, { name: _names[_i], md5: md5_string_utf8(_all), n: array_length(_l) });
    }
    _s.groups = {}; // per-file lines are not needed any more
    if (_c.test_mode && _c.scenario == "files" && _c.slot == 1)
    {
        // test: a changed language folder and a mod only this player has
        for (var _i = 0; _i < array_length(_s.sig); _i++)
        {
            if (_s.sig[_i].name == "languages") _s.sig[_i].md5 = "changed";
        }
        array_push(_s.sig, { name: "mod:testmod", md5: "x", n: 1 });
    }
    _s.done = true;
    coop_log("files: ", array_length(_s.sig), " groups hashed in ", current_time - _s.t0, " ms");
    if (_c.connected)
    {
        coop_files_send(COOP_ALL);
    }
}

function coop_files_send(_to)
{
    var _s = coop_files_state();
    if (!_s.done)
    {
        _s.sent_pending = true;
        return;
    }
    var _b = coop_msg_begin(COOP_MSG_FILES);
    buffer_write(_b, buffer_u16, array_length(_s.sig));
    for (var _i = 0; _i < array_length(_s.sig); _i++)
    {
        buffer_write(_b, buffer_string, _s.sig[_i].name);
        buffer_write(_b, buffer_string, _s.sig[_i].md5);
        buffer_write(_b, buffer_u16, _s.sig[_i].n);
    }
    coop_msg_send_to(_to, true);
}

// coop_on_connected: everybody tells the others; answers go back once per peer (coop_files_on_msg).
function coop_files_on_connected()
{
    coop_files_send(COOP_ALL);
}

function coop_files_on_peer_left(_slot)
{
    var _s = coop_files_state();
    if (_slot >= 0 && _slot < array_length(_s.answered)) _s.answered[_slot] = false;
    coop_files_drop_diffs(_slot);
    if (variable_struct_exists(_s, "last")) variable_struct_remove(_s.last, "s" + string(_slot));
}

// Removes one player's lines from the panel.
function coop_files_drop_diffs(_slot)
{
    var _s = coop_files_state();
    var _keep = [];
    for (var _i = 0; _i < array_length(_s.diffs); _i++)
    {
        if (_s.diffs[_i].slot != _slot) array_push(_keep, _s.diffs[_i]);
    }
    _s.diffs = _keep;
}

function coop_files_on_msg(_b)
{
    var _c = coop();
    var _s = coop_files_state();
    var _from = _c.msg_from;
    var _n = buffer_read(_b, buffer_u16);
    var _theirs = {};
    for (var _i = 0; _i < _n; _i++)
    {
        var _name = buffer_read(_b, buffer_string);
        var _md5 = buffer_read(_b, buffer_string);
        var _cnt = buffer_read(_b, buffer_u16);
        variable_struct_set(_theirs, _name, _md5 + "/" + string(_cnt));
    }
    if (_from >= 0 && _from < array_length(_s.answered) && !_s.answered[_from])
    {
        _s.answered[_from] = true;
        coop_files_send(_from);
    }
    if (!_s.done)
    {
        // our own hashes are not ready: ask again later (their message is answered by ours, which makes them
        // send theirs back only if they had not answered us - so keep theirs for the comparison)
        if (!variable_struct_exists(_s, "pending_theirs") || !is_array(_s.pending_theirs)) _s.pending_theirs = [];
        array_push(_s.pending_theirs, { from: _from, data: _theirs });
        return;
    }
    coop_files_compare(_from, _theirs);
}

function coop_files_compare(_from, _theirs)
{
    var _s = coop_files_state();
    var _who = coop_peer_name(_from);
    var _mine = {};
    for (var _i = 0; _i < array_length(_s.sig); _i++)
    {
        variable_struct_set(_mine, _s.sig[_i].name, _s.sig[_i].md5 + "/" + string(_s.sig[_i].n));
    }
    var _game_diff = [];
    var _mods_only_me = [];
    var _mods_only_them = [];
    var _mods_diff = [];
    var _names = variable_struct_get_names(_mine);
    for (var _i = 0; _i < array_length(_names); _i++)
    {
        var _k = _names[_i];
        var _isMod = string_copy(_k, 1, 4) == "mod:";
        if (!variable_struct_exists(_theirs, _k))
        {
            if (_isMod) array_push(_mods_only_me, string_delete(_k, 1, 4)); else array_push(_game_diff, _k);
        }
        else if (variable_struct_get(_theirs, _k) != variable_struct_get(_mine, _k))
        {
            if (_isMod) array_push(_mods_diff, string_delete(_k, 1, 4)); else array_push(_game_diff, _k);
        }
    }
    _names = variable_struct_get_names(_theirs);
    for (var _i = 0; _i < array_length(_names); _i++)
    {
        var _k = _names[_i];
        if (!variable_struct_exists(_mine, _k))
        {
            if (string_copy(_k, 1, 4) == "mod:") array_push(_mods_only_them, string_delete(_k, 1, 4)); else array_push(_game_diff, _k);
        }
    }
    coop_files_drop_diffs(_from); // replace that player's old lines
    var _lines = [];
    if (array_length(_game_diff) > 0)
    {
        array_push(_lines, coop_tf("{0} has different game files: {1}", "У {0} отличаются файлы игры: {1}", _who, coop_files_join(_game_diff)));
    }
    if (array_length(_mods_only_them) > 0)
    {
        array_push(_lines, coop_tf("Mods only {0} has: {1}", "Моды, которые есть только у {0}: {1}", _who, coop_files_join(_mods_only_them)));
    }
    if (array_length(_mods_only_me) > 0)
    {
        array_push(_lines, coop_tf("Mods {0} does not have: {1}", "Моды, которых нет у {0}: {1}", _who, coop_files_join(_mods_only_me)));
    }
    if (array_length(_mods_diff) > 0)
    {
        array_push(_lines, coop_tf("Mods with different files than {0}'s: {1}", "Моды с другими файлами, чем у {0}: {1}", _who, coop_files_join(_mods_diff)));
    }
    // the same result again (a second fingerprint from that player): nothing new to say
    var _key = "s" + string(_from);
    var _sum = coop_files_join(_lines);
    if (!variable_struct_exists(_s, "last")) _s.last = {};
    var _was = variable_struct_exists(_s.last, _key) ? variable_struct_get(_s.last, _key) : undefined;
    variable_struct_set(_s.last, _key, _sum);
    if (array_length(_lines) == 0)
    {
        if (_was != "") coop_log("files: same game files and mods as slot ", _from);
        return;
    }
    if (_was == _sum)
    {
        for (var _i = 0; _i < array_length(_lines); _i++) array_push(_s.diffs, { slot: _from, text: _lines[_i] });
        return;
    }
    for (var _i = 0; _i < array_length(_lines); _i++)
    {
        array_push(_s.diffs, { slot: _from, text: _lines[_i] });
        coop_notify(_lines[_i]);
    }
    coop_log("FILES DIFFER from slot ", _from, ": game=", coop_files_join(_game_diff), " only_them=", coop_files_join(_mods_only_them),
        " only_me=", coop_files_join(_mods_only_me), " mods_diff=", coop_files_join(_mods_diff));
}

function coop_files_join(_a)
{
    var _s = "";
    for (var _i = 0; _i < array_length(_a); _i++)
    {
        _s += ((_i > 0) ? ", " : "") + _a[_i];
    }
    return _s;
}

// obj_coop Step (after coop_files_step): a message that arrived before our hashes were ready.
function coop_files_pending_step()
{
    var _s = coop_files_state();
    if (_s.done && variable_struct_exists(_s, "pending_theirs") && is_array(_s.pending_theirs) && array_length(_s.pending_theirs) > 0)
    {
        var _l = _s.pending_theirs;
        _s.pending_theirs = [];
        for (var _i = 0; _i < array_length(_l); _i++)
        {
            coop_files_compare(_l[_i].from, _l[_i].data);
        }
    }
}

// Hooks [136]/[137]: mods_enabled.json as a buffer holding valid JSON ("{}" when the file is empty or broken).
function coop_mods_json_load(_name = "mods_enabled.json")
{
    var _b = buffer_load(_name);
    var _ok = false;
    try
    {
        if (_b >= 0 && buffer_get_size(_b) > 0)
        {
            var _txt = buffer_read(_b, buffer_text);
            json_parse(_txt);
            buffer_seek(_b, buffer_seek_start, 0);
            _ok = true;
        }
    }
    catch (_e)
    {
        _ok = false;
    }
    if (_ok)
    {
        return _b;
    }
    if (_b >= 0) buffer_delete(_b);
    coop_log(_name, " was empty or broken - read as {}");
    var _nb = buffer_create(2, buffer_grow, 1);
    buffer_write(_nb, buffer_text, "{}");
    buffer_seek(_nb, buffer_seek_start, 0);
    return _nb;
}
