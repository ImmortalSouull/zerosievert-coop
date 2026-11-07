// ZERO Sievert co-op: trading between two players (2.0.0 item 13).
// U next to a teammate asks for a trade; the teammate accepts with U (15 s). A window shows your inventory (click a
// stack to offer it / take it back) and the teammate's offer. Both press Ready; ready counts only for the exact
// offers on both sides (a signature of both lists), so changing anything un-readies both. When both are ready each
// side takes its offered stacks out of its inventory and sends them; received stacks go into the inventory
// (coop_give_receive_pending: when the inventory screen is closed, a bag at your feet if it is full).

#macro COOP_MSG_TRADE 81
#macro COOP_TRADE_KEY 85
#macro COOP_TRADE_RANGE 120

function coop_trade()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "trade"))
    {
        _c.trade = { state: "none", slot: -1, t: 0, offer: [], theirs: [], ready: false, their_sig: "", done: false, opts: [] };
    }
    return _c.trade;
}

function coop_trade_send(_slot, _op, _text)
{
    var _b = coop_msg_begin(COOP_MSG_TRADE);
    buffer_write(_b, buffer_u8, _op);
    buffer_write(_b, buffer_string, _text);
    coop_msg_send_to(_slot, true);
}

// what is shown to the other side (and signed)
function coop_trade_offer_data(_tr)
{
    var _out = [];
    for (var _i = 0; _i < array_length(_tr.offer); _i++)
    {
        var _l = _tr.offer[_i];
        array_push(_out, { item: _l.item, quantity: _l.quantity, durability: variable_struct_exists(_l, "durability") ? _l.durability : 100 });
    }
    return _out;
}

// The same stack (the inventory is read again every frame: compare contents, not references).
function coop_trade_same(_a, _b)
{
    return is_struct(_a) && is_struct(_b) && _a.item == _b.item
        && (variable_struct_exists(_a, "quantity") ? _a.quantity : 1) == (variable_struct_exists(_b, "quantity") ? _b.quantity : 1)
        && (variable_struct_exists(_a, "x") ? _a.x : 0) == (variable_struct_exists(_b, "x") ? _b.x : 0)
        && (variable_struct_exists(_a, "y") ? _a.y : 0) == (variable_struct_exists(_b, "y") ? _b.y : 0);
}

function coop_trade_find(_arr, _loot)
{
    for (var _i = 0; _i < array_length(_arr); _i++)
    {
        if (coop_trade_same(_arr[_i], _loot)) return _i;
    }
    return -1;
}

function coop_trade_sig(_list)
{
    return md5_string_utf8(json_stringify(_list));
}

function coop_trade_both_sig(_tr)
{
    return coop_trade_sig(coop_trade_offer_data(_tr)) + "|" + coop_trade_sig(_tr.theirs);
}

function coop_trade_close(_why)
{
    var _tr = coop_trade();
    if (_tr.state != "none")
    {
        coop_log("trade closed: ", _why);
    }
    _tr.state = "none";
    _tr.offer = [];
    _tr.theirs = [];
    _tr.ready = false;
    _tr.their_sig = "";
    _tr.done = false;
}

function coop_trade_nearest()
{
    var _best = -1;
    var _bd = COOP_TRADE_RANGE;
    var _l = coop_puppets();
    for (var _i = 0; _i < array_length(_l); _i++)
    {
        var _d = point_distance(obj_player.x, obj_player.y, _l[_i].x, _l[_i].y);
        if (_d < _bd) { _bd = _d; _best = _l[_i].coop_slot; }
    }
    return _best;
}

// obj_coop Step
function coop_trade_step()
{
    var _c = coop();
    var _tr = coop_trade();
    if (!_c.connected || !instance_exists(obj_player) || !(coop_in_raid() || is_in_hub()))
    {
        if (_tr.state != "none") coop_trade_close("left");
        exit;
    }
    var _key = keyboard_check_pressed(COOP_TRADE_KEY) && !coop_chat_is_open() && !(variable_struct_exists(_c, "panel") && _c.panel);
    if (variable_struct_exists(_c, "sim_trade_key")) { _key = true; variable_struct_remove(_c, "sim_trade_key"); } // panel button / tests
    switch (_tr.state)
    {
        case "none":
            if (_key)
            {
                var _s = coop_trade_nearest();
                if (_s >= 0)
                {
                    _tr.state = "asked";
                    _tr.slot = _s;
                    _tr.t = current_time;
                    coop_trade_send(_s, 0, "");
                    coop_notify(coop_tf("Trade offered to {0}", "Обмен предложен: {0}", coop_peer_name(_s)));
                    coop_log("trade: asked slot ", _s);
                }
            }
            break;
        case "incoming":
            if (current_time - _tr.t > 15000)
            {
                coop_trade_close("not accepted");
            }
            else if (_key)
            {
                _tr.state = "open";
                coop_trade_send(_tr.slot, 1, "");
                coop_log("trade: accepted slot ", _tr.slot);
            }
            break;
        case "asked":
            if (current_time - _tr.t > 16000)
            {
                coop_notify(coop_t("No answer to the trade", "Нет ответа на обмен"));
                coop_trade_close("no answer");
            }
            break;
        case "open":
            if (keyboard_check_pressed(vk_escape) || !instance_exists(coop_puppet_of(_tr.slot)))
            {
                keyboard_clear(vk_escape);
                coop_trade_send(_tr.slot, 4, "");
                coop_trade_close("cancelled by us");
                exit;
            }
            coop_trade_input();
            // both ready on the same offers: hand over ours
            if (_tr.ready && !_tr.done && _tr.their_sig == coop_trade_both_sig_theirs_view(_tr))
            {
                coop_trade_commit();
            }
            break;
    }
}

// the signature as the other side computes it (their offer first)
function coop_trade_both_sig_theirs_view(_tr)
{
    return coop_trade_sig(_tr.theirs) + "|" + coop_trade_sig(coop_trade_offer_data(_tr));
}

function coop_trade_set_ready(_on)
{
    var _tr = coop_trade();
    _tr.ready = _on;
    coop_trade_send(_tr.slot, 3, _on ? coop_trade_both_sig(_tr) : "");
}

function coop_trade_offer_changed()
{
    var _tr = coop_trade();
    _tr.ready = false;
    coop_trade_send(_tr.slot, 2, json_stringify(coop_trade_offer_data(_tr)));
}

// Hand our offer over: out of our inventory, to the teammate.
function coop_trade_commit()
{
    var _c = coop();
    var _tr = coop_trade();
    _tr.done = true;
    var _db = inventory_target_db();
    db_open(_db);
    var _arr = db_read("Inventory", "items", []);
    var _send = [];
    for (var _i = 0; _i < array_length(_tr.offer); _i++)
    {
        var _k = coop_trade_find(_arr, _tr.offer[_i]);
        if (_k >= 0)
        {
            array_push(_send, coop_loot_to_struct(loot_duplicate(_arr[_k])));
            array_delete(_arr, _k, 1);
        }
    }
    db_write("Inventory", "items", _arr);
    db_close();
    coop_trade_send(_tr.slot, 5, json_stringify(_send));
    coop_log("trade: sent ", array_length(_send), " stacks to slot ", _tr.slot);
    coop_notify(coop_tf("Trade with {0} done", "Обмен с {0} завершён", coop_peer_name(_tr.slot)));
    if (_tr.state == "open" && variable_struct_exists(_tr, "got") && _tr.got) coop_trade_close("done");
}

function coop_trade_on_msg(_b)
{
    var _c = coop();
    var _tr = coop_trade();
    var _op = buffer_read(_b, buffer_u8);
    var _text = buffer_read(_b, buffer_string);
    var _from = _c.msg_from;
    switch (_op)
    {
        case 0: // asked
            if (_tr.state == "none")
            {
                _tr.state = "incoming";
                _tr.slot = _from;
                _tr.t = current_time;
                coop_notify(coop_tf("{0} wants to trade - press U", "{0} предлагает обмен - нажмите U", coop_peer_name(_from)));
            }
            else
            {
                coop_trade_send(_from, 4, ""); // busy
            }
            break;
        case 1: // accepted
            if (_tr.state == "asked" && _tr.slot == _from)
            {
                _tr.state = "open";
                coop_log("trade: open with slot ", _from);
            }
            break;
        case 2: // their offer changed
            if (_tr.slot == _from)
            {
                _tr.theirs = json_parse(_text);
                _tr.ready = false;
                _tr.their_sig = "";
                coop_trade_send(_from, 3, "");
            }
            break;
        case 3: // their ready (signature of both offers, theirs first) or not ready ("")
            if (_tr.slot == _from)
            {
                _tr.their_sig = _text;
            }
            break;
        case 4: // cancelled
            if (_tr.slot == _from && _tr.state != "none")
            {
                coop_notify(coop_tf("{0} cancelled the trade", "{0} отменил обмен", coop_peer_name(_from)));
                coop_trade_close("cancelled by them");
            }
            break;
        case 5: // their stacks
            var _l = json_parse(_text);
            if (!variable_struct_exists(_c, "give_in")) _c.give_in = [];
            for (var _i = 0; _i < array_length(_l); _i++)
            {
                array_push(_c.give_in, json_stringify(_l[_i]));
            }
            coop_log("trade: got ", array_length(_l), " stacks from slot ", _from);
            _tr.got = true;
            if (_tr.done) coop_trade_close("done");
            break;
    }
}

// ---- window ----

function coop_trade_layout()
{
    return { x1: COOP_GW / 2 - 640, x2: COOP_GW / 2 + 640, y1: 170, y2: 900, row: 40 };
}

function coop_trade_input()
{
    var _c = coop();
    var _tr = coop_trade();
    _tr.opts = coop_give_options();
    // more than 14 stacks: the wheel scrolls the list
    if (!variable_struct_exists(_tr, "scroll")) _tr.scroll = 0;
    if (!variable_struct_exists(_tr, "sel")) _tr.sel = -1;
    _tr.scroll = clamp(_tr.scroll + mouse_wheel_down() - mouse_wheel_up(), 0, max(0, array_length(_tr.opts) - 14));
    // gamepad (item 47): d-pad picks a stack, A offers / takes it back, Y ready, B cancel
    var _np = array_length(_tr.opts);
    if (coop_pad_pressed(gp_padd)) _tr.sel = min(_np - 1, _tr.sel + 1);
    if (coop_pad_pressed(gp_padu)) _tr.sel = max(0, _tr.sel - 1);
    if (_tr.sel >= 0)
    {
        if (_tr.sel < _tr.scroll) _tr.scroll = _tr.sel;
        if (_tr.sel >= _tr.scroll + 14) _tr.scroll = _tr.sel - 13;
    }
    if (coop_pad_pressed(gp_face1) && _tr.sel >= 0 && _tr.sel < _np)
    {
        var _pl = _tr.opts[_tr.sel].loot;
        var _pk = coop_trade_find(_tr.offer, _pl);
        if (_pk >= 0) array_delete(_tr.offer, _pk, 1); else array_push(_tr.offer, _pl);
        coop_trade_offer_changed();
    }
    if (coop_pad_pressed(gp_face4)) coop_trade_set_ready(!_tr.ready);
    if (coop_pad_pressed(gp_face2))
    {
        coop_trade_send(_tr.slot, 4, "");
        coop_trade_close("cancelled by us");
        exit;
    }
    if (!mouse_check_button_pressed(mb_left) && !(_c.test_mode && variable_struct_exists(_c, "sim_trade_click")))
    {
        exit;
    }
    var _L = coop_trade_layout();
    var _mx = coop_ui_mouse_x();
    var _my = coop_ui_mouse_y();
    if (_c.test_mode && variable_struct_exists(_c, "sim_trade_click"))
    {
        var _sc = _c.sim_trade_click;
        variable_struct_remove(_c, "sim_trade_click");
        _mx = _sc[0];
        _my = _sc[1];
    }
    // my inventory rows (left)
    var _y0 = _L.y1 + 110;
    if (_mx > _L.x1 + 20 && _mx < (_L.x1 + _L.x2) / 2 - 10)
    {
        var _i = floor((_my - _y0) / _L.row);
        if (_i >= 0 && _i < 14) _i += _tr.scroll;
        if (_i >= _tr.scroll && _i < min(_tr.scroll + 14, array_length(_tr.opts)))
        {
            var _loot = _tr.opts[_i].loot;
            var _k = coop_trade_find(_tr.offer, _loot);
            if (_k >= 0) array_delete(_tr.offer, _k, 1); else array_push(_tr.offer, _loot);
            coop_trade_offer_changed();
            coop_log("trade: offer now ", array_length(_tr.offer), " stacks");
        }
    }
    // buttons
    var _by = _L.y2 - 70;
    if (_my > _by && _my < _by + 46)
    {
        if (_mx > _L.x1 + 40 && _mx < _L.x1 + 400) coop_trade_set_ready(!_tr.ready);
        if (_mx > _L.x2 - 400 && _mx < _L.x2 - 40)
        {
            coop_trade_send(_tr.slot, 4, "");
            coop_trade_close("cancelled by us");
        }
    }
}

function coop_trade_draw()
{
    var _tr = coop_trade();
    if (_tr.state != "open")
    {
        exit;
    }
    var _L = coop_trade_layout();
    coop_ui_font(COOP_F_BODY);
    var _y = coop_ui_panel(_L.x1, _L.y1, _L.x2, _L.y2, coop_tf("TRADE WITH {0}", "ОБМЕН С {0}", string_upper(coop_peer_name(_tr.slot))), COOP_PANEL_ALPHA);
    coop_ui_font(COOP_F_SMALL);
    var _mid = (_L.x1 + _L.x2) / 2;
    draw_set_halign(fa_center);
    coop_ui_text((_L.x1 + _mid) / 2, _y, coop_t("Your inventory - click to offer, wheel to scroll", "Ваш инвентарь - клик: предложить, колесо: листать"), COOP_C_DIM);
    coop_ui_text((_mid + _L.x2) / 2, _y, coop_tf("{0} offers", "{0} предлагает", coop_peer_name(_tr.slot)), COOP_C_DIM);
    draw_set_halign(fa_left);
    var _y0 = _L.y1 + 110;
    draw_set_valign(fa_middle);
    var _sc = variable_struct_exists(_tr, "scroll") ? _tr.scroll : 0;
    for (var _i = 0; _i < min(14, array_length(_tr.opts) - _sc); _i++)
    {
        var _o = _tr.opts[_i + _sc];
        var _on = coop_trade_find(_tr.offer, _o.loot) >= 0;
        var _ry = _y0 + _i * _L.row;
        coop_ui_slot(_L.x1 + 20, _ry + 2, _mid - 10, _ry + _L.row - 2, _on || (variable_struct_exists(_tr, "sel") && _tr.sel == _i + _sc), 0.85);
        coop_ui_item_icon_wh(_o.loot.item, _L.x1 + 52, _ry + _L.row / 2, 52, 30);
        coop_ui_text(_L.x1 + 90, _ry + _L.row / 2, coop_ui_fit(_o.name, _mid - _L.x1 - 130), _on ? COOP_C_KEY : COOP_C_TEXT);
    }
    for (var _i = 0; _i < min(14, array_length(_tr.theirs)); _i++)
    {
        var _e = _tr.theirs[_i];
        var _ry = _y0 + _i * _L.row;
        coop_ui_slot(_mid + 10, _ry + 2, _L.x2 - 20, _ry + _L.row - 2, false, 0.85);
        coop_ui_item_icon_wh(_e.item, _mid + 42, _ry + _L.row / 2, 52, 30);
        coop_ui_text(_mid + 80, _ry + _L.row / 2, coop_ui_fit(item_get_name(_e.item) + ((_e.quantity > 1) ? " x" + string(_e.quantity) : ""), _L.x2 - _mid - 120), COOP_C_TEXT);
    }
    draw_set_valign(fa_top);
    // ready states and buttons
    var _theirs_ready = _tr.their_sig != "" && _tr.their_sig == coop_trade_both_sig_theirs_view(_tr);
    var _by = _L.y2 - 70;
    draw_set_halign(fa_center);
    coop_ui_slot(_L.x1 + 40, _by, _L.x1 + 400, _by + 46, _tr.ready, 0.9);
    coop_ui_text(_L.x1 + 220, _by + 10, _tr.ready ? coop_t("Ready (click to undo)", "Готов (клик - отменить)") : coop_t("Ready", "Готов"), _tr.ready ? COOP_C_GREEN : COOP_C_TEXT);
    coop_ui_text(_mid, _by + 10, _theirs_ready ? coop_tf("{0} is ready", "{0} готов", coop_peer_name(_tr.slot)) : coop_tf("{0} is choosing...", "{0} выбирает...", coop_peer_name(_tr.slot)), _theirs_ready ? COOP_C_GREEN : COOP_C_DIM);
    coop_ui_slot(_L.x2 - 400, _by, _L.x2 - 40, _by + 46, false, 0.9);
    coop_ui_text(_L.x2 - 220, _by + 10, coop_t("Cancel [Esc]", "Отмена [Esc]"), COOP_C_TEXT);
    draw_set_halign(fa_left);
}
