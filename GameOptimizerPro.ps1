<#
.SYNOPSIS    GameOptimizerPro - Windows & Gaming Optimizer
.DESCRIPTION GUI-based PowerShell optimizer with checkboxes and info tooltips.
             Tabs: Windows (Debloat) | Gaming | Network | RAM & Storage
.AUTHOR      FloDePin
.VERSION     3.0
#>

# ─────────────────────────────────────────
# SELF-ELEVATION -- kein #Requires, saubere Umleitung
# ─────────────────────────────────────────
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -STA -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# ─────────────────────────────────────────
# WPF ASSEMBLIES (zuerst laden)
# ─────────────────────────────────────────
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# ─────────────────────────────────────────
# KONSOLE SOFORT VERSTECKEN (nach WPF-Load)
# ─────────────────────────────────────────
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class ConsoleWindow {
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]   public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@
[ConsoleWindow]::ShowWindow([ConsoleWindow]::GetConsoleWindow(), 0) | Out-Null

# ─────────────────────────────────────────
# HARDWARE DETECTION
# ─────────────────────────────────────────
$GPU        = (Get-WmiObject Win32_VideoController | Where-Object { $_.Name -notmatch "Microsoft" } | Select-Object -First 1).Name
$CPU        = (Get-WmiObject Win32_Processor | Select-Object -First 1).Name
$RAM        = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
$IsNVIDIA   = $GPU -match "NVIDIA"
$IsAMD      = $GPU -match "AMD|Radeon"
$IsIntelGPU = $GPU -match "Intel"
$HWInfo     = "GPU: $GPU   |   CPU: $CPU   |   RAM: $RAM GB"

# ─────────────────────────────────────────
# LOGGING
# ─────────────────────────────────────────
$LogFile = "$env:TEMP\GameOptimizerPro_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
function Write-Log {
    param([string]$Message)
    $entry = "[$(Get-Date -Format 'HH:mm:ss')] $Message"
    Add-Content -Path $LogFile -Value $entry
}
