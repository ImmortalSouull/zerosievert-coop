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
$langDir = Join-Path $game "ZS_vanilla\languages"
$backup = Join-Path $game "coop_backup"

if ($Action -eq "uninstall") {
    if (-not (Test-Path $backup)) { Say "No backup found - use Steam > Verify integrity of game files." "Бэкап не найден - используйте Steam > Проверить целостность файлов."; exit 1 }
    Copy-Item (Join-Path $backup "data.win") $data -Force
    Copy-Item (Join-Path $backup "mm_difficulty.ui") $ui -Force
    Get-ChildItem (Join-Path $backup "languages") -Filter *.csv | ForEach-Object {
        Copy-Item $_.FullName (Join-Path $langDir ($_.BaseName + "\" + $_.Name)) -Force
    }
    Say "Co-op mod removed, original files restored." "Кооп-мод удалён, оригинальные файлы восстановлены."
    exit 0
}

$h = Sha $data
if ($h -ne $cfg.vanilla_sha256 -and $h -ne $cfg.modded_sha256) {
    Say "Your data.win does not match the game version this mod was built for ($($cfg.game_version)). Update/verify the game in Steam, or wait for a mod update." "Ваш data.win не совпадает с версией игры, под которую собран мод ($($cfg.game_version)). Обновите/проверьте игру в Steam или дождитесь обновления мода."
    exit 1
}

# Backups (once, from the vanilla state)
if (-not (Test-Path $backup) -and $h -eq $cfg.vanilla_sha256) {
    New-Item -ItemType Directory -Force (Join-Path $backup "languages") | Out-Null
    Copy-Item $data (Join-Path $backup "data.win")
    Copy-Item $ui (Join-Path $backup "mm_difficulty.ui")
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

# 2. Difficulty menu: Co-op tab + enemy/anomaly sliders
$u = [IO.File]::ReadAllText($ui)
if ($u -notmatch "coop\.difficulty\.tab") {
    $enemies = [IO.File]::ReadAllText((Join-Path $here "ui_enemies_entries.txt"))
    $tab = [IO.File]::ReadAllText((Join-Path $here "ui_coop_tab.txt"))
    $u = [regex]::Replace($u, '(setting: "enemy_mutant_damage",\r?\n\t+\},\r?\n)', { param($m) $m.Value + $enemies })
    $u = [regex]::Replace($u, '(\t\tbuild UiBox \{\r?\n\t\t\tsize = \[50, 50\])', { param($m) $tab + $m.Value })
    if ($u -notmatch "coop\.difficulty\.tab" -or $u -notmatch "enemy_count_mult") { Say "Could not patch the difficulty menu (unexpected file)." "Не удалось изменить меню сложности (неожиданный файл)."; exit 1 }
    [IO.File]::WriteAllText($ui, $u, (New-Object Text.UTF8Encoding($false)))
}

# 3. Language rows (Russian text for russian, English for every other language)
$rows = Get-Content (Join-Path $here "lang_rows.tsv") -Encoding UTF8 | Where-Object { $_ -ne "" }
$num = 90001
Get-ChildItem $langDir -Directory | ForEach-Object {
    $csv = Join-Path $_.FullName ($_.Name + ".csv")
    if (-not (Test-Path $csv)) { return }
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

Say "Co-op mod installed. In the bunker or main menu press F7." "Кооп-мод установлен. В бункере или главном меню нажмите F7."
