$ErrorActionPreference = "Stop"
$url  = "https://raw.githubusercontent.com/FloDePin/GameOptimizerPro/main/GameOptimizerPro.ps1"
$dest = "$env:TEMP\GameOptimizerPro.ps1"

Write-Host ""
Write-Host "  GameOptimizerPro v1.0 Installer" -ForegroundColor Red
Write-Host "  ─────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Downloading GameOptimizerPro v1.0..." -ForegroundColor Cyan

try {
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
    Write-Host "  Download complete!" -ForegroundColor Green
    Write-Host "  Launching as Administrator..." -ForegroundColor Yellow
    Write-Host ""
    # -STA ist PFLICHT fuer WPF-GUIs; -NoProfile beschleunigt den Start
    Start-Process powershell -ArgumentList "-STA -ExecutionPolicy Bypass -NoProfile -File `"$dest`"" -Verb RunAs
    Write-Host "  GameOptimizerPro wurde gestartet!" -ForegroundColor Green
} catch {
    Write-Host "  [ERROR] Download fehlgeschlagen: $_" -ForegroundColor Red
    Write-Host "  Stelle sicher dass du mit dem Internet verbunden bist." -ForegroundColor Gray
    Write-Host ""
}

# Fenster offen halten damit Meldungen lesbar bleiben
Read-Host "`n  Druecke Enter zum Beenden"
