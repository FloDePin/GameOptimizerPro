$ErrorActionPreference = "SilentlyContinue"
$url  = "https://raw.githubusercontent.com/FloDePin/GameOptimizerPro/main/GameOptimizerPro.ps1"
$dest = "$env:TEMP\GameOptimizerPro.ps1"

Write-Host ""
Write-Host "  GameOptimizerPro v3.0" -ForegroundColor Red
Write-Host "  ---------------------" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Downloading..." -ForegroundColor Cyan

try {
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
    Write-Host "  Done! Launching..." -ForegroundColor Green
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -STA -File `"$dest`"" -Verb RunAs
} catch {
    Write-Host "  [ERROR] $_" -ForegroundColor Red
    Read-Host "  Press Enter to exit"
}
