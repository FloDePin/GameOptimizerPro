
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    WinTweaker - Windows & Gaming Optimizer
.DESCRIPTION
    GUI-based PowerShell script to optimize Windows for performance, privacy and gaming.
    GitHub: https://github.com/FloDePin/WinTweaker
.AUTHOR
    FloDePin
#>

# ─────────────────────────────────────────────
#  ADMIN CHECK
# ─────────────────────────────────────────────
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# ─────────────────────────────────────────────
#  LOGGING
# ─────────────────────────────────────────────
$LogFile = "$env:TEMP\WinTweaker_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] [$Level] $Message"
    Add-Content -Path $LogFile -Value $line
    Write-Host $line
}

Write-Log "WinTweaker started. Log: $LogFile"

# ─────────────────────────────────────────────
#  HARDWARE AUTO-DETECTION
# ─────────────────────────────────────────────
function Get-HardwareInfo {
    $gpu  = Get-CimInstance Win32_VideoController | Select-Object -First 1
    $cpu  = Get-CimInstance Win32_Processor       | Select-Object -First 1
    $ram  = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)

    $gpuName    = $gpu.Name
    $gpuVram    = [math]::Round($gpu.AdapterRAM / 1GB)
    $gpuVendor  = if ($gpuName -match "NVIDIA") { "NVIDIA" } elseif ($gpuName -match "AMD|Radeon") { "AMD" } else { "Intel" }
    $cpuName    = $cpu.Name
    $cpuVendor  = if ($cpuName -match "Intel") { "Intel" } else { "AMD" }

    return [PSCustomObject]@{
        GPUName   = $gpuName
        GPUVram   = $gpuVram
        GPUVendor = $gpuVendor
        CPUName   = $cpuName
        CPUVendor = $cpuVendor
        RAM       = $ram
    }
}

$HW = Get-HardwareInfo
Write-Log "GPU: $($HW.GPUName) ($($HW.GPUVram) GB) | CPU: $($HW.CPUName) | RAM: $($HW.RAM) GB"

# ─────────────────────────────────────────────
#  HELPER FUNCTIONS
# ─────────────────────────────────────────────
function Set-RegistryValue {
    param([string]$Path, [string]$Name, $Value, [string]$Type = "DWord")
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
}

function Remove-RegistryValue {
    param([string]$Path, [string]$Name)
    if (Test-Path $Path) {
        Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction SilentlyContinue
    }
}

function Show-Status {
    param([string]$Message, [System.Windows.Controls.TextBox]$Box)
    $ts = Get-Date -Format "HH:mm:ss"
    $Box.Dispatcher.Invoke([action]{
        $Box.AppendText("[$ts] $Message`r`n")
        $Box.ScrollToEnd()
    })
    Write-Log $Message
}

# ─────────────────────────────────────────────
#  RESTORE POINT
# ─────────────────────────────────────────────
function New-RestorePointIfNeeded {
    param([System.Windows.Controls.TextBox]$Box)
    try {
        Show-Status "Creating System Restore Point..." $Box
        Enable-ComputerRestore -Drive "$env:SystemDrive\"
        Checkpoint-Computer -Description "WinTweaker Backup $(Get-Date -Format 'yyyy-MM-dd')" -RestorePointType MODIFY_SETTINGS
        Show-Status "✅ Restore Point created." $Box
    } catch {
        Show-Status "⚠️  Restore Point failed (may already exist today): $_" $Box
    }
}

# ═══════════════════════════════════════════════
#  WINDOWS TWEAKS
# ═══════════════════════════════════════════════

function Remove-Bloatware {
    param([System.Windows.Controls.TextBox]$Box)
    Show-Status "🗑️  Starting Bloatware removal..." $Box

    $apps = @(
        "Microsoft.BingNews", "Microsoft.BingWeather", "Microsoft.BingFinance",
        "Microsoft.BingSports", "Microsoft.BingSearch",
        "Microsoft.Cortana", "Microsoft.549981C3F5F10",
        "Microsoft.Xbox.TCUI", "Microsoft.XboxApp", "Microsoft.XboxGameOverlay",
        "Microsoft.XboxGamingOverlay", "Microsoft.XboxIdentityProvider",
        "Microsoft.XboxSpeechToTextOverlay", "Microsoft.GamingApp",
        "Microsoft.MicrosoftSolitaireCollection", "Microsoft.MicrosoftMahjong",
        "Microsoft.ZuneMusic", "Microsoft.ZuneVideo",
        "Microsoft.People", "Microsoft.Wallet",
        "Microsoft.WindowsFeedbackHub", "Microsoft.WindowsMaps",
        "Microsoft.WindowsSoundRecorder", "Microsoft.YourPhone",
        "Microsoft.GetHelp", "Microsoft.Getstarted",
        "Microsoft.MixedReality.Portal", "Microsoft.SkypeApp",
        "Microsoft.Teams", "MicrosoftTeams",
        "Microsoft.Todos", "Microsoft.PowerAutomateDesktop",
        "Microsoft.WindowsCommunicationsApps",
        "Clipchamp.Clipchamp", "MicrosoftCorporationII.MicrosoftFamily"
    )

    foreach ($app in $apps) {
        $pkg = Get-AppxPackage -Name $app -AllUsers -ErrorAction SilentlyContinue
        if ($pkg) {
            Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction SilentlyContinue
            Show-Status "  Removed: $app" $Box
        }
        Get-AppxProvisionedPackage -Online | Where-Object DisplayName -EQ $app | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    }

    # Remove OneDrive
    Show-Status "  Removing OneDrive..." $Box
    Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
    $odu = "$env:SystemRoot\System32\OneDriveSetup.exe"
    if (-not (Test-Path $odu)) { $odu = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" }
    if (Test-Path $odu) { Start-Process $odu -ArgumentList "/uninstall" -Wait }
    Remove-Item "$env:USERPROFILE\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:LOCALAPPDATA\Microsoft\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
    Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableFileSyncNGSC" 1

    # Disable Copilot
    Show-Status "  Disabling Copilot..." $Box
    Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1
    Set-RegistryValue "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1

    # Disable Recall
    Show-Status "  Disabling Recall..." $Box
    Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis" 1
    DISM /Online /Disable-Feature /FeatureName:Recall /NoRestart 2>$null

    Show-Status "✅ Bloatware removal complete." $Box
}

function Set-PrivacyTweaks {
    param([System.Windows.Controls.TextBox]$Box)
    Show-Status "🔒 Applying Privacy & Telemetry tweaks..." $Box

    # Disable Telemetry
    Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0
    Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry" 0
    Set-RegistryValue "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry" 0

    # Disable DiagTrack
    $services = @("DiagTrack","dmwappushservice","WerSvc","PcaSvc","SysMain","WSearch")
    foreach ($svc in $services) {
        Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
        Set-Service  -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
        Show-Status "  Service disabled: $svc" $Box
    }

    # Disable Activity History
    Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableActivityFeed" 0
    Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "PublishUserActivities" 0

    # Disable Advertising ID
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 0
    Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" "DisabledByGroupPolicy" 1

    # Disable Location
    Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" "DisableLocation" 1

    # Disable Feedback
    Set-RegistryValue "HKCU:\Software\Microsoft\Siuf\Rules" "NumberOfSIUFInPeriod" 0
    Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "DoNotShowFeedbackNotifications" 1

    # Block telemetry hosts via HOSTS file
    $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
    $telemetryHosts = @(
        "vortex.data.microsoft.com","vortex-win.data.microsoft.com",
        "telecommand.telemetry.microsoft.com","telecommand.telemetry.microsoft.com.nsatc.net",
        "oca.telemetry.microsoft.com","oca.telemetry.microsoft.com.nsatc.net",
        "sqm.telemetry.microsoft.com","sqm.telemetry.microsoft.com.nsatc.net",
        "watson.telemetry.microsoft.com","watson.telemetry.microsoft.com.nsatc.net",
        "redir.metaservices.microsoft.com","choice.microsoft.com",
        "choice.microsoft.com.nsatc.net","df.telemetry.microsoft.com"
    )
    $hostsContent = Get-Content $hostsPath -ErrorAction SilentlyContinue
    foreach ($host in $telemetryHosts) {
        $entry = "0.0.0.0 $host"
        if ($hostsContent -notcontains $entry) {
            Add-Content -Path $hostsPath -Value $entry
        }
    }
    Show-Status "  Telemetry hosts blocked in HOSTS file." $Box
    Show-Status "✅ Privacy tweaks applied." $Box
}

function Set-PerformanceTweaks {
    param([System.Windows.Controls.TextBox]$Box)
    Show-Status "🚀 Applying Performance tweaks..." $Box

    # Ultimate Performance Plan
    $up = powercfg -list | Select-String "Ultimate"
    if (-not $up) {
        powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 | Out-Null
        Show-Status "  Ultimate Performance plan created." $Box
    }
    $upGuid = (powercfg -list | Select-String "Ultimate" | ForEach-Object { ($_ -split "\s+")[3] }) | Select-Object -First 1
    if ($upGuid) { powercfg -setactive $upGuid; Show-Status "  Ultimate Performance plan activated." $Box }

    # HAGS (Hardware Accelerated GPU Scheduling)
    Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 2
    Show-Status "  HAGS enabled." $Box

    # Timer Resolution (0.5ms)
    bcdedit /set useplatformtick yes    | Out-Null
    bcdedit /set disabledynamictick yes | Out-Null
    bcdedit /set tscsyncpolicy Enhanced | Out-Null
    Show-Status "  Timer resolution set to 0.5ms." $Box

    # Page File — System Managed
    $cs = Get-CimInstance Win32_ComputerSystem
    $cs | Set-CimInstance -Property @{ AutomaticManagedPagefile = $true }
    Show-Status "  Page file set to system-managed." $Box

    # Disable Xbox Game Bar DVR
    Set-RegistryValue "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 0
    Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" 0

    # Disable Fullscreen Optimizations
    Set-RegistryValue "HKCU:\System\GameConfigStore" "GameDVR_FSEBehaviorMode" 2
    Set-RegistryValue "HKCU:\System\GameConfigStore" "GameDVR_HonorUserFSEBehaviorMode" 1

    # CPU Priority for Games
    Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 26

    # Disable Power Throttling
    Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" "PowerThrottlingOff" 1

    # Visual Effects — Performance
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 2

    Show-Status "✅ Performance tweaks applied." $Box
}

function Set-MouseAndUI {
    param([System.Windows.Controls.TextBox]$Box)
    Show-Status "🖱️  Applying Mouse & UI tweaks..." $Box

    # Disable Mouse Acceleration
    Set-RegistryValue "HKCU:\Control Panel\Mouse" "MouseThreshold1" "0" -Type String
    Set-RegistryValue "HKCU:\Control Panel\Mouse" "MouseThreshold2" "0" -Type String
    Set-RegistryValue "HKCU:\Control Panel\Mouse" "MouseSpeed"      "0" -Type String
    Show-Status "  Mouse acceleration disabled." $Box

    # Disable Sticky Keys
    Set-RegistryValue "HKCU:\Control Panel\Accessibility\StickyKeys"   "Flags" "506" -Type String
    Set-RegistryValue "HKCU:\Control Panel\Accessibility\ToggleKeys"   "Flags" "58"  -Type String
    Set-RegistryValue "HKCU:\Control Panel\Accessibility\Keyboard Response" "Flags" "122" -Type String
    Show-Status "  Sticky Keys disabled." $Box

    # Dark Mode
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme"   0
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "SystemUsesLightTheme" 0
    Show-Status "  Dark Mode enabled." $Box

    # Disable Animations
    Set-RegistryValue "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate" "0" -Type String
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAnimations" 0
    Show-Status "  Animations disabled." $Box

    # Disable Transparency
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 0

    # Show File Extensions
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 0

    Show-Status "✅ Mouse & UI tweaks applied." $Box
}

# ═══════════════════════════════════════════════
#  GAMING TWEAKS
# ═══════════════════════════════════════════════

function Set-GPUTweaks {
    param([System.Windows.Controls.TextBox]$Box)
    Show-Status "📊 Applying GPU & Driver tweaks for $($HW.GPUVendor) ($($HW.GPUName))..." $Box

    # HAGS
    Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 2
    Show-Status "  HAGS enabled." $Box

    if ($HW.GPUVendor -eq "NVIDIA") {
        Show-Status "  Applying NVIDIA-specific tweaks..." $Box

        # MSI Mode for NVIDIA GPU
        $nvDevices = Get-PnpDevice | Where-Object { $_.FriendlyName -like "*NVIDIA*" -and $_.Class -eq "Display" }
        foreach ($dev in $nvDevices) {
            $devPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($dev.InstanceId)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
            Set-RegistryValue $devPath "MSISupported" 1
            Show-Status "  MSI Mode enabled for: $($dev.FriendlyName)" $Box
        }

        # NVIDIA Low Latency (Ultra Low Latency Mode)
        Set-RegistryValue "HKCU:\Software\NVIDIA Corporation\Global\NvTweak" "NvCplGlassEnabled" 0
        Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak" "EnableMidBufferPreemption" 0
        Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak" "EnableCEPreemption"       0
        Show-Status "  NVIDIA Low Latency Mode configured." $Box

        # Shader Cache
        Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak" "EnableShaderCache" 1
        Show-Status "  NVIDIA Shader Cache enabled." $Box

        # Disable HDCP
        Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak" "RMHdcpKeyglobZero" 1

    } elseif ($HW.GPUVendor -eq "AMD") {
        Show-Status "  Applying AMD-specific tweaks..." $Box

        # MSI Mode for AMD GPU
        $amdDevices = Get-PnpDevice | Where-Object { ($_.FriendlyName -like "*AMD*" -or $_.FriendlyName -like "*Radeon*") -and $_.Class -eq "Display" }
        foreach ($dev in $amdDevices) {
            $devPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($dev.InstanceId)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
            Set-RegistryValue $devPath "MSISupported" 1
            Show-Status "  MSI Mode enabled for: $($dev.FriendlyName)" $Box
        }

        # AMD Shader Cache
        Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Services\amdkmdap\Parameters" "EnableShaderCache" 1
        Show-Status "  AMD Shader Cache enabled." $Box

        # AMD Anti-Lag (registry hint)
        Set-RegistryValue "HKCU:\Software\ATI\ACE\Settings\ADL\GISettingsManager" "FRTC_Level" 0
        Show-Status "  AMD tweaks applied." $Box

    } else {
        Show-Status "  Intel GPU detected — applying generic tweaks." $Box
        $intelDevices = Get-PnpDevice | Where-Object { $_.FriendlyName -like "*Intel*" -and $_.Class -eq "Display" }
        foreach ($dev in $intelDevices) {
            $devPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($dev.InstanceId)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
            Set-RegistryValue $devPath "MSISupported" 1
        }
    }

    # CPU MSI Mode
    if ($HW.CPUVendor -eq "Intel") {
        Show-Status "  Applying Intel CPU tweaks..." $Box
        Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "GlobalTimerResolutionRequests" 1
    } else {
        Show-Status "  Applying AMD CPU tweaks..." $Box
        Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "GlobalTimerResolutionRequests" 1
    }

    Show-Status "✅ GPU & Driver tweaks applied." $Box
}

function Set-InGameBoosts {
    param([System.Windows.Controls.TextBox]$Box)
    Show-Status "⚡ Applying In-Game Boosts..." $Box

    # Game Mode
    Set-RegistryValue "HKCU:\Software\Microsoft\GameBar" "AllowAutoGameMode"  1
    Set-RegistryValue "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" 1
    Show-Status "  Game Mode enabled." $Box

    # CPU Priority for Games
    Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 26
    Show-Status "  CPU Priority (Win32PrioritySeparation=26) set." $Box

    # MMCSS — Games High Priority
    Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "GPU Priority"      8
    Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Priority"         6
    Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Scheduling Category" "High" -Type String
    Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 0
    Show-Status "  MMCSS Games priority set to High." $Box

    # Disable Xbox DVR & Game Bar
    Set-RegistryValue "HKCU:\System\GameConfigStore"                           "GameDVR_Enabled"             0
    Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"      "AllowGameDVR"                0
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled"           0
    Show-Status "  Xbox DVR / Game Bar disabled." $Box

    # Disable Fullscreen Optimizations globally
    Set-RegistryValue "HKCU:\System\GameConfigStore" "GameDVR_FSEBehaviorMode"           2
    Set-RegistryValue "HKCU:\System\GameConfigStore" "GameDVR_HonorUserFSEBehaviorMode"  1
    Show-Status "  Fullscreen Optimizations disabled." $Box

    # Timer Resolution 0.5ms
    bcdedit /set useplatformtick yes     | Out-Null
    bcdedit /set disabledynamictick yes  | Out-Null
    Show-Status "  Timer resolution 0.5ms applied." $Box

    Show-Status "✅ In-Game Boosts applied." $Box
}

# ═══════════════════════════════════════════════
#  NETWORK TWEAKS
# ═══════════════════════════════════════════════

function Set-NetworkTweaks {
    param([System.Windows.Controls.TextBox]$Box)
    Show-Status "🌐 Applying Network tweaks..." $Box

    # TCP Auto-Tuning — Normal
    netsh int tcp set global autotuninglevel=normal | Out-Null
    Show-Status "  TCP Auto-Tuning set to Normal." $Box

    # Disable Nagle's Algorithm on all adapters
    $adapters = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\*" -ErrorAction SilentlyContinue
    $ifaceKeys = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" -ErrorAction SilentlyContinue
    foreach ($key in $ifaceKeys) {
        Set-RegistryValue $key.PSPath "TcpAckFrequency" 1
        Set-RegistryValue $key.PSPath "TCPNoDelay"      1
        Set-RegistryValue $key.PSPath "TcpDelAckTicks"  0
    }
    Show-Status "  Nagle's Algorithm disabled (TCPNoDelay) on all adapters." $Box

    # Cloudflare DNS (1.1.1.1 / 1.0.0.1)
    $nics = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
    foreach ($nic in $nics) {
        Set-DnsClientServerAddress -InterfaceIndex $nic.InterfaceIndex -ServerAddresses @("1.1.1.1","1.0.0.1") -ErrorAction SilentlyContinue
        Show-Status "  Cloudflare DNS set on: $($nic.Name)" $Box
    }

    # Disable QoS Packet Scheduler reservation (reserve 0%)
    Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" "NonBestEffortLimit" 0
    Show-Status "  QoS bandwidth reservation set to 0%." $Box

    # Disable Large Send Offload (LSO)
    $netAdapters = Get-NetAdapterAdvancedProperty -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*Large Send Offload*" }
    foreach ($prop in $netAdapters) {
        Disable-NetAdapterLso -Name $prop.Name -ErrorAction SilentlyContinue
        Show-Status "  LSO disabled on: $($prop.Name)" $Box
    }

    # Disable Network Throttling
    Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 0xFFFFFFFF

    # ECN Capability
    netsh int tcp set global ecncapability=disabled | Out-Null
    Show-Status "  ECN disabled." $Box

    # RSS
    netsh int tcp set global rss=enabled | Out-Null
    Show-Status "  RSS enabled." $Box

    # Flush DNS
    ipconfig /flushdns | Out-Null
    Show-Status "  DNS cache flushed." $Box

    Show-Status "✅ Network tweaks applied." $Box
}

# ═══════════════════════════════════════════════
#  FULL RUN
# ═══════════════════════════════════════════════

function Invoke-FullRun {
    param([System.Windows.Controls.TextBox]$Box)
    New-RestorePointIfNeeded $Box
    Remove-Bloatware     $Box
    Set-PrivacyTweaks    $Box
    Set-PerformanceTweaks $Box
    Set-MouseAndUI       $Box
    Set-GPUTweaks        $Box
    Set-InGameBoosts     $Box
    Set-NetworkTweaks    $Box
    Show-Status "🎉 Full Run complete! Please restart your PC." $Box
}

# ═══════════════════════════════════════════════
#  GUI — WPF
# ═══════════════════════════════════════════════

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

[xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="WinTweaker v1.0 — by FloDePin"
    Width="780" Height="620"
    WindowStartupLocation="CenterScreen"
    Background="#1a1a2e">

    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#16213e"/>
            <Setter Property="Foreground" Value="#e0e0e0"/>
            <Setter Property="BorderBrush" Value="#0f3460"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="12,8"/>
            <Setter Property="Margin" Value="5"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="6"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#0f3460"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter Property="Background" Value="#533483"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="TabItem">
            <Setter Property="Background" Value="#16213e"/>
            <Setter Property="Foreground" Value="#a0a0c0"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="Padding" Value="15,8"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TabItem">
                        <Border Name="Border" Background="{TemplateBinding Background}"
                                BorderBrush="#0f3460" BorderThickness="1,1,1,0"
                                CornerRadius="6,6,0,0" Margin="2,0">
                            <ContentPresenter x:Name="ContentSite"
                                VerticalAlignment="Center" HorizontalAlignment="Center"
                                ContentSource="Header" Margin="{TemplateBinding Padding}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="Border" Property="Background" Value="#0f3460"/>
                                <Setter Property="Foreground" Value="#ffffff"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Border" Property="Background" Value="#1a3a6e"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="180"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <StackPanel Grid.Row="0" Margin="0,0,0,10">
            <TextBlock Text="⚡ WinTweaker" FontSize="26" FontWeight="Bold"
                       Foreground="#e94560" HorizontalAlignment="Center"/>
            <TextBlock Text="Windows &amp; Gaming Optimizer — by FloDePin"
                       FontSize="12" Foreground="#a0a0c0" HorizontalAlignment="Center" Margin="0,2,0,0"/>
        </StackPanel>

        <!-- HW Info -->
        <Border Grid.Row="1" Background="#16213e" BorderBrush="#0f3460" BorderThickness="1"
                CornerRadius="6" Padding="10,6" Margin="0,0,0,8">
            <TextBlock Name="HwInfo" FontSize="12" Foreground="#00d4aa" FontFamily="Consolas"/>
        </Border>

        <!-- Tabs -->
        <TabControl Grid.Row="2" Background="#1a1a2e" BorderBrush="#0f3460" Margin="0,0,0,8">

            <!-- WINDOWS TAB -->
            <TabItem Header="🪟  Windows">
                <StackPanel Background="#1a1a2e" Margin="10">
                    <TextBlock Text="Windows Optimizations" Foreground="#e94560"
                               FontSize="15" FontWeight="Bold" Margin="0,0,0,10"/>
                    <UniformGrid Columns="2" Rows="2">
                        <Button Name="BtnBloat"    Content="🗑️  Remove Bloatware"/>
                        <Button Name="BtnPrivacy"  Content="🔒  Privacy &amp; Telemetry"/>
                        <Button Name="BtnPerf"     Content="🚀  Performance Tweaks"/>
                        <Button Name="BtnMouse"    Content="🖱️  Mouse &amp; UI"/>
                    </UniformGrid>
                </StackPanel>
            </TabItem>

            <!-- GAMING TAB -->
            <TabItem Header="🎮  Gaming">
                <StackPanel Background="#1a1a2e" Margin="10">
                    <TextBlock Text="Gaming Optimizations" Foreground="#e94560"
                               FontSize="15" FontWeight="Bold" Margin="0,0,0,10"/>
                    <UniformGrid Columns="2" Rows="1">
                        <Button Name="BtnGPU"      Content="📊  GPU &amp; Driver Tweaks"/>
                        <Button Name="BtnInGame"   Content="⚡  In-Game Boosts"/>
                    </UniformGrid>
                </StackPanel>
            </TabItem>

            <!-- NETWORK TAB -->
            <TabItem Header="🌐  Network">
                <StackPanel Background="#1a1a2e" Margin="10">
                    <TextBlock Text="Network Optimizations" Foreground="#e94560"
                               FontSize="15" FontWeight="Bold" Margin="0,0,0,10"/>
                    <Button Name="BtnNet" Content="🌐  Apply Network Tweaks (Nagle off, Cloudflare DNS, QoS, TCP)" Width="400" HorizontalAlignment="Left"/>
                </StackPanel>
            </TabItem>

            <!-- SYSTEM TAB -->
            <TabItem Header="⚙️  System">
                <StackPanel Background="#1a1a2e" Margin="10">
                    <TextBlock Text="System Actions" Foreground="#e94560"
                               FontSize="15" FontWeight="Bold" Margin="0,0,0,10"/>
                    <UniformGrid Columns="2" Rows="1">
                        <Button Name="BtnAll"     Content="🎯  Full Run (Everything)"  Background="#0f3460"/>
                        <Button Name="BtnRestore" Content="💾  Create Restore Point"/>
                    </UniformGrid>
                    <TextBlock Margin="5,15,5,0" Foreground="#606080" FontSize="11"
                        Text="⚠️  Full Run applies ALL tweaks. A Restore Point will be created first.&#x0a;Log file saved to: %TEMP%\WinTweaker_*.log"/>
                </StackPanel>
            </TabItem>

        </TabControl>

        <!-- Status Log -->
        <Border Grid.Row="3" Background="#0d0d1a" BorderBrush="#0f3460" BorderThickness="1" CornerRadius="6">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                <TextBlock Grid.Row="0" Text=" 📋 Output Log" Foreground="#a0a0c0"
                           FontSize="11" Margin="5,4,0,2"/>
                <TextBox Grid.Row="1" Name="StatusBox"
                         Background="#0d0d1a" Foreground="#00ff88"
                         FontFamily="Consolas" FontSize="11"
                         IsReadOnly="True" TextWrapping="Wrap"
                         VerticalScrollBarVisibility="Auto"
                         BorderThickness="0" Margin="5,0,5,5"/>
            </Grid>
        </Border>

    </Grid>
</Window>
"@

$reader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get controls
$StatusBox  = $window.FindName("StatusBox")
$HwInfoBox  = $window.FindName("HwInfo")
$BtnBloat   = $window.FindName("BtnBloat")
$BtnPrivacy = $window.FindName("BtnPrivacy")
$BtnPerf    = $window.FindName("BtnPerf")
$BtnMouse   = $window.FindName("BtnMouse")
$BtnGPU     = $window.FindName("BtnGPU")
$BtnInGame  = $window.FindName("BtnInGame")
$BtnNet     = $window.FindName("BtnNet")
$BtnAll     = $window.FindName("BtnAll")
$BtnRestore = $window.FindName("BtnRestore")

# HW Info display
$HwInfoBox.Text = "🖥️  GPU: $($HW.GPUName)  ($($HW.GPUVram) GB, $($HW.GPUVendor))   |   CPU: $($HW.CPUName) ($($HW.CPUVendor))   |   RAM: $($HW.RAM) GB"

# Button click handlers (run in background jobs to keep GUI responsive)
function Invoke-Async {
    param([scriptblock]$Action, [System.Windows.Controls.TextBox]$Box)
    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = "STA"
    $rs.ThreadOptions   = "ReuseThread"
    $rs.Open()
    $rs.SessionStateProxy.SetVariable("StatusBox", $Box)
    $rs.SessionStateProxy.SetVariable("HW", $HW)
    $ps = [powershell]::Create()
    $ps.Runspace = $rs

    # Pass helper functions into runspace
    $helpers = @(
        ${function:Write-Log},
        ${function:Set-RegistryValue},
        ${function:Remove-RegistryValue},
        ${function:Show-Status}
    )
    $ps.AddScript({
        param($helpers, $action, $StatusBox, $HW, $LogFile)
        # Re-define helpers
        New-Item -Path function:Write-Log          -Value $helpers[0] -Force | Out-Null
        New-Item -Path function:Set-RegistryValue  -Value $helpers[1] -Force | Out-Null
        New-Item -Path function:Remove-RegistryValue -Value $helpers[2] -Force | Out-Null
        New-Item -Path function:Show-Status        -Value $helpers[3] -Force | Out-Null
        & $action $StatusBox
    }).AddArgument($helpers).AddArgument($Action).AddArgument($Box).AddArgument($HW).AddArgument($LogFile) | Out-Null
    $ps.BeginInvoke() | Out-Null
}

$BtnBloat.Add_Click({   Invoke-Async ${function:Remove-Bloatware}      $StatusBox })
$BtnPrivacy.Add_Click({ Invoke-Async ${function:Set-PrivacyTweaks}     $StatusBox })
$BtnPerf.Add_Click({    Invoke-Async ${function:Set-PerformanceTweaks} $StatusBox })
$BtnMouse.Add_Click({   Invoke-Async ${function:Set-MouseAndUI}        $StatusBox })
$BtnGPU.Add_Click({     Invoke-Async ${function:Set-GPUTweaks}         $StatusBox })
$BtnInGame.Add_Click({  Invoke-Async ${function:Set-InGameBoosts}      $StatusBox })
$BtnNet.Add_Click({     Invoke-Async ${function:Set-NetworkTweaks}     $StatusBox })
$BtnAll.Add_Click({     Invoke-Async ${function:Invoke-FullRun}        $StatusBox })
$BtnRestore.Add_Click({ Invoke-Async ${function:New-RestorePointIfNeeded} $StatusBox })

Show-Status "WinTweaker ready. Hardware detected: $($HW.GPUVendor) GPU / $($HW.CPUVendor) CPU" $StatusBox

$window.ShowDialog() | Out-Null
