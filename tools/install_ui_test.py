"""Test install of the co-op UI patch for the PDA map (the installer's step 2b): restores pda_map.ui from the
installer's backup in the game folder and inserts mod/ui/pda_partner.txt before the same line the installer uses.
usage: python tools/install_ui_test.py   (run after tools/install_test.sh when mod/ui/pda_partner.txt changed)"""
import os, re, shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME = os.environ.get("ZS_GAME_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ZERO Sievert")
backup = os.path.join(GAME, "coop_backup", "pda_map.ui")
target = os.path.join(GAME, "ZS_vanilla", "ui", "pda_map.ui")
if not os.path.exists(backup):
    raise SystemExit("no installer backup of pda_map.ui - install the mod once with the installer")
text = open(backup, encoding="utf-8", newline="").read()
snippet = open(os.path.join(ROOT, "mod", "ui", "pda_partner.txt"), encoding="utf-8", newline="").read()
nl = "\r\n" if "\r\n" in text else "\n"
snippet = snippet.replace("\r\n", "\n").replace("\n", nl)
new, n = re.subn(r"(\t\t\t//Allow scrolling around the minimap)", lambda m: snippet + m.group(1), text)
if n != 1:
    raise SystemExit("insert point not found")
open(target, "w", encoding="utf-8", newline="").write(new)
print("pda_map.ui patched")

# quick slots take the co-op radio (installer step 2e)
gb = os.path.join(GAME, "coop_backup", "inventory_exec_player_gear.ui")
gt = os.path.join(GAME, "ZS_vanilla", "ui", "inventory_exec_player_gear.ui")
if not os.path.exists(gb):
    shutil.copy(gt, gb)  # first time: the installed file is still the game's own
g = open(gb, encoding="utf-8", newline="").read()
g2, n = re.subn(r'(category = \["medication", "injector", "grenade","consumable")', lambda m: m.group(1) + ', "coop_radio"', g)
if n != 1:
    raise SystemExit("quick slot categories not found")
open(gt, "w", encoding="utf-8", newline="").write(g2)
print("inventory_exec_player_gear.ui patched")
