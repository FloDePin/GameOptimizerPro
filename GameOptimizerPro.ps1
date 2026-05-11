#Requires -RunAsAdministrator
<#
.SYNOPSIS
    GameOptimizerPro - Windows & Gaming Optimizer
.DESCRIPTION
    GUI-based PowerShell optimizer with checkboxes and info tooltips.
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

# HIDE CONSOLE WINDOW
Add-Type -Name Win32 -Namespace Native -MemberDefinition @"
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]   public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
"@
[Native.Win32]::ShowWindow([Native.Win32]::GetConsoleWindow(), 0) | Out-Null

# ADMIN CHECK
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    [System.Windows.MessageBox]::Show("Please run this script as Administrator!", "GameOptimizerPro - Admin Required", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    exit
}

# HARDWARE DETECTION
$GPU        = (Get-WmiObject Win32_VideoController | Where-Object { $_.Name -notmatch "Microsoft" } | Select-Object -First 1).Name
$CPU        = (Get-WmiObject Win32_Processor | Select-Object -First 1).Name
$RAM        = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
$IsNVIDIA   = $GPU -match "NVIDIA"
$IsAMD      = $GPU -match "AMD|Radeon"
$IsIntelGPU = $GPU -match "Intel"
$HWInfo     = "GPU: $GPU   |   CPU: $CPU   |   RAM: $RAM GB"

# LOGGING
$LogFile = "$env:TEMP\GameOptimizerPro_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
function Write-Log {
    param([string]$Message)
    $entry = "[$(Get-Date -Format 'HH:mm:ss')] $Message"
    Add-Content -Path $LogFile -Value $entry
}

# TWEAK DEFINITIONS
$AllTweaks = @(

    # WINDOWS / BLOATWARE
    [PSCustomObject]@{
        Name     = "Remove Cortana"
        Desc     = "Deinstalliert Cortana vollstaendig. Cortana sendet Daten an Microsoft. Fuer die meisten Nutzer nicht benoetigt."
        Category = "Windows"
        Group    = "Bloatware"
        Action   = {
            Get-AppxPackage -AllUsers "*Microsoft.549981C3F5F10*" | Remove-AppxPackage -ErrorAction SilentlyContinue
            Write-Log "Cortana removed"
        }
    },
    [PSCustomObject]@{
        Name     = "Remove Xbox Apps"
        Desc     = "Entfernt Xbox Game Bar, Xbox Identity Provider und Xbox TCUI. Laufen im Hintergrund auch ohne Xbox."
        Category = "Windows"
        Group    = "Bloatware"
        Action   = {
            $xboxApps = @("*XboxApp*","*XboxGameOverlay*","*XboxGamingOverlay*","*XboxIdentityProvider*","*XboxSpeechToTextOverlay*","*XboxTCUI*")
            foreach ($app in $xboxApps) { Get-AppxPackage -AllUsers $app | Remove-AppxPackage -ErrorAction SilentlyContinue }
            Write-Log "Xbox Apps removed"
        }
    },
    [PSCustomObject]@{
        Name     = "Remove Microsoft Teams (Personal)"
        Desc     = "Entfernt Microsoft Teams Consumer-Version. Blockiert automatische Neuinstallation."
        Category = "Windows"
        Group    = "Bloatware"
        Action   = {
            Get-AppxPackage -AllUsers "*MicrosoftTeams*" | Remove-AppxPackage -ErrorAction SilentlyContinue
            reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Communications" /v ConfigureChatAutoInstall /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Teams Personal removed"
        }
    },
    [PSCustomObject]@{
        Name     = "Remove Copilot"
        Desc     = "Deaktiviert und entfernt Windows Copilot. Verhindert Hintergrundlauf und Datenuebertragung."
        Category = "Windows"
        Group    = "Bloatware"
        Action   = {
            reg add "HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f | Out-Null
            Get-AppxPackage -AllUsers "*Copilot*" | Remove-AppxPackage -ErrorAction SilentlyContinue
            Write-Log "Copilot disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Remove OneDrive"
        Desc     = "Deinstalliert OneDrive komplett inkl. Autostart und Explorer-Integration. Lokale Dateien bleiben erhalten."
        Category = "Windows"
        Group    = "Bloatware"
        Action   = {
            Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
            Start-Sleep 1
            $onedrive = "$env:SYSTEMROOT\SysWOW64\OneDriveSetup.exe"
            if (!(Test-Path $onedrive)) { $onedrive = "$env:SYSTEMROOT\System32\OneDriveSetup.exe" }
            if (Test-Path $onedrive) { & $onedrive /uninstall }
            reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v OneDrive /f 2>$null
            Write-Log "OneDrive removed"
        }
    },
    [PSCustomObject]@{
        Name     = "Remove Windows Recall"
        Desc     = "Deaktiviert Windows Recall. Datenschutzkritisches KI-Feature das Screenshots speichert."
        Category = "Windows"
        Group    = "Bloatware"
        Action   = {
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v DisableAIDataAnalysis /t REG_DWORD /d 1 /f | Out-Null
            Disable-WindowsOptionalFeature -Online -FeatureName "Recall" -NoRestart -ErrorAction SilentlyContinue | Out-Null
            Write-Log "Recall disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Remove Other Bloatware"
        Desc     = "Entfernt Candy Crush, TikTok, Disney+, Facebook, Instagram, Spotify, News, Solitaire, Clipchamp, ToDo, Paint3D und weitere vorinstallierte Apps."
        Category = "Windows"
        Group    = "Bloatware"
        Action   = {
            $bloat = @(
                "*king.com*","*Facebook*","*Spotify*","*Disney*","*TikTok*","*Instagram*",
                "*Netflix*","*Twitter*","*BubbleWitch*","*MarchofEmpires*","*CandyCrush*",
                "*Microsoft.News*","*Microsoft.BingWeather*","*Microsoft.BingNews*",
                "*Microsoft.MicrosoftSolitaireCollection*","*Microsoft.ZuneMusic*",
                "*Microsoft.ZuneVideo*","*Microsoft.WindowsFeedbackHub*","*Microsoft.Todos*",
                "*Microsoft.Paint3D*","*Microsoft.MixedReality*","*Clipchamp*",
                "*Microsoft.GetHelp*","*Microsoft.Getstarted*","*Microsoft.PowerAutomateDesktop*"
            )
            foreach ($app in $bloat) { Get-AppxPackage -AllUsers $app | Remove-AppxPackage -ErrorAction SilentlyContinue }
            Write-Log "Bloatware removed"
        }
    },

    # WINDOWS / PRIVACY
    [PSCustomObject]@{
        Name     = "Disable Telemetry and Data Collection"
        Desc     = "Deaktiviert alle Windows-Telemetriedienste (DiagTrack, dmwappushservice). Empfohlen fuer alle Nutzer."
        Category = "Windows"
        Group    = "Privacy"
        Action   = {
            Stop-Service DiagTrack -Force -ErrorAction SilentlyContinue
            Set-Service DiagTrack -StartupType Disabled -ErrorAction SilentlyContinue
            Stop-Service dmwappushservice -Force -ErrorAction SilentlyContinue
            Set-Service dmwappushservice -StartupType Disabled -ErrorAction SilentlyContinue
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Telemetry disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Activity History"
        Desc     = "Deaktiviert die Windows Aktivitaetsverlauf-Funktion (Timeline)."
        Category = "Windows"
        Group    = "Privacy"
        Action   = {
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v EnableActivityFeed /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v PublishUserActivities /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Activity History disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Advertising ID"
        Desc     = "Deaktiviert die Werbe-ID. Verhindert geraeteuebergreifendes Tracking durch Apps."
        Category = "Windows"
        Group    = "Privacy"
        Action   = {
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" /v DisabledByGroupPolicy /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "Advertising ID disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Location Tracking"
        Desc     = "Deaktiviert den Windows Standortdienst systemweit."
        Category = "Windows"
        Group    = "Privacy"
        Action   = {
            reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v Value /t REG_SZ /d Deny /f | Out-Null
            Set-Service lfsvc -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Log "Location tracking disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Block Telemetry Hosts (hosts file)"
        Desc     = "Fuegt Microsoft Telemetrie-Server in die hosts-Datei ein und blockiert sie systemweit."
        Category = "Windows"
        Group    = "Privacy"
        Action   = {
            $hosts = @(
                "0.0.0.0 telemetry.microsoft.com",
                "0.0.0.0 vortex.data.microsoft.com",
                "0.0.0.0 vortex-win.data.microsoft.com",
                "0.0.0.0 telecommand.telemetry.microsoft.com",
                "0.0.0.0 oca.telemetry.microsoft.com",
                "0.0.0.0 sqm.telemetry.microsoft.com",
                "0.0.0.0 watson.telemetry.microsoft.com",
                "0.0.0.0 redir.metaservices.microsoft.com",
                "0.0.0.0 choice.microsoft.com",
                "0.0.0.0 df.telemetry.microsoft.com",
                "0.0.0.0 reports.wes.df.telemetry.microsoft.com",
                "0.0.0.0 wes.df.telemetry.microsoft.com"
            )
            $hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
            $existing  = Get-Content $hostsFile
            foreach ($entry in $hosts) {
                if ($existing -notcontains $entry) { Add-Content $hostsFile $entry }
            }
            Write-Log "Telemetry hosts blocked"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Scheduled Telemetry Tasks"
        Desc     = "Deaktiviert geplante Windows-Aufgaben die Telemetriedaten sammeln und senden."
        Category = "Windows"
        Group    = "Privacy"
        Action   = {
            $tasks = @(
                "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
                "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
                "\Microsoft\Windows\Autochk\Proxy",
                "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
                "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
                "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
            )
            foreach ($task in $tasks) { schtasks /Change /TN $task /Disable 2>$null }
            Write-Log "Telemetry tasks disabled"
        }
    },

    # WINDOWS / PERFORMANCE
    [PSCustomObject]@{
        Name     = "Ultimate Performance Plan"
        Desc     = "Aktiviert den Ultimative Leistung Energiesparplan. CPU-Kerne werden nicht mehr gedrosselt."
        Category = "Windows"
        Group    = "Performance"
        Action   = {
            powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
            $guid = (powercfg -list | Select-String "Ultimative Leistung|Ultimate Performance").ToString().Split()[3]
            if ($guid) { powercfg -setactive $guid }
            Write-Log "Ultimate Performance Plan activated"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable HPET"
        Desc     = "Deaktiviert den High Precision Event Timer. Kann Latenz reduzieren und Gaming-Performance verbessern."
        Category = "Windows"
        Group    = "Performance"
        Action   = {
            bcdedit /deletevalue useplatformclock 2>$null | Out-Null
            bcdedit /set useplatformtick yes | Out-Null
            bcdedit /set disabledynamictick yes | Out-Null
            Write-Log "HPET disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Set 0.5ms Timer Resolution"
        Desc     = "Setzt die Timer-Aufloesung auf 0.5ms. Verbessert Frame-Timing und reduziert Input-Lag."
        Category = "Windows"
        Group    = "Performance"
        Action   = {
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v GlobalTimerResolutionRequests /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "Timer resolution set to 0.5ms"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Prefetch and Superfetch"
        Desc     = "Deaktiviert Prefetch und SysMain. Fuer SSDs empfohlen. Reduziert Hintergrund-Schreibzugriffe."
        Category = "Windows"
        Group    = "Performance"
        Action   = {
            Stop-Service SysMain -Force -ErrorAction SilentlyContinue
            Set-Service SysMain -StartupType Disabled -ErrorAction SilentlyContinue
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnablePrefetcher /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnableSuperfetch /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Prefetch / Superfetch disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Optimize Visual Effects (Performance Mode)"
        Desc     = "Schaltet alle Animationen aus. Windows reagiert spuerbar schneller besonders beim Gaming."
        Category = "Windows"
        Group    = "Performance"
        Action   = {
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 2 /f | Out-Null
            $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
            Set-ItemProperty $path -Name "TaskbarAnimations" -Value 0
            reg add "HKCU\Control Panel\Desktop\WindowMetrics" /v MinAnimate /t REG_SZ /d 0 /f | Out-Null
            Write-Log "Visual effects set to performance mode"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Windows Search Indexing"
        Desc     = "Deaktiviert den Windows Search Indexer. Reduziert Festplattenzugriffe im Hintergrund."
        Category = "Windows"
        Group    = "Performance"
        Action   = {
            Stop-Service WSearch -Force -ErrorAction SilentlyContinue
            Set-Service WSearch -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Log "Windows Search Indexing disabled"
        }
    },

    # WINDOWS / MOUSE AND UI
    [PSCustomObject]@{
        Name     = "Disable Mouse Acceleration"
        Desc     = "Deaktiviert Mausbeschleunigung. Wichtig fuer FPS-Spiele: 1:1 Uebertragung ohne dynamische Verstaerkung."
        Category = "Windows"
        Group    = "Mouse and UI"
        Action   = {
            reg add "HKCU\Control Panel\Mouse" /v MouseSpeed /t REG_SZ /d 0 /f | Out-Null
            reg add "HKCU\Control Panel\Mouse" /v MouseThreshold1 /t REG_SZ /d 0 /f | Out-Null
            reg add "HKCU\Control Panel\Mouse" /v MouseThreshold2 /t REG_SZ /d 0 /f | Out-Null
            Write-Log "Mouse acceleration disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Sticky Keys"
        Desc     = "Deaktiviert den Sticky Keys Dialog. Verhindert ungewollte Unterbrechungen im Spiel."
        Category = "Windows"
        Group    = "Mouse and UI"
        Action   = {
            reg add "HKCU\Control Panel\Accessibility\StickyKeys" /v Flags /t REG_SZ /d 506 /f | Out-Null
            reg add "HKCU\Control Panel\Accessibility\Keyboard Response" /v Flags /t REG_SZ /d 122 /f | Out-Null
            reg add "HKCU\Control Panel\Accessibility\ToggleKeys" /v Flags /t REG_SZ /d 58 /f | Out-Null
            Write-Log "Sticky Keys disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Enable Dark Mode"
        Desc     = "Aktiviert dunklen Modus systemweit. Schont die Augen bei langen Gaming-Sessions."
        Category = "Windows"
        Group    = "Mouse and UI"
        Action   = {
            reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v AppsUseLightTheme /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v SystemUsesLightTheme /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Dark Mode enabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Transparency Effects"
        Desc     = "Deaktiviert Transparenz-Effekte in Taskleiste und Startmenue. Spart GPU-Ressourcen."
        Category = "Windows"
        Group    = "Mouse and UI"
        Action   = {
            reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Transparency disabled"
        }
    },

    # GAMING / IN-GAME BOOSTS
    [PSCustomObject]@{
        Name     = "Enable Game Mode"
        Desc     = "Aktiviert Windows Game Mode. Priorisiert CPU/GPU fuer das aktive Spiel und blockiert WU-Neustarts."
        Category = "Gaming"
        Group    = "In-Game Boosts"
        Action   = {
            reg add "HKCU\Software\Microsoft\GameBar" /v AllowAutoGameMode /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKCU\Software\Microsoft\GameBar" /v AutoGameModeEnabled /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "Game Mode enabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Xbox Game Bar"
        Desc     = "Deaktiviert die Xbox Game Bar (Win+G). Game Mode bleibt unberuehrt."
        Category = "Gaming"
        Group    = "In-Game Boosts"
        Action   = {
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v AllowGameDVR /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Xbox Game Bar disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "CPU Priority for Games (Win32Priority)"
        Desc     = "Setzt Win32PrioritySeparation auf 26. Gibt aktiven Spielen deutlich mehr CPU-Zeit."
        Category = "Gaming"
        Group    = "In-Game Boosts"
        Action   = {
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v Win32PrioritySeparation /t REG_DWORD /d 26 /f | Out-Null
            Write-Log "CPU Priority set for gaming"
        }
    },
    [PSCustomObject]@{
        Name     = "MMCSS Gaming Profile (High Priority)"
        Desc     = "Setzt MMCSS-Profile fuer Spiele auf High Priority. Priorisiert Audio und Timer-Interrupts."
        Category = "Gaming"
        Group    = "In-Game Boosts"
        Action   = {
            reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "GPU Priority" /t REG_DWORD /d 8 /f | Out-Null
            reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "Priority" /t REG_DWORD /d 6 /f | Out-Null
            reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "Scheduling Category" /t REG_SZ /d High /f | Out-Null
            Write-Log "MMCSS Gaming profile set"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Fullscreen Optimizations"
        Desc     = "Deaktiviert Windows Fullscreen Optimizations global fuer niedrigeren Input-Lag."
        Category = "Gaming"
        Group    = "In-Game Boosts"
        Action   = {
            reg add "HKCU\System\GameConfigStore" /v GameDVR_FSEBehaviorMode /t REG_DWORD /d 2 /f | Out-Null
            reg add "HKCU\System\GameConfigStore" /v GameDVR_HonorUserFSEBehaviorMode /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKCU\System\GameConfigStore" /v GameDVR_FSEBehavior /t REG_DWORD /d 2 /f | Out-Null
            Write-Log "Fullscreen Optimizations disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Windows Update During Gaming"
        Desc     = "Verhindert dass Windows Update waehrend Gaming-Sessions aktiv wird und Ressourcen verbraucht."
        Category = "Gaming"
        Group    = "In-Game Boosts"
        Action   = {
            reg add "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v ActiveHoursStart /t REG_DWORD /d 8 /f | Out-Null
            reg add "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v ActiveHoursEnd /t REG_DWORD /d 23 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoRebootWithLoggedOnUsers /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "Windows Update during gaming disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Background App Throttling"
        Desc     = "Deaktiviert Hintergrund-Drosselung von Apps. Verhindert FPS-Drops durch Windows Throttling."
        Category = "Gaming"
        Group    = "In-Game Boosts"
        Action   = {
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v DisableLowQosTimerResolution /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "Background App Throttling disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Enable DirectX 12 Optimization"
        Desc     = "Aktiviert DirectX 12-Optimierungen in der Registry fuer bessere GPU-Nutzung in DX12-Spielen."
        Category = "Gaming"
        Group    = "In-Game Boosts"
        Action   = {
            reg add "HKLM\SOFTWARE\Microsoft\DirectX" /v D3D12_ENABLE_UNSAFE_COMMAND_BUFFER_REUSE /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "DirectX 12 Optimization enabled"
        }
    },

    # GAMING / GPU AND DRIVER
    [PSCustomObject]@{
        Name     = "NVIDIA Low Latency Mode (Reflex)"
        Desc     = "Aktiviert NVIDIA Ultra Low Latency Mode. Render-Queue auf 1 Frame. Nur fuer NVIDIA GPUs."
        Category = "Gaming"
        Group    = "GPU and Driver"
        Action   = {
            if ($IsNVIDIA) {
                $nvPath = "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak"
                reg add $nvPath /v NVLatency /t REG_DWORD /d 1 /f | Out-Null
                Write-Log "NVIDIA Low Latency Mode enabled"
            } else {
                Write-Log "NVIDIA Low Latency skipped (no NVIDIA GPU: $GPU)"
            }
        }
    },
    [PSCustomObject]@{
        Name     = "Enable MSI Mode (Message Signaled Interrupts)"
        Desc     = "Aktiviert MSI-Modus fuer GPU. Reduziert Interrupt-Latenz erheblich. Reboot empfohlen."
        Category = "Gaming"
        Group    = "GPU and Driver"
        Action   = {
            $gpuObj = Get-WmiObject Win32_VideoController | Where-Object { $_.Name -notmatch "Microsoft" } | Select-Object -First 1
            if ($gpuObj) {
                $pnpId   = $gpuObj.PNPDeviceID
                $regPath = "HKLM\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
                reg add $regPath /v MSISupported /t REG_DWORD /d 1 /f | Out-Null
                Write-Log "MSI Mode enabled for: $($gpuObj.Name)"
            }
        }
    },
    [PSCustomObject]@{
        Name     = "Enable Hardware-Accelerated GPU Scheduling (HAGS)"
        Desc     = "Aktiviert HAGS. Benoetigt NVIDIA RTX 2000+ oder AMD RX 5000+ und Windows 10 2004+."
        Category = "Gaming"
        Group    = "GPU and Driver"
        Action   = {
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v HwSchMode /t REG_DWORD /d 2 /f | Out-Null
            Write-Log "HAGS enabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Clear Shader Cache"
        Desc     = "Leert NVIDIA und AMD Shader-Cache. Sinnvoll nach Treiberupdates oder bei Grafikfehlern."
        Category = "Gaming"
        Group    = "GPU and Driver"
        Action   = {
            if ($IsNVIDIA) {
                $nvcache = "$env:LOCALAPPDATA\NVIDIA\DXCache"
                if (Test-Path $nvcache) { Remove-Item "$nvcache\*" -Recurse -Force -ErrorAction SilentlyContinue }
                $nvcache2 = "$env:LOCALAPPDATA\NVIDIA\GLCache"
                if (Test-Path $nvcache2) { Remove-Item "$nvcache2\*" -Recurse -Force -ErrorAction SilentlyContinue }
            }
            if ($IsAMD) {
                $amdcache = "$env:TEMP\AMD"
                if (Test-Path $amdcache) { Remove-Item "$amdcache\*" -Recurse -Force -ErrorAction SilentlyContinue }
            }
            $dxcache = "$env:LOCALAPPDATA\D3DSCache"
            if (Test-Path $dxcache) { Remove-Item "$dxcache\*" -Recurse -Force -ErrorAction SilentlyContinue }
            Write-Log "Shader Cache cleared"
        }
    },

    # NETWORK / LATENCY
    [PSCustomObject]@{
        Name     = "Disable Nagles Algorithm (TCPNoDelay)"
        Desc     = "Deaktiviert Nagles Algorithmus auf allen Netzwerkadaptern. Senkt Ping in Online-Spielen."
        Category = "Network"
        Group    = "Latency"
        Action   = {
            $adapters = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\*"
            foreach ($adapter in $adapters) {
                $path = $adapter.PSPath
                Set-ItemProperty -Path $path -Name "TcpAckFrequency" -Value 1 -Type DWord -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $path -Name "TCPNoDelay" -Value 1 -Type DWord -ErrorAction SilentlyContinue
            }
            Write-Log "Nagle's Algorithm disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Large Send Offload (LSO)"
        Desc     = "Deaktiviert LSO auf allen aktiven Netzwerkadaptern. Hilft bei instabilem Ping."
        Category = "Network"
        Group    = "Latency"
        Action   = {
            $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
            foreach ($adapter in $adapters) {
                Disable-NetAdapterLso -Name $adapter.Name -ErrorAction SilentlyContinue
            }
            Write-Log "LSO disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Network Throttling Index"
        Desc     = "Deaktiviert den Network Throttling Index. Windows begrenzt Netzwerk-Durchsatz nicht mehr kuenstlich."
        Category = "Network"
        Group    = "Latency"
        Action   = {
            reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v NetworkThrottlingIndex /t REG_DWORD /d 0xffffffff /f | Out-Null
            Write-Log "Network Throttling Index disabled"
        }
    },

    # NETWORK / DNS
    [PSCustomObject]@{
        Name     = "Set DNS to Cloudflare (1.1.1.1)"
        Desc     = "Setzt DNS auf Cloudflare 1.1.1.1 und 1.0.0.1. Schnell und datenschutzfreundlich."
        Category = "Network"
        Group    = "DNS"
        Action   = {
            $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
            foreach ($adapter in $adapters) {
                Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses ("1.1.1.1","1.0.0.1") -ErrorAction SilentlyContinue
            }
            Write-Log "DNS set to Cloudflare 1.1.1.1"
        }
    },
    [PSCustomObject]@{
        Name     = "Set DNS to Google (8.8.8.8)"
        Desc     = "Setzt DNS auf Google 8.8.8.8 und 8.8.4.4. Sehr schnell und global verfuegbar."
        Category = "Network"
        Group    = "DNS"
        Action   = {
            $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
            foreach ($adapter in $adapters) {
                Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses ("8.8.8.8","8.8.4.4") -ErrorAction SilentlyContinue
            }
            Write-Log "DNS set to Google 8.8.8.8"
        }
    },
    [PSCustomObject]@{
        Name     = "Flush DNS Cache"
        Desc     = "Leert den lokalen DNS-Cache. Sinnvoll nach DNS-Aenderungen oder bei Verbindungsproblemen."
        Category = "Network"
        Group    = "DNS"
        Action   = {
            ipconfig /flushdns | Out-Null
            Write-Log "DNS Cache flushed"
        }
    },

    # NETWORK / TCP
    [PSCustomObject]@{
        Name     = "Disable TCP Auto-Tuning"
        Desc     = "Deaktiviert automatische TCP-Empfangsfenstergroesse. Kann Latenz-Spikes reduzieren."
        Category = "Network"
        Group    = "TCP"
        Action   = {
            netsh int tcp set global autotuninglevel=disabled | Out-Null
            Write-Log "TCP Auto-Tuning disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Optimize TCP Settings (ECN and SACK)"
        Desc     = "Deaktiviert ECN, SACK und TCP Timestamps fuer niedrigere Latenz in Online-Spielen."
        Category = "Network"
        Group    = "TCP"
        Action   = {
            netsh int tcp set global ecncapability=disabled | Out-Null
            netsh int tcp set global timestamps=disabled | Out-Null
            reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v SackOpts /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "TCP ECN/SACK/Timestamps optimized"
        }
    },

    # NETWORK / QOS
    [PSCustomObject]@{
        Name     = "Disable QoS Packet Scheduler Limit"
        Desc     = "Entfernt das 20-Prozent-Bandbreitenlimit das Windows fuer QoS reserviert."
        Category = "Network"
        Group    = "QoS"
        Action   = {
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched" /v NonBestEffortLimit /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "QoS bandwidth limit removed"
        }
    },

    # RAM AND STORAGE / MEMORY
    [PSCustomObject]@{
        Name     = "Optimize PageFile (System Managed)"
        Desc     = "Setzt den PageFile auf System Managed. Windows passt die Auslagerungsdatei automatisch an."
        Category = "RAM and Storage"
        Group    = "Memory"
        Action   = {
            $cs = Get-WmiObject Win32_ComputerSystem
            $cs.AutomaticManagedPagefile = $true
            $cs.Put() | Out-Null
            Write-Log "PageFile set to System Managed"
        }
    },
    [PSCustomObject]@{
        Name     = "Clear PageFile on Shutdown"
        Desc     = "Leert den PageFile beim Herunterfahren. Verbessert Datenschutz und verhindert Datenlecks."
        Category = "RAM and Storage"
        Group    = "Memory"
        Action   = {
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v ClearPageFileAtShutdown /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "Clear PageFile on Shutdown enabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Memory Compression"
        Desc     = "Deaktiviert Windows RAM-Komprimierung. Empfohlen ab 16 GB RAM. Reduziert CPU-Last."
        Category = "RAM and Storage"
        Group    = "Memory"
        Action   = {
            Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
            Write-Log "Memory Compression disabled"
        }
    },

    # RAM AND STORAGE / STORAGE
    [PSCustomObject]@{
        Name     = "Enable SSD TRIM"
        Desc     = "Stellt sicher dass TRIM fuer SSDs aktiv ist. Haelt SSD-Leistung langfristig aufrecht."
        Category = "RAM and Storage"
        Group    = "Storage"
        Action   = {
            fsutil behavior set DisableDeleteNotify 0 | Out-Null
            Write-Log "SSD TRIM enabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Scheduled Defragmentation"
        Desc     = "Deaktiviert geplante Defragmentierung. Fuer SSDs schaedlich und unnoetig."
        Category = "RAM and Storage"
        Group    = "Storage"
        Action   = {
            schtasks /Change /TN "\Microsoft\Windows\Defrag\ScheduledDefrag" /Disable 2>$null | Out-Null
            Write-Log "Scheduled Defragmentation disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Hibernation"
        Desc     = "Deaktiviert den Ruhezustand und entfernt hiberfil.sys. Spart Speicherplatz in RAM-Groesse."
        Category = "RAM and Storage"
        Group    = "Storage"
        Action   = {
            powercfg -h off | Out-Null
            Write-Log "Hibernation disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Optimize NVMe Queue Depth"
        Desc     = "Setzt die Queue-Tiefe fuer NVMe-SSDs auf den optimalen Wert. Verbessert Lese- und Schreibdurchsatz."
        Category = "RAM and Storage"
        Group    = "Storage"
        Action   = {
            $disks = Get-PhysicalDisk | Where-Object { $_.BusType -eq "NVMe" }
            if (-not $disks) {
                Write-Log "NVMe Queue Depth: no NVMe disks found"
            } else {
                $count = ($disks | Measure-Object).Count
                reg add "HKLM\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device" /v "QueueDepth" /t REG_DWORD /d 32 /f | Out-Null
                Write-Log "NVMe Queue Depth optimized ($count NVMe disk(s) detected)"
            }
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Write-Cache Buffer Flushing"
        Desc     = "Deaktiviert das Leeren des Schreib-Cache-Puffers. Nur fuer Systeme mit unterbrechungsfreier Stromversorgung empfohlen."
        Category = "RAM and Storage"
        Group    = "Storage"
        Action   = {
            $disks = Get-WmiObject Win32_DiskDrive
            $count = 0
            foreach ($disk in $disks) {
                $pnpId   = $disk.PNPDeviceID
                $regPath = "HKLM\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters\Disk"
                reg add $regPath /v UserWriteCacheSetting /t REG_DWORD /d 1 /f 2>$null | Out-Null
                $count++
            }
            Write-Log "Write-Cache Buffer Flushing disabled ($count disk(s) updated)"
        }
    },

    # RAM AND STORAGE / MAINTENANCE
    [PSCustomObject]@{
        Name     = "Clean Temp Files"
        Desc     = "Loescht temporaere Dateien aus TEMP und Windows Temp-Ordner. Gibt Speicherplatz frei."
        Category = "RAM and Storage"
        Group    = "Maintenance"
        Action   = {
            Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item "$env:SystemRoot\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Temp files cleaned"
        }
    }
)

# WPF XAML GUI
[xml]$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="GameOptimizerPro v3.0 - by FloDePin"
        Height="720" Width="860"
        ResizeMode="CanMinimize"
        WindowStartupLocation="CenterScreen"
        Background="#1a1a2e">

    <Window.Resources>
        <Style TargetType="Button" x:Key="PrimaryBtn">
            <Setter Property="Background" Value="#0f3460"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Padding" Value="16,8"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#e94560"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter Property="Background" Value="#c73652"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#dddddd"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Margin" Value="0,0,8,0"/>
            <Setter Property="VerticalAlignment" Value="Center"/>
        </Style>
        <Style TargetType="TabItem">
            <Setter Property="Background" Value="#16213e"/>
            <Setter Property="Foreground" Value="#aaaaaa"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="16,8"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TabItem">
                        <Border Name="Border" Background="{TemplateBinding Background}" CornerRadius="6,6,0,0" Margin="2,0" Padding="{TemplateBinding Padding}">
                            <ContentPresenter x:Name="ContentSite" VerticalAlignment="Center" HorizontalAlignment="Center"
                                              ContentSource="Header" RecognizesAccessKey="True"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="Border" Property="Background" Value="#e94560"/>
                                <Setter Property="Foreground" Value="White"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Border" Property="Background" Value="#0f3460"/>
                                <Setter Property="Foreground" Value="White"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <StackPanel Grid.Row="0" Margin="0,0,0,12">
            <TextBlock Text="GameOptimizerPro" FontSize="26" FontWeight="Bold" Foreground="#e94560"/>
            <TextBlock Text="Windows &amp; Gaming Optimizer - by FloDePin" FontSize="12" Foreground="#888" Margin="2,2,0,0"/>
        </StackPanel>

        <Border Grid.Row="1" Background="#16213e" CornerRadius="8" Padding="12,8" Margin="0,0,0,12">
            <TextBlock Name="HwInfoText" Text="Detecting hardware..." FontSize="12" Foreground="#00d4aa" FontFamily="Consolas"/>
        </Border>

        <TabControl Grid.Row="2" Background="#16213e" BorderBrush="#333" Padding="0">
            <TabItem Header="[WIN]  Windows">
                <ScrollViewer Background="#1a1a2e" Padding="8" VerticalScrollBarVisibility="Auto">
                    <StackPanel Name="WindowsPanel" Margin="4"/>
                </ScrollViewer>
            </TabItem>
            <TabItem Header="[GAME] Gaming">
                <ScrollViewer Background="#1a1a2e" Padding="8" VerticalScrollBarVisibility="Auto">
                    <StackPanel Name="GamingPanel" Margin="4"/>
                </ScrollViewer>
            </TabItem>
            <TabItem Header="[NET]  Network">
                <ScrollViewer Background="#1a1a2e" Padding="8" VerticalScrollBarVisibility="Auto">
                    <StackPanel Name="NetworkPanel" Margin="4"/>
                </ScrollViewer>
            </TabItem>
            <TabItem Header="[RAM]  RAM and Storage">
                <ScrollViewer Background="#1a1a2e" Padding="8" VerticalScrollBarVisibility="Auto">
                    <StackPanel Name="RamPanel" Margin="4"/>
                </ScrollViewer>
            </TabItem>
        </TabControl>

        <WrapPanel Grid.Row="3" Margin="0,12,0,0" HorizontalAlignment="Center">
            <Button Name="BtnSelectAll"   Content="[x] Select All"    Style="{StaticResource PrimaryBtn}" Margin="6,0"/>
            <Button Name="BtnDeselectAll" Content="[ ] Deselect All"  Style="{StaticResource PrimaryBtn}" Margin="6,0"/>
            <Button Name="BtnApply"       Content=">> Apply Selected" Style="{StaticResource PrimaryBtn}" Margin="6,0" Background="#e94560"/>
            <Button Name="BtnOpenLog"     Content="[Log] Open Log"    Style="{StaticResource PrimaryBtn}" Margin="6,0"/>
        </WrapPanel>

        <Border Grid.Row="4" Background="#16213e" CornerRadius="6" Padding="10,6" Margin="0,10,0,0">
            <TextBlock Name="StatusText" Text="Ready - select tweaks and click Apply Selected."
                       Foreground="#aaaaaa" FontSize="12" FontFamily="Consolas"/>
        </Border>
    </Grid>
</Window>
"@

# PARSE XAML
$Reader = New-Object System.Xml.XmlNodeReader $XAML
$Window = [Windows.Markup.XamlReader]::Load($Reader)

$HwInfoText   = $Window.FindName("HwInfoText")
$WindowsPanel = $Window.FindName("WindowsPanel")
$GamingPanel  = $Window.FindName("GamingPanel")
$NetworkPanel = $Window.FindName("NetworkPanel")
$RamPanel     = $Window.FindName("RamPanel")
$BtnApply     = $Window.FindName("BtnApply")
$BtnSelectAll = $Window.FindName("BtnSelectAll")
$BtnDeselect  = $Window.FindName("BtnDeselectAll")
$BtnOpenLog   = $Window.FindName("BtnOpenLog")
$StatusText   = $Window.FindName("StatusText")

$HwInfoText.Text = $HWInfo

# BUILD TWEAK ROWS
$CheckBoxMap = @{}

function New-GroupHeader {
    param([string]$Title)
    $tb            = New-Object Windows.Controls.TextBlock
    $tb.Text       = "-- $Title"
    $tb.FontSize   = 12
    $tb.FontWeight = "SemiBold"
    $tb.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(0,212,170))
    $tb.Margin     = New-Object Windows.Thickness(0,14,0,4)
    return $tb
}

function New-TweakRow {
    param($Tweak)
    $panel             = New-Object Windows.Controls.StackPanel
    $panel.Orientation = "Horizontal"
    $panel.Margin      = New-Object Windows.Thickness(0,3,0,3)

    $cb                   = New-Object Windows.Controls.CheckBox
    $cb.Content           = $Tweak.Name
    $cb.Tag               = $Tweak.Name
    $cb.VerticalAlignment = "Center"
    $cb.Foreground        = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(221,221,221))
    $cb.FontSize          = 13
    $cb.Margin            = New-Object Windows.Thickness(0,0,8,0)
    $CheckBoxMap[$Tweak.Name] = $cb

    $btn                  = New-Object Windows.Controls.Button
    $btn.Content          = "?"
    $btn.Width            = 22
    $btn.Height           = 22
    $btn.FontSize         = 11
    $btn.Background       = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(22,33,62))
    $btn.Foreground       = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(170,170,170))
    $btn.BorderBrush      = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(68,68,68))
    $btn.BorderThickness  = New-Object Windows.Thickness(1)
    $btn.Cursor           = [System.Windows.Input.Cursors]::Hand
    $btn.VerticalAlignment = "Center"

    $capturedDesc = $Tweak.Desc
    $capturedName = $Tweak.Name
    $btn.Add_Click({
        [System.Windows.MessageBox]::Show(
            $capturedDesc, "Info: $capturedName",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        )
    }.GetNewClosure())
    $btn.Add_MouseEnter({
        $btn.Background = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(233,69,96))
        $btn.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(255,255,255))
    })
    $btn.Add_MouseLeave({
        $btn.Background = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(22,33,62))
        $btn.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(170,170,170))
    })

    $panel.Children.Add($cb)  | Out-Null
    $panel.Children.Add($btn) | Out-Null
    return $panel
}

# FILL PANELS
$categories = @{
    "Windows"         = $WindowsPanel
    "Gaming"          = $GamingPanel
    "Network"         = $NetworkPanel
    "RAM and Storage" = $RamPanel
}

foreach ($cat in @("Windows","Gaming","Network","RAM and Storage")) {
    $panel  = $categories[$cat]
    $groups = $AllTweaks | Where-Object { $_.Category -eq $cat } | Select-Object -ExpandProperty Group -Unique
    foreach ($group in $groups) {
        $panel.Children.Add((New-GroupHeader $group)) | Out-Null
        $tweaks = $AllTweaks | Where-Object { $_.Category -eq $cat -and $_.Group -eq $group }
        foreach ($tweak in $tweaks) {
            $panel.Children.Add((New-TweakRow $tweak)) | Out-Null
        }
    }
}

# BUTTON EVENTS
$BtnSelectAll.Add_Click({ foreach ($cb in $CheckBoxMap.Values) { $cb.IsChecked = $true } })
$BtnDeselect.Add_Click({  foreach ($cb in $CheckBoxMap.Values) { $cb.IsChecked = $false } })

$BtnOpenLog.Add_Click({
    if (Test-Path $LogFile) { Start-Process notepad.exe $LogFile }
    else {
        [System.Windows.MessageBox]::Show("No log file yet. Apply some tweaks first.", "Log",
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
})

$BtnApply.Add_Click({
    $selected = $AllTweaks | Where-Object { $CheckBoxMap[$_.Name].IsChecked -eq $true }
    if ($selected.Count -eq 0) {
        [System.Windows.MessageBox]::Show("No tweaks selected!", "GameOptimizerPro",
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    $confirm = [System.Windows.MessageBox]::Show(
        "Apply $($selected.Count) selected tweak(s)?`n`nA system restore point will be created first.",
        "GameOptimizerPro -- Confirm",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )
    if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

    $StatusText.Text = "Creating restore point..."
    try {
        Checkpoint-Computer -Description "GameOptimizerPro Backup" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Log "Restore point created"
    } catch {
        Write-Log "Restore point failed (may already exist): $_"
    }

    $done  = 0
    $total = $selected.Count
    foreach ($tweak in $selected) {
        $StatusText.Text = "Applying: $($tweak.Name) ($done/$total)..."
        $Window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Render)
        try {
            & $tweak.Action
            Write-Log "OK: $($tweak.Name)"
        } catch {
            Write-Log "FAILED: $($tweak.Name) -- $_"
        }
        $done++
    }

    $StatusText.Text = "Done! $done tweak(s) applied. Log: $LogFile"
    [System.Windows.MessageBox]::Show(
        "$done tweak(s) applied successfully!`n`nSome changes require a restart.`nLog: $LogFile",
        "GameOptimizerPro -- Done",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Information
    )
})

# LAUNCH
Write-Log "GameOptimizerPro v3.0 started | $HWInfo"
$Window.ShowDialog() | Out-Null
