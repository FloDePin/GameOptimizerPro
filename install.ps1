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
} catch {
    Write-Host "  [ERROR] Download failed: $_" -ForegroundColor Red
    Write-Host "  Make sure you have internet access and the file exists on GitHub." -ForegroundColor Gray
    Write-Host ""
    Read-Host "  Press Enter to exit"
    exit
}

Write-Host "  Launching as Administrator..." -ForegroundColor Yellow
Write-Host ""

# Check if already running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin) {
    # Already admin — run directly in same process (WPF GUI works fine)
    try {
        & powershell.exe -ExecutionPolicy Bypass -NonInteractive -File "$dest"
    } catch {
        Write-Host "  [ERROR] Script launch failed: $_" -ForegroundColor Red
        Read-Host "  Press Enter to exit"
    }
} else {
    # Need elevation — launch as admin
    # Use -Wait so this window stays open if it crashes
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName        = "powershell.exe"
        $psi.Arguments       = "-ExecutionPolicy Bypass -NonInteractive -File `"$dest`""
        $psi.Verb            = "runas"
        $psi.UseShellExecute = $true

        $proc = [System.Diagnostics.Process]::Start($psi)
        # Wait for the GUI process to exit
        $proc.WaitForExit()

        if ($proc.ExitCode -ne 0) {
            Write-Host ""
            Write-Host "  [WARN] Process exited with code: $($proc.ExitCode)" -ForegroundColor Yellow
            Write-Host "  Check the log in %TEMP%\GameOptimizerPro_*.log for details." -ForegroundColor Gray
            Read-Host "  Press Enter to exit"
        }
    } catch {
        Write-Host ""
        Write-Host "  [ERROR] Failed to launch as Administrator: $_" -ForegroundColor Red
        Write-Host "  Try running PowerShell as Administrator manually and execute:" -ForegroundColor Gray
        Write-Host "  powershell -ExecutionPolicy Bypass -File `"$dest`"" -ForegroundColor White
        Write-Host ""
        Read-Host "  Press Enter to exit"
    }
}
