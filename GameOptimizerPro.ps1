#Requires -RunAsAdministrator
<#
.SYNOPSIS
    GameOptimizerPro - Windows & Gaming Optimizer
.DESCRIPTION
    GUI-based PowerShell optimizer.
    Tabs: Windows | Gaming | Network | RAM & Storage
.AUTHOR
    FloDePin
.VERSION
    3.0.0
#>

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# Hide Console Window (Win32 API)
$HideConsoleCode = @"
using System;
using System.Runtime.InteropServices;
public class ConsoleHelper {
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]   public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    public const int SW_HIDE = 0;
}
"@
Add-Type -TypeDefinition $HideConsoleCode -ErrorAction SilentlyContinue
$consoleHwnd = [ConsoleHelper]::GetConsoleWindow()
if ($consoleHwnd -ne [IntPtr]::Zero) {
    [ConsoleHelper]::ShowWindow($consoleHwnd, [ConsoleHelper]::SW_HIDE) | Out-Null
}

# Admin Check
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    [System.Windows.MessageBox]::Show("Please run as Administrator!", "GameOptimizerPro", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    exit
}

# Hardware Detection
$GPU        = (Get-WmiObject Win32_VideoController | Where-Object { $_.Name -notmatch "Microsoft" } | Select-Object -First 1).Name
$CPU        = (Get-WmiObject Win32_Processor | Select-Object -First 1).Name
$RAM        = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
$IsNVIDIA   = $GPU -match "NVIDIA"
$IsAMD      = $GPU -match "AMD|Radeon"
$IsIntelGPU = $GPU -match "Intel"
$HWInfo     = "GPU: $GPU   |   CPU: $CPU   |   RAM: $RAM GB"

# Logging
$LogFile = "$env:TEMP\GameOptimizerPro_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
function Write-Log {
    param([string]$Message)
    $entry = "[$(Get-Date -Format 'HH:mm:ss')] $Message"
    Add-Content -Path $LogFile -Value $entry
}