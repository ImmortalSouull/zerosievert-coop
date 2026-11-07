// ZERO Sievert co-op: the session survives the host leaving (2.0.0 item 2).
// The roster tells every player where the others can be reached (the host's view: IP or Steam id). When the host is
// gone (BYE or timeout), every guest picks the same successor: on Steam the lobby's new owner (Steam hands the lobby
// over by itself), otherwise the remaining player with the lowest slot. The successor becomes the host (UDP: it
// listens on the co-op port), the others say hello to it. Raids go on: the world passes to the lowest slot in the
// raid as when an owner extracts, and the replicas are adopted again on reconnect.

// Before the old peers are dropped: { me, addr, slot } of the successor, or undefined (nobody left).
function coop_migrate_pick()
{
    var _c = coop();
    var _ps = coop_peers();
    if (_c.transport == "steam")
    {
        var _owner = 0;
        try { _owner = steam_lobby_get_owner_id(); } catch (_e) { }
        if (_owner != 0 && _owner == steam_get_user_steam_id())
        {
            return { me: true, addr: "", slot: _c.slot };
        }
        for (var _k = 1; _k < COOP_MAX_PLAYERS; _k++)
        {
            if (_k != _c.slot && is_struct(_ps[_k]) && _ps[_k].connected && variable_struct_exists(_ps[_k], "addr") && _ps[_k].addr == string(_owner))
            {
                return { me: false, addr: _ps[_k].addr, slot: _k };
            }
        }
    }
    for (var _k = 1; _k < COOP_MAX_PLAYERS; _k++)
    {
        if (_k == _c.slot)
        {
            return { me: true, addr: "", slot: _k };
        }
        if (is_struct(_ps[_k]) && _ps[_k].connected && variable_struct_exists(_ps[_k], "addr") && _ps[_k].addr != "")
        {
            return { me: false, addr: _ps[_k].addr, slot: _k };
        }
    }
    return undefined;
}

function coop_migrate_go(_next)
{
    var _c = coop();
    if (!is_struct(_next))
    {
        exit; // alone: wait for the host to come back
    }
    coop_log("migrate: the host left, successor slot ", _next.slot, _next.me ? " (me)" : " at " + _next.addr);
    if (_next.me)
    {
        // we host now: same transport, our own listening socket / the lobby we are in
        var _tr = _c.transport;
        coop_net_stop();
        _c.role = "host";
        _c.transport = _tr;
        coop_net_start();
        if (_tr == "steam")
        {
            try
            {
                steam_lobby_set_data("zs_host", string(steam_get_user_steam_id()));
                _c.lobby = steam_lobby_get_lobby_id();
            }
            catch (_e) { }
        }
        coop_notify(coop_t("The host left - you host the session now", "Хост вышел - теперь хост вы"));
        exit;
    }
    // say hello to the successor (coop_guest_reset_host left peer 0 for it)
    var _h = coop_peer(0);
    if (_c.transport == "steam")
    {
        _c.peer_steam = int64(_next.addr);
        if (is_struct(_h)) _h.steam = _c.peer_steam;
    }
    else
    {
        _c.peer_ip = _next.addr;
        _c.peer_port = COOP_PORT;
        if (is_struct(_h)) { _h.ip = _next.addr; _h.port = COOP_PORT; }
    }
    coop_notify(coop_t("The host left - reconnecting to the new host", "Хост вышел - подключаемся к новому хосту"));
}
