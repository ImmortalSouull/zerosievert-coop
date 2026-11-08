// ZERO Sievert co-op: raid events (2.0.0 item 43; only with 2+ players in the raid).
// The raid owner, some minutes into a shared raid, places a survivor (a loner NPC who can't be hurt; its AI never runs)
// 40-75 m from the group and tells everybody: "Someone needs help" with a mark on the screen edge and the PDA map.
// E next to the survivor takes the job, one of three: hold out against 3 waves of bandits / clear the bandits
// around / kill a commander and his guards. When the owner sees every event enemy dead, a small reward bag appears
// at the survivor (a modest one for waves and clearing, a better one for the commander). Owner-side only: enemies and
// the bag reach the others as usual (NPC replicas, a dropped bag).

#macro COOP_MSG_EVENT 83
#macro COOP_EVENT_RANGE 48

function coop_ev()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "ev"))
    {
        _c.ev = { state: "none", type: 0, x: 0, y: 0, wave: 0, waves: 0, npcs: [], giver: -4, t_at: -1, accept_t: 0 };
    }
    return _c.ev;
}

// coop_summary_reset (raid start)
function coop_events_reset()
{
    var _e = coop_ev();
    _e.state = "none";
    _e.npcs = [];
    _e.giver = -4;
    _e.t_at = -1;
}

function coop_event_text(_type)
{
    switch (_type)
    {
        case 1: return coop_t("Bandits hold the area around me - clear them out", "Бандиты засели вокруг - зачистите их");
        case 2: return coop_t("Their commander is close - take him and his guards down", "Их командир рядом - уберите его и охрану");
    }
    return coop_t("They are coming back - help me hold this place (3 waves)", "Они возвращаются - помогите удержать место (3 волны)");
}

function coop_event_send(_op, _a, _b)
{
    var _m = coop_msg_begin(COOP_MSG_EVENT);
    buffer_write(_m, buffer_u8, _op);
    buffer_write(_m, buffer_u8, _a);
    buffer_write(_m, buffer_u8, _b);
    var _e = coop_ev();
    buffer_write(_m, buffer_f32, _e.x);
    buffer_write(_m, buffer_f32, _e.y);
    coop_msg_send(true);
}

// obj_coop Step
function coop_events_step()
{
    var _c = coop();
    var _e = coop_ev();
    if (!coop_shared_ready() || !instance_exists(obj_player))
    {
        exit;
    }
    // everybody: E at the survivor takes the job
    if (_e.state == "offered" && point_distance(obj_player.x, obj_player.y, _e.x, _e.y) < COOP_EVENT_RANGE
        && (keyboard_check_pressed(ord("E")) || coop_pad_pressed(gp_face3) || (_c.test_mode && variable_struct_exists(_c, "sim_event_e"))))
    {
        if (variable_struct_exists(_c, "sim_event_e")) variable_struct_remove(_c, "sim_event_e");
        if (coop_is_world_owner()) coop_event_start(); else coop_event_send(1, 0, 0);
    }
    if (!coop_is_world_owner())
    {
        exit;
    }
    // owner: schedule once per raid, only with teammates in it
    if (_e.state == "none")
    {
        if (_e.t_at < 0)
        {
            var _fast = _c.test_mode && _c.scenario == "event";
            _e.t_at = current_time + (_fast ? 8000 : irandom_range(180, 420) * 1000);
        }
        if (current_time >= _e.t_at && coop_events_players_in_raid() >= 2)
        {
            coop_event_offer();
        }
        exit;
    }
    // the event area stays simulated even with nobody looking (the game suspends NPCs outside the cameras)
    if (_e.state == "active")
    {
        instance_activate_region(_e.x - 520, _e.y - 400, 1040, 800, true);
    }
    // the survivor stays put and unhurt
    if (instance_exists(_e.giver))
    {
        _e.giver.x = _e.x;
        _e.giver.y = _e.y;
        _e.giver.hp = max(_e.giver.hp, 1);
    }
    if (_e.state == "active" && _c.frame mod 30 == 0)
    {
        var _alive = 0;
        for (var _i = 0; _i < array_length(_e.npcs); _i++)
        {
            instance_activate_object(_e.npcs[_i]);
            // one that wandered far off (90 m) no longer holds the event up
            if (instance_exists(_e.npcs[_i]) && _e.npcs[_i].hp > 0 && point_distance(_e.npcs[_i].x, _e.npcs[_i].y, _e.x, _e.y) < 1440) _alive++;
        }
        if (_c.test_mode && _c.frame mod 600 == 0)
        {
            var _hl = "";
            for (var _i = 0; _i < array_length(_e.npcs); _i++) _hl += instance_exists(_e.npcs[_i]) ? string(floor(_e.npcs[_i].hp)) + " " : "x ";
            coop_log("event: alive ", _alive, " hp ", _hl);
        }
        if (_alive == 0)
        {
            if (_e.type == 0 && _e.wave < _e.waves)
            {
                coop_event_spawn_wave();
            }
            else
            {
                coop_event_finish();
            }
        }
    }
}

function coop_events_players_in_raid()
{
    var _n = 1;
    var _ps = coop_peers();
    for (var _k = 0; _k < COOP_MAX_PLAYERS; _k++)
    {
        if (_k != coop().slot && is_struct(_ps[_k]) && _ps[_k].connected && _ps[_k].in_raid) _n++;
    }
    return _n;
}

// A free spot 40-75 m from the group, inside the map.
function coop_event_find_spot()
{
    var _cx = obj_player.x;
    var _cy = obj_player.y;
    var _mh = instance_exists(obj_map_generator) ? obj_map_generator.map_height : room_height;
    repeat (60)
    {
        var _d = irandom_range(640, 1200);
        var _a = irandom(359);
        var _x = _cx + lengthdir_x(_d, _a);
        var _y = _cy + lengthdir_y(_d, _a);
        if (_x < 320 || _y < 320 || _x > room_width - 320 || _y > _mh - 320) continue;
        if (collision_rectangle(_x - 24, _y - 24, _x + 24, _y + 24, obj_solid, false, true) == noone)
        {
            return [_x, _y];
        }
    }
    return undefined;
}

function coop_event_offer()
{
    var _e = coop_ev();
    var _p = coop_event_find_spot();
    if (_p == undefined)
    {
        _e.t_at = current_time + 30000; // try again later
        exit;
    }
    _e.x = _p[0];
    _e.y = _p[1];
    _e.type = irandom(2);
    if (coop().test_mode && variable_struct_exists(coop(), "event_type")) _e.type = coop().event_type;
    _e.giver = instance_create_depth(_e.x, _e.y, -_e.y, obj_loner_enemy);
    with (_e.giver)
    {
        faction = "All Friend";
        can_be_damaged = false;
        coop_event_giver = true;
        // no AI at all (it walked around on the owner while the others saw it standing): run it like a replica,
        // which keeps its idle animation and holds it at coop_tx/coop_ty
        coop_replica = true;
        coop_replica_frame = -1;
        coop_tx = x;
        coop_ty = y;
    }
    _e.state = "offered";
    coop_log("event: offered type ", _e.type, " at ", floor(_e.x), ",", floor(_e.y));
    coop_event_send(0, _e.type, 0);
    coop_event_notify_offer();
}

function coop_event_notify_offer()
{
    coop_notify(coop_t("Someone needs help - follow the SOS mark", "Кому-то нужна помощь - идите к метке SOS"));
}

function coop_event_start()
{
    var _e = coop_ev();
    if (_e.state != "offered")
    {
        exit;
    }
    _e.state = "active";
    _e.npcs = [];
    _e.wave = 0;
    _e.waves = (_e.type == 0) ? 3 : 1;
    coop_log("event: accepted, type ", _e.type);
    coop_event_spawn_wave();
}

// Enemies 14-19 m from the survivor, where the AI sees the players.
function coop_event_spawn_wave()
{
    var _e = coop_ev();
    _e.wave++;
    _e.npcs = [];
    var _count = (_e.type == 1) ? 6 : 3;
    for (var _i = 0; _i < _count; _i++)
    {
        var _obj = (_e.type == 2 && _i == 0) ? obj_green_army_soldier1 : obj_enemy_human_bandit_novice;
        var _x = _e.x;
        var _y = _e.y;
        repeat (30)
        {
            var _a = irandom(359);
            var _d = irandom_range(230, 300);
            _x = _e.x + lengthdir_x(_d, _a);
            _y = _e.y + lengthdir_y(_d, _a);
            if (collision_rectangle(_x - 10, _y - 10, _x + 10, _y + 10, obj_solid, false, true) == noone) break;
        }
        var _n = instance_create_depth(_x, _y, -_y, _obj);
        _n.coop_event_npc = true; // known to the others too: a new raid owner picks the event up (coop_events_on_take_over)
        if (_e.type == 2 && _i == 0)
        {
            // the commander: five times the health (NPCs get their hp in Create, npc_setup)
            _n.hp *= 5;
            _n.coop_event_boss = true;
            coop_log("event: commander hp ", _n.hp);
        }
        array_push(_e.npcs, _n);
    }
    coop_log("event: wave ", _e.wave, "/", _e.waves, ", ", _count, " enemies");
    coop_event_send(2, _e.type, _e.wave);
    coop_event_notify_wave(_e.type, _e.wave, _e.waves);
}

function coop_event_notify_wave(_type, _wave, _waves)
{
    if (_type == 0)
    {
        coop_notify(coop_tf("Event: wave {0} of 3", "Событие: волна {0} из 3", _wave));
    }
    else if (_wave == 1)
    {
        coop_notify(coop_event_text(_type));
    }
}

function coop_event_finish()
{
    var _e = coop_ev();
    _e.state = "done";
    var _items = (_e.type == 2)
        ? [["medikit_2", 1], ["ammo_545x39", 60], ["bandage_military", 2], ["ak_74", 1]]
        : [[choose("ammo_9x18", "ammo_545x39", "ammo_762x39"), 30], [choose("bandage", "medikit_1"), 1], [choose("bread", "water_bottle", "canned_beans"), 1]];
    var _loots = [];
    var _grid = new class_loot_grid(8, 11);
    for (var _i = 0; _i < array_length(_items); _i++)
    {
        if (!item_exists(_items[_i][0])) continue;
        var _pos = _grid.TryPlace(_items[_i][0]);
        var _l = new class_loot(_items[_i][0], _items[_i][1], is_struct(_pos) ? _pos.x * 16 : 0, is_struct(_pos) ? _pos.y * 16 : 0, 0, "other inventory");
        array_push(_loots, _l);
    }
    _grid.Destroy();
    var _bag = instance_create_depth(_e.x + 12, _e.y + 6, -_e.y, obj_chest_general);
    _bag.tipo = "discard";
    db_open("all loot");
    db_write("chest_" + string(_bag.id), "chest_x", _bag.x);
    db_write("chest_" + string(_bag.id), "chest_y", _bag.y);
    db_write("chest_" + string(_bag.id), "items", _loots);
    db_close();
    coop_log("event: done, reward bag with ", array_length(_loots), " stacks");
    coop_event_send(3, _e.type, 0);
    coop_notify(coop_t("Event complete - the survivor left you supplies", "Событие выполнено - выживший оставил вам припасы"));
}

function coop_events_on_msg(_b)
{
    var _c = coop();
    var _e = coop_ev();
    var _op = buffer_read(_b, buffer_u8);
    var _a = buffer_read(_b, buffer_u8);
    var _w = buffer_read(_b, buffer_u8);
    var _x = buffer_read(_b, buffer_f32);
    var _y = buffer_read(_b, buffer_f32);
    switch (_op)
    {
        case 0:
            _e.state = "offered";
            _e.type = _a;
            _e.x = _x;
            _e.y = _y;
            coop_log("event: offered by the owner at ", floor(_x), ",", floor(_y));
            coop_event_notify_offer();
            break;
        case 1:
            if (coop_is_world_owner())
            {
                coop_log("event: slot ", _c.msg_from, " took the job");
                coop_event_start();
            }
            break;
        case 2:
            _e.state = "active";
            _e.type = _a;
            _e.wave = _w;
            _e.waves = (_a == 0) ? 3 : 1;
            coop_log("event: wave ", _w, " from the owner");
            coop_event_notify_wave(_a, _w, (_a == 0) ? 3 : 1);
            break;
        case 3:
            _e.state = "done";
            coop_log("event: done (owner)");
            coop_notify(coop_t("Event complete - the survivor left you supplies", "Событие выполнено - выживший оставил вам припасы"));
            break;
    }
}

// coop_npc_take_over: we run the raid's world now (the owner left): the event goes on here - our replica of the
// survivor stays without AI, and the enemies of the running wave count again.
function coop_events_on_take_over()
{
    var _e = coop_ev();
    if (_e.state != "offered" && _e.state != "active") exit;
    var _giver = -4;
    var _npcs = [];
    with (obj_npc_parent)
    {
        if (variable_instance_exists(id, "coop_event_giver") && coop_event_giver) _giver = id;
        else if (variable_instance_exists(id, "coop_event_npc") && coop_event_npc && hp > 0) array_push(_npcs, id);
    }
    _e.giver = _giver;
    if (instance_exists(_giver))
    {
        _giver.coop_tx = _e.x;
        _giver.coop_ty = _e.y;
    }
    if (_e.state == "active")
    {
        _e.npcs = _npcs;
        if (_e.waves <= 0) _e.waves = (_e.type == 0) ? 3 : 1;
        _e.wave = max(1, _e.wave);
    }
    coop_log("event: taken over (", _e.state, ", wave ", _e.wave, "/", _e.waves, ", ", array_length(_npcs), " enemies, survivor ", instance_exists(_giver), ")");
}

// Draw GUI: the SOS mark (edge arrow off screen) and the "E - talk" prompt next to the survivor.
function coop_events_draw()
{
    var _e = coop_ev();
    if ((_e.state != "offered" && _e.state != "active") || !instance_exists(obj_player) || !coop_in_raid())
    {
        exit;
    }
    var _gx = coop_ui_world_x(_e.x);
    var _gy = coop_ui_world_y(_e.y);
    coop_ui_font(COOP_F_SMALL);
    var _m = floor(point_distance(obj_player.x, obj_player.y, _e.x, _e.y) / 16);
    if (_gx >= 32 && _gx <= COOP_GW - 32 && _gy >= 64 && _gy <= COOP_GH - 32)
    {
        draw_set_halign(fa_center);
        if (_e.state == "offered")
        {
            if (_m * 16 < COOP_EVENT_RANGE) coop_ui_prompt(_gx, _gy - 120, "E", coop_t("Talk", "Говорить"));
            else coop_ui_text_ol(_gx, _gy - 100, "SOS", c_red);
        }
        draw_set_halign(fa_left);
    }
    else
    {
        coop_ui_edge_arrow(_gx, _gy, "SOS " + string(_m) + coop_t("m", "м"), c_red);
    }
}
