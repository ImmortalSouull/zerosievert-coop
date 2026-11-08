// ZERO Sievert co-op: the barman's co-op tasks (2.0.0 item 31).
// While more than one player is in the session (never solo, not even when hosting alone), the barman offers three
// group tasks (kill quests made with the game's quest structures): bandit sweep, mutant hunt, army patrol. They are
// added to his quest list in memory only, after the slots the game saves (the game reads back only its own number
// of slots, so a solo start never shows them). Everybody gets a notification when they become available. Rewards are
// split by each player's share of the work (coop_quests.gml).

#macro COOP_BARQ_IDS ["coop_q_bandits", "coop_q_mutants", "coop_q_army"]

function coop_barq_define()
{
    if (!variable_global_exists("quest_database") || variable_struct_exists(global.quest_database, "coop_q_bandits"))
    {
        exit;
    }
    var _defs = [
        ["coop_q_bandits", coop_t("Group task: bandit sweep", "Групповое задание: зачистка банд"),
            coop_t("Bandit gangs are getting bolder. Take your group and thin them out - 12 of them. Share the pay among you.", "Бандиты совсем обнаглели. Возьмите группу и проредите их - 12 человек. Плату поделите между собой."),
            ["bandit_novice", "bandit_regular", "bandit_rookie", "bandit_intermediate", "bandit_skilled", "bandit_expert", "bandit_veteran", "bandit_master", "bandit_boss_guard"], 12, 9000, 400, coop_t("Kill bandits", "Убить бандитов")],
        ["coop_q_mutants", coop_t("Group task: mutant hunt", "Групповое задание: охота на мутантов"),
            coop_t("Ghouls are nesting too close to the tracks. Clear 8 of them together.", "Гули гнездятся слишком близко к путям. Вместе уничтожьте 8 штук."),
            ["ghoul", "ghoul_2"], 8, 8000, 350, coop_t("Kill ghouls", "Убить гулей")],
        ["coop_q_army", coop_t("Group task: army patrol", "Групповое задание: армейский патруль"),
            coop_t("A Green Army patrol keeps robbing our people. Take out 6 soldiers - only as a group.", "Патруль Зелёной армии грабит наших. Уберите 6 солдат - только группой."),
            ["green_army_soldier", "green_army_rookie", "green_army_intermediate", "green_army_skilled", "green_army_expert"], 6, 12000, 500, coop_t("Kill Green Army soldiers", "Убить солдат Зелёной армии")]
    ];
    for (var _i = 0; _i < array_length(_defs); _i++)
    {
        var _d = _defs[_i];
        variable_struct_set(global.quest_database, _d[0], {
            id: _d[0], name: _d[1], experience: _d[6], reputation: 5, money: _d[5], faction: "Loners", daily: false,
            initial_item: [], rep_min: 0, quest_next: [], removable: true, text: _d[2],
            objective: [new quest_create_kill(_d[4], "", -1, _d[3], 0, _d[7])], reward: []
        });
    }
    coop_log("barman co-op tasks defined");
}

// The barman in the bunker (a quest giver whose speaker is "bar"), or noone.
function coop_barq_barman()
{
    var _b = -4;
    with (obj_npc_parent)
    {
        if (variable_instance_exists(id, "npc_speaker_id") && npc_speaker_id == "bar" && variable_instance_exists(id, "quest_array")) _b = id;
    }
    return _b;
}

function coop_barq_active(_q)
{
    for (var _i = 0; _i < 30; _i++)
    {
        if (global.quest_state[_i].id == _q) return true;
    }
    return false;
}

// obj_coop Step (bunker): offer while the group is together, take them back when alone.
function coop_barq_step()
{
    var _c = coop();
    if (!is_in_hub() || _c.frame mod 30 != 0)
    {
        exit;
    }
    var _bar = coop_barq_barman();
    if (!instance_exists(_bar))
    {
        exit;
    }
    coop_barq_define();
    var _group = _c.connected && coop_player_count() > 1;
    var _ids = COOP_BARQ_IDS;
    var _changed = false;
    for (var _i = 0; _i < array_length(_ids); _i++)
    {
        var _q = _ids[_i];
        var _k = array_get_index(_bar.quest_array, _q);
        if (_group && _k < 0 && !coop_barq_active(_q))
        {
            array_push(_bar.quest_array, _q); // after the saved slots
            _changed = true;
        }
        else if (!_group && _k >= 0 && !coop_barq_active(_q))
        {
            array_delete(_bar.quest_array, _k, 1);
            _changed = true;
        }
    }
    if (_changed)
    {
        coop_log("barman co-op tasks ", _group ? "offered" : "withdrawn", ", list ", array_length(_bar.quest_array));
    }
    if (_group && !(variable_struct_exists(_c, "barq_told") && _c.barq_told))
    {
        _c.barq_told = true;
        coop_notify(coop_t("The barman has group tasks for you", "У бармена есть задания для группы"));
    }
    if (!_group) _c.barq_told = false;
}

// ---- saves stay vanilla-safe (hooks [150] / [151]) ----

function coop_barq_is(_id)
{
    return is_string(_id) && string_copy(_id, 1, 7) == "coop_q_";
}

// quest_save: our group tasks never go into the game's quest slots (an empty slot instead).
function coop_quest_state_for_save(_i)
{
    try
    {
        if (coop_barq_is(global.quest_state[_i].id)) return new class_quest_state();
    }
    catch (_e)
    {
        coop_report_error(_e);
    }
    return global.quest_state[_i];
}

// quest_save (database "general" open): the active group tasks under their own key.
function coop_barq_save()
{
    try
    {
        var _out = [];
        for (var _i = 0; _i < 30; _i++)
        {
            if (coop_barq_is(global.quest_state[_i].id)) array_push(_out, SnapDeepCopy(global.quest_state[_i]));
        }
        db_write("coop", "barq", _out);
    }
    catch (_e)
    {
        coop_report_error(_e);
    }
}

// quest_load (database "general" open): definitions first, then the saved group tasks into free slots.
function coop_barq_load()
{
    try
    {
        coop_barq_define();
        var _l = db_read("coop", "barq", []);
        if (!is_array(_l)) exit;
        var _n = 0;
        for (var _k = 0; _k < array_length(_l); _k++)
        {
            var _s = SnapDeepCopy(_l[_k]);
            if (!is_struct(_s) || !coop_barq_is(_s.id) || coop_barq_active(_s.id)) continue;
            for (var _i = 0; _i < 30; _i++)
            {
                if (global.quest_state[_i].id == "")
                {
                    global.quest_state[_i] = _s;
                    _n++;
                    break;
                }
            }
        }
        if (_n > 0) coop_log("barman co-op tasks loaded: ", _n);
    }
    catch (_e)
    {
        coop_report_error(_e);
    }
}
