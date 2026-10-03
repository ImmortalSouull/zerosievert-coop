// ZERO Sievert co-op: core state, command line, logging, test-mode helpers.

#macro COOP_VERSION 1
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
            case "-coop_bot":
                _c.bot = true;
                break;
            case "-coop_quiet":
                _c.overlay = false;
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

// Guest in a shared raid: NPCs are replicas driven by the host.
function coop_guest_in_raid()
{
    var _c = coop();
    return _c.role == "guest" && coop_shared_ready();
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

// Both players are in the same raid and both maps are finished.
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
    if (_c.test_mode)
    {
        // Tests run unattended: log crashes instead of blocking on the error dialog.
        exception_unhandled_handler(function(_e)
        {
            coop_log("CRASH: ", _e.longMessage, " | ", _e.stacktrace);
            return 0;
        });
    }
    coop_log("boot, steam=", steam_initialised());
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
// Keep the co-op controller alive, and on the host keep the area around the partner simulated.
function coop_after_culling()
{
    instance_activate_object(obj_coop);
    var _c = coop();
    if (_c.connected)
    {
        instance_activate_object(obj_player_parent);
        var _p = coop_partner();
        if (instance_exists(_p) && _c.role == "host")
        {
            instance_activate_region(_p.x - 480, _p.y - 270, 960, 540, true);
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
