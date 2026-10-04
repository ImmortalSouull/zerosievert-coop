// ZERO Sievert co-op: core state, command line, logging, test-mode helpers.

#macro COOP_VERSION 6
#macro COOP_PORT 47777

function coop()
{
    if (!variable_global_exists("coop_state"))
    {
        coop_init_globals();
    }
    return global.coop_state;
}

function coop_init_globals()
{
    global.coop_state = {
        role: "none",          // none | host | guest
        transport: "none",     // udp | steam
        connected: false,
        sock: -1,
        peer_ip: "",
        peer_port: 0,
        peer_steam: 0,
        lobby: 0,
        last_recv_time: 0,
        last_hello_time: 0,
        seed: undefined,
        peer_in_raid: false,
        peer_hub_ready: false,
        peer_ready: false,
        peer_loc: 0,
        local_paused: false,
        pending_raid: undefined,
        peer_map: -1,
        peer_name: "Partner",
        tag: "solo",
        test_mode: false,
        save_root: "",
        autoslot: -1,
        autoslot_done: false,
        autoraid: -1,
        autoraid_done: false,
        bot: false,
        scenario: "",
        sc_t: 0,
        window: undefined,
        frame: 0,
        send_buf: buffer_create(256, buffer_grow, 1),
        recv_buf: buffer_create(256, buffer_grow, 1),
        npc_next_nid: 1,
        npc_by_nid: ds_map_create(),
        npc_state_ids: {},
        npc_state_names: [],
        npc_state_next: 0,
        bullet_quiet: false,
        spawn_synced: false,
        gen_seed: undefined,
        gen_step: 0,
        stats_sent: 0,
        stats_recv: 0,
        overlay: true,
        ping: 0,
        notes: [],
        log_lines: []
    };
    global.coop_trace = false; // test: log every subsystem call (-coop_trace) to find hangs
    global.coop_phase_on = false; // test: log frame phases (-coop_phase)
    coop_parse_params();
}

function coop_parse_params()
{
    var _c = global.coop_state;
    var _n = parameter_count();
    for (var _i = 0; _i < _n; _i++)
    {
        var _p = parameter_string(_i);
        var _v = (_i + 1 < _n) ? parameter_string(_i + 1) : "";
        switch (_p)
        {
            case "-coop_host":
                _c.role = "host";
                _c.transport = "udp";
                break;
            case "-coop_join":
                _c.role = "guest";
                _c.transport = "udp";
                _c.peer_ip = _v;
                _c.peer_port = COOP_PORT;
                break;
            case "-coop_root":
                _c.test_mode = true;
                _c.save_root = _v + "/";
                _c.tag = _v;
                break;
            case "-coop_slot":
                _c.autoslot = real(_v);
                break;
            case "-coop_autoraid":
                _c.autoraid = real(_v);
                break;
            case "-coop_delay_join":
                _c.delay_join = real(_v) * 1000; // test: the guest says hello only after this many seconds
                break;
            case "-coop_seq_dump":
                _c.seq_dump = real(_v);
                break;
            case "-coop_fps_marker":
                _c.fps_marker = true;
                break;
            case "-coop_expect":
                _c.expect = real(_v); // test: the autopilot starts the raid only with this many players
                break;
            case "-coop_bot":
                _c.bot = true;
                break;
            case "-coop_quiet":
                _c.overlay = false;
                break;
            case "-coop_trace":
                global.coop_trace = true;
                break;
            case "-coop_prof":
                global.coop_prof = true;
                break;
            case "-coop_phase":
                global.coop_phase_on = true;
                break;
            case "-coop_netsim":
                // test: <latency ms>,<loss %>,<jitter ms> on outgoing UDP
                var _ns = string_split(_v, ",");
                // optional 4th/5th: blackout start and duration in seconds after the raid map is ready
                _c.netsim = { lat: real(_ns[0]), loss: (array_length(_ns) > 1) ? real(_ns[1]) : 0, jitter: (array_length(_ns) > 2) ? real(_ns[2]) : 0, dropped: 0,
                    black_at: (array_length(_ns) > 4) ? real(_ns[3]) : 0, black_dur: (array_length(_ns) > 4) ? real(_ns[4]) : 0, black_logged: false };
                break;
            case "-coop_fps":
                _c.fps_force = real(_v);
                break;
            case "-coop_scenario":
                _c.scenario = _v;
                break;
            case "-coop_window":
                // x,y,w,h
                var _parts = string_split(_v, ",");
                if (array_length(_parts) == 4)
                {
                    _c.window = [real(_parts[0]), real(_parts[1]), real(_parts[2]), real(_parts[3])];
                }
                break;
        }
    }
    coop_steam_check_launch_invite();
    coop_log("coop init: role=", _c.role, " transport=", _c.transport, " test=", _c.test_mode, " tag=", _c.tag, " params=", parameter_string(1), " ", parameter_string(2));
}

function coop_test_mode()
{
    return coop().test_mode;
}

function coop_save_root_override(_root)
{
    var _c = coop();
    if (_c.test_mode)
    {
        return _c.save_root;
    }
    return _root;
}

function coop_is_host()
{
    return coop().role == "host";
}

function coop_is_guest()
{
    return coop().role == "guest";
}

function coop_active()
{
    var _c = coop();
    return _c.role != "none" && _c.connected;
}

// The raid owner simulates the shared world (NPC AI, time, weather, emissions, kill credit): the player with
// the lowest slot among those in this raid - the host while it is there, otherwise the next player, so the
// raid keeps one world when the host extracts.
function coop_raid_owner()
{
    var _c = coop();
    if (!coop_in_raid())
    {
        return -1;
    }
    var _best = (instance_exists(obj_player) || _c.local_paused) ? max(0, _c.slot) : COOP_MAX_PLAYERS;
    var _ps = coop_peers();
    for (var _i = 0; _i < COOP_MAX_PLAYERS; _i++)
    {
        var _p = _ps[_i];
        if (_i != _c.slot && is_struct(_p) && _p.connected && _p.in_raid && _i < _best)
        {
            _best = _i;
        }
    }
    return (_best >= COOP_MAX_PLAYERS) ? -1 : _best;
}

function coop_is_world_owner()
{
    return coop_shared_ready() && coop_raid_owner() == max(0, coop().slot);
}

// Someone else owns the shared raid we are in: our NPCs are replicas driven by them.
function coop_is_world_replica()
{
    return coop_shared_ready() && coop_raid_owner() != max(0, coop().slot);
}

// Older name.
function coop_guest_in_raid()
{
    return coop_is_world_replica();
}

// obj_coop Step: when the owner changes (the host extracted), the new owner takes the NPCs over.
function coop_owner_step()
{
    var _c = coop();
    var _o = coop_shared_ready() ? coop_raid_owner() : -1;
    if (!variable_struct_exists(_c, "owner_last"))
    {
        _c.owner_last = -1;
    }
    if (_o == _c.owner_last)
    {
        exit;
    }
    var _was = _c.owner_last;
    _c.owner_last = _o;
    if (_o < 0)
    {
        exit;
    }
    coop_log("raid owner: slot ", _o, (_o == max(0, _c.slot)) ? " (me)" : "", " (was ", _was, ")");
    if (_o == max(0, _c.slot) && _was >= 0)
    {
        // we drive the world from now on: our replicas become real NPCs, keep their ids
        coop_npc_take_over();
        coop_notify(coop_t("You now run the raid's world", "Теперь мир рейда считается у вас"));
    }
}

function coop_in_raid()
{
    return room == room1 && instance_exists(obj_map_generator);
}

// Raid map fully generated (instances may be created/destroyed freely without affecting the map).
function coop_raid_ready()
{
    return coop_in_raid() && obj_map_generator.state == 21;
}

// We and at least one other player are in the same raid and the maps are finished.
function coop_shared_ready()
{
    var _c = coop();
    return _c.connected && _c.peer_in_raid && _c.peer_ready && coop_raid_ready();
}

function coop_log()
{
    var _s = "";
    for (var _i = 0; _i < argument_count; _i++)
    {
        _s += string(argument[_i]);
    }
    var _line = string(current_time) + " [" + coop().tag + "] " + _s;
    show_debug_message("[COOP] " + _line);
    var _f = file_text_open_append("coop_" + coop().tag + ".log");
    if (_f != -1)
    {
        file_text_write_string(_f, _line);
        file_text_writeln(_f);
        file_text_close(_f);
    }
    var _lines = coop().log_lines;
    array_push(_lines, _s);
    if (array_length(_lines) > 8)
    {
        array_delete(_lines, 0, 1);
    }
}

// Called once from the logo screen: create the persistent controller.
function coop_boot()
{
    var _c = coop();
    if (!instance_exists(obj_coop))
    {
        instance_create_depth(0, 0, -15000, obj_coop);
    }
    // Crashes always go to the co-op log (players can send it with a bug report). Tests run unattended,
    // so they skip the dialog; normal players still see the message.
    exception_unhandled_handler(function(_e)
    {
        coop_log("CRASH: ", _e.longMessage, " | ", _e.stacktrace);
        if (!coop().test_mode)
        {
            show_message("ZERO Sievert crashed." + chr(10) + "Co-op log: %LOCALAPPDATA%/ZERO_Sievert/coop_" + coop().tag + ".log" + chr(10) + chr(10) + string(_e.longMessage));
        }
        return 0;
    });
    coop_log("boot, steam=", steam_initialised());
    coop_try(zs_fps_apply);
}

// Seed handed to the map generator (shared raids use the host's seed).
function coop_take_seed()
{
    var _c = coop();
    var _s = _c.seed;
    _c.seed = undefined;
    _c.gen_seed = _s;
    _c.gen_step = 0;
    _c.spawn_synced = false;
    if (_s != undefined)
    {
        coop_log("map generator uses coop seed ", _s);
    }
    return _s;
}

// The game deactivates everything outside the camera region (and everything when paused).
// Keep the co-op controller alive, and on the host keep the areas around the other players simulated.
function coop_after_culling()
{
    instance_activate_object(obj_coop);
    var _c = coop();
    if (_c.connected)
    {
        instance_activate_object(obj_player_parent);
        if (coop_raid_owner() == max(0, _c.slot))
        {
            // the world around every other player keeps running on the raid owner
            with (obj_player_puppet)
            {
                instance_activate_region(x - 480, y - 270, 960, 540, true);
            }
        }
    }
}

// Hook: top of obj_map_generator Alarm_2 (one generation step per fire). Re-seeding every step makes
// the shared map depend only on the seed and step number, not on random() calls made by other
// objects between steps (weather, particles, sounds...), so host and guest build the same map.
function coop_gen_reseed()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "gen_seed") || _c.gen_seed == undefined)
    {
        exit;
    }
    _c.gen_step++;
    random_set_seed((_c.gen_seed + _c.gen_step * 7919) mod 2147483647);
}

// Hook: top of obj_controller / obj_main_menu Step. The controller must survive every room change,
// pause and menu; if anything deactivated or destroyed it, bring it back.
function coop_ensure_alive()
{
    if (instance_exists(obj_coop))
    {
        exit;
    }
    instance_activate_object(obj_coop);
    if (instance_exists(obj_coop))
    {
        coop_log("controller was deactivated - reactivated in ", room_get_name(room));
        exit;
    }
    coop_log("controller was missing - recreated in ", room_get_name(room));
    instance_create_depth(0, 0, -15000, obj_coop);
}

// Hook: end of obj_vertex_grass Create. Grass density follows each player's own graphics setting, so the
// number of random() calls it makes differs between players; restore a deterministic RNG state after it.
function coop_gen_reseed_after_grass()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "gen_seed") || _c.gen_seed == undefined || !instance_exists(obj_map_generator) || obj_map_generator.state == 21)
    {
        exit;
    }
    random_set_seed((_c.gen_seed + _c.gen_step * 7919 + 4099) mod 2147483647);
}

// Per-object deterministic RNG for things the map generator creates and that roll their layout a frame later
// (decor, building templates, anomaly fields, containers): same seed + same position = same result on both.
function coop_pos_reseed(_salt)
{
    var _c = coop();
    if (!variable_struct_exists(_c, "gen_seed") || _c.gen_seed == undefined || room != room1)
    {
        exit;
    }
    var _h = (_c.gen_seed + floor(xstart) * 73856093 + floor(ystart) * 19349663 + real(object_index) * 83492791 + _salt * 2654435) mod 2147483647;
    random_set_seed(abs(_h));
}

// Run one subsystem; a bug in it must never take the game down.
if (!variable_global_exists("coop_prof")) global.coop_prof = false; // test: per-subsystem timing (-coop_prof), logged every 5 s

function coop_prof_add(_name, _us)
{
    if (!variable_global_exists("coop_prof_tab"))
    {
        global.coop_prof_tab = {};
        global.coop_prof_t0 = get_timer();
    }
    var _tab = global.coop_prof_tab;
    var _old = variable_struct_exists(_tab, _name) ? variable_struct_get(_tab, _name) : 0;
    variable_struct_set(_tab, _name, _old + _us);
    var _now = get_timer();
    if (_now - global.coop_prof_t0 > 5000000)
    {
        var _secs = (_now - global.coop_prof_t0) / 1000000;
        var _names = variable_struct_get_names(_tab);
        array_sort(_names, function(_a, _b) { return variable_struct_get(global.coop_prof_tab, _b) - variable_struct_get(global.coop_prof_tab, _a); });
        var _s = "prof us/s:";
        var _total = 0;
        for (var _i = 0; _i < array_length(_names); _i++)
        {
            var _v = variable_struct_get(_tab, _names[_i]) / _secs;
            _total += _v;
            if (_i < 10)
            {
                _s += " " + string_replace(_names[_i], "gml_Script_", "") + "=" + string(round(_v));
            }
        }
        coop_log(_s, " | total=", round(_total));
        global.coop_prof_tab = {};
        global.coop_prof_t0 = _now;
    }
}

function coop_try(_f)
{
    try
    {
        if (variable_global_exists("coop_trace") && global.coop_trace)
        {
            coop_log("T ", script_get_name(_f));
        }
        if (global.coop_prof)
        {
            var _t0 = get_timer();
            _f();
            coop_prof_add(script_get_name(_f), get_timer() - _t0);
            exit;
        }
        _f();
    }
    catch (_e)
    {
        coop_report_error(_e);
    }
}

function coop_report_error(_e)
{
    var _c = coop();
    var _msg = is_struct(_e) ? (string(_e.message) + " @ " + string(_e.stacktrace)) : string(_e);
    if (!variable_struct_exists(_c, "err_last")) _c.err_last = "";
    if (_msg != _c.err_last || _c.frame mod 600 == 0)
    {
        _c.err_last = _msg;
        coop_log("ERROR (recovered): ", _msg);
    }
}

// Test: frame phase marker (-coop_phase), to locate a freeze.
function coop_phase(_name)
{
    if (variable_global_exists("coop_phase_on") && global.coop_phase_on && coop_shared_ready())
    {
        // the current event's name sits in a buffer whose address is logged once: tools/peek.py reads it
        // from the frozen process
        if (!variable_global_exists("coop_phase_buf"))
        {
            global.coop_phase_buf = buffer_create(256, buffer_fixed, 1);
            global.coop_phase_n = 0;
            coop_log("phase buffer at ", string(int64(buffer_get_address(global.coop_phase_buf))));
        }
        global.coop_phase_n++;
        var _b = global.coop_phase_buf;
        buffer_seek(_b, buffer_seek_start, 0);
        buffer_write(_b, buffer_u32, global.coop_phase_n);
        buffer_write(_b, buffer_string, string_copy(_name, 1, 200));
    }
}

// Hook: obj_fog_setup Alarm_1. vertex_freeze() of an EMPTY vertex buffer never returns (the runner spins
// forever). The fog mesh is empty when it was rebuilt (Alarm_0) less than 5 steps before the freeze in a
// place with no walls nearby - after a teleport or entering/leaving a building. Game bug, also solo.
function coop_fog_freeze(_vb)
{
    var _n = vertex_get_number(_vb);
    if (_n <= 0)
    {
        if (coop().test_mode)
        {
            coop_log("fog freeze skipped: empty mesh");
        }
        exit;
    }
    vertex_freeze(_vb);
}
