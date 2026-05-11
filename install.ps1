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
    Write-Host "  Download complete! File size: $((Get-Item $dest).Length) bytes" -ForegroundColor Green
    Write-Host "  Launching as Administrator..." -ForegroundColor Yellow
    Write-Host ""
    $proc = Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -STA -File `"$dest`"" -Verb RunAs -WindowStyle Hidden -PassThru
    Write-Host "  Process started, PID: $($proc.Id)" -ForegroundColor Cyan
    Start-Sleep -Seconds 3
    Write-Host "  Still running: $(-not $proc.HasExited)" -ForegroundColor Cyan
} catch {
    Write-Host "  [ERROR] $_" -ForegroundColor Red
    Read-Host "  Press Enter to exit"
}
Read-Host "  Press Enter to close installer"
