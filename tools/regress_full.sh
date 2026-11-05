#!/usr/bin/env bash
# The whole release check, in the order players use the mod: solo -> duo -> trio -> squad, then everything
# again on a bad network. Each phase prints its own summary; logs are in work/regress/<timestamp>/.
# usage: bash tools/regress_full.sh [soak minutes, default 20]
source "$(dirname "$0")/env.sh"
cd "$ROOT"
SOAK=${1:-20}
P=(python tools/regress.py)
LIST=$(python tools/regress.py --list | tr -d '\r')  # Windows Python prints CRLF
pick() { for s in $LIST; do case "$s" in $1) echo "$s";; esac; done; }
SOLO="lang solo $(pick 'solo[0-9]*_*')"
DUO="fps anim v3 revive both chest livechest join latejoin leave reconnect aiguest grouphp lobby lobby2 tele $(pick 'map[0-9]*_*') $(pick 'aiguest[0-9]*_*')"
TRIO="trio handoff3 chest3 both3 ownerjoin"
SQUAD="quad handoff"
echo "######## SOLO";  "${P[@]}" $SOLO
echo "######## DUO";   "${P[@]}" $DUO
echo "######## TRIO";  "${P[@]}" $TRIO
echo "######## SQUAD"; "${P[@]}" $SQUAD
echo "######## SQUAD SOAK ($SOAK min)"; python tools/soak.py "$SOAK"
echo "######## BAD NETWORK (120 ms, 3% loss, 40 ms jitter)"
COOP_REGRESS_ARGS="-coop_netsim 120,3,40" "${P[@]}" fps v3 revive both chest livechest join latejoin leave reconnect aiguest lobby $TRIO $SQUAD
echo "######## FULL RUN FINISHED"
