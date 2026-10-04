// ZERO Sievert co-op: local player broadcast + puppets of the other players.
// Each client sees itself as player index 0; the player in slot s is mp_index coop_mp_of(s) (1..3), using the
// game's own multiplayer player API (player_get / player_create with obj_player_puppet).

#macro COOP_MSG_ARMS 12
#macro COOP_MSG_PSND 13

function coop_state_list()
{
    static _list = [scr_player_state_move, scr_player_state_inventory, scr_player_state_dead, scr_player_state_start,
        scr_player_state_consumable_animation, scr_player_state_sleep, scr_player_state_craft, scr_player_state_item_spawn,
        scr_player_state_weapon_look, scr_player_state_cristallo_viola, scr_player_state_free_camera, scr_player_state_talk,
        scr_player_state_teleport];
    return _list;
}

function coop_state_to_id(_state)
{
    var _list = coop_state_list();
    for (var _i = 0; _i < array_length(_list); _i++)
    {
        if (_list[_i] == _state)
        {
            return _i;
        }
    }
    return 0;
}

// The character of the player in slot _slot on this machine (noone if not in our raid).
function coop_puppet_of(_slot)
{
    if (_slot == coop().slot)
    {
        return instance_exists(obj_player) ? obj_player.id : -4;
    }
    with (obj_player_puppet)
    {
        if (variable_instance_exists(id, "coop_slot") && coop_slot == _slot)
        {
            return id;
        }
    }
    return -4;
}

// All puppets (other players' characters) present in our raid.
function coop_puppets()
{
    var _out = [];
    with (obj_player_puppet)
    {
        if (variable_instance_exists(id, "coop_slot"))
        {
            array_push(_out, id);
        }
    }
    return _out;
}

// Older single-partner call sites: the nearest other player's character.
function coop_partner()
{
    if (!instance_exists(obj_player_puppet))
    {
        return -4;
    }
    if (!instance_exists(obj_player))
    {
        return instance_find(obj_player_puppet, 0);
    }
    return instance_nearest(obj_player.x, obj_player.y, obj_player_puppet);
}

// ---- local -> partner ----

function coop_players_step()
{
    var _c = coop();
    if (!_c.connected || !coop_in_raid() || !instance_exists(obj_player))
    {
        exit;
    }
    if (_c.frame mod 2 == 0 && _c.peer_in_raid)
    {
        coop_send_pstate();
    }
    // Loadout changes (weapon swap, armor change): checked a few times per second.
    if (_c.frame mod 10 != 0)
    {
        exit;
    }
    with (obj_player)
    {
        var _sig = string(arma_now) + "|" + string(armor_now) + "|" + string(backpack_now) + "|" + string(headset_now) + "|" + string(weapon_slot_now);
        if (!variable_instance_exists(id, "coop_loadout_sig") || coop_loadout_sig != _sig || _c.frame mod 300 == 0)
        {
            coop_loadout_sig = _sig;
            coop_send_loadout();
        }
    }
}

function coop_send_pstate()
{
    var _c = coop();
    var _b = coop_msg_begin(COOP_MSG_PSTATE);
    with (obj_player)
    {
        buffer_write(_b, buffer_f32, x);
        buffer_write(_b, buffer_f32, y);
        buffer_write(_b, buffer_f32, weapon_pointing_direction);
        buffer_write(_b, buffer_f32, aim_point_x);
        buffer_write(_b, buffer_f32, aim_point_y);
        buffer_write(_b, buffer_s8, sign(image_xscale));
        buffer_write(_b, buffer_s32, real(sprite_index));
        buffer_write(_b, buffer_f32, image_index);
        buffer_write(_b, buffer_u8, coop_state_to_id(state));
        buffer_write(_b, buffer_f32, hp);
        buffer_write(_b, buffer_f32, hp_max);
        var _flags = 0;
        if (aiming) _flags |= 1;
        if (coop_down_is_down()) _flags |= 2;
        if (torch_on_general) _flags |= 4;
        if (laser_on_general) _flags |= 8;
        buffer_write(_b, buffer_u8, _flags);
        // hands animation (meds, food, drinks, smoking, grenade): class_player_arms
        var _arms = arms_holder;
        var _has_arms = is_struct(_arms) && !_arms.destroyed;
        buffer_write(_b, buffer_s32, _has_arms ? real(_arms.sprite_index) : -1);
        buffer_write(_b, buffer_f32, _has_arms ? _arms.image_index : 0);
        // weapon as drawn (recoil kick, weapon inspection), relative to the player
        var _w = weapon_holder;
        buffer_write(_b, buffer_f32, _w.x - x);
        buffer_write(_b, buffer_f32, _w.y - y);
        buffer_write(_b, buffer_f32, _w.image_angle);
        buffer_write(_b, buffer_f32, _w.image_xscale);
        buffer_write(_b, buffer_u8, _w.draw_before_follow ? 1 : 0);
        if (_has_arms && !variable_struct_exists(_arms, "coop_sent"))
        {
            _arms.coop_sent = true;
            coop_arms_started = _arms.item_id;
        }
    }
    coop_msg_send(false);
    with (obj_player)
    {
        if (variable_instance_exists(id, "coop_arms_started") && coop_arms_started != undefined)
        {
            // start of an animation: reliable, so the partner hears the item's sound once
            var _b2 = coop_msg_begin(COOP_MSG_ARMS);
            buffer_write(_b2, buffer_string, string(coop_arms_started));
            coop_msg_send(true);
            coop_arms_started = undefined;
        }
    }
}

function coop_send_loadout()
{
    var _c = coop();
    if (!_c.connected || !instance_exists(obj_player))
    {
        exit;
    }
    var _b = coop_msg_begin(COOP_MSG_PLOADOUT);
    with (obj_player)
    {
        var _data = {
            arma_now: arma_now,
            armor_now: armor_now,
            backpack_now: backpack_now,
            headset_now: headset_now,
            weapon_slot_now: weapon_slot_now,
            w1: coop_loot_to_struct(player_loadout_get_loot(self, "weapon slot 1", false)),
            w2: coop_loot_to_struct(player_loadout_get_loot(self, "weapon slot 2", false))
        };
        buffer_write(_b, buffer_string, json_stringify(_data));
    }
    coop_msg_send(true);
}

// Plain-data copy of a class_loot (methods/statics are not serialisable).
function coop_loot_to_struct(_loot)
{
    if (!is_struct(_loot))
    {
        return undefined;
    }
    var _out = {};
    var _names = variable_struct_get_names(_loot);
    for (var _i = 0; _i < array_length(_names); _i++)
    {
        var _v = variable_struct_get(_loot, _names[_i]);
        if (!is_method(_v))
        {
            variable_struct_set(_out, _names[_i], _v);
        }
    }
    return _out;
}

function coop_struct_to_loot(_data)
{
    if (!is_struct(_data))
    {
        return undefined;
    }
    var _loot = new class_loot();
    var _names = variable_struct_get_names(_data);
    for (var _i = 0; _i < array_length(_names); _i++)
    {
        variable_struct_set(_loot, _names[_i], variable_struct_get(_data, _names[_i]));
    }
    return _loot;
}

// ---- partner -> puppet ----

function coop_puppet_ensure(_slot, _x, _y)
{
    var _p = coop_puppet_of(_slot);
    if (instance_exists(_p))
    {
        return _p;
    }
    if (!coop_raid_ready() || !instance_exists(obj_player))
    {
        return -4;
    }
    _p = player_create(_x, _y, coop_mp_of(_slot));
    with (_p)
    {
        coop_slot = _slot;
        weapon_holder.is_visible = false; // until the loadout and the first pose arrive
        coop_net_x = _x;
        coop_net_y = _y;
        coop_hp = 100;
        coop_hp_max = 100;
        hp = 100;
        hp_max = 100;
        coop_flags = 0;
        coop_lights_were_on = false;
        coop_name = coop_peer_name(_slot);
        state = scr_player_state_move;
    }
    var _peer = coop_peer(_slot);
    if (is_struct(_peer) && variable_struct_exists(_peer, "loadout"))
    {
        coop_puppet_apply_loadout(_p, _peer.loadout);
    }
    player_get(-1); // reset player_get cache
    coop_log("puppet of slot ", _slot, " created at ", _x, ",", _y);
    return _p;
}

function coop_puppet_remove_slot(_slot)
{
    var _p = coop_puppet_of(_slot);
    if (instance_exists(_p) && _p.object_index == obj_player_puppet)
    {
        instance_destroy(_p);
        player_get(-1);
        coop_log("puppet of slot ", _slot, " removed");
    }
}

function coop_puppet_remove_all()
{
    var _l = coop_puppets();
    for (var _i = 0; _i < array_length(_l); _i++)
    {
        instance_destroy(_l[_i]);
    }
    if (array_length(_l) > 0)
    {
        player_get(-1);
        coop_log("puppets removed: ", array_length(_l));
    }
}

// Legacy name.
function coop_puppet_remove()
{
    coop_puppet_remove_all();
}

function coop_puppet_on_state(_b)
{
    var _x = buffer_read(_b, buffer_f32);
    var _y = buffer_read(_b, buffer_f32);
    var _dir = buffer_read(_b, buffer_f32);
    var _ax = buffer_read(_b, buffer_f32);
    var _ay = buffer_read(_b, buffer_f32);
    var _xs = buffer_read(_b, buffer_s8);
    var _spr = buffer_read(_b, buffer_s32);
    var _img = buffer_read(_b, buffer_f32);
    var _st = buffer_read(_b, buffer_u8);
    var _hp = buffer_read(_b, buffer_f32);
    var _hpm = buffer_read(_b, buffer_f32);
    var _flags = buffer_read(_b, buffer_u8);
    var _arms_spr = buffer_read(_b, buffer_s32);
    var _arms_img = buffer_read(_b, buffer_f32);
    var _wdx = buffer_read(_b, buffer_f32);
    var _wdy = buffer_read(_b, buffer_f32);
    var _wang = buffer_read(_b, buffer_f32);
    var _wxs = buffer_read(_b, buffer_f32);
    var _wbf = buffer_read(_b, buffer_u8);
    var _c = coop();
    var _slot = _c.msg_from;
    var _peer = coop_peer(_slot);
    if (!is_struct(_peer) || !_peer.in_raid)
    {
        exit;
    }
    var _p = coop_puppet_ensure(_slot, _x, _y);
    if (!instance_exists(_p))
    {
        exit;
    }
    if (_slot == 0)
    {
        coop_spawn_sync(_x, _y);
    }
    with (_p)
    {
        coop_net_x = _x;
        coop_net_y = _y;
        weapon_pointing_direction = _dir;
        aim_point_x = _ax;
        aim_point_y = _ay;
        image_xscale = (_xs == 0) ? 1 : _xs;
        if (sprite_exists(_spr))
        {
            sprite_index = _spr;
        }
        image_index = _img;
        var _list = coop_state_list();
        state = _list[clamp(_st, 0, array_length(_list) - 1)];
        // took damage on their machine: the same white flash the game gives a hit player
        if (_hp < coop_hp - 0.5 && !(_flags & 2))
        {
            hit_shader = "BULLET_HIT_SHADER_NORMAL";
            alarm[3] = 3;
        }
        coop_hp = _hp;
        coop_name = coop_peer_name(_slot);
        coop_hp_max = _hpm;
        hp = _hp;
        coop_flags = _flags;
        aiming = (_flags & 1) != 0;
        torch_on_general = (_flags & 4) != 0;
        laser_on_general = (_flags & 8) != 0;
        coop_w = [_wdx, _wdy, _wang, _wxs, _wbf != 0];
        coop_puppet_set_arms(_arms_spr, _arms_img);
    }
}

// ---- partner's hands animation (display only: no healing/eating logic runs on the puppet) ----

function coop_puppet_set_arms(_spr, _img)
{
    var _a = arms_holder;
    if (_spr < 0 || !sprite_exists(_spr))
    {
        if (is_struct(_a))
        {
            _a.func_destroy();
        }
        arms_holder = undefined;
        exit;
    }
    if (!is_struct(_a) || _a.destroyed)
    {
        _a = {
            destroyed: false,
            follow_id: id,
            item_id: "no_item",
            sprite_index: _spr,
            image_index: _img,
            image_speed: 0,
            coop_view: true
        };
        _a.func_draw = method(_a, coop_arms_view_draw);
        _a.func_step = method(_a, coop_arms_view_step);
        _a.func_destroy = method(_a, coop_arms_view_destroy);
        arms_holder = _a;
    }
    _a.sprite_index = _spr;
    _a.image_index = _img;
}

function coop_arms_view_draw()
{
    if (destroyed || !instance_exists(follow_id) || !sprite_exists(sprite_index))
    {
        exit;
    }
    draw_sprite_ext(sprite_index, image_index, follow_id.x, follow_id.y, follow_id.image_xscale, 1, 0, c_white, 1);
}

// End Step of the puppet: the smoke puff of a cigarette, like class_player_arms.
function coop_arms_view_step()
{
    if (destroyed || !instance_exists(follow_id) || sprite_index != s_arms_smoke || image_index <= 7 || image_index >= 12)
    {
        exit;
    }
    var _pc = obj_particles_controller;
    if (!instance_exists(_pc))
    {
        exit;
    }
    with (follow_id)
    {
        if (image_xscale > 0)
        {
            part_type_direction(_pc.particles_type[41], -10, 10, 0, 0);
        }
        else
        {
            part_type_direction(_pc.particles_type[41], 170, 190, 0, 0);
        }
        part_emitter_region(_pc.particles_system[41], _pc.partciles_emitter[41], x + (2 * image_xscale), x + (2 * image_xscale), y + 2, y + 2, 0, 1);
        part_emitter_burst(_pc.particles_system[41], _pc.partciles_emitter[41], _pc.particles_type[41], 1);
    }
}

function coop_arms_view_destroy()
{
    if (destroyed)
    {
        exit;
    }
    destroyed = true;
    with (follow_id)
    {
        if (arms_holder == other)
        {
            arms_holder = undefined;
        }
    }
}

// Partner started using an item: its sound at the puppet.
function coop_puppet_on_arms(_b)
{
    var _item = buffer_read(_b, buffer_string);
    var _p = coop_puppet_of(coop().msg_from);
    if (!instance_exists(_p) || !item_exists(_item))
    {
        exit;
    }
    var _snd = item_consumable_get_sound(_item);
    if (audio_exists(_snd))
    {
        with (_p)
        {
            audio_emitter_position(emitter_walk, x, y, 0);
            audio_play_sound_on(emitter_walk, _snd, false, 6);
        }
    }
}

// class_player_weapon End Step on the puppet: the weapon pose comes from the network instead of the local
// camera (weapon inspection) and local recoil. true = handled.
function coop_weapon_net_end_step(_w)
{
    var _p = _w.follow_id;
    if (!instance_exists(_p) || _p.object_index != obj_player_puppet || !variable_instance_exists(_p, "coop_w"))
    {
        return false;
    }
    var _n = _p.coop_w;
    // the loadout may arrive after the first state (latency): no weapon drawn until it is a real weapon
    _w.is_visible = item_exists(_p.arma_now) && item_get_category(_p.arma_now) == "weapon" && sprite_exists(item_get_sprite_ingame(_p.arma_now) ?? -1);
    _w.x = _p.x + _n[0];
    _w.y = _p.y + _n[1];
    _w.image_angle = _n[2];
    _w.image_xscale = _n[3];
    _w.image_yscale = 0.4;
    _w.draw_before_follow = _n[4];
    return true;
}

function coop_puppet_on_loadout(_b)
{
    var _json = buffer_read(_b, buffer_string);
    var _data = json_parse(_json);
    var _c = coop();
    var _peer = coop_peer(_c.msg_from);
    if (is_struct(_peer))
    {
        _peer.loadout = _data;
    }
    var _p = coop_puppet_of(_c.msg_from);
    if (instance_exists(_p) && _p.object_index == obj_player_puppet)
    {
        coop_puppet_apply_loadout(_p, _data);
    }
}

function coop_puppet_apply_loadout(_p, _data)
{
    with (_p)
    {
        arma_now = _data.arma_now;
        armor_now = _data.armor_now;
        backpack_now = _data.backpack_now;
        headset_now = _data.headset_now;
        weapon_slot_now = _data.weapon_slot_now;
        if (!is_struct(loot_in_slot))
        {
            loot_in_slot = {};
        }
        var _w1 = coop_struct_to_loot(_data.w1);
        var _w2 = coop_struct_to_loot(_data.w2);
        if (_w1 != undefined) variable_struct_set(loot_in_slot, "weapon slot 1", _w1);
        if (_w2 != undefined) variable_struct_set(loot_in_slot, "weapon slot 2", _w2);
        sprite_idle = item_armor_get_s_idle(armor_now);
        sprite_run = item_armor_get_s_run(armor_now);
        sprite_dead = item_armor_get_s_dead(armor_now);
    }
}

// Replaces obj_player_puppet Step: follow the network state, never read local input.
function coop_puppet_step()
{
    if (!variable_instance_exists(id, "coop_net_x"))
    {
        exit;
    }
    var _d = point_distance(x, y, coop_net_x, coop_net_y);
    if (_d > 96)
    {
        x = coop_net_x;
        y = coop_net_y;
    }
    else
    {
        x = lerp(x, coop_net_x, 0.35);
        y = lerp(y, coop_net_y, 0.35);
    }
    depth = -y;
    player_step_update_building_exit();
    coop_puppet_footsteps();
    if (torch_on_general || laser_on_general || coop_lights_were_on)
    {
        // torch/laser attachment positions on the partner's own weapon (mods come with the loadout)
        coop_lights_were_on = torch_on_general || laser_on_general;
        try
        {
            player_update_weapon_torch();
            player_update_weapon_laser();
        }
        catch (_e)
        {
            torch_on_general = false;
            laser_on_general = false;
        }
    }
}

// Name tag + hp bar above the partner (Draw event of obj_coop, world space).
function coop_puppet_draw_tag()
{
    with (obj_player_puppet)
    {
        draw_set_halign(fa_center);
        draw_set_valign(fa_bottom);
        draw_set_font(-1);
        var _name = variable_instance_exists(id, "coop_name") ? coop_name : "Partner";
        draw_text_transformed_colour(x, y - 22, _name, 0.35, 0.35, 0, c_white, c_white, c_white, c_white, 0.9);
        var _w = 16;
        var _k = clamp(coop_hp / max(1, coop_hp_max), 0, 1);
        draw_set_alpha(0.8);
        draw_rectangle_colour(x - _w / 2, y - 20, x + _w / 2, y - 19, c_black, c_black, c_black, c_black, false);
        var _col = ((coop_flags & 2) != 0) ? c_red : c_lime;
        draw_rectangle_colour(x - _w / 2, y - 20, x - _w / 2 + _w * _k, y - 19, _col, _col, _col, _col, false);
        draw_set_alpha(1);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
    }
}

// Guest: start the raid next to the host (once, right after loading).
function coop_spawn_sync(_hx, _hy)
{
    var _c = coop();
    if (_c.role != "guest" || _c.spawn_synced || !instance_exists(obj_player))
    {
        exit;
    }
    if (obj_map_generator.state != 21 || !player_state_is(0, scr_player_state_move) || (_hx == 0 && _hy == 0))
    {
        exit;
    }
    _c.spawn_synced = true;
    if (point_distance(obj_player.x, obj_player.y, _hx, _hy) < 120)
    {
        exit;
    }
    // Nearest free spot around the host.
    for (var _r = 16; _r <= 64; _r += 8)
    {
        for (var _a = 0; _a < 360; _a += 45)
        {
            var _nx = _hx + lengthdir_x(_r, _a);
            var _ny = _hy + lengthdir_y(_r, _a);
            with (obj_player)
            {
                if (!place_meeting(_nx, _ny, obj_solid))
                {
                    x = _nx;
                    y = _ny;
                    coop_log("spawn synced next to host at ", floor(_nx), ",", floor(_ny));
                    return;
                }
            }
        }
    }
}

// Draw GUI (480x270): partner name + hp over everything (night darkness, roofs). Off screen: an edge marker
// pointing at them with the distance.
function coop_puppet_draw_tag_gui()
{
    if (!player_state_is(0, scr_player_state_move))
    {
        exit;
    }
    var _l = coop_puppets();
    for (var _i = 0; _i < array_length(_l); _i++)
    {
        coop_puppet_draw_tag_gui_one(_l[_i]);
    }
}

function coop_puppet_draw_tag_gui_one(_p)
{
    if (!instance_exists(_p) || !variable_instance_exists(_p, "coop_hp"))
    {
        exit;
    }
    var _cam = view_camera[0];
    var _vx = camera_get_view_x(_cam);
    var _vy = camera_get_view_y(_cam);
    var _vw = max(1, camera_get_view_width(_cam));
    var _vh = max(1, camera_get_view_height(_cam));
    var _gx = (_p.x - _vx) / _vw * 480;
    var _gy = (_p.y - _vy) / _vh * 270;
    var _name = variable_instance_exists(_p, "coop_name") ? _p.coop_name : "Partner";
    var _down = (_p.coop_flags & 2) != 0;
    var _col = _down ? c_red : c_lime;
    draw_set_halign(fa_center);
    draw_set_valign(fa_bottom);
    if (_gx >= 8 && _gx <= 472 && _gy >= 16 && _gy <= 262)
    {
        coop_text_outlined(_gx, _gy - 13, _name, c_white);
        var _w = 18;
        var _k = clamp(_p.coop_hp / max(1, _p.coop_hp_max), 0, 1);
        draw_rectangle_colour(_gx - _w / 2, _gy - 12, _gx + _w / 2, _gy - 11, c_black, c_black, c_black, c_black, false);
        draw_rectangle_colour(_gx - _w / 2, _gy - 12, _gx - _w / 2 + _w * _k, _gy - 11, _col, _col, _col, _col, false);
    }
    else
    {
        var _cx = clamp(_gx, 14, 466);
        var _cy = clamp(_gy, 24, 252);
        var _dir = point_direction(240, 135, _gx, _gy);
        var _m = floor(point_distance(obj_player.x, obj_player.y, _p.x, _p.y) / 16);
        draw_triangle_colour(_cx + lengthdir_x(6, _dir), _cy + lengthdir_y(6, _dir), _cx + lengthdir_x(4, _dir + 140), _cy + lengthdir_y(4, _dir + 140), _cx + lengthdir_x(4, _dir - 140), _cy + lengthdir_y(4, _dir - 140), _col, _col, _col, false);
        draw_set_valign(fa_middle);
        coop_text_outlined(clamp(_cx - lengthdir_x(14, _dir), 30, 450), _cy - lengthdir_y(10, _dir), _name + " " + string(_m) + coop_t("m", "м"), _col);
    }
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}

// ---- partner sounds (reload, bolt, unjam, torch click, footsteps...) ----

// Replaces audio_play_sound(snd, prio, false) in the local player's actions: same local sound, and the
// partner hears it at our puppet.
function coop_psound(_snd, _prio)
{
    var _h = audio_play_sound(_snd, _prio, false);
    coop_psound_send(_snd);
    return _h;
}

function coop_psound_send(_snd)
{
    try
    {
        var _c = coop();
        if (_c.connected && _c.peer_in_raid && coop_in_raid() && audio_exists(_snd))
        {
            var _b = coop_msg_begin(COOP_MSG_PSND);
            buffer_write(_b, buffer_u32, real(_snd));
            coop_msg_send(false);
        }
    }
    catch (_e)
    {
        coop_log("ERROR (recovered): psound ", _e.message);
    }
}

function coop_puppet_on_sound(_b)
{
    var _snd = buffer_read(_b, buffer_u32);
    var _p = coop_puppet_of(coop().msg_from);
    if (!instance_exists(_p) || !audio_exists(_snd))
    {
        exit;
    }
    with (_p)
    {
        audio_emitter_position(emitter_walk, x, y, 0);
        audio_play_sound_on(emitter_walk, _snd, false, 10);
    }
    if (coop().test_mode)
    {
        coop_log("psound from partner: ", audio_get_name(_snd));
    }
}

// Puppet footsteps: same cadence and ground sounds as the local player (scr_player_movement).
function coop_puppet_footsteps()
{
    if (sprite_index != sprite_run)
    {
        exit;
    }
    if (!variable_instance_exists(id, "coop_walk_time"))
    {
        coop_walk_time = 0;
    }
    coop_walk_time++;
    if (coop_walk_time >= 28)
    {
        coop_walk_time = 0;
        audio_emitter_position(emitter_walk, x, y, 0);
        scr_choose_footstep_sound(1);
        if (coop().test_mode && coop().scenario == "anim")
        {
            coop_log("puppet footstep");
        }
    }
}
