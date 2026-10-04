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
    if (_c.scenario != "livechest" || !coop_shared_ready() || !instance_exists(obj_player))
    {
        exit;
    }
    if (!variable_struct_exists(_c, "lt")) _c.lt = 0;
    _c.lt++;
    var _t = _c.lt;
    var _tag = _c.tag;
    if (_t == 110)
    {
        instance_activate_object(obj_chest_general);
    }
    if (_t == 115)
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
