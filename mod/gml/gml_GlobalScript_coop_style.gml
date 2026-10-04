// ZERO Sievert co-op: drawing helpers in the look of the game's own interface (inventory / PDA): dark grey
// panels with a black outline, a lighter header bar, inventory-like slots, key prompts in a framed black box,
// and the game's Munro language fonts. Everything is drawn in the game's UI space of 1920x1080.

#macro COOP_GW 1920
#macro COOP_GH 1080
// Colours (BGR): edge #141414, panel #2b2b2b, inner #3c3c3c, header #333333, slot #3d3d3d, selected slot #5b5b5b,
// text #e9e9e9, dim #9a9a9a, key yellow #f3c847, red #cc3333, green #4fbf4e. No comments after a #macro: build.csx
// expands it textually.
// Font sizes (indices into global.language_fonts) for small text (tags, captions, prompts) and body text.
#macro COOP_F_SMALL 3
#macro COOP_F_BODY 4
#macro COOP_C_EDGE 1315860
#macro COOP_C_PANEL 2829099
#macro COOP_C_INNER 3947580
#macro COOP_C_HEADER 3355443
#macro COOP_C_SLOT 4013373
#macro COOP_C_SLOT_HI 5987163
#macro COOP_C_TEXT 15329769
#macro COOP_C_DIM 10132122
#macro COOP_C_KEY 4704499
#macro COOP_C_RED 3355596
#macro COOP_C_GREEN 5160783

// Start drawing in the 1920x1080 UI space. _size: 0 = 8px, 1 = 16px, 2 = 12px, 3 = 24px, 4 = 32px, 5 = 64px.
function coop_ui_begin(_size)
{
    display_set_gui_size(COOP_GW, COOP_GH);
    coop_ui_font(_size);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1);
}

function coop_ui_font(_size)
{
    if (variable_global_exists("language_fonts") && is_array(global.language_fonts) && _size < array_length(global.language_fonts) && font_exists(global.language_fonts[_size]))
    {
        language_set_font(_size);
    }
    else
    {
        draw_set_font(-1);
    }
}

function coop_ui_end()
{
    draw_set_font(-1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1);
    display_set_gui_size(COOP_GW, COOP_GH);
}

function coop_ui_rect(_x1, _y1, _x2, _y2, _col, _alpha = 1)
{
    draw_set_alpha(_alpha);
    draw_rectangle_colour(_x1, _y1, _x2, _y2, _col, _col, _col, _col, false);
    draw_set_alpha(1);
}

// A window: black outline, dark fill, thin inner border; optional header bar with a centred title.
// Returns the y where the content starts.
function coop_ui_panel(_x1, _y1, _x2, _y2, _title = "")
{
    coop_ui_rect(_x1 - 4, _y1 - 4, _x2 + 4, _y2 + 4, COOP_C_EDGE, 0.95);
    coop_ui_rect(_x1, _y1, _x2, _y2, COOP_C_PANEL, 0.97);
    draw_set_colour(COOP_C_INNER);
    draw_rectangle(_x1 + 6, _y1 + 6, _x2 - 6, _y2 - 6, true);
    if (_title == "")
    {
        return _y1 + 14;
    }
    coop_ui_rect(_x1 + 10, _y1 + 10, _x2 - 10, _y1 + 54, COOP_C_INNER);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    coop_ui_text((_x1 + _x2) / 2, _y1 + 32, _title, COOP_C_TEXT);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    return _y1 + 66;
}

// An inventory-like slot (selected: lighter, with a yellow frame).
function coop_ui_slot(_x1, _y1, _x2, _y2, _selected)
{
    coop_ui_rect(_x1 - 2, _y1 - 2, _x2 + 2, _y2 + 2, COOP_C_EDGE);
    coop_ui_rect(_x1, _y1, _x2, _y2, _selected ? COOP_C_SLOT_HI : COOP_C_SLOT);
    if (_selected)
    {
        draw_set_colour(COOP_C_KEY);
        draw_rectangle(_x1, _y1, _x2, _y2, true);
        draw_rectangle(_x1 + 1, _y1 + 1, _x2 - 1, _y2 - 1, true);
    }
}

function coop_ui_text(_x, _y, _s, _col)
{
    draw_text_colour(_x, _y, _s, _col, _col, _col, _col, 1);
}

// Text over the world (night, roofs): with a 2px black outline.
function coop_ui_text_ol(_x, _y, _s, _col)
{
    draw_text_colour(_x - 2, _y, _s, c_black, c_black, c_black, c_black, 1);
    draw_text_colour(_x + 2, _y, _s, c_black, c_black, c_black, c_black, 1);
    draw_text_colour(_x, _y - 2, _s, c_black, c_black, c_black, c_black, 1);
    draw_text_colour(_x, _y + 2, _s, c_black, c_black, c_black, c_black, 1);
    draw_text_colour(_x, _y, _s, _col, _col, _col, _col, 1);
}

// A key prompt like the game's "[L Ctrl] Quick move": black box, light frame, yellow key, white text.
// _ax: 0 = left, 1 = centre, 2 = right aligned at _x.
function coop_ui_prompt(_x, _y, _key, _text, _ax = 1)
{
    var _k = (_key == "") ? "" : ("[" + _key + "] ");
    var _w = string_width(_k + _text) + 24;
    var _h = string_height("A") + 12;
    var _x1 = _x - ((_ax == 1) ? _w / 2 : ((_ax == 2) ? _w : 0));
    coop_ui_rect(_x1, _y, _x1 + _w, _y + _h, c_black, 0.9);
    draw_set_colour(COOP_C_TEXT);
    draw_rectangle(_x1, _y, _x1 + _w, _y + _h, true);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    coop_ui_text(_x1 + 12, _y + 6, _k, COOP_C_KEY);
    coop_ui_text(_x1 + 12 + string_width(_k), _y + 6, _text, COOP_C_TEXT);
    return _h;
}

// A thin bar (HP, timers).
function coop_ui_bar(_x1, _y1, _w, _h, _k, _col)
{
    coop_ui_rect(_x1 - 2, _y1 - 2, _x1 + _w + 2, _y1 + _h + 2, c_black, 0.85);
    if (_k > 0)
    {
        coop_ui_rect(_x1, _y1, _x1 + _w * clamp(_k, 0, 1), _y1 + _h, _col);
    }
}

// World position -> UI space.
function coop_ui_world_x(_wx)
{
    var _cam = view_camera[0];
    return (_wx - camera_get_view_x(_cam)) / max(1, camera_get_view_width(_cam)) * COOP_GW;
}

function coop_ui_world_y(_wy)
{
    var _cam = view_camera[0];
    return (_wy - camera_get_view_y(_cam)) / max(1, camera_get_view_height(_cam)) * COOP_GH;
}

// Mouse in UI space (see coop_gui_mouse_x for why it is not device_mouse_x_to_gui).
function coop_ui_mouse_x()
{
    return coop_gui_mouse_x() * 4;
}

function coop_ui_mouse_y()
{
    return coop_gui_mouse_y() * 4;
}

// Item icon fitted into a box (inventory sprite).
function coop_ui_item_icon(_item, _cx, _cy, _box)
{
    var _spr = item_exists(_item) ? item_get_sprite_inv(_item) : -1;
    if (!sprite_exists(_spr))
    {
        return false;
    }
    var _w = sprite_get_width(_spr);
    var _h = sprite_get_height(_spr);
    var _s = floor(min(_box / max(1, _w), _box / max(1, _h)) * 2) / 2;
    _s = max(0.5, _s);
    var _ox = sprite_get_xoffset(_spr);
    var _oy = sprite_get_yoffset(_spr);
    draw_sprite_ext(_spr, 0, _cx - (_w / 2 - _ox) * _s, _cy - (_h / 2 - _oy) * _s, _s, _s, 0, c_white, 1);
    return true;
}
