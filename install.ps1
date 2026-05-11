#Requires -RunAsAdministrator
<#
.SYNOPSIS
    WinTweaker Installer / Launcher
.DESCRIPTION
    Downloads and runs WinTweaker v2.0 from GitHub.
    Also sets ExecutionPolicy temporarily so the script can run.
.USAGE
    irm https://raw.githubusercontent.com/FloDePin/GameOptimizerPro/main/install.ps1 | iex
#>

$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"

Write-Host ""
Write-Host "  ⚡ WinTweaker v2.0 Installer" -ForegroundColor Red
Write-Host "  ─────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

# Check Admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "  [ERROR] Please run this as Administrator!" -ForegroundColor Red
    Write-Host "  Right-click PowerShell → Run as Administrator" -ForegroundColor Yellow
    pause
    exit 1
}

# Set ExecutionPolicy temporarily
$oldPolicy = Get-ExecutionPolicy -Scope Process
Set-ExecutionPolicy Bypass -Scope Process -Force

# Download script
$url    = "https://raw.githubusercontent.com/FloDePin/GameOptimizerPro/main/WinTweaker_v2.ps1"
$outDir = "$env:TEMP\WinTweaker"
$outFile= "$outDir\WinTweaker_v2.ps1"

Write-Host "  Downloading WinTweaker v2.0..." -ForegroundColor Cyan

if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

try {
    Invoke-WebRequest -Uri $url -OutFile $outFile -UseBasicParsing
    Write-Host "  Download complete!" -ForegroundColor Green
} catch {
    Write-Host "  [ERROR] Download failed: $_" -ForegroundColor Red
    Write-Host "  Make sure you have internet access and the file exists on GitHub." -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host "  Launching WinTweaker..." -ForegroundColor Cyan
Write-Host ""

# Launch
& $outFile

# Restore policy
Set-ExecutionPolicy $oldPolicy -Scope Process -Force
