$ErrorActionPreference = "Stop"
$url  = "https://raw.githubusercontent.com/FloDePin/GameOptimizerPro/main/GameOptimizerPro.ps1"
$dest = "$env:TEMP\GameOptimizerPro.ps1"

Write-Host ""
Write-Host "  GameOptimizerPro v3.0 Installer" -ForegroundColor Red
Write-Host "  ─────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Downloading GameOptimizerPro v3.0..." -ForegroundColor Cyan

try {
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
    Write-Host "  Download complete!" -ForegroundColor Green
    Write-Host "  Launching as Administrator..." -ForegroundColor Yellow
    Write-Host ""
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$dest`"" -Verb RunAs
} catch {
    Write-Host "  [ERROR] Download failed: $_" -ForegroundColor Red
    Write-Host "  Make sure you have internet access and the file exists on GitHub." -ForegroundColor Gray
    Write-Host ""
    Read-Host "  Press Enter to exit"
}
