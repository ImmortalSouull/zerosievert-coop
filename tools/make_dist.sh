#!/usr/bin/env bash
# Build the shareable mod package: zerosievert-coop-work/dist/ZS-Coop-v<ver>.zip
# Contains only our patch + our files + xdelta3 (GPL) - no game files.
set -euo pipefail
VER=${1:-0.1.0}
source "$(dirname "$0")/env.sh"
OUT=$WORK/dist/ZS-Coop-v$VER
bash $ROOT/tools/build.sh > /dev/null
rm -rf "$OUT"; mkdir -p "$OUT"
# (run from WORK with relative paths)
(cd "$WORK" && "$XDELTA_EXE" -e -9 -f -s vanilla/data.win build/data.win "dist/ZS-Coop-v$VER/coop.xdelta")
cp "$XDELTA_EXE" "$OUT/xdelta3.exe"
# Steam build of the vanilla copy (written by tools/decompile.sh --refresh from the app manifest)
GAMEVER=$(cat "$WORK/vanilla/game_version.txt" 2>/dev/null || echo "unknown build")
VAN=$(sha256sum $WORK/vanilla/data.win | cut -d' ' -f1)
MOD=$(sha256sum $WORK/build/data.win | cut -d' ' -f1)
cat > "$OUT/mod_info.json" <<EOF
{
  "mod_version": "$VER",
  "game_version": "ZERO Sievert, $GAMEVER",
  "vanilla_sha256": "$VAN",
  "modded_sha256": "$MOD"
}
EOF
cp $ROOT/mod/ui/enemies_entries.txt "$OUT/ui_enemies_entries.txt"
cp $ROOT/mod/ui/coop_tab.txt "$OUT/ui_coop_tab.txt"
cp $ROOT/mod/lang/difficulty_rows.tsv "$OUT/lang_rows.tsv"
cp $ROOT/mod/ui/pda_partner.txt "$OUT/ui_pda_partner.txt"
cp $ROOT/mod/ui/menu_button.txt "$OUT/ui_menu_button.txt"
cp $ROOT/mod/ui/mods_entry.txt "$OUT/ui_mods_entry.txt"
# PowerShell 5.1 needs a BOM to read UTF-8 (Cyrillic) scripts correctly
printf '\xef\xbb\xbf' > "$OUT/installer.ps1"; cat $ROOT/dist_src/installer.ps1 >> "$OUT/installer.ps1"
printf '@echo off\r\nchcp 65001 >nul\r\npowershell -NoProfile -ExecutionPolicy Bypass -File "%%~dp0installer.ps1" install\r\npause\r\n' > "$OUT/install.bat"
printf '@echo off\r\nchcp 65001 >nul\r\npowershell -NoProfile -ExecutionPolicy Bypass -File "%%~dp0installer.ps1" uninstall\r\npause\r\n' > "$OUT/uninstall.bat"
cp $ROOT/dist_src/README.txt "$OUT/README.txt"
cp $ROOT/dist_src/THIRD_PARTY.txt "$OUT/THIRD_PARTY.txt"
(cd "$WORK/dist" && rm -f "ZS-Coop-v$VER.zip" && powershell -NoProfile -Command "Compress-Archive -Path 'ZS-Coop-v$VER' -DestinationPath 'ZS-Coop-v$VER.zip' -Force")
ls -la "$OUT" "$WORK/dist/ZS-Coop-v$VER.zip"
