$ErrorActionPreference = "Continue"
$url  = "https://raw.githubusercontent.com/FloDePin/GameOptimizerPro/main/GameOptimizerPro.ps1"
$dest = "$env:TEMP\GameOptimizerPro.ps1"

Write-Host ""
Write-Host "  GameOptimizerPro v1.0 Installer" -ForegroundColor Red
Write-Host "  ─────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Downloading GameOptimizerPro v1.0..." -ForegroundColor Cyan
Write-Host "  Ziel: $dest" -ForegroundColor Gray

try {
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
    $size = (Get-Item $dest).Length
    Write-Host "  Download complete! ($size Bytes)" -ForegroundColor Green

    if ($size -lt 10000) {
        Write-Host "  [WARNUNG] Datei zu klein - GitHub hat evt. alte Version!" -ForegroundColor Yellow
        Read-Host "  Enter zum Beenden"
        exit
    }

    Write-Host "  Starte als Administrator (-STA)..." -ForegroundColor Yellow
    Write-Host ""
    Start-Process powershell.exe -ArgumentList "-STA -ExecutionPolicy Bypass -File `"$dest`"" -Verb RunAs
    Write-Host "  Prozess gestartet. Dieses Fenster kann geschlossen werden." -ForegroundColor Green
    Start-Sleep 3
} catch {
    Write-Host "  [ERROR] $_" -ForegroundColor Red
    Write-Host ""
    Read-Host "  Enter zum Beenden"
}
