// ZERO Sievert co-op: transport (UDP for direct/local play, Steam P2P for invites) and message dispatch.

#macro COOP_MSG_HELLO 1
#macro COOP_MSG_WELCOME 2
#macro COOP_MSG_PING 3
#macro COOP_MSG_PONG 4
#macro COOP_MSG_RAID_START 5
#macro COOP_MSG_RAID_STATE 6
#macro COOP_MSG_BYE 7
#macro COOP_MSG_JOIN_REQ 8
#macro COOP_MSG_PSTATE 10
#macro COOP_MSG_PLOADOUT 11
#macro COOP_MSG_BULLET 20
#macro COOP_MSG_NPC_SPAWN 30
#macro COOP_MSG_NPC_SNAP 31
#macro COOP_MSG_NPC_DIE 32
#macro COOP_MSG_NPC_GONE 33
#macro COOP_MSG_NPC_HIT 34
#macro COOP_MSG_DOWN 40
#macro COOP_MSG_REVIVE 41
#macro COOP_MSG_DEAD 42
#macro COOP_MSG_CHEST 50
#macro COOP_MSG_CHEST_REQ 51
#macro COOP_MSG_SETTINGS 60
#macro COOP_MSG_FP 66

function coop_net_start()
{
    var _c = coop();
    if (_c.transport == "udp" && _c.sock < 0)
    {
        if (_c.role == "host")
        {
            _c.sock = network_create_socket_ext(network_socket_udp, COOP_PORT);
        }
        else
        {
            _c.sock = network_create_socket(network_socket_udp);
        }
        coop_log("udp socket ", _c.sock, " role ", _c.role);
    }
    if (_c.transport == "steam")
    {
        steam_net_set_auto_accept_p2p_sessions(true);
        coop_log("steam p2p ready, me=", steam_get_user_steam_id());
    }
}

function coop_net_stop()
{
    var _c = coop();
    if (_c.connected)
    {
        coop_msg_begin(COOP_MSG_BYE);
        coop_msg_send(true);
    }
    if (_c.sock >= 0)
    {
        network_destroy(_c.sock);
        _c.sock = -1;
    }
    if (_c.transport == "steam" && _c.peer_steam != 0)
    {
        steam_net_close_p2p_session(_c.peer_steam);
    }
    if (_c.lobby != 0)
    {
        steam_lobby_leave();
        steam_clear_rich_presence();
        _c.lobby = 0;
    }
    _c.connected = false;
    _c.role = "none";
    _c.transport = "none";
    _c.peer_steam = 0;
    coop_log("network stopped");
}

// ---- outgoing ----

function coop_msg_begin(_type)
{
    var _b = coop().send_buf;
    buffer_seek(_b, buffer_seek_start, 0);
    buffer_write(_b, buffer_u8, _type);
    return _b;
}

function coop_msg_send(_reliable)
{
    var _c = coop();
    var _b = _c.send_buf;
    var _size = buffer_tell(_b);
    if (_c.transport == "udp")
    {
        if (_c.peer_ip != "" && _c.sock >= 0)
        {
            network_send_udp_raw(_c.sock, _c.peer_ip, _c.peer_port, _b, _size);
        }
    }
    else if (_c.transport == "steam")
    {
        if (_c.peer_steam != 0)
        {
            steam_net_packet_set_type(_reliable ? 2 : 1);
            steam_net_packet_send(_c.peer_steam, _b, _size);
        }
    }
    _c.stats_sent++;
}

// ---- incoming ----

// UDP: called from obj_coop Async - Networking.
function coop_net_on_async()
{
    var _c = coop();
    if (_c.transport != "udp")
    {
        exit;
    }
    if (ds_map_find_value(async_load, "id") != _c.sock)
    {
        exit;
    }
    if (ds_map_find_value(async_load, "type") != network_type_data)
    {
        exit;
    }
    var _buf = ds_map_find_value(async_load, "buffer");
    var _size = ds_map_find_value(async_load, "size");
    if (_c.role == "host")
    {
        // Host learns the guest's address from its packets.
        _c.peer_ip = ds_map_find_value(async_load, "ip");
        _c.peer_port = ds_map_find_value(async_load, "port");
    }
    buffer_seek(_buf, buffer_seek_start, 0);
    coop_handle_message(_buf, _size);
}

// Steam: polled every step.
function coop_net_poll_steam()
{
    var _c = coop();
    if (_c.transport != "steam")
    {
        exit;
    }
    var _guard = 0;
    while (steam_net_packet_receive() && _guard < 256)
    {
        _guard++;
        var _size = steam_net_packet_get_size();
        var _sender = steam_net_packet_get_sender_id();
        var _b = _c.recv_buf;
        if (buffer_get_size(_b) < _size)
        {
            buffer_resize(_b, _size);
        }
        steam_net_packet_get_data(_b);
        if (_c.peer_steam == 0 && _c.role == "host")
        {
            _c.peer_steam = _sender;
        }
        if (_sender != _c.peer_steam)
        {
            continue;
        }
        buffer_seek(_b, buffer_seek_start, 0);
        coop_handle_message(_b, _size);
    }
}

function coop_handle_message(_b, _size)
{
    try
    {
        coop_handle_message_inner(_b, _size);
    }
    catch (_e)
    {
        coop_report_error(_e);
    }
}

function coop_handle_message_inner(_b, _size)
{
    var _c = coop();
    _c.last_recv_time = current_time;
    _c.stats_recv++;
    var _type = buffer_read(_b, buffer_u8);
    switch (_type)
    {
        case COOP_MSG_HELLO:
            var _ver = buffer_read(_b, buffer_u16);
            var _name = buffer_read(_b, buffer_string);
            if (_c.role == "host")
            {
                if (_ver != COOP_VERSION)
                {
                    coop_log("guest has mod version ", _ver, ", host has ", COOP_VERSION, " - refused");
                    coop_notify(coop_t("Partner has a different co-op mod version - update both!", "У напарника другая версия кооп-мода - обновитесь оба!"));
                    coop_msg_begin(COOP_MSG_BYE);
                    coop_msg_send(true);
                    break;
                }
                if (!_c.connected)
                {
                    coop_log("guest connected: ", _name);
                    coop_notify(_name + " joined");
                }
                _c.connected = true;
                _c.peer_name = _name;
                coop_msg_begin(COOP_MSG_WELCOME);
                buffer_write(_c.send_buf, buffer_u16, COOP_VERSION);
                buffer_write(_c.send_buf, buffer_string, coop_my_name());
                coop_msg_send(true);
                coop_on_connected();
            }
            break;
        case COOP_MSG_WELCOME:
            var _wver = buffer_read(_b, buffer_u16);
            var _wname = buffer_read(_b, buffer_string);
            if (_c.role == "guest" && !_c.connected && _wver != COOP_VERSION)
            {
                coop_notify(coop_t("Host has a different co-op mod version - update both!", "У хоста другая версия кооп-мода - обновитесь оба!"));
                coop_log("host version ", _wver, " != ", COOP_VERSION);
                break;
            }
            if (_c.role == "guest" && !_c.connected)
            {
                _c.connected = true;
                _c.peer_name = _wname;
                coop_log("connected to host ", _wname, " v", _wver);
                coop_notify("Connected to " + _wname);
                coop_on_connected();
            }
            break;
        case COOP_MSG_PING:
            var _t = buffer_read(_b, buffer_f64);
            coop_msg_begin(COOP_MSG_PONG);
            buffer_write(_c.send_buf, buffer_f64, _t);
            coop_msg_send(false);
            break;
        case COOP_MSG_PONG:
            var _t2 = buffer_read(_b, buffer_f64);
            _c.ping = current_time - _t2;
            break;
        case COOP_MSG_BYE:
            if (!_c.connected)
            {
                coop_log("refused by peer (version?) - stopping");
                coop_net_stop();
                break;
            }
            coop_log("peer left");
            coop_notify(_c.peer_name + " left");
            _c.connected = false;
            _c.peer_in_raid = false;
            coop_on_disconnected();
            break;
        case COOP_MSG_JOIN_REQ:
            coop_on_join_request();
            break;
        case COOP_MSG_RAID_START:
            var _map = buffer_read(_b, buffer_u8);
            var _seed = buffer_read(_b, buffer_f64);
            coop_on_raid_start(_map, _seed);
            break;
        case COOP_MSG_RAID_STATE:
            var _loc = buffer_read(_b, buffer_u8);
            var _pmap = buffer_read(_b, buffer_s8);
            var _rid = buffer_read(_b, buffer_f64);
            var _rdy = buffer_read(_b, buffer_u8);
            var _in = (_loc == 2) && _rid >= 0 && _c.gen_seed != undefined && _rid == _c.gen_seed && coop_in_raid();
            var _was = _c.peer_in_raid;
            if (_c.peer_in_raid != _in)
            {
                coop_log("peer in raid = ", _in, " map ", _pmap);
            }
            _c.peer_in_raid = _in;
            var _became_ready = _in && _rdy && !_c.peer_ready;
            _c.peer_ready = _in && _rdy;
            if (_became_ready)
            {
                coop_log("peer map ready");
                coop_on_peer_ready();
            }
            if (_c.peer_loc != _loc && _loc == 2 && _c.role == "guest" && is_in_hub())
            {
                coop_notify(coop_t(_c.peer_name + " is in a raid - F7 to join", _c.peer_name + " в рейде - F7, чтобы присоединиться"));
            }
            _c.peer_loc = _loc;
            _c.peer_hub_ready = (_loc == 1);
            _c.peer_map = _pmap;
            if (!_in)
            {
                coop_puppet_remove();
                if (_was && _c.role == "guest")
                {
                    coop_npc_guest_release();
                    coop_notify(coop_t(_c.peer_name + " left the raid", _c.peer_name + " покинул рейд"));
                }
            }
            break;
        case COOP_MSG_PSTATE:
            coop_puppet_on_state(_b);
            break;
        case COOP_MSG_ARMS:
            coop_puppet_on_arms(_b);
            break;
        case COOP_MSG_PLOADOUT:
            coop_puppet_on_loadout(_b);
            break;
        case COOP_MSG_BULLET:
            coop_bullet_on_message(_b);
            break;
        case COOP_MSG_GRENADE:
            coop_grenade_on_message(_b);
            break;
        case COOP_MSG_NPC_SPAWN:
            coop_npc_on_spawn(_b);
            break;
        case COOP_MSG_NPC_SNAP:
            coop_npc_on_snap(_b);
            break;
        case COOP_MSG_NPC_DIE:
            coop_npc_on_die(_b);
            break;
        case COOP_MSG_NPC_GONE:
            coop_npc_on_gone(_b);
            break;
        case COOP_MSG_NPC_STATESTR:
            coop_npc_on_statestr(_b);
            break;
        case COOP_MSG_NPC_HIT:
            coop_npc_on_hit(_b);
            break;
        case COOP_MSG_DOWN:
        case COOP_MSG_REVIVE:
        case COOP_MSG_DEAD:
            coop_down_on_message(_type, _b);
            break;
        case COOP_MSG_CHEST:
            coop_chest_on_message(_b);
            break;
        case COOP_MSG_CHEST_SPAWN:
            coop_chest_on_spawn(_b);
            break;
        case COOP_MSG_CHEST_GONE:
            coop_chest_on_gone(_b);
            break;
        case COOP_MSG_CHEST_REQ:
            coop_chest_on_request(_b);
            break;
        case COOP_MSG_WORLD_TIME:
            coop_world_on_time(_b);
            break;
        case COOP_MSG_WEATHER:
            coop_world_on_weather(_b);
            break;
        case COOP_MSG_EMISSION:
            coop_world_on_emission(_b);
            break;
        case COOP_MSG_CREDIT:
            coop_credit_on_message(_b);
            break;
        case COOP_MSG_DOOR:
            coop_door_on_message(_b);
            break;
        case COOP_MSG_FP:
            coop_diag_on_fp(_b);
            break;
        case COOP_MSG_SETTINGS:
            coop_settings_on_message(_b);
            break;
    }
}

function coop_my_name()
{
    if (steam_initialised())
    {
        return steam_get_persona_name();
    }
    return "Player";
}

// ---- per-frame driver (obj_coop Step) ----

function coop_net_step()
{
    var _c = coop();
    _c.frame++;
    if (_c.role == "none")
    {
        exit;
    }
    coop_net_poll_steam();
    // Guest keeps saying hello until welcomed.
    if (_c.role == "guest" && !_c.connected && current_time - _c.last_hello_time > 1000)
    {
        _c.last_hello_time = current_time;
        coop_msg_begin(COOP_MSG_HELLO);
        buffer_write(_c.send_buf, buffer_u16, COOP_VERSION);
        buffer_write(_c.send_buf, buffer_string, coop_my_name());
        coop_msg_send(true);
    }
    if (_c.connected)
    {
        if (_c.frame mod 60 == 0)
        {
            coop_msg_begin(COOP_MSG_PING);
            buffer_write(_c.send_buf, buffer_f64, current_time);
            coop_msg_send(false);
            coop_send_raid_state();
        }
        if (current_time - _c.last_recv_time > 15000)
        {
            coop_log("connection timed out");
            coop_notify("Connection to " + _c.peer_name + " lost");
            _c.connected = false;
            _c.peer_in_raid = false;
            coop_on_disconnected();
        }
    }
}

function coop_send_raid_state()
{
    var _c = coop();
    coop_msg_begin(COOP_MSG_RAID_STATE);
    var _in = coop_in_raid() && (instance_exists(obj_player) || _c.local_paused);
    var _loc = _in ? 2 : ((is_in_hub() && instance_exists(obj_player)) ? 1 : 0);
    buffer_write(_c.send_buf, buffer_u8, _loc);
    buffer_write(_c.send_buf, buffer_s8, _in ? obj_map_generator.area : -1);
    buffer_write(_c.send_buf, buffer_f64, (_in && _c.gen_seed != undefined) ? _c.gen_seed : -1);
    buffer_write(_c.send_buf, buffer_u8, coop_raid_ready());
    coop_msg_send(true);
}

function coop_on_connected()
{
    var _c = coop();
    _c.last_recv_time = current_time;
    coop_send_raid_state();
    coop_settings_send();
    coop_send_loadout();
}

function coop_on_disconnected()
{
    coop_puppet_remove();
    coop_npc_guest_release();
}

// ---- notifications (top-left list in obj_coop Draw GUI) ----

function coop_notify(_text)
{
    var _c = coop();
    if (!variable_struct_exists(_c, "notes"))
    {
        _c.notes = [];
    }
    array_push(_c.notes, { text: _text, t_end: current_time + 5000 });
}
