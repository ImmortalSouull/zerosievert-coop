# ZERO Sievert Co-op mod installer / uninstaller.
# Patches YOUR OWN game files (data.win via an xdelta patch, the difficulty menu .ui and the
# language tables). Nothing from the game is shipped with the mod. Backups go to <game>\coop_backup.
param([ValidateSet("install", "uninstall")][string]$Action = "install")
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$cfg = Get-Content (Join-Path $here "mod_info.json") -Raw | ConvertFrom-Json

# Messages in the Windows display language (English in brackets); the game itself picks its own language.
# Keys are the English texts; {0} is filled in by Say's third argument.
$UiLang = (Get-UICulture).Name
$UiCode = switch -Wildcard ($UiLang) { "ru*" {"ru"} "pl*" {"pl"} "de*" {"de"} "fr*" {"fr"} "it*" {"it"} "es*" {"es"} "pt*" {"pt"} "tr*" {"tr"} "ja*" {"ja"} "ko*" {"ko"} "zh-TW" {"zht"} "zh-HK" {"zht"} "zh-MO" {"zht"} "zh-Hant*" {"zht"} "zh*" {"zh"} default {"en"} }
$Msg = @{
"ZERO Sievert folder not found." = @{ pl="Nie znaleziono folderu ZERO Sievert."; de="ZERO-Sievert-Ordner nicht gefunden."; fr="Dossier de ZERO Sievert introuvable."; it="Cartella di ZERO Sievert non trovata."; es="No se encontró la carpeta de ZERO Sievert."; pt="Pasta do ZERO Sievert não encontrada."; tr="ZERO Sievert klasörü bulunamadı."; ja="ZERO Sievertのフォルダーが見つかりません。"; ko="ZERO Sievert 폴더를 찾을 수 없습니다."; zh="未找到 ZERO Sievert 文件夹。"; zht="找不到 ZERO Sievert 資料夾。" }
"Close the game first." = @{ pl="Najpierw zamknij grę."; de="Schließe zuerst das Spiel."; fr="Ferme d'abord le jeu."; it="Chiudi prima il gioco."; es="Cierra primero el juego."; pt="Feche o jogo primeiro."; tr="Önce oyunu kapat."; ja="先にゲームを終了してください。"; ko="먼저 게임을 종료하세요."; zh="请先关闭游戏。"; zht="請先關閉遊戲。" }
"No backup found - use Steam > Verify integrity of game files." = @{ pl="Nie znaleziono kopii zapasowej - użyj Steam > Zweryfikuj spójność plików gry."; de="Keine Sicherung gefunden - nutze Steam > Dateien auf Fehler überprüfen."; fr="Aucune sauvegarde - utilise Steam > Vérifier l'intégrité des fichiers du jeu."; it="Nessun backup trovato - usa Steam > Verifica integrità dei file di gioco."; es="No hay copia de seguridad: usa Steam > Verificar integridad de los archivos del juego."; pt="Nenhum backup encontrado - use Steam > Verificar integridade dos arquivos do jogo."; tr="Yedek bulunamadı - Steam > Oyun dosyalarının bütünlüğünü doğrula seçeneğini kullan."; ja="バックアップが見つかりません - Steam > ゲームファイルの整合性を確認 を使ってください。"; ko="백업이 없습니다 - Steam > 게임 파일 무결성 확인을 사용하세요."; zh="未找到备份 - 请使用 Steam > 验证游戏文件的完整性。"; zht="找不到備份 - 請使用 Steam > 驗證遊戲檔案的完整性。" }
"Co-op mod removed, original files restored." = @{ pl="Mod kooperacji usunięty, oryginalne pliki przywrócone."; de="Koop-Mod entfernt, Originaldateien wiederhergestellt."; fr="Mod coop supprimé, fichiers d'origine restaurés."; it="Mod coop rimossa, file originali ripristinati."; es="Mod cooperativo eliminado, archivos originales restaurados."; pt="Mod cooperativo removido, arquivos originais restaurados."; tr="Co-op modu kaldırıldı, orijinal dosyalar geri yüklendi."; ja="協力MODを削除し、元のファイルを復元しました。"; ko="협동 모드를 제거하고 원래 파일을 복원했습니다."; zh="合作模组已移除，原始文件已恢复。"; zht="合作模組已移除，原始檔案已還原。" }
"Updating an older co-op version..." = @{ pl="Aktualizacja starszej wersji moda kooperacji..."; de="Ältere Koop-Version wird aktualisiert..."; fr="Mise à jour d'une ancienne version du mod coop..."; it="Aggiornamento di una versione precedente della mod coop..."; es="Actualizando una versión anterior del mod cooperativo..."; pt="Atualizando uma versão anterior do mod cooperativo..."; tr="Eski co-op sürümü güncelleniyor..."; ja="古い協力MODを更新しています..."; ko="이전 협동 모드 버전을 업데이트하는 중..."; zh="正在更新旧版合作模组……"; zht="正在更新舊版合作模組……" }
"Your data.win does not match the game version this mod was built for ({0}). Update/verify the game in Steam, or wait for a mod update." = @{ pl="Twój data.win nie pasuje do wersji gry, dla której zbudowano moda ({0}). Zaktualizuj/zweryfikuj grę w Steam albo poczekaj na aktualizację moda."; de="Deine data.win passt nicht zur Spielversion, für die die Mod gebaut wurde ({0}). Aktualisiere/überprüfe das Spiel in Steam oder warte auf ein Mod-Update."; fr="Ton data.win ne correspond pas à la version du jeu prévue pour ce mod ({0}). Mets à jour/vérifie le jeu dans Steam ou attends une mise à jour du mod."; it="Il tuo data.win non corrisponde alla versione del gioco per cui è fatta la mod ({0}). Aggiorna/verifica il gioco su Steam o attendi un aggiornamento della mod."; es="Tu data.win no coincide con la versión del juego para la que se hizo el mod ({0}). Actualiza/verifica el juego en Steam o espera una actualización del mod."; pt="Seu data.win não corresponde à versão do jogo para a qual o mod foi feito ({0}). Atualize/verifique o jogo no Steam ou aguarde uma atualização do mod."; tr="data.win dosyan, modun yapıldığı oyun sürümüyle eşleşmiyor ({0}). Oyunu Steam'de güncelle/doğrula veya mod güncellemesini bekle."; ja="data.winがこのMODの対象バージョン ({0}) と一致しません。Steamでゲームを更新/確認するか、MODの更新をお待ちください。"; ko="data.win이 모드가 만들어진 게임 버전({0})과 맞지 않습니다. Steam에서 게임을 업데이트/확인하거나 모드 업데이트를 기다리세요."; zh="你的 data.win 与本模组对应的游戏版本（{0}）不符。请在 Steam 中更新/验证游戏，或等待模组更新。"; zht="你的 data.win 與本模組對應的遊戲版本（{0}）不符。請在 Steam 中更新/驗證遊戲，或等待模組更新。" }
"Patch result is wrong, nothing changed." = @{ pl="Wynik łatki jest nieprawidłowy, nic nie zmieniono."; de="Patch-Ergebnis fehlerhaft, nichts geändert."; fr="Le résultat du patch est incorrect, rien n'a été modifié."; it="Il risultato della patch è errato, nulla è stato modificato."; es="El resultado del parche es incorrecto, no se ha cambiado nada."; pt="O resultado do patch está errado, nada foi alterado."; tr="Yama sonucu hatalı, hiçbir şey değiştirilmedi."; ja="パッチの結果が正しくありません。何も変更していません。"; ko="패치 결과가 잘못되었습니다. 아무것도 변경되지 않았습니다."; zh="补丁结果错误，未做任何更改。"; zht="修補結果錯誤，未做任何變更。" }
"{0} is modified but has no backup - verify the game files in Steam, then install again." = @{ pl="{0} jest zmieniony, ale nie ma kopii zapasowej - zweryfikuj pliki gry w Steam i zainstaluj ponownie."; de="{0} ist verändert, aber ohne Sicherung - überprüfe die Spieldateien in Steam und installiere erneut."; fr="{0} est modifié mais sans sauvegarde - vérifie les fichiers du jeu dans Steam puis réinstalle."; it="{0} è modificato ma senza backup - verifica i file di gioco su Steam, poi reinstalla."; es="{0} está modificado pero no tiene copia de seguridad: verifica los archivos del juego en Steam y vuelve a instalar."; pt="{0} foi modificado mas não tem backup - verifique os arquivos do jogo no Steam e instale de novo."; tr="{0} değiştirilmiş ama yedeği yok - Steam'de oyun dosyalarını doğrula, sonra tekrar kur."; ja="{0}は変更されていますがバックアップがありません - Steamでゲームファイルを確認してから再インストールしてください。"; ko="{0}이(가) 변경되었지만 백업이 없습니다 - Steam에서 게임 파일을 확인한 뒤 다시 설치하세요."; zh="{0} 已被修改但没有备份 - 请在 Steam 中验证游戏文件后重新安装。"; zht="{0} 已被修改但沒有備份 - 請在 Steam 中驗證遊戲檔案後重新安裝。" }
"Could not patch {0} (unexpected file)." = @{ pl="Nie udało się zmienić: {0} (nieoczekiwany plik)."; de="{0} konnte nicht gepatcht werden (unerwartete Datei)."; fr="Impossible de modifier {0} (fichier inattendu)."; it="Impossibile modificare {0} (file inatteso)."; es="No se pudo modificar {0} (archivo inesperado)."; pt="Não foi possível modificar {0} (arquivo inesperado)."; tr="{0} değiştirilemedi (beklenmeyen dosya)."; ja="{0}を変更できませんでした (想定外のファイル)。"; ko="{0}을(를) 수정할 수 없습니다 (예상치 못한 파일)."; zh="无法修改{0}（文件不符合预期）。"; zht="無法修改{0}（檔案不符合預期）。" }
"Co-op mod installed. Main menu or pause menu > Co-op (or F7)." = @{ pl="Mod kooperacji zainstalowany. Menu główne lub menu pauzy > Kooperacja (albo F7)."; de="Koop-Mod installiert. Hauptmenü oder Pausenmenü > Koop (oder F7)."; fr="Mod coop installé. Menu principal ou menu pause > Coop (ou F7)."; it="Mod coop installata. Menu principale o menu di pausa > Coop (o F7)."; es="Mod cooperativo instalado. Menú principal o menú de pausa > Cooperativo (o F7)."; pt="Mod cooperativo instalado. Menu principal ou menu de pausa > Cooperativo (ou F7)."; tr="Co-op modu kuruldu. Ana menü veya duraklatma menüsü > Co-op (ya da F7)."; ja="協力MODをインストールしました。メインメニューまたはポーズメニュー > 協力プレイ (またはF7)。"; ko="협동 모드를 설치했습니다. 메인 메뉴 또는 일시 정지 메뉴 > 협동 (또는 F7)."; zh="合作模组已安装。主菜单或暂停菜单 > 合作模式（或 F7）。"; zht="合作模組已安裝。主選單或暫停選單 > 合作模式（或 F7）。" }
}
function Say($en, $ru, $arg = "") {
    $local = $null
    if ($UiCode -eq "ru") { $local = $ru }
    elseif ($Msg.ContainsKey($en) -and $Msg[$en].ContainsKey($UiCode)) { $local = $Msg[$en][$UiCode] }
    $en = $en.Replace("{0}", "$arg")
    if ($local) { Write-Host "$($local.Replace('{0}', "$arg"))`n  ($en)" } else { Write-Host $en }
}

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
    Say "Your data.win does not match the game version this mod was built for ({0}). Update/verify the game in Steam, or wait for a mod update." "Ваш data.win не совпадает с версией игры, под которую собран мод ({0}). Обновите/проверьте игру в Steam или дождитесь обновления мода." $cfg.game_version
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
        if ($t0 -match $f.mark) { Say "{0} is modified but has no backup - verify the game files in Steam, then install again." "{0} изменён, но бэкапа нет - проверьте целостность файлов в Steam и установите снова." $f.name; exit 1 }
        Copy-Item $f.path $b
    }
    Copy-Item $b $f.path -Force
}
function Patch-Ui($path, $pattern, $insert, $before, $check, $what) {
    $t = [IO.File]::ReadAllText($path)
    $t = [regex]::Replace($t, $pattern, { param($m) if ($before) { $insert + $m.Value } else { $m.Value + $insert } })
    if ($t -notmatch $check) { Say "Could not patch {0} (unexpected file)." "Не удалось изменить {0} (неожиданный файл)." $what; exit 1 }
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

# 3. Language rows: lang_rows.tsv has a header (key + one column per game language folder); a language the
#    table doesn't know gets the English text.
$rows = @(Get-Content (Join-Path $here "lang_rows.tsv") -Encoding UTF8 | Where-Object { $_ -ne "" })
$cols = $rows[0].Split("`t")
$rows = $rows[1..($rows.Count - 1)]
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
        $ci = [array]::IndexOf($cols, $_.Name)
        if ($ci -lt 1 -or $ci -ge $p.Count -or $p[$ci] -eq "") { $ci = [array]::IndexOf($cols, "english") }
        $val = $p[$ci]
        # the game's CSV: quote texts with commas or quotes
        if ($val -match '[",]') { $val = '"' + $val.Replace('"', '""') + '"' }
        $add += "$n,$($p[0]),Co-op mod,64,$val`r`n"
        $n++
    }
    [IO.File]::WriteAllText($csv, $text + $add, (New-Object Text.UTF8Encoding($true)))
}

Say "Co-op mod installed. Main menu or pause menu > Co-op (or F7)." "Кооп-мод установлен. Главное меню или пауза > Кооператив (или F7)."
