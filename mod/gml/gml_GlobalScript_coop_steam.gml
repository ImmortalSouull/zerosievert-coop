// ZERO Sievert co-op: Steam lobby + invite flow (GMEXT-Steamworks).
// Host: F7 panel -> "Host via Steam" -> friends-only lobby (up to 4 players) -> Steam invite overlay.
// Friend: accepts the invite in Steam. Running game: lobby_join_requested event; not running:
// Steam starts the game with "+connect_lobby <id>". Once in the lobby, gameplay traffic is Steam P2P.

function coop_steam_host()
{
    var _c = coop();
    if (!steam_initialised())
    {
        coop_notify(coop_t("Steam is not running", "Steam не запущен"));
        exit;
    }
    coop_net_stop();
    _c.role = "host";
    _c.transport = "steam";
    _c.peer_steam = 0;
    coop_net_start();
    _c.kicked = [];
    steam_lobby_create(coop_lobby_type(), COOP_MAX_PLAYERS); // friends only / invite only / public (coop_lobby.gml)
    coop_notify(coop_t("Creating Steam lobby...", "Создаём лобби Steam..."));
    coop_log("steam lobby create requested");
}

function coop_steam_join_lobby(_lobby)
{
    var _c = coop();
    if (!steam_initialised())
    {
        exit;
    }
    coop_net_stop();
    _c.role = "guest";
    _c.transport = "steam";
    _c.peer_steam = 0;
    coop_net_start();
    steam_lobby_join_id(_lobby);
    coop_notify(coop_t("Joining friend's lobby...", "Подключаемся к лобби друга..."));
    coop_log("joining lobby ", _lobby);
}

// "+connect_lobby <id>" on the command line (game launched from a Steam invite).
function coop_steam_check_launch_invite()
{
    var _n = parameter_count();
    for (var _i = 0; _i < _n - 1; _i++)
    {
        if (parameter_string(_i) == "+connect_lobby")
        {
            var _id = int64(parameter_string(_i + 1));
            coop().pending_lobby = _id;
            coop_log("launched from invite, lobby ", _id);
        }
    }
}

// obj_coop Async - Steam.
function coop_steam_on_async()
{
    var _c = coop();
    var _type = ds_map_find_value(async_load, "event_type");
    if (_type == undefined)
    {
        exit;
    }
    // "Join game" from the friends list arrives with a connect string.
    var _connect = ds_map_find_value(async_load, "connect");
    if (is_string(_connect) && string_pos("+connect_lobby", _connect) > 0 && _c.role == "none")
    {
        var _parts = string_split(_connect, " ");
        coop_log("join via friends list: ", _connect);
        coop_steam_join_lobby(int64(_parts[array_length(_parts) - 1]));
        exit;
    }
    switch (_type)
    {
        case "lobby_created":
            var _ok = ds_map_find_value(async_load, "success");
            _c.lobby = steam_lobby_get_lobby_id();
            coop_log("lobby created ok=", _ok, " id=", _c.lobby);
            if (_ok == undefined || _ok)
            {
                steam_lobby_set_data("zs_coop", string(COOP_VERSION));
                // who hosts: when the host quits, Steam hands the lobby to a guest who is not hosting
                steam_lobby_set_data("zs_host", string(steam_get_user_steam_id()));
                coop_lobby_apply_type();
                // Friends can also use "Join game" in the Steam friends list.
                steam_set_rich_presence("connect", "+connect_lobby " + string(_c.lobby));
                steam_set_rich_presence("status", "ZERO Sievert co-op");
                steam_lobby_activate_invite_overlay();
                coop_notify(coop_t("Lobby ready - invite your friend in the Steam overlay", "Лобби готово - пригласите друга через оверлей Steam"));
            }
            else
            {
                coop_notify(coop_t("Could not create a Steam lobby", "Не удалось создать лобби Steam"));
            }
            break;
        case "lobby_join_requested":
            var _lobby = ds_map_find_value(async_load, "lobby_id");
            coop_log("invite accepted, lobby ", _lobby);
            coop_steam_join_lobby(_lobby);
            break;
        case "lobby_joined":
            _c.lobby = steam_lobby_get_lobby_id();
            coop_log("lobby joined ", _c.lobby, " members ", steam_lobby_get_member_count());
            if (_c.role == "guest")
            {
                coop_steam_pick_peer();
            }
            break;
        case "lobby_chat_update":
            // Someone entered/left: the host learns a guest's id from its first P2P packet.
            coop_log("lobby update, members ", steam_lobby_get_member_count());
            if (_c.role == "host")
            {
                coop_steam_drop_left_members();
            }
            if (_c.role == "guest" && _c.peer_steam != 0 && steam_lobby_get_owner_id() != _c.peer_steam)
            {
                // the host left the lobby: leave it too, a lobby without its host can't be joined
                coop_steam_stale_lobby();
            }
            break;
        case "p2p_session_request":
            var _who = ds_map_find_value(async_load, "user_id");
            if (_who != undefined)
            {
                steam_net_accept_p2p_session(_who);
            }
            break;
    }
}

// Guest: the lobby owner is the host (other members are reached through it).
function coop_steam_pick_peer()
{
    var _c = coop();
    var _owner = steam_lobby_get_owner_id();
    if (_owner == 0 || _owner == steam_get_user_steam_id())
    {
        exit;
    }
    var _host = steam_lobby_get_data("zs_host");
    if (is_string(_host) && _host != "" && _host != string(_owner))
    {
        // live bug 2026-11-06: an invite to a lobby whose host had quit hung until the timeout
        coop_log("lobby owner ", _owner, " is not its host ", _host);
        coop_steam_stale_lobby();
        exit;
    }
    _c.peer_steam = _owner;
    var _h = coop_peer(0);
    if (is_struct(_h))
    {
        _h.steam = _owner;
    }
    coop_log("steam host = ", _owner);
}

// Host: a guest who left the Steam lobby is gone now. Its BYE often never arrives: the guest closes the P2P session
// right after sending it. Without this its character stood (breathing fast) until the connection timed out.
function coop_steam_drop_left_members()
{
    var _c = coop();
    var _n = steam_lobby_get_member_count();
    var _ids = [];
    for (var _i = 0; _i < _n; _i++)
    {
        array_push(_ids, steam_lobby_get_member_id(_i));
    }
    var _ps = coop_peers();
    for (var _k = 1; _k < COOP_MAX_PLAYERS; _k++)
    {
        var _p = _ps[_k];
        if (is_struct(_p) && _p.connected && _p.steam != 0 && !array_contains(_ids, _p.steam))
        {
            coop_log("slot ", _k, " left the steam lobby");
            coop_peer_left(_k, false);
        }
    }
}

// Guest: the lobby lost its host (quit / left). Leave it and say what to do.
function coop_steam_stale_lobby()
{
    coop_log("steam lobby has no host any more - leaving");
    coop_net_stop();
    coop_notify(coop_t("The host has left this lobby - ask your friend to host again", "Хост вышел из этого лобби - попросите друга создать игру заново"));
}

function coop_steam_step()
{
    var _c = coop();
    if (variable_struct_exists(_c, "pending_lobby") && _c.pending_lobby != undefined && steam_initialised() && room != r_logo_screen)
    {
        var _l = _c.pending_lobby;
        _c.pending_lobby = undefined;
        coop_steam_join_lobby(_l);
    }
}
