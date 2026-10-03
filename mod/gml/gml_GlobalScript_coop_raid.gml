// ZERO Sievert co-op: shared raid start, room hooks, test-mode autopilot.

// Hook: first line of go_to_map(). Host shares map + seed with the guest.
function coop_hook_go_to_map(_map)
{
    var _c = coop();
    if (_c.role == "host" && _c.connected)
    {
        var _seed = irandom(2147483646);
        _c.seed = _seed;
        coop_msg_begin(COOP_MSG_RAID_START);
        buffer_write(_c.send_buf, buffer_u8, _map);
        buffer_write(_c.send_buf, buffer_f64, _seed);
        coop_msg_send(true);
        coop_log("raid start sent: map ", _map, " seed ", _seed);
        coop_settings_send();
    }
}

// Guest: host started a raid.
function coop_on_raid_start(_map, _seed)
{
    var _c = coop();
    if (_c.role != "guest")
    {
        exit;
    }
    coop_log("host started raid map ", _map, " seed ", _seed);
    if (is_in_hub() && instance_exists(obj_player))
    {
        _c.seed = _seed;
        coop_notify("Following " + _c.peer_name + " into the raid");
        go_to_map(_map);
    }
    else
    {
        _c.pending_raid = { map: _map, seed: _seed, time: current_time };
        coop_notify(_c.peer_name + " started a raid - go to the bunker to follow");
    }
}

// obj_coop Room Start
function coop_on_room_start()
{
    var _c = coop();
    coop_log("room start: ", room_get_name(room));
    coop_apply_test_window();
    coop_npc_reset_room();
    if (room == room1)
    {
        coop_down_reset();
    }
    if (_c.connected)
    {
        coop_send_raid_state();
    }
}

function coop_apply_test_window()
{
    var _c = coop();
    if (_c.window != undefined)
    {
        window_set_fullscreen(false);
        window_set_size(_c.window[2], _c.window[3]);
        window_set_position(_c.window[0], _c.window[1]);
    }
}

// Test autopilot: load slot from the main menu, host starts the raid once the guest is in the hub.
function coop_autopilot_step()
{
    var _c = coop();
    if (!_c.test_mode)
    {
        exit;
    }
    if (!variable_struct_exists(_c, "ap_timer"))
    {
        _c.ap_timer = 0;
    }
    _c.ap_timer++;
    if (_c.autoslot >= 0 && !_c.autoslot_done && room == r_menu && _c.ap_timer > 90)
    {
        _c.autoslot_done = true;
        coop_log("autopilot: loading slot ", _c.autoslot);
        saveslot_load(_c.autoslot);
        _c.ap_timer = 0;
    }
    if (_c.autoraid >= 0 && !_c.autoraid_done && _c.role == "host" && _c.connected && is_in_hub() && instance_exists(obj_player) && _c.ap_timer > 120)
    {
        if (variable_struct_exists(_c, "peer_hub_ready") && _c.peer_hub_ready)
        {
            _c.autoraid_done = true;
            coop_log("autopilot: starting raid ", _c.autoraid);
            go_to_map(_c.autoraid);
        }
    }
    // Pending raid for a guest that just arrived in the hub.
    if (_c.role == "guest" && variable_struct_exists(_c, "pending_raid") && _c.pending_raid != undefined && is_in_hub() && instance_exists(obj_player) && _c.ap_timer > 60)
    {
        var _pr = _c.pending_raid;
        _c.pending_raid = undefined;
        if (current_time - _pr.time < 120000)
        {
            _c.seed = _pr.seed;
            go_to_map(_pr.map);
        }
    }
    coop_test_press_space();
    coop_bot_step();
    coop_scenario_step();
    coop_scenario_hub_step();
}

function coop_scenario_hub_step()
{
    var _c = coop();
    if (_c.scenario != "steamhost" || !is_in_hub() || !instance_exists(obj_player))
    {
        exit;
    }
    if (!variable_struct_exists(_c, "hub_t"))
    {
        _c.hub_t = 0;
    }
    _c.hub_t++;
    var _t = _c.hub_t;
    if (_t == 90) { _c.panel = true; _c.ip_edit = false; _c.last_ip = "127.0.0.1"; }
    if (_t == 120) screen_save("coop_panel.png");
    if (_t == 130) coop_panel_click("steam_host");
    if (_t == 420) screen_save("coop_lobby.png");
    if (_t == 480) { coop_log("scenario steamhost done"); game_end(); }
}

// Scripted test scenarios (test mode only).
function coop_scenario_step()
{
    var _c = coop();
    if (_c.scenario == "" || !coop_in_raid() || !instance_exists(obj_player) || !player_state_is(0, scr_player_state_move) || !_c.peer_in_raid)
    {
        exit;
    }
    _c.sc_t++;
    var _t = _c.sc_t;
    if (_c.scenario == "revive")
    {
        if (_c.role == "guest" && _t == 240)
        {
            coop_log("scenario: taking lethal damage");
            obj_player.hp = 0;
        }
        if (_c.role == "host")
        {
            var _p = coop_partner();
            if (coop_partner_is_down() && instance_exists(_p))
            {
                if (!variable_struct_exists(_c, "sc_rev_t"))
                {
                    _c.sc_rev_t = _t;
                    obj_player.x = _p.x + 12;
                    obj_player.y = _p.y;
                    coop_log("scenario: host moved next to downed partner");
                }
                var _k = _t - _c.sc_rev_t;
                if (_k == 60 || _k == 100)
                {
                    _c.sim_e = true;
                    coop_log("scenario: host presses E");
                }
                if (_k == 90)
                {
                    screen_save("coop_revive_menu.png");
                }
            }
        }
    }
}

// Test mode: tap Space through "failed to load", raid loading and train intro screens.
function coop_test_press_space()
{
    var _c = coop();
    if (_c.frame mod 40 == 1)
    {
        keyboard_key_release(vk_space);
    }
    if (_c.frame mod 40 != 0)
    {
        exit;
    }
    var _need = (room == r_logo_screen);
    if (coop_in_raid())
    {
        _need = !instance_exists(obj_player) || !player_state_is(0, scr_player_state_move);
    }
    if (_need)
    {
        keyboard_key_press(vk_space);
    }
}

// Guest bot: walks a small square so the host can see the puppet move.
function coop_bot_step()
{
    var _c = coop();
    if (!_c.bot || !coop_in_raid() || !instance_exists(obj_player) || !player_state_is(0, scr_player_state_move))
    {
        exit;
    }
    if (!variable_struct_exists(_c, "bot_wait"))
    {
        _c.bot_wait = 0;
    }
    _c.bot_wait++;
    if (_c.bot_wait < 120)
    {
        exit; // let the generator place the player at the spawn first
    }
    if (!variable_struct_exists(_c, "bot_t"))
    {
        _c.bot_t = 0;
        _c.bot_ox = obj_player.x;
        _c.bot_oy = obj_player.y;
    }
    _c.bot_t++;
    var _a = _c.bot_t * 2;
    with (obj_player)
    {
        var _nx = _c.bot_ox + lengthdir_x(24, _a);
        var _ny = _c.bot_oy + lengthdir_y(24, _a);
        x = _nx;
        y = _ny;
        aim_point_x = x + lengthdir_x(40, _a + 90);
        aim_point_y = y + lengthdir_y(40, _a + 90);
    }
}
