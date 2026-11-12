$ErrorActionPreference = "Stop"
$repo = "https://raw.githubusercontent.com/FloDePin/GameOptimizerPro"
$dest = "$env:TEMP\GameOptimizerPro.ps1"

# SHA256 of the last known-good GameOptimizerPro.ps1 release. Bump this
# whenever GameOptimizerPro.ps1 changes (see CHECKSUMS.txt). This is an
# integrity check against corruption/tampering in transit -- it does not
# replace reading the source, but lets users verify what they're about
# to run with Admin rights without having to read the whole script by hand.
$ExpectedHash = "11ABF776AAFE446D0EA92DC3870D3F404D220DB628A2F3D4A37D787FEA728CA3"

# Keep this in sync with $Script:AppVersion in GameOptimizerPro.ps1 (used for
# display only -- integrity is enforced by $ExpectedHash above, not this string).
$ScriptVersion = "1.2.5"

Write-Host ""
Write-Host "  GameOptimizerPro v$ScriptVersion Installer" -ForegroundColor Red
Write-Host "  ---------------------------------" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Downloading GameOptimizerPro v$ScriptVersion..." -ForegroundColor Cyan

# The copy of this installer's own release tag first: a tag never changes, so it always
# matches $ExpectedHash. "main" is cached by GitHub for up to 5 minutes (a query string
# doesn't get past that cache) and can hand out the previous script right after a
# release -- it is only the fallback for the seconds before the tag exists.
# Without the progress bar: PowerShell 5.1 redraws it for every chunk, which makes the
# download several times slower.
$ProgressPreference = "SilentlyContinue"
$actualHash = $null; $lastError = $null
foreach ($url in "$repo/v$ScriptVersion/GameOptimizerPro.ps1", "$repo/main/GameOptimizerPro.ps1") {
    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
        $actualHash = (Get-FileHash -Path $dest -Algorithm SHA256).Hash
        if ($actualHash -eq $ExpectedHash) { break }
    } catch { $lastError = $_ }
}
if (-not $actualHash) {
    Write-Host "  [ERROR] Download failed: $lastError" -ForegroundColor Red
    Write-Host "  Make sure you have internet access and the file exists on GitHub." -ForegroundColor Gray
    Write-Host ""
    Read-Host "  Press Enter to exit"
    exit
}
Write-Host "  Download complete!" -ForegroundColor Green

# --- INTEGRITY CHECK (SHA256) --- a mismatch never runs
Write-Host "  SHA256: $actualHash" -ForegroundColor DarkGray
if ($actualHash -ne $ExpectedHash) {
    Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue
    Write-Host ""
    Write-Host "  [ERROR] Checksum mismatch -- nothing was started." -ForegroundColor Red
    Write-Host "  Expected: $ExpectedHash" -ForegroundColor Gray
    Write-Host "  Actual:   $actualHash" -ForegroundColor Gray
    Write-Host "  The downloaded file does not match the published checksum in CHECKSUMS.txt" -ForegroundColor Gray
    Write-Host "  (a release a few minutes old, a broken download, or a changed file)." -ForegroundColor Gray
    Write-Host "  Wait a few minutes and run the installer again, or download the script from the" -ForegroundColor Gray
    Write-Host "  Releases page and compare its hash with CHECKSUMS.txt yourself." -ForegroundColor Gray
    Write-Host ""
    Read-Host "  Press Enter to exit"
    exit
}
Write-Host "  Checksum verified OK." -ForegroundColor Green

# Make sure the file is UTF-8 WITH a BOM: Windows PowerShell 5.1 reads BOM-less
# scripts as ANSI. For the published file this rewrite is byte-identical, so the
# file that runs is exactly the one whose hash was checked above.
$raw = [System.IO.File]::ReadAllText($dest, [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText($dest, $raw, (New-Object System.Text.UTF8Encoding($true)))
Write-Host "  Encoding verified (UTF-8)." -ForegroundColor DarkGray

Write-Host "  Launching as Administrator..." -ForegroundColor Yellow
Write-Host ""

# Check if already running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

$launched = $false

if ($isAdmin) {
    # Already admin -- launch the GUI in its own hidden PowerShell process.
    try {
        Start-Process powershell.exe -ArgumentList "-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$dest`"" -WindowStyle Hidden
        $launched = $true
    } catch {
        Write-Host "  [ERROR] Script launch failed: $_" -ForegroundColor Red
        Read-Host "  Press Enter to exit"
    }
} else {
    # Need elevation -- launch the GUI elevated and hidden.
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName        = "powershell.exe"
        $psi.Arguments       = "-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$dest`""
        $psi.Verb            = "runas"
        $psi.UseShellExecute = $true
        $psi.WindowStyle     = "Hidden"

        [System.Diagnostics.Process]::Start($psi) | Out-Null
        $launched = $true
    } catch {
        Write-Host ""
        Write-Host "  [ERROR] Failed to launch as Administrator: $_" -ForegroundColor Red
        Write-Host "  Try running PowerShell as Administrator manually and execute:" -ForegroundColor Gray
        Write-Host "  powershell -ExecutionPolicy Bypass -File `"$dest`"" -ForegroundColor White
        Write-Host ""
        Read-Host "  Press Enter to exit"
    }
}

if ($launched) {
    # Close this PowerShell session so the terminal window disappears.
    # The GUI keeps running in its own hidden process.
    # NOTE: If you ran this via 'irm | iex' in a terminal you want to KEEP,
    # be aware the window will close -- this is intentional (clean launch).
    Write-Host "  GameOptimizerPro is starting. This window will close..." -ForegroundColor DarkGray
    Start-Sleep -Milliseconds 800
    exit
}
