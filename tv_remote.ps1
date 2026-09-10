# Exalere TV Remote Controller
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
if (-not (Test-Path $adb)) {
    $adbCmd = Get-Command "adb.exe" -ErrorAction SilentlyContinue
    if ($adbCmd) { $adb = $adbCmd.Source } else { Write-Host "Error: adb.exe not found." -ForegroundColor Red; exit 1 }
}

Clear-Host
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "               EXALERE ANDROID TV REMOTE                " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Use your physical keyboard to control the TV Emulator:  " -ForegroundColor White
Write-Host "                                                          " -ForegroundColor Gray
Write-Host "    [ Arrow Keys ]   : D-Pad Up / Down / Left / Right     " -ForegroundColor Yellow
Write-Host "    [ Enter ]        : OK / Select / Play                 " -ForegroundColor Yellow
Write-Host "    [ Spacebar ]     : Play / Pause Toggle                " -ForegroundColor Yellow
Write-Host "    [ Esc / Bcksp ]  : Back Button                        " -ForegroundColor Yellow
Write-Host "    [ H ]            : Home Button                        " -ForegroundColor Yellow
Write-Host "    [ + / = ]        : Volume Up                          " -ForegroundColor Yellow
Write-Host "    [ - ]            : Volume Down                        " -ForegroundColor Yellow
Write-Host "    [ Q ]            : Quit Remote                        " -ForegroundColor Red
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Ready! Press any key to navigate..." -ForegroundColor Gray

while ($true) {
    $key = [Console]::ReadKey($true)
    switch ($key.Key) {
        "UpArrow"    { & $adb shell input keyevent 19 }
        "DownArrow"  { & $adb shell input keyevent 20 }
        "LeftArrow"  { & $adb shell input keyevent 21 }
        "RightArrow" { & $adb shell input keyevent 22 }
        "Enter"      { & $adb shell input keyevent 23 }
        "Spacebar"   { & $adb shell input keyevent 85 }
        "Escape"     { & $adb shell input keyevent 4 }
        "Backspace"  { & $adb shell input keyevent 4 }
        "H"          { & $adb shell input keyevent 3 }
        "OemPlus"    { & $adb shell input keyevent 24 }
        "Add"        { & $adb shell input keyevent 24 }
        "OemMinus"   { & $adb shell input keyevent 25 }
        "Subtract"   { & $adb shell input keyevent 25 }
        "Q"          { Write-Host "`nExiting TV Remote." -ForegroundColor Cyan; exit 0 }
    }
}
