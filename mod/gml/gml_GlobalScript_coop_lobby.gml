// ZERO Sievert co-op: lobby management (2.0.0 items 36 and 37).
// Host: lobby type (friends only / invite only / public, Steam), "Kick" per player. A kicked player gets KICK, is
// dropped and cannot come back into this session (its Steam id / IP is remembered until the host stops hosting).
// Anyone not in a session: "Find open games" lists public Steam lobbies of this mod version (host name, players,
// where the host is) with a Join button.

#macro COOP_MSG_KICK 70
#macro COOP_LOBBY_PRIVATE 0
#macro COOP_LOBBY_FRIENDS 1
#macro COOP_LOBBY_PUBLIC 2

// ---- lobby type (local setting, applied when the lobby is created and when it changes) ----

function coop_lobby_type()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "lobby_type"))
    {
        ini_open("coop_local.ini");
        _c.lobby_type = clamp(ini_read_real("coop", "lobby_type", COOP_LOBBY_FRIENDS), 0, 2);
        ini_close();
    }
    return _c.lobby_type;
}

function coop_lobby_type_label()
{
    switch (coop_lobby_type())
    {
        case COOP_LOBBY_PRIVATE: return coop_t("invite only", "только по приглашению");
        case COOP_LOBBY_PUBLIC: return coop_t("open to everyone", "открытое для всех");
    }
    return coop_t("friends only", "только друзья");
}

function coop_lobby_type_cycle()
{
    var _c = coop();
    _c.lobby_type = (coop_lobby_type() + 1) mod 3;
    ini_open("coop_local.ini");
    ini_write_real("coop", "lobby_type", _c.lobby_type);
    ini_close();
    coop_lobby_apply_type();
}

// Host with a Steam lobby: Steam type + the data the lobby browser shows.
function coop_lobby_apply_type()
{
    var _c = coop();
    if (_c.role != "host" || _c.transport != "steam" || !variable_struct_exists(_c, "lobby") || _c.lobby == 0)
    {
        exit;
    }
    // GMEXT-Steamworks: 0 private, 1 friends only, 2 public
    steam_lobby_set_type(coop_lobby_type());
    steam_lobby_set_data("zs_name", coop_my_name());
    coop_log("lobby type ", coop_lobby_type());
}

// Host, every few seconds: what the browser shows (players, where the host is).
function coop_lobby_step()
{
    var _c = coop();
    if (_c.role == "host" && _c.transport == "steam" && variable_struct_exists(_c, "lobby") && _c.lobby != 0 && _c.frame mod 300 == 120)
    {
        steam_lobby_set_data("zs_players", string(coop_player_count()) + "/" + string(COOP_MAX_PLAYERS));
        steam_lobby_set_data("zs_where", coop_in_raid() ? "raid" : (is_in_hub() ? "hub" : "menu"));
    }
    coop_lobby_browser_step();
}

// ---- kick ----

function coop_peer_key(_p)
{
    if (!is_struct(_p)) return "";
    if (_p.steam != 0) return "steam:" + string(_p.steam);
    // by IP the name counts too: two friends behind one router are two players
    return "ip:" + string(_p.ip) + "|" + string(_p.name);
}

function coop_kick(_slot)
{
    var _c = coop();
    var _p = coop_peer(_slot);
    if (_c.role != "host" || _slot == 0 || !is_struct(_p) || !_p.connected)
    {
        exit;
    }
    if (!variable_struct_exists(_c, "kicked")) _c.kicked = [];
    array_push(_c.kicked, coop_peer_key(_p));
    var _name = _p.name;
    coop_msg_begin(COOP_MSG_KICK);
    coop_msg_send_to(_slot, true);
    // let the reliable KICK go out before the peer is forgotten
    _c.kick_pending = { slot: _slot, t: current_time };
    coop_log("kicked ", _name, " slot ", _slot, " (", coop_peer_key(_p), ")");
    coop_notify(coop_tf("{0} was removed from the session", "{0} удалён из сессии", _name));
}

// Host: a kicked player saying hello again is refused (coop_net_on_hello).
function coop_is_kicked(_p)
{
    var _c = coop();
    return variable_struct_exists(_c, "kicked") && array_contains(_c.kicked, coop_peer_key(_p));
}

function coop_kick_step()
{
    var _c = coop();
    if (variable_struct_exists(_c, "kick_pending") && is_struct(_c.kick_pending) && current_time - _c.kick_pending.t > 400)
    {
        var _s = _c.kick_pending.slot;
        _c.kick_pending = undefined;
        if (is_struct(coop_peer(_s)))
        {
            coop_peer_left(_s, true);
            coop_peer_drop(_s);
        }
    }
}

// Guest: the host removed us.
function coop_kick_on_msg()
{
    var _c = coop();
    if (_c.role != "guest" || _c.msg_from != 0)
    {
        exit;
    }
    coop_log("kicked by the host");
    if (_c.test_mode) _c.kicks = (variable_struct_exists(_c, "kicks") ? _c.kicks : 0) + 1;
    coop_on_disconnected();
    coop_net_stop();
    coop_notify(coop_t("The host removed you from the session", "Хост удалил вас из сессии"));
}

// ---- open games browser ----

function coop_lobby_browser_open()
{
    var _c = coop();
    _c.browser = { loading: true, list: [], t: current_time };
    if (!steam_initialised())
    {
        _c.browser.loading = false;
        exit;
    }
    _c.browser.friends = coop_friends_in_game();
    steam_lobby_list_add_string_filter("zs_coop", string(COOP_VERSION), 0); // 0 = equal
    steam_lobby_list_request();
    coop_log("lobby list requested");
}

// The list is read once loading finishes (steam_lobby_list_is_loading), no async handler needed.
function coop_lobby_browser_step()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "browser") || !is_struct(_c.browser) || !_c.browser.loading)
    {
        exit;
    }
    if (steam_lobby_list_is_loading() && current_time - _c.browser.t < 8000)
    {
        exit;
    }
    _c.browser.loading = false;
    var _n = steam_lobby_list_get_count();
    var _l = [];
    for (var _i = 0; _i < _n && _i < 12; _i++)
    {
        var _where = steam_lobby_list_get_data(_i, "zs_where");
        array_push(_l, {
            index: _i,
            id: steam_lobby_list_get_lobby_id(_i),
            name: steam_lobby_list_get_data(_i, "zs_name"),
            players: steam_lobby_list_get_data(_i, "zs_players"),
            where: _where
        });
    }
    _c.browser.list = _l;
    coop_log("lobby list: ", _n, " open games");
}

// Steam friends playing ZERO Sievert now (item 29): [{ name, lobby }] (lobby 0 = not in a lobby).
function coop_friends_in_game()
{
    var _out = [];
    try
    {
        var _app = steam_get_app_id();
        var _l = steam_get_friends_game_info();
        if (!is_array(_l))
        {
            return _out;
        }
        for (var _i = 0; _i < array_length(_l); _i++)
        {
            var _f = _l[_i];
            if (!is_struct(_f)) continue;
            var _game = variable_struct_exists(_f, "gameId") ? _f.gameId : (variable_struct_exists(_f, "game_id") ? _f.game_id : 0);
            if (real(_game) != real(_app)) continue;
            var _lob = variable_struct_exists(_f, "lobbyId") ? _f.lobbyId : (variable_struct_exists(_f, "lobby_id") ? _f.lobby_id : 0);
            var _nm = variable_struct_exists(_f, "name") ? _f.name : "?";
            array_push(_out, { name: string(_nm), lobby: _lob });
        }
    }
    catch (_e)
    {
        coop_report_error(_e);
    }
    coop_log("friends in game: ", array_length(_out));
    return _out;
}

function coop_lobby_browser_label(_e)
{
    var _nm = (is_string(_e.name) && _e.name != "") ? _e.name : coop_t("Player", "Игрок");
    var _w = (_e.where == "raid") ? coop_t("in a raid", "в рейде") : ((_e.where == "hub") ? coop_t("in the bunker", "в бункере") : coop_t("in the menu", "в меню"));
    return coop_ui_fit(_nm, 300) + "  " + string(_e.players) + "  · " + _w;
}
