#Requires -RunAsAdministrator
<#
.SYNOPSIS
    WinTweaker - Windows & Gaming Optimizer
.DESCRIPTION
    GUI-based PowerShell optimizer with checkboxes and info tooltips.
    Tabs: Windows (Debloat) | Gaming | Network | RAM & Storage
.AUTHOR
    FloDePin
.VERSION
    1.0.0
#>

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# ─────────────────────────────────────────
# ADMIN CHECK
# ─────────────────────────────────────────
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    [System.Windows.Forms.MessageBox]::Show("Please run this script as Administrator!", "WinTweaker - Admin Required", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit
}

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
$LogFile = "$env:TEMP\WinTweaker_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
function Write-Log {
    param([string]$Message)
    $entry = "[$(Get-Date -Format 'HH:mm:ss')] $Message"
    Add-Content -Path $LogFile -Value $entry
}

# ─────────────────────────────────────────
# TWEAK DEFINITIONS
# ─────────────────────────────────────────
$AllTweaks = @(

    # ── WINDOWS / BLOATWARE ────────────────────────────────────────────────
    [PSCustomObject]@{
        Name     = "Remove Cortana"
        Desc     = "Deinstalliert Cortana vollständig. Cortana ist Microsofts Sprachassistent der Daten an Microsoft sendet. Für die meisten Nutzer nicht benötigt."
        Category = "Windows"
        Group    = "Bloatware"
        Action   = {
            Get-AppxPackage -AllUsers "*Microsoft.549981C3F5F10*" | Remove-AppxPackage -ErrorAction SilentlyContinue
            Write-Log "Cortana removed"
        }
    },
    [PSCustomObject]@{
        Name     = "Remove Xbox Apps"
        Desc     = "Entfernt Xbox Game Bar, Xbox Identity Provider und Xbox TCUI. Diese Apps laufen im Hintergrund und verbrauchen Ressourcen — auch wenn du keine Xbox hast."
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
        Desc     = "Entfernt Microsoft Teams (die Consumer-Version). Nicht zu verwechseln mit Teams for Work. Blockiert automatische Neuinstallation."
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
        Desc     = "Deaktiviert und entfernt Windows Copilot (KI-Assistent). Verhindert dass Copilot im Hintergrund läuft und Daten sendet."
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
        Desc     = "Deinstalliert OneDrive komplett inkl. Autostart und Explorer-Integration. Deine lokalen Dateien bleiben unangetastet."
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
        Desc     = "Deaktiviert Windows Recall — das KI-Feature das Screenshots deiner Aktivitäten macht und lokal speichert. Datenschutzkritisch."
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
        Desc     = "Entfernt vorinstallierte Apps wie: Candy Crush, TikTok, Disney+, Facebook, Instagram, Spotify, News, Weather, Solitaire, Clipchamp, ToDo, Paint3D und weitere."
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

    # ── WINDOWS / PRIVACY ──────────────────────────────────────────────────
    [PSCustomObject]@{
        Name     = "Disable Telemetry & Data Collection"
        Desc     = "Deaktiviert alle Windows-Telemetriedienste (DiagTrack, dmwappushservice). Windows sendet dann keine Nutzungsdaten mehr an Microsoft."
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
        Desc     = "Deaktiviert die Windows Aktivitätsverlauf-Funktion (Timeline). Windows speichert dann nicht mehr welche Apps und Dateien du geöffnet hast."
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
        Desc     = "Deaktiviert die Werbe-ID die Windows jedem Nutzer zuweist. Apps können dich dann nicht mehr geräteübergreifend tracken."
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
        Desc     = "Deaktiviert den Windows Standortdienst systemweit. Apps können deinen Standort nicht mehr abfragen."
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
        Desc     = "Fügt Microsoft Telemetrie-Server in die Windows hosts-Datei ein und blockt sie. Damit können diese Server nicht mehr erreicht werden."
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
        Desc     = "Deaktiviert alle geplanten Windows-Aufgaben die Telemetriedaten sammeln und senden."
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

    # ── WINDOWS / PERFORMANCE ──────────────────────────────────────────────
    [PSCustomObject]@{
        Name     = "Ultimate Performance Plan"
        Desc     = "Aktiviert den 'Ultimative Leistung' Energiesparplan. Windows drosselt dann keine CPU-Kerne mehr — maximale Performance zu jeder Zeit."
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
        Name     = "Disable HPET (High Precision Event Timer)"
        Desc     = "Deaktiviert den High Precision Event Timer. Kann die System-Latenz reduzieren und Gaming-Performance verbessern."
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
        Desc     = "Setzt die Windows Timer-Auflösung auf 0.5ms (statt Standard 15.6ms). Verbessert Frame-Timing und reduziert Input-Lag in Spielen."
        Category = "Windows"
        Group    = "Performance"
        Action   = {
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v GlobalTimerResolutionRequests /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "Timer resolution set to 0.5ms"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Prefetch & Superfetch"
        Desc     = "Deaktiviert Prefetch und SysMain (Superfetch). Sinnvoll bei SSDs — auf HDDs nicht empfohlen."
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
        Desc     = "Schaltet alle Windows-Animationen und visuelle Effekte aus. Windows reagiert dadurch spürbar schneller."
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
        Desc     = "Deaktiviert den Windows Search Indexer (WSearch). Reduziert ständige Festplattenzugriffe im Hintergrund."
        Category = "Windows"
        Group    = "Performance"
        Action   = {
            Stop-Service WSearch -Force -ErrorAction SilentlyContinue
            Set-Service WSearch -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Log "Windows Search Indexing disabled"
        }
    },

    # ── WINDOWS / MOUSE & UI ───────────────────────────────────────────────
    [PSCustomObject]@{
        Name     = "Disable Mouse Acceleration"
        Desc     = "Deaktiviert die Mausbeschleunigung (Enhance Pointer Precision). Wichtig für FPS-Spiele: 1:1 Mausübertragung."
        Category = "Windows"
        Group    = "Mouse & UI"
        Action   = {
            reg add "HKCU\Control Panel\Mouse" /v MouseSpeed /t REG_SZ /d 0 /f | Out-Null
            reg add "HKCU\Control Panel\Mouse" /v MouseThreshold1 /t REG_SZ /d 0 /f | Out-Null
            reg add "HKCU\Control Panel\Mouse" /v MouseThreshold2 /t REG_SZ /d 0 /f | Out-Null
            Write-Log "Mouse acceleration disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Sticky Keys"
        Desc     = "Deaktiviert den Sticky Keys Dialog (der beim 5x Shift-Drücken aufpoppt). Verhindert ungewollte Unterbrechungen im Spiel."
        Category = "Windows"
        Group    = "Mouse & UI"
        Action   = {
            reg add "HKCU\Control Panel\Accessibility\StickyKeys" /v Flags /t REG_SZ /d 506 /f | Out-Null
            reg add "HKCU\Control Panel\Accessibility\Keyboard Response" /v Flags /t REG_SZ /d 122 /f | Out-Null
            reg add "HKCU\Control Panel\Accessibility\ToggleKeys" /v Flags /t REG_SZ /d 58 /f | Out-Null
            Write-Log "Sticky Keys disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Enable Dark Mode"
        Desc     = "Aktiviert den dunklen Modus für Windows und Apps systemweit."
        Category = "Windows"
        Group    = "Mouse & UI"
        Action   = {
            reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v AppsUseLightTheme /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v SystemUsesLightTheme /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Dark Mode enabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Transparency Effects"
        Desc     = "Deaktiviert die Transparenz-Effekte in Taskleiste und Startmenü. Spart GPU-Ressourcen."
        Category = "Windows"
        Group    = "Mouse & UI"
        Action   = {
            reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Transparency disabled"
        }
    },

    # ── GAMING / IN-GAME BOOSTS ───────────────────────────────────────────
    [PSCustomObject]@{
        Name     = "Enable Game Mode"
        Desc     = "Aktiviert den Windows Game Mode. Windows priorisiert CPU/GPU-Ressourcen für das aktive Spiel und unterdrückt Windows Update Neustarts."
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
        Desc     = "Deaktiviert die Xbox Game Bar (Win+G Overlay). Verhindert dass die Game Bar im Hintergrund läuft."
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
        Desc     = "Setzt Win32PrioritySeparation auf 26. Windows gibt dann aktiven Spielen deutlich mehr CPU-Zeit."
        Category = "Gaming"
        Group    = "In-Game Boosts"
        Action   = {
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v Win32PrioritySeparation /t REG_DWORD /d 26 /f | Out-Null
            Write-Log "CPU Priority set for gaming"
        }
    },
    [PSCustomObject]@{
        Name     = "MMCSS Gaming Profile (High Priority)"
        Desc     = "Setzt die MMCSS Profile für Spiele auf High Priority. Windows priorisiert Audio und Timer-Interrupts für besseres Gaming."
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
        Desc     = "Deaktiviert Windows Fullscreen Optimizations global. Erzwingt echtes Fullscreen für niedrigeren Input-Lag."
        Category = "Gaming"
        Group    = "In-Game Boosts"
        Action   = {
            reg add "HKCU\System\GameConfigStore" /v GameDVR_FSEBehaviorMode /t REG_DWORD /d 2 /f | Out-Null
            reg add "HKCU\System\GameConfigStore" /v GameDVR_HonorUserFSEBehaviorMode /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKCU\System\GameConfigStore" /v GameDVR_FSEBehavior /t REG_DWORD /d 2 /f | Out-Null
            Write-Log "Fullscreen Optimizations disabled"
        }
    },

    # ── GAMING / GPU & DRIVER ─────────────────────────────────────────────
    [PSCustomObject]@{
        Name     = "NVIDIA Low Latency Mode (Reflex)"
        Desc     = "Aktiviert NVIDIA Ultra Low Latency Mode. Reduziert Render-Queue auf 1 Frame — weniger Input-Lag. Nur NVIDIA GPUs."
        Category = "Gaming"
        Group    = "GPU & Driver"
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
        Desc     = "Aktiviert MSI-Modus für GPU. Reduziert Interrupt-Latenz erheblich. Reboot empfohlen."
        Category = "Gaming"
        Group    = "GPU & Driver"
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
        Desc     = "Aktiviert HAGS — GPU-Scheduling direkt an Hardware statt Software. Reduziert CPU-Overhead. Erfordert RTX 2000+ oder RX 5000+."
        Category = "Gaming"
        Group    = "GPU & Driver"
        Action   = {
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v HwSchMode /t REG_DWORD /d 2 /f | Out-Null
            Write-Log "HAGS enabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Clear Shader Cache"
        Desc     = "Leert den NVIDIA/AMD Shader-Cache. Erzwingt frische Shader-Kompilierung. Sinnvoll nach Treiberupdates."
        Category = "Gaming"
        Group    = "GPU & Driver"
        Action   = {
            if ($IsNVIDIA) {
                $p1 = "$env:LOCALAPPDATA\NVIDIA\DXCache"
                $p2 = "$env:LOCALAPPDATA\NVIDIA\GLCache"
                if (Test-Path $p1) { Remove-Item "$p1\*" -Recurse -Force -ErrorAction SilentlyContinue }
                if (Test-Path $p2) { Remove-Item "$p2\*" -Recurse -Force -ErrorAction SilentlyContinue }
            }
            if ($IsAMD) {
                $p3 = "$env:TEMP\AMD"
                if (Test-Path $p3) { Remove-Item "$p3\*" -Recurse -Force -ErrorAction SilentlyContinue }
            }
            $dxc = "$env:LOCALAPPDATA\D3DSCache"
            if (Test-Path $dxc) { Remove-Item "$dxc\*" -Recurse -Force -ErrorAction SilentlyContinue }
            Write-Log "Shader Cache cleared"
        }
    },

    # ── NETWORK / LATENCY ─────────────────────────────────────────────────
    [PSCustomObject]@{
        Name     = "Disable Nagle's Algorithm (TCPNoDelay)"
        Desc     = "Deaktiviert Nagles Algorithmus. Bündelt keine Pakete mehr — senkt Ping in Online-Spielen spürbar."
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
        Desc     = "Deaktiviert Large Send Offload auf allen aktiven Adaptern. Hilft bei instabilem Ping in Online-Spielen."
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

    # ── NETWORK / DNS ─────────────────────────────────────────────────────
    [PSCustomObject]@{
        Name     = "Set DNS to Cloudflare (1.1.1.1)"
        Desc     = "Setzt DNS auf Cloudflare 1.1.1.1 — einer der schnellsten und datenschutzfreundlichsten DNS-Anbieter."
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
        Name     = "Flush DNS Cache"
        Desc     = "Leert den lokalen DNS-Cache. Sinnvoll nach DNS-Änderungen oder bei Verbindungsproblemen."
        Category = "Network"
        Group    = "DNS"
        Action   = {
            ipconfig /flushdns | Out-Null
            Write-Log "DNS Cache flushed"
        }
    },

    # ── NETWORK / TCP ─────────────────────────────────────────────────────
    [PSCustomObject]@{
        Name     = "Disable TCP Auto-Tuning"
        Desc     = "Deaktiviert automatische TCP-Empfangsfenstergröße. Kann Latenz-Spikes reduzieren."
        Category = "Network"
        Group    = "TCP"
        Action   = {
            netsh int tcp set global autotuninglevel=disabled | Out-Null
            Write-Log "TCP Auto-Tuning disabled"
        }
    },

    # ── NETWORK / QoS ─────────────────────────────────────────────────────
    [PSCustomObject]@{
        Name     = "Disable QoS Packet Scheduler Limit"
        Desc     = "Entfernt das 20% Bandbreiten-Limit das Windows für QoS reserviert. Gibt volle Bandbreite frei."
        Category = "Network"
        Group    = "QoS"
        Action   = {
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched" /v NonBestEffortLimit /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "QoS bandwidth limit removed"
        }
    }
)

# ─────────────────────────────────────────
# WPF XAML GUI
# ─────────────────────────────────────────
[xml]$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="WinTweaker v2.0 — by FloDePin"
        Height="700" Width="860"
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
        <Style TargetType="Button" x:Key="InfoBtn">
            <Setter Property="Background" Value="#16213e"/>
            <Setter Property="Foreground" Value="#aaaaaa"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="Width" Value="22"/>
            <Setter Property="Height" Value="22"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="#444"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="11"
                                BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#e94560"/>
                                <Setter Property="BorderBrush" Value="#e94560"/>
                                <Setter Property="Foreground" Value="White"/>
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

        <!-- HEADER -->
        <StackPanel Grid.Row="0" Margin="0,0,0,12">
            <TextBlock Text="&#9889; WinTweaker v2.0" FontSize="26" FontWeight="Bold" Foreground="#e94560"/>
            <TextBlock Text="Windows &amp; Gaming Optimizer | by FloDePin" FontSize="12" Foreground="#888" Margin="2,2,0,0"/>
        </StackPanel>

        <!-- HW INFO -->
        <Border Grid.Row="1" Background="#16213e" CornerRadius="8" Padding="12,8" Margin="0,0,0,12">
            <TextBlock Name="HwInfoText" Text="Detecting hardware..." FontSize="12" Foreground="#00d4aa" FontFamily="Consolas"/>
        </Border>

        <!-- TABS -->
        <TabControl Grid.Row="2" Background="#16213e" BorderBrush="#333" Padding="0">

            <TabItem Header="&#128919;  Windows">
                <ScrollViewer Background="#1a1a2e" Padding="8" VerticalScrollBarVisibility="Auto">
                    <StackPanel Name="WindowsPanel" Margin="4"/>
                </ScrollViewer>
            </TabItem>

            <TabItem Header="&#127918;  Gaming">
                <ScrollViewer Background="#1a1a2e" Padding="8" VerticalScrollBarVisibility="Auto">
                    <StackPanel Name="GamingPanel" Margin="4"/>
                </ScrollViewer>
            </TabItem>

            <TabItem Header="&#127760;  Network">
                <ScrollViewer Background="#1a1a2e" Padding="8" VerticalScrollBarVisibility="Auto">
                    <StackPanel Name="NetworkPanel" Margin="4"/>
                </ScrollViewer>
            </TabItem>

        </TabControl>

        <!-- BUTTONS -->
        <WrapPanel Grid.Row="3" Margin="0,12,0,0" HorizontalAlignment="Center">
            <Button Name="BtnSelectAll"   Content="&#9745; Select All"     Style="{StaticResource PrimaryBtn}" Margin="6,0"/>
            <Button Name="BtnDeselectAll" Content="&#9744; Deselect All"   Style="{StaticResource PrimaryBtn}" Margin="6,0"/>
            <Button Name="BtnApply"       Content="&#9989; Apply Selected" Style="{StaticResource PrimaryBtn}" Margin="6,0" Background="#e94560"/>
            <Button Name="BtnOpenLog"     Content="&#128203; Open Log"     Style="{StaticResource PrimaryBtn}" Margin="6,0"/>
        </WrapPanel>

        <!-- STATUS -->
        <Border Grid.Row="4" Background="#16213e" CornerRadius="6" Padding="10,6" Margin="0,10,0,0">
            <TextBlock Name="StatusText" Text="Ready - select tweaks and click Apply Selected." Foreground="#aaaaaa" FontSize="12" FontFamily="Consolas"/>
        </Border>
    </Grid>
</Window>
"@

# Parse XAML
$Reader = New-Object System.Xml.XmlNodeReader $XAML
$Window = [Windows.Markup.XamlReader]::Load($Reader)

# Get controls
$HwInfoText   = $Window.FindName("HwInfoText")
$WindowsPanel = $Window.FindName("WindowsPanel")
$GamingPanel  = $Window.FindName("GamingPanel")
$NetworkPanel = $Window.FindName("NetworkPanel")
$BtnApply     = $Window.FindName("BtnApply")
$BtnSelectAll = $Window.FindName("BtnSelectAll")
$BtnDeselect  = $Window.FindName("BtnDeselectAll")
$BtnOpenLog   = $Window.FindName("BtnOpenLog")
$StatusText   = $Window.FindName("StatusText")

$HwInfoText.Text = $HWInfo

# ─────────────────────────────────────────
# BUILD TWEAK ROWS
# ─────────────────────────────────────────
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

    # Checkbox
    $cb                   = New-Object Windows.Controls.CheckBox
    $cb.Content           = $Tweak.Name
    $cb.Tag               = $Tweak.Name
    $cb.VerticalAlignment = "Center"
    $cb.Foreground        = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(221,221,221))
    $cb.FontSize          = 13
    $cb.Margin            = New-Object Windows.Thickness(0,0,8,0)
    $CheckBoxMap[$Tweak.Name] = $cb

    # Info button
    $btn                     = New-Object Windows.Controls.Button
    $btn.Content             = "?"
    $btn.Width               = 22
    $btn.Height              = 22
    $btn.FontSize            = 11
    $btn.Background          = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(22,33,62))
    $btn.Foreground          = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(170,170,170))
    $btn.BorderBrush         = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(68,68,68))
    $btn.BorderThickness     = New-Object Windows.Thickness(1)
    $btn.Cursor              = [System.Windows.Input.Cursors]::Hand
    $btn.VerticalAlignment   = "Center"

    # ── FIX: Enum-Typen statt Strings ──────────────────────────────
    $desc = $Tweak.Desc
    $name = $Tweak.Name
    $btn.Add_Click({
        [System.Windows.MessageBox]::Show(
            $desc,
            "Info: $name",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        )
    })

    $btn.Add_MouseEnter({
        $this.Background = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(233,69,96))
        $this.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(255,255,255))
    })
    $btn.Add_MouseLeave({
        $this.Background = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(22,33,62))
        $this.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(170,170,170))
    })

    $panel.Children.Add($cb)  | Out-Null
    $panel.Children.Add($btn) | Out-Null
    return $panel
}

# Fill panels
$categories = @{ "Windows" = $WindowsPanel; "Gaming" = $GamingPanel; "Network" = $NetworkPanel }
foreach ($cat in @("Windows","Gaming","Network")) {
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

# ─────────────────────────────────────────
# BUTTON EVENTS
# ─────────────────────────────────────────
$BtnSelectAll.Add_Click({
    foreach ($cb in $CheckBoxMap.Values) { $cb.IsChecked = $true }
})

$BtnDeselect.Add_Click({
    foreach ($cb in $CheckBoxMap.Values) { $cb.IsChecked = $false }
})

$BtnOpenLog.Add_Click({
    if (Test-Path $LogFile) {
        Start-Process notepad.exe $LogFile
    } else {
        [System.Windows.MessageBox]::Show(
            "No log file yet. Apply some tweaks first.",
            "Log",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        )
    }
})

$BtnApply.Add_Click({
    $selected = $AllTweaks | Where-Object { $CheckBoxMap[$_.Name].IsChecked -eq $true }

    if ($selected.Count -eq 0) {
        [System.Windows.MessageBox]::Show(
            "No tweaks selected!",
            "WinTweaker",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning
        )
        return
    }

    $confirm = [System.Windows.MessageBox]::Show(
        "Apply $($selected.Count) selected tweak(s)?`n`nA system restore point will be created first.",
        "WinTweaker - Confirm",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )
    if ($confirm -ne "Yes") { return }

    $StatusText.Text = "Creating restore point..."
    try {
        Checkpoint-Computer -Description "WinTweaker Backup" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Log "Restore point created"
    } catch {
        Write-Log "Restore point failed: $_"
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
        "$done tweak(s) applied successfully!`n`nSome changes require a restart.`nLog saved to:`n$LogFile",
        "WinTweaker - Done",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Information
    )
})

# ─────────────────────────────────────────
# LAUNCH
# ─────────────────────────────────────────
Write-Log "WinTweaker started | $HWInfo"
$Window.ShowDialog() | Out-Null
