// ZERO Sievert co-op: character appearance (2.0.0 item 25).
// Two choices on the co-op panel's Appearance page (coop_local.ini): the body worn without armor (the game's own
// player sprites: survivor, two other men, three scientists) and a clothes tint (8 colours, also over armor). The
// body reaches teammates by itself (they draw the sprite we send); the tint travels with the loadout message.

function coop_look_bodies()
{
    // [idle, run, english name, russian name]
    return [[s_pg1_idle, s_pg1_run, "Survivor", "Выживший"], [s_pg_m1_idle, s_pg_m1_run, "Stalker", "Сталкер"],
        [s_pg_m3_idle, s_pg_m3_run, "Drifter", "Бродяга"], [s_pg_scientist_1_idle, s_pg_scientist_1_run, "Scientist", "Учёный"],
        [s_pg_scientist_2_idle, s_pg_scientist_2_run, "Lab assistant", "Лаборант"], [s_pg_scientist_3_idle, s_pg_scientist_3_run, "Researcher", "Исследователь"]];
}

function coop_look_tints()
{
    // [colour, english, russian]; c_white = none
    return [[c_white, "none", "нет"], [make_colour_rgb(120, 150, 90), "olive", "олива"], [make_colour_rgb(90, 110, 160), "navy", "синий"],
        [make_colour_rgb(160, 80, 70), "rust", "ржавчина"], [make_colour_rgb(150, 140, 110), "sand", "песок"], [make_colour_rgb(90, 90, 90), "black", "чёрный"],
        [make_colour_rgb(110, 160, 150), "teal", "бирюза"], [make_colour_rgb(150, 100, 150), "plum", "слива"]];
}

function coop_look()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "look"))
    {
        ini_open("coop_local.ini");
        _c.look = { body: clamp(ini_read_real("look", "body", 0), 0, 5), tint: clamp(ini_read_real("look", "tint", 0), 0, 7) };
        ini_close();
    }
    return _c.look;
}

function coop_look_save()
{
    var _l = coop_look();
    ini_open("coop_local.ini");
    ini_write_real("look", "body", _l.body);
    ini_write_real("look", "tint", _l.tint);
    ini_close();
    coop_send_loadout();
}

function coop_look_label(_what)
{
    var _l = coop_look();
    if (_what == "body")
    {
        var _b = coop_look_bodies();
        return coop_t("Body (without armor): ", "Тело (без брони): ") + coop_t(_b[_l.body][2], _b[_l.body][3]);
    }
    var _t = coop_look_tints();
    return coop_t("Clothes tint: ", "Оттенок одежды: ") + coop_t(_t[_l.tint][1], _t[_l.tint][2]);
}

// The blend colour drawn over a character (a mild tint, never a full recolour).
function coop_look_blend(_tint)
{
    var _t = coop_look_tints();
    return (_tint <= 0 || _tint >= array_length(_t)) ? c_white : merge_colour(c_white, _t[_tint][0], 0.45);
}

// obj_coop End Step: our body without armor and our tint; teammates' tints.
function coop_look_end_step()
{
    var _l = coop_look();
    var _b = coop_look_bodies();
    if (instance_exists(obj_player))
    {
        with (obj_player)
        {
            // the game gives an unarmored player the survivor sprites (item_armor_get_s_idle)
            if (sprite_idle == s_pg1_idle || sprite_idle == _b[1][0] || sprite_idle == _b[2][0] || sprite_idle == _b[3][0] || sprite_idle == _b[4][0] || sprite_idle == _b[5][0])
            {
                sprite_idle = _b[_l.body][0];
                sprite_move = _b[_l.body][1];
                if (sprite_index == s_pg1_idle || sprite_index == s_pg1_run)
                {
                    sprite_index = (sprite_index == s_pg1_idle) ? sprite_idle : sprite_move;
                }
            }
            image_blend = coop_look_blend(_l.tint);
        }
    }
    with (obj_player_puppet)
    {
        image_blend = coop_look_blend(variable_instance_exists(id, "coop_tint") ? coop_tint : 0);
    }
}
