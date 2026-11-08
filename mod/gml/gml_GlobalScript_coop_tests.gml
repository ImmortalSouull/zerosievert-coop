// ZERO Sievert co-op: scripted test scenarios (test mode only, -coop_scenario <name>; never active in normal play).
// tools/regress.py launches 1-4 game windows per scenario and checks their logs. See CLAUDE.md for the list.

function coop_test_ext_step()
{
    var _c = coop();
    if (!_c.test_mode)
    {
        exit;
    }
    if (_c.scenario == "join")
    {
        coop_test_join_step();
    }
    coop_test_v3_step();
    coop_test_fps_step();
    coop_test_anim_step();
    coop_test_tele_step();
    coop_test_leave_step();
    coop_test_quad_step();
    coop_test_handoff_step();
    coop_test_ownerjoin_step();
    coop_test_hostjoin_step();
    coop_test_gather_step();
    coop_test_solo_step();
    coop_test_aiguest_step();
    coop_test_lang_step();
    coop_test_soak_step();
    coop_test_menus_step();
    coop_test_backup_step();
    coop_test_report_step();
    coop_test_panelraid_step();
    coop_test_group_step();
    coop_test_ff_step();
    coop_test_kick_step();
    coop_test_extract_step();
    coop_test_tutorial_step();
    coop_test_spectate_step();
    coop_test_drag_step();
    coop_test_rejoin_step();
    coop_test_pda_step();
    coop_test_questloot_step();
    coop_test_fallen_step();
    coop_test_trade_step();
    coop_test_voice_step();
    coop_test_radio_step();
    coop_test_event_step();
    coop_test_quest_step();
    coop_test_barq_step();
    coop_test_arena_step();
    coop_test_migrate_step();
    coop_test_treefade_step();
    coop_test_bystand_step();
    if (_c.scenario != "livechest" || !coop_shared_ready() || !instance_exists(obj_player))
    {
        exit;
    }
    if (!variable_struct_exists(_c, "lt")) _c.lt = 0;
    _c.lt++;
    var _t = _c.lt;
    var _tag = _c.tag;
    obj_player.hp = obj_player.hp_max; // 1.4 enemies near the chest killed both players once (death closes the chest UI)
    if (_t >= 110 && _t <= 138 && !variable_struct_exists(_c, "lc_chest"))
    {
        instance_activate_object(obj_chest_general); // effective from the next step; culling may undo it
    }
    if (_t >= 111 && _t <= 139 && !variable_struct_exists(_c, "lc_chest") && (instance_number(obj_chest_general) > 20 || _t == 139))
    {
        // nearest container to the shared spawn (same on both machines)
        var _best = -4;
        var _bd = infinity;
        var _px = 4800; // the shared spawn point: both pick the same container
        var _py = 1304;
        with (obj_chest_general)
        {
            // map containers only: corpses / bags made during the raid (1.4 roaming squads fight off screen and
            // leave bodies) reach the other machines a little later
            if (variable_instance_exists(id, "coop_dynamic") || variable_instance_exists(id, "coop_net_spawned")) continue;
            var _d = point_distance(x, y, _px, _py);
            if (_d < _bd) { _bd = _d; _best = id; }
        }
        _c.lc_chest = _best;
        coop_log("lc: chests=", instance_number(obj_chest_general), " nearest=", _best, " d=", _bd);
        if (instance_exists(_best))
        {
            obj_player.x = _best.x + 8 + ((_c.role == "host") ? 0 : 6);
            obj_player.y = _best.y + 10;
        }
    }
    if (_t == 140 && variable_struct_exists(_c, "lc_chest") && instance_exists(_c.lc_chest))
    {
        player_action_open_chest(_c.lc_chest);
        coop_log("lc: opened ", coop_chest_key(_c.lc_chest), " layer=", uiLayerGetRoot("inventory layer") != undefined);
    }
    if (_t > 140 && _t < 200 && _t mod 6 == 0)
    {
        coop_log("lc dbg t=", _t, " using=", uiGetData().chest_using, " layer=", uiLayerGetRoot("inventory layer") != undefined, " inv_state=", player_state_is(0, scr_player_state_inventory));
    }
    // the second look is ~4 s after the host took the item: the two test clocks differ by seconds
    if (_t == 160 || _t == 450)
    {
        var _it = coop_chest_ui_items();
        coop_log("lc t=", _t, " ui items=", (_it == undefined) ? -1 : array_length(_it));
        screen_save("lc_" + string(_t) + "_" + _tag + ".png");
    }
    if (_t == 200 && _c.role == "host")
    {
        var _root = uiLayerGetRoot("inventory layer");
        if (_root == undefined) { coop_log("lc: no inventory layer"); exit; }
        var _arr = uiFindAllType(_root, "class_ui_item");
        for (var _i = 0; _i < array_length(_arr); _i++)
        {
            if (_arr[_i].Get("parent").identifier == "other inventory")
            {
                _arr[_i].Destroy();
                coop_log("lc: host removed one item from the open chest");
                break;
            }
        }
    }
    if (_t == 470)
    {
        ui_chest_close();
        __uiGlobal().__defaultOnion.Clear();
        player_set_local_state(scr_player_state_move);
    }
    if (_t == 510 && _c.role == "guest")
    {
        var _bag = instance_create_depth(obj_player.x, obj_player.y + 6, -obj_player.y, obj_chest_general);
        _bag.tipo = "discard";
        db_open("all loot");
        db_write("chest_" + string(_bag.id), "chest_x", _bag.x);
        db_write("chest_" + string(_bag.id), "chest_y", _bag.y);
        db_write("chest_" + string(_bag.id), "items", [new class_loot("bandage", 1)]);
        db_close();
        coop_log("lc: guest dropped a bag");
    }
    if (_t == 570 && _c.role == "host")
    {
        var _gid = "grenade_flash";
        var _g = instance_create_depth(obj_player.x, obj_player.y, 0, obj_grenade_parent,
        {
            grenade_id: _gid,
            throw_min: item_grenade_get_throw_min(_gid),
            throw_max: item_grenade_get_throw_max(_gid),
            fuse_time: item_grenade_get_fuse_time(_gid),
            throw_type: item_grenade_get_throw_type(_gid),
            damage_max: item_grenade_get_damage_max(_gid),
            damage_min: item_grenade_get_damage_min(_gid),
            detonation_type: item_grenade_get_detonation_type(_gid),
            detonation_duration: item_grenade_get_detonation_duration(_gid),
            radius_max_damage: item_grenade_get_radius_max_damage(_gid),
            radius_min_damage: item_grenade_get_radius_min_damage(_gid),
            throw_direction: 0,
            detonation_point: 160,
            sprite_index: item_get_sprite_ingame(_gid),
            throw_speed: 3
        });
        _g.thrown_by_player = true;
        coop_log("lc: host threw a flashbang");
    }
    if (_t == 670 && _c.role == "host")
    {
        player_action_open_minimap();
    }
    if (_t == 730 && _c.role == "host")
    {
        screen_save("lc_map_" + _tag + ".png");
    }
    if (_t == 790)
    {
        __uiGlobal().__defaultOnion.Clear();
        player_set_local_state(scr_player_state_move);
        coop_log("lc: done");
    }
}

function coop_test_join_step()
{
    var _c = coop();
    if (!is_in_hub() || !instance_exists(obj_player))
    {
        exit;
    }
    if (!variable_struct_exists(_c, "jt")) _c.jt = 0;
    _c.jt++;
    if (_c.role == "host" && _c.jt == 60)
    {
        coop_log("join test: host goes into the raid alone");
        go_to_map(1);
    }
    if (_c.role == "guest" && _c.jt > 90 && !variable_struct_exists(_c, "join_sent") && coop_can_join_host_raid())
    {
        _c.join_sent = true;
        coop_request_join();
    }
}

// v3 scenario: kill credit (guest shoots an NPC), forced emission (host), co-op pause (host).
function coop_test_v3_step()
{
    var _c = coop();
    if (_c.scenario != "v3" || !coop_shared_ready())
    {
        exit;
    }
    if (!variable_struct_exists(_c, "v3t")) _c.v3t = 0;
    _c.v3t++;
    var _t = _c.v3t;
    if (_t == 120)
    {
        // group scaling: the NPCs the host made (and the guest's replicas of them) carry the same hp
        var _sum = 0;
        var _n = 0;
        var _list = "";
        instance_activate_object(obj_npc_parent);
        with (obj_npc_parent)
        {
            if (variable_instance_exists(id, "coop_nid") && coop_nid < 40 && object_is_ancestor(object_index, obj_npc_human_parent))
            {
                // max hp: 1.4 squads may already fight each other, and host and guest measure at slightly different moments
                var _hm = variable_instance_exists(id, "hp_max") ? hp_max : hp;
                _sum += _hm;
                _n++;
                _list += string(coop_nid) + ":" + string(round(_hm)) + " ";
            }
        }
        coop_log("v3: group hp factor=", coop_group_factor("hp"), " npc hp sum=", _sum, " n=", _n);
        coop_log("v3: npc hp list ", _list);
    }
    if (_c.role == "guest" && instance_exists(obj_player) && _t >= 150 && _t <= 600)
    {
        if (!variable_struct_exists(_c, "v3_target") || !instance_exists(_c.v3_target))
        {
            var _best = -4;
            var _bd = infinity;
            instance_activate_object(obj_npc_parent);
            with (obj_npc_parent)
            {
                if (coop_npc_is_replica() && hp > 0 && object_is_ancestor(object_index, obj_npc_human_parent))
                {
                    var _d = point_distance(x, y, obj_player.x, obj_player.y);
                    if (_d < _bd) { _bd = _d; _best = id; }
                }
            }
            _c.v3_target = _best;
            if (instance_exists(_best))
            {
                obj_player.x = _best.x - 50;
                obj_player.y = _best.y;
                coop_log("v3: guest targets ", object_get_name(_best.object_index), " d=", _bd);
            }
        }
        else if (_t mod 12 == 0)
        {
            var _tg = _c.v3_target;
            obj_player.x = _tg.x - 50;
            obj_player.y = _tg.y;
            if (_t mod 48 == 0) coop_log("v3: replica at ", floor(_tg.x), ",", floor(_tg.y), " hp=", _tg.hp);
            with (obj_player)
            {
                if (item_exists(arma_now) && item_get_category(arma_now) == "weapon")
                {
                    scr_shoot(point_direction(x, y, _tg.x, _tg.y), 1, item_weapon_get_damage(arma_now) * 3, 0);
                }
            }
        }
    }
    if (_c.role == "host" && _t == 300)
    {
        with (obj_meteo_controller)
        {
            alarm[0] = 2;
            alarm[1] = 1;
        }
        coop_log("v3: host forces an emission");
    }
    if (_c.role == "host" && _t == 480)
    {
        coop_log("v3: host pauses");
        game_pause();
    }
    if (_c.role == "host" && _t == 600)
    {
        game_unpause();
        coop_log("v3: host unpaused, player exists=", instance_exists(obj_player));
    }
    if (_t == 720)
    {
        coop_log("v3: done");
    }
}

// -coop_scenario fps: walk right for 300 logic ticks and log how far / how long it took (compare -coop_fps 60 vs 165).
function coop_test_fps_step()
{
    var _c = coop();
    if (!_c.test_mode || _c.scenario != "fps" || !coop_raid_ready() || !instance_exists(obj_player) || !player_state_is(0, scr_player_state_move))
    {
        exit;
    }
    if (!variable_struct_exists(_c, "ft")) _c.ft = 0;
    _c.ft++;
    var _t = _c.ft;
    var _gt = instance_exists(obj_light_controller) ? obj_light_controller.game_time_played : 0;
    if (_t == 120 || _t == 900)
    {
        _c.f_us = get_timer();
        _c.f_x = obj_player.x;
        _c.f_y = obj_player.y;
        _c.f_gt = _gt;
        // hold a direction toward the middle of the map (spawns can be at an edge, and walking off the map moves
        // the player): horizontal first, then vertical. kb_hold: 0 up, 1 down, 2 right, 3 left (coop_test_input)
        var _mh = instance_exists(obj_map_generator) ? obj_map_generator.map_height : room_height;
        if (_t == 120) _c.f_key = (obj_player.x > room_width / 2) ? 3 : 2;
        else _c.f_key = (obj_player.y > _mh / 2) ? 0 : 1;
    }
    if (_t == 420 || _t == 1200)
    {
        _c.f_key = -1;
        coop_log("fpstest: 300 ticks real_s=", (get_timer() - _c.f_us) / 1000000, " dx=", obj_player.x - _c.f_x, " dy=", obj_player.y - _c.f_y,
            " game_s+=", (_gt - _c.f_gt) * 86400, " fps_real=", fps_real, " speed=", game_get_speed(gamespeed_fps), " npcs=", instance_number(obj_npc_parent));
    }
    if (_t == 300 || _t == 1000)
    {
        screen_save("fps_" + string(_t) + "_" + _c.tag + ".png");
    }
}

// obj_player Begin Step, right after the game read the keyboard: scripted held keys (test mode only).
function coop_test_input()
{
    var _c = coop();
    if (_c.test_mode && variable_struct_exists(_c, "f_key") && _c.f_key >= 0)
    {
        global.kb_hold[_c.f_key] = true;
    }
}

// -coop_scenario anim: the guest bandages itself, eats, toggles torch/laser; the host logs/screenshots the puppet.
function coop_test_anim_step()
{
    var _c = coop();
    if (!_c.test_mode || _c.scenario != "anim" || !coop_shared_ready() || !instance_exists(obj_player) || !_c.peer_in_raid)
    {
        exit;
    }
    if (!variable_struct_exists(_c, "at")) _c.at = 0;
    _c.at++;
    var _t = _c.at;
    if (_c.role == "guest")
    {
        var _host = coop_test_partner();
        with (obj_player)
        {
            if (_t == 150 && instance_exists(_host))
            {
                x = _host.x + 24;
                y = _host.y;
            }
            if ((_t == 200 || _t == 700) && arms_holder == undefined && player_state_is(0, scr_player_state_move))
            {
                var _item = (_t == 200) ? "bandage" : "bread";
                var _anim = (_t == 200) ? item_med_get_animation(_item) : item_consumable_get_animation(_item);
                arms_holder = new class_player_arms(id, _item, _anim);
                coop_log("anim: guest uses ", _item, " sprite=", sprite_get_name(_anim));
            }
            if (_t == 1050)
            {
                // moddable rifle with a tactical torch on att_1 (test only)
                var _loot = player_loadout_get_loot(id, weapon_slot_now);
                if (is_struct(_loot))
                {
                    _loot.item = "ak_74";
                    var _m = loot_mod_cont_create();
                    loot_mod_cont_copy_from_default(_m, "ak_74");
                    loot_mod_cont_set(_m, "handguard", "mod_ak74_handguard_3");
                    loot_mod_cont_set(_m, "att_1", "mod_torch_1");
                    _loot.mods = _m;
                    arma_now = "ak_74";
                    coop_send_loadout();
                }
            }
            if (_t == 1200) _c.f_key = 2; // walk right (footsteps)
            if (_t == 1320) _c.f_key = -1;
            if (_t == 1350)
            {
                player_action_reload();
                coop_log("anim: guest reload, reloading=", reloading);
            }
            if (_t == 1100)
            {
                torch_on_general = true;
                laser_on_general = true;
                coop_log("anim: guest torch+laser on, weapon=", arma_now);
            }
        }
        exit;
    }
    var _p = coop_test_partner();
    if (!instance_exists(_p))
    {
        exit;
    }
    if (_t == 1000)
    {
        with (obj_light_controller)
        {
            time_increment_seconds(((23 - time_get_hours() + 24) mod 24) * 3600);
        }
    }
    if (_t mod 30 == 0 && _t > 1000)
    {
        var _tc = _p.torch_container_array[_p.weapon_slot_now].data.att_1;
        coop_log("anim: puppet torch att_1 have=", _tc.have, " on=", _tc.on, " x=", _tc.x, " y=", _tc.y, " arma=", _p.arma_now, " hour=", time_get_hours());
    }
    if (_t mod 30 == 0)
    {
        var _a = _p.arms_holder;
        coop_log("anim: puppet arms=", is_struct(_a) ? sprite_get_name(_a.sprite_index) + " img=" + string(_a.image_index) : "none",
            " state=", script_get_name(_p.state), " torch=", _p.torch_on_general, " laser=", _p.laser_on_general,
            " w=", _p.weapon_holder.x - _p.x, ",", _p.weapon_holder.y - _p.y, " ang=", _p.weapon_holder.image_angle);
        if (is_struct(_a) && !variable_struct_exists(_c, "anim_shot_" + sprite_get_name(_a.sprite_index)))
        {
            variable_struct_set(_c, "anim_shot_" + sprite_get_name(_a.sprite_index), true);
            _c.anim_shot_t = _t + 40;
            _c.anim_shot_n = sprite_get_name(_a.sprite_index);
        }
    }
    if (variable_struct_exists(_c, "anim_shot_t") && _t == _c.anim_shot_t)
    {
        screen_save("anim_" + _c.anim_shot_n + ".png");
    }
    if (_t == 1500 || _t == 1700)
    {
        screen_save("anim_light_" + string(_t) + ".png");
    }
}

// -coop_scenario tele: the guest jumps to a far NPC every second (hunting a freeze seen after long teleports).
function coop_test_tele_step()
{
    var _c = coop();
    if (!_c.test_mode || _c.scenario != "tele" || _c.role != "guest" || !coop_shared_ready() || !instance_exists(obj_player))
    {
        exit;
    }
    if (!variable_struct_exists(_c, "tt")) _c.tt = 0;
    _c.tt++;
    if (_c.tt < 120 || _c.tt mod 60 != 0)
    {
        exit;
    }
    var _list = [];
    instance_activate_object(obj_npc_parent);
    with (obj_npc_parent)
    {
        if (point_distance(x, y, obj_player.x, obj_player.y) > 700)
        {
            array_push(_list, id);
        }
    }
    if (array_length(_list) == 0)
    {
        exit;
    }
    var _tg = _list[irandom(array_length(_list) - 1)];
    coop_log("tele #", _c.tt div 60, " to ", object_get_name(_tg.object_index), " at ", floor(_tg.x), ",", floor(_tg.y), " from ", floor(obj_player.x), ",", floor(obj_player.y));
    obj_player.x = _tg.x - 50;
    obj_player.y = _tg.y;
}

// -coop_scenario leave: the host walks onto an extraction point and leaves; the guest carries on alone.
function coop_test_leave_step()
{
    var _c = coop();
    if (!_c.test_mode || _c.scenario != "leave")
    {
        exit;
    }
    if (!variable_struct_exists(_c, "lv")) _c.lv = 0;
    if (_c.role == "host" && coop_shared_ready() && instance_exists(obj_player))
    {
        _c.lv++;
        if (_c.lv == 300 || (_c.lv > 300 && _c.lv mod 60 == 0 && coop_in_raid()))
        {
            instance_activate_object(obj_extraction_point);
            var _ex = undefined;
            var _ey = undefined;
            with (obj_extraction_point)
            {
                _ex = x;
                _ey = y;
            }
            if (variable_struct_exists(_c, "lv_x"))
            {
                _ex = _c.lv_x;
                _ey = _c.lv_y;
            }
            if (_ex != undefined)
            {
                _c.lv_x = _ex;
                _c.lv_y = _ey;
                obj_player.x = _ex + 8;
                obj_player.y = _ey + 8;
                coop_log("leave: host on extraction point at ", _ex, ",", _ey);
            }
        }
    }
    if (_c.role == "host" && instance_exists(obj_exit_screen) && obj_exit_screen.can_go_hub && !variable_struct_exists(_c, "lv_gone"))
    {
        // the "next" button of the extraction screen, minus the save bookkeeping (test saves only)
        _c.lv_gone = true;
        coop_log("leave: host leaves the extraction screen for the hub");
        instance_activate_all();
        obj_controller.disattiva = false;
        __uiGlobal().__defaultOnion.Clear();
        room_goto(r_hub);
    }
    if (_c.role == "guest" && coop_in_raid() && instance_exists(obj_player))
    {
        _c.lv++;
        if (_c.lv mod 300 == 0)
        {
            var _active = 0;
            var _repl = 0;
            with (obj_npc_parent)
            {
                _active++;
                if (coop_npc_is_replica()) _repl++;
            }
            coop_log("leave: guest t=", _c.lv, " peer_in_raid=", _c.peer_in_raid, " peer_loc=", _c.peer_loc, " npcs=", _active, " replicas=", _repl,
                " slaved=", coop_world_guest_skips_roll(), " hp=", obj_player.hp);
        }
    }
}

// -coop_scenario quad (tools/test4.sh): everybody sees everybody, slot 1 kills NPCs (credit), slot 2 goes down and
// the host revives it.
function coop_test_quad_step()
{
    var _c = coop();
    if (!_c.test_mode || _c.scenario != "quad" || !coop_shared_ready() || !instance_exists(obj_player))
    {
        exit;
    }
    if (!variable_struct_exists(_c, "qt")) _c.qt = 0;
    _c.qt++;
    var _t = _c.qt;
    if (_t == 200 || _t == 900)
    {
        var _l = coop_puppets();
        var _s = "";
        for (var _i = 0; _i < array_length(_l); _i++) _s += string(_l[_i].coop_slot) + ":" + _l[_i].coop_name + " ";
        coop_log("quad: me slot ", _c.slot, " players=", coop_player_count(), " puppets=", array_length(_l), " [", _s, "]");
    }
    if (_c.slot == 1 && _t >= 300 && _t <= 700 && _t mod 12 == 0)
    {
        // like the v3 scenario: stand next to a replica and shoot it
        if (!variable_struct_exists(_c, "q_tg") || !instance_exists(_c.q_tg) || _c.q_tg.hp <= 0)
        {
            instance_activate_object(obj_npc_parent);
            var _best = -4;
            var _bd = infinity;
            with (obj_npc_parent)
            {
                if (coop_npc_is_replica() && hp > 0 && object_is_ancestor(object_index, obj_npc_human_parent))
                {
                    var _d = point_distance(x, y, obj_player.x, obj_player.y);
                    if (_d < _bd) { _bd = _d; _best = id; }
                }
            }
            _c.q_tg = _best;
        }
        var _tg = _c.q_tg;
        if (instance_exists(_tg))
        {
            obj_player.x = _tg.x - 50;
            obj_player.y = _tg.y;
            with (obj_player)
            {
                if (item_exists(arma_now) && item_get_category(arma_now) == "weapon")
                {
                    scr_shoot(point_direction(x, y, _tg.x, _tg.y), 1, item_weapon_get_damage(arma_now) * 3, 0);
                }
            }
        }
    }
    if (_c.slot == 2 && _t == 260)
    {
        coop_log("quad: slot 2 takes lethal damage");
        obj_player.hp = 0;
    }
    if (_c.slot == 0 && _t > 300)
    {
        var _down = coop_puppet_of(2);
        if (instance_exists(_down) && coop_puppet_is_down(_down))
        {
            if (!variable_struct_exists(_c, "q_rev"))
            {
                _c.q_rev = _t;
                obj_player.x = _down.x + 12;
                obj_player.y = _down.y;
                coop_log("quad: host goes to downed slot 2");
            }
            var _k = _t - _c.q_rev;
            if (_k == 60 || _k == 100)
            {
                _c.sim_e = true;
            }
            if (_k == 30 || _k == 90)
            {
                obj_player.x = _down.x + 12;
                obj_player.y = _down.y;
            }
        }
    }
    if (_t == 420 + max(0, _c.slot) * 20)
    {
        _c.sim_ping = true;
    }
    // slot 1: a mark, then a second click on the same spot takes it away (for everybody)
    if (_c.slot == 1 && (_t == 600 || _t == 640))
    {
        if (_t == 600) _c.sim_ping_at = [obj_player.x + 40, obj_player.y]; // the same spot both times (the player walks)
        _c.sim_ping = true;
    }
    if (_t == 490)
    {
        screen_save("quad_ui_" + _c.tag + ".png"); // name tags, ping marks, arrows to teammates off screen
    }
    // the last slot hands the host an item
    if (_c.slot == coop_player_count() - 1 && _c.slot >= 2 && (_t == 940 || _t == 941 || _t == 942))
    {
        var _h = coop_puppet_of(0);
        if (instance_exists(_h))
        {
            obj_player.x = _h.x + 16;
            obj_player.y = _h.y;
        }
        if (_t == 941) { _c.sim_give_to = 0; _c.sim_give = true; }
        if (_t == 942) _c.sim_give_ok = true;
    }
    if (_t == 1000)
    {
        coop_log("quad: done");
    }
}

// -coop_scenario handoff (tools/test4.sh): the host extracts while the three guests stay; slot 1 becomes the raid
// owner and keeps the world shared; slot 2 kills NPCs and gets the credit from the new owner.
function coop_test_handoff_step()
{
    var _c = coop();
    if (!_c.test_mode || !(_c.scenario == "handoff" || (_c.scenario == "ownerjoin" && _c.slot <= 1)))
    {
        exit;
    }
    if (!variable_struct_exists(_c, "ht")) _c.ht = 0;
    if (_c.slot == 0)
    {
        if (instance_exists(obj_exit_screen) && obj_exit_screen.can_go_hub && !variable_struct_exists(_c, "ho_gone"))
        {
            _c.ho_gone = true;
            coop_log("handoff: host leaves the extraction screen");
            instance_activate_all();
            obj_controller.disattiva = false;
            __uiGlobal().__defaultOnion.Clear();
            room_goto(r_hub);
        }
        if (coop_shared_ready() && instance_exists(obj_player))
        {
            _c.ht++;
            if (_c.ht >= 300 && _c.ht mod 60 == 0)
            {
                if (!variable_struct_exists(_c, "ho_x"))
                {
                    instance_activate_object(obj_extraction_point); // found from the next step on
                    with (obj_extraction_point) { _c.ho_x = x; _c.ho_y = y; }
                    if (variable_struct_exists(_c, "ho_x")) coop_log("handoff: host walks to the extraction at ", _c.ho_x, ",", _c.ho_y);
                }
                if (variable_struct_exists(_c, "ho_x"))
                {
                    obj_player.x = _c.ho_x + 8;
                    obj_player.y = _c.ho_y + 8;
                }
            }
        }
        exit;
    }
    if (!coop_in_raid() || !instance_exists(obj_player))
    {
        exit;
    }
    _c.ht++;
    var _t = _c.ht;
    var _hp0 = coop_peer(0);
    var _host_gone = !is_struct(_hp0) || !_hp0.in_raid;
    if (_t mod 300 == 0)
    {
        var _r = 0;
        var _n = 0;
        with (obj_npc_parent) { _n++; if (coop_npc_is_replica()) _r++; }
        coop_log("handoff: t=", _t, " slot ", _c.slot, " host_gone=", _host_gone, " owner=", coop_raid_owner(), " shared=", coop_shared_ready(), " npcs=", _n, " replicas=", _r, " puppets=", array_length(coop_puppets()));
    }
    if (!_host_gone)
    {
        _c.h_seen = true;
        exit;
    }
    if (!variable_struct_exists(_c, "h_seen"))
    {
        exit; // the host has not shown up in the raid yet
    }
    if (!variable_struct_exists(_c, "h_gone_t"))
    {
        _c.h_gone_t = _t;
        coop_log("handoff: host gone at t=", _t);
    }
    var _k = _t - _c.h_gone_t;
    if (_c.slot == 2 && _k >= 180 && _k <= 600 && _k mod 12 == 0)
    {
        if (!variable_struct_exists(_c, "h_tg") || !instance_exists(_c.h_tg) || _c.h_tg.hp <= 0)
        {
            instance_activate_object(obj_npc_parent);
            var _best = -4;
            var _bd = infinity;
            with (obj_npc_parent)
            {
                if (coop_npc_is_replica() && hp > 0 && object_is_ancestor(object_index, obj_npc_human_parent))
                {
                    var _d = point_distance(x, y, obj_player.x, obj_player.y);
                    if (_d < _bd) { _bd = _d; _best = id; }
                }
            }
            _c.h_tg = _best;
        }
        var _tg = _c.h_tg;
        if (instance_exists(_tg))
        {
            obj_player.x = _tg.x - 50;
            obj_player.y = _tg.y;
            with (obj_player)
            {
                if (item_exists(arma_now) && item_get_category(arma_now) == "weapon")
                {
                    scr_shoot(point_direction(x, y, _tg.x, _tg.y), 1, item_weapon_get_damage(arma_now) * 3, 0);
                }
            }
        }
    }
    if (_k == 720)
    {
        coop_log("handoff: done");
    }
}

// -coop_scenario soak (tools/soak.py): a long session - everyone walks around, slot 1 keeps shooting NPCs,
// everyone pings now and then; the NPC consistency check runs as usual.
function coop_test_soak_step()
{
    var _c = coop();
    if (!_c.test_mode || _c.scenario != "soak" || !coop_shared_ready() || !instance_exists(obj_player))
    {
        exit;
    }
    if (!variable_struct_exists(_c, "st")) _c.st = 0;
    _c.st++;
    var _t = _c.st;
    if (_t mod 3600 == 0)
    {
        coop_log("soak: minute ", _t div 3600, " players=", coop_player_count(), " puppets=", array_length(coop_puppets()), " known npcs=", ds_map_size(_c.npc_by_nid));
    }
    if (_t mod 1500 == 300 + max(0, _c.slot) * 60)
    {
        _c.sim_ping = true;
    }
    // walk a slow circle around the start point (each player its own)
    if (!variable_struct_exists(_c, "so_x"))
    {
        _c.so_x = obj_player.x;
        _c.so_y = obj_player.y;
    }
    if (_c.slot != 1)
    {
        var _a = _t * 0.6 + max(0, _c.slot) * 90;
        var _r = 40 + max(0, _c.slot) * 12;
        with (obj_player)
        {
            var _nx = _c.so_x + lengthdir_x(_r, _a);
            var _ny = _c.so_y + lengthdir_y(_r, _a);
            if (!place_meeting(_nx, _ny, obj_solid))
            {
                x = _nx;
                y = _ny;
            }
        }
        exit;
    }
    // slot 1: hunt NPCs (two shots a second)
    if (_t mod 30 != 0)
    {
        exit;
    }
    if (!variable_struct_exists(_c, "so_tg") || !instance_exists(_c.so_tg) || _c.so_tg.hp <= 0)
    {
        instance_activate_object(obj_npc_parent);
        var _best = -4;
        var _bd = infinity;
        with (obj_npc_parent)
        {
            if (hp > 0 && (coop_npc_is_replica() || coop_is_world_owner()) && object_is_ancestor(object_index, obj_npc_human_parent))
            {
                var _d = point_distance(x, y, obj_player.x, obj_player.y);
                if (_d < _bd) { _bd = _d; _best = id; }
            }
        }
        _c.so_tg = _best;
    }
    var _tg = _c.so_tg;
    if (instance_exists(_tg))
    {
        obj_player.x = _tg.x - 50;
        obj_player.y = _tg.y;
        with (obj_player)
        {
            if (item_exists(arma_now) && item_get_category(arma_now) == "weapon")
            {
                scr_shoot(point_direction(x, y, _tg.x, _tg.y), 1, item_weapon_get_damage(arma_now) * 2, 0);
            }
        }
    }
}

// -coop_scenario menus: screenshots of the main menu (Co-op button, the harness clicks it), the panel it opens,
// then the pause menu in the bunker.
function coop_test_menus_step()
{
    var _c = coop();
    if (!_c.test_mode || _c.scenario != "menus")
    {
        exit;
    }
    if (!variable_struct_exists(_c, "mt")) { _c.mt = 0; _c.mh = 0; }
    if (room == r_menu)
    {
        _c.mt++;
        if (_c.mt == 240)
        {
            screen_save("menu_main.png");
            coop_log("menus: main menu shot");
            coop_log("menus: description ", coop_difficulty_description("coop.desc.down_seconds"), " | tab ", language_get_string("coop.difficulty.tab"));
        }
        if (_c.mt == 600 && !_c.connected)
        {
            screen_save("menu_mods.png"); // the tester clicks "Mods" meanwhile (um win drive)
        }
        if (_c.mt > 240 && _c.panel && !variable_struct_exists(_c, "m_panel"))
        {
            _c.m_panel = _c.mt;
            coop_log("menus: panel opened from the menu button");
        }
        if (variable_struct_exists(_c, "m_panel") && _c.mt == _c.m_panel + 30)
        {
            screen_save("menu_panel.png");
            _c.panel = false;
            saveslot_load(1);
        }
    }
    if (is_in_hub() && (instance_exists(obj_player) || _c.mh >= 120)) // the pause deactivates the player
    {
        _c.mh++;
        if (_c.mh == 120)
        {
            game_pause();
        }
        if (_c.mh == 200)
        {
            screen_save("menu_pause.png");
            coop_log("menus: pause menu shot");
        }
    }
}

// -coop_scenario treefade: stand under a tree canopy and walk (with -coop_seq_dump to grab rendered frames).
function coop_test_treefade_step()
{
    var _c = coop();
    if (!_c.test_mode || _c.scenario != "treefade" || !coop_in_raid() || !instance_exists(obj_player))
    {
        exit;
    }
    // trees become one baked mesh (obj_vertex_props destroys the instances): remember one before that
    if (!variable_struct_exists(_c, "tf_x"))
    {
        instance_activate_object(obj_tree);
        var _t = instance_nearest(obj_player.x, obj_player.y, obj_tree);
        if (instance_exists(_t))
        {
            _c.tf_x = _t.x;
            _c.tf_y = _t.y;
            coop_log("treefade: tree at ", _t.x, ",", _t.y);
        }
    }
    if (!coop_shared_ready() || !variable_struct_exists(_c, "tf_x") || !player_state_is(0, scr_player_state_move))
    {
        exit; // (the raid's intro scene would put the player back)
    }
    if (!variable_struct_exists(_c, "tf")) _c.tf = 0;
    _c.tf++;
    if (_c.tf == 60)
    {
        obj_player.x = _c.tf_x + 30;
        obj_player.y = _c.tf_y - 8;
        coop_log("treefade: player next to the tree");
    }
    if (_c.tf == 120) _c.f_key = 3; // walk left through the canopy
    if (_c.tf == 300) _c.f_key = -1;
}

// Lobby + visit (both players in the hub): the guest walks next to the host, then visits the host's bunker,
// whose modules the test changes on the guest's side (both test saves have the same bunker).
function coop_test_lobby_step(_t)
{
    var _c = coop();
    var _tag = _c.tag;
    if (_t == 200)
    {
        coop_log("lobby: puppets=", array_length(coop_puppets()), " together=", coop_hub_together());
        screen_save("hub_lobby_" + _tag + ".png");
    }
    // the guest hands the host an item in the bunker (straight into the host's inventory grid)
    if (_c.scenario == "lobby" && _c.role == "guest" && (_t == 240 || _t == 241 || _t == 242))
    {
        var _h = coop_puppet_of(0);
        if (instance_exists(_h))
        {
            obj_player.x = _h.x + 16;
            obj_player.y = _h.y;
        }
        if (_t == 241) { _c.sim_give_to = 0; _c.sim_give = true; }
        if (_t == 242) _c.sim_give_ok = true;
    }
    if (_c.role != "guest")
    {
        if (_t == 1200) game_end();
        exit;
    }
    var _host = coop_peer(0);
    if (_c.scenario == "lobby2")
    {
        coop_test_lobby2_step(_t);
        exit;
    }
    // GitHub issue #1: a normal pause in the hub while connected (hub_t stops while the player is set aside;
    // coop_test_pause_step runs the rest every frame)
    if (_t == 120)
    {
        _c.pause_test = 0;
        game_pause();
        coop_log("lobby: paused in the hub, controller=", instance_exists(obj_controller), " menu=", instance_exists(obj_main_menu));
    }
    if (_t == 220)
    {
        coop_visit_place_player();
    }
    if (_t == 250)
    {
        screen_save("hub_room_" + _tag + ".png");
    }
    if (_t == 260 && is_struct(_host) && variable_struct_exists(_host, "base"))
    {
        // a different bunker: every free slot gets the next module not installed yet, at level 1
        var _d = _host.base;
        var _used = array_create(array_length(_d.lvl), false);
        for (var _i = 0; _i < array_length(_d.sb); _i++)
        {
            if (_d.sb[_i] >= 0 && _d.sb[_i] < array_length(_used)) _used[_d.sb[_i]] = true;
        }
        // and the modules of slots 0/4 and 1/5 swapped, all at level 2
        var _tmp = _d.sb[0]; _d.sb[0] = _d.sb[4]; _d.sb[4] = _tmp;
        _tmp = _d.sb[1]; _d.sb[1] = _d.sb[5]; _d.sb[5] = _tmp;
        for (var _i = 0; _i < array_length(_d.sb); _i++)
        {
            if (_d.sb[_i] >= 0) _d.lvl[_d.sb[_i]] = max(2, _d.lvl[_d.sb[_i]]);
        }
        coop_log("lobby: test bunker ", json_stringify(_d));
        _c.lobby_own = json_stringify(coop_base_capture());
        coop_visit_start(0);
        coop_log("lobby: visiting=", coop_visit_active(), " player at ", obj_player.x, ",", obj_player.y, " own ", _c.lobby_own);
    }
    if (_t == 300 || _t == 380)
    {
        coop_log("lobby: player at ", obj_player.x, ",", obj_player.y, " inside=", is_inside_bunker());
    }
    if (_t == 340)
    {
        screen_save("hub_visit_" + _tag + ".png");
        scr_save_skill_and_base(); // must write our own modules
        db_open("general");
        var _ok = true;
        for (var _i = 0; _i < array_length(global.sl_id); _i++)
        {
            var _own = json_parse(_c.lobby_own);
            if (db_read("Base slot", string(global.sl_id[_i]), -99) != _own.sb[global.sl_id[_i]]) _ok = false;
        }
        db_close();
        coop_log("lobby: save during visit wrote own modules=", _ok, " modules now=", json_stringify(global.sl_base_id));
    }
    if (_t == 420)
    {
        coop_visit_end("panel");
        coop_log("lobby: restored=", json_stringify(coop_base_capture()) == _c.lobby_own);
    }
    if (_t == 480)
    {
        screen_save("hub_back_" + _tag + ".png");
    }
    if (_t == 1200) game_end();
}

// Runs every frame (also while the world is paused): see the pause step of coop_test_lobby_step.
function coop_test_pause_step()
{
    var _c = coop();
    if (!_c.test_mode || !variable_struct_exists(_c, "pause_test") || _c.pause_test < 0)
    {
        exit;
    }
    _c.pause_test++;
    if (_c.pause_test == 60)
    {
        // before the fix obj_player was woken here without obj_controller and crashed in its Step
        coop_log("lobby: paused 60 frames, player active=", instance_exists(obj_player), " controller=", instance_exists(obj_controller));
        game_unpause();
    }
    if (_c.pause_test == 120)
    {
        coop_log("lobby: pause test done, player=", instance_exists(obj_player), " controller=", instance_exists(obj_controller));
        _c.pause_test = -1;
    }
}

// Furniture of our own modules that is there from the start (vertex batching runs ~8 frames into the hub):
// it must disappear while visiting a friend without modules and come back after. The modules are raised in
// memory only and put back at the end (nothing of it is saved).
function coop_lobby_count_decor()
{
    var _n = 0;
    with (obj_decor_parent)
    {
        if (coop_is_base_decor(id)) _n++;
    }
    return _n;
}

function coop_lobby_dump(_what)
{
    var _s = "";
    with (obj_base_parent)
    {
        _s += " [" + string(slot) + ":" + string(id_base) + "@" + string(lvl_now) + "]";
    }
    var _names = {};
    with (obj_decor_parent)
    {
        if (coop_is_base_decor(id))
        {
            var _on = object_get_name(object_index) + (visible ? "" : "(inv)");
            variable_struct_set(_names, _on, (variable_struct_exists(_names, _on) ? variable_struct_get(_names, _on) : 0) + 1);
        }
    }
    coop_log("lobby2 ", _what, ": decor ", json_stringify(_names));
    coop_log("lobby2 ", _what, ": slots", _s, " sb=", json_stringify(global.sl_base_id), " lvl=", json_stringify(global.base_lvl), " decor=", coop_lobby_count_decor());
}

function coop_test_lobby2_step(_t)
{
    var _c = coop();
    if (_t == 229 || _t == 299 || _t == 369) coop_lobby_dump(string(_t));
    if (_t == 1)
    {
        _c.lobby_orig = coop_base_capture();
        for (var _i = 0; _i < array_length(global.sl_base_id); _i++)
        {
            if (global.sl_base_id[_i] >= 0 && global.sl_free[_i] == 2) global.base_lvl[global.sl_base_id[_i]] = 2;
        }
        // whatever the test save holds: bedroom (3) and kitchen (4) at level 2 in the first two empty slots
        // (both build furniture; module 2 for example builds none)
        var _want = [3, 4];
        var _k = 0;
        for (var _i = 0; _i < array_length(global.sl_base_id) && _k < array_length(_want); _i++)
        {
            var _m = _want[_k];
            var _used = false;
            for (var _j = 0; _j < array_length(global.sl_base_id); _j++) if (global.sl_base_id[_j] == _m) _used = true;
            if (_used) { _k++; _i--; continue; }
            if (global.sl_base_id[_i] < 0)
            {
                global.sl_base_id[_i] = _m;
                global.sl_free[global.sl_id[_i]] = 2;
                global.base_lvl[_m] = 2;
                _k++;
            }
        }
        coop_base_rebuild();
        coop_log("lobby2: own modules raised");
    }
    if (_t == 200)
    {
        coop_visit_place_player();
    }
    if (_t == 230)
    {
        // the visit must show an EMPTY bunker whatever the test saves hold (both roots may be copies of one save):
        // the host's base is replaced in memory by the same layout without modules
        var _hb = coop_peer(0).base;
        for (var _i = 0; _i < array_length(_hb.sb); _i++) _hb.sb[_i] = -1;
        for (var _i = 0; _i < array_length(_hb.lvl); _i++) _hb.lvl[_i] = 0;
        _c.lobby2_own = coop_lobby_count_decor();
        coop_log("lobby2: own decor=", _c.lobby2_own, " host base ", json_stringify(_hb));
        screen_save("hub2_own_" + _c.tag + ".png");
        coop_visit_start(0);
    }
    if (_t == 300)
    {
        coop_log("lobby2: visiting decor=", coop_lobby_count_decor());
        screen_save("hub2_visit_" + _c.tag + ".png");
        coop_visit_end("panel");
    }
    if (_t == 370)
    {
        var _back = coop_lobby_count_decor();
        coop_log("lobby2: back decor=", _back, " own=", _c.lobby2_own, " matches=", _back == _c.lobby2_own && _back > 0);
        screen_save("hub2_back_" + _c.tag + ".png");
        coop_base_apply(_c.lobby_orig);
        coop_base_rebuild();
        coop_log("lobby2: done");
    }
}

// -coop_scenario ownerjoin (3 players): host and slot 1 raid (the handoff scenario: the host extracts),
// slot 2 stays in the hub and joins the raid slot 1 owns after the host left.
function coop_test_ownerjoin_step()
{
    var _c = coop();
    if (_c.scenario != "ownerjoin")
    {
        exit;
    }
    // the raid owner after the handoff (slot 1) pauses while slot 2 plays in its raid
    if (_c.slot == 1)
    {
        var _p2 = coop_peer(2);
        if (coop_shared_ready() && is_struct(_p2) && _p2.ready)
        {
            if (!variable_struct_exists(_c, "oj_pt")) _c.oj_pt = 0;
            _c.oj_pt++;
            if (_c.oj_pt == 240)
            {
                game_pause();
                coop_log("ownerjoin: owner paused, local_paused=", _c.local_paused);
            }
            if (_c.oj_pt == 480)
            {
                game_unpause();
                coop_log("ownerjoin: owner unpaused, owner=", coop_raid_owner(), " player=", instance_exists(obj_player));
            }
        }
        exit;
    }
    if (_c.slot != 2)
    {
        exit;
    }
    if (!variable_struct_exists(_c, "oj_t")) _c.oj_t = 0;
    _c.oj_t++;
    var _t = _c.oj_t;
    if (!variable_struct_exists(_c, "oj_asked"))
    {
        if (_t mod 120 == 0)
        {
            var _p0 = coop_peer(0);
            var _p1 = coop_peer(1);
            coop_log("ownerjoin: t=", _t, " target=", coop_join_target(), " host loc=", is_struct(_p0) ? _p0.loc : -1, " slot1 loc=", is_struct(_p1) ? _p1.loc : -1);
            // once the host is back in its hub (and not before it has been in the raid)
            if (is_struct(_p0) && _p0.loc == 2) _c.oj_host_raided = true;
            if (variable_struct_exists(_c, "oj_host_raided") && coop_join_target() == 1)
            {
                _c.oj_asked = true;
                coop_panel_click("join_raid");
            }
        }
        exit;
    }
    if (coop_shared_ready() && instance_exists(obj_player))
    {
        if (!variable_struct_exists(_c, "oj_in")) _c.oj_in = _t;
        if (_t - _c.oj_in == 600)
        {
            coop_log("ownerjoin: done owner=", coop_raid_owner(), " puppets=", array_length(coop_puppets()));
        }
    }
}

// -coop_scenario solo (one instance, no session): a plain raid with the mod installed - shoot at the nearest
// NPC, pause/unpause, open the inventory; the log must stay free of errors.
function coop_test_solo_step()
{
    var _c = coop();
    if (_c.scenario != "solo")
    {
        exit;
    }
    // solo pause deactivates the whole raid: count the paused frames here
    if (variable_struct_exists(_c, "so_pause") && _c.so_pause >= 0)
    {
        _c.so_pause++;
        if (_c.so_pause == 100)
        {
            _c.so_pause = -1;
            game_unpause();
            coop_log("solo: unpaused, player=", instance_exists(obj_player));
        }
        exit;
    }
    if (!coop_raid_ready() || !instance_exists(obj_player))
    {
        exit;
    }
    if (!variable_struct_exists(_c, "so_t")) { _c.so_t = 0; _c.so_hits = 0; _c.so_engaged = 0; _c.so_hp = obj_player.hp; }
    _c.so_t++;
    var _t = _c.so_t;
    // stay alive for the whole test, count the hits taken
    if (obj_player.hp < _c.so_hp - 0.5) _c.so_hits++;
    obj_player.hp = obj_player.hp_max;
    _c.so_hp = obj_player.hp;
    if (_t mod 10 == 0) _c.so_engaged = max(_c.so_engaged, coop_test_ai_targeting(obj_player.id));
    if (_t mod 120 == 0) { coop_log("solo t=", _t, " engaged=", _c.so_engaged, " hits=", _c.so_hits); coop_test_ai_dump(obj_player); }
    // 2 s in: stand at combat distance from an experienced bandit; 8 s of letting the AI engage, then fight back
    if (_t == 120)
    {
        _c.so_tg = coop_test_pick_enemy(obj_player.x, obj_player.y, false);
        if (instance_exists(_c.so_tg))
        {
            obj_player.x = _c.so_tg.x - 300;
            obj_player.y = _c.so_tg.y;
            coop_log("solo: next to ", object_get_name(_c.so_tg.object_index), " ", _c.so_tg.npc_id);
        }
    }
    if (_t == 160 && variable_struct_exists(_c, "so_tg") && instance_exists(_c.so_tg))
    {
        var _spot = coop_test_open_spot(_c.so_tg, 160);
        _c.so_x = _spot[0];
        _c.so_y = _spot[1];
    }
    if (_t > 160 && _t <= 900 && variable_struct_exists(_c, "so_x"))
    {
        var _a = _t * 3;
        obj_player.x = _c.so_x + lengthdir_x(20, _a);
        obj_player.y = _c.so_y + lengthdir_y(20, _a);
        if (_t > 600 && _t mod 20 == 0)
        {
            instance_activate_object(obj_npc_parent);
            var _tg = instance_nearest(obj_player.x, obj_player.y, obj_npc_human_parent);
            if (instance_exists(_tg) && point_distance(_tg.x, _tg.y, obj_player.x, obj_player.y) < 500)
            {
                with (obj_player)
                {
                    if (item_exists(arma_now) && item_get_category(arma_now) == "weapon")
                    {
                        scr_shoot(point_direction(x, y, _tg.x, _tg.y), 1, item_weapon_get_damage(arma_now), 0);
                    }
                }
            }
        }
    }
    if (_t == 1000)
    {
        _c.so_pause = 0;
        game_pause();
        coop_log("solo: paused");
    }
    if (_t == 1300)
    {
        var _n = 0;
        with (obj_npc_parent) _n++;
        coop_log("solo: done, npcs=", _n, " hp=", obj_player.hp, " fps=", fps, " kills=", coop_test_kills(), " hits taken=", _c.so_hits, " ai engaged=", _c.so_engaged);
    }
}

// Number of behaviour-tree NPCs whose current target is _who (1.4 AI: ai_execution.knowledge).
function coop_test_ai_targeting(_who)
{
    var _n = 0;
    with (obj_npc_parent)
    {
        if (hp > 0 && ai_human_migrated(id) && ai_execution.knowledge.valid && ai_execution.knowledge.target == _who)
        {
            _n++;
        }
    }
    return _n;
}

// Kills counted by the game's own statistics (whatever the save had before is subtracted by the caller).
function coop_test_kills()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "kills_seen")) _c.kills_seen = 0;
    return _c.kills_seen;
}

// -coop_scenario aiguest (host and guest): the 1.4 AI fighting a guest far away from the host.
// Guest: jumps next to enemies at least 700 px from every other player, walks in a small circle there (stays
// alive), counts the hits it takes and the callout bubbles it receives. Host (raid owner): logs how many of its
// NPCs target the guest's puppet and how many of the guest's footsteps its AI heard.
function coop_test_aiguest_step()
{
    var _c = coop();
    if (_c.scenario != "aiguest" || !coop_shared_ready() || !instance_exists(obj_player))
    {
        exit;
    }
    if (!variable_struct_exists(_c, "ag_t")) { _c.ag_t = 0; _c.ag_hits = 0; _c.ag_hp = obj_player.hp; _c.ag_best = 0; }
    _c.ag_t++;
    var _t = _c.ag_t;
    if (obj_player.hp < _c.ag_hp - 0.5) _c.ag_hits++;
    obj_player.hp = obj_player.hp_max; // both stay alive for the whole test
    _c.ag_hp = obj_player.hp;
    if (_c.role == "host")
    {
        if (_t mod 10 == 0)
        {
            var _n = 0;
            with (obj_player_puppet) _n += coop_test_ai_targeting(id);
            _c.ag_best = max(_c.ag_best, _n);
        }
        if (_t mod 120 == 0)
        {
            coop_log("aiguest owner: best=", _c.ag_best, " hearing emits=", variable_struct_exists(_c, "hearing_emits") ? _c.hearing_emits : 0);
            coop_test_ai_dump(obj_player_puppet);
        }
        if (_t == 3000) game_end();
        exit;
    }
    // a new experienced enemy every 10 s (the previous one may be dead or led away by a roaming squad)
    if (_t mod 600 == 150 && _t < 2400)
    {
        var _best = coop_test_pick_enemy(obj_player.x, obj_player.y, true);
        if (instance_exists(_best))
        {
            _c.ag_tg = _best;
            obj_player.x = _best.x - 300;
            obj_player.y = _best.y;
            coop_log("aiguest: jumped next to ", object_get_name(_best.object_index), " ", _best.npc_id, " (", npc_get_faction(_best.npc_id), ")");
        }
    }
    // the spot is picked again every 3 s: the enemy moves (takes cover, fights mutants) and a wall between us made the
    // test flaky (the AI was right not to see the guest)
    if (_t >= 190 && _t mod 180 == 10 && variable_struct_exists(_c, "ag_tg") && instance_exists(_c.ag_tg))
    {
        // trees and walls around the target are active now (culling re-activates the camera region every 20 ticks)
        var _spot = coop_test_open_spot(_c.ag_tg, 160);
        _c.ag_x = _spot[0];
        _c.ag_y = _spot[1];
    }
    if (_t > 190 && variable_struct_exists(_c, "ag_x") && _t < 2700)
    {
        // walk: the owner must hear the puppet's footsteps
        var _a = _t * 3;
        obj_player.x = _c.ag_x + lengthdir_x(20, _a);
        obj_player.y = _c.ag_y + lengthdir_y(20, _a);
    }
    if (_t mod 300 == 0)
    {
        coop_log("aiguest: hits=", _c.ag_hits, " barks=", variable_struct_exists(_c, "barks_in") ? _c.barks_in : 0);
    }
    if (_t == 2700)
    {
        coop_log("aiguest: done hits=", _c.ag_hits, " barks=", variable_struct_exists(_c, "barks_in") ? _c.barks_in : 0);
    }
}

// Debug: the AI state of the 3 NPCs closest to _who (test logs only).
function coop_test_ai_dump(_who)
{
    if (!instance_exists(_who)) exit;
    var _px = _who.x, _py = _who.y;
    var _l = ds_priority_create();
    with (obj_npc_parent) if (hp > 0) ds_priority_add(_l, id, point_distance(x, y, _px, _py));
    repeat (min(3, ds_priority_size(_l)))
    {
        var _n = ds_priority_delete_min(_l);
        var _s = object_get_name(_n.object_index) + " d=" + string(floor(point_distance(_n.x, _n.y, _px, _py))) + " state=" + string(_n.state) + " hs=" + string(_n.human_state_now) + " ai=" + string(_n.ai_status);
        if (ai_human_migrated(_n))
        {
            var _k = _n.ai_execution.knowledge;
            _s += " know=" + string(_k.valid) + " vis=" + string(_k.visible) + " tgt=" + (instance_exists(_k.target) ? object_get_name(_k.target.object_index) : string(_k.target));
            if (variable_struct_exists(_n.ai_execution, "withdrawal")) _s += " withdraw=" + string(_n.ai_execution.withdrawal.active);
            var _pn = player_nearest_instance(_n.x, _n.y);
            var _v = __ai_perception_view(_n);
            _s += " nearest=" + (instance_exists(_pn) ? object_get_name(_pn.object_index) : "none");
            if (instance_exists(_pn))
            {
                _s += " hostile=" + string(__ai_perception_hostile(_n, _pn)) + " inview=" + string(__ai_perception_in_view(_n.x, _n.y, _pn.x, _pn.y, _n.weapon_pointing_direction, _v))
                    + " wall=" + string(collision_line(_n.x, _n.y, _pn.x, _pn.y, obj_solid, true, false) != -4) + " vdist=" + string(floor(_v.distance)) + " ang=" + string(floor(_v.angle))
                    + " alert=" + string(_n.ai_execution.perception.alert) + "/" + string(_n.alert_player_max) + " atgt=" + (instance_exists(_n.ai_execution.perception.alert_target) ? object_get_name(_n.ai_execution.perception.alert_target.object_index) : "none");
            }
        }
        coop_log("  ai near: ", _s);
    }
    ds_priority_destroy(_l);
}

// Test helper: an enemy on the 1.4 behaviour-tree AI to fight. Bandits first (always hostile), never rookies or
// novices (the new AI withdraws when they are surprised at close range). _far_from_players: at least 700 px from
// every other player (the fight must happen away from the raid owner); otherwise the nearest to (_x, _y).
function coop_test_pick_enemy(_x, _y, _far_from_players)
{
    instance_activate_object(obj_npc_parent);
    var _best = noone, _bs = -1;
    with (obj_npc_human_parent)
    {
        if (hp <= 0 || !ai_human_supported(id) || !ai_human_rollout_enabled(npc_id)) continue;
        if (string_pos("rookie", npc_id) > 0 || string_pos("novice", npc_id) > 0) continue;
        if (variable_instance_exists(id, "coop_test_used")) continue; // tried already
        var _score;
        if (_far_from_players)
        {
            var _far = 1000000;
            with (obj_player_puppet) _far = min(_far, point_distance(x, y, other.x, other.y));
            if (_far < 700) continue;
            _score = _far;
        }
        else
        {
            _score = 1000000 - point_distance(x, y, _x, _y);
        }
        if (npc_get_faction(npc_id) == "Bandits") _score += 10000000;
        if (_score > _bs) { _bs = _score; _best = id; }
    }
    if (instance_exists(_best)) _best.coop_test_used = true;
    return _best;
}

// Test helper: a point _dist px from _npc with no wall in between (8 directions tried), inside its sight range.
function coop_test_open_spot(_npc, _dist)
{
    for (var _a = 180; _a < 540; _a += 45)
    {
        var _x = _npc.x + lengthdir_x(_dist, _a);
        var _y = _npc.y + lengthdir_y(_dist, _a);
        if (collision_line(_npc.x, _npc.y, _x, _y, obj_solid, true, false) == -4 && !collision_circle(_x, _y, 8, obj_solid, false, true))
        {
            return [_x, _y];
        }
    }
    return [_npc.x - _dist, _npc.y];
}

// -coop_scenario lang (one window, in the hub): every game language in turn through the game's own
// language_set_new_language; checks that every mod text comes from mod/lang/strings.tsv for it and saves a
// screenshot of the co-op panel (fonts: Polish letters, kana/kanji, hangul, hanzi). Ends back in English.
function coop_test_lang_step()
{
    var _c = coop();
    if (_c.scenario != "lang" || !is_in_hub() || !instance_exists(obj_player))
    {
        exit;
    }
    if (!variable_struct_exists(_c, "lg_t")) { _c.lg_t = 0; _c.lg_ok = 0; }
    _c.lg_t++;
    var _t = _c.lg_t;
    if (!variable_struct_exists(_c, "lg_langs"))
    {
        // only the languages the game offers (gamedata/languages.json); the table may have more
        var _game = variable_struct_get(global.language_data, "languages");
        _c.lg_langs = [];
        var _all = coop_lang_list();
        for (var _q = 0; _q < array_length(_all); _q++) if (variable_struct_exists(_game, _all[_q])) array_push(_c.lg_langs, _all[_q]);
        coop_log("lang: game languages ", array_length(_c.lg_langs), " of ", array_length(_all), " in the table");
    }
    var _langs = _c.lg_langs;
    var _n = array_length(_langs);
    if (_t == 60) _c.panel = true;
    var _i = (_t - 90) div 45;
    var _k = (_t - 90) mod 45;
    if (_t >= 90 && _i < _n)
    {
        var _l = _langs[_i];
        if (_k == 0)
        {
            language_set_new_language(_l);
        }
        if (_k == 30)
        {
            var _d = coop_lang_data();
            var _keys = variable_struct_get_names(_d.index);
            var _bad = 0;
            for (var _j = 0; _j < array_length(_keys); _j++)
            {
                var _want = _keys[_j];
                if (_l != "english")
                {
                    var _a = variable_struct_get(_d.langs, _l);
                    _want = _a[variable_struct_get(_d.index, _keys[_j])];
                }
                if (coop_t(_keys[_j], "") != _want) _bad++;
            }
            if (_bad == 0) _c.lg_ok++;
            coop_log("lang: ", _l, " current=", global.language_current, " texts=", array_length(_keys), " wrong=", _bad, " sample=", coop_tf("{0} joined", "", "Ondrey"));
            screen_save("lang_" + _l + ".png");
        }
    }
    if (_t == 90 + _n * 45)
    {
        language_set_new_language("english");
        _c.panel = false;
        coop_log("lang: done ok=", _c.lg_ok, "/", _n);
    }
}

// -coop_scenario hostjoin (2 players): the guest takes the train alone while the host stays in the bunker; later the
// host takes the train to ANOTHER map and must land in the guest's raid (same map + seed), which the guest keeps
// owning (it started the raid, the host joined it late). Live bug 2026-11-06: the two ended up in separate raids.
function coop_test_hostjoin_step()
{
    var _c = coop();
    if (_c.scenario != "hostjoin" || !_c.connected)
    {
        exit;
    }
    if (!variable_struct_exists(_c, "hj_t")) _c.hj_t = 0;
    _c.hj_t++;
    var _t = _c.hj_t;
    if (_c.role == "guest" && !variable_struct_exists(_c, "hj_go") && is_in_hub() && instance_exists(obj_player) && _t > 240)
    {
        _c.hj_go = true;
        coop_log("hostjoin: guest starts its own raid");
        go_to_map(1);
    }
    if (_c.role == "host" && !variable_struct_exists(_c, "hj_go") && is_in_hub() && instance_exists(obj_player))
    {
        var _p = coop_peer(1);
        if (is_struct(_p) && _p.loc == 2 && _p.raid_seed >= 0)
        {
            if (!variable_struct_exists(_c, "hj_seen")) _c.hj_seen = _t;
            if (_t - _c.hj_seen == 600)
            {
                _c.hj_go = true;
                coop_log("hostjoin: host takes the train to map 3");
                go_to_map(3);
            }
        }
    }
    if (variable_struct_exists(_c, "hj_go") && coop_shared_ready() && instance_exists(obj_player) && instance_exists(obj_map_generator))
    {
        if (!variable_struct_exists(_c, "hj_in")) _c.hj_in = _t;
        if (_t - _c.hj_in == 900)
        {
            var _rep = 0;
            instance_activate_object(obj_npc_parent);
            with (obj_npc_parent)
            {
                if (coop_npc_is_replica()) _rep++;
            }
            coop_log("hostjoin: done owner=", coop_raid_owner(), " late=", _c.raid_late, " map=", obj_map_generator.area, " replicas=", _rep > 0);
        }
    }
}

// -coop_scenario gather (3 players, host autoraid): the host's train ride opens the zone at the train; slot 2 walks
// out of it and must stay in the bunker, slot 1 steps into it and goes along.
function coop_test_gather_step()
{
    var _c = coop();
    if (_c.role != "guest")
    {
        exit;
    }
    if (_c.scenario != "gather")
    {
        // every other scenario: guests answer the host's train zone like a player would, by walking into it
        if (variable_struct_exists(_c, "gather") && _c.gather != undefined && instance_exists(obj_player) && is_in_hub())
        {
            var _z = _c.gather;
            if (!coop_gather_in(_z, obj_player.x, obj_player.y))
            {
                obj_player.x = (_z.x1 + _z.x2) / 2 + max(0, _c.slot) * 12;
                obj_player.y = (_z.y1 + _z.y2) / 2;
            }
        }
        exit;
    }
    if (variable_struct_exists(_c, "gather") && _c.gather != undefined && !variable_struct_exists(_c, "gt_moved") && instance_exists(obj_player))
    {
        _c.gt_moved = true;
        var _g = _c.gather;
        if (_c.slot == 2)
        {
            obj_player.x = _g.x2 + 200; // out of the zone
            obj_player.y = (_g.y1 + _g.y2) / 2;
            coop_log("gather test: slot 2 walks away from the train");
        }
        else
        {
            obj_player.x = (_g.x1 + _g.x2) / 2; // into the zone
            obj_player.y = (_g.y1 + _g.y2) / 2;
            coop_log("gather test: slot ", _c.slot, " steps into the zone ", floor(_g.x1), ",", floor(_g.y1), " - ", floor(_g.x2), ",", floor(_g.y2));
        }
    }
    if (_c.slot == 1 && variable_struct_exists(_c, "gt_moved") && !variable_struct_exists(_c, "gt_shot") && is_in_hub())
    {
        if (!variable_struct_exists(_c, "gt_shot_t")) _c.gt_shot_t = 0;
        _c.gt_shot_t++;
        if (_c.gt_shot_t == 60)
        {
            _c.gt_shot = true;
            screen_save("gather_zone_" + _c.tag + ".png"); // what the zone looks like at the train
        }
    }
    if (!variable_struct_exists(_c, "gt_t")) _c.gt_t = 0;
    _c.gt_t++;
    if (variable_struct_exists(_c, "gt_moved") && _c.gt_t mod 60 == 0 && !variable_struct_exists(_c, "gt_done"))
    {
        if (!variable_struct_exists(_c, "gt_from")) _c.gt_from = _c.gt_t;
        if (_c.gt_t - _c.gt_from >= 900)
        {
            _c.gt_done = true;
            coop_log("gather test: done hub=", is_in_hub(), " raid=", coop_in_raid());
        }
    }
    if (_c.slot == 1 && coop_shared_ready() && !variable_struct_exists(_c, "gt_done") && instance_exists(obj_player))
    {
        _c.gt_done = true;
        coop_log("gather test: done hub=", is_in_hub(), " raid=", coop_in_raid());
    }
}

// -coop_scenario backup (1 window): back up slot 1, damage the slot file, restore it from the co-op panel's
// backup page, compare the file, then load the slot and reach the bunker.
function coop_test_backup_step()
{
    var _c = coop();
    if (!_c.test_mode || _c.scenario != "backup")
    {
        exit;
    }
    if (!variable_struct_exists(_c, "bt")) { _c.bt = 0; _c.bh = 0; }
    var _root = coop_backup_root();
    var _live = _root + coop_backup_slot_file(1);
    if (room == r_menu)
    {
        _c.bt++;
        if (_c.bt == 120)
        {
            _c.b_md5 = md5_file(_live);
            var _ok = coop_backup_make(1, "coop");
            coop_log("backup: made=", _ok, " count=", array_length(coop_backup_list(1)));
            // damage the live file
            var _f = file_text_open_write(_live);
            file_text_write_string(_f, "broken");
            file_text_close(_f);
            coop_log("backup: damaged, md5 now ", md5_file(_live) != _c.b_md5);
            _c.panel = true;
            coop_panel_click("backups");
        }
        if (_c.bt == 180)
        {
            screen_save("backup_page.png");
            var _btns = coop_panel_buttons();
            // the newest backup is the second button; click it twice (confirm)
            coop_panel_click(_btns[1].id);
            var _b2 = coop_panel_buttons();
            coop_log("backup: confirm label ", _btns[1].label, " -> ", _b2[1].label);
            coop_panel_click(_btns[1].id);
            coop_log("backup: restore ok=", md5_file(_live) == _c.b_md5);
            _c.panel = false;
        }
        if (_c.bt == 240)
        {
            saveslot_load(1);
        }
    }
    if (is_in_hub() && instance_exists(obj_player) && _c.bt >= 240)
    {
        _c.bh++;
        if (_c.bh == 120)
        {
            coop_log("backup: hub after restore, player=", instance_exists(obj_player));
            coop_log("backup: done");
        }
    }
}

// -coop_scenario report (1 window, main menu): "Collect logs" from the panel, a simulated crash report, pruning.
function coop_test_report_step()
{
    var _c = coop();
    if (!_c.test_mode || _c.scenario != "report" || room != r_menu)
    {
        exit;
    }
    if (!variable_struct_exists(_c, "rt")) _c.rt = 0;
    _c.rt++;
    if (_c.rt == 120)
    {
        _c.panel = true;
        coop_panel_click("report");
        var _dir = string_replace(clipboard_get_text(), string_replace_all(game_save_id, "/", "\\"), "");
        _dir = string_replace_all(_dir, "\\", "/");
        coop_log("report: manual dir=", _dir, " log=", file_exists(_dir + "coop_" + _c.tag + ".log"), " info=", file_exists(_dir + "info.txt"),
            " panel closed=", !_c.panel);
    }
    if (_c.rt == 150)
    {
        var _full = coop_report_on_crash({ longMessage: "test crash", stacktrace: ["coop_test_report_step"] });
        var _dir = string_replace_all(string_replace(_full, string_replace_all(game_save_id, "/", "\\"), ""), "\\", "/");
        var _t = file_text_open_read(_dir + "info.txt");
        var _txt = "";
        while (!file_text_eof(_t)) { _txt += file_text_readln(_t); }
        file_text_close(_t);
        coop_log("report: crash info has message=", string_pos("test crash", _txt) > 0);
    }
    if (_c.rt >= 160 && _c.rt < 166)
    {
        coop_report_make("prune", "");
    }
    if (_c.rt == 140)
    {
        // separate co-op character: on at once, off only after a restart (the shared test ini is put back)
        var _before = global.database_savedata_root;
        coop_panel_click("profile");
        var _on = global.database_savedata_root;
        coop_log("report: profile on root changed=", _on != _before, " dir=", directory_exists(_on), " settings copied=", file_exists(_on + "settings_shared.json") || !file_exists(_before + "settings_shared.json"), " cloud=", db_cloud_enabled());
        coop_panel_click("profile");
        var _b3 = coop_panel_buttons();
        var _lab = "";
        for (var _i = 0; _i < array_length(_b3); _i++) if (_b3[_i].id == "profile") _lab = _b3[_i].label;
        coop_log("report: profile off pending, root same=", global.database_savedata_root == _on, " label ", _lab);
        ini_open("coop_local.ini"); ini_write_real("coop", "coop_profile", 0); ini_close();
    }
    if (_c.rt == 170)
    {
        _c.panel = true;
        coop_panel_click("browser");
        // one-click update with the published 1.2.0 zip as "v9.9.9"
        _c.upd_latest = "9.9.9";
        _c.upd_zip_url = "https://github.com/ImmortalSouull/zerosievert-coop/releases/download/v1.2.0/ZS-Coop-v1.2.0.zip";
        coop_panel_click("update");
    }
    if (_c.rt == 900) coop_log("report: done"); // after the update download
    if (_c.rt > 200 && coop_update_state() == "ready" && !variable_struct_exists(_c, "upd_logged"))
    {
        _c.upd_logged = true;
        coop_log("report: update cmd=", file_exists("coop_update/update.cmd"));
    }
    if (_c.rt == 200)
    {
        var _bb = coop_panel_buttons();
        coop_log("report: browser first button ", _bb[0].label, " loading=", _c.browser.loading);
        _c.panel = false;
        var _n = 0;
        var _f = file_find_first(COOP_REPORT_DIR + "report_*", 16);
        while (_f != "") { _n++; _f = file_find_next(); }
        file_find_close();
        coop_log("report: kept=", _n);
        // hooks [136]/[137]: an empty and a cut mods file read as {} (a test file, not the real one)
        var _tf = file_text_open_write("coop_test_mods.json");
        file_text_close(_tf);
        var _bb = coop_mods_json_load("coop_test_mods.json");
        var _e1 = buffer_read(_bb, buffer_text);
        buffer_delete(_bb);
        _tf = file_text_open_write("coop_test_mods.json");
        file_text_write_string(_tf, "{" + chr(34) + "a");
        file_text_close(_tf);
        _bb = coop_mods_json_load("coop_test_mods.json");
        var _e2 = buffer_read(_bb, buffer_text);
        buffer_delete(_bb);
        file_delete("coop_test_mods.json");
        coop_log("report: mods json safe=", _e1 == "{}" && _e2 == "{}");

    }
}

// -coop_scenario panelraid (1 window): the co-op panel opened in a raid (see-through background), screenshot.
function coop_test_panelraid_step()
{
    var _c = coop();
    if (!_c.test_mode || _c.scenario != "panelraid" || !coop_raid_ready() || !instance_exists(obj_player))
    {
        exit;
    }
    if (!variable_struct_exists(_c, "prt")) _c.prt = 0;
    _c.prt++;
    if (_c.prt == 200) _c.panel = true;
    if (_c.prt == 240)
    {
        screen_save("panel_raid.png");
        coop_log("panelraid: shot, panel=", _c.panel);
    }
    if (_c.prt == 260)
    {
        _c.panel = false;
        coop_log("panelraid: done");
    }
}

// -coop_scenario group: the guest bandages next to the host (group panel: action icon), opens the co-op panel
// (status "in a menu"), then idles (status "away"); the host logs what it sees and takes screenshots.
function coop_test_group_step()
{
    var _c = coop();
    if (!_c.test_mode || _c.scenario != "group" || !coop_shared_ready() || !instance_exists(obj_player) || !_c.peer_in_raid)
    {
        exit;
    }
    if (!variable_struct_exists(_c, "gt")) _c.gt = 0;
    _c.gt++;
    var _t = _c.gt;
    if (_c.role == "guest")
    {
        var _host = coop_test_partner();
        with (obj_player)
        {
            if (_t == 150 && instance_exists(_host))
            {
                x = _host.x + 40;
                y = _host.y;
            }
            if (_t == 200 && arms_holder == undefined)
            {
                arms_holder = new class_player_arms(id, "bandage", item_med_get_animation("bandage"));
                coop_log("group: guest uses bandage");
            }
        }
        if (_t == 300) coop_chat_send("Привет, it's the guest: " + chr(1046) + "!");
        // appearance: scientist body (shows without armor) and the navy tint; put back at the end (shared test ini)
        if (_t == 160) { coop_look().body = 3; coop_look().tint = 2; coop_look_save(); }
        if (_t == 880) { coop_look().body = 0; coop_look().tint = 0; coop_look_save(); }
        // quick-command wheel: open, point down-right (sector 3), release; then the icon page, sector 1
        if (_t == 320) { _c.sim_wheel = true; _c.sim_wheel_dir = -45; }
        if (_t == 340) _c.sim_wheel = false;
        if (_t == 350) { _c.sim_wheel = true; _c.sim_wheel_dir = 45; }
        if (_t == 360) coop_wheel().page = 1;
        if (_t == 362) screen_save("wheel_" + _c.tag + ".png");
        if (_t == 370) _c.sim_wheel = false;
        if (_t == 390) _c.sim_need = "medikit_1"; // "I need this" on a hovered medkit
        if (_t == 400) _c.panel = true;
        if (_t == 520) _c.panel = false;
        if (_t == 530) _c.afk_test_ms = 2000;
        if (_t == 900) coop_log("group: done");
    }
    else
    {
        var _pup = coop_puppet_of(1);
        if (_t == 240 || _t == 250 || _t == 260)
        {
            if (instance_exists(_pup) && variable_instance_exists(_pup, "coop_arms_item") && _pup.coop_arms_item != "" && !variable_struct_exists(_c, "g_arms"))
            {
                _c.g_arms = true;
                coop_log("group: partner uses ", _pup.coop_arms_item, " weapon ", _pup.arma_now);
                screen_save("group_panel_" + _c.tag + ".png");
            }
        }
        if (_t == 420) screen_save("wheel_seen_" + _c.tag + ".png");
        if (_t == 680) coop_gear_request(1);
        if (_t == 690)
        {
            var _gp = coop_puppet_of(1);
            coop_log("group: partner tint=", instance_exists(_gp) && variable_instance_exists(_gp, "coop_tint") ? _gp.coop_tint : -1,
                " blend tinted=", instance_exists(_gp) && _gp.image_blend != c_white, " sprite ", instance_exists(_gp) ? sprite_get_name(_gp.sprite_index) : "?");
        }
        // aiming hides the co-op HUD; a hit while aiming shows the health bar
        if (_t >= 760 && _t <= 860) with (obj_player) aiming = true;
        if (_t == 780) { coop_log("group: aiming hud hidden=", coop_hud_hidden()); screen_save("aim_" + _c.tag + ".png"); }
        if (_t == 800) with (obj_player) hp -= 5;
        if (_t == 810) { coop_log("group: hit while aiming, hp shown=", current_time - _c.hud_hit_t < 3000); screen_save("aim_hit_" + _c.tag + ".png"); }
        if (_t == 740) { screen_save("gear_" + _c.tag + ".png"); coop_gear().open = false; }
        // streamer mode: names hidden everywhere on screen (the setting is shared by the test windows: switch it back)
        if (_t == 600) { coop_streamer_toggle(); _c.panel = true; coop_log("group: streamer name ", coop_peer_name(1), " me ", coop_my_shown_name()); }
        if (_t == 620) screen_save("streamer_" + _c.tag + ".png");
        if (_t == 630) { coop_streamer_toggle(); _c.panel = false; coop_log("group: streamer off name ", coop_peer_name(1)); }
        if (_t == 470) coop_log("group: partner status ", coop_status_of(1));
        if (_t == 330)
        {
            var _ch = coop_chat();
            _ch.open = true; // as if Enter was pressed: the game's input is muted
            coop_log("group: chat open, game blocked=", coop_panel_blocks_game());
            screen_save("chat_" + _c.tag + ".png");
            _ch.open = false;
            coop_chat_send("host answers");
        }
        if (_t == 800)
        {
            coop_log("group: partner status ", coop_status_of(1), " weapon ", instance_exists(_pup) ? _pup.arma_now : "?");
            screen_save("group_away_" + _c.tag + ".png");
            coop_log("group: done");
        }
    }
}

// -coop_scenario ff (host: -coop_diff coop_friendly_fire=1,coop_friendly_fire_damage=0.5): the guest shoots the
// host once from close by; the host logs how much health it lost (half of the bullet's damage at most).
function coop_test_ff_step()
{
    var _c = coop();
    if (!_c.test_mode || _c.scenario != "ff" || !coop_shared_ready() || !instance_exists(obj_player) || !_c.peer_in_raid)
    {
        exit;
    }
    if (!variable_struct_exists(_c, "fft")) _c.fft = 0;
    _c.fft++;
    var _t = _c.fft;
    if (_c.role == "guest")
    {
        var _host = coop_test_partner();
        with (obj_player)
        {
            // (again right before the shot: the host's spawn may move once its map is in)
            if ((_t == 150 || _t == 235) && instance_exists(_host)) { x = _host.x + 40; y = _host.y; }
            if (_t == 240 && instance_exists(_host))
            {
                scr_shoot(point_direction(x, y, _host.x, _host.y - 6), 1, 40, 0);
                coop_log("ff: guest shot the host, damage 40");
            }
        }
        if (_t == 420) coop_log("ff: done");
    }
    else
    {
        with (obj_player)
        {
            if (_t == 100) { hp = hp_max; _c.ff_hp = hp; coop_log("ff: host hp ", hp, " setting ", coop_setting("friendly_fire_damage")); }
            if (_t == 400) { coop_log("ff: host lost ", _c.ff_hp - hp); coop_log("ff: done"); }
        }
    }
}

// -coop_scenario kick (hub): the host removes the guest from the "Players and lobby" page (two clicks); the guest
// tries to connect again and is refused.
function coop_test_kick_step()
{
    var _c = coop();
    if (!_c.test_mode || _c.scenario != "kick")
    {
        exit;
    }
    if (!variable_struct_exists(_c, "kt")) { _c.kt = 0; _c.kicks = 0; }
    if (_c.role == "host" && _c.connected && is_in_hub())
    {
        _c.kt++;
        if (_c.kt == 300)
        {
            _c.panel = true;
            coop_panel_click("lobby");
        }
        if (_c.kt == 330)
        {
            var _b = coop_panel_buttons();
            coop_log("kick: page buttons ", array_length(_b), " first ", _b[0].id);
            screen_save("kick_page_" + _c.tag + ".png");
            coop_panel_click("kick_1");
            var _b2 = coop_panel_buttons();
            coop_log("kick: confirm label ", _b2[0].label);
            coop_panel_click("kick_1");
            _c.panel = false;
        }
    }
    if (_c.role == "host" && _c.kt >= 330)
    {
        _c.kt++;
        if (_c.kt >= 1000 && !variable_struct_exists(_c, "k_done")) // (kt also counts in the block above while others stay)
        {
            _c.k_done = true;
            coop_log("kick: host players now ", coop_player_count());
            coop_log("kick: done");
        }
    }
    if (_c.role == "none" && variable_struct_exists(_c, "was_guest"))
    {
        _c.kt++;
        if (_c.kt == 120 && _c.kicks == 1)
        {
            coop_log("kick: guest tries again");
            _c.role = "guest";
            _c.transport = "udp";
            _c.peer_ip = "127.0.0.1";
            _c.peer_port = COOP_PORT;
            coop_net_start();
        }
        if (_c.kt == 400) coop_log("kick: done");
    }
    if (_c.role == "guest")
    {
        _c.was_guest = true;
        _c.kt = 0;
    }
}

// -coop_scenario extract: the guest shoots NPCs (kills for the summary), the host stands on an extraction point and
// waits for the guest (10 s timer); the guest arrives, both leave together; the exit screen shows the summary.
function coop_test_extract_step()
{
    var _c = coop();
    if (!_c.test_mode || _c.scenario != "extract")
    {
        exit;
    }
    if (!variable_struct_exists(_c, "xt")) { _c.xt = 0; }
    if (instance_exists(obj_exit_screen))
    {
        _c.xt_exit = (variable_struct_exists(_c, "xt_exit") ? _c.xt_exit : 0) + 1;
        if (_c.xt_exit == 1) coop_log("extract: exit screen, my t=", _c.xt, " survived=", obj_exit_screen.survived);
        var _n = 0;
        for (var _k = 0; _k < COOP_MAX_PLAYERS; _k++) if (is_struct(_c.summary[_k])) _n++;
        // after 4 s, as soon as every player's summary is in (a teammate may reach its exit screen seconds later)
        if (_c.xt_exit >= 240 && !variable_struct_exists(_c, "xt_done") && (_n >= coop_player_count() || _c.xt_exit >= 900))
        {
            _c.xt_done = true;
            screen_save("summary_" + _c.tag + ".png");
            coop_log("extract: done, summaries=", _n, " kills=", _c.my_stats.kills);
            var _pb = coop_panel_partner_buttons();
            coop_log("extract: partners page ", _pb[0].label);
        }
        exit;
    }
    if (!coop_shared_ready() || !instance_exists(obj_player))
    {
        exit;
    }
    _c.xt++;
    var _t = _c.xt;
    instance_activate_object(obj_extraction_point);
    var _ex = undefined;
    var _ey = undefined;
    with (obj_extraction_point) { if (_ex == undefined) { _ex = x; _ey = y; } }
    if (_c.role == "guest" && _t >= 150 && _t <= 500 && _t mod 12 == 0)
    {
        if (!variable_struct_exists(_c, "x_tg") || !instance_exists(_c.x_tg) || _c.x_tg.hp <= 1)
        {
            instance_activate_object(obj_npc_parent);
            var _best = -4;
            var _bd = infinity;
            with (obj_npc_parent)
            {
                if (coop_npc_is_replica() && hp > 1 && object_is_ancestor(object_index, obj_npc_human_parent))
                {
                    var _d = point_distance(x, y, obj_player.x, obj_player.y);
                    if (_d < _bd) { _bd = _d; _best = id; }
                }
            }
            _c.x_tg = _best;
        }
        var _tg = _c.x_tg;
        if (instance_exists(_tg))
        {
            obj_player.x = _tg.x - 50;
            obj_player.y = _tg.y;
            with (obj_player)
            {
                hp = hp_max;
                if (item_exists(arma_now) && item_get_category(arma_now) == "weapon")
                {
                    scr_shoot(point_direction(x, y, _tg.x, _tg.y), 1, item_weapon_get_damage(arma_now) * 4, 0);
                }
            }
        }
    }
    with (obj_player) hp = hp_max; // the 1.4 AI must not end this test early
    if (_ex == undefined) exit;
    if (_c.role == "host" && _t >= 300)
    {
        obj_player.x = _ex + 8;
        obj_player.y = _ey + 8;
        var _x = coop_extract();
        // past the solo 5 s and still here: the group timer waits for the guest
        if (_x.mine.timer > 320 && !variable_struct_exists(_c, "xt_logged"))
        {
            _c.xt_logged = true;
            coop_log("extract: host waiting=", array_length(_x.waiting), " max=", _x.group_max, " timer=", _x.mine.timer);
        }
    }
    // the guest comes once the host has waited 6 s on the point
    var _ho = coop_extract().others[0];
    if (_c.role == "guest" && is_struct(_ho) && _ho.in_zone && !variable_struct_exists(_c, "xt_seen")) _c.xt_seen = _t;
    if (_c.role == "guest" && variable_struct_exists(_c, "xt_seen") && _t >= _c.xt_seen + 360)
    {
        obj_player.x = _ex + 4;
        obj_player.y = _ey + 10;
    }
}

// -coop_scenario tutorial (1 window, main menu): the tutorial opens by itself; both pages are shot.
function coop_test_tutorial_step()
{
    var _c = coop();
    if (!_c.test_mode || _c.scenario != "tutorial" || room != r_menu) exit;
    if (!variable_struct_exists(_c, "tt")) _c.tt = 0;
    _c.tt++;
    if (_c.tt == 100) { coop_log("tutorial: panel=", _c.panel, " page=", _c.panel_page); screen_save("tutorial_0.png"); coop_panel_click("help"); }
    if (_c.tt == 110) { screen_save("tutorial_1.png"); coop_panel_click("help2"); }
    if (_c.tt == 140) { screen_save("tutorial_2.png"); coop_panel_click("page_main"); }
    if (_c.tt == 150) { coop_log("tutorial: closed page=", _c.panel_page); _c.panel = true; _c.panel_page = "welcome"; coop_panel_click("welcome_never"); }
    if (_c.tt == 160) { coop_log("tutorial: after never panel=", _c.panel); coop_log("tutorial: done"); }
}

// -coop_scenario spectate (host: revive off): the guest dies for real, watches the host from the death screen,
// then goes back to it.
function coop_test_spectate_step()
{
    var _c = coop();
    if (!_c.test_mode || _c.scenario != "spectate") exit;
    if (!variable_struct_exists(_c, "st")) _c.st = 0;
    if (_c.role == "host")
    {
        if (coop_shared_ready() && instance_exists(obj_player))
        {
            _c.st++;
            with (obj_player) hp = hp_max;
            if (_c.st == 1500) coop_log("spectate: done");
        }
        exit;
    }
    if (instance_exists(obj_exit_screen))
    {
        _c.st_d = (variable_struct_exists(_c, "st_d") ? _c.st_d : 0) + 1;
        var _d = _c.st_d;
        if (_d == 120) _c.sim_spec = true;
        if (_d == 200)
        {
            var _h = coop_puppet_of(0);
            var _cx = camera_get_view_x(view_camera[0]) + 240;
            var _cy = camera_get_view_y(view_camera[0]) + 135;
            coop_log("spectate: on=", coop_spectating(), " camera on host=", instance_exists(_h) && point_distance(_cx, _cy, _h.x, _h.y) < 40);
            screen_save("spectate_" + _c.tag + ".png");
        }
        if (_d == 260) _c.sim_spec_next = true;
        if (_d == 300) _c.sim_spec = true;
        if (_d == 340) { coop_log("spectate: back, on=", coop_spectating()); coop_log("spectate: done"); }
        exit;
    }
    if (coop_shared_ready() && instance_exists(obj_player))
    {
        _c.st++;
        if (_c.st == 300)
        {
            coop_log("spectate: guest dies");
            obj_player.hp = 0;
        }
    }
}

// -coop_scenario drag (item 30): down #1 - the host drags and revives the guest while walking; down #2 - the host
// drags only (the guest bleeds 3x slower), lets go, starts a revive on the spot, the guest crawls (cancels it, the
// bleed-out timer keeps running from where it was), the host revives again.
function coop_test_drag_step()
{
    var _c = coop();
    if (!_c.test_mode || _c.scenario != "drag" || !coop_shared_ready() || !instance_exists(obj_player)) exit;
    if (!variable_struct_exists(_c, "dg")) { _c.dg = 0; _c.dhs = 0; _c.dk = 0; }
    _c.dg++;
    var _t = _c.dg;
    var _d = coop_down();
    if (_c.role == "guest")
    {
        if (_t == 240) { coop_log("drag: guest down #1"); _c.dg_x = obj_player.x; _c.dg_y = obj_player.y; obj_player.hp = 0; }
        if (_d.count == 1 && !_d.active && !variable_struct_exists(_c, "dg_rev1"))
        {
            _c.dg_rev1 = _t;
            coop_log("drag: first revive moved ", floor(point_distance(_c.dg_x, _c.dg_y, obj_player.x, obj_player.y)), " px");
        }
        if (variable_struct_exists(_c, "dg_rev1") && _t == _c.dg_rev1 + 200) { coop_log("drag: guest down #2"); obj_player.hp = 0; }
        if (_d.active && _d.count == 2)
        {
            var _dragged = current_time - _d.drag_time < 400 && _d.drag_mode == COOP_REVIVE_MODE_DRAGONLY;
            if (_dragged)
            {
                if (!variable_struct_exists(_c, "dg_d0")) { _c.dg_d0 = _d.timer; _c.dg_dt = _t; }
                if (_t == _c.dg_dt + 120) coop_log("drag: dragged-only bleed per 60 ticks = ", (_c.dg_d0 - _d.timer) / 2);
            }
            var _still = current_time - _d.ping_time < 400 && current_time - _d.drag_time > 400;
            if (_still && !variable_struct_exists(_c, "dg_moved") && variable_struct_exists(_c, "dg_d0"))
            {
                if (!variable_struct_exists(_c, "dg_still")) _c.dg_still = _t;
                if (_t == _c.dg_still + 40)
                {
                    _c.dg_moved = _t;
                    _c.dg_tb = _d.timer;
                    obj_player.x += 4; // tries to crawl away
                    coop_log("drag: guest crawls while revived, timer ", _d.timer);
                }
            }
            if (variable_struct_exists(_c, "dg_moved") && _t == _c.dg_moved + 60)
            {
                coop_log("drag: timer after cancel kept=", _d.timer < _c.dg_tb && _d.timer > _c.dg_tb - 90, " (", _c.dg_tb, " -> ", _d.timer, ")");
            }
        }
        if (_d.count == 2 && !_d.active && !variable_struct_exists(_c, "dg_done")) { _c.dg_done = true; coop_log("drag: guest revived twice"); coop_log("drag: done"); }
        exit;
    }
    // host
    var _p = coop_test_partner();
    var _r = coop_revive();
    _c.dk++;
    var _k = _c.dk;
    switch (_c.dhs)
    {
        case 0:
            if (coop_partner_is_down() && instance_exists(_p)) { obj_player.x = _p.x + 12; obj_player.y = _p.y; _c.dhs = 1; _c.dk = 0; }
            break;
        case 1: // drag and revive, walking right
            if (_k == 30) _c.sim_revive_mode = COOP_REVIVE_MODE_DRAG;
            if (_k == 60 || _k == 90) _c.sim_e = true;
            if (_k > 100 && _r.active) obj_player.x += 1.5;
            if (_k > 100 && !coop_partner_is_down()) { coop_log("drag: host revived while dragging"); _c.dhs = 2; _c.dk = 0; }
            break;
        case 2:
            if (_k > 60 && coop_partner_is_down() && instance_exists(_p)) { obj_player.x = _p.x + 12; obj_player.y = _p.y; _c.dhs = 3; _c.dk = 0; }
            break;
        case 3: // drag only, let go, then revive on the spot
            if (_k == 30) _c.sim_revive_mode = COOP_REVIVE_MODE_DRAGONLY;
            if (_k == 60 || _k == 90) _c.sim_e = true;
            if (_k == 90 + 300) _c.sim_e = true; // let go
            if (_k == 420) _c.sim_revive_mode = COOP_REVIVE_MODE_STILL;
            if (_k == 450 || _k == 480) { if (instance_exists(_p)) { obj_player.x = _p.x + 12; obj_player.y = _p.y; } _c.sim_e = true; }
            if (_k > 500 && !_r.active && !_r.menu) { coop_log("drag: host sees the revive stopped"); _c.dhs = 4; _c.dk = 0; }
            break;
        case 4: // again, the guest keeps still now
            if (_k == 60 || _k == 90) { if (instance_exists(_p)) { obj_player.x = _p.x + 12; obj_player.y = _p.y; } _c.sim_e = true; }
            if (_k > 100 && !coop_partner_is_down()) { coop_log("drag: done"); _c.dhs = 5; }
            break;
    }
}

// -coop_scenario rejoin (hub): the guest's session drops like after a crash (the rejoin note stays), the co-op panel
// offers "Rejoin {host}", the guest clicks it and is back; at the end the note is cleaned up.
function coop_test_rejoin_step()
{
    var _c = coop();
    if (!_c.test_mode || _c.scenario != "rejoin") exit;
    if (!variable_struct_exists(_c, "rj")) { _c.rj = 0; _c.rj_n = 0; }
    _c.rj++;
    if (_c.role == "guest" && _c.connected && is_in_hub() && _c.rj_n == 0 && _c.rj > 300)
    {
        _c.rj_n = 1;
        ini_open("coop_local.ini");
        coop_log("rejoin: note written=", ini_read_real("rejoin", "active", 0), " host=", ini_read_string("rejoin", "host", ""));
        ini_close();
        // a crash: no BYE, no clean leave - just gone
        coop_on_disconnected();
        if (_c.sock >= 0) { network_destroy(_c.sock); _c.sock = -1; }
        _c.role = "none";
        _c.connected = false;
        _c.rj_t = _c.rj;
    }
    if (_c.role == "none" && _c.rj_n == 1 && _c.rj == _c.rj_t + 120)
    {
        variable_struct_remove(_c, "rejoin_offer"); // as on the next start
        var _b = coop_panel_buttons();
        coop_log("rejoin: first button ", _b[0].id, " ", _b[0].label);
        coop_panel_click(_b[0].id);
        _c.rj_n = 2;
    }
    if (_c.role == "guest" && _c.connected && _c.rj_n == 2)
    {
        _c.rj_n = 3;
        coop_log("rejoin: back in the session");
    }
    if (_c.rj_n == 3 && _c.rj == _c.rj_t + 600)
    {
        coop_rejoin_forget();
        coop_log("rejoin: done");
    }
    if (_c.role == "host" && _c.rj == 1800) { coop_rejoin_forget(); coop_log("rejoin: done"); }
}

// -coop_scenario pda: the host adds an air drop marker (as the owner's air drop roll does) and puts a ping mark;
// both open the PDA map (screenshots): teammates in colour, the mark, the air drop on the guest's map too.
function coop_test_pda_step()
{
    var _c = coop();
    if (!_c.test_mode || _c.scenario != "pda" || !coop_shared_ready() || !instance_exists(obj_player)) exit;
    if (!variable_struct_exists(_c, "pd")) _c.pd = 0;
    _c.pd++;
    var _t = _c.pd;
    if (_c.role == "host" && _t == 200)
    {
        minimap_add_interesting_marker(floor(obj_player.x / 16) + 6, floor(obj_player.y / 16) - 4, 3);
        _c.sim_ping_at = [obj_player.x + 60, obj_player.y + 30];
        _c.sim_ping = true;
        coop_log("pda: host air drop marker + ping");
    }
    if (_c.role == "guest" && _t == 300)
    {
        var _h = coop_puppet_of(0);
        if (instance_exists(_h)) { obj_player.x = _h.x - 120; obj_player.y = _h.y + 40; }
    }
    if (_t == 400)
    {
        var _n = 0;
        for (var _k = 0; _k < ds_list_size(global.list_intresting_id); _k++) if (ds_list_find_value(global.list_intresting_id, _k) == 3) _n++;
        coop_log("pda: air drop markers=", _n, " marks=", coop_minimap_mark_count(), " mate on map=", coop_minimap_mate_on_map(0), " colour ok=", coop_minimap_mate_color(0) == coop_slot_colour(coop_minimap_mate(0).coop_slot));
        with (obj_player) player_action_open_minimap();
    }
    if (_t == 460) screen_save("pda_" + _c.tag + ".png");
    if (_t == 480) { __uiGlobal().__defaultOnion.Clear(); coop_log("pda: done"); }
}

// -coop_scenario questloot (item 27): one container holds a bandage and a quest document on both machines; the host
// takes the document - the guest still has its own; the guest takes it too - the host's never comes back.
function coop_questloot_set(_inst, _items)
{
    db_open("all loot");
    db_write("chest_" + string(_inst.id), "items", _items);
    db_close();
    _inst.coop_sig = coop_chest_norm(coop_chest_read(_inst));
}

function coop_questloot_has(_inst)
{
    return array_length(coop_chest_quest_list(coop_chest_read(_inst)));
}

function coop_test_questloot_step()
{
    var _c = coop();
    if (!_c.test_mode || _c.scenario != "questloot" || !coop_shared_ready() || !instance_exists(obj_player)) exit;
    if (!variable_struct_exists(_c, "ql")) _c.ql = 0;
    _c.ql++;
    var _t = _c.ql;
    var _mk = function(_item) { var _l = new class_loot(); _l.item = _item; _l.quantity = 1; _l.x = 0; _l.y = 0; return _l; };
    if (_c.role == "host")
    {
        if (_t == 200)
        {
            var _best = -4;
            var _bd = infinity;
            var _px = obj_player.x;
            var _py = obj_player.y;
            instance_activate_object(obj_chest_general);
            with (obj_chest_general)
            {
                if (!variable_instance_exists(id, "coop_dynamic") && point_distance(x, y, _px, _py) < _bd) { _bd = point_distance(x, y, _px, _py); _best = id; }
            }
            _c.ql_inst = _best;
            coop_questloot_set(_best, [_mk("bandage"), _mk("document_quest_lab")]);
            coop_chat_send("QTEST " + coop_chest_key(_best));
            coop_log("questloot: host container ", coop_chest_key(_best), " quest=", coop_questloot_has(_best));
        }
        if (_t == 500)
        {
            var _now = [_mk("bandage")];
            coop_chest_quest_track(_c.ql_inst, _now);
            coop_questloot_set(_c.ql_inst, _now);
            coop_chest_send_content(coop_chest_key(_c.ql_inst), json_stringify(_now), _c.ql_inst);
            coop_log("questloot: host took the document");
        }
        if (_t == 1000)
        {
            coop_log("questloot: host quest back=", coop_questloot_has(_c.ql_inst));
            coop_log("questloot: done");
        }
        exit;
    }
    // guest
    if (!variable_struct_exists(_c, "ql_inst"))
    {
        var _ls = coop_chat().lines;
        for (var _i = 0; _i < array_length(_ls); _i++)
        {
            if (string_pos("QTEST ", _ls[_i].text) == 1)
            {
                var _f = coop_chest_find(string_delete(_ls[_i].text, 1, 6));
                if (instance_exists(_f))
                {
                    _c.ql_inst = _f;
                    _c.ql_t = _t;
                    coop_questloot_set(_f, [_mk("bandage"), _mk("document_quest_lab")]);
                    coop_log("questloot: guest ready");
                }
            }
        }
        exit;
    }
    if (_t == _c.ql_t + 400)
    {
        coop_log("questloot: guest still has quest=", coop_questloot_has(_c.ql_inst));
        var _now = [_mk("bandage")];
        coop_chest_quest_track(_c.ql_inst, _now);
        coop_questloot_set(_c.ql_inst, _now);
        coop_chest_send_content(coop_chest_key(_c.ql_inst), json_stringify(_now), _c.ql_inst);
        coop_log("questloot: guest took the document");
    }
    if (_t == _c.ql_t + 700) coop_log("questloot: done");
}

// -coop_scenario fallen (host: revive off): the guest dies - its things land in a bag; the host takes a stack out of
// it and extracts; the stack goes back to the guest, who gets it into its inventory in the bunker.
function coop_test_fallen_step()
{
    var _c = coop();
    if (!_c.test_mode || _c.scenario != "fallen") exit;
    if (!variable_struct_exists(_c, "fa")) _c.fa = 0;
    _c.fa++;
    var _t = _c.fa;
    var _f = coop_fallen();
    if (_c.role == "guest")
    {
        if (coop_shared_ready() && instance_exists(obj_player) && !variable_struct_exists(_c, "fa_dead") && _t > 400)
        {
            _c.fa_dead = true;
            coop_log("fallen: guest dies");
            obj_player.hp = 0;
        }
        // the death screen's Next, minus the save bookkeeping: back to the bunker
        if (instance_exists(obj_exit_screen) && obj_exit_screen.can_go_hub && !variable_struct_exists(_c, "fa_hub") && _t > 1500)
        {
            _c.fa_hub = true;
            instance_activate_all();
            obj_controller.disattiva = false;
            __uiGlobal().__defaultOnion.Clear();
            room_goto(r_hub);
        }
        if (is_in_hub() && variable_struct_exists(_c, "fa_hub") && !variable_struct_exists(_c, "fa_end"))
        {
            _c.fa_end = _t;
        }
        if (variable_struct_exists(_c, "fa_end") && _t == _c.fa_end + 300) coop_log("fallen: done");
        exit;
    }
    // host
    if (!coop_shared_ready() || !instance_exists(obj_player)) exit;
    with (obj_player) hp = hp_max;
    var _names = variable_struct_get_names(_f.bags);
    if (array_length(_names) > 0 && !variable_struct_exists(_c, "fa_took"))
    {
        var _bag = coop_chest_find(_names[0]);
        if (instance_exists(_bag) && _bag.alarm[0] <= 0)
        {
            var _before = coop_chest_read(_bag);
            if (is_array(_before) && array_length(_before) > 0)
            {
                _c.fa_took = _before[0].item;
                var _after = [];
                for (var _i = 1; _i < array_length(_before); _i++) array_push(_after, _before[_i]);
                coop_fallen_track(_bag, _before, _after);
                db_open("all loot");
                db_write("chest_" + string(_bag.id), "items", _after);
                db_close();
                coop_log("fallen: host took ", _c.fa_took, " from the bag");
                _c.fa_t = _t;
            }
        }
    }
    if (variable_struct_exists(_c, "fa_t") && _t > _c.fa_t + 120)
    {
        instance_activate_object(obj_extraction_point);
        with (obj_extraction_point) { if (!variable_struct_exists(_c, "fa_x")) { _c.fa_x = x; _c.fa_y = y; } }
        if (variable_struct_exists(_c, "fa_x")) { obj_player.x = _c.fa_x + 8; obj_player.y = _c.fa_y + 8; }
    }
}

// -coop_scenario trade: the guest stands next to the host; the host asks (U), the guest accepts; each offers one stack
// (a click on its first / second inventory row), both press Ready; each gets the other's stack.
// -coop_scenario trade_race: the host presses Ready and changes its offer 3 frames later; the guest presses Ready the
// moment it sees the host ready (a stale view): nothing may be handed over until both are ready on the final offers.
function coop_test_trade_step()
{
    var _c = coop();
    if (!_c.test_mode || (_c.scenario != "trade" && _c.scenario != "trade_race") || !coop_shared_ready() || !instance_exists(obj_player)) exit;
    var _race = _c.scenario == "trade_race";
    if (!variable_struct_exists(_c, "tdt")) _c.tdt = 0;
    _c.tdt++;
    var _t = _c.tdt;
    var _tr = coop_trade();
    if (_c.role == "guest")
    {
        var _h = coop_puppet_of(0);
        // next to the host, again every 2 s until the request comes (the host's spawn may move once its map is in)
        if (_t >= 150 && _t mod 120 == 30 && !variable_struct_exists(_c, "td_acc") && instance_exists(_h)) { obj_player.x = _h.x + 30; obj_player.y = _h.y; }
        if (_tr.state == "incoming" && !variable_struct_exists(_c, "td_acc")) { _c.td_acc = _t; }
        if (variable_struct_exists(_c, "td_acc") && _t == _c.td_acc + 30) _c.sim_trade_key = true;
        if (variable_struct_exists(_c, "td_acc") && _t == _c.td_acc + 90) _c.sim_trade_click = [400, 340]; // second row
        if (!_race && variable_struct_exists(_c, "td_acc") && _t == _c.td_acc + 200) _c.sim_trade_click = [500, 850]; // Ready
        if (_race && variable_struct_exists(_c, "td_acc") && _t > _c.td_acc + 100 && _tr.state == "open" && !_tr.ready && _tr.their_sig != ""
            && (!variable_struct_exists(_c, "td_rdy") || _t - _c.td_rdy > 20))
        {
            _c.td_rdy = _t;
            _c.sim_trade_click = [500, 850]; // Ready as soon as the host is
        }
        if (_race && _tr.done && !variable_struct_exists(_c, "td_dn"))
        {
            _c.td_dn = true;
            coop_log("trade race: handed over against an offer of ", array_length(_tr.theirs), " stacks");
        }
        if (variable_struct_exists(_c, "td_acc") && _t == _c.td_acc + (_race ? 700 : 500)) coop_log("trade test: done");
    }
    else
    {
        if (_t == 300) { _c.panel = true; coop_panel_click("near_trade"); } // the panel button (gamepad route)
        if (_tr.state == "open" && !variable_struct_exists(_c, "td_open")) _c.td_open = _t;
        if (variable_struct_exists(_c, "td_open") && _t == _c.td_open + 40) _c.sim_trade_click = [400, 300]; // first row
        if (variable_struct_exists(_c, "td_open") && _t == _c.td_open + 160) { screen_save("trade_" + _c.tag + ".png"); _c.sim_trade_click = [500, 850]; }
        if (_race && variable_struct_exists(_c, "td_open") && _t == _c.td_open + 163) _c.sim_trade_click = [400, 340]; // and a second stack
        if (_race && variable_struct_exists(_c, "td_open") && _t == _c.td_open + 400) _c.sim_trade_click = [500, 850]; // Ready again
        if (_race && _tr.done && !variable_struct_exists(_c, "td_dn"))
        {
            _c.td_dn = true;
            coop_log("trade race: handed over against an offer of ", array_length(_tr.theirs), " stacks");
        }
        if (variable_struct_exists(_c, "td_open") && _t == _c.td_open + (_race ? 660 : 460)) coop_log("trade test: done");
    }
}

// -coop_scenario voice: the guest "speaks" a test tone next to the host (full volume), then 60 m away (silent), then
// both tune the radio to channel 3 (heard again at any distance). The host logs what it gets.
function coop_test_voice_step()
{
    var _c = coop();
    if (!_c.test_mode || _c.scenario != "voice" || !coop_shared_ready() || !instance_exists(obj_player)) exit;
    if (!variable_struct_exists(_c, "vt")) _c.vt = 0;
    _c.vt++;
    var _t = _c.vt;
    var _v = coop_voice();
    if (_t == 100) { _v.mode = 1; _v.channel = 0; coop_log("voice: recorders=", audio_get_recorder_count()); }
    with (obj_player) hp = hp_max;
    if (_c.role == "guest")
    {
        var _h = coop_puppet_of(0);
        if (_t == 150 && instance_exists(_h)) { obj_player.x = _h.x + 40; obj_player.y = _h.y; _c.voice_test_tone = 0; }
        if (_t > 150 && _t < 900 && _t mod 120 == 30 && instance_exists(_h)) { obj_player.x = _h.x + 40; obj_player.y = _h.y; } // stay next to it
        // the steps are 700+ ticks apart: host and guest test clocks start when each one's map is ready (seconds apart)
        if (_t == 900 && instance_exists(_h)) { obj_player.x = _h.x + 1000; }
        if (_t == 1650) { _v.channel = 3; inventory_add_item(COOP_RADIO_ITEM, 1); coop_log("voice test: guest radio=", coop_radio_have()); }
        if (_t == 2100) { variable_struct_remove(_c, "voice_test_tone"); coop_log("voice test: done"); }
    }
    else
    {
        if (_t == 1650) _v.channel = 3; // no radio in the host's inventory yet: channel 3 does nothing
        if (_t == 1750) { coop_log("voice test: host without radio gain=", coop_voice_gain(1)); inventory_add_item(COOP_RADIO_ITEM, 1); coop_log("voice test: bar sells radio=", coop_radio_sold(), " name=", item_get_name(COOP_RADIO_ITEM)); }
        if (_t == 550 || _t == 1250 || _t == 2000)
        {
            var _s = _v.spk[1];
            coop_log("voice test: t=", _t, " got=", is_struct(_s) ? _s.got : 0, " gain=", coop_voice_gain(1), " speaking=", coop_voice_speaking(1));
        }
        if (_t == 2100) coop_log("voice test: done");
    }
}

// -coop_scenario radio: both get a radio (the guest's in quick slot 1). The guest, 60 m away, raises it with the quick
// slot and talks (test tone): the host hears it on channel 1; lowered, the host hears nothing. Also checks the
// workshop recipe and the barman's reputation gate.
function coop_test_radio_step()
{
    var _c = coop();
    if (!_c.test_mode || _c.scenario != "radio" || !coop_shared_ready() || !instance_exists(obj_player)) exit;
    if (!variable_struct_exists(_c, "rdt")) _c.rdt = 0;
    _c.rdt++;
    var _t = _c.rdt;
    var _v = coop_voice();
    with (obj_player) hp = hp_max;
    if (_t == 100)
    {
        _v.mode = 1;
        _v.channel = 1;
        inventory_add_item(COOP_RADIO_ITEM, 1);
        var _rec = -1;
        for (var _i = 0; _i < array_length(global.craft_get); _i++) if (global.craft_get[_i] == COOP_RADIO_ITEM) _rec = _i;
        var _lvl = -1;
        var _items = variable_struct_get(global.trader_data, "bar").items;
        for (var _i = 0; _i < array_length(_items); _i++) if (_items[_i].item == COOP_RADIO_ITEM) _lvl = _items[_i].level;
        coop_log("radio test: have=", coop_radio_have(), " recipe=", _rec >= 0, " module=", (_rec >= 0) ? global.craft_req_module_id[_rec] : -1,
            " bar level=", _lvl, " category=", item_get_category(COOP_RADIO_ITEM));
    }
    if (_c.role == "guest")
    {
        var _h = coop_puppet_of(0);
        if (_t == 150 && instance_exists(_h)) { obj_player.x = _h.x + 1000; obj_player.y = _h.y; }
        if (_t == 160)
        {
            // into quick slot 1 (as dragged in the inventory)
            var _db = inventory_target_db();
            db_open(_db);
            var _arr = db_read("Inventory", "items", []);
            for (var _i = 0; _i < array_length(_arr); _i++)
            {
                if (_arr[_i].placement == "quick slot 1") { _arr[_i].placement = "player inventory"; }
            }
            for (var _i = 0; _i < array_length(_arr); _i++)
            {
                if (_arr[_i].item == COOP_RADIO_ITEM) { _arr[_i].placement = "quick slot 1"; _arr[_i].x = 0; _arr[_i].y = 0; }
            }
            db_write("Inventory", "items", _arr);
            db_close();
        }
        if (_t == 200)
        {
            inventory_use_quick_slot("quick slot 1");
            coop_log("radio test: guest raised=", coop_radio_in_hand(), " talk channel=", coop_radio_talk_channel());
            _c.voice_test_tone = 0;
        }
        if (_t == 260) coop_log("radio test: shooting blocked=", obj_player.shooting);
        if (_t == 280) screen_save("radio_" + _c.tag + ".png");
        if (_t == 1000) // far from the host's checks at 600 / 1300 (the two test clocks differ by seconds)
        {
            inventory_use_quick_slot("quick slot 1");
            coop_log("radio test: guest lowered, in hand=", coop_radio_in_hand());
        }
        if (_t == 1400) { variable_struct_remove(_c, "voice_test_tone"); coop_log("radio test: done"); }
    }
    else
    {
        if (_t == 600 || _t == 1300)
        {
            var _s = _v.spk[1];
            coop_log("radio test: t=", _t, " got=", is_struct(_s) ? _s.got : 0, " gain=", coop_voice_gain(1), " radio drawn=", instance_exists(coop_puppet_of(1)) && (coop_puppet_of(1).coop_flags & 32) != 0);
        }
        if (_t == 1400) coop_log("radio test: done");
    }
}

// -coop_scenario event (the owner offers an event 8 s into the raid): both go to the survivor, the guest takes the
// job (E); the host kills the event enemies wave by wave; at the end the reward bag appears.
function coop_test_event_step()
{
    var _c = coop();
    if (!_c.test_mode || _c.scenario != "event" || !coop_shared_ready() || !instance_exists(obj_player)) exit;
    var _e = coop_ev();
    with (obj_player) hp = hp_max;
    if (!variable_struct_exists(_c, "evt")) _c.evt = 0;
    _c.evt++;
    if (_e.state == "offered" || _e.state == "active")
    {
        // stand next to the survivor
        if (_c.evt mod 30 == 0) { obj_player.x = _e.x + ((_c.role == "host") ? -20 : 20); obj_player.y = _e.y + 10; }
        if (_c.role == "guest" && _e.state == "offered" && _c.evt mod 120 == 60) { _c.sim_event_e = true; coop_log("event test: guest presses E"); }
        if (_e.state == "offered" && !variable_struct_exists(_c, "ev_shot") && _c.evt > 200) { _c.ev_shot = true; screen_save("event_" + _c.tag + ".png"); }
        if (_c.role == "host" && _e.state == "offered" && !variable_struct_exists(_c, "ev_still") && _c.evt > 150 && instance_exists(_e.giver))
        {
            _c.ev_still = true;
            coop_log("event test: survivor moved ", floor(point_distance(_e.giver.x, _e.giver.y, _e.x, _e.y)), " px");
        }
    }
    // the host shoots the event enemies down (kills them on the owner)
    if (_c.role == "host" && _e.state == "active" && _c.evt mod 90 == 0)
    {
        for (var _i = 0; _i < array_length(_e.npcs); _i++)
        {
            instance_activate_object(_e.npcs[_i]);
            if (instance_exists(_e.npcs[_i]) && _e.npcs[_i].hp > 0) { _e.npcs[_i].hp = 0; break; }
        }
    }
    if (_e.state == "done" && !variable_struct_exists(_c, "ev_done")) { _c.ev_done = _c.evt; }
    if (variable_struct_exists(_c, "ev_done") && _c.evt == _c.ev_done + 240) coop_log("event test: done");
}

// -coop_scenario quest (item 8): both have the same kill task (a test quest: 20 kills of the humans on this map). The
// guest kills 3 (credited by the host, the owner), the host kills 2: each machine counts both, and the reward shares
// are 3/5 and 2/5.
function coop_test_quest_step()
{
    var _c = coop();
    if (!_c.test_mode || _c.scenario != "quest" || !coop_shared_ready() || !instance_exists(obj_player)) exit;
    if (!variable_struct_exists(_c, "qt2")) { _c.qt2 = 0; _c.q_kills = 0; }
    _c.qt2++;
    var _t = _c.qt2;
    with (obj_player) hp = hp_max;
    if (_t == 120)
    {
        var _ids = [];
        instance_activate_object(obj_npc_parent);
        with (obj_npc_parent)
        {
            if (object_is_ancestor(object_index, obj_npc_human_parent) && variable_instance_exists(id, "npc_id") && !array_contains(_ids, npc_id)) array_push(_ids, npc_id);
        }
        variable_struct_set(global.quest_database, "coop_test_quest", { objective: [{ type: "kill", map: -1, array_kill: _ids, amount_max: 20 }], money: 1000, experience: 100, reputation: 0 });
        for (var _i = 0; _i < 30; _i++)
        {
            if (global.quest_state[_i].id == "")
            {
                var _q = new class_quest_state();
                _q.id = "coop_test_quest";
                _q.state = "active";
                global.quest_state[_i] = _q;
                _c.q_slot = _i;
                break;
            }
        }
        coop_log("quest test: task with ", array_length(_ids), " npc types");
    }
    var _want = (_c.role == "guest") ? 3 : 2;
    var _qw = coop_qwork();
    _c.q_kills = variable_struct_exists(_qw, "coop_test_quest") ? variable_struct_get(_qw, "coop_test_quest").me : 0;
    if (_t > 200 && _t < 1400 && _t mod 20 == 0 && _c.q_kills < _want && !variable_struct_exists(_c, "q_wait"))
    {
        // kill one human: the guest by shooting (the owner credits it), the host directly
        instance_activate_object(obj_npc_parent);
        var _best = -4;
        var _bd = infinity;
        with (obj_npc_parent)
        {
            if (hp > 1 && object_is_ancestor(object_index, obj_npc_human_parent) && !(variable_instance_exists(id, "coop_event_giver")))
            {
                var _d = point_distance(x, y, obj_player.x, obj_player.y);
                if (_d < _bd) { _bd = _d; _best = id; }
            }
        }
        if (instance_exists(_best))
        {
            obj_player.x = _best.x - 40;
            obj_player.y = _best.y;
            var _tg = _best;
            with (obj_player)
            {
                if (item_exists(arma_now) && item_get_category(arma_now) == "weapon") scr_shoot(point_direction(x, y, _tg.x, _tg.y), 1, 999, 0);
            }
        }
    }
    if (_t == 1400)
    {
        var _s = global.quest_state[_c.q_slot];
        var _w = coop_qwork();
        var _e = variable_struct_exists(_w, "coop_test_quest") ? variable_struct_get(_w, "coop_test_quest") : { me: 0, others: 0 };
        coop_log("quest test: progress=", _s.amount_now[0], " me=", _e.me, " others=", _e.others, " money=", coop_quest_reward("coop_test_quest", 1000));
        global.quest_state[_c.q_slot] = new class_quest_state();
        coop_quest_turned_in("coop_test_quest");
        coop_log("quest test: done");
    }
}

// -coop_scenario barq (bunker): with two players the barman offers the group tasks; the host takes one (the game's
// accept), the quest window is shot; the guest leaves co-op and the free tasks are withdrawn on the host.
function coop_test_barq_step()
{
    var _c = coop();
    if (!_c.test_mode || _c.scenario != "barq" || !is_in_hub() || !instance_exists(obj_player)) exit;
    if (!variable_struct_exists(_c, "bq")) _c.bq = 0;
    _c.bq++;
    var _t = _c.bq;
    var _bar = coop_barq_barman();
    if (_c.role == "guest") _c.bq_guest = true;
    if (variable_struct_exists(_c, "bq_guest"))
    {
        if (_t == 900) { coop_log("barq: guest leaves"); coop_panel_click("leave"); }
        if (_t == 1000) coop_log("barq: done");
        exit;
    }
    // host: from the moment the guest is here
    if (!variable_struct_exists(_c, "bq0"))
    {
        if (_c.connected && coop_player_count() > 1) _c.bq0 = _t; else exit;
    }
    if (!variable_struct_exists(_c, "bq_left") && _t > _c.bq0 + 500 && coop_player_count() <= 1) _c.bq_left = _t;
    if (variable_struct_exists(_c, "bq_left")) { _t = (_t == _c.bq_left + 120) ? 1300 : -1; } else { _t = _t - _c.bq0 + 100; }
    if (_t == 400)
    {
        coop_log("barq: barman=", instance_exists(_bar), " list has bandits=", instance_exists(_bar) && array_contains(_bar.quest_array, "coop_q_bandits"),
            " mutants=", instance_exists(_bar) && array_contains(_bar.quest_array, "coop_q_mutants"));
        if (instance_exists(_bar))
        {
            obj_player.x = _bar.x;
            obj_player.y = _bar.y + 20;
            global.speaker_nearest = _bar;
            player_action_talk_to_npc();
            uiFind(uiLayerGetRoot("npc"), "left frame").ReplaceFromFile("ZS_vanilla/ui/npc_left_quest_selection.ui");
            uiGetData().npc_instance = _bar;
            uiGetData().npc_quest_index = array_get_index(_bar.quest_array, "coop_q_bandits");
            try { npc_dialogue_quest_accept(); } catch (_ex) { coop_log("barq: accept ui: ", _ex.message); }
            coop_log("barq: accepted=", coop_barq_active("coop_q_bandits"));
        }
    }
    if (_t == 460) screen_save("barq_" + _c.tag + ".png");
    if (_t == 480) { __uiGlobal().__defaultOnion.Clear(); player_set_local_state(scr_player_state_move); }
    if (_t == 1300)
    {
        coop_log("barq: after the guest left, mutants offered=", instance_exists(_bar) && array_contains(_bar.quest_array, "coop_q_mutants"),
            " accepted kept=", coop_barq_active("coop_q_bandits"));
        // leave the test save as it was
        for (var _i = 0; _i < 30; _i++) if (global.quest_state[_i].id == "coop_q_bandits") global.quest_state[_i] = new class_quest_state();
        coop_log("barq: done");
    }
}

// -coop_scenario arena (bunker): the host starts the arena and takes the AK preset, the guest keeps its own gear and
// shoots the host (frags); mid-fight the host writes a real save (its own weapon must go back first); the host ends it.
function coop_test_arena_step()
{
    var _c = coop();
    if (!_c.test_mode || _c.scenario != "arena" || !is_in_hub() || !instance_exists(obj_player)) exit;
    var _a = coop_arena();
    if (!variable_struct_exists(_c, "ar")) _c.ar = 0;
    if (!_c.connected || coop_player_count() < 2) exit;
    _c.ar++;
    var _t = _c.ar;
    if (_c.role == "host")
    {
        if (_t == 300) { _c.ar_own = obj_player.arma_now; coop_log("arena test: own weapon ", _c.ar_own); coop_arena_start(); }
        if (_t == 320) _c.sim_arena_pick = 2;
        if (_t == 360) coop_log("arena test: host weapon now ", obj_player.arma_now, " swapped=", _a.swapped);
        if (_t == 650) coop_log("arena test: host got bullets ", variable_struct_exists(_c, "bullets_recv") ? _c.bullets_recv : 0, " hp ", obj_player.hp, " at ", floor(obj_player.x), ",", floor(obj_player.y));
        if (_t == 700) { db_force_save("pre_raid"); coop_log("arena test: after a save swapped=", _a.swapped, " weapon ", obj_player.arma_now); }
        if (_t == 900)
        {
            coop_arena_send(2, 0, 0);
            coop_arena_end("test");
            var _w = player_loadout_get_loot(obj_player, "weapon slot 1", false);
            coop_log("arena test: end, weapon back=", obj_player.arma_now == _c.ar_own || (is_struct(_w) && _w.item == _c.ar_own), " frags guest=", _a.frags[1], " hp full=", obj_player.hp == obj_player.hp_max);
            screen_save("arena_end_" + _c.tag + ".png");
        }
        if (_t == 1000) coop_log("arena test: done");
    }
    else
    {
        if (_a.on && _a.pick && !variable_struct_exists(_c, "ar_p")) { _c.ar_p = true; _c.sim_arena_pick = -1; }
        if (_a.on && !_a.pick && _t mod 20 == 0)
        {
            var _h = coop_puppet_of(0);
            if (instance_exists(_h))
            {
                obj_player.x = _h.x - 50;
                obj_player.y = _h.y;
                with (obj_player) if (item_exists(arma_now) && item_get_category(arma_now) == "weapon") scr_shoot(point_direction(x, y, _h.x, _h.y - 6), 1, 300, 0);
            }
        }
        if (_a.on && !_a.pick && !variable_struct_exists(_c, "ar_shot") && _t mod 20 == 10) { _c.ar_shot = true; screen_save("arena_" + _c.tag + ".png"); coop_log("arena test: guest weapon ", obj_player.arma_now, " at ", floor(obj_player.x), ",", floor(obj_player.y), " bullets ", instance_number(obj_bullet_parent)); }
        if (!_a.on && variable_struct_exists(_c, "ar_p") && !variable_struct_exists(_c, "ar_done")) { _c.ar_done = _t; }
        if (variable_struct_exists(_c, "ar_done") && _t == _c.ar_done + 100) coop_log("arena test: done");
    }
}

// -coop_scenario migrate (3 players in a raid): the host quits the game; slot 1 takes the session over, slot 2
// reconnects to it, both stay in the raid and see each other again.
function coop_test_migrate_step()
{
    var _c = coop();
    if (!_c.test_mode || (_c.scenario != "migrate" && _c.scenario != "migrate_crash") || !coop_in_raid() || !instance_exists(obj_player)) exit;
    if (!variable_struct_exists(_c, "mg")) { _c.mg = 0; _c.mg_was = _c.slot; }
    _c.mg++;
    var _t = _c.mg;
    with (obj_player) hp = hp_max;
    if (_c.role == "host" && _c.mg_was == 0 && _t == 700 && coop_player_count() >= 3)
    {
        coop_log("migrate test: host quits");
        if (_c.scenario == "migrate_crash")
        {
            // like a crash: no goodbye, the socket just goes silent
            network_destroy(_c.sock);
            _c.sock = -1;
            _c.connected = false;
            _c.role = "none";
        }
        game_end();
    }
    if (_c.mg_was > 0 && _c.connected && _c.slot == 0 && !variable_struct_exists(_c, "mg_host")) { _c.mg_host = _t; coop_log("migrate test: I host now (was slot ", _c.mg_was, ")"); }
    if (_c.mg_was > 0 && _c.role == "guest" && _c.connected && variable_struct_exists(_c, "mg_lost") && !variable_struct_exists(_c, "mg_back")) { _c.mg_back = _t; coop_log("migrate test: back in, slot ", _c.slot); }
    if (_c.mg_was > 0 && !_c.connected && !variable_struct_exists(_c, "mg_lost")) _c.mg_lost = _t;
    var _end = variable_struct_exists(_c, "mg_host") ? _c.mg_host : (variable_struct_exists(_c, "mg_back") ? _c.mg_back : -1);
    if (_end >= 0 && _t == _end + 900)
    {
        coop_log("migrate test: done players=", coop_player_count(), " puppets=", array_length(coop_puppets()), " owner me=", coop_is_world_owner(), " in raid=", coop_in_raid());
    }
}

// -coop_scenario bystand: an extra player for the 3-8 player runs of the two-player scenarios (regress.py "name@N").
// Joins, goes into the raid with the group (the train zone), follows the host there and never dies - so every
// feature is checked with a full session around it, without taking part in the scripted steps.
function coop_test_bystand_step()
{
    var _c = coop();
    if (_c.scenario != "bystand")
    {
        exit;
    }
    // after an extraction: the "next" button of the extraction screen (as the host of the leave test)
    if (instance_exists(obj_exit_screen) && obj_exit_screen.can_go_hub && !variable_struct_exists(_c, "bs_gone"))
    {
        _c.bs_gone = true;
        coop_log("bystand: slot ", _c.slot, " leaves the extraction screen");
        instance_activate_all();
        obj_controller.disattiva = false;
        __uiGlobal().__defaultOnion.Clear();
        room_goto(r_hub);
    }
    if (!instance_exists(obj_player))
    {
        exit;
    }
    if (!instance_exists(obj_exit_screen) && variable_struct_exists(_c, "bs_gone")) variable_struct_remove(_c, "bs_gone");
    if (!variable_struct_exists(_c, "bs_t")) { _c.bs_t = 0; coop_log("bystand: slot ", _c.slot, " ready"); }
    _c.bs_t++;
    with (obj_player) hp = hp_max;
    // the group leaves together: walk to the exit the host is extracting at (players do the same)
    var _xo = coop_extract().others[0];
    if (coop_in_raid() && _c.bs_t mod 30 == 0 && is_struct(_xo) && _xo.in_zone && current_time - _xo.t < 3000)
    {
        with (obj_player) { x = _xo.px + 12 * max(1, coop().slot); y = _xo.py; }
    }
    else if (coop_in_raid() && _c.bs_t mod 60 == 0)
    {
        var _h = coop_puppet_of(0);
        if (instance_exists(_h) && point_distance(obj_player.x, obj_player.y, _h.x, _h.y) > 600)
        {
            var _a = max(1, _c.slot) * 45;
            var _nx = _h.x + lengthdir_x(260, _a);
            var _ny = _h.y + lengthdir_y(260, _a);
            with (obj_player) { if (!place_meeting(_nx, _ny, obj_solid)) { x = _nx; y = _ny; } else { x = _h.x; y = _h.y; } }
        }
    }
    if (_c.bs_t mod 1800 == 0) coop_log("bystand: slot ", _c.slot, " alive, raid=", coop_in_raid(), " players=", coop_player_count());
}

// Tests are written for two players: the partner is the other one of the pair (host: slot 1, guest: slot 0), not a
// bystander that happens to stand closer ("name@N" runs, scenario bystand).
function coop_test_partner()
{
    var _want = (coop().slot == 0) ? 1 : 0;
    with (obj_player_puppet)
    {
        if (variable_instance_exists(id, "coop_slot") && coop_slot == _want) return id;
    }
    return coop_partner();
}
