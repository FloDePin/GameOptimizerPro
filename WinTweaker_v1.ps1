#Requires -RunAsAdministrator
<#
.SYNOPSIS
    WinTweaker - Windows and Gaming Optimizer
.AUTHOR
    FloDePin
.VERSION
    3.0.0
#>

# HIDE CONSOLE WINDOW
Add-Type -Name ConsoleUtils -Namespace WinTweaker -MemberDefinition @'
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]   public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'@
[WinTweaker.ConsoleUtils]::ShowWindow([WinTweaker.ConsoleUtils]::GetConsoleWindow(), 0) | Out-Null

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# ADMIN CHECK
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    [System.Windows.MessageBox]::Show("Please run as Administrator!", "WinTweaker", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    exit
}

# HARDWARE DETECTION
$GPU        = (Get-WmiObject Win32_VideoController | Where-Object { $_.Name -notmatch "Microsoft" } | Select-Object -First 1).Name
$CPU        = (Get-WmiObject Win32_Processor | Select-Object -First 1).Name
$RAM        = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
$IsNVIDIA   = $GPU -match "NVIDIA"
$IsAMD      = $GPU -match "AMD|Radeon"
$HWInfo     = "GPU: $GPU   |   CPU: $CPU   |   RAM: $RAM GB"

# LOGGING
$LogFile = "$env:TEMP\WinTweaker_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
function Write-Log { param([string]$Message); Add-Content -Path $LogFile -Value "[$(Get-Date -Format 'HH:mm:ss')] $Message" }


$AllTweaks = @(
    # WINDOWS / BLOATWARE
    [PSCustomObject]@{ Name="Remove Cortana"; Desc="Deinstalliert Cortana vollstaendig. Sendet Daten an Microsoft."; Category="Windows"; Group="Bloatware"; Action={
        Get-AppxPackage -AllUsers "*Microsoft.549981C3F5F10*" | Remove-AppxPackage -ErrorAction SilentlyContinue
        Write-Log "Cortana removed" }},
    [PSCustomObject]@{ Name="Remove Xbox Apps"; Desc="Entfernt Xbox Game Bar, Xbox Identity Provider und Xbox TCUI."; Category="Windows"; Group="Bloatware"; Action={
        @("*XboxApp*","*XboxGameOverlay*","*XboxGamingOverlay*","*XboxIdentityProvider*","*XboxSpeechToTextOverlay*","*XboxTCUI*") | ForEach-Object { Get-AppxPackage -AllUsers $_ | Remove-AppxPackage -ErrorAction SilentlyContinue }
        Write-Log "Xbox Apps removed" }},
    [PSCustomObject]@{ Name="Remove Microsoft Teams Personal"; Desc="Entfernt Microsoft Teams (Consumer) und blockiert automatische Neuinstallation."; Category="Windows"; Group="Bloatware"; Action={
        Get-AppxPackage -AllUsers "*MicrosoftTeams*" | Remove-AppxPackage -ErrorAction SilentlyContinue
        reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Communications" /v ConfigureChatAutoInstall /t REG_DWORD /d 0 /f | Out-Null
        Write-Log "Teams Personal removed" }},
    [PSCustomObject]@{ Name="Remove Copilot"; Desc="Deaktiviert und entfernt Windows Copilot. Verhindert Hintergrundlauf."; Category="Windows"; Group="Bloatware"; Action={
        reg add "HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f | Out-Null
        Get-AppxPackage -AllUsers "*Copilot*" | Remove-AppxPackage -ErrorAction SilentlyContinue
        Write-Log "Copilot disabled" }},
    [PSCustomObject]@{ Name="Remove OneDrive"; Desc="Deinstalliert OneDrive komplett inkl. Autostart. Lokale Dateien bleiben erhalten."; Category="Windows"; Group="Bloatware"; Action={
        Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue; Start-Sleep 1
        $od = "$env:SYSTEMROOT\SysWOW64\OneDriveSetup.exe"
        if (!(Test-Path $od)) { $od = "$env:SYSTEMROOT\System32\OneDriveSetup.exe" }
        if (Test-Path $od) { & $od /uninstall }
        reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v OneDrive /f 2>$null
        Write-Log "OneDrive removed" }},
    [PSCustomObject]@{ Name="Remove Windows Recall"; Desc="Deaktiviert Windows Recall - das KI-Feature das Screenshots deiner Aktivitaeten macht."; Category="Windows"; Group="Bloatware"; Action={
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v DisableAIDataAnalysis /t REG_DWORD /d 1 /f | Out-Null
        Disable-WindowsOptionalFeature -Online -FeatureName "Recall" -NoRestart -ErrorAction SilentlyContinue | Out-Null
        Write-Log "Recall disabled" }},
    [PSCustomObject]@{ Name="Remove Other Bloatware"; Desc="Entfernt Candy Crush, TikTok, Disney+, Spotify, Solitaire, Clipchamp, ToDo, Paint3D und weitere."; Category="Windows"; Group="Bloatware"; Action={
        @("*king.com*","*Facebook*","*Spotify*","*Disney*","*TikTok*","*Instagram*","*Netflix*","*Twitter*","*BubbleWitch*","*CandyCrush*","*Microsoft.News*","*Microsoft.BingWeather*","*Microsoft.BingNews*","*Microsoft.MicrosoftSolitaireCollection*","*Microsoft.ZuneMusic*","*Microsoft.ZuneVideo*","*Microsoft.WindowsFeedbackHub*","*Microsoft.Todos*","*Microsoft.Paint3D*","*Clipchamp*","*Microsoft.GetHelp*","*Microsoft.Getstarted*") | ForEach-Object { Get-AppxPackage -AllUsers $_ | Remove-AppxPackage -ErrorAction SilentlyContinue }
        Write-Log "Bloatware removed" }},

    # WINDOWS / PRIVACY
    [PSCustomObject]@{ Name="Disable Telemetry and Data Collection"; Desc="Deaktiviert alle Windows-Telemetriedienste. Windows sendet keine Nutzungsdaten mehr an Microsoft."; Category="Windows"; Group="Privacy"; Action={
        Stop-Service DiagTrack -Force -ErrorAction SilentlyContinue
        Set-Service DiagTrack -StartupType Disabled -ErrorAction SilentlyContinue
        Stop-Service dmwappushservice -Force -ErrorAction SilentlyContinue
        Set-Service dmwappushservice -StartupType Disabled -ErrorAction SilentlyContinue
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f | Out-Null
        Write-Log "Telemetry disabled" }},
    [PSCustomObject]@{ Name="Disable Activity History"; Desc="Deaktiviert die Windows Timeline-Funktion."; Category="Windows"; Group="Privacy"; Action={
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v EnableActivityFeed /t REG_DWORD /d 0 /f | Out-Null
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v PublishUserActivities /t REG_DWORD /d 0 /f | Out-Null
        Write-Log "Activity History disabled" }},
    [PSCustomObject]@{ Name="Disable Advertising ID"; Desc="Deaktiviert die Werbe-ID. Apps koennen dich nicht mehr geraeteuebergreifend tracken."; Category="Windows"; Group="Privacy"; Action={
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" /v DisabledByGroupPolicy /t REG_DWORD /d 1 /f | Out-Null
        Write-Log "Advertising ID disabled" }},
    [PSCustomObject]@{ Name="Disable Location Tracking"; Desc="Deaktiviert den Windows Standortdienst systemweit."; Category="Windows"; Group="Privacy"; Action={
        reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v Value /t REG_SZ /d Deny /f | Out-Null
        Set-Service lfsvc -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Log "Location tracking disabled" }},
    [PSCustomObject]@{ Name="Block Telemetry Hosts"; Desc="Fuegt Microsoft Telemetrie-Server in die hosts-Datei ein und blockt sie komplett."; Category="Windows"; Group="Privacy"; Action={
        $hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
        $existing  = Get-Content $hostsFile
        @("0.0.0.0 telemetry.microsoft.com","0.0.0.0 vortex.data.microsoft.com","0.0.0.0 vortex-win.data.microsoft.com","0.0.0.0 telecommand.telemetry.microsoft.com","0.0.0.0 oca.telemetry.microsoft.com","0.0.0.0 watson.telemetry.microsoft.com","0.0.0.0 df.telemetry.microsoft.com") | ForEach-Object { if ($existing -notcontains $_) { Add-Content $hostsFile $_ } }
        Write-Log "Telemetry hosts blocked" }},
    [PSCustomObject]@{ Name="Disable Scheduled Telemetry Tasks"; Desc="Deaktiviert alle geplanten Windows-Aufgaben die Telemetriedaten sammeln."; Category="Windows"; Group="Privacy"; Action={
        @("\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser","\Microsoft\Windows\Application Experience\ProgramDataUpdater","\Microsoft\Windows\Customer Experience Improvement Program\Consolidator","\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip","\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector") | ForEach-Object { schtasks /Change /TN $_ /Disable 2>$null }
        Write-Log "Telemetry tasks disabled" }},

    # WINDOWS / PERFORMANCE
    [PSCustomObject]@{ Name="Ultimate Performance Plan"; Desc="Aktiviert den Ultimative Leistung Energiesparplan. CPU wird nicht mehr gedrosselt."; Category="Windows"; Group="Performance"; Action={
        powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
        $guid = (powercfg -list | Select-String "Ultimative Leistung|Ultimate Performance").ToString().Split()[3]
        if ($guid) { powercfg -setactive $guid }
        Write-Log "Ultimate Performance Plan activated" }},
    [PSCustomObject]@{ Name="Disable HPET"; Desc="Deaktiviert den High Precision Event Timer. Kann Latenz reduzieren und Gaming-Performance verbessern."; Category="Windows"; Group="Performance"; Action={
        bcdedit /deletevalue useplatformclock 2>$null | Out-Null
        bcdedit /set useplatformtick yes | Out-Null
        bcdedit /set disabledynamictick yes | Out-Null
        Write-Log "HPET disabled" }},
    [PSCustomObject]@{ Name="Set 0.5ms Timer Resolution"; Desc="Setzt Timer-Aufloesung auf 0.5ms statt 15.6ms. Verbessert Frame-Timing und Input-Lag."; Category="Windows"; Group="Performance"; Action={
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v GlobalTimerResolutionRequests /t REG_DWORD /d 1 /f | Out-Null
        Write-Log "Timer resolution 0.5ms set" }},
    [PSCustomObject]@{ Name="Disable Prefetch and Superfetch"; Desc="Deaktiviert SysMain und Prefetch. Sinnvoll bei SSDs. Reduziert Hintergrund-Schreibzugriffe."; Category="Windows"; Group="Performance"; Action={
        Stop-Service SysMain -Force -ErrorAction SilentlyContinue
        Set-Service SysMain -StartupType Disabled -ErrorAction SilentlyContinue
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnablePrefetcher /t REG_DWORD /d 0 /f | Out-Null
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnableSuperfetch /t REG_DWORD /d 0 /f | Out-Null
        Write-Log "Prefetch and Superfetch disabled" }},
    [PSCustomObject]@{ Name="Optimize Visual Effects Performance Mode"; Desc="Schaltet alle Windows-Animationen aus. Spuerbar schnellere Reaktion."; Category="Windows"; Group="Performance"; Action={
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 2 /f | Out-Null
        Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -Value 0
        reg add "HKCU\Control Panel\Desktop\WindowMetrics" /v MinAnimate /t REG_SZ /d 0 /f | Out-Null
        Write-Log "Visual effects performance mode set" }},
    [PSCustomObject]@{ Name="Disable Windows Search Indexing"; Desc="Deaktiviert den Windows Search Indexer. Reduziert Hintergrund-Festplattenzugriffe."; Category="Windows"; Group="Performance"; Action={
        Stop-Service WSearch -Force -ErrorAction SilentlyContinue
        Set-Service WSearch -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Log "Windows Search Indexing disabled" }},

    # WINDOWS / MOUSE AND UI
    [PSCustomObject]@{ Name="Disable Mouse Acceleration"; Desc="Deaktiviert Mausbeschleunigung. Wichtig fuer FPS-Spiele: 1-zu-1 Uebertragung ohne Verstaerkung."; Category="Windows"; Group="Mouse and UI"; Action={
        reg add "HKCU\Control Panel\Mouse" /v MouseSpeed /t REG_SZ /d 0 /f | Out-Null
        reg add "HKCU\Control Panel\Mouse" /v MouseThreshold1 /t REG_SZ /d 0 /f | Out-Null
        reg add "HKCU\Control Panel\Mouse" /v MouseThreshold2 /t REG_SZ /d 0 /f | Out-Null
        Write-Log "Mouse acceleration disabled" }},
    [PSCustomObject]@{ Name="Disable Sticky Keys"; Desc="Deaktiviert den Sticky Keys Dialog beim 5x Shift-Druecken. Kein Unterbrechen im Spiel mehr."; Category="Windows"; Group="Mouse and UI"; Action={
        reg add "HKCU\Control Panel\Accessibility\StickyKeys" /v Flags /t REG_SZ /d 506 /f | Out-Null
        reg add "HKCU\Control Panel\Accessibility\Keyboard Response" /v Flags /t REG_SZ /d 122 /f | Out-Null
        reg add "HKCU\Control Panel\Accessibility\ToggleKeys" /v Flags /t REG_SZ /d 58 /f | Out-Null
        Write-Log "Sticky Keys disabled" }},
    [PSCustomObject]@{ Name="Enable Dark Mode"; Desc="Aktiviert den dunklen Modus fuer Windows und Apps systemweit."; Category="Windows"; Group="Mouse and UI"; Action={
        reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v AppsUseLightTheme /t REG_DWORD /d 0 /f | Out-Null
        reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v SystemUsesLightTheme /t REG_DWORD /d 0 /f | Out-Null
        Write-Log "Dark Mode enabled" }},
    [PSCustomObject]@{ Name="Disable Transparency Effects"; Desc="Deaktiviert Transparenz in Taskleiste und Startmenue. Spart GPU-Ressourcen."; Category="Windows"; Group="Mouse and UI"; Action={
        reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 0 /f | Out-Null
        Write-Log "Transparency disabled" }},

    # GAMING / IN-GAME BOOSTS
    [PSCustomObject]@{ Name="Enable Game Mode"; Desc="Aktiviert Windows Game Mode. Priorisiert CPU/GPU fuer das aktive Spiel."; Category="Gaming"; Group="In-Game Boosts"; Action={
        reg add "HKCU\Software\Microsoft\GameBar" /v AllowAutoGameMode /t REG_DWORD /d 1 /f | Out-Null
        reg add "HKCU\Software\Microsoft\GameBar" /v AutoGameModeEnabled /t REG_DWORD /d 1 /f | Out-Null
        Write-Log "Game Mode enabled" }},
    [PSCustomObject]@{ Name="Disable Xbox Game Bar"; Desc="Deaktiviert die Xbox Game Bar (Win+G). Verhindert Hintergrundlauf."; Category="Gaming"; Group="In-Game Boosts"; Action={
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 0 /f | Out-Null
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v AllowGameDVR /t REG_DWORD /d 0 /f | Out-Null
        Write-Log "Xbox Game Bar disabled" }},
    [PSCustomObject]@{ Name="CPU Priority for Games"; Desc="Setzt Win32PrioritySeparation auf 26. Mehr CPU-Zeit fuer aktive Spiele."; Category="Gaming"; Group="In-Game Boosts"; Action={
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v Win32PrioritySeparation /t REG_DWORD /d 26 /f | Out-Null
        Write-Log "CPU Priority for gaming set" }},
    [PSCustomObject]@{ Name="MMCSS Gaming High Priority"; Desc="Setzt MMCSS-Profile fuer Spiele auf High Priority. Besseres Audio und Timer-Timing."; Category="Gaming"; Group="In-Game Boosts"; Action={
        reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "GPU Priority" /t REG_DWORD /d 8 /f | Out-Null
        reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "Priority" /t REG_DWORD /d 6 /f | Out-Null
        reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "Scheduling Category" /t REG_SZ /d High /f | Out-Null
        Write-Log "MMCSS Gaming profile set" }},
    [PSCustomObject]@{ Name="Disable Fullscreen Optimizations"; Desc="Erzwingt echtes Fullscreen global. Weniger Input-Lag als Borderless Window."; Category="Gaming"; Group="In-Game Boosts"; Action={
        reg add "HKCU\System\GameConfigStore" /v GameDVR_FSEBehaviorMode /t REG_DWORD /d 2 /f | Out-Null
        reg add "HKCU\System\GameConfigStore" /v GameDVR_HonorUserFSEBehaviorMode /t REG_DWORD /d 1 /f | Out-Null
        reg add "HKCU\System\GameConfigStore" /v GameDVR_FSEBehavior /t REG_DWORD /d 2 /f | Out-Null
        Write-Log "Fullscreen Optimizations disabled" }},
    [PSCustomObject]@{ Name="Disable Windows Update during Gaming"; Desc="Setzt Active Hours auf 8-23 Uhr. Windows laed keine Updates waehrend du spielst."; Category="Gaming"; Group="In-Game Boosts"; Action={
        reg add "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v ActiveHoursStart /t REG_DWORD /d 8 /f | Out-Null
        reg add "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v ActiveHoursEnd /t REG_DWORD /d 23 /f | Out-Null
        Write-Log "Windows Update active hours set 8-23" }},
    [PSCustomObject]@{ Name="Disable Background App Throttling"; Desc="Deaktiviert das Drosseln von Hintergrundprozessen. Verhindert Frame-Drops."; Category="Gaming"; Group="In-Game Boosts"; Action={
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v DisableLowQosTimerResolution /t REG_DWORD /d 1 /f | Out-Null
        Write-Log "Background App Throttling disabled" }},
    [PSCustomObject]@{ Name="Enable DirectX 12 Optimization"; Desc="Optimiert DirectX 12 Einstellungen fuer niedrigere Latenz. Relevant fuer RTX und RDNA2+ Karten."; Category="Gaming"; Group="In-Game Boosts"; Action={
        reg add "HKLM\SOFTWARE\Microsoft\DirectX" /v DisableDriverOptimizations /t REG_DWORD /d 0 /f | Out-Null
        Write-Log "DirectX 12 optimization set" }},

    # GAMING / GPU AND DRIVER
    [PSCustomObject]@{ Name="NVIDIA Low Latency Mode"; Desc="Aktiviert NVIDIA Ultra Low Latency Mode. Render-Queue auf 1 Frame. Nur auf NVIDIA wirksam."; Category="Gaming"; Group="GPU and Driver"; Action={
        if ($IsNVIDIA) {
            reg add "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak" /v NVLatency /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "NVIDIA Low Latency Mode enabled"
        } else { Write-Log "NVIDIA Low Latency skipped (GPU: $GPU)" } }},
    [PSCustomObject]@{ Name="Enable MSI Mode for GPU"; Desc="Aktiviert MSI-Modus fuer GPU. Reduziert Interrupt-Latenz erheblich. Reboot empfohlen."; Category="Gaming"; Group="GPU and Driver"; Action={
        $gpuObj = Get-WmiObject Win32_VideoController | Where-Object { $_.Name -notmatch "Microsoft" } | Select-Object -First 1
        if ($gpuObj) {
            $regPath = "HKLM\SYSTEM\CurrentControlSet\Enum\$($gpuObj.PNPDeviceID)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
            reg add $regPath /v MSISupported /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "MSI Mode enabled: $($gpuObj.Name)"
        } }},
    [PSCustomObject]@{ Name="Enable Hardware GPU Scheduling HAGS"; Desc="Aktiviert HAGS. GPU-Scheduling direkt an Hardware. Weniger CPU-Overhead. Braucht RTX 2000+ oder RX 5000+."; Category="Gaming"; Group="GPU and Driver"; Action={
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v HwSchMode /t REG_DWORD /d 2 /f | Out-Null
        Write-Log "HAGS enabled" }},
    [PSCustomObject]@{ Name="Clear Shader Cache"; Desc="Leert NVIDIA und AMD Shader-Cache. Sinnvoll nach Treiberupdates oder bei Grafikfehlern."; Category="Gaming"; Group="GPU and Driver"; Action={
        if ($IsNVIDIA) {
            foreach ($p in @("$env:LOCALAPPDATA\NVIDIA\DXCache","$env:LOCALAPPDATA\NVIDIA\GLCache")) { if (Test-Path $p) { Remove-Item "$p\*" -Recurse -Force -ErrorAction SilentlyContinue } }
        }
        if ($IsAMD) { if (Test-Path "$env:TEMP\AMD") { Remove-Item "$env:TEMP\AMD\*" -Recurse -Force -ErrorAction SilentlyContinue } }
        if (Test-Path "$env:LOCALAPPDATA\D3DSCache") { Remove-Item "$env:LOCALAPPDATA\D3DSCache\*" -Recurse -Force -ErrorAction SilentlyContinue }
        Write-Log "Shader Cache cleared" }},

    # NETWORK
    [PSCustomObject]@{ Name="Disable Nagles Algorithm"; Desc="Deaktiviert Nagles Algorithmus. Buendelt keine Pakete mehr auf Kosten von Latenz. Senkt Ping spuerbar."; Category="Network"; Group="Latency"; Action={
        Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\*" | ForEach-Object {
            Set-ItemProperty -Path $_.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $_.PSPath -Name "TCPNoDelay" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        }
        Write-Log "Nagle's Algorithm disabled" }},
    [PSCustomObject]@{ Name="Disable Large Send Offload LSO"; Desc="Deaktiviert LSO auf allen aktiven Adaptern. LSO kann Ping-Spikes verursachen."; Category="Network"; Group="Latency"; Action={
        Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | ForEach-Object { Disable-NetAdapterLso -Name $_.Name -ErrorAction SilentlyContinue }
        Write-Log "LSO disabled" }},
    [PSCustomObject]@{ Name="Disable Network Throttling Index"; Desc="Setzt NetworkThrottlingIndex auf max. Hebt das Standard-Limit von 10 Interrupts/s auf."; Category="Network"; Group="Latency"; Action={
        reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v NetworkThrottlingIndex /t REG_DWORD /d 0xFFFFFFFF /f | Out-Null
        Write-Log "Network Throttling Index removed" }},
    [PSCustomObject]@{ Name="Set DNS to Cloudflare 1.1.1.1"; Desc="Setzt DNS auf Cloudflare 1.1.1.1 und 1.0.0.1. Schnell und datenschutzfreundlich."; Category="Network"; Group="DNS"; Action={
        Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | ForEach-Object { Set-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -ServerAddresses ("1.1.1.1","1.0.0.1") -ErrorAction SilentlyContinue }
        Write-Log "DNS set to Cloudflare 1.1.1.1" }},
    [PSCustomObject]@{ Name="Set DNS to Google 8.8.8.8"; Desc="Setzt DNS auf Google 8.8.8.8 und 8.8.4.4. Alternative zu Cloudflare."; Category="Network"; Group="DNS"; Action={
        Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | ForEach-Object { Set-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -ServerAddresses ("8.8.8.8","8.8.4.4") -ErrorAction SilentlyContinue }
        Write-Log "DNS set to Google 8.8.8.8" }},
    [PSCustomObject]@{ Name="Flush DNS Cache"; Desc="Leert den lokalen DNS-Cache. Sinnvoll nach DNS-Aenderungen oder Verbindungsproblemen."; Category="Network"; Group="DNS"; Action={
        ipconfig /flushdns | Out-Null
        Write-Log "DNS Cache flushed" }},
    [PSCustomObject]@{ Name="Disable TCP Auto-Tuning"; Desc="Deaktiviert automatische TCP-Empfangsfenstergroesse. Kann Latenz-Spikes reduzieren."; Category="Network"; Group="TCP"; Action={
        netsh int tcp set global autotuninglevel=disabled | Out-Null
        Write-Log "TCP Auto-Tuning disabled" }},
    [PSCustomObject]@{ Name="Optimize TCP Settings"; Desc="Deaktiviert TCP Timestamps und Chimney. Reduziert Overhead fuer Gaming."; Category="Network"; Group="TCP"; Action={
        netsh int tcp set global timestamps=disabled | Out-Null
        netsh int tcp set global chimney=disabled | Out-Null
        netsh int tcp set global rss=enabled | Out-Null
        reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpTimedWaitDelay /t REG_DWORD /d 30 /f | Out-Null
        Write-Log "TCP settings optimized" }},
    [PSCustomObject]@{ Name="Disable QoS Bandwidth Limit"; Desc="Entfernt das Standard-Limit von 20 Prozent Bandbreite fuer QoS. Volle Bandbreite fuer dich."; Category="Network"; Group="QoS"; Action={
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched" /v NonBestEffortLimit /t REG_DWORD /d 0 /f | Out-Null
        Write-Log "QoS bandwidth limit removed" }},

    # RAM AND STORAGE
    [PSCustomObject]@{ Name="Optimize Virtual Memory Page File"; Desc="Setzt Auslagerungsdatei auf festen Wert (RAM x 1.5). Verhindert dynamisches Wachsen."; Category="RAM and Storage"; Group="Memory"; Action={
        $ramMB = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1MB)
        $cs = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges
        $cs.AutomaticManagedPagefile = $false; $cs.Put() | Out-Null
        $pf = Get-WmiObject -Query "Select * From Win32_PageFileSetting"
        if ($pf) { $pf.InitialSize = [math]::Round($ramMB*1.5); $pf.MaximumSize = [math]::Round($ramMB*2); $pf.Put() | Out-Null }
        Write-Log "PageFile optimized" }},
    [PSCustomObject]@{ Name="Clear Page File on Shutdown"; Desc="Loescht die Auslagerungsdatei beim Herunterfahren. Schuetzt sensible RAM-Daten."; Category="RAM and Storage"; Group="Memory"; Action={
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v ClearPageFileAtShutdown /t REG_DWORD /d 1 /f | Out-Null
        Write-Log "Clear PageFile on shutdown enabled" }},
    [PSCustomObject]@{ Name="Disable Memory Compression"; Desc="Deaktiviert RAM-Komprimierung. Sinnvoll bei 16GB+ RAM. Reduziert CPU-Last."; Category="RAM and Storage"; Group="Memory"; Action={
        Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
        Write-Log "Memory Compression disabled" }},
    [PSCustomObject]@{ Name="Enable SSD TRIM"; Desc="Stellt sicher dass TRIM fuer alle SSDs aktiv ist. Haelt SSDs langfristig schnell."; Category="RAM and Storage"; Group="Storage"; Action={
        fsutil behavior set DisableDeleteNotify 0 | Out-Null
        Write-Log "SSD TRIM enabled" }},
    [PSCustomObject]@{ Name="Disable SSD Defragmentation"; Desc="Deaktiviert automatische Defragmentierung fuer SSDs. SSDs brauchen keine Defrag - verkuerzt Lebensdauer."; Category="RAM and Storage"; Group="Storage"; Action={
        schtasks /Change /TN "\Microsoft\Windows\Defrag\ScheduledDefrag" /Disable 2>$null | Out-Null
        Write-Log "SSD Defrag scheduled task disabled" }},
    [PSCustomObject]@{ Name="Disable Hibernation"; Desc="Deaktiviert Ruhezustand und loescht hiberfil.sys. Gibt Speicherplatz frei (gleich RAM-Groesse)."; Category="RAM and Storage"; Group="Storage"; Action={
        powercfg -h off | Out-Null
        Write-Log "Hibernation disabled" }},
    [PSCustomObject]@{ Name="Clean Temp Files"; Desc="Loescht temporaere Dateien aus TEMP und Windows Temp. Gibt Speicherplatz frei ohne Risiko."; Category="RAM and Storage"; Group="Storage"; Action={
        Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:SystemRoot\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log "Temp files cleaned" }},
    [PSCustomObject]@{ Name="Optimize NVMe Queue Depth"; Desc="Erhoeht NVMe Queue-Tiefe fuer besseren Durchsatz. Relevant fuer M.2 NVMe SSDs."; Category="RAM and Storage"; Group="Storage"; Action={
        reg add "HKLM\SYSTEM\CurrentControlSet\Services\storahci\Parameters\Device" /v TreatAsInternalPort /t REG_MULTI_SZ /d "0\01\02\03\04\05" /f | Out-Null
        Write-Log "NVMe Queue Depth optimized" }},
    [PSCustomObject]@{ Name="Disable Write Cache Buffer Flushing"; Desc="Schnellere Schreiboperationen. Nur empfohlen bei unterbrechungsfreier Stromversorgung (USV)."; Category="RAM and Storage"; Group="Storage"; Action={
        reg add "HKLM\SYSTEM\CurrentControlSet\Services\disk" /v UserWriteCacheSetting /t REG_DWORD /d 1 /f | Out-Null
        Write-Log "Write-Cache Buffer Flushing disabled" }}
)

# WPF XAML GUI
[xml]$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="WinTweaker v1.0 - by FloDePin"
        Height="700" Width="900"
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
                            <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#e94560"/></Trigger>
                            <Trigger Property="IsPressed" Value="True"><Setter Property="Background" Value="#c73652"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="Button" x:Key="InfoBtn">
            <Setter Property="Width" Value="22"/>
            <Setter Property="Height" Value="22"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="VerticalAlignment" Value="Center"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="IB" Background="#16213e" CornerRadius="11" BorderBrush="#444444" BorderThickness="1">
                            <TextBlock x:Name="IT" Text="?" HorizontalAlignment="Center" VerticalAlignment="Center" FontSize="11" Foreground="#aaaaaa"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="IB" Property="Background" Value="#e94560"/>
                                <Setter TargetName="IB" Property="BorderBrush" Value="#e94560"/>
                                <Setter TargetName="IT" Property="Foreground"  Value="White"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="IB" Property="Background" Value="#c73652"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="TabItem">
            <Setter Property="Background" Value="#16213e"/>
            <Setter Property="Foreground" Value="#aaaaaa"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="14,8"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TabItem">
                        <Border x:Name="TB" Background="{TemplateBinding Background}" CornerRadius="6,6,0,0" Margin="2,0" Padding="{TemplateBinding Padding}">
                            <ContentPresenter x:Name="CS" VerticalAlignment="Center" HorizontalAlignment="Center" ContentSource="Header" RecognizesAccessKey="True"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="TB" Property="Background" Value="#e94560"/>
                                <Setter Property="Foreground" Value="White"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="TB" Property="Background" Value="#0f3460"/>
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
            <TextBlock Text="WinTweaker" FontSize="26" FontWeight="Bold" Foreground="#e94560"/>
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
            <TabItem Header="[RAM]  RAM &amp; Storage">
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
            <TextBlock Name="StatusText" Text="Ready - select tweaks and click Apply Selected." Foreground="#aaaaaa" FontSize="12" FontFamily="Consolas"/>
        </Border>
    </Grid>
</Window>
"@

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

$CheckBoxMap = @{}

function New-GroupHeader ([string]$Title) {
    $tb = New-Object Windows.Controls.TextBlock
    $tb.Text       = $Title
    $tb.FontSize   = 12
    $tb.FontWeight = "SemiBold"
    $tb.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(0,212,170))
    $tb.Margin     = New-Object Windows.Thickness(0,14,0,4)
    return $tb
}

function New-TweakRow ($Tweak) {
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
    $btn       = New-Object Windows.Controls.Button
    $btn.Style = $Window.Resources["InfoBtn"]
    $desc = $Tweak.Desc
    $name = $Tweak.Name
    $btn.Add_Click({
        [System.Windows.MessageBox]::Show($desc, "Info: $name", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }.GetNewClosure())
    $panel.Children.Add($cb)  | Out-Null
    $panel.Children.Add($btn) | Out-Null
    return $panel
}

$panelMap = @{ "Windows"=""; "Gaming"=""; "Network"=""; "RAM and Storage"="" }
$panelMap["Windows"]         = $WindowsPanel
$panelMap["Gaming"]          = $GamingPanel
$panelMap["Network"]         = $NetworkPanel
$panelMap["RAM and Storage"] = $RamPanel

foreach ($cat in @("Windows","Gaming","Network","RAM and Storage")) {
    $panel  = $panelMap[$cat]
    $groups = $AllTweaks | Where-Object { $_.Category -eq $cat } | Select-Object -ExpandProperty Group -Unique
    foreach ($group in $groups) {
        $panel.Children.Add((New-GroupHeader "-- $group")) | Out-Null
        $AllTweaks | Where-Object { $_.Category -eq $cat -and $_.Group -eq $group } | ForEach-Object {
            $panel.Children.Add((New-TweakRow $_)) | Out-Null
        }
    }
}

$BtnSelectAll.Add_Click({ foreach ($cb in $CheckBoxMap.Values) { $cb.IsChecked = $true } })
$BtnDeselect.Add_Click({  foreach ($cb in $CheckBoxMap.Values) { $cb.IsChecked = $false } })
$BtnOpenLog.Add_Click({
    if (Test-Path $LogFile) { Start-Process notepad.exe $LogFile }
    else { [System.Windows.MessageBox]::Show("No log yet. Apply tweaks first.", "Log", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) }
})
$BtnApply.Add_Click({
    $selected = $AllTweaks | Where-Object { $CheckBoxMap[$_.Name].IsChecked -eq $true }
    if ($selected.Count -eq 0) {
        [System.Windows.MessageBox]::Show("No tweaks selected!", "WinTweaker", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }
    $confirm = [System.Windows.MessageBox]::Show("Apply $($selected.Count) tweak(s)?`n`nA system restore point will be created first.", "WinTweaker - Confirm", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }
    $StatusText.Text = "Creating restore point..."
    $Window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Render)
    try { Checkpoint-Computer -Description "WinTweaker Backup" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop; Write-Log "Restore point created" }
    catch { Write-Log "Restore point failed: $_" }
    $done = 0; $total = $selected.Count
    foreach ($tweak in $selected) {
        $StatusText.Text = "Applying: $($tweak.Name) ($done/$total)..."
        $Window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Render)
        try { & $tweak.Action; Write-Log "OK: $($tweak.Name)" }
        catch { Write-Log "FAILED: $($tweak.Name) -- $_" }
        $done++
    }
    $StatusText.Text = "Done! $done tweak(s) applied. Log: $LogFile"
    [System.Windows.MessageBox]::Show("$done tweak(s) applied!`n`nSome changes require a restart.`nLog: $LogFile", "WinTweaker - Done", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
})

Write-Log "WinTweaker v3.0 started | $HWInfo"
$Window.ShowDialog() | Out-Null
