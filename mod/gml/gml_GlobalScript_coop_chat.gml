// ZERO Sievert co-op: text chat (2.0.0 item 26).
// Enter opens a line at the bottom left (the game gets no input meanwhile, same as under the F7 panel), Enter sends,
// Esc cancels. Messages go to everybody (reliable, the host relays), shown above the hotbar in the sender's colour
// for 12 s; the last ones show again while typing.

#macro COOP_MSG_CHAT 71
#macro COOP_CHAT_MAX 120
#macro COOP_CHAT_SHOW_MS 12000

function coop_chat()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "chat"))
    {
        _c.chat = { open: false, text: "", lines: [], opened_frame: -1 };
    }
    return _c.chat;
}

function coop_chat_is_open()
{
    if (!variable_global_exists("coop_state")) return false;
    var _c = global.coop_state;
    return variable_struct_exists(_c, "chat") && _c.chat.open;
}

// obj_coop Step
function coop_chat_step()
{
    var _c = coop();
    var _ch = coop_chat();
    if (!_c.connected)
    {
        _ch.open = false;
        exit;
    }
    if (!_ch.open)
    {
        // opens only while playing (not in the inventory, a menu or the F7 panel)
        if (keyboard_check_pressed(vk_enter) && instance_exists(obj_player) && (coop_in_raid() || is_in_hub())
            && !(variable_struct_exists(_c, "panel") && _c.panel) && coop_status_local() == 0)
        {
            _ch.open = true;
            _ch.opened_frame = _c.frame;
            keyboard_string = "";
            keyboard_clear(vk_enter);
        }
        exit;
    }
    _ch.text = string_copy(keyboard_string, 1, COOP_CHAT_MAX);
    if (string_length(keyboard_string) > COOP_CHAT_MAX)
    {
        keyboard_string = _ch.text;
    }
    if (keyboard_check_pressed(vk_escape))
    {
        _ch.open = false;
        keyboard_clear(vk_escape); // no pause menu
        exit;
    }
    if (keyboard_check_pressed(vk_enter) && _c.frame != _ch.opened_frame)
    {
        _ch.open = false;
        keyboard_clear(vk_enter);
        var _t = _ch.text;
        if (string_length(string_replace_all(_t, " ", "")) > 0)
        {
            coop_chat_send(_t);
        }
    }
}

function coop_chat_send(_text)
{
    var _c = coop();
    var _b = coop_msg_begin(COOP_MSG_CHAT);
    buffer_write(_b, buffer_string, _text);
    coop_msg_send(true);
    coop_chat_add(max(0, _c.slot), coop_my_name(), _text);
}

function coop_chat_on_msg(_b)
{
    var _c = coop();
    var _text = string_copy(buffer_read(_b, buffer_string), 1, COOP_CHAT_MAX);
    coop_chat_add(_c.msg_from, coop_peer_name(_c.msg_from), _text);
}

function coop_chat_add(_slot, _name, _text)
{
    var _ch = coop_chat();
    array_push(_ch.lines, { slot: _slot, name: _name, text: _text, t: current_time });
    if (array_length(_ch.lines) > 8)
    {
        array_delete(_ch.lines, 0, 1);
    }
    coop_log("chat ", _name, ": ", _text);
}

// Draw GUI: bottom left, above the ammo counter.
function coop_chat_draw()
{
    var _c = coop();
    if (!_c.connected)
    {
        exit;
    }
    var _ch = coop_chat();
    coop_ui_font(COOP_F_SMALL);
    var _x = 16;
    var _y = COOP_GH - 220;
    var _lh = string_height("A") + 6;
    if (_ch.open)
    {
        var _line = _ch.text + (((current_time div 400) mod 2) ? "_" : " ");
        var _w = max(520, string_width(_line) + 24);
        coop_ui_rect(_x, _y, _x + _w, _y + _lh + 4, c_black, 0.7);
        coop_ui_rect(_x, _y, _x + 3, _y + _lh + 4, COOP_C_KEY);
        coop_ui_text(_x + 10, _y + 4, (_ch.text == "") ? coop_t("Say something... (Enter - send, Esc - cancel)", "Напишите сообщение... (Enter - отправить, Esc - отмена)") : _line,
            (_ch.text == "") ? COOP_C_DIM : COOP_C_TEXT);
    }
    _y -= 6;
    for (var _i = array_length(_ch.lines) - 1; _i >= 0; _i--)
    {
        var _l = _ch.lines[_i];
        var _age = current_time - _l.t;
        if (!_ch.open && _age > COOP_CHAT_SHOW_MS)
        {
            continue;
        }
        var _a = _ch.open ? 1 : clamp((COOP_CHAT_SHOW_MS - _age) / 600, 0, 1);
        _y -= _lh;
        var _nm = ((_l.slot == max(0, _c.slot)) ? coop_my_shown_name() : coop_peer_name(_l.slot)) + ": ";
        var _w2 = string_width(_nm) + string_width(_l.text) + 20;
        coop_ui_rect(_x, _y, _x + _w2, _y + _lh, c_black, 0.5 * _a);
        var _col = coop_slot_colour(_l.slot);
        draw_text_colour(_x + 8, _y + 3, _nm, _col, _col, _col, _col, _a);
        draw_text_colour(_x + 8 + string_width(_nm), _y + 3, _l.text, COOP_C_TEXT, COOP_C_TEXT, COOP_C_TEXT, COOP_C_TEXT, _a);
    }
}

