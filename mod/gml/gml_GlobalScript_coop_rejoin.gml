// ZERO Sievert co-op: back into the session after a crash (2.0.0 item 20).
// While connected as a guest, coop_local.ini [rejoin] remembers how to reach the host (Steam lobby or IP) and the
// host's name; a host remembers that it hosted. A clean end (leaving co-op, being removed, quitting the game - obj_coop
// Game End) forgets it. After a crash it is still there: on the next start the main menu offers "Rejoin {host}"
// (or "Host again" for a host) for 30 minutes.

#macro COOP_REJOIN_MAX_MIN 30

function coop_rejoin_remember()
{
    var _c = coop();
    if (_c.test_mode && (_c.scenario != "rejoin" || _c.role != "guest"))
    {
        exit; // the test windows share coop_local.ini with real play (and are killed, never ending cleanly)
    }
    ini_open("coop_local.ini");
    ini_write_real("rejoin", "active", 1);
    ini_write_string("rejoin", "role", _c.role);
    ini_write_string("rejoin", "transport", _c.transport);
    ini_write_string("rejoin", "ip", (_c.role == "guest" && variable_struct_exists(_c, "peer_ip")) ? string(_c.peer_ip) : "");
    ini_write_string("rejoin", "lobby", (variable_struct_exists(_c, "lobby") && _c.lobby != 0) ? string(_c.lobby) : "");
    ini_write_string("rejoin", "host", (_c.role == "guest") ? coop_peer_name(0) : coop_my_name());
    ini_write_real("rejoin", "time", date_current_datetime());
    ini_close();
}

function coop_rejoin_forget()
{
    ini_open("coop_local.ini");
    ini_section_delete("rejoin");
    ini_close();
}

// Main menu, once per start: what to offer (undefined = nothing).
function coop_rejoin_offer()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "rejoin_offer"))
    {
        _c.rejoin_offer = undefined;
        ini_open("coop_local.ini");
        if (ini_read_real("rejoin", "active", 0))
        {
            var _age = date_minute_span(ini_read_real("rejoin", "time", 0), date_current_datetime());
            if (_age <= COOP_REJOIN_MAX_MIN)
            {
                _c.rejoin_offer = {
                    role: ini_read_string("rejoin", "role", ""),
                    transport: ini_read_string("rejoin", "transport", ""),
                    ip: ini_read_string("rejoin", "ip", ""),
                    lobby: ini_read_string("rejoin", "lobby", ""),
                    host: ini_read_string("rejoin", "host", "?")
                };
                coop_log("rejoin offered: ", json_stringify(_c.rejoin_offer));
            }
        }
        ini_close();
    }
    return _c.rejoin_offer;
}

// obj_coop Step: offer it once the main menu is up (a toast; the button is on the co-op panel).
function coop_rejoin_step()
{
    var _c = coop();
    if (room != r_menu || variable_struct_exists(_c, "rejoin_toast"))
    {
        exit;
    }
    _c.rejoin_toast = true;
    var _o = coop_rejoin_offer();
    if (is_struct(_o) && _c.role == "none")
    {
        coop_notify(coop_t("The game closed during co-op - F7 to get back in", "Игра закрылась во время кооператива - F7, чтобы вернуться"));
    }
}

function coop_rejoin_label()
{
    var _o = coop_rejoin_offer();
    if (_o.role == "host")
    {
        return coop_t("Host again (you were hosting)", "Создать игру снова (вы были хостом)");
    }
    return coop_tf("Rejoin {0}", "Вернуться к {0}", coop_streamer() ? coop_t("the host", "хосту") : _o.host);
}

function coop_rejoin_go()
{
    var _c = coop();
    var _o = coop_rejoin_offer();
    _c.rejoin_offer = undefined;
    coop_rejoin_forget();
    if (!is_struct(_o))
    {
        exit;
    }
    coop_log("rejoin: ", json_stringify(_o));
    if (_o.role == "host")
    {
        if (_o.transport == "steam")
        {
            coop_steam_host();
        }
        else
        {
            coop_net_stop();
            _c.role = "host";
            _c.transport = "udp";
            coop_net_start();
        }
        exit;
    }
    if (_o.transport == "steam" && _o.lobby != "")
    {
        coop_steam_join_lobby(int64(_o.lobby));
    }
    else if (_o.ip != "")
    {
        coop_net_stop();
        _c.role = "guest";
        _c.transport = "udp";
        _c.peer_ip = _o.ip;
        _c.peer_port = COOP_PORT;
        coop_net_start();
        coop_notify(coop_tf("Connecting to {0}", "Подключение к {0}", coop_streamer() ? "***" : _c.peer_ip));
    }
}
