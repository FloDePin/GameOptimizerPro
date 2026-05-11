#Requires -RunAsAdministrator
<#
.SYNOPSIS
    WinTweaker - Windows & Gaming Optimizer v2.0
.DESCRIPTION
    GUI-based PowerShell optimizer.
    Tabs: Windows | Gaming | Network | RAM & Storage
.AUTHOR
    FloDePin
.VERSION
    2.0.0
#>

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# ADMIN CHECK
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    [System.Windows.Forms.MessageBox]::Show("Please run this script as Administrator!", "WinTweaker - Admin Required", "OK", "Error")
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
$LogFile = "$env:TEMP\WinTweaker_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
function Write-Log {
    param([string]$Message)
    $entry = "[$(Get-Date -Format 'HH:mm:ss')] $Message"
    Add-Content -Path $LogFile -Value $entry
}

# TWEAK DEFINITIONS
$AllTweaks = @(

    # ── WINDOWS / Bloatware ───────────────────────────────────────────
    [PSCustomObject]@{
        Name = "Remove Cortana"
        Desc = "Deinstalliert Cortana vollstaendig. Cortana ist Microsofts Sprachassistent der Daten an Microsoft sendet. Fuer die meisten Nutzer nicht benoetigt."
        Category = "Windows"; Group = "Bloatware"
        Action = { Get-AppxPackage -AllUsers "*Microsoft.549981C3F5F10*" | Remove-AppxPackage -ErrorAction SilentlyContinue; Write-Log "Cortana removed" }
    },
    [PSCustomObject]@{
        Name = "Remove Xbox Apps"
        Desc = "Entfernt Xbox Game Bar, Xbox Identity Provider und Xbox TCUI. Diese Apps laufen im Hintergrund und verbrauchen Ressourcen - auch wenn du keine Xbox hast."
        Category = "Windows"; Group = "Bloatware"
        Action = {
            @("*XboxApp*","*XboxGameOverlay*","*XboxGamingOverlay*","*XboxIdentityProvider*","*XboxSpeechToTextOverlay*","*XboxTCUI*") |
            ForEach-Object { Get-AppxPackage -AllUsers $_ | Remove-AppxPackage -ErrorAction SilentlyContinue }
            Write-Log "Xbox Apps removed"
        }
    },
    [PSCustomObject]@{
        Name = "Remove Microsoft Teams (Personal)"
        Desc = "Entfernt Microsoft Teams (die Consumer-Version). Nicht zu verwechseln mit Teams for Work. Blockiert automatische Neuinstallation."
        Category = "Windows"; Group = "Bloatware"
        Action = {
            Get-AppxPackage -AllUsers "*MicrosoftTeams*" | Remove-AppxPackage -ErrorAction SilentlyContinue
            reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Communications" /v ConfigureChatAutoInstall /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Teams Personal removed"
        }
    },
    [PSCustomObject]@{
        Name = "Remove Copilot"
        Desc = "Deaktiviert und entfernt Windows Copilot (KI-Assistent). Verhindert dass Copilot im Hintergrund laeuft und Daten sendet."
        Category = "Windows"; Group = "Bloatware"
        Action = {
            reg add "HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f | Out-Null
            Get-AppxPackage -AllUsers "*Copilot*" | Remove-AppxPackage -ErrorAction SilentlyContinue
            Write-Log "Copilot disabled"
        }
    },
    [PSCustomObject]@{
        Name = "Remove OneDrive"
        Desc = "Deinstalliert OneDrive komplett inkl. Autostart und Explorer-Integration. Deine lokalen Dateien bleiben unangetastet."
        Category = "Windows"; Group = "Bloatware"
        Action = {
            Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
            Start-Sleep 1
            $od = if (Test-Path "$env:SYSTEMROOT\SysWOW64\OneDriveSetup.exe") { "$env:SYSTEMROOT\SysWOW64\OneDriveSetup.exe" } else { "$env:SYSTEMROOT\System32\OneDriveSetup.exe" }
            if (Test-Path $od) { & $od /uninstall }
            reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v OneDrive /f 2>$null
            Write-Log "OneDrive removed"
        }
    },
    [PSCustomObject]@{
        Name = "Remove Windows Recall"
        Desc = "Deaktiviert Windows Recall - das KI-Feature das Screenshots deiner Aktivitaeten macht und lokal speichert. Datenschutzkritisch."
        Category = "Windows"; Group = "Bloatware"
        Action = {
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v DisableAIDataAnalysis /t REG_DWORD /d 1 /f | Out-Null
            Disable-WindowsOptionalFeature -Online -FeatureName "Recall" -NoRestart -ErrorAction SilentlyContinue | Out-Null
            Write-Log "Recall disabled"
        }
    },
    [PSCustomObject]@{
        Name = "Remove Other Bloatware"
        Desc = "Entfernt vorinstallierte Apps wie: Candy Crush, TikTok, Disney+, Facebook, Instagram, Spotify, News, Weather, Solitaire, Clipchamp, ToDo, Paint3D und weitere."
        Category = "Windows"; Group = "Bloatware"
        Action = {
            @("*king.com*","*Facebook*","*Spotify*","*Disney*","*TikTok*","*Instagram*","*Netflix*","*Twitter*","*BubbleWitch*","*CandyCrush*",
              "*Microsoft.News*","*Microsoft.BingWeather*","*Microsoft.BingNews*","*Microsoft.MicrosoftSolitaireCollection*",
              "*Microsoft.ZuneMusic*","*Microsoft.ZuneVideo*","*Microsoft.WindowsFeedbackHub*","*Microsoft.Todos*",
              "*Microsoft.Paint3D*","*Microsoft.MixedReality*","*Clipchamp*","*Microsoft.GetHelp*","*Microsoft.Getstarted*","*Microsoft.PowerAutomateDesktop*") |
            ForEach-Object { Get-AppxPackage -AllUsers $_ | Remove-AppxPackage -ErrorAction SilentlyContinue }
            Write-Log "Bloatware removed"
        }
    },

    # ── WINDOWS / Privacy ──────────────────────────────────────────────
    [PSCustomObject]@{
        Name = "Disable Telemetry & Data Collection"
        Desc = "Deaktiviert alle Windows-Telemetriedienste (DiagTrack, dmwappushservice). Windows sendet dann keine Nutzungsdaten mehr an Microsoft. Empfohlen fuer alle Nutzer."
        Category = "Windows"; Group = "Privacy"
        Action = {
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
        Name = "Disable Activity History"
        Desc = "Deaktiviert die Windows Aktivitaetsverlauf-Funktion (Timeline). Windows speichert dann nicht mehr welche Apps und Dateien du geoeffnet hast."
        Category = "Windows"; Group = "Privacy"
        Action = {
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v EnableActivityFeed /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v PublishUserActivities /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Activity History disabled"
        }
    },
    [PSCustomObject]@{
        Name = "Disable Advertising ID"
        Desc = "Deaktiviert die Werbe-ID die Windows jedem Nutzer zuweist. Apps koennen dich dann nicht mehr geraeteuebergreifend tracken um personalisierte Werbung zu schalten."
        Category = "Windows"; Group = "Privacy"
        Action = {
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" /v DisabledByGroupPolicy /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "Advertising ID disabled"
        }
    },
    [PSCustomObject]@{
        Name = "Disable Location Tracking"
        Desc = "Deaktiviert den Windows Standortdienst systemweit. Apps koennen deinen Standort nicht mehr abfragen."
        Category = "Windows"; Group = "Privacy"
        Action = {
            reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v Value /t REG_SZ /d Deny /f | Out-Null
            Set-Service lfsvc -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Log "Location tracking disabled"
        }
    },
    [PSCustomObject]@{
        Name = "Block Telemetry Hosts (hosts file)"
        Desc = "Fuegt Microsoft Telemetrie-Server in die Windows hosts-Datei ein und blockt sie. Damit koennen diese Server nicht mehr erreicht werden."
        Category = "Windows"; Group = "Privacy"
        Action = {
            $entries = @("0.0.0.0 telemetry.microsoft.com","0.0.0.0 vortex.data.microsoft.com","0.0.0.0 vortex-win.data.microsoft.com",
                "0.0.0.0 telecommand.telemetry.microsoft.com","0.0.0.0 oca.telemetry.microsoft.com","0.0.0.0 sqm.telemetry.microsoft.com",
                "0.0.0.0 watson.telemetry.microsoft.com","0.0.0.0 redir.metaservices.microsoft.com","0.0.0.0 choice.microsoft.com",
                "0.0.0.0 df.telemetry.microsoft.com","0.0.0.0 reports.wes.df.telemetry.microsoft.com","0.0.0.0 wes.df.telemetry.microsoft.com")
            $hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
            $existing  = Get-Content $hostsFile
            foreach ($e in $entries) { if ($existing -notcontains $e) { Add-Content $hostsFile $e } }
            Write-Log "Telemetry hosts blocked"
        }
    },
    [PSCustomObject]@{
        Name = "Disable Scheduled Telemetry Tasks"
        Desc = "Deaktiviert alle geplanten Windows-Aufgaben die Telemetriedaten sammeln und senden (Microsoft Compatibility Appraiser, Customer Experience Improvement usw.)."
        Category = "Windows"; Group = "Privacy"
        Action = {
            @("\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
              "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
              "\Microsoft\Windows\Autochk\Proxy",
              "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
              "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
              "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector") |
            ForEach-Object { schtasks /Change /TN $_ /Disable 2>$null }
            Write-Log "Telemetry tasks disabled"
        }
    },

    # ── WINDOWS / Performance ──────────────────────────────────────────
    [PSCustomObject]@{
        Name = "Ultimate Performance Plan"
        Desc = "Aktiviert den Ultimative Leistung Energiesparplan. Windows drosselt dann keine CPU-Kerne mehr - maximale Performance zu jeder Zeit. Erhoeht Stromverbrauch."
        Category = "Windows"; Group = "Performance"
        Action = {
            powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
            $guid = (powercfg -list | Select-String "Ultimative Leistung|Ultimate Performance").ToString().Split()[3]
            if ($guid) { powercfg -setactive $guid }
            Write-Log "Ultimate Performance Plan activated"
        }
    },
    [PSCustomObject]@{
        Name = "Disable HPET"
        Desc = "Deaktiviert den High Precision Event Timer. Kann die System-Latenz reduzieren und Gaming-Performance verbessern. Auf manchen Systemen sorgt dies fuer niedrigere Frame-Zeiten."
        Category = "Windows"; Group = "Performance"
        Action = {
            bcdedit /deletevalue useplatformclock 2>$null | Out-Null
            bcdedit /set useplatformtick yes | Out-Null
            bcdedit /set disabledynamictick yes | Out-Null
            Write-Log "HPET disabled"
        }
    },
    [PSCustomObject]@{
        Name = "Set 0.5ms Timer Resolution"
        Desc = "Setzt die Windows Timer-Aufloesung auf 0.5ms (statt Standard 15.6ms). Verbessert die Praezision von Frame-Timing und reduziert Input-Lag in Spielen spuerbar."
        Category = "Windows"; Group = "Performance"
        Action = {
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v GlobalTimerResolutionRequests /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "Timer resolution set to 0.5ms"
        }
    },
    [PSCustomObject]@{
        Name = "Disable Prefetch & Superfetch"
        Desc = "Deaktiviert Prefetch und SysMain (Superfetch). Sinnvoll bei SSDs - auf HDDs nicht empfohlen. Reduziert Hintergrund-Schreibzugriffe."
        Category = "Windows"; Group = "Performance"
        Action = {
            Stop-Service SysMain -Force -ErrorAction SilentlyContinue
            Set-Service SysMain -StartupType Disabled -ErrorAction SilentlyContinue
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnablePrefetcher /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnableSuperfetch /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Prefetch / Superfetch disabled"
        }
    },
    [PSCustomObject]@{
        Name = "Optimize Visual Effects (Performance Mode)"
        Desc = "Schaltet alle Windows-Animationen und visuelle Effekte aus. Windows reagiert dadurch spuerbar schneller - besonders auf schwaecheren Systemen oder beim Gaming."
        Category = "Windows"; Group = "Performance"
        Action = {
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 2 /f | Out-Null
            Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -Value 0
            reg add "HKCU\Control Panel\Desktop\WindowMetrics" /v MinAnimate /t REG_SZ /d 0 /f | Out-Null
            Write-Log "Visual effects set to performance mode"
        }
    },
    [PSCustomObject]@{
        Name = "Disable Windows Search Indexing"
        Desc = "Deaktiviert den Windows Search Indexer (WSearch). Reduziert staendige Festplattenzugriffe im Hintergrund. Suche in Explorer funktioniert weiterhin, aber langsamer."
        Category = "Windows"; Group = "Performance"
        Action = {
            Stop-Service WSearch -Force -ErrorAction SilentlyContinue
            Set-Service WSearch -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Log "Windows Search Indexing disabled"
        }
    },

    # ── WINDOWS / Mouse & UI ──────────────────────────────────────────
    [PSCustomObject]@{
        Name = "Disable Mouse Acceleration"
        Desc = "Deaktiviert die Mausbeschleunigung (Enhance Pointer Precision). Wichtig fuer FPS-Spiele: Deine Mausbewegung wird 1:1 uebertragen ohne dynamische Verstaerkung."
        Category = "Windows"; Group = "Mouse & UI"
        Action = {
            reg add "HKCU\Control Panel\Mouse" /v MouseSpeed /t REG_SZ /d 0 /f | Out-Null
            reg add "HKCU\Control Panel\Mouse" /v MouseThreshold1 /t REG_SZ /d 0 /f | Out-Null
            reg add "HKCU\Control Panel\Mouse" /v MouseThreshold2 /t REG_SZ /d 0 /f | Out-Null
            Write-Log "Mouse acceleration disabled"
        }
    },
    [PSCustomObject]@{
        Name = "Disable Sticky Keys"
        Desc = "Deaktiviert den Sticky Keys Dialog (der beim 5x Shift-Druecken aufpoppt). Verhindert ungewollte Unterbrechungen mitten im Spiel."
        Category = "Windows"; Group = "Mouse & UI"
        Action = {
            reg add "HKCU\Control Panel\Accessibility\StickyKeys" /v Flags /t REG_SZ /d 506 /f | Out-Null
            reg add "HKCU\Control Panel\Accessibility\Keyboard Response" /v Flags /t REG_SZ /d 122 /f | Out-Null
            reg add "HKCU\Control Panel\Accessibility\ToggleKeys" /v Flags /t REG_SZ /d 58 /f | Out-Null
            Write-Log "Sticky Keys disabled"
        }
    },
    [PSCustomObject]@{
        Name = "Enable Dark Mode"
        Desc = "Aktiviert den dunklen Modus fuer Windows und Apps systemweit. Schont die Augen bei langen Sessions - besonders nachts beim Gaming."
        Category = "Windows"; Group = "Mouse & UI"
        Action = {
            reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v AppsUseLightTheme /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v SystemUsesLightTheme /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Dark Mode enabled"
        }
    },
    [PSCustomObject]@{
        Name = "Disable Transparency Effects"
        Desc = "Deaktiviert die Transparenz-Effekte in Taskleiste und Startmenue. Spart GPU-Ressourcen und reduziert leicht den RAM-Verbrauch."
        Category = "Windows"; Group = "Mouse & UI"
        Action = {
            reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Transparency disabled"
        }
    },

    # ── GAMING / In-Game Boosts ───────────────────────────────────────
    [PSCustomObject]@{
        Name = "Enable Game Mode"
        Desc = "Aktiviert den Windows Game Mode. Windows priorisiert dann CPU/GPU-Ressourcen fuer das aktive Spiel und unterdrueckt Windows Update Neustarts waehrend du spielst."
        Category = "Gaming"; Group = "In-Game Boosts"
        Action = {
            reg add "HKCU\Software\Microsoft\GameBar" /v AllowAutoGameMode /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKCU\Software\Microsoft\GameBar" /v AutoGameModeEnabled /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "Game Mode enabled"
        }
    },
    [PSCustomObject]@{
        Name = "Disable Xbox Game Bar"
        Desc = "Deaktiviert die Xbox Game Bar (Win+G Overlay). Verhindert dass die Game Bar im Hintergrund laeuft und Ressourcen verbraucht. Game Mode bleibt davon unberuehrt."
        Category = "Gaming"; Group = "In-Game Boosts"
        Action = {
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v AllowGameDVR /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Xbox Game Bar disabled"
        }
    },
    [PSCustomObject]@{
        Name = "CPU Priority for Games"
        Desc = "Setzt Win32PrioritySeparation auf 26. Windows gibt dann aktiven Spielen deutlich mehr CPU-Zeit und reduziert Hintergrundprozesse. Spuerbar bei CPU-limitierten Spielen."
        Category = "Gaming"; Group = "In-Game Boosts"
        Action = {
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v Win32PrioritySeparation /t REG_DWORD /d 26 /f | Out-Null
            Write-Log "CPU Priority set for gaming"
        }
    },
    [PSCustomObject]@{
        Name = "MMCSS Gaming Profile (High Priority)"
        Desc = "Setzt die Multimedia Class Scheduler Service Profile fuer Spiele auf High Priority. Windows priorisiert dann Audio und Timer-Interrupts fuer besseres Gaming-Erlebnis."
        Category = "Gaming"; Group = "In-Game Boosts"
        Action = {
            $p = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
            reg add $p /v "GPU Priority" /t REG_DWORD /d 8 /f | Out-Null
            reg add $p /v "Priority" /t REG_DWORD /d 6 /f | Out-Null
            reg add $p /v "Scheduling Category" /t REG_SZ /d High /f | Out-Null
            Write-Log "MMCSS Gaming profile set"
        }
    },
    [PSCustomObject]@{
        Name = "Disable Fullscreen Optimizations"
        Desc = "Deaktiviert Windows Fullscreen Optimizations global. Erzwingt echtes Fullscreen fuer niedrigeren Input-Lag anstatt Borderless Windowed."
        Category = "Gaming"; Group = "In-Game Boosts"
        Action = {
            reg add "HKCU\System\GameConfigStore" /v GameDVR_FSEBehaviorMode /t REG_DWORD /d 2 /f | Out-Null
            reg add "HKCU\System\GameConfigStore" /v GameDVR_HonorUserFSEBehaviorMode /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKCU\System\GameConfigStore" /v GameDVR_FSEBehavior /t REG_DWORD /d 2 /f | Out-Null
            Write-Log "Fullscreen Optimizations disabled"
        }
    },

    # ── GAMING / GPU & Driver ─────────────────────────────────────────
    [PSCustomObject]@{
        Name = "NVIDIA Low Latency Mode"
        Desc = "Aktiviert NVIDIA Ultra Low Latency Mode via Registry. Reduziert den Render-Queue auf 1 Frame - weniger Input-Lag. Nur wirksam auf NVIDIA GPUs."
        Category = "Gaming"; Group = "GPU & Driver"
        Action = {
            if ($IsNVIDIA) {
                reg add "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak" /v NVLatency /t REG_DWORD /d 1 /f | Out-Null
                Write-Log "NVIDIA Low Latency Mode enabled"
            } else { Write-Log "NVIDIA Low Latency skipped (no NVIDIA GPU: $GPU)" }
        }
    },
    [PSCustomObject]@{
        Name = "Enable MSI Mode (GPU Interrupts)"
        Desc = "Aktiviert MSI-Modus fuer GPU. Reduziert Interrupt-Latenz erheblich. Standard-Windows nutzt Line-Based Interrupts - MSI ist moderner und schneller. Reboot empfohlen."
        Category = "Gaming"; Group = "GPU & Driver"
        Action = {
            $gpuDev = Get-WmiObject Win32_VideoController | Where-Object { $_.Name -notmatch "Microsoft" } | Select-Object -First 1
            if ($gpuDev) {
                $regPath = "HKLM\SYSTEM\CurrentControlSet\Enum\$($gpuDev.PNPDeviceID)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
                reg add $regPath /v MSISupported /t REG_DWORD /d 1 /f | Out-Null
                Write-Log "MSI Mode enabled for: $($gpuDev.Name)"
            }
        }
    },
    [PSCustomObject]@{
        Name = "Enable Hardware GPU Scheduling (HAGS)"
        Desc = "Aktiviert HAGS - Windows uebergibt GPU-Scheduling direkt an die Hardware. Reduziert CPU-Overhead und Input-Lag. Erfordert NVIDIA RTX 2000+ oder AMD RX 5000+ und Windows 10 2004+."
        Category = "Gaming"; Group = "GPU & Driver"
        Action = {
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v HwSchMode /t REG_DWORD /d 2 /f | Out-Null
            Write-Log "HAGS enabled"
        }
    },
    [PSCustomObject]@{
        Name = "Clear Shader Cache"
        Desc = "Leert den NVIDIA/AMD Shader-Cache auf der Festplatte. Erzwingt beim naechsten Spielstart eine frische Kompilierung. Sinnvoll nach Treiberupdates oder bei Grafikfehlern."
        Category = "Gaming"; Group = "GPU & Driver"
        Action = {
            @("$env:LOCALAPPDATA\NVIDIA\DXCache","$env:LOCALAPPDATA\NVIDIA\GLCache","$env:LOCALAPPDATA\D3DSCache","$env:TEMP\AMD") |
            Where-Object { Test-Path $_ } | ForEach-Object { Remove-Item "$_\*" -Recurse -Force -ErrorAction SilentlyContinue }
            Write-Log "Shader Cache cleared"
        }
    },

    # ── NETWORK / Latency ──────────────────────────────────────────────
    [PSCustomObject]@{
        Name = "Disable Nagle's Algorithm"
        Desc = "Deaktiviert Nagles Algorithmus auf allen Netzwerkadaptern. Nagle buendelt kleine Datenpakete auf Kosten von Latenz. Deaktivieren senkt Ping in Online-Spielen spuerbar."
        Category = "Network"; Group = "Latency"
        Action = {
            Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\*" | ForEach-Object {
                Set-ItemProperty -Path $_.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $_.PSPath -Name "TCPNoDelay" -Value 1 -Type DWord -ErrorAction SilentlyContinue
            }
            Write-Log "Nagle's Algorithm disabled"
        }
    },
    [PSCustomObject]@{
        Name = "Disable Large Send Offload (LSO)"
        Desc = "Deaktiviert Large Send Offload auf allen aktiven Netzwerkadaptern. LSO kann auf manchen Systemen zu Ping-Spikes fuehren."
        Category = "Network"; Group = "Latency"
        Action = {
            Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | ForEach-Object { Disable-NetAdapterLso -Name $_.Name -ErrorAction SilentlyContinue }
            Write-Log "LSO disabled"
        }
    },
    [PSCustomObject]@{
        Name = "Disable TCP Auto-Tuning"
        Desc = "Deaktiviert die automatische TCP-Empfangsfenstergroesse. Kann auf manchen Systemen Latenz-Spikes reduzieren."
        Category = "Network"; Group = "TCP"
        Action = { netsh int tcp set global autotuninglevel=disabled | Out-Null; Write-Log "TCP Auto-Tuning disabled" }
    },
    [PSCustomObject]@{
        Name = "Disable QoS Bandwidth Limit"
        Desc = "Entfernt das Standard-Limit von 20% Bandbreite das Windows fuer QoS reserviert. Gibt dir die volle verfuegbare Bandbreite."
        Category = "Network"; Group = "QoS"
        Action = {
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched" /v NonBestEffortLimit /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "QoS bandwidth limit removed"
        }
    },
    [PSCustomObject]@{
        Name = "Set DNS to Cloudflare (1.1.1.1)"
        Desc = "Setzt den DNS-Server auf Cloudflare 1.1.1.1 (Primary) und 1.0.0.1 (Secondary). Einer der schnellsten und datenschutzfreundlichsten DNS-Anbieter weltweit."
        Category = "Network"; Group = "DNS"
        Action = {
            Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | ForEach-Object {
                Set-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -ServerAddresses ("1.1.1.1","1.0.0.1") -ErrorAction SilentlyContinue
            }
            Write-Log "DNS set to Cloudflare 1.1.1.1"
        }
    },
    [PSCustomObject]@{
        Name = "Flush DNS Cache"
        Desc = "Leert den lokalen DNS-Cache. Sinnvoll nach DNS-Aenderungen oder bei Verbindungsproblemen. Schnell und ohne Nebenwirkungen."
        Category = "Network"; Group = "DNS"
        Action = { ipconfig /flushdns | Out-Null; Write-Log "DNS Cache flushed" }
    },

    # ── RAM & STORAGE / RAM ───────────────────────────────────────────
    [PSCustomObject]@{
        Name = "Increase System RAM for Kernel"
        Desc = "Erhoeht den NonPagedPool Limit fuer den Windows Kernel auf 192 MB. Verbessert Performance bei RAM-intensiven Spielen und reduziert Speicherengpaesse."
        Category = "RAM & Storage"; Group = "RAM"
        Action = {
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v NonPagedPoolSize /t REG_DWORD /d 192 /f | Out-Null
            Write-Log "NonPagedPool increased"
        }
    },
    [PSCustomObject]@{
        Name = "Disable Memory Compression"
        Desc = "Deaktiviert die Windows RAM-Kompression. Auf Systemen mit ausreichend RAM (16GB+) sinnvoll - spart CPU-Zyklen die sonst fuer Kompression genutzt werden."
        Category = "RAM & Storage"; Group = "RAM"
        Action = {
            Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
            Write-Log "Memory Compression disabled"
        }
    },
    [PSCustomObject]@{
        Name = "Clear Standby Memory List"
        Desc = "Leert den Windows Standby-Speicher (gecachte Daten die noch im RAM liegen aber nicht mehr genutzt werden). Befreit RAM sofort fuer aktive Prozesse."
        Category = "RAM & Storage"; Group = "RAM"
        Action = {
            $code = @'
using System;
using System.Runtime.InteropServices;
public class MemTools {
    [DllImport("ntdll.dll")] public static extern uint NtSetSystemInformation(int InfoClass, IntPtr Info, int Length);
    public static void ClearStandbyList() {
        var val = 4; var ptr = Marshal.AllocHGlobal(4);
        Marshal.WriteInt32(ptr, val);
        NtSetSystemInformation(80, ptr, 4);
        Marshal.FreeHGlobal(ptr);
    }
}
'@
            Add-Type -TypeDefinition $code -Language CSharp
            [MemTools]::ClearStandbyList()
            Write-Log "Standby Memory cleared"
        }
    },
    [PSCustomObject]@{
        Name = "Optimize Pagefile (Auto-Managed)"
        Desc = "Setzt die Auslagerungsdatei auf automatisch verwaltet und optimiert die Groesse. Empfohlen fuer Systeme unter 16GB RAM. Bei 32GB+ kann die Pagefile stark reduziert werden."
        Category = "RAM & Storage"; Group = "RAM"
        Action = {
            $cs = Get-WmiObject Win32_ComputerSystem
            $cs.AutomaticManagedPagefile = $true
            $cs.Put() | Out-Null
            Write-Log "Pagefile set to auto-managed"
        }
    },

    # ── RAM & STORAGE / Storage ────────────────────────────────────────
    [PSCustomObject]@{
        Name = "Enable TRIM for SSD"
        Desc = "Aktiviert TRIM fuer alle SSDs. TRIM haelt die SSD-Performance aufrecht indem gloeschte Bloecke sofort als frei markiert werden. Standardmaessig aktiv - aber gut zur Verifikation."
        Category = "RAM & Storage"; Group = "Storage"
        Action = { fsutil behavior set DisableDeleteNotify 0 | Out-Null; Write-Log "TRIM enabled" }
    },
    [PSCustomObject]@{
        Name = "Disable 8.3 Filename Creation"
        Desc = "Deaktiviert die Erstellung von kurzen 8.3 Dateinamen (DOS-Kompatibilitaet). Verbessert NTFS-Performance bei Ordnern mit vielen Dateien - auf modernen Systemen nicht benoetigt."
        Category = "RAM & Storage"; Group = "Storage"
        Action = { fsutil behavior set disable8dot3 1 | Out-Null; Write-Log "8.3 filenames disabled" }
    },
    [PSCustomObject]@{
        Name = "Disable Last Access Timestamp"
        Desc = "Deaktiviert das Aktualisieren des Letzter-Zugriff-Zeitstempels bei jedem Dateilese-Vorgang. Reduziert unnoetige Schreibzugriffe auf die Festplatte spuerbar."
        Category = "RAM & Storage"; Group = "Storage"
        Action = { fsutil behavior set disablelastaccess 1 | Out-Null; Write-Log "Last access timestamp disabled" }
    },
    [PSCustomObject]@{
        Name = "Clean Temp Files"
        Desc = "Loescht alle Dateien in %TEMP% und dem Windows Temp-Ordner. Gibt Speicherplatz frei und kann die System-Performance minimal verbessern. Gaenzlich sicher."
        Category = "RAM & Storage"; Group = "Storage"
        Action = {
            @("$env:TEMP", "$env:SystemRoot\Temp") | ForEach-Object {
                if (Test-Path $_) { Remove-Item "$_\*" -Recurse -Force -ErrorAction SilentlyContinue }
            }
            Write-Log "Temp files cleaned"
        }
    },
    [PSCustomObject]@{
        Name = "Run Disk Cleanup (Silent)"
        Desc = "Fuehrt die Windows Datentraegerbereinigung im Hintergrund aus. Loescht temporaere Dateien, Thumbnails, Windows Update Reste und Papierkorbinhalt."
        Category = "RAM & Storage"; Group = "Storage"
        Action = {
            $sageset = 65535
            Start-Process cleanmgr.exe -ArgumentList "/sagerun:$sageset" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
            Write-Log "Disk Cleanup completed"
        }
    }
)

# WPF XAML GUI
[xml]$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="WinTweaker v2.0 - by FloDePin"
        Height="720" Width="860"
        ResizeMode="CanMinimize"
        WindowStartupLocation="CenterScreen"
        Background="#1a1a2e">
    <Window.Resources>
        <Style TargetType="Button" x:Key="PrimaryBtn">
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Padding" Value="16,8"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Name="bd" Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#e94560"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#c73652"/>
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
            <Setter Property="Foreground" Value="#aaaaaa"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="14,8"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TabItem">
                        <Border Name="bd" Background="#16213e" CornerRadius="6,6,0,0" Margin="2,0" Padding="{TemplateBinding Padding}">
                            <ContentPresenter x:Name="ContentSite" VerticalAlignment="Center" HorizontalAlignment="Center" ContentSource="Header"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#e94560"/>
                                <Setter Property="Foreground" Value="White"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#0f3460"/>
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
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- HEADER -->
        <StackPanel Grid.Row="0" Margin="0,0,0,10">
            <TextBlock Text="&#x26A1; WinTweaker v2.0" FontSize="26" FontWeight="Bold" Foreground="#e94560"/>
            <TextBlock Text="Windows &amp; Gaming Optimizer  |  by FloDePin" FontSize="12" Foreground="#888" Margin="2,2,0,0"/>
        </StackPanel>

        <!-- HW INFO -->
        <Border Grid.Row="1" Background="#16213e" CornerRadius="8" Padding="12,7" Margin="0,0,0,10">
            <TextBlock Name="HwInfoText" Text="Detecting hardware..." FontSize="12" Foreground="#00d4aa" FontFamily="Consolas"/>
        </Border>

        <!-- TABS -->
        <TabControl Grid.Row="2" Background="#16213e" BorderBrush="#333">
            <TabItem Header="&#x1FA9F;  Windows">
                <ScrollViewer Background="#1a1a2e" Padding="8" VerticalScrollBarVisibility="Auto">
                    <StackPanel Name="WindowsPanel" Margin="4"/>
                </ScrollViewer>
            </TabItem>
            <TabItem Header="&#x1F3AE;  Gaming">
                <ScrollViewer Background="#1a1a2e" Padding="8" VerticalScrollBarVisibility="Auto">
                    <StackPanel Name="GamingPanel" Margin="4"/>
                </ScrollViewer>
            </TabItem>
            <TabItem Header="&#x1F310;  Network">
                <ScrollViewer Background="#1a1a2e" Padding="8" VerticalScrollBarVisibility="Auto">
                    <StackPanel Name="NetworkPanel" Margin="4"/>
                </ScrollViewer>
            </TabItem>
            <TabItem Header="&#x1F4BE;  RAM &amp; Storage">
                <ScrollViewer Background="#1a1a2e" Padding="8" VerticalScrollBarVisibility="Auto">
                    <StackPanel Name="StoragePanel" Margin="4"/>
                </ScrollViewer>
            </TabItem>
        </TabControl>

        <!-- BUTTONS -->
        <WrapPanel Grid.Row="3" Margin="0,10,0,0" HorizontalAlignment="Center">
            <Button Name="BtnSelectAll"   Content="&#x2611; Select All"     Background="#0f3460" Style="{StaticResource PrimaryBtn}" Margin="6,0"/>
            <Button Name="BtnDeselectAll" Content="&#x2610; Deselect All"   Background="#0f3460" Style="{StaticResource PrimaryBtn}" Margin="6,0"/>
            <Button Name="BtnApply"       Content="&#x2705; Apply Selected" Background="#e94560" Style="{StaticResource PrimaryBtn}" Margin="6,0"/>
            <Button Name="BtnOpenLog"     Content="&#x1F4CB; Open Log"      Background="#0f3460" Style="{StaticResource PrimaryBtn}" Margin="6,0"/>
        </WrapPanel>

        <!-- PROGRESS BAR -->
        <ProgressBar Name="ProgressBar" Grid.Row="4" Height="6" Margin="0,8,0,0"
                     Minimum="0" Maximum="100" Value="0"
                     Background="#16213e" Foreground="#e94560" BorderThickness="0"/>

        <!-- STATUS -->
        <Border Grid.Row="5" Background="#16213e" CornerRadius="6" Padding="10,6" Margin="0,6,0,0">
            <TextBlock Name="StatusText" Text="Ready - select tweaks and click Apply Selected."
                       Foreground="#aaaaaa" FontSize="12" FontFamily="Consolas"/>
        </Border>
    </Grid>
</Window>
"@

$Reader      = New-Object System.Xml.XmlNodeReader $XAML
$Window      = [Windows.Markup.XamlReader]::Load($Reader)
$HwInfoText  = $Window.FindName("HwInfoText")
$WindowsPanel= $Window.FindName("WindowsPanel")
$GamingPanel = $Window.FindName("GamingPanel")
$NetworkPanel= $Window.FindName("NetworkPanel")
$StoragePanel= $Window.FindName("StoragePanel")
$BtnApply    = $Window.FindName("BtnApply")
$BtnSelectAll= $Window.FindName("BtnSelectAll")
$BtnDeselect = $Window.FindName("BtnDeselectAll")
$BtnOpenLog  = $Window.FindName("BtnOpenLog")
$StatusText  = $Window.FindName("StatusText")
$ProgressBar = $Window.FindName("ProgressBar")

$HwInfoText.Text = $HWInfo
$CheckBoxMap = @{}

function New-GroupHeader([string]$Title) {
    $tb = New-Object Windows.Controls.TextBlock
    $tb.Text       = $Title
    $tb.FontSize   = 12
    $tb.FontWeight = "SemiBold"
    $tb.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(0,212,170))
    $tb.Margin     = New-Object Windows.Thickness(0,14,0,4)
    return $tb
}

function New-TweakRow($Tweak) {
    $row = New-Object Windows.Controls.StackPanel
    $row.Orientation = "Horizontal"
    $row.Margin      = New-Object Windows.Thickness(0,3,0,3)

    $cb = New-Object Windows.Controls.CheckBox
    $cb.Content           = $Tweak.Name
    $cb.Tag               = $Tweak.Name
    $cb.VerticalAlignment = "Center"
    $cb.Foreground        = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(221,221,221))
    $cb.FontSize          = 13
    $cb.Margin            = New-Object Windows.Thickness(0,0,8,0)
    $CheckBoxMap[$Tweak.Name] = $cb

    $btn          = New-Object Windows.Controls.Button
    $btn.Content  = "?"
    $btn.Width    = 22
    $btn.Height   = 22
    $btn.FontSize = 11
    $btn.BorderThickness = New-Object Windows.Thickness(1)
    $btn.VerticalAlignment = "Center"
    $btn.Cursor   = [System.Windows.Input.Cursors]::Hand

    # Store colors as resources on the button so closures can access them
    $colorNormal  = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(22,33,62))
    $colorHover   = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(233,69,96))
    $fgNormal     = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(170,170,170))
    $fgHover      = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(255,255,255))
    $borderNormal = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(68,68,68))

    $btn.Background   = $colorNormal
    $btn.Foreground   = $fgNormal
    $btn.BorderBrush  = $borderNormal

    $desc = $Tweak.Desc
    $name = $Tweak.Name

    $btn.Add_Click({
        [System.Windows.MessageBox]::Show($desc, "Info:  $name", "OK", "Information")
    })
    $btn.Add_MouseEnter({
        $this.Background = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(233,69,96))
        $this.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(255,255,255))
        $this.BorderBrush = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(233,69,96))
    })
    $btn.Add_MouseLeave({
        $this.Background = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(22,33,62))
        $this.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(170,170,170))
        $this.BorderBrush = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(68,68,68))
    })

    $row.Children.Add($cb)  | Out-Null
    $row.Children.Add($btn) | Out-Null
    return $row
}

# Fill panels
$panelMap = @{
    "Windows"      = $WindowsPanel
    "Gaming"       = $GamingPanel
    "Network"      = $NetworkPanel
    "RAM & Storage"= $StoragePanel
}

foreach ($cat in @("Windows","Gaming","Network","RAM & Storage")) {
    $panel  = $panelMap[$cat]
    $groups = $AllTweaks | Where-Object { $_.Category -eq $cat } | Select-Object -ExpandProperty Group -Unique
    foreach ($grp in $groups) {
        $panel.Children.Add((New-GroupHeader "── $grp")) | Out-Null
        $AllTweaks | Where-Object { $_.Category -eq $cat -and $_.Group -eq $grp } | ForEach-Object {
            $panel.Children.Add((New-TweakRow $_)) | Out-Null
        }
    }
}

# BUTTON EVENTS
$BtnSelectAll.Add_Click({ foreach ($cb in $CheckBoxMap.Values) { $cb.IsChecked = $true } })
$BtnDeselect.Add_Click({ foreach ($cb in $CheckBoxMap.Values) { $cb.IsChecked = $false } })
$BtnOpenLog.Add_Click({
    if (Test-Path $LogFile) { Start-Process notepad.exe $LogFile }
    else { [System.Windows.MessageBox]::Show("No log file yet. Apply some tweaks first.", "Log", "OK", "Information") }
})

$BtnApply.Add_Click({
    $selected = @($AllTweaks | Where-Object { $CheckBoxMap[$_.Name].IsChecked -eq $true })
    if ($selected.Count -eq 0) {
        [System.Windows.MessageBox]::Show("No tweaks selected!", "WinTweaker", "OK", "Warning")
        return
    }

    $confirm = [System.Windows.MessageBox]::Show(
        "Apply $($selected.Count) selected tweak(s)?`n`nA system restore point will be created first.",
        "WinTweaker v2.0 - Confirm", "YesNo", "Question")
    if ($confirm -ne "Yes") { return }

    $StatusText.Text  = "Creating restore point..."
    $ProgressBar.Value = 0
    $Window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Render)

    try {
        Checkpoint-Computer -Description "WinTweaker v2.0 Backup" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Log "Restore point created"
    } catch {
        Write-Log "Restore point failed (may already exist): $_"
    }

    $done = 0
    $total = $selected.Count
    foreach ($tweak in $selected) {
        $done++
        $pct = [math]::Round(($done / $total) * 100)
        $StatusText.Text   = "[$done/$total] Applying: $($tweak.Name)..."
        $ProgressBar.Value = $pct
        $Window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Render)
        try   { & $tweak.Action; Write-Log "OK: $($tweak.Name)" }
        catch { Write-Log "FAILED: $($tweak.Name) - $_" }
    }

    $ProgressBar.Value = 100
    $StatusText.Text   = "Done! $done tweak(s) applied. Log: $LogFile"
    [System.Windows.MessageBox]::Show(
        "Done! $done tweak(s) applied.`n`nSome changes need a restart to take effect.`nLog: $LogFile",
        "WinTweaker v2.0 - Done", "OK", "Information")
})

Write-Log "WinTweaker v2.0 started | $HWInfo"
$Window.ShowDialog() | Out-Null
