"""Co-op regression suite: runs every two-instance test scenario and prints a pass/fail table.

usage: python tools/regress.py [name ...]      (no names = all scenarios)
       python tools/regress.py --list
Extra args for every launch can be given with env COOP_REGRESS_ARGS (e.g. "-coop_netsim 150,3,40").
Logs of each run are kept in zerosievert-coop-work/regress/<timestamp>/<scenario>/.
The data.win under test must already be installed (tools/install_test.sh).
"""
import os, re, sys, time, shutil, subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK = os.path.join(os.path.dirname(ROOT), "zerosievert-coop-work")
SAVES = os.path.join(os.environ["LOCALAPPDATA"], "ZERO_Sievert")
BASH = r"C:\Program Files\Git\bin\bash.exe"
LOGS = {k: os.path.join(SAVES, f"coop_coop{k}.log") for k in "ABCDEFGH"}


def S(name, host, guest, done, checks, minutes=4, timeout=260, custom=None, need_identical=True, tags="", players=2):
    return dict(name=name, host=host, guest=guest, done=done, checks=checks, minutes=minutes,
                timeout=timeout, custom=custom, need_identical=need_identical, tags=tags, players=players)


def chest_md5_equal(logs):
    """Both players read identical content for the same container."""
    a = re.findall(r"scenario chest t=420 (\S+) len=\d+ md5=(\w+)", logs["A"])
    b = re.findall(r"scenario chest t=420 (\S+) len=\d+ md5=(\w+)", logs["B"])
    if not a or not b:
        return "no t=420 chest reads"
    return None if a[0] == b[0] else f"chest differs A={a[0]} B={b[0]}"


def chest3_equal(logs):
    """Three players read identical content for the container the host took an item from."""
    got = {k: re.findall(r"scenario chest t=420 (\S+) len=\d+ md5=(\w+)", logs[k]) for k in "ABC"}
    if any(not v for v in got.values()):
        return "missing t=420 chest reads: " + ",".join(k for k, v in got.items() if not v)
    vals = {k: v[0] for k, v in got.items()}
    return None if len(set(vals.values())) == 1 else f"chest differs {vals}"


def grouphp_ok(logs):
    """Group hp scaling doubles the enemies' hp on the host and the guest's replicas carry the same."""
    a = re.findall(r"v3: group hp factor=(\S+) npc hp sum=(\d+)", logs["A"])
    b = re.findall(r"v3: group hp factor=(\S+) npc hp sum=(\d+)", logs["B"])
    if not a or not b:
        return "no hp lines"
    if a[0][0] != "2" or b[0][0] != "2":
        return f"factor A={a[0][0]} B={b[0][0]}"
    return None if a[0][1] == b[0][1] else f"hp sum differs A={a[0][1]} B={b[0][1]}"


def files_ok(logs):
    """Each side reports the difference once (no fingerprint ping-pong)."""
    a, b = logs["A"].count("FILES DIFFER"), logs["B"].count("FILES DIFFER")
    return None if a == 1 and b == 1 else f"FILES DIFFER lines A={a} B={b} (expected 1 each)"


def ff_ok(logs):
    """A teammate's 40-damage bullet took more than 0 and at most half (friendly fire damage 0.5)."""
    m = re.findall(r"ff: host lost ([0-9.]+)", logs["A"])
    if not m:
        return "no ff line"
    lost = float(m[0])
    return None if 0 < lost <= 20.5 else f"host lost {lost} hp (expected 0 < x <= 20)"


def ownerjoin_ok(logs):
    """Slot 2 (whichever instance got it) stayed in the hub, then joined the raid slot 1 owns."""
    j = [k for k in "BC" if "ownerjoin: stays in the hub" in logs[k]]
    if len(j) != 1:
        return "no single player stayed in the hub"
    j = j[0]
    o = "C" if j == "B" else "B"
    need = [(j, r"train joins the raid of slot 1"),
            (j, r"maps identical with partner"), (j, r"ownerjoin: done owner=1 puppets=1"),
            (o, r"ownerjoin: owner paused, local_paused=1"), (o, r"ownerjoin: owner unpaused, owner=1 player=1")]
    miss = [f"{k}: /{rx}/" for k, rx in need if not re.search(rx, logs[k])]
    return ("missing " + ", ".join(miss)) if miss else None


def livechest_ok(logs):
    """The open container lost exactly the item the host took, on both machines."""
    out = []
    for k in "AB":
        a = re.findall(r"lc t=160 ui items=(\d+)", logs[k])
        b = re.findall(r"lc t=280 ui items=(\d+)", logs[k])
        if not a or not b:
            return f"{k}: missing lc lines"
        out.append((int(a[0]), int(b[0])))
    if out[0] != out[1] or out[0][1] != out[0][0] - 1:
        return f"live chest counts A={out[0]} B={out[1]}"
    return None


def handoff_ok(logs):
    """Whoever got slot 2 killed NPCs after the host left and got the credit from the new owner (slot 1)."""
    by_slot = {}
    for k in "ABCDEFGH":
        m = re.search(r"handoff: t=\d+ slot (\d)", logs.get(k, ""))
        if m:
            by_slot[int(m.group(1))] = k
    if 1 not in by_slot or 2 not in by_slot:
        return f"slots seen: {by_slot}"
    if not re.search(r"raid owner: slot 1 \(me\)", logs[by_slot[1]]) or not re.search(r"took over \d+ NPCs", logs[by_slot[1]]):
        return "slot 1 did not take the raid over"
    if not re.search(r"player slot 2 killed", logs[by_slot[1]]):
        return "the new owner credited no kill to slot 2"
    if not re.search(r"kill credited", logs[by_slot[2]]):
        return "slot 2 got no kill credit"
    return None


def fps_ok(logs):
    for k in "AB":
        m = re.findall(r"fpstest: 300 ticks real_s=([\d.]+)", logs[k])
        if not m:
            return f"{k}: no fpstest"
        bad = [x for x in m if not 4.8 <= float(x) <= 5.6]
        if bad:
            return f"{k}: 300 ticks took {bad} s"
    return None


SCENARIOS = [
    # every game language: mod texts from mod/lang/strings.tsv, screenshots of the co-op panel (lang_<language>.png)
    S("lang", "-coop_scenario lang", "",
      done=[("A", r"lang: done")], checks=[("A", r"lang: done ok=13/13", 1), ("A", r"lang: game languages 13 ", 1)],
      need_identical=False, timeout=180, minutes=3, players=1),
    S("panelraid", "-coop_autoraid 1 -coop_scenario panelraid", "",
      done=[("A", r"panelraid: done")], checks=[("A", r"panelraid: shot, panel=1", 1)],
      need_identical=False, timeout=200, minutes=3, players=1),
    S("tutorial", "-coop_scenario tutorial", "",
      done=[("A", r"tutorial: done")], checks=[("A", r"tutorial: panel=1 page=welcome", 1), ("A", r"tutorial: closed page=main", 1), ("A", r"welcome: welcome_never", 1), ("A", r"after never panel=0", 1)],
      need_identical=False, timeout=120, minutes=2, players=1),
    S("report", "-coop_scenario report", "",
      done=[("A", r"report: done")],
      checks=[("A", r"report: manual dir=coop_reports/report_\S+ log=1 info=1 panel closed=1", 1),
              ("A", r"report: crash info has message=1", 1), ("A", r"report: kept=5", 1), ("A", r"report: mods json safe=1", 1),
              ("A", r"profile on root changed=1 dir=1 settings copied=1 cloud=0", 1), ("A", r"profile off pending, root same=1 label .*restart", 1)],
      need_identical=False, timeout=150, minutes=3, players=1),
    S("backup", "-coop_scenario backup", "",
      done=[("A", r"backup: done")],
      checks=[("A", r"backup: made=1", 1), ("A", r"backup: damaged, md5 now 1", 1), ("A", r"backup: restore ok=1", 1),
              ("A", r"save restored slot 1", 1), ("A", r"save backup slot 1 \(restore\)", 1)],
      need_identical=False, timeout=200, minutes=3, players=1),
    # one window, no co-op session: the mod installed for single player (the new AI must fight normally)
    S("solo", "-coop_autoraid 1 -coop_scenario solo", "",
      done=[("A", r"solo: done")],
      checks=[("A", r"solo: unpaused, player=1", 1), ("A", r"ai engaged=[1-9]", 1), ("A", r"kills=[1-9]", 1)],
      need_identical=False, timeout=240, minutes=4, players=1),
    S("fps", "-coop_autoraid 1 -coop_scenario fps", "-coop_scenario fps -coop_fps 60",
      done=[("A", r"fpstest(.|\n)*fpstest"), ("B", r"fpstest(.|\n)*fpstest")],
      checks=[], custom=fps_ok),
    S("anim", "-coop_autoraid 1 -coop_scenario anim", "-coop_scenario anim",
      done=[("A", r"torch att_1 have=1 on=1")],
      checks=[("A", r"arms=s_arms_med_bandage", 1), ("A", r"arms=s_arms_eat", 1),
              ("A", r"psound from partner", 1), ("A", r"puppet footstep", 1)], timeout=300),
    S("v3", "-coop_autoraid 1 -coop_scenario v3", "-coop_scenario v3",
      done=[("A", r"v3: done"), ("B", r"v3: done")],
      checks=[("B", r"kill credited", 1), ("B", r"emission started by host", 1), ("A", r"v3: host unpaused, player exists=1", 1)]),
    # game files / mods check: the guest fakes a changed languages folder and an extra mod
    S("files", "-coop_scenario files", "-coop_scenario files",
      done=[("A", r"files: test done"), ("B", r"files: test done")],
      checks=[("A", r"FILES DIFFER from slot 1: game=languages only_them=testmod only_me= mods_diff=\s", 1),
              ("B", r"FILES DIFFER from slot 0: game=languages only_them= only_me=testmod mods_diff=\s", 1),
              ("A", r"files: \d+ groups hashed", 1)], custom=files_ok,
      need_identical=False, timeout=150, minutes=3),
    S("revive", "-coop_autoraid 1 -coop_scenario revive", "-coop_scenario revive",
      done=[("B", r"revived with \d+ hp")],
      checks=[("A", r"revived partner with", 1), ("B", r"down #1 timer", 1)]),
    S("both", "-coop_autoraid 1 -coop_scenario both", "-coop_scenario both",
      done=[("B", r"both down: death for both|partner death message")],
      checks=[("B", r"down #2|both down|forced death", 1)], timeout=300),
    S("chest", "-coop_autoraid 1 -coop_scenario chest", "-coop_scenario chest",
      done=[("A", r"scenario chest t=420"), ("B", r"scenario chest t=420")],
      checks=[("A", r"scenario: host took first item", 1)], custom=chest_md5_equal),
    S("livechest", "-coop_autoraid 1 -coop_scenario livechest", "-coop_scenario livechest",
      done=[("A", r"lc t=280"), ("B", r"lc t=280")],
      checks=[], custom=livechest_ok),
    S("join", "-coop_scenario join", "-coop_scenario join",
      done=[("B", r"maps identical")],
      checks=[("A", r"join test: host goes into the raid alone", 1)]),
    # the host starts its raid alone, the guest connects later and joins it (group scaling must not change)
    S("latejoin", "-coop_scenario join", "-coop_scenario join -coop_delay_join 25",
      done=[("B", r"maps identical")],
      checks=[("A", r"raid started without partner", 1), ("B", r"train joins the raid of slot 0", 1)]),
    S("leave", "-coop_autoraid 1 -coop_scenario leave", "-coop_scenario leave",
      done=[("B", r"peer_in_raid=0(.|\n)*peer_in_raid=0")],
      checks=[("A", r"host leaves the extraction screen", 1)], timeout=320, minutes=6),
    # connection indicator: the host's link is slow and lossy, both sides show the problem
    S("conn", "-coop_scenario conn -coop_netsim 260,12,0", "-coop_scenario conn",
      done=[("A", r"conn: test done"), ("B", r"conn: test done")],
      checks=[("A", r"conn: problem shown", 1), ("B", r"conn: problem shown", 1), ("A", r"conn: slot 1 ping 2[5-9]\d", 1)],
      need_identical=False, timeout=150, minutes=3),
    # teammates: status (menu, away) under the name tag, group panel with the item being used
    S("group", "-coop_autoraid 1 -coop_scenario group", "-coop_scenario group",
      done=[("A", r"group: done"), ("B", r"group: done")],
      checks=[("A", r"group: partner uses bandage weapon", 1), ("A", r"status: slot 1 is 2", 1),
              ("A", r"status: slot 1 is 3", 1), ("B", r"status: mine 2", 1),
              ("A", r"chat .*: Привет, it's the guest", 1), ("B", r"chat .*: host answers", 1), ("A", r"chat open, game blocked=1", 1),
              ("A", r"chat .*: \[Enemy spotted\]", 1), ("A", r"chat .*: \[Need a medkit\]", 1),
              ("A", r"group: streamer name Player 2 me Player 1", 1), ("A", r"group: streamer off name SaWka", 1),
              ("B", r"gear: sent to slot 0 equip [1-9]", 1), ("A", r"gear: got slot 1 equip [1-9] items", 1), ("A", r"aiming hud hidden=1", 1), ("A", r"hit while aiming, hp shown=1", 1), ("A", r"chat .*: \[Need: ", 1)], timeout=300),
    # friendly fire with half damage
    S("ff", "-coop_autoraid 1 -coop_scenario ff -coop_diff coop_friendly_fire=1,coop_friendly_fire_damage=0.5", "-coop_scenario ff",
      done=[("A", r"ff: done"), ("B", r"ff: done")], checks=[("A", r"setting 0.5", 1)], custom=ff_ok),
    S("ff_full", "-coop_autoraid 1 -coop_scenario ff -coop_diff coop_friendly_fire=1,coop_friendly_fire_damage=1", "-coop_scenario ff",
      done=[("A", r"ff: done"), ("B", r"ff: done")], checks=[("A", r"setting 1", 1), ("A", r"host lost [1-9]", 1)]),
    # lobby: the host removes the guest, who cannot come back
    S("kick", "-coop_scenario kick", "-coop_scenario kick",
      done=[("A", r"kick: done"), ("B", r"kick: done")],
      checks=[("A", r"kicked SaWka|kicked \S+ slot 1", 1), ("B", r"kicked by the host", 2), ("A", r"tried to come back - refused", 1),
              ("A", r"kick: host players now 1", 1), ("A", r"confirm label Remove .*Click again", 1)],
      need_identical=False, timeout=200, minutes=3),
    # group extraction: the host waits on the point (10 s), the guest arrives, both leave together; summary
    S("extract", "-coop_autoraid 1 -coop_scenario extract", "-coop_scenario extract",
      done=[("A", r"extract: done"), ("B", r"extract: done")],
      checks=[("A", r"extract: host waiting=1 max=600", 1), ("B", r"extract: slot 0 is extracting", 1),
              ("A", r"extract: done, summaries=2", 1), ("B", r"extract: done, summaries=2 kills=[1-9]", 1),
              ("A", r"summary from slot 1: kills [1-9]", 1), ("A", r"partners page SaWka S4mple: raids [1-9]\d*, revived \d+, kills [1-9]", 1)], timeout=360, minutes=6),
    # watching teammates after the final death (revive off): the camera follows the host, back to the death screen
    S("spectate", "-coop_autoraid 1 -coop_scenario spectate -coop_diff coop_revive_enabled=0", "-coop_scenario spectate",
      done=[("B", r"spectate: done")],
      checks=[("B", r"spectate: watching slot 0", 1), ("B", r"spectate: on=1 camera on host=1", 1), ("B", r"spectate: back, on=0", 1)],
      timeout=300, minutes=5),
    # crawl / drag (item 30): drag and revive while walking, drag only (slower bleed), a crawl cancels a revive on the spot
    S("drag", "-coop_autoraid 1 -coop_scenario drag", "-coop_scenario drag",
      done=[("A", r"drag: done"), ("B", r"drag: done")],
      checks=[("B", r"drag: first revive moved ([4-9]\d|[1-9]\d\d) px", 1), ("A", r"revive started, mode 1", 1), ("A", r"revive started, mode 2", 1),
              ("B", r"dragged-only bleed per 60 ticks = (1[5-9]|2[0-5])", 1), ("A", r"revive cancelled: slot 1 moved", 1),
              ("B", r"down: moved while being revived", 1), ("B", r"timer after cancel kept=1", 1), ("B", r"revived with", 2)],
      timeout=420, minutes=7),
    # back into the session after a crash: the panel offers Rejoin {host}
    S("rejoin", "-coop_scenario rejoin", "-coop_scenario rejoin",
      done=[("B", r"rejoin: done")],
      checks=[("B", r"rejoin: note written=1 host=", 1), ("B", r"rejoin: first button rejoin Rejoin ", 1),
              ("B", r"rejoin: back in the session", 1), ("A", r"guest connected: ", 2)],
      need_identical=False, timeout=200, minutes=3),
    # PDA map: teammates in colour, ping marks, the owner's air drop marker on the guest's map
    S("pda", "-coop_autoraid 1 -coop_scenario pda", "-coop_scenario pda",
      done=[("A", r"pda: done"), ("B", r"pda: done")],
      checks=[("B", r"air drop markers added: 1", 1), ("B", r"pda: air drop markers=[1-9] marks=1 mate on map=1 colour ok=1", 1),
              ("A", r"pda: air drop markers=[1-9] marks=1 mate on map=1 colour ok=1", 1)], timeout=300),
    # quest items are each player's own, even in a shared container
    S("questloot", "-coop_autoraid 1 -coop_scenario questloot", "-coop_scenario questloot",
      done=[("A", r"questloot: done"), ("B", r"questloot: done")],
      checks=[("B", r"questloot: guest ready", 1), ("B", r"guest still has quest=1", 1), ("B", r"quest item kept for us: document_quest_lab", 1),
              ("A", r"questloot: host quest back=0", 1), ("A", r"quest item taken by us", 1)], timeout=300),
    # personal loot: the same container rolls different content for host and guest
    S("personal", "-coop_autoraid 1 -coop_scenario chest -coop_diff coop_personal_loot=1", "-coop_scenario chest",
      done=[("A", r"scenario chest t=420"), ("B", r"scenario chest t=420")],
      checks=[], custom=lambda logs: "same content with personal loot" if chest_md5_equal(logs) is None else None),
    S("reconnect", "-coop_autoraid 1", "-coop_netsim 0,0,0,15,20",
      done=[("B", r"netsim: blackout(.|\n)*connected to host(.|\n)*re-adopted")],
      checks=[("A", r"timed out", 1), ("A", r"guest connected", 2), ("B", r"connected to host", 2)], timeout=300, minutes=5),
    # 1.4 AI against a guest far from the host: targets the puppet, hears its steps, shoots it, callouts reach it
    S("aiguest", "-coop_autoraid 1 -coop_scenario aiguest", "-coop_scenario aiguest",
      done=[("B", r"aiguest: done")],
      checks=[("A", r"best=[1-9]", 1), ("A", r"hearing emits=[1-9]", 1), ("B", r"npc bark from owner", 1)],
      timeout=300, minutes=5),
    S("quad", "-coop_autoraid 1 -coop_scenario quad -coop_fps 60", "-coop_scenario quad -coop_fps 60",
      done=[(k, r"quad: done") for k in "ABCD"],
      checks=[(k, r"players=4 puppets=3", 1) for k in "ABCD"] + [("A", r"maps identical with partner", 3),
              ("A", r"revived partner .* slot 2", 1), ("BCD", r"kill credited", 1)]  # the shooter is slot 1, whichever guest connected first
              + [(k, r"ping mark from slot", 3) for k in "ABCD"]
              + [("B", r"ping mark removed at", 1)] + [(k, r"ping mark removed by slot 1", 1) for k in "ACD"],
      custom=lambda logs: None if (re.search(r"received .* from slot 3", logs["A"]) and any(re.search(r"gave .* to slot 0", logs[k]) for k in "BCD")) else "item give slot 3 -> host failed",
      timeout=420, minutes=7, players=4),
    # eight players (2.0.0): the quad scenario with everybody
    S("octo", "-coop_autoraid 1 -coop_scenario quad -coop_fps 60", "-coop_scenario quad -coop_fps 60",
      done=[(k, r"quad: done") for k in "ABCDEFGH"],
      checks=[(k, r"players=8 puppets=7", 1) for k in "ABCDEFGH"] + [("A", r"maps identical with partner", 7),
              ("A", r"revived partner .* slot 2", 1), ("BCDEFGH", r"kill credited", 1)]
              + [(k, r"ping mark from slot", 7) for k in "ABCDEFGH"],
      custom=lambda logs: None if (re.search(r"received .* from slot 7", logs["A"]) and any(re.search(r"gave .* to slot 0", logs[k]) for k in "BCDEFGH")) else "item give slot 7 -> host failed",
      timeout=600, minutes=9, players=8),
    S("handoff", "-coop_autoraid 1 -coop_scenario handoff -coop_fps 60", "-coop_scenario handoff -coop_fps 60",
      done=[(k, r"handoff: done") for k in "BCD"],
      checks=[(k, r"raid owner: slot 1", 1) for k in "BCD"] + [("A", r"handoff: host leaves", 1)], custom=handoff_ok,
      timeout=480, minutes=8, players=4),
    # three instances (lighter on RAM): the same group logic as quad/handoff
    S("trio", "-coop_autoraid 1 -coop_scenario quad -coop_fps 60", "-coop_scenario quad -coop_fps 60",
      done=[(k, r"quad: done") for k in "ABC"],
      checks=[(k, r"players=3 puppets=2", 1) for k in "ABC"] + [("A", r"maps identical with partner", 2),
              ("A", r"revived partner .* slot 2", 1), ("A", r"received .* from slot 2", 1)]
              + [(k, r"ping mark from slot", 2) for k in "ABC"]
              + [("B", r"ping mark removed at", 1)] + [(k, r"ping mark removed by slot 1", 1) for k in "AC"],
      timeout=420, minutes=7, players=3),
    S("handoff3", "-coop_autoraid 1 -coop_scenario handoff -coop_fps 60", "-coop_scenario handoff -coop_fps 60",
      done=[(k, r"handoff: done") for k in "BC"],
      checks=[(k, r"raid owner: slot 1", 1) for k in "BC"] + [("A", r"handoff: host leaves", 1)], custom=handoff_ok,
      timeout=480, minutes=8, players=3),
    # the host takes an item from a container next to two guests: all three see the same content
    S("chest3", "-coop_autoraid 1 -coop_scenario chest -coop_fps 60", "-coop_scenario chest -coop_fps 60",
      done=[("A", r"scenario chest t=420"), ("B", r"scenario chest t=420"), ("C", r"scenario chest t=420")],
      checks=[("A", r"scenario: host took first item", 1)], custom=chest3_equal,
      need_identical=False, timeout=420, minutes=7, players=3),
    # enemy hp for the group (+100% per extra player): scaled on the host, the same on the guest
    S("grouphp", "-coop_autoraid 1 -coop_scenario v3 -coop_diff coop_group_hp=1", "-coop_scenario v3",
      done=[("A", r"v3: group hp"), ("B", r"v3: group hp")], checks=[], custom=grouphp_ok, timeout=260),
    # three players: both guests go down, then the host - everybody dies
    S("both3", "-coop_autoraid 1 -coop_scenario both -coop_fps 60", "-coop_scenario both -coop_fps 60",
      done=[(k, r"forced death: everyone down|both down: death for both") for k in "ABC"],
      checks=[(k, r"forced death: everyone down|both down: death for both", 1) for k in "ABC"],
      need_identical=False, timeout=420, minutes=7, players=3),
    # slot 2 joins the raid slot 1 owns after the host extracted (join request goes to the raid owner)
    S("ownerjoin", "-coop_autoraid 1 -coop_scenario ownerjoin -coop_fps 60", "-coop_scenario ownerjoin -coop_fps 60",
      done=[("BC", r"ownerjoin: done")], checks=[], custom=ownerjoin_ok,
      need_identical=False, timeout=600, minutes=10, players=3),
    # the host's train opens a circle with a countdown: slot 1 inside goes along, slot 2 walks away and stays home
    S("gather", "-coop_autoraid 1 -coop_scenario gather -coop_fps 60", "-coop_scenario gather -coop_fps 60",
      done=[("B", r"gather test: done"), ("C", r"gather test: done")],
      checks=[("A", r"gather: countdown over", 1), ("B", r"gather test: done hub=0 raid=1", 1),
              ("C", r"gather: stays in the bunker", 1), ("C", r"gather test: done hub=1 raid=0", 1)],
      need_identical=False, timeout=420, minutes=7, players=3),
    # the guest raids alone first, the host's train later goes into the guest's raid (the guest keeps owning it)
    S("hostjoin", "-coop_scenario hostjoin", "-coop_scenario hostjoin",
      done=[("A", r"hostjoin: done"), ("B", r"hostjoin: done")],
      checks=[("A", r"train joins the raid of slot 1: map 1", 1), ("A", r"hostjoin: done owner=1 late=1 map=1 replicas=1", 1),
              ("B", r"hostjoin: done owner=1 late=0 map=1 replicas=0", 1), ("AB", r"maps identical with partner", 1)],
      timeout=360, minutes=6),
    # the hub as a lobby: both players see each other; a visit shows the friend's bunker modules and saves ours
    S("lobby", "-coop_scenario lobby", "-coop_scenario lobby",
      done=[("B", r"lobby: restored")],
      checks=[("B", r"lobby: puppets=1 together=1", 1), ("A", r"puppet of slot 1 created", 1),
              ("A", r"save backup slot 1 \(coop\): slot1_", 1), ("B", r"save backup slot 1 \(coop\): slot1_", 1),
              ("B", r"weather synced from host", 1),  # the bunker weather follows the host's
              ("B", r"gave \S+ x\d+ to slot 0 \(bunker\)", 1), ("A", r"gift placed in the inventory|gift dropped in a bag", 1),
              ("B", r"save during visit wrote own modules=1", 1), ("B", r"lobby: restored=1", 1),
              # GitHub issue #1: pause in the hub while connected must not wake the player without obj_controller
              ("B", r"paused 60 frames, player active=0 controller=0", 1), ("B", r"pause test done, player=1 controller=1", 1)],
      need_identical=False, timeout=200, minutes=3),
    # own module furniture there from the start: gone during the visit of an empty bunker, back after
    S("lobby2", "-coop_scenario lobby", "-coop_scenario lobby2",
      done=[("B", r"lobby2: done")],
      checks=[("B", r"lobby2: visiting decor=[01]", 1), ("B", r"lobby2: back decor=\d+ own=\d+ matches=1", 1)],
      need_identical=False, timeout=200, minutes=3),
    S("tele", "-coop_autoraid 1", "-coop_scenario tele",
      done=[("B", r"tele #20 ")], checks=[], timeout=200),
]

# Every raid map with the v3 scenario (identical map, NPC sync, guest kill credit, emission, co-op pause).
MAPS = {2: "camp", 3: "industrial", 4: "swamp", 6: "mall", 8: "zakov", 9: "cnpp"}
for _id, _nm in MAPS.items():
    SCENARIOS.append(S(f"map{_id}_{_nm}", f"-coop_autoraid {_id} -coop_scenario v3", "-coop_scenario v3",
                       done=[("A", r"v3: done"), ("B", r"v3: done")],
                       checks=[("B", r"emission started by host", 1), ("A", r"v3: host unpaused, player exists=1", 1)],
                       timeout=320, minutes=6, tags="maps"))
    # single player with the mod on every map
    SCENARIOS.append(S(f"solo{_id}_{_nm}", f"-coop_autoraid {_id} -coop_scenario solo", "",
                       done=[("A", r"solo: done")], checks=[("A", r"solo: unpaused, player=1", 1)],
                       need_identical=False, timeout=240, minutes=4, players=1, tags="maps"))
    # the 1.4 AI near a guest far from the host, on every map
    SCENARIOS.append(S(f"aiguest{_id}_{_nm}", f"-coop_autoraid {_id} -coop_scenario aiguest", "-coop_scenario aiguest",
                       done=[("B", r"aiguest: done")], checks=[("A", r"hearing emits=[1-9]", 1)],
                       timeout=300, minutes=5, tags="maps"))


def read(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return ""


def stop():
    subprocess.run([sys.executable, os.path.join(ROOT, "tools", "game_guard.py"), "stop"], capture_output=True)


def run(sc, outdir, extra):
    stop()
    for p in LOGS.values():
        if os.path.exists(p):
            os.remove(p)
    # the scenario's own arguments come last, so they win over the shared extra ones
    if sc["players"] == 1:
        # single player with the mod: no session, one window (save root coopA, log coop_coopA.log)
        cmd = (f'source tools/env.sh && python tools/game_guard.py run --max-minutes {sc["minutes"]} '
               f'--note "regress {sc["name"]}" --launch "-no_gpu_pref -coop_slot 1 -coop_root coopA '
               f'-coop_window $WIN_A {extra} {sc["host"]}"')
    else:
        script = "tools/test4.sh" if sc["players"] >= 3 else "tools/test2.sh"
        cmd = f'bash {script} {sc["minutes"]} "regress {sc["name"]}" "{extra} {sc["host"]}" "{extra} {sc["guest"]}"'
    env = dict(os.environ, COOP_PLAYERS=str(sc["players"]))
    proc = subprocess.Popen([BASH, "-c", cmd], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env)
    t0 = time.time()
    status = "timeout"
    while time.time() - t0 < sc["timeout"]:
        time.sleep(2)
        logs = {k: read(p) for k, p in LOGS.items()}
        if any("CRASH" in logs[k] for k in logs):
            status = "crash"
            break
        if all(any(re.search(rx, logs[x]) for x in k) for k, rx in sc["done"]):
            status = "done"
            time.sleep(4)  # let late lines land
            break
        if proc.poll() is not None and time.time() - t0 > 20:
            status = "game exited"
            break
    logs = {k: read(p) for k, p in LOGS.items()}
    stop()
    proc.wait(timeout=30)
    os.makedirs(outdir, exist_ok=True)
    for k, p in LOGS.items():
        if os.path.exists(p):
            shutil.copy(p, os.path.join(outdir, os.path.basename(p)))
    problems = []
    if status != "done":
        problems.append(status)
    keys = "ABCDEFGH"[:sc["players"]]
    for k in keys:
        for line in logs[k].splitlines():
            if "CRASH" in line or "ERROR" in line or "NPC DRIFT" in line:
                problems.append(f"{k}: {line[:160]}")
                break
    if sc["need_identical"]:
        for k in keys:
            if "maps identical" not in logs[k]:
                problems.append(f"{k}: maps not confirmed identical")
            if "MAP MISMATCH" in logs[k] or "maps differ" in logs[k]:
                problems.append(f"{k}: map mismatch")
    for k, rx, n in sc["checks"]:
        c = sum(len(re.findall(rx, logs[x])) for x in k)  # k may name several windows: any of them counts
        if c < n:
            problems.append(f"{k}: expected /{rx}/ x{n}, got {c}")
    if sc["custom"] and status == "done":
        r = sc["custom"](logs)
        if r:
            problems.append(r)
    return time.time() - t0, problems


def main():
    args = sys.argv[1:]
    if args == ["--list"]:
        for sc in SCENARIOS:
            print(sc["name"])
        return 0
    pick = [sc for sc in SCENARIOS if (not args and sc["tags"] == "") or sc["name"] in args or sc["tags"] in args or "all" in args]
    extra = os.environ.get("COOP_REGRESS_ARGS", "")
    stamp = time.strftime("%Y%m%d-%H%M%S")
    base = os.path.join(WORK, "regress", stamp)
    results = []
    for sc in pick:
        print(f"== {sc['name']} ...", flush=True)
        secs, problems = run(sc, os.path.join(base, sc["name"]), extra)
        results.append((sc["name"], secs, problems))
        print(f"   {'PASS' if not problems else 'FAIL'} in {secs:.0f}s" + "".join(f"\n     - {p}" for p in problems), flush=True)
    print("\nscenario      result  time")
    for name, secs, problems in results:
        print(f"{name:13} {'PASS' if not problems else 'FAIL':6} {secs:4.0f}s")
    fails = sum(1 for r in results if r[2])
    print(f"\n{len(results) - fails}/{len(results)} passed{(' (extra args: ' + extra + ')') if extra else ''}; logs: {base}")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
