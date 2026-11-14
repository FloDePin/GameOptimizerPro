$ErrorActionPreference = "Stop"
$repo = "https://raw.githubusercontent.com/FloDePin/GameOptimizerPro"
$dest = "$env:TEMP\GameOptimizerPro.ps1"

# SHA256 of the last known-good GameOptimizerPro.ps1 release. Bump this
# whenever GameOptimizerPro.ps1 changes (see CHECKSUMS.txt). This is an
# integrity check against corruption/tampering in transit -- it does not
# replace reading the source, but lets users verify what they're about
# to run with Admin rights without having to read the whole script by hand.
$ExpectedHash = "9DA6D2E4F3C8CA73E124EA96A92AFCCA5158C97496C6A8D497DF07114562FF67"

# Keep this in sync with $Script:AppVersion in GameOptimizerPro.ps1. It also picks the
# release tag the script is downloaded from (see below); integrity is $ExpectedHash.
$ScriptVersion = "1.2.6"

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

Write-Host "  Launching as Administrator..." -ForegroundColor Yellow
Write-Host ""

# The elevated PowerShell reads the downloaded file ONCE, checks its SHA256 again and starts
# exactly those bytes from a new folder only administrators can write to. So no other program
# can swap the file in %TEMP% between the check above and the start with admin rights.
# (The published file is UTF-8 with a BOM -- the hash proves these are its exact bytes.)
$loader = @'
try {
    $bytes = [IO.File]::ReadAllBytes('__SRC__')
    $sha = [Security.Cryptography.SHA256]::Create()
    $got = [BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', ''
    if ($got -ne '__HASH__') { throw "the downloaded file changed after the check (SHA256 $got)" }
    $root = Join-Path $env:SystemRoot 'Temp'
    Get-ChildItem -LiteralPath $root -Directory -Filter 'GameOptimizerPro-*' -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    $acl = New-Object Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($sid in 'S-1-5-32-544', 'S-1-5-18') {
        $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule((New-Object Security.Principal.SecurityIdentifier $sid), 'FullControl', 'ContainerInherit, ObjectInherit', 'None', 'Allow')))
    }
    $dir = Join-Path $root ('GameOptimizerPro-' + [guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($dir, $acl)
    $file = Join-Path $dir 'GameOptimizerPro.ps1'
    [IO.File]::WriteAllBytes($file, $bytes)
    & $file
} catch {
    Add-Type -AssemblyName PresentationFramework
    [void][System.Windows.MessageBox]::Show("GameOptimizerPro was not started: $($_.Exception.Message)", 'GameOptimizerPro', 'OK', 'Error')
}
'@
$loader = $loader.Replace('__SRC__', $dest.Replace("'", "''")).Replace('__HASH__', $ExpectedHash)
$psArgs = "-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -EncodedCommand " + [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($loader))

# Check if already running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

$launched = $false

if ($isAdmin) {
    # Already admin -- launch the GUI in its own hidden PowerShell process.
    try {
        Start-Process powershell.exe -ArgumentList $psArgs -WindowStyle Hidden
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
        $psi.Arguments       = $psArgs
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
