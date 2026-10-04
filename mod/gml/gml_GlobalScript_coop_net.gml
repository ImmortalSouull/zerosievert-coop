// ZERO Sievert co-op: transport and message dispatch for up to 4 players.
//
// Star topology: the host (slot 0) owns the world; every guest (slots 1..3) talks only to the host, which
// relays guest messages meant for everybody. Every packet:
//   [u8 kind][u16 seq][u8 from][u8 to][u8 reserved] + payload ([u8 type] + data)
//   kind 0 = unreliable, 1 = reliable (UDP: numbered, acked, resent, delivered in order), 2 = ack (seq =
//   last in-order seq received). Steam P2P has its own reliable mode, so Steam packets are always kind 0.
//   from/to are slots; to = 255 means everybody.
// Handlers read the payload exactly as before; coop().msg_from is the sender's slot.
// -coop_netsim <latency ms>,<loss %>,<jitter ms> (test) delays/drops outgoing UDP packets.

#macro COOP_MSG_HELLO 1
#macro COOP_MSG_WELCOME 2
#macro COOP_MSG_PING 3
#macro COOP_MSG_PONG 4
#macro COOP_MSG_RAID_START 5
#macro COOP_MSG_RAID_STATE 6
#macro COOP_MSG_BYE 7
#macro COOP_MSG_JOIN_REQ 8
#macro COOP_MSG_ROSTER 9
#macro COOP_MSG_REJOIN 14
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
#macro COOP_MAX_PLAYERS 4
#macro COOP_HDR 6
#macro COOP_ALL 255

// ---- peers ----

function coop_peer_new(_slot)
{
    return {
        slot: _slot,
        name: "Player",
        ip: "",
        port: 0,
        steam: 0,
        connected: false,
        hello: false,
        last_recv: current_time,
        ping: 0,
        in_raid: false,
        ready: false,
        loc: 0,
        map: -1,
        fp: undefined,
        // reliability (UDP)
        tx_seq: 0,
        tx_queue: [],
        rx_expect: 0,
        rx_buf: ds_map_create(),
        ack_due: false
    };
}

function coop_peer_free(_p)
{
    if (!is_struct(_p))
    {
        exit;
    }
    var _q = _p.tx_queue;
    for (var _i = 0; _i < array_length(_q); _i++)
    {
        buffer_delete(_q[_i].buf);
    }
    _p.tx_queue = [];
    var _k = ds_map_find_first(_p.rx_buf);
    while (_k != undefined)
    {
        buffer_delete(ds_map_find_value(_p.rx_buf, _k));
        _k = ds_map_find_next(_p.rx_buf, _k);
    }
    ds_map_destroy(_p.rx_buf);
}

function coop_peers()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "peers"))
    {
        _c.peers = array_create(COOP_MAX_PLAYERS, undefined);
        _c.slot = -1;
        _c.msg_from = 0;
        _c.msg_dest = COOP_ALL;
        if (!variable_struct_exists(_c, "netsim"))
        {
            _c.netsim = undefined;
        }
        _c.netsim_q = [];
        _c.netsim_rng = 12345;
    }
    return _c.peers;
}

function coop_peer(_slot)
{
    if (_slot < 0 || _slot >= COOP_MAX_PLAYERS)
    {
        return undefined;
    }
    var _ps = coop_peers();
    return _ps[_slot];
}

// Connected remote players (structs), excluding us.
function coop_remote_peers()
{
    var _c = coop();
    var _ps = coop_peers();
    var _out = [];
    for (var _i = 0; _i < COOP_MAX_PLAYERS; _i++)
    {
        var _p = _ps[_i];
        if (_i != _c.slot && is_struct(_p) && _p.connected)
        {
            array_push(_out, _p);
        }
    }
    return _out;
}

function coop_player_count()
{
    var _c = coop();
    return variable_struct_exists(_c, "player_count") ? _c.player_count : 1; // kept by coop_peers_refresh
}

function coop_peer_name(_slot)
{
    var _p = coop_peer(_slot);
    return is_struct(_p) ? _p.name : "Player";
}

// The game's player index (mp_index) of a slot's character on this machine: we are always 0.
function coop_mp_of(_slot)
{
    var _c = coop();
    return (_slot - max(0, _c.slot) + COOP_MAX_PLAYERS) mod COOP_MAX_PLAYERS;
}

function coop_slot_of_mp(_mp)
{
    var _c = coop();
    return (_mp + max(0, _c.slot)) mod COOP_MAX_PLAYERS;
}

// Legacy single-partner view used by older code paths: kept in sync from the peer list.
function coop_peers_refresh()
{
    var _c = coop();
    var _r = coop_remote_peers();
    _c.connected = array_length(_r) > 0;
    _c.player_count = array_length(_r) + 1;
    var _any_in = false;
    var _any_ready = false;
    var _host_like = undefined;
    for (var _i = 0; _i < array_length(_r); _i++)
    {
        var _p = _r[_i];
        _any_in |= _p.in_raid;
        _any_ready |= _p.ready;
        if (_host_like == undefined || _p.slot == 0)
        {
            _host_like = _p;
        }
    }
    if (_c.role == "guest")
    {
        var _h = coop_peer(0);
        _host_like = (is_struct(_h) && _h.connected) ? _h : undefined;
    }
    if (_host_like != undefined)
    {
        _c.peer_name = _host_like.name;
        _c.peer_loc = _host_like.loc;
        _c.peer_map = _host_like.map;
        _c.peer_hub_ready = (_host_like.loc == 1);
        _c.ping = _host_like.ping;
    }
    // anybody else in our raid (the host may have extracted while other players stay)
    _c.peer_in_raid = _any_in;
    _c.peer_ready = _any_ready;
    if (_c.role == "host")
    {
        var _all_hub = array_length(_r) > 0;
        for (var _i = 0; _i < array_length(_r); _i++)
        {
            _all_hub &= (_r[_i].loc == 1);
        }
        _c.peer_hub_ready = _all_hub;
    }
}

// Guest: (re)start talking to the host from scratch - first connection, or after the host was lost.
function coop_guest_reset_host()
{
    var _c = coop();
    var _ps = coop_peers();
    var _steam = is_struct(_ps[0]) ? _ps[0].steam : 0;
    for (var _i = 0; _i < COOP_MAX_PLAYERS; _i++)
    {
        if (is_struct(_ps[_i]))
        {
            coop_peer_free(_ps[_i]);
            _ps[_i] = undefined;
        }
    }
    var _h = coop_peer_new(0);
    _h.ip = _c.peer_ip;
    _h.port = _c.peer_port;
    _h.steam = (_steam != 0) ? _steam : _c.peer_steam;
    _ps[0] = _h;
    _c.slot = -1;
    coop_peers_refresh();
}

// ---- start / stop ----

function coop_net_start()
{
    var _c = coop();
    coop_peers();
    if (_c.role == "host")
    {
        _c.slot = 0;
        if (!is_struct(_c.peers[0]))
        {
            _c.peers[0] = coop_peer_new(0);
        }
        var _me = _c.peers[0];
        _me.name = coop_my_name();
    }
    if (_c.role == "guest")
    {
        coop_guest_reset_host();
    }
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
        coop_net_flush_now();
    }
    if (_c.sock >= 0)
    {
        network_destroy(_c.sock);
        _c.sock = -1;
    }
    var _ps = coop_peers();
    for (var _i = 0; _i < COOP_MAX_PLAYERS; _i++)
    {
        var _p = _ps[_i];
        if (is_struct(_p))
        {
            if (_c.transport == "steam" && _p.steam != 0)
            {
                steam_net_close_p2p_session(_p.steam);
            }
            coop_peer_free(_p);
        }
        _ps[_i] = undefined;
    }
    if (_c.lobby != 0)
    {
        steam_lobby_leave();
        steam_clear_rich_presence();
        _c.lobby = 0;
    }
    coop_puppet_remove_all();
    _c.connected = false;
    _c.role = "none";
    _c.transport = "none";
    _c.peer_steam = 0;
    _c.slot = -1;
    _c.peer_in_raid = false;
    _c.peer_ready = false;
    _c.player_count = 1;
    coop_log("network stopped");
}

// ---- outgoing ----

// Payload starts after the header; handlers that save/restore send_buf copy it whole.
function coop_msg_begin(_type)
{
    var _b = coop().send_buf;
    buffer_seek(_b, buffer_seek_start, COOP_HDR);
    buffer_write(_b, buffer_u8, _type);
    return _b;
}

// Send the message being built to everybody (or to coop().msg_dest when a caller narrowed it).
function coop_msg_send(_reliable)
{
    var _c = coop();
    coop_msg_send_to(_c.msg_dest, _reliable);
}

function coop_msg_send_to(_to, _reliable)
{
    var _c = coop();
    var _b = _c.send_buf;
    var _size = buffer_tell(_b);
    var _me = max(0, _c.slot);
    if (_c.role == "host")
    {
        var _ps = coop_peers();
        for (var _i = 1; _i < COOP_MAX_PLAYERS; _i++)
        {
            var _p = _ps[_i];
            if (is_struct(_p) && (_p.connected || _p.hello) && (_to == COOP_ALL || _to == _i))
            {
                coop_packet_send(_p, _b, _size, _reliable, _me, _to);
            }
        }
    }
    else if (_c.role == "guest")
    {
        var _h = coop_peer(0);
        if (is_struct(_h))
        {
            coop_packet_send(_h, _b, _size, _reliable, _me, _to);
        }
    }
    _c.stats_sent++;
}

// One hop to one peer. _b holds header space + payload; the header is (re)written here.
function coop_packet_send(_p, _b, _size, _reliable, _from, _to)
{
    var _c = coop();
    var _kind = (_reliable && _c.transport == "udp") ? 1 : 0;
    var _seq = 0;
    if (_kind == 1)
    {
        _seq = _p.tx_seq;
        _p.tx_seq = (_p.tx_seq + 1) mod 65536;
    }
    var _end = buffer_tell(_b);
    buffer_seek(_b, buffer_seek_start, 0);
    buffer_write(_b, buffer_u8, _kind);
    buffer_write(_b, buffer_u16, _seq);
    buffer_write(_b, buffer_u8, _from);
    buffer_write(_b, buffer_u8, _to);
    buffer_write(_b, buffer_u8, 0);
    buffer_seek(_b, buffer_seek_start, _end);
    if (_kind == 1)
    {
        var _copy = buffer_create(_size, buffer_fixed, 1);
        buffer_copy(_b, 0, _size, _copy, 0);
        array_push(_p.tx_queue, { seq: _seq, buf: _copy, size: _size, t: current_time, tries: 1 });
    }
    coop_raw_send(_p, _b, _size, _reliable);
}

function coop_raw_send(_p, _b, _size, _reliable)
{
    var _c = coop();
    if (_c.transport == "udp")
    {
        if (_p.ip == "" || _c.sock < 0)
        {
            exit;
        }
        if (_c.netsim != undefined)
        {
            coop_netsim_send(_p, _b, _size);
            exit;
        }
        network_send_udp_raw(_c.sock, _p.ip, _p.port, _b, _size);
    }
    else if (_c.transport == "steam")
    {
        if (_p.steam == 0)
        {
            exit;
        }
        steam_net_packet_set_type(_reliable ? 2 : 1);
        steam_net_packet_send(_p.steam, _b, _size);
    }
}

// ---- network simulator (test) ----

function coop_netsim_rand()
{
    var _c = coop();
    _c.netsim_rng = (_c.netsim_rng * 1103515245 + 12345) mod 2147483648;
    return _c.netsim_rng / 2147483648;
}

function coop_netsim_send(_p, _b, _size)
{
    var _c = coop();
    var _ns = _c.netsim;
    // blackout window (seconds after the raid map is ready): the link is cut completely
    if (_ns.black_dur > 0 && variable_struct_exists(_c, "ready_time") && _c.ready_time > 0)
    {
        var _ts = (current_time - _c.ready_time) / 1000;
        if (_ts >= _ns.black_at && _ts < _ns.black_at + _ns.black_dur)
        {
            _ns.dropped++;
            if (!_ns.black_logged)
            {
                _ns.black_logged = true;
                coop_log("netsim: blackout for ", _ns.black_dur, " s");
            }
            exit;
        }
    }
    if (coop_netsim_rand() * 100 < _ns.loss)
    {
        _ns.dropped++;
        exit;
    }
    var _copy = buffer_create(_size, buffer_fixed, 1);
    buffer_copy(_b, 0, _size, _copy, 0);
    var _due = current_time + _ns.lat + coop_netsim_rand() * _ns.jitter;
    array_push(_c.netsim_q, { due: _due, buf: _copy, size: _size, ip: _p.ip, port: _p.port });
}

function coop_netsim_flush()
{
    var _c = coop();
    var _q = _c.netsim_q;
    var _n = array_length(_q);
    if (_n == 0)
    {
        exit;
    }
    var _keep = [];
    for (var _i = 0; _i < _n; _i++)
    {
        var _e = _q[_i];
        if (current_time >= _e.due || _c.sock < 0)
        {
            if (_c.sock >= 0)
            {
                network_send_udp_raw(_c.sock, _e.ip, _e.port, _e.buf, _e.size);
            }
            buffer_delete(_e.buf);
        }
        else
        {
            array_push(_keep, _e);
        }
    }
    _c.netsim_q = _keep;
}

function coop_net_flush_now()
{
    var _c = coop();
    if (_c.netsim != undefined)
    {
        var _q = _c.netsim_q;
        for (var _i = 0; _i < array_length(_q); _i++)
        {
            _q[_i].due = 0;
        }
        coop_netsim_flush();
    }
}

// ---- incoming ----

// UDP: obj_coop Async - Networking.
function coop_net_on_async()
{
    var _c = coop();
    if (_c.transport != "udp" || ds_map_find_value(async_load, "id") != _c.sock || ds_map_find_value(async_load, "type") != network_type_data)
    {
        exit;
    }
    var _buf = ds_map_find_value(async_load, "buffer");
    var _size = ds_map_find_value(async_load, "size");
    var _ip = ds_map_find_value(async_load, "ip");
    var _port = ds_map_find_value(async_load, "port");
    var _p = undefined;
    if (_c.role == "guest")
    {
        _p = coop_peer(0);
    }
    else
    {
        _p = coop_peer_find_udp(_ip, _port);
        if (_p == undefined)
        {
            _p = coop_peer_alloc();
            if (_p == undefined)
            {
                exit; // full
            }
            _p.ip = _ip;
            _p.port = _port;
        }
    }
    if (_p == undefined)
    {
        exit;
    }
    coop_net_on_packet(_p, _buf, _size);
}

function coop_peer_find_udp(_ip, _port)
{
    var _ps = coop_peers();
    for (var _i = 1; _i < COOP_MAX_PLAYERS; _i++)
    {
        var _p = _ps[_i];
        if (is_struct(_p) && _p.ip == _ip && _p.port == _port)
        {
            return _p;
        }
    }
    return undefined;
}

function coop_peer_find_steam(_id)
{
    var _ps = coop_peers();
    for (var _i = 0; _i < COOP_MAX_PLAYERS; _i++)
    {
        var _p = _ps[_i];
        if (is_struct(_p) && _p.steam == _id)
        {
            return _p;
        }
    }
    return undefined;
}

// Host: a free slot for a new endpoint (it becomes a player only after a valid HELLO).
function coop_peer_alloc()
{
    var _ps = coop_peers();
    for (var _i = 1; _i < COOP_MAX_PLAYERS; _i++)
    {
        if (!is_struct(_ps[_i]))
        {
            var _p = coop_peer_new(_i);
            _p.hello = false;
            _ps[_i] = _p;
            return _p;
        }
    }
    return undefined;
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
    while (steam_net_packet_receive() && _guard < 512)
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
        var _p = coop_peer_find_steam(_sender);
        if (_p == undefined)
        {
            if (_c.role != "host")
            {
                continue; // guests only listen to the host
            }
            _p = coop_peer_alloc();
            if (_p == undefined)
            {
                continue;
            }
            _p.steam = _sender;
        }
        coop_net_on_packet(_p, _b, _size);
    }
}

// Raw packet from a known endpoint: reliability layer, then delivery.
function coop_net_on_packet(_p, _b, _size)
{
    var _c = coop();
    if (_size < COOP_HDR + 1 && _size != COOP_HDR)
    {
        exit;
    }
    buffer_seek(_b, buffer_seek_start, 0);
    var _kind = buffer_read(_b, buffer_u8);
    var _seq = buffer_read(_b, buffer_u16);
    _p.last_recv = current_time;
    _c.last_recv_time = current_time;
    if (_kind == 2)
    {
        coop_net_on_ack(_p, _seq);
        exit;
    }
    if (_kind == 1)
    {
        _p.ack_due = true;
        var _d = (_seq - _p.rx_expect + 65536) mod 65536;
        if (_d >= 32768)
        {
            exit; // duplicate of something already delivered
        }
        if (_d > 0)
        {
            // arrived early: keep until the gap is filled
            if (!ds_map_exists(_p.rx_buf, _seq))
            {
                var _copy = buffer_create(_size, buffer_fixed, 1);
                buffer_copy(_b, 0, _size, _copy, 0);
                ds_map_add(_p.rx_buf, _seq, _copy);
            }
            exit;
        }
        _p.rx_expect = (_p.rx_expect + 1) mod 65536;
        coop_net_deliver(_p, _b, _size);
        while (ds_map_exists(_p.rx_buf, _p.rx_expect))
        {
            var _nb = ds_map_find_value(_p.rx_buf, _p.rx_expect);
            ds_map_delete(_p.rx_buf, _p.rx_expect);
            _p.rx_expect = (_p.rx_expect + 1) mod 65536;
            coop_net_deliver(_p, _nb, buffer_get_size(_nb));
            buffer_delete(_nb);
        }
        exit;
    }
    coop_net_deliver(_p, _b, _size);
}

function coop_net_on_ack(_p, _seq)
{
    var _q = _p.tx_queue;
    var _keep = [];
    for (var _i = 0; _i < array_length(_q); _i++)
    {
        var _e = _q[_i];
        if ((_seq - _e.seq + 65536) mod 65536 < 32768)
        {
            buffer_delete(_e.buf);
        }
        else
        {
            array_push(_keep, _e);
        }
    }
    _p.tx_queue = _keep;
}

// Header -> routing (host relays) -> handler.
function coop_net_deliver(_p, _b, _size)
{
    var _c = coop();
    buffer_seek(_b, buffer_seek_start, 3);
    var _from = buffer_read(_b, buffer_u8);
    var _to = buffer_read(_b, buffer_u8);
    buffer_seek(_b, buffer_seek_start, COOP_HDR);
    if (_size <= COOP_HDR)
    {
        exit;
    }
    var _type = buffer_peek(_b, COOP_HDR, buffer_u8);
    if (_c.role == "host")
    {
        _from = _p.slot; // a guest can only speak for itself
        if (_type != COOP_MSG_HELLO && !_p.connected)
        {
            // a guest we dropped (timeout) still talks to us: tell it to say hello again, once a second
            if (!variable_struct_exists(_p, "rejoin_t") || current_time - _p.rejoin_t > 1000)
            {
                _p.rejoin_t = current_time;
                _p.hello = true;
                coop_msg_begin(COOP_MSG_REJOIN);
                coop_msg_send_to(_p.slot, false);
                _p.hello = false;
            }
            exit;
        }
        if (_to != 0 && (_to != COOP_ALL || coop_net_relayable(_type)))
        {
            coop_net_relay(_p.slot, _to, _b, _size, (buffer_peek(_b, 0, buffer_u8) == 1) || coop_net_reliable_type(_type));
        }
        if (_to != 0 && _to != COOP_ALL)
        {
            exit; // meant for another guest only
        }
    }
    _c.msg_from = _from;
    coop_handle_message(_b, _size);
}

// Guest -> everybody messages the host forwards to the other guests.
function coop_net_relayable(_type)
{
    switch (_type)
    {
        case COOP_MSG_HELLO:
        case COOP_MSG_WELCOME:
        case COOP_MSG_PING:
        case COOP_MSG_PONG:
        case COOP_MSG_BYE:
        case COOP_MSG_JOIN_REQ:
        case COOP_MSG_NPC_HIT:
        case COOP_MSG_CHEST_REQ:
        case COOP_MSG_FP:
        case COOP_MSG_ROSTER:
        case COOP_MSG_REJOIN:
            return false;
    }
    return true;
}

// Steam relays need the original reliability (UDP kind is visible in the header).
function coop_net_reliable_type(_type)
{
    return _type != COOP_MSG_PSTATE && _type != COOP_MSG_NPC_SNAP && _type != COOP_MSG_PING && _type != COOP_MSG_PONG && _type != COOP_MSG_BULLET && _type != COOP_MSG_PSND;
}

function coop_net_relay(_from, _to, _b, _size, _reliable)
{
    var _c = coop();
    if (!variable_struct_exists(_c, "relay_buf"))
    {
        _c.relay_buf = buffer_create(256, buffer_grow, 1);
    }
    var _out = _c.relay_buf;
    buffer_copy(_b, 0, _size, _out, 0);
    buffer_seek(_out, buffer_seek_start, _size);
    var _ps = coop_peers();
    for (var _i = 1; _i < COOP_MAX_PLAYERS; _i++)
    {
        var _p = _ps[_i];
        if (_i != _from && is_struct(_p) && _p.connected && (_to == COOP_ALL || _to == _i))
        {
            coop_packet_send(_p, _out, _size, _reliable, _from, _to);
        }
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
    _c.stats_recv++;
    var _from = _c.msg_from;
    var _fp = coop_peer(_from);
    var _type = buffer_read(_b, buffer_u8);
    switch (_type)
    {
        case COOP_MSG_HELLO:
            coop_net_on_hello(_b);
            break;
        case COOP_MSG_WELCOME:
            coop_net_on_welcome(_b);
            break;
        case COOP_MSG_ROSTER:
            coop_net_on_roster(_b);
            break;
        case COOP_MSG_REJOIN:
            if (_c.role == "guest" && _c.connected)
            {
                coop_log("host lost us - reconnecting");
                coop_notify(coop_t("Reconnecting...", "Переподключение..."));
                coop_peer_left(0, true);
            }
            break;
        case COOP_MSG_PING:
            var _t = buffer_read(_b, buffer_f64);
            coop_msg_begin(COOP_MSG_PONG);
            buffer_write(_c.send_buf, buffer_f64, _t);
            coop_msg_send_to(_from, false);
            break;
        case COOP_MSG_PONG:
            var _t2 = buffer_read(_b, buffer_f64);
            if (is_struct(_fp))
            {
                _fp.ping = current_time - _t2;
            }
            coop_peers_refresh();
            break;
        case COOP_MSG_BYE:
            if (_c.role == "guest" && !_c.connected)
            {
                coop_log("refused by host (version or full) - stopping");
                coop_notify(coop_t("The host refused the connection (different mod version or full)", "Хост отклонил подключение (другая версия мода или нет мест)"));
                coop_net_stop();
                break;
            }
            coop_peer_left(_from, false);
            break;
        case COOP_MSG_JOIN_REQ:
            coop_on_join_request(_from);
            break;
        case COOP_MSG_RAID_START:
            var _map = buffer_read(_b, buffer_u8);
            var _seed = buffer_read(_b, buffer_f64);
            if (_from == 0 || (variable_struct_exists(_c, "join_target") && _from == _c.join_target))
            {
                coop_on_raid_start(_map, _seed);
            }
            break;
        case COOP_MSG_RAID_STATE:
            coop_net_on_raid_state(_from, _b);
            break;
        case COOP_MSG_PSTATE:
            coop_puppet_on_state(_b);
            break;
        case COOP_MSG_BASE:
            coop_base_on_msg(_b);
            break;
        case COOP_MSG_VISIT:
            coop_visit_on_msg(_b);
            break;
        case COOP_MSG_PSND:
            coop_puppet_on_sound(_b);
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
        case COOP_MSG_MARK:
            coop_mark_on_message(_b);
            break;
        case COOP_MSG_GIVE:
            coop_give_on_message(_b);
            break;
        case COOP_MSG_NPC_CHECK:
            coop_npc_on_check(_b);
            break;
        case COOP_MSG_NPC_MISSING:
            coop_npc_on_missing(_b);
            break;
        case COOP_MSG_SETTINGS:
            coop_settings_on_message(_b);
            break;
    }
}

// ---- session ----

// Host: a guest says hello (repeated every second until welcomed).
function coop_net_on_hello(_b)
{
    var _c = coop();
    var _ver = buffer_read(_b, buffer_u16);
    var _name = buffer_read(_b, buffer_string);
    if (_c.role != "host")
    {
        exit;
    }
    var _p = coop_peer(_c.msg_from);
    if (!is_struct(_p))
    {
        exit;
    }
    if (_ver != COOP_VERSION)
    {
        coop_log("guest ", _name, " has mod version ", _ver, ", host has ", COOP_VERSION, " - refused");
        coop_notify(coop_t(_name + " has a different co-op mod version - update!", "У " + _name + " другая версия кооп-мода - обновитесь!"));
        _p.hello = true;
        coop_msg_begin(COOP_MSG_BYE);
        coop_msg_send_to(_p.slot, true);
        _p.hello = false;
        coop_peer_drop(_p.slot);
        exit;
    }
    var _new = !_p.connected;
    _p.connected = true;
    _p.name = _name;
    coop_msg_begin(COOP_MSG_WELCOME);
    buffer_write(_c.send_buf, buffer_u16, COOP_VERSION);
    buffer_write(_c.send_buf, buffer_string, coop_my_name());
    buffer_write(_c.send_buf, buffer_u8, _p.slot);
    coop_msg_send_to(_p.slot, true);
    if (_new)
    {
        coop_log("guest connected: ", _name, " slot ", _p.slot, " (players ", coop_player_count(), ")");
        coop_notify(coop_t(_name + " joined", _name + " подключился"));
        coop_peers_refresh();
        coop_send_roster();
        coop_on_connected(_p.slot);
    }
}

// Guest: the host accepted us and told us our slot.
function coop_net_on_welcome(_b)
{
    var _c = coop();
    var _wver = buffer_read(_b, buffer_u16);
    var _wname = buffer_read(_b, buffer_string);
    var _slot = buffer_read(_b, buffer_u8);
    if (_c.role != "guest" || _c.connected)
    {
        exit;
    }
    if (_wver != COOP_VERSION)
    {
        coop_notify(coop_t("Host has a different co-op mod version - update both!", "У хоста другая версия кооп-мода - обновитесь оба!"));
        coop_log("host version ", _wver, " != ", COOP_VERSION);
        exit;
    }
    _c.slot = _slot;
    var _h = coop_peer(0);
    _h.connected = true;
    _h.name = _wname;
    coop_peers_refresh();
    coop_log("connected to host ", _wname, " v", _wver, " as slot ", _slot);
    coop_notify(coop_t("Connected to ", "Подключено к ") + _wname);
    coop_on_connected(0);
}

// Host -> all: who is in the session.
function coop_send_roster()
{
    var _c = coop();
    if (_c.role != "host")
    {
        exit;
    }
    coop_msg_begin(COOP_MSG_ROSTER);
    var _ps = coop_peers();
    for (var _i = 0; _i < COOP_MAX_PLAYERS; _i++)
    {
        var _p = _ps[_i];
        var _on = (_i == 0) || (is_struct(_p) && _p.connected);
        buffer_write(_c.send_buf, buffer_u8, _on);
        buffer_write(_c.send_buf, buffer_string, _on ? ((_i == 0) ? coop_my_name() : _p.name) : "");
    }
    coop_msg_send(true);
}

// Guest: other guests appear/disappear (they are reached through the host).
function coop_net_on_roster(_b)
{
    var _c = coop();
    if (_c.role != "guest")
    {
        exit;
    }
    var _ps = coop_peers();
    for (var _i = 0; _i < COOP_MAX_PLAYERS; _i++)
    {
        var _on = buffer_read(_b, buffer_u8);
        var _name = buffer_read(_b, buffer_string);
        if (_i == 0 || _i == _c.slot)
        {
            continue;
        }
        var _p = _ps[_i];
        if (_on && !is_struct(_p))
        {
            _p = coop_peer_new(_i);
            _ps[_i] = _p;
            coop_notify(coop_t(_name + " joined", _name + " подключился"));
            coop_send_loadout(); // so the newcomer can dress our character
        }
        if (_on)
        {
            _p.connected = true;
            _p.name = _name;
        }
        else if (is_struct(_p))
        {
            coop_peer_left(_i, true);
        }
    }
    coop_peers_refresh();
}

// A player left (BYE, timeout, or roster). The host tells everybody.
function coop_peer_left(_slot, _quiet)
{
    var _c = coop();
    var _p = coop_peer(_slot);
    if (!is_struct(_p))
    {
        exit;
    }
    var _was_in = _p.in_raid;
    if (!_quiet)
    {
        coop_log("player left: ", _p.name, " slot ", _slot);
    }
    coop_notify(coop_t(_p.name + " left", _p.name + " вышел"));
    coop_puppet_remove_slot(_slot);
    if (_slot == 0 && _c.role == "guest")
    {
        // the host is gone: drop the session, keep saying hello so we reconnect when it is back
        coop_puppet_remove_all();
        coop_on_disconnected();
        coop_guest_reset_host();
        if (_was_in)
        {
            coop_down_on_player_gone();
        }
        exit;
    }
    coop_peer_drop(_slot);
    coop_peers_refresh();
    if (_c.role == "host")
    {
        coop_send_roster();
    }
    if (_was_in)
    {
        coop_down_on_player_gone();
    }
}

function coop_peer_drop(_slot)
{
    var _ps = coop_peers();
    if (is_struct(_ps[_slot]))
    {
        coop_peer_free(_ps[_slot]);
    }
    _ps[_slot] = undefined;
}

function coop_net_on_raid_state(_from, _b)
{
    var _c = coop();
    var _loc = buffer_read(_b, buffer_u8);
    var _pmap = buffer_read(_b, buffer_s8);
    var _rid = buffer_read(_b, buffer_f64);
    var _rdy = buffer_read(_b, buffer_u8);
    var _p = coop_peer(_from);
    if (!is_struct(_p) || _from == _c.slot)
    {
        exit;
    }
    var _in = (_loc == 2) && _rid >= 0 && _c.gen_seed != undefined && _rid == _c.gen_seed && coop_in_raid();
    var _was = _p.in_raid;
    if (_p.in_raid != _in)
    {
        coop_log("player ", _p.name, " (slot ", _from, ") in raid = ", _in, " map ", _pmap);
    }
    _p.in_raid = _in;
    var _became_ready = _in && _rdy && !_p.ready;
    _p.ready = _in && _rdy;
    var _old_loc = _p.loc;
    _p.loc = _loc;
    _p.map = _pmap;
    coop_peers_refresh();
    if (_became_ready)
    {
        coop_log("player ", _p.name, " map ready");
        coop_on_peer_ready(_from);
        if (_from == 0 && _c.role == "guest")
        {
            coop_npc_guest_readopt(); // back after a lost connection: the host drives the NPCs again
        }
    }
    if (_from == 0 && _old_loc != _loc && _loc == 2 && _c.role == "guest" && is_in_hub())
    {
        coop_notify(coop_t(_p.name + " is in a raid - F7 to join", _p.name + " в рейде - F7, чтобы присоединиться"));
    }
    if (!_in)
    {
        if (!coop_hub_peer_here(_from))
        {
            coop_puppet_remove_slot(_from);
        }
        if (_was)
        {
            coop_notify(coop_t(_p.name + " left the raid", _p.name + " покинул рейд"));
            if (!_c.peer_in_raid && coop_in_raid())
            {
                coop_npc_guest_release(); // nobody else is left: our NPCs run on our own AI
            }
            coop_down_on_player_gone();
        }
    }
}

function coop_my_name()
{
    if (variable_struct_exists(coop(), "name_override"))
    {
        return coop().name_override;
    }
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
    if (coop_shared_ready() && (!variable_struct_exists(_c, "ready_time") || _c.ready_time <= 0))
    {
        _c.ready_time = current_time;
    }
    // Guest keeps saying hello until welcomed.
    if (_c.role == "guest" && !_c.connected && current_time - _c.last_hello_time > 1000 && (!variable_struct_exists(_c, "delay_join") || current_time > _c.delay_join))
    {
        _c.last_hello_time = current_time;
        coop_msg_begin(COOP_MSG_HELLO);
        buffer_write(_c.send_buf, buffer_u16, COOP_VERSION);
        buffer_write(_c.send_buf, buffer_string, coop_my_name());
        coop_msg_send_to(0, false);
    }
    var _ps = coop_peers();
    for (var _i = 0; _i < COOP_MAX_PLAYERS; _i++)
    {
        var _p = _ps[_i];
        if (!is_struct(_p) || _i == _c.slot)
        {
            continue;
        }
        coop_net_resend(_p);
        if (_p.ack_due)
        {
            _p.ack_due = false;
            coop_net_send_ack(_p);
        }
        // a host slot that never said a valid hello is freed after a while
        if (_c.role == "host" && !_p.connected && !_p.hello && current_time - _p.last_recv > 10000)
        {
            coop_peer_drop(_i);
            continue;
        }
        var _direct = (_c.role == "host") || (_i == 0);
        if (_p.connected && _direct && current_time - _p.last_recv > 15000)
        {
            coop_log("connection to ", _p.name, " timed out");
            coop_notify(coop_t("Connection to " + _p.name + " lost", "Связь с " + _p.name + " потеряна"));
            coop_peer_left(_i, true);
        }
    }
    if (_c.connected && _c.frame mod 60 == 0)
    {
        coop_msg_begin(COOP_MSG_PING);
        buffer_write(_c.send_buf, buffer_f64, current_time);
        if (_c.role == "host")
        {
            coop_msg_send_to(COOP_ALL, false);
        }
        else
        {
            coop_msg_send_to(0, false);
        }
        coop_send_raid_state();
    }
    if (_c.netsim != undefined)
    {
        coop_netsim_flush();
        if (_c.frame mod 600 == 0)
        {
            coop_log("netsim: dropped ", _c.netsim.dropped, " packets so far");
        }
    }
}

// UDP: resend reliable packets that were not acknowledged in time.
function coop_net_resend(_p)
{
    var _c = coop();
    if (_c.transport != "udp")
    {
        exit;
    }
    var _q = _p.tx_queue;
    var _n = array_length(_q);
    if (_n == 0)
    {
        exit;
    }
    var _rto = clamp(_p.ping * 1.5 + 60, 120, 1000);
    var _budget = 64; // packets per step, so a long backlog can't flood the link
    for (var _i = 0; _i < _n && _budget > 0; _i++)
    {
        var _e = _q[_i];
        if (current_time - _e.t > _rto * min(_e.tries, 4))
        {
            _e.t = current_time;
            _e.tries++;
            _budget--;
            coop_raw_send(_p, _e.buf, _e.size, true);
        }
    }
}

function coop_net_send_ack(_p)
{
    var _c = coop();
    if (!variable_struct_exists(_c, "ack_buf"))
    {
        _c.ack_buf = buffer_create(COOP_HDR, buffer_fixed, 1);
    }
    var _b = _c.ack_buf;
    buffer_seek(_b, buffer_seek_start, 0);
    buffer_write(_b, buffer_u8, 2);
    buffer_write(_b, buffer_u16, (_p.rx_expect + 65535) mod 65536);
    buffer_write(_b, buffer_u8, max(0, _c.slot));
    buffer_write(_b, buffer_u8, _p.slot);
    buffer_write(_b, buffer_u8, 0);
    coop_raw_send(_p, _b, COOP_HDR, false);
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
    coop_msg_send_to(COOP_ALL, true);
}

// A connection was made (_slot = the new guest on the host, 0 = the host on a guest).
function coop_on_connected(_slot)
{
    var _c = coop();
    _c.last_recv_time = current_time;
    _c.base_sig = ""; // the new player gets our bunker modules (coop_hub_step)
    coop_send_raid_state();
    coop_settings_send();
    coop_send_loadout();
}

function coop_on_disconnected()
{
    coop_puppet_remove_all();
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
