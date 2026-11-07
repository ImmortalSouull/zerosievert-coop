// ZERO Sievert co-op: connection indicator (2.0.0 item 11).
// Every ping (once a second, coop_net_step) is remembered per peer; a pong marks it answered. Loss = pings older
// than 2 s that got no answer, over the last 20 s (round trip, so it counts losses in both directions).
// Shown under the co-op status line: always / only when a link is bad / off (local setting, coop_local.ini).

#macro COOP_CONN_BAD_PING 200
#macro COOP_CONN_BAD_LOSS 5
#macro COOP_CONN_SILENT_MS 2500

function coop_conn_mode()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "conn_mode"))
    {
        ini_open("coop_local.ini");
        _c.conn_mode = clamp(ini_read_real("coop", "conn_indicator", 1), 0, 2); // 0 always, 1 problems, 2 off
        ini_close();
    }
    return _c.conn_mode;
}

function coop_conn_mode_label()
{
    switch (coop_conn_mode())
    {
        case 0: return coop_t("always", "всегда");
        case 1: return coop_t("only on problems", "только при проблемах");
    }
    return coop_t("off", "выключен");
}

function coop_conn_cycle()
{
    var _c = coop();
    _c.conn_mode = (coop_conn_mode() + 1) mod 3;
    ini_open("coop_local.ini");
    ini_write_real("coop", "conn_indicator", _c.conn_mode);
    ini_close();
}

// coop_net_step, right after a ping went out to _to (a slot or COOP_ALL on the host).
function coop_conn_on_ping_sent(_to, _t)
{
    var _ps = coop_peers();
    for (var _k = 0; _k < COOP_MAX_PLAYERS; _k++)
    {
        var _p = _ps[_k];
        if (!is_struct(_p) || !_p.connected || (_to != COOP_ALL && _to != _k) || _k == coop().slot)
        {
            continue;
        }
        if (!variable_struct_exists(_p, "ping_hist")) _p.ping_hist = [];
        array_push(_p.ping_hist, { t: _t, ok: false });
        if (array_length(_p.ping_hist) > 20) array_delete(_p.ping_hist, 0, 1);
    }
}

// PONG from _p for the ping sent at _t.
function coop_conn_on_pong(_p, _t)
{
    if (!is_struct(_p) || !variable_struct_exists(_p, "ping_hist"))
    {
        exit;
    }
    var _h = _p.ping_hist;
    for (var _i = array_length(_h) - 1; _i >= 0; _i--)
    {
        if (_h[_i].t == _t)
        {
            _h[_i].ok = true;
            break;
        }
    }
}

// { ping, loss (%), silent (ms since anything arrived), bad }
function coop_conn_quality(_p)
{
    var _n = 0;
    var _lost = 0;
    if (variable_struct_exists(_p, "ping_hist"))
    {
        var _h = _p.ping_hist;
        for (var _i = 0; _i < array_length(_h); _i++)
        {
            if (current_time - _h[_i].t > 2000)
            {
                _n++;
                if (!_h[_i].ok) _lost++;
            }
        }
    }
    var _loss = (_n > 0) ? round(_lost * 100 / _n) : 0;
    var _silent = current_time - _p.last_recv;
    // the first seconds after connecting measure the handshake, not the link
    var _settled = _n >= 3;
    return { ping: round(_p.ping), loss: _loss, silent: _silent,
        bad: (_settled && (_p.ping > COOP_CONN_BAD_PING || _loss >= COOP_CONN_BAD_LOSS)) || _silent > COOP_CONN_SILENT_MS };
}

// The peers whose link we measure: the host measures every guest, a guest only the host.
function coop_conn_lines()
{
    var _c = coop();
    var _out = [];
    var _mode = coop_conn_mode();
    if (!_c.connected || _mode == 2)
    {
        return _out;
    }
    var _ps = coop_peers();
    for (var _k = 0; _k < COOP_MAX_PLAYERS; _k++)
    {
        var _p = _ps[_k];
        if (_k == _c.slot || !is_struct(_p) || !_p.connected || (_c.role == "guest" && _k != 0))
        {
            continue;
        }
        var _q = coop_conn_quality(_p);
        if (_mode == 1 && !_q.bad)
        {
            continue;
        }
        var _txt = coop_ui_fit(_p.name, 220) + ": " + string(_q.ping) + coop_t(" ms", " мс")
            + coop_tf(", loss {0}%", ", потери {0}%", _q.loss);
        if (_q.silent > COOP_CONN_SILENT_MS)
        {
            _txt += coop_tf(" - no data for {0} s", " - нет данных {0} с", _q.silent div 1000);
        }
        var _col = !_q.bad ? COOP_C_GREEN : ((_q.silent > COOP_CONN_SILENT_MS || _q.loss >= 20 || _q.ping > 400) ? COOP_C_RED : COOP_C_KEY);
        array_push(_out, { slot: _k, text: _txt, col: _col, bad: _q.bad });
    }
    return _out;
}

// Draw GUI, under the status line. Returns the new y.
function coop_conn_draw(_x, _y)
{
    var _l = coop_conn_lines();
    var _c = coop();
    for (var _i = 0; _i < array_length(_l); _i++)
    {
        var _h = string_height("A") + 6;
        var _w = string_width(_l[_i].text) + 34;
        coop_ui_rect(_x, _y, _x + _w, _y + _h, c_black, 0.55);
        // signal bars: 3 green, 2 yellow, 1 red
        var _bars = (_l[_i].col == COOP_C_GREEN) ? 3 : ((_l[_i].col == COOP_C_KEY) ? 2 : 1);
        for (var _b = 0; _b < 3; _b++)
        {
            var _bh = 4 + _b * 4;
            coop_ui_rect(_x + 6 + _b * 6, _y + _h - 4 - _bh, _x + 10 + _b * 6, _y + _h - 4, (_b < _bars) ? _l[_i].col : COOP_C_INNER);
        }
        coop_ui_text(_x + 28, _y + 3, _l[_i].text, _l[_i].col);
        if (_c.test_mode && _l[_i].bad && !variable_struct_exists(_c, "conn_bad_logged"))
        {
            _c.conn_bad_logged = true;
            coop_log("conn: problem shown: ", _l[_i].text);
        }
        _y += _h + 3;
    }
    return _y;
}

// test mode: the measured link every 10 s
function coop_conn_step()
{
    var _c = coop();
    if (_c.test_mode && _c.scenario == "conn" && _c.connected)
    {
        _c.conn_t = (variable_struct_exists(_c, "conn_t") ? _c.conn_t : 0) + 1;
        if (_c.conn_t == 1300) screen_save("conn_" + _c.tag + ".png");
        if (_c.conn_t == 1320) coop_log("conn: test done");
    }
    if (!_c.test_mode || !_c.connected || _c.frame mod 600 != 0)
    {
        exit;
    }
    var _ps = coop_peers();
    for (var _k = 0; _k < COOP_MAX_PLAYERS; _k++)
    {
        if (_k != _c.slot && is_struct(_ps[_k]) && _ps[_k].connected)
        {
            var _q = coop_conn_quality(_ps[_k]);
            coop_log("conn: slot ", _k, " ping ", _q.ping, " loss ", _q.loss, "% silent ", _q.silent, " bad ", _q.bad);
        }
    }
}
