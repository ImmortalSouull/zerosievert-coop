// ZERO Sievert co-op: shared world state in a raid - time of day, weather, emissions (blowouts), air drops.
// Each save has its own clock and weather; in a shared raid the host's world is the truth.

#macro COOP_MSG_WORLD_TIME 61
#macro COOP_MSG_WEATHER 62
#macro COOP_MSG_EMISSION 63

// Guest whose world follows the host right now.
function coop_world_slave()
{
    var _c = coop();
    return coop_is_world_replica();
}

function coop_world_step()
{
    var _c = coop();
    if (!coop_is_world_owner() || !instance_exists(obj_light_controller))
    {
        exit;
    }
    if (_c.frame mod 300 == 0)
    {
        coop_world_send_time();
    }
    if (variable_global_exists("weather") && is_struct(global.weather))
    {
        if (!variable_struct_exists(_c, "weather_hour_sent") || _c.weather_hour_sent != global.weather.last_generated_hour)
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
    global.weather = json_parse(_json);
    with (obj_meteo_controller)
    {
        part_smoother_now = 0;
        weather_transition(pp_transition, false);
        weather_assign_wind_values();
    }
    coop_log("weather synced from host (hour ", global.weather.last_generated_hour, ")");
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
