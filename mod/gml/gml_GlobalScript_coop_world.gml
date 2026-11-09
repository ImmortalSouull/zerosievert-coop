// ZERO Sievert co-op: shared world state in a raid - time of day, weather, emissions (blowouts), air drops.
// Each save has its own clock and weather; in a shared raid the raid owner's world is the truth and every other
// player follows it (coop_world_slave): they never roll their own weather, emissions or air drops.

#macro COOP_MSG_WORLD_TIME 61
#macro COOP_MSG_WEATHER 62
#macro COOP_MSG_EMISSION 63

// Guest whose world follows the host right now: in a shared raid, and in the bunker while the host is in its
// bunker too (live report 2026-11-06: one player had fog in the bunker, the other not).
function coop_world_slave()
{
    var _c = coop();
    return coop_is_world_replica() || coop_world_hub_slave();
}

function coop_world_hub_slave()
{
    var _c = coop();
    return _c.role == "guest" && _c.connected && is_in_hub() && _c.peer_loc == 1;
}

function coop_world_step()
{
    var _c = coop();
    // the session host's bunker sets the bunker weather for everyone in theirs
    var _hub = _c.role == "host" && _c.connected && is_in_hub();
    if (!(coop_is_world_owner() || _hub) || !instance_exists(obj_light_controller))
    {
        exit;
    }
    if (_c.frame mod 300 == 0)
    {
        coop_world_send_time();
    }
    if (variable_global_exists("weather") && is_struct(global.weather))
    {
        // also every 5 s (applied only when changed): a guest who just came back from a raid gets the bunker weather,
        // and in a raid a guest who dropped the map-ready send (it came before the guest knew the raid owner, live
        // report 2026-11-09: fog for the guest, sun for the host until the next game hour) gets it a moment later
        if (!variable_struct_exists(_c, "weather_hour_sent") || _c.weather_hour_sent != global.weather.last_generated_hour || _c.frame mod 300 == 150)
        {
            _c.weather_hour_sent = global.weather.last_generated_hour;
            coop_world_send_weather();
        }
    }
}

function coop_world_send_time()
{
    var _c = coop();
    coop_msg_begin(COOP_MSG_WORLD_TIME);
    buffer_write(_c.send_buf, buffer_f64, obj_light_controller.game_time_played);
    coop_msg_send(true);
}

function coop_world_send_weather()
{
    var _c = coop();
    coop_msg_begin(COOP_MSG_WEATHER);
    buffer_write(_c.send_buf, buffer_string, json_stringify(global.weather));
    coop_msg_send(true);
}

// Host: everything a freshly loaded guest needs (called when the guest's map is ready).
function coop_world_sync_peer()
{
    var _c = coop();
    if (!coop_is_world_owner() || !instance_exists(obj_light_controller))
    {
        exit;
    }
    coop_world_send_time();
    if (variable_global_exists("weather") && is_struct(global.weather))
    {
        coop_world_send_weather();
    }
    if (variable_global_exists("state_emission_now") && global.state_emission_now > 0)
    {
        coop_world_send_emission();
    }
}

function coop_world_on_time(_b)
{
    var _t = buffer_read(_b, buffer_f64);
    if (!coop_world_slave() || !instance_exists(obj_light_controller))
    {
        exit;
    }
    obj_light_controller.game_time_played = _t;
}

function coop_world_on_weather(_b)
{
    var _json = buffer_read(_b, buffer_string);
    if (!coop_world_slave() || !instance_exists(obj_meteo_controller))
    {
        exit;
    }
    var _c = coop();
    if (variable_struct_exists(_c, "weather_json_in") && _c.weather_json_in == _json)
    {
        exit; // the periodic resend of a weather we already show
    }
    _c.weather_json_in = _json;
    global.weather = json_parse(_json);
    with (obj_meteo_controller)
    {
        part_smoother_now = 0;
        weather_transition(pp_transition, false);
        weather_assign_wind_values();
    }
    coop_log("weather synced from host (hour ", global.weather.last_generated_hour, ", raid=", is_in_raid() ? 1 : 0, ", now ", weather_get_weather_now(), ")");
}

// Hook: top of obj_meteo_controller Alarm_1 (an emission stage starts/advances).
function coop_world_on_emission_stage()
{
    var _c = coop();
    if (coop_is_world_owner() && global.state_emission_now == 0)
    {
        coop_world_send_emission();
    }
}

function coop_world_send_emission()
{
    var _c = coop();
    coop_msg_begin(COOP_MSG_EMISSION);
    buffer_write(_c.send_buf, buffer_u8, global.state_emission_now);
    coop_msg_send(true);
    coop_log("emission start sent");
}

function coop_world_on_emission(_b)
{
    var _stage = buffer_read(_b, buffer_u8);
    if (!coop_world_slave() || !instance_exists(obj_meteo_controller))
    {
        exit;
    }
    if (global.state_emission_now == 0 && !global.is_emission_now)
    {
        with (obj_meteo_controller)
        {
            alarm[0] = 2;
            alarm[1] = 1;
        }
        coop_log("emission started by host");
    }
}

// Hook: top of obj_meteo_controller Alarm_2 (the emission roll) and obj_controller Alarm_3 (air drop roll).
// A connected guest in a raid never rolls these itself - the host decides for both.
function coop_world_guest_skips_roll()
{
    var _c = coop();
    // replicas never roll world events; while the maps are still loading, the session host's raid decides
    return coop_is_world_replica() || (_c.role == "guest" && _c.connected && coop_in_raid() && !coop_shared_ready() && _c.peer_loc == 2);
}
