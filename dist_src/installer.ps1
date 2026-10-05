# ZERO Sievert Co-op mod installer / uninstaller.
# Patches YOUR OWN game files (data.win via an xdelta patch, the difficulty menu .ui and the
# language tables). Nothing from the game is shipped with the mod. Backups go to <game>\coop_backup.
param([ValidateSet("install", "uninstall")][string]$Action = "install")
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$cfg = Get-Content (Join-Path $here "mod_info.json") -Raw | ConvertFrom-Json

function Say($en, $ru) { Write-Host "$ru`n  ($en)" }

function Find-Game {
    $cands = @("C:\Program Files (x86)\Steam\steamapps\common\ZERO Sievert")
    $steam = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).SteamPath
    if ($steam) {
        $vdf = Join-Path $steam "steamapps\libraryfolders.vdf"
        if (Test-Path $vdf) {
            foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) {
                $cands += (Join-Path ($m.Groups[1].Value -replace '\\\\', '\') "steamapps\common\ZERO Sievert")
            }
        }
    }
    foreach ($c in $cands) { if (Test-Path (Join-Path $c "data.win")) { return $c } }
    return $null
}

function Sha($p) { (Get-FileHash $p -Algorithm SHA256).Hash.ToLower() }

$game = Find-Game
if (-not $game) { Say "ZERO Sievert folder not found." "Папка ZERO Sievert не найдена."; exit 1 }
if (Get-Process "ZERO Sievert" -ErrorAction SilentlyContinue) { Say "Close the game first." "Сначала закройте игру."; exit 1 }
$data = Join-Path $game "data.win"
$ui = Join-Path $game "ZS_vanilla\ui\mm_difficulty.ui"
$pda = Join-Path $game "ZS_vanilla\ui\pda_map.ui"
$mmMain = Join-Path $game "ZS_vanilla\ui\mm_sidebar_main.ui"
$mmPause = Join-Path $game "ZS_vanilla\ui\mm_sidebar_pause.ui"
$mmMods = Join-Path $game "ZS_vanilla\ui\mm_mods.ui"
# game UI files the mod patches, with a text that only a patched file contains
$uiFiles = @(
    @{ path = $ui; name = "mm_difficulty.ui"; mark = "coop\.difficulty\.tab" },
    @{ path = $pda; name = "pda_map.ui"; mark = "CoopPartnerOnMap|CoopMateOnMap" },
    @{ path = $mmMain; name = "mm_sidebar_main.ui"; mark = "CoopOpenPanel" },
    @{ path = $mmPause; name = "mm_sidebar_pause.ui"; mark = "CoopOpenPanel" },
    @{ path = $mmMods; name = "mm_mods.ui"; mark = "CoopModVersion" }
)
$langDir = Join-Path $game "ZS_vanilla\languages"
$backup = Join-Path $game "coop_backup"

if ($Action -eq "uninstall") {
    if (-not (Test-Path $backup)) { Say "No backup found - use Steam > Verify integrity of game files." "Бэкап не найден - используйте Steam > Проверить целостность файлов."; exit 1 }
    Copy-Item (Join-Path $backup "data.win") $data -Force
    foreach ($f in $uiFiles) {
        $b = Join-Path $backup $f.name
        if (Test-Path $b) { Copy-Item $b $f.path -Force }
    }
    Get-ChildItem (Join-Path $backup "languages") -Filter *.csv | ForEach-Object {
        Copy-Item $_.FullName (Join-Path $langDir ($_.BaseName + "\" + $_.Name)) -Force
    }
    Say "Co-op mod removed, original files restored." "Кооп-мод удалён, оригинальные файлы восстановлены."
    exit 0
}

$h = Sha $data
# Upgrade from an older co-op version: start again from the vanilla backup.
if ($h -ne $cfg.vanilla_sha256 -and $h -ne $cfg.modded_sha256 -and (Test-Path (Join-Path $backup "data.win"))) {
    if ((Sha (Join-Path $backup "data.win")) -eq $cfg.vanilla_sha256) {
        Say "Updating an older co-op version..." "Обновляем старую версию кооп-мода..."
        Copy-Item (Join-Path $backup "data.win") $data -Force
        $h = $cfg.vanilla_sha256
    }
}
if ($h -ne $cfg.vanilla_sha256 -and $h -ne $cfg.modded_sha256) {
    Say "Your data.win does not match the game version this mod was built for ($($cfg.game_version)). Update/verify the game in Steam, or wait for a mod update." "Ваш data.win не совпадает с версией игры, под которую собран мод ($($cfg.game_version)). Обновите/проверьте игру в Steam или дождитесь обновления мода."
    exit 1
}

# Backups (once, from the vanilla state)
if (-not (Test-Path $backup) -and $h -eq $cfg.vanilla_sha256) {
    New-Item -ItemType Directory -Force (Join-Path $backup "languages") | Out-Null
    Copy-Item $data (Join-Path $backup "data.win")
    Get-ChildItem $langDir -Directory | ForEach-Object {
        $csv = Join-Path $_.FullName ($_.Name + ".csv")
        if (Test-Path $csv) { Copy-Item $csv (Join-Path $backup "languages\") }
    }
}

# 1. data.win
if ($h -eq $cfg.vanilla_sha256) {
    $new = "$data.coop_new"
    & (Join-Path $here "xdelta3.exe") -d -f -s $data (Join-Path $here "coop.xdelta") $new
    if ((Sha $new) -ne $cfg.modded_sha256) { Remove-Item $new -Force; Say "Patch result is wrong, nothing changed." "Патч применился неверно, ничего не изменено."; exit 1 }
    Move-Item $new $data -Force
}

New-Item -ItemType Directory -Force (Join-Path $backup "languages") | Out-Null
# 2. Game UI files. An older install may lack the backup of a file the mod patches only since a later
# version: take it now, while that file is still untouched. Then every install starts again from the
# backups, so an update always brings the current UI changes.
foreach ($f in $uiFiles) {
    $b = Join-Path $backup $f.name
    if (-not (Test-Path $b)) {
        $t0 = [IO.File]::ReadAllText($f.path)
        if ($t0 -match $f.mark) { Say "$($f.name) is modified but has no backup - verify the game files in Steam, then install again." "$($f.name) изменён, но бэкапа нет - проверьте целостность файлов в Steam и установите снова."; exit 1 }
        Copy-Item $f.path $b
    }
    Copy-Item $b $f.path -Force
}
function Patch-Ui($path, $pattern, $insert, $before, $check, $what) {
    $t = [IO.File]::ReadAllText($path)
    $t = [regex]::Replace($t, $pattern, { param($m) if ($before) { $insert + $m.Value } else { $m.Value + $insert } })
    if ($t -notmatch $check) { Say "Could not patch $what (unexpected file)." "Не удалось изменить $what (неожиданный файл)."; exit 1 }
    [IO.File]::WriteAllText($path, $t, (New-Object Text.UTF8Encoding($false)))
}
# 2a. Difficulty menu: Co-op tab + enemy/anomaly sliders
Patch-Ui $ui '(setting: "enemy_mutant_damage",\r?\n\t+\},\r?\n)' ([IO.File]::ReadAllText((Join-Path $here "ui_enemies_entries.txt"))) $false "enemy_count_mult" "the difficulty menu"
Patch-Ui $ui '(\t\tbuild UiBox \{\r?\n\t\t\tsize = \[50, 50\])' ([IO.File]::ReadAllText((Join-Path $here "ui_coop_tab.txt"))) $true "coop\.difficulty\.tab" "the difficulty menu"
# 2b. PDA map: markers of the other players
Patch-Ui $pda '(\t\t\t//Allow scrolling around the minimap)' ([IO.File]::ReadAllText((Join-Path $here "ui_pda_partner.txt"))) $true "CoopMateOnMap" "the PDA map"
# 2c. "Co-op" button in the main menu and in the pause menu (before "Settings")
$btn = [IO.File]::ReadAllText((Join-Path $here "ui_menu_button.txt"))
Patch-Ui $mmMain '(\t\tbuild UiTextButton \{\r?\n\t\t\tlabel = "Settings")' $btn $true "CoopOpenPanel" "the main menu"
Patch-Ui $mmPause '(\t\tbuild UiTextButton \{\r?\n\t\t\tlabel = "Settings")' $btn $true "CoopOpenPanel" "the pause menu"
# 2d. The co-op entry at the top of the Mods menu (the mod is a patch: the game itself does not list it)
# (before the game's own list: with no mods installed UiModMapIDtoOrder(0) fails and the rest is not built)
Patch-Ui $mmMods '(\t\tdata\.modding_menu_current = UiModMapIDtoOrder\(0\))' ([IO.File]::ReadAllText((Join-Path $here "ui_mods_entry.txt"))) $true "CoopModVersion" "the mods menu"
# the game's "New" tag sits at a fixed height next to "Mods": with one more button it would point at another row
$t = [IO.File]::ReadAllText($mmMain)
[IO.File]::WriteAllText($mmMain, $t.Replace('label = "New"', 'label = ""'), (New-Object Text.UTF8Encoding($false)))

# 3. Language rows (Russian text for russian, English for every other language)
$rows = Get-Content (Join-Path $here "lang_rows.tsv") -Encoding UTF8 | Where-Object { $_ -ne "" }
$num = 90001
Get-ChildItem $langDir -Directory | ForEach-Object {
    $csv = Join-Path $_.FullName ($_.Name + ".csv")
    if (-not (Test-Path $csv)) { return }
    # start again from the backup, so an update brings new rows too
    $bcsv = Join-Path $backup ("languages\" + $_.Name + ".csv")
    if (Test-Path $bcsv) { Copy-Item $bcsv $csv -Force }
    $text = [IO.File]::ReadAllText($csv, [Text.Encoding]::UTF8)
    if ($text -match "coop\.difficulty\.tab") { return }
    $add = ""
    if (-not $text.EndsWith("`n")) { $add += "`r`n" }
    $n = $num
    foreach ($r in $rows) {
        $p = $r.Split("`t")
        $val = if ($_.Name -eq "russian") { $p[2] } else { $p[1] }
        $add += "$n,$($p[0]),Co-op mod,64,$val`r`n"
        $n++
    }
    [IO.File]::WriteAllText($csv, $text + $add, (New-Object Text.UTF8Encoding($true)))
}

Say "Co-op mod installed. Main menu or pause menu > Co-op (or F7)." "Кооп-мод установлен. Главное меню или пауза > Кооператив (или F7)."
