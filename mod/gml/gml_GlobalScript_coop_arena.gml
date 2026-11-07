// ZERO Sievert co-op: a safe arena in the bunker (2.0.0 item 33).
// The host starts it from the co-op panel (bunker, 2+ players there). It is the bunker's shooting range: the game
// spends no ammo there. Every player picks a loadout (own gear or a preset weapon, which goes into weapon slot 1
// only in memory - hook [148] puts the player's own weapon back before the game writes any save to disk, so nothing
// can be lost or gained). Bullets fly between the players (also in the bunker while the arena runs), a lethal hit is a
// frag: the victim is healed and put back at a spawn point. 3 minutes or 10 frags; at the end everybody gets their
// own weapon back and full health, and the scoreboard shows for a few seconds.

#macro COOP_MSG_ARENA 85
#macro COOP_ARENA_X1 1300
#macro COOP_ARENA_X2 1910
#macro COOP_ARENA_Y1 700
#macro COOP_ARENA_Y2 825
#macro COOP_ARENA_SECONDS 180
#macro COOP_ARENA_FRAGS 10

function coop_arena()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "arena"))
    {
        _c.arena = { on: false, pick: false, t_end: 0, frags: array_create(COOP_MAX_PLAYERS, 0), orig: undefined, swapped: false,
            last_hit: -1, board_t: 0 };
    }
    return _c.arena;
}

// [item, ammo item] presets
function coop_arena_presets()
{
    return [["makarov", "ammo_9x18"], ["pp19_bizon", "ammo_9x18"], ["ak_74", "ammo_545x39"], ["mp_133", "ammo_12x70"], ["mosin", "ammo_762x54R"]];
}

function coop_arena_on()
{
    if (!variable_global_exists("coop_state")) return false;
    var _c = global.coop_state;
    return variable_struct_exists(_c, "arena") && _c.arena.on && is_in_hub();
}

function coop_arena_can_start()
{
    var _c = coop();
    if (_c.role != "host" || !is_in_hub() || coop_arena().on) return false;
    var _n = 0;
    var _ps = coop_peers();
    for (var _k = 1; _k < COOP_MAX_PLAYERS; _k++)
    {
        if (is_struct(_ps[_k]) && _ps[_k].connected && coop_hub_peer_here(_k)) _n++;
    }
    return _n > 0;
}

function coop_arena_send(_op, _a, _b)
{
    var _m = coop_msg_begin(COOP_MSG_ARENA);
    buffer_write(_m, buffer_u8, _op);
    buffer_write(_m, buffer_u8, _a);
    buffer_write(_m, buffer_u8, _b);
    coop_msg_send(true);
}

// Host: panel button.
function coop_arena_start()
{
    coop_arena_send(0, 0, 0);
    coop_arena_begin();
}

function coop_arena_begin()
{
    var _a = coop_arena();
    _a.on = true;
    _a.pick = true;
    _a.t_end = current_time + COOP_ARENA_SECONDS * 1000;
    _a.frags = array_create(COOP_MAX_PLAYERS, 0);
    _a.board_t = 0;
    coop_log("arena: started");
    coop_notify(coop_t("Arena! Pick a loadout", "Арена! Выберите снаряжение"));
}

// The choice: -1 own gear, 0..4 a preset. Then into the range.
function coop_arena_pick(_choice)
{
    var _a = coop_arena();
    _a.pick = false;
    if (_choice >= 0)
    {
        var _pr = coop_arena_presets();
        coop_arena_give(_pr[_choice]);
    }
    coop_arena_respawn();
    coop_log("arena: picked ", _choice);
}

function coop_arena_respawn()
{
    if (!instance_exists(obj_player)) exit;
    repeat (40)
    {
        var _x = irandom_range(COOP_ARENA_X1, COOP_ARENA_X2);
        var _y = irandom_range(COOP_ARENA_Y1, COOP_ARENA_Y2);
        var _free = false;
        with (obj_player) _free = !place_meeting(_x, _y, obj_solid);
        if (_free)
        {
            obj_player.x = _x;
            obj_player.y = _y;
            break;
        }
    }
    with (obj_player) hp = hp_max;
}

// A preset weapon into weapon slot 1, in memory only (the save on disk keeps the own one: hook [148]).
function coop_arena_give(_preset)
{
    var _a = coop_arena();
    var _db = inventory_target_db();
    db_open(_db);
    var _arr = db_read("Inventory", "items", []);
    var _orig = undefined;
    for (var _i = array_length(_arr) - 1; _i >= 0; _i--)
    {
        if (is_struct(_arr[_i]) && _arr[_i].placement == "weapon slot 1")
        {
            _orig = coop_loot_to_struct(_arr[_i]);
            array_delete(_arr, _i, 1);
        }
    }
    var _l = new class_loot(_preset[0], 1, 0, 0, 0, "weapon slot 1");
    var _m = loot_mod_cont_create();
    loot_mod_cont_copy_from_default(_m, _preset[0]);
    _l.mods = _m;
    _l.durability = 100;
    _l.ammo_id = _preset[1];
    _l.ammo_quantity = 30;
    array_push(_arr, _l);
    db_write("Inventory", "items", _arr);
    db_close();
    _a.orig = is_struct(_orig) ? json_stringify(_orig) : "";
    _a.swapped = true;
    _a.slot_was = obj_player.weapon_slot_now;
    player_loadout_update();
    with (obj_player)
    {
        weapon_slot_now = 1;
        arma_now = _preset[0];
    }
    coop_send_loadout();
    coop_log("arena: preset ", _preset[0]);
}

// The own weapon back (end of the arena, a save about to be written, leaving the bunker).
function coop_arena_restore()
{
    var _a = coop_arena();
    if (!_a.swapped)
    {
        exit;
    }
    _a.swapped = false;
    var _db = inventory_target_db();
    db_open(_db);
    var _arr = db_read("Inventory", "items", []);
    for (var _i = array_length(_arr) - 1; _i >= 0; _i--)
    {
        if (is_struct(_arr[_i]) && _arr[_i].placement == "weapon slot 1") array_delete(_arr, _i, 1);
    }
    var _item = "no_item";
    if (_a.orig != "")
    {
        var _o = coop_struct_to_loot(json_parse(_a.orig));
        _item = _o.item;
        array_push(_arr, _o);
    }
    db_write("Inventory", "items", _arr);
    db_close();
    player_loadout_update();
    if (instance_exists(obj_player))
    {
        with (obj_player)
        {
            weapon_slot_now = variable_struct_exists(_a, "slot_was") ? _a.slot_was : 1;
            var _lw = player_loadout_get_loot(id, weapon_slot_now, false);
            arma_now = is_struct(_lw) ? _lw.item : "no_item";
        }
    }
    coop_send_loadout();
    coop_log("arena: own weapon back (", _item, ")");
}

// Hook [148]: top of db_force_save - never write the preset weapon into a save.
function coop_arena_before_save()
{
    try
    {
        coop_arena_restore();
    }
    catch (_e)
    {
        coop_report_error(_e);
    }
}

function coop_arena_end(_why)
{
    var _a = coop_arena();
    if (!_a.on) exit;
    _a.on = false;
    _a.pick = false;
    coop_arena_restore();
    with (obj_player) hp = hp_max;
    _a.board_t = current_time + 8000;
    coop_log("arena: ended (", _why, ") frags ", json_stringify(_a.frags));
}

// obj_coop Step
function coop_arena_step()
{
    var _c = coop();
    var _a = coop_arena();
    if (!_a.on)
    {
        exit;
    }
    if (!is_in_hub() || !_c.connected)
    {
        coop_arena_end("left the bunker");
        exit;
    }
    if (_a.pick)
    {
        // 1..5 a preset, 6 / Enter own gear
        for (var _k = 0; _k < 5; _k++) if (keyboard_check_pressed(ord(string(_k + 1)))) { coop_arena_pick(_k); exit; }
        if (keyboard_check_pressed(ord("6")) || keyboard_check_pressed(vk_enter)) coop_arena_pick(-1);
        if (_c.test_mode && variable_struct_exists(_c, "sim_arena_pick")) { var _p = _c.sim_arena_pick; variable_struct_remove(_c, "sim_arena_pick"); coop_arena_pick(_p); }
        exit;
    }
    if (_c.role == "host")
    {
        var _top = 0;
        for (var _k = 0; _k < COOP_MAX_PLAYERS; _k++) _top = max(_top, _a.frags[_k]);
        if (current_time > _a.t_end || _top >= COOP_ARENA_FRAGS)
        {
            coop_arena_send(2, 0, 0);
            coop_arena_end((_top >= COOP_ARENA_FRAGS) ? "frag limit" : "time");
        }
    }
}

// From coop_down_grim_reaper_inner: a lethal hit in the arena is a frag, not a death. true = handled.
function coop_arena_on_lethal()
{
    var _a = coop_arena();
    if (!coop_arena_on() || _a.pick)
    {
        return false;
    }
    var _killer = _a.last_hit;
    var _me = max(0, coop().slot);
    if (_killer >= 0 && _killer != _me) _a.frags[_killer]++;
    coop_arena_send(1, (_killer >= 0) ? _killer : 255, _me);
    coop_log("arena: frag by slot ", _killer, " on me");
    coop_arena_respawn();
    _a.last_hit = -1;
    return true;
}

function coop_arena_on_msg(_b)
{
    var _a = coop_arena();
    var _op = buffer_read(_b, buffer_u8);
    var _x = buffer_read(_b, buffer_u8);
    var _y = buffer_read(_b, buffer_u8);
    switch (_op)
    {
        case 0:
            if (is_in_hub()) coop_arena_begin();
            break;
        case 1:
            if (_x != 255 && _x < COOP_MAX_PLAYERS) _a.frags[_x]++;
            coop_log("arena: slot ", _x, " fragged slot ", _y);
            break;
        case 2:
            coop_arena_end("host");
            break;
    }
}

// Draw GUI: the loadout picker, the timer and frags, the scoreboard after the end.
function coop_arena_draw()
{
    var _a = coop_arena();
    var _c = coop();
    if (!_a.on && current_time > _a.board_t)
    {
        exit;
    }
    coop_ui_font(COOP_F_SMALL);
    draw_set_halign(fa_center);
    if (_a.on && _a.pick)
    {
        var _pr = coop_arena_presets();
        var _y = coop_ui_panel(COOP_GW / 2 - 420, 260, COOP_GW / 2 + 420, 700, coop_t("ARENA - LOADOUT", "АРЕНА - СНАРЯЖЕНИЕ"), COOP_PANEL_ALPHA);
        for (var _i = 0; _i < 5; _i++)
        {
            var _ry = _y + 10 + _i * 62;
            coop_ui_slot(COOP_GW / 2 - 380, _ry, COOP_GW / 2 + 380, _ry + 54, false, 0.9);
            coop_ui_item_icon_wh(_pr[_i][0], COOP_GW / 2 - 300, _ry + 27, 120, 40);
            coop_ui_text(COOP_GW / 2 + 60, _ry + 16, "[" + string(_i + 1) + "] " + item_get_name(_pr[_i][0]), COOP_C_TEXT);
        }
        coop_ui_text(COOP_GW / 2, _y + 330, coop_t("[6] / Enter - your own gear (no ammo is used in the range)", "[6] / Enter - своё снаряжение (в тире патроны не тратятся)"), COOP_C_DIM);
        draw_set_halign(fa_left);
        exit;
    }
    // frags of everybody, best first
    var _rows = [];
    var _ps = coop_peers();
    for (var _k = 0; _k < COOP_MAX_PLAYERS; _k++)
    {
        if (_k == max(0, _c.slot) || (is_struct(_ps[_k]) && _ps[_k].connected)) array_push(_rows, _k);
    }
    for (var _i = 0; _i < array_length(_rows); _i++)
    {
        for (var _j = _i + 1; _j < array_length(_rows); _j++)
        {
            if (_a.frags[_rows[_j]] > _a.frags[_rows[_i]]) { var _tmp = _rows[_i]; _rows[_i] = _rows[_j]; _rows[_j] = _tmp; }
        }
    }
    var _h = 50 + array_length(_rows) * 30;
    coop_ui_rect(COOP_GW / 2 - 220, 120, COOP_GW / 2 + 220, 120 + _h, c_black, 0.6);
    var _title = _a.on ? coop_tf("ARENA  {0}", "АРЕНА  {0}", string(max(0, ceil((_a.t_end - current_time) / 1000))) + coop_t(" s", " с")) : coop_t("ARENA RESULTS", "ИТОГИ АРЕНЫ");
    coop_ui_text(COOP_GW / 2, 128, _title, COOP_C_KEY);
    for (var _i = 0; _i < array_length(_rows); _i++)
    {
        var _k = _rows[_i];
        var _nm = (_k == max(0, _c.slot)) ? coop_my_shown_name() : coop_peer_name(_k);
        coop_ui_text(COOP_GW / 2, 160 + _i * 30, _nm + "   " + string(_a.frags[_k]), coop_slot_colour(_k));
    }
    draw_set_halign(fa_left);
}
