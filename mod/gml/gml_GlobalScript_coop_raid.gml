// ZERO Sievert co-op: shared raid start, room hooks, test-mode autopilot.

// Hook: first line of go_to_map(). Host shares map + seed with the guest.
function coop_hook_go_to_map(_map)
{
    var _c = coop();
    if (_c.role == "host")
    {
        // Always a known seed while hosting, so a partner can still join this raid later.
        var _seed = irandom(2147483646);
        _c.seed = _seed;
        coop_group_fix(); // the raid is generated with the group size of this moment
        if (!_c.connected)
        {
            coop_log("raid started without partner, seed ", _seed);
            exit;
        }
        coop_settings_send(); // world settings must arrive before the guest generates the map
        coop_msg_begin(COOP_MSG_RAID_START);
        buffer_write(_c.send_buf, buffer_u8, _map);
        buffer_write(_c.send_buf, buffer_f64, _seed);
        coop_msg_send(true);
        coop_log("raid start sent: map ", _map, " seed ", _seed);
        _c.raid_map = _map;
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
    if (_c.test_mode && _c.scenario == "ownerjoin" && _c.slot == 2 && !variable_struct_exists(_c, "oj_asked"))
    {
        coop_log("ownerjoin: stays in the hub");
        exit;
    }
    coop_log("host started raid map ", _map, " seed ", _seed);
    _c.pending_raid = { map: _map, seed: _seed, time: current_time };
    if (is_in_hub() && instance_exists(obj_player) && player_state_is(0, scr_player_state_move))
    {
        coop_pending_raid_step();
    }
    else
    {
        coop_notify(coop_t(_c.peer_name + " started a raid - you will follow when you close the menu", _c.peer_name + " начал рейд - вы поедете следом, когда закроете меню"));
    }
}

// obj_coop Room Start
function coop_on_room_start()
{
    var _c = coop();
    coop_log("room start: ", room_get_name(room));
    coop_apply_test_window();
    coop_npc_reset_room();
    coop_puppets_prune(); // characters carried over from the hub lobby, if any
    if (room == room1)
    {
        // what this raid is generated with, for players joining it from us later (coop_on_join_request)
        _c.raid_settings_json = json_stringify(variable_struct_exists(_c, "host_settings") ? _c.host_settings : {});
        coop_down_reset();
        coop_chest_reset_room();
        _c.my_fp = undefined;
        var _ps = coop_peers();
        for (var _k = 0; _k < COOP_MAX_PLAYERS; _k++)
        {
            if (is_struct(_ps[_k])) _ps[_k].fp = undefined;
        }
        _c.ready_time = 0;
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
        if (variable_struct_exists(_c, "peer_hub_ready") && _c.peer_hub_ready && coop_player_count() >= (variable_struct_exists(_c, "expect") ? _c.expect : 2))
        {
            _c.autoraid_done = true;
            coop_log("autopilot: starting raid ", _c.autoraid);
            go_to_map(_c.autoraid);
        }
    }
    // solo play with the mod (no co-op session): the same raid start, then coop_test_solo_step
    if (_c.autoraid >= 0 && !_c.autoraid_done && _c.role == "none" && _c.scenario == "solo" && is_in_hub() && instance_exists(obj_player) && _c.ap_timer > 120)
    {
        _c.autoraid_done = true;
        coop_log("autopilot: solo raid ", _c.autoraid);
        go_to_map(_c.autoraid);
    }
    coop_test_press_space();
    coop_bot_step();
    coop_scenario_step();
    coop_scenario_hub_step();
    coop_test_ext_step();
}

function coop_scenario_hub_step()
{
    var _c = coop();
    if ((_c.scenario != "steamhost" && _c.scenario != "difficulty" && _c.scenario != "show" && _c.scenario != "panel" && _c.scenario != "lobby" && _c.scenario != "lobby2") || !is_in_hub() || !instance_exists(obj_player))
    {
        exit;
    }
    if (!variable_struct_exists(_c, "hub_t"))
    {
        _c.hub_t = 0;
    }
    _c.hub_t++;
    var _t = _c.hub_t;
    if (_c.scenario == "show")
    {
        coop_show_hub_step(_t);
        exit;
    }
    if (_c.scenario == "lobby" || _c.scenario == "lobby2")
    {
        coop_test_lobby_step(_t);
        exit;
    }
    if (_c.scenario == "panel")
    {
        if (_t == 90) { _c.panel = true; _c.ip_edit = false; _c.last_ip = "127.0.0.1"; }
        if (_t == 150) screen_save("coop_panel_" + _c.tag + ".png");
        if (_t == 330) _c.panel = false;
        if (_t == 3600) game_end();
        exit;
    }
    if (_c.scenario == "difficulty")
    {
        if (_t == 3600)
        {
            game_end();
        }
        exit;
    }
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
    if (_c.scenario == "show")
    {
        coop_show_raid_step(_t);
        exit;
    }
    if (_c.scenario == "chest")
    {
        if (_t == 199 || _t == 259 || _t == 299 || _t == 419)
        {
            instance_activate_object(obj_chest_general);
        }
        if (_t == 200 || _t == 420)
        {
            // both read the container nearest to the host (the guest spawns next to it)
            var _hp = (_c.role == "host") ? obj_player.id : coop_puppet_of(0);
            if (!instance_exists(_hp)) _hp = obj_player.id;
            var _ch = instance_nearest(_hp.x, _hp.y, obj_chest_general);
            if (instance_exists(_ch))
            {
                _c.sc_chest = coop_chest_key(_ch);
                var _j = json_stringify(coop_chest_read(_ch));
                coop_log("scenario chest t=", _t, " ", _c.sc_chest, " len=", string_length(_j), " md5=", md5_string_utf8(_j));
            }
        }
        if (_c.role == "host" && _t == 260)
        {
            var _ch2 = instance_nearest(obj_player.x, obj_player.y, obj_chest_general);
            if (instance_exists(_ch2))
            {
                obj_player.x = _ch2.x + 10;
                obj_player.y = _ch2.y + 10;
            }
        }
        if (_c.role == "host" && _t == 300)
        {
            var _ch3 = instance_nearest(obj_player.x, obj_player.y, obj_chest_general);
            if (!instance_exists(_ch3)) exit;
            db_open("all loot");
            var _it = db_read("chest_" + string(_ch3.id), "items", []);
            if (array_length(_it) > 0) array_delete(_it, 0, 1);
            db_write("chest_" + string(_ch3.id), "items", _it);
            db_close();
            coop_log("scenario: host took first item from ", coop_chest_key(_ch3));
        }
        if (_t == 110)
        {
            coop_log("scenario: weapon=", obj_player.arma_now, " slot=", obj_player.weapon_slot_now);
        }
        if (_c.role == "guest" && _t >= 120 && _t <= 400 && _t mod 25 == 0)
        {
            with (obj_player)
            {
                if (item_exists(arma_now) && item_get_category(arma_now) == "weapon")
                {
                    scr_shoot(_t * 7 mod 360, 1, item_weapon_get_damage(arma_now), 1);
                }
            }
        }
    }
    if (_c.scenario == "revive" || _c.scenario == "both")
    {
        if (_c.scenario == "both" && _c.role == "guest" && _t == 800)
        {
            coop_log("scenario: second lethal damage");
            obj_player.hp = 0;
        }
        if (_c.scenario == "both" && _c.role == "host" && coop_down().count == 0 && variable_struct_exists(_c, "sc_rev_t") && _t > _c.sc_rev_t + 520 && coop_partner_is_down())
        {
            coop_log("scenario: host takes lethal damage while partner is down");
            obj_player.hp = 0;
        }
        if (_c.role == "guest" && _t == 330)
        {
            screen_save("coop_down.png");
        }
        if (_c.role == "guest" && _t == 240)
        {
            coop_log("scenario: taking lethal damage");
            obj_player.hp = 0;
        }
        // after the revive: the give menu next to the partner (screenshot), then give the first item
        if (_c.scenario == "revive" && _c.role == "host" && variable_struct_exists(_c, "sc_rev_t") && !coop_partner_is_down())
        {
            var _k2 = _t - _c.sc_rev_t;
            if (_k2 == 520)
            {
                _c.sim_give = true;
            }
            if (_k2 == 540)
            {
                screen_save("coop_give_menu.png");
                coop_log("scenario: give menu open=", coop_give().menu);
            }
            if (_k2 == 560)
            {
                _c.sim_give_ok = true;
            }
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
                if (_k == 220)
                {
                    screen_save("coop_reviving.png");
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
        _need = !instance_exists(obj_player) || player_state_is(0, scr_player_state_start);
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

// ---- joining a raid in progress ----

// The player to ask for a running raid (-1: none we may join). It is the raid's owner, the lowest slot in
// it - the host's raid, or after the host extracted the next player's. The owner never changes to a player
// who joins later (a fresh copy of the map must not drive the world), so only higher slots may join.
function coop_join_target()
{
    var _c = coop();
    if (_c.role != "guest" || !_c.connected || !is_in_hub() || !instance_exists(obj_player))
    {
        return -1;
    }
    var _ps = coop_peers();
    for (var _k = 0; _k < COOP_MAX_PLAYERS; _k++)
    {
        var _p = _ps[_k];
        if (_k != _c.slot && is_struct(_p) && _p.connected && _p.loc == 2)
        {
            return (_k < _c.slot) ? _k : -1;
        }
    }
    return -1;
}

function coop_can_join_host_raid()
{
    return coop_join_target() >= 0;
}

// Guest (co-op panel): ask the raid owner for its raid.
function coop_request_join()
{
    var _c = coop();
    var _t = coop_join_target();
    if (_t < 0)
    {
        exit;
    }
    _c.join_target = _t;
    coop_msg_begin(COOP_MSG_JOIN_REQ);
    coop_msg_send_to(_t, true);
    var _name = coop_peer_name(_t);
    coop_notify(coop_t("Asking " + _name + " to join the raid...", "Запрос на вход в рейд " + _name + "..."));
    coop_log("join request sent to slot ", _t);
}

// Raid owner: send the running raid (settings + map + seed) to a player standing in the bunker.
function coop_on_join_request(_from)
{
    var _c = coop();
    if (!coop_raid_ready() || _c.gen_seed == undefined || coop_raid_owner() != max(0, _c.slot))
    {
        coop_log("join request ignored (not owning a raid)");
        exit;
    }
    if (_c.role != "host")
    {
        // the settings this raid was generated with (the host may have changed its own since)
        _c.msg_dest = _from;
        coop_msg_begin(COOP_MSG_SETTINGS);
        buffer_write(_c.send_buf, buffer_string, _c.raid_settings_json);
        coop_msg_send(true);
        coop_msg_begin(COOP_MSG_RAID_START);
        buffer_write(_c.send_buf, buffer_u8, obj_map_generator.area);
        buffer_write(_c.send_buf, buffer_f64, _c.gen_seed);
        coop_msg_send(true);
        _c.msg_dest = COOP_ALL;
        coop_log("join request of slot ", _from, " accepted (raid owner): map ", obj_map_generator.area, " seed ", _c.gen_seed);
        exit;
    }
    _c.msg_dest = _from;
    coop_settings_send();
    coop_msg_begin(COOP_MSG_RAID_START);
    buffer_write(_c.send_buf, buffer_u8, obj_map_generator.area);
    buffer_write(_c.send_buf, buffer_f64, _c.gen_seed);
    coop_msg_send(true);
    _c.msg_dest = COOP_ALL;
    coop_log("join request of slot ", _from, " accepted: map ", obj_map_generator.area, " seed ", _c.gen_seed);
}

// Raid owner: another player's copy of our raid finished generating (fresh start or late join): stream
// everything to it.
function coop_on_peer_ready(_slot)
{
    var _c = coop();
    if (!coop_raid_ready() || coop_raid_owner() != max(0, _c.slot))
    {
        exit; // the raid owner streams the world to newcomers
    }
    instance_activate_object(obj_npc_parent);
    with (obj_npc_parent)
    {
        if (variable_instance_exists(id, "coop_spawn_sent"))
        {
            coop_spawn_sent = false;
        }
    }
    // NPC spawns go to everybody (known ones are ignored); the rest only to the new player
    _c.msg_dest = _slot;
    try
    {
        coop_chest_sync_late_joiner();
        coop_doors_resend_all();
        coop_world_sync_peer();
        coop_send_loadout();
    }
    catch (_e)
    {
        coop_report_error(_e);
    }
    _c.msg_dest = COOP_ALL;
}

// Guest: follow the host's raid as soon as we are in the bunker and not busy (dialog, trading, inventory).
function coop_pending_raid_step()
{
    var _c = coop();
    if (_c.role != "guest" || _c.pending_raid == undefined)
    {
        exit;
    }
    var _pr = _c.pending_raid;
    if (current_time - _pr.time > 180000 || !_c.connected)
    {
        _c.pending_raid = undefined;
        exit;
    }
    if (!is_in_hub() || !instance_exists(obj_player) || !player_state_is(0, scr_player_state_move) || instance_exists(obj_main_menu))
    {
        exit;
    }
    _c.pending_raid = undefined;
    _c.seed = _pr.seed;
    coop_notify(coop_t("Following " + _c.peer_name + " into the raid", "Едем за " + _c.peer_name + " в рейд"));
    __uiGlobal().__defaultOnion.Clear();
    go_to_map(_pr.map);
}
