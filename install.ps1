param()
$ErrorActionPreference = "Stop"
$url  = "https://raw.githubusercontent.com/FloDePin/GameOptimizerPro/main/WinTweaker_v1.ps1"
$dest = "$env:TEMP\WinTweaker_v1.ps1"

Write-Host ""
Write-Host "  WinTweaker v3.0 Installer" -ForegroundColor Red
Write-Host "  -----------------------------" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Downloading WinTweaker v3.0..." -ForegroundColor Cyan

try {
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
    Write-Host "  Download complete!" -ForegroundColor Green
    Write-Host "  Launching as Administrator..." -ForegroundColor Yellow
    Write-Host ""
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$dest`"" -Verb RunAs
} catch {
    Write-Host "  [ERROR] Download failed: $_" -ForegroundColor Red
    Write-Host "  Check your internet connection and GitHub file." -ForegroundColor Gray
    Write-Host ""
    Read-Host "  Press Enter to exit"
}
