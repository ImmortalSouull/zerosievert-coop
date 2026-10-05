// ZERO Sievert co-op: extra scripted test scenarios (test mode only).

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
    coop_test_solo_step();
    coop_test_soak_step();
    coop_test_menus_step();
    coop_test_treefade_step();
    if (_c.scenario != "livechest" || !coop_shared_ready() || !instance_exists(obj_player))
    {
        exit;
    }
    if (!variable_struct_exists(_c, "lt")) _c.lt = 0;
    _c.lt++;
    var _t = _c.lt;
    var _tag = _c.tag;
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
    if (_t == 160 || _t == 280)
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
    if (_t == 320)
    {
        ui_chest_close();
        __uiGlobal().__defaultOnion.Clear();
        player_set_local_state(scr_player_state_move);
    }
    if (_t == 360 && _c.role == "guest")
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
    if (_t == 420 && _c.role == "host")
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
    if (_t == 520 && _c.role == "host")
    {
        player_action_open_minimap();
    }
    if (_t == 580 && _c.role == "host")
    {
        screen_save("lc_map_" + _tag + ".png");
    }
    if (_t == 640)
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
        instance_activate_object(obj_npc_parent);
        with (obj_npc_parent)
        {
            if (variable_instance_exists(id, "coop_nid") && coop_nid < 40 && object_is_ancestor(object_index, obj_npc_human_parent))
            {
                _sum += hp; // nobody has shot yet
                _n++;
            }
        }
        coop_log("v3: group hp factor=", coop_group_factor("hp"), " npc hp sum=", _sum, " n=", _n);
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
        _c.f_key = (_t == 120) ? 3 : 1; // hold left, then down (coop_test_input)
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
        var _host = coop_partner();
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
    var _p = coop_partner();
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
        if (_t == 941) _c.sim_give = true;
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
        coop_base_rebuild();
        coop_log("lobby2: own modules raised");
    }
    if (_t == 200)
    {
        coop_visit_place_player();
    }
    if (_t == 230)
    {
        coop_log("lobby2: own decor=", coop_lobby_count_decor(), " host base ", json_stringify(coop_peer(0).base));
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
        coop_log("lobby2: back decor=", coop_lobby_count_decor());
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
    if (!variable_struct_exists(_c, "so_t")) _c.so_t = 0;
    _c.so_t++;
    var _t = _c.so_t;
    if (_t >= 120 && _t <= 900 && _t mod 20 == 0 && instance_exists(obj_player))
    {
        instance_activate_object(obj_npc_parent);
        var _tg = instance_nearest(obj_player.x, obj_player.y, obj_npc_human_parent);
        if (instance_exists(_tg))
        {
            if (_t mod 200 == 0)
            {
                obj_player.x = _tg.x - 60;
                obj_player.y = _tg.y;
            }
            with (obj_player)
            {
                if (item_exists(arma_now) && item_get_category(arma_now) == "weapon")
                {
                    scr_shoot(point_direction(x, y, _tg.x, _tg.y), 1, item_weapon_get_damage(arma_now), 0);
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
        coop_log("solo: done, npcs=", _n, " hp=", obj_player.hp, " fps=", fps);
    }
}
