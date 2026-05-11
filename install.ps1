# WinTweaker v2.0 -- One-Liner Installer
# Autor: FloDePin
# Usage: irm https://raw.githubusercontent.com/FloDePin/GameOptimizerPro/main/install.ps1 | iex

$ErrorActionPreference = "Stop"
$url  = "https://raw.githubusercontent.com/FloDePin/GameOptimizerPro/main/WinTweaker_v1.ps1"
$dest = "$env:TEMP\WinTweaker_v1.ps1"

Write-Host ""
Write-Host "  WinTweaker v2.0 Installer" -ForegroundColor Red
Write-Host "  ─────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

Write-Host "  Downloading WinTweaker v2.0..." -ForegroundColor Cyan

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
