// ZERO Sievert co-op: voice chat (2.0.0 item 48).
// The microphone is read with GameMaker's audio recording (16 kHz, 16 bit, mono; obj_coop Async - Audio
// Recording). While transmitting (hold C, or always with "open mic"), every second sample is mu-law coded (8 kHz,
// 8 bit: about 8 KB/s) and sent to everybody (unreliable, the host relays). Each speaker plays through a queue of its
// own; its volume follows the distance between the two characters: up to 10 m full, 20 m half, 30 m quiet, further
// nothing. A radio on the same channel (1..8) is heard at any distance (two pairs of players can split up on
// different channels and don't hear each other).

#macro COOP_MSG_VOICE 82
// the push-to-talk key: C
#macro COOP_VOICE_KEY 67
#macro COOP_VOICE_PACKET 800

function coop_voice()
{
    var _c = coop();
    if (!variable_struct_exists(_c, "voice"))
    {
        _c.voice = { rec: -1, tx: false, out: buffer_create(COOP_VOICE_PACKET, buffer_fixed, 1), out_n: 0,
            spk: array_create(COOP_MAX_PLAYERS, undefined), level: 0 };
        ini_open("coop_local.ini");
        _c.voice.mode = clamp(ini_read_real("voice", "mode", 1), 0, 2); // 0 off, 1 push to talk, 2 open mic
        _c.voice.channel = clamp(ini_read_real("voice", "radio", 0), 0, 8); // 0 = radio off
        ini_close();
    }
    return _c.voice;
}

function coop_voice_save()
{
    var _v = coop_voice();
    ini_open("coop_local.ini");
    ini_write_real("voice", "mode", _v.mode);
    ini_write_real("voice", "radio", _v.channel);
    ini_close();
}

function coop_voice_mode_label()
{
    switch (coop_voice().mode)
    {
        case 0: return coop_t("off", "выключен");
        case 2: return coop_t("open mic", "микрофон всегда включён");
    }
    return coop_t("hold C to talk", "говорить, удерживая C");
}

function coop_voice_channel_label()
{
    var _ch = coop_voice().channel;
    return (_ch == 0) ? coop_t("off", "выключена") : coop_tf("channel {0}", "частота {0}", _ch);
}

// ---- sending ----

// obj_coop Step
function coop_voice_step()
{
    var _c = coop();
    var _v = coop_voice();
    if (!_c.connected || _v.mode == 0)
    {
        _v.tx = false;
        exit;
    }
    _v.tx = (_v.mode == 2) || (keyboard_check(COOP_VOICE_KEY) && !coop_chat_is_open());
    if (_v.tx) _v.tx_t = current_time;
    // the microphone is open only while it is needed (push to talk: from the key press to 1 s after release)
    var _need = (_v.mode == 2) || (variable_struct_exists(_v, "tx_t") && current_time - _v.tx_t < 1000);
    if (_need && _v.rec < 0 && audio_get_recorder_count() > 0)
    {
        _v.rec = audio_start_recording(0);
        var _info = audio_get_recorder_info(0);
        coop_log("voice: microphone on (", ds_map_find_value(_info, "name"), ")");
    }
    else if (!_need && _v.rec >= 0)
    {
        audio_stop_recording(_v.rec);
        _v.rec = -1;
        coop_log("voice: microphone off");
    }
    if (_c.test_mode && variable_struct_exists(_c, "voice_test_tone"))
    {
        // test: a 440 Hz tone instead of the microphone, 100 ms per 6 ticks
        _v.tx = true;
        if (_c.frame mod 6 == 0)
        {
            var _b = buffer_create(3200, buffer_fixed, 1);
            for (var _i = 0; _i < 1600; _i++)
            {
                buffer_write(_b, buffer_s16, round(8000 * sin(2 * pi * 440 * (_c.voice_test_tone + _i) / 16000)));
            }
            _c.voice_test_tone += 1600;
            coop_voice_feed(_b, 3200);
            buffer_delete(_b);
        }
    }
    coop_voice_gains();
}

// obj_coop Async - Audio Recording
function coop_voice_on_recording()
{
    var _v = coop_voice();
    if (ds_map_find_value(async_load, "channel_index") != _v.rec)
    {
        exit;
    }
    coop_voice_feed(ds_map_find_value(async_load, "buffer_id"), ds_map_find_value(async_load, "data_len"));
}

// 16 kHz s16 samples in, mu-law 8 kHz packets out.
function coop_voice_feed(_buf, _len)
{
    var _v = coop_voice();
    if (!_v.tx)
    {
        _v.out_n = 0;
        exit;
    }
    var _n = _len div 2;
    var _peak = 0;
    for (var _i = 0; _i < _n; _i += 2)
    {
        var _s = buffer_peek(_buf, _i * 2, buffer_s16);
        _peak = max(_peak, abs(_s));
        buffer_poke(_v.out, _v.out_n, buffer_u8, coop_ulaw_encode(_s));
        _v.out_n++;
        if (_v.out_n >= COOP_VOICE_PACKET)
        {
            coop_voice_send();
        }
    }
    _v.level = _peak;
}

function coop_voice_send()
{
    var _c = coop();
    var _v = coop_voice();
    var _b = coop_msg_begin(COOP_MSG_VOICE);
    buffer_write(_b, buffer_u8, _v.channel);
    buffer_write(_b, buffer_u16, _v.out_n);
    buffer_copy(_v.out, 0, _v.out_n, _b, buffer_tell(_b));
    buffer_seek(_b, buffer_seek_relative, _v.out_n);
    coop_msg_send(false);
    _v.out_n = 0;
    _v.sent = (variable_struct_exists(_v, "sent") ? _v.sent : 0) + 1;
    if (_c.test_mode && _v.sent mod 20 == 1) coop_log("voice: sent packet ", _v.sent);
}

// ---- receiving ----

function coop_voice_on_msg(_b)
{
    var _c = coop();
    var _v = coop_voice();
    var _ch = buffer_read(_b, buffer_u8);
    var _n = buffer_read(_b, buffer_u16);
    var _from = _c.msg_from;
    if (_v.mode == 0 || _from < 0 || _from >= COOP_MAX_PLAYERS || _n == 0)
    {
        exit;
    }
    var _s = _v.spk[_from];
    if (!is_struct(_s))
    {
        _s = { q: audio_create_play_queue(buffer_s16, 8000, audio_mono), inst: -1, bufs: [], ch: 0, t: 0, got: 0 };
        _v.spk[_from] = _s;
    }
    _s.ch = _ch;
    _s.t = current_time;
    _s.got += _n;
    var _pcm = buffer_create(_n * 2, buffer_fixed, 1);
    var _pos = buffer_tell(_b);
    for (var _i = 0; _i < _n; _i++)
    {
        buffer_write(_pcm, buffer_s16, coop_ulaw_decode(buffer_peek(_b, _pos + _i, buffer_u8)));
    }
    array_push(_s.bufs, _pcm);
    audio_queue_sound(_s.q, _pcm, 0, _n * 2);
    if (_s.inst < 0 || !audio_is_playing(_s.inst))
    {
        _s.inst = audio_play_sound(_s.q, 20, false);
        audio_sound_gain(_s.inst, coop_voice_gain(_from), 0);
    }
    if (_c.test_mode && _s.got mod 16000 < _n) coop_log("voice: got ", _s.got, " samples from slot ", _from, " gain ", coop_voice_gain(_from));
}

// obj_coop Async - Audio Playback: a queued buffer was played, free it.
function coop_voice_on_playback()
{
    var _v = coop_voice();
    var _q = ds_map_find_value(async_load, "queue_id");
    var _buf = ds_map_find_value(async_load, "buffer_id");
    for (var _k = 0; _k < COOP_MAX_PLAYERS; _k++)
    {
        var _s = _v.spk[_k];
        if (is_struct(_s) && _s.q == _q)
        {
            var _i = array_get_index(_s.bufs, _buf);
            if (_i >= 0)
            {
                array_delete(_s.bufs, _i, 1);
                buffer_delete(_buf);
            }
        }
    }
}

// How loud slot _k is for us: distance between the characters, or the radio.
function coop_voice_gain(_k)
{
    var _v = coop_voice();
    var _s = _v.spk[_k];
    var _g = 0;
    var _p = coop_puppet_of(_k);
    if (instance_exists(_p) && instance_exists(obj_player))
    {
        var _m = point_distance(obj_player.x, obj_player.y, _p.x, _p.y) / 16;
        _g = (_m <= 10) ? 1 : ((_m <= 20) ? 0.5 : ((_m <= 30) ? 0.2 : 0));
    }
    else if (!coop_in_raid() && !is_in_hub())
    {
        _g = 1; // both in menus: plain voice
    }
    if (is_struct(_s) && _s.ch != 0 && _s.ch == _v.channel)
    {
        _g = max(_g, 0.8); // same radio channel: any distance
    }
    return _g;
}

function coop_voice_gains()
{
    var _v = coop_voice();
    for (var _k = 0; _k < COOP_MAX_PLAYERS; _k++)
    {
        var _s = _v.spk[_k];
        if (is_struct(_s) && _s.inst >= 0 && audio_is_playing(_s.inst))
        {
            audio_sound_gain(_s.inst, coop_voice_gain(_k), 100);
        }
    }
}

// Speaking right now (for the name tags / group panel).
function coop_voice_speaking(_k)
{
    var _v = coop_voice();
    var _s = _v.spk[_k];
    return is_struct(_s) && current_time - _s.t < 300 && coop_voice_gain(_k) > 0;
}

// ---- mu-law (G.711) ----

function coop_ulaw_encode(_s)
{
    var _sign = (_s < 0) ? 128 : 0;
    var _m = min(abs(_s), 32635) + 132;
    var _exp = 7;
    var _mask = 16384;
    while (_exp > 0 && (_m & _mask) == 0)
    {
        _exp--;
        _mask = _mask >> 1;
    }
    var _mant = (_m >> (_exp + 3)) & 15;
    return (~(_sign | (_exp << 4) | _mant)) & 255;
}

function coop_ulaw_decode(_u)
{
    _u = (~_u) & 255;
    var _sign = _u & 128;
    var _exp = (_u >> 4) & 7;
    var _mant = _u & 15;
    var _m = (((_mant << 3) + 132) << _exp) - 132;
    return _sign ? -_m : _m;
}
