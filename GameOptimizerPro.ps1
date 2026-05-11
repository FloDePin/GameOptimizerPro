
# ─────────────────────────────────────────
# TWEAK DEFINITIONS
# ─────────────────────────────────────────
$AllTweaks = @(

    # ── WINDOWS / BLOATWARE ─────────────────────────────────────────
    [PSCustomObject]@{
        Name="Remove Cortana"; Category="Windows"; Group="Bloatware"
        Desc="Deinstalliert Cortana vollstaendig."
        Action={ Get-AppxPackage -AllUsers "*Microsoft.549981C3F5F10*" | Remove-AppxPackage -EA SilentlyContinue; Write-Log "Cortana removed" }
    },
    [PSCustomObject]@{
        Name="Remove Xbox Apps"; Category="Windows"; Group="Bloatware"
        Desc="Entfernt Xbox Game Bar, Xbox Identity Provider und Xbox TCUI."
        Action={
            @("*XboxApp*","*XboxGameOverlay*","*XboxGamingOverlay*","*XboxIdentityProvider*","*XboxSpeechToTextOverlay*","*XboxTCUI*") |
            ForEach-Object { Get-AppxPackage -AllUsers $_ | Remove-AppxPackage -EA SilentlyContinue }
            Write-Log "Xbox Apps removed"
        }
    },
    [PSCustomObject]@{
        Name="Remove Microsoft Teams (Personal)"; Category="Windows"; Group="Bloatware"
        Desc="Entfernt die Consumer-Version von Microsoft Teams. Blockiert automatische Neuinstallation."
        Action={
            Get-AppxPackage -AllUsers "*MicrosoftTeams*" | Remove-AppxPackage -EA SilentlyContinue
            reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Communications" /v ConfigureChatAutoInstall /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Teams Personal removed"
        }
    },
    [PSCustomObject]@{
        Name="Remove Copilot"; Category="Windows"; Group="Bloatware"
        Desc="Deaktiviert und entfernt Windows Copilot."
        Action={
            reg add "HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f | Out-Null
            Get-AppxPackage -AllUsers "*Copilot*" | Remove-AppxPackage -EA SilentlyContinue
            Write-Log "Copilot disabled"
        }
    },
    [PSCustomObject]@{
        Name="Remove OneDrive"; Category="Windows"; Group="Bloatware"
        Desc="Deinstalliert OneDrive inkl. Autostart und Explorer-Integration."
        Action={
            Stop-Process -Name "OneDrive" -Force -EA SilentlyContinue; Start-Sleep 1
            $od="$env:SYSTEMROOT\SysWOW64\OneDriveSetup.exe"
            if(!(Test-Path $od)){$od="$env:SYSTEMROOT\System32\OneDriveSetup.exe"}
            if(Test-Path $od){& $od /uninstall}
            reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v OneDrive /f 2>$null
            Write-Log "OneDrive removed"
        }
    },
    [PSCustomObject]@{
        Name="Remove Windows Recall"; Category="Windows"; Group="Bloatware"
        Desc="Deaktiviert Windows Recall (KI-Screenshot-Feature). Datenschutzkritisch."
        Action={
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v DisableAIDataAnalysis /t REG_DWORD /d 1 /f | Out-Null
            Disable-WindowsOptionalFeature -Online -FeatureName "Recall" -NoRestart -EA SilentlyContinue | Out-Null
            Write-Log "Recall disabled"
        }
    },
    [PSCustomObject]@{
        Name="Remove Other Bloatware"; Category="Windows"; Group="Bloatware"
        Desc="Entfernt vorinstallierte Apps: Candy Crush, TikTok, Disney+, Spotify, Clipchamp, Paint3D u.v.m."
        Action={
            @("*king.com*","*Facebook*","*Spotify*","*Disney*","*TikTok*","*Instagram*","*Netflix*","*Twitter*",
              "*BubbleWitch*","*CandyCrush*","*Microsoft.News*","*Microsoft.BingWeather*","*Microsoft.BingNews*",
              "*Microsoft.MicrosoftSolitaireCollection*","*Microsoft.ZuneMusic*","*Microsoft.ZuneVideo*",
              "*Microsoft.WindowsFeedbackHub*","*Microsoft.Todos*","*Microsoft.Paint3D*","*Clipchamp*",
              "*Microsoft.GetHelp*","*Microsoft.Getstarted*","*Microsoft.PowerAutomateDesktop*") |
            ForEach-Object { Get-AppxPackage -AllUsers $_ | Remove-AppxPackage -EA SilentlyContinue }
            Write-Log "Bloatware removed"
        }
    },

    # ── WINDOWS / PRIVACY ───────────────────────────────────────────
    [PSCustomObject]@{
        Name="Disable Telemetry & Data Collection"; Category="Windows"; Group="Privacy"
        Desc="Deaktiviert alle Windows-Telemetriedienste (DiagTrack, dmwappushservice)."
        Action={
            Stop-Service DiagTrack -Force -EA SilentlyContinue; Set-Service DiagTrack -StartupType Disabled -EA SilentlyContinue
            Stop-Service dmwappushservice -Force -EA SilentlyContinue; Set-Service dmwappushservice -StartupType Disabled -EA SilentlyContinue
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Telemetry disabled"
        }
    },
    [PSCustomObject]@{
        Name="Disable Activity History"; Category="Windows"; Group="Privacy"
        Desc="Deaktiviert den Windows Aktivitaetsverlauf (Timeline)."
        Action={
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v EnableActivityFeed /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v PublishUserActivities /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Activity History disabled"
        }
    },
    [PSCustomObject]@{
        Name="Disable Advertising ID"; Category="Windows"; Group="Privacy"
        Desc="Deaktiviert die Werbe-ID. Apps koennen dich nicht mehr tracken."
        Action={
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" /v DisabledByGroupPolicy /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "Advertising ID disabled"
        }
    },
    [PSCustomObject]@{
        Name="Disable Location Tracking"; Category="Windows"; Group="Privacy"
        Desc="Deaktiviert den Windows Standortdienst systemweit."
        Action={
            reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v Value /t REG_SZ /d Deny /f | Out-Null
            Set-Service lfsvc -StartupType Disabled -EA SilentlyContinue
            Write-Log "Location tracking disabled"
        }
    },
    [PSCustomObject]@{
        Name="Block Telemetry Hosts (hosts file)"; Category="Windows"; Group="Privacy"
        Desc="Blockt Microsoft Telemetrie-Server in der hosts-Datei."
        Action={
            $entries=@("0.0.0.0 telemetry.microsoft.com","0.0.0.0 vortex.data.microsoft.com",
                       "0.0.0.0 vortex-win.data.microsoft.com","0.0.0.0 telecommand.telemetry.microsoft.com",
                       "0.0.0.0 oca.telemetry.microsoft.com","0.0.0.0 sqm.telemetry.microsoft.com",
                       "0.0.0.0 watson.telemetry.microsoft.com","0.0.0.0 df.telemetry.microsoft.com")
            $hf="$env:SystemRoot\System32\drivers\etc\hosts"; $ex=Get-Content $hf
            foreach($e in $entries){if($ex -notcontains $e){Add-Content $hf $e}}
            Write-Log "Telemetry hosts blocked"
        }
    },
    [PSCustomObject]@{
        Name="Disable Scheduled Telemetry Tasks"; Category="Windows"; Group="Privacy"
        Desc="Deaktiviert geplante Aufgaben die Telemetriedaten sammeln."
        Action={
            @("\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
              "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
              "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
              "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
              "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector") |
            ForEach-Object { schtasks /Change /TN $_ /Disable 2>$null }
            Write-Log "Telemetry tasks disabled"
        }
    },

    # ── WINDOWS / PERFORMANCE ────────────────────────────────────────
    [PSCustomObject]@{
        Name="Ultimate Performance Plan"; Category="Windows"; Group="Performance"
        Desc="Aktiviert den 'Ultimative Leistung' Energiesparplan. Windows drosselt keine CPU-Kerne mehr."
        Action={
            powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
            $m=powercfg -list|Select-String '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})'|Where-Object{$_ -match "Ultimative Leistung|Ultimate Performance"}|Select-Object -First 1
            if($m -and $m.Matches.Count -gt 0){powercfg -setactive $m.Matches[0].Value;Write-Log "Ultimate Performance activated"}
        }
    },
    [PSCustomObject]@{
        Name="Disable HPET"; Category="Windows"; Group="Performance"
        Desc="Deaktiviert den High Precision Event Timer. Kann System-Latenz reduzieren."
        Action={
            bcdedit /deletevalue useplatformclock 2>$null|Out-Null
            bcdedit /set useplatformtick yes|Out-Null
            bcdedit /set disabledynamictick yes|Out-Null
            Write-Log "HPET disabled"
        }
    },
    [PSCustomObject]@{
        Name="Set 0.5ms Timer Resolution"; Category="Windows"; Group="Performance"
        Desc="Setzt die Windows Timer-Aufloesung auf 0.5ms (Standard: 15.6ms). Reduziert Input-Lag."
        Action={
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v GlobalTimerResolutionRequests /t REG_DWORD /d 1 /f|Out-Null
            Write-Log "Timer resolution 0.5ms set"
        }
    },
    [PSCustomObject]@{
        Name="Disable Prefetch & Superfetch"; Category="Windows"; Group="Performance"
        Desc="Deaktiviert Prefetch und SysMain. Sinnvoll bei SSDs."
        Action={
            Stop-Service SysMain -Force -EA SilentlyContinue; Set-Service SysMain -StartupType Disabled -EA SilentlyContinue
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnablePrefetcher /t REG_DWORD /d 0 /f|Out-Null
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnableSuperfetch /t REG_DWORD /d 0 /f|Out-Null
            Write-Log "Prefetch/Superfetch disabled"
        }
    },
    [PSCustomObject]@{
        Name="Optimize Visual Effects (Performance Mode)"; Category="Windows"; Group="Performance"
        Desc="Schaltet alle Windows-Animationen und visuelle Effekte aus."
        Action={
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 2 /f|Out-Null
            Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name TaskbarAnimations -Value 0
            reg add "HKCU\Control Panel\Desktop\WindowMetrics" /v MinAnimate /t REG_SZ /d 0 /f|Out-Null
            Write-Log "Visual effects: performance mode"
        }
    },
    [PSCustomObject]@{
        Name="Disable Windows Search Indexing"; Category="Windows"; Group="Performance"
        Desc="Deaktiviert den Windows Search Indexer. Reduziert Hintergrund-Festplattenzugriffe."
        Action={
            Stop-Service WSearch -Force -EA SilentlyContinue; Set-Service WSearch -StartupType Disabled -EA SilentlyContinue
            Write-Log "Search Indexing disabled"
        }
    },

    # ── WINDOWS / MOUSE & UI ────────────────────────────────────────
    [PSCustomObject]@{
        Name="Disable Mouse Acceleration"; Category="Windows"; Group="Mouse & UI"
        Desc="Deaktiviert Mausbeschleunigung. Wichtig fuer FPS-Spiele: 1:1 Maustransfer."
        Action={
            reg add "HKCU\Control Panel\Mouse" /v MouseSpeed /t REG_SZ /d 0 /f|Out-Null
            reg add "HKCU\Control Panel\Mouse" /v MouseThreshold1 /t REG_SZ /d 0 /f|Out-Null
            reg add "HKCU\Control Panel\Mouse" /v MouseThreshold2 /t REG_SZ /d 0 /f|Out-Null
            Write-Log "Mouse acceleration disabled"
        }
    },
    [PSCustomObject]@{
        Name="Disable Sticky Keys"; Category="Windows"; Group="Mouse & UI"
        Desc="Deaktiviert den Sticky Keys Dialog beim 5x Shift-Druecken."
        Action={
            reg add "HKCU\Control Panel\Accessibility\StickyKeys" /v Flags /t REG_SZ /d 506 /f|Out-Null
            reg add "HKCU\Control Panel\Accessibility\Keyboard Response" /v Flags /t REG_SZ /d 122 /f|Out-Null
            reg add "HKCU\Control Panel\Accessibility\ToggleKeys" /v Flags /t REG_SZ /d 58 /f|Out-Null
            Write-Log "Sticky Keys disabled"
        }
    },
    [PSCustomObject]@{
        Name="Enable Dark Mode"; Category="Windows"; Group="Mouse & UI"
        Desc="Aktiviert den dunklen Modus fuer Windows und Apps systemweit."
        Action={
            reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v AppsUseLightTheme /t REG_DWORD /d 0 /f|Out-Null
            reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v SystemUsesLightTheme /t REG_DWORD /d 0 /f|Out-Null
            Write-Log "Dark Mode enabled"
        }
    },
    [PSCustomObject]@{
        Name="Disable Transparency Effects"; Category="Windows"; Group="Mouse & UI"
        Desc="Deaktiviert Transparenz-Effekte in Taskleiste und Startmenue. Spart GPU-Ressourcen."
        Action={
            reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 0 /f|Out-Null
            Write-Log "Transparency disabled"
        }
    },

    # ── GAMING / IN-GAME BOOSTS ─────────────────────────────────────
    [PSCustomObject]@{
        Name="Enable Game Mode"; Category="Gaming"; Group="In-Game Boosts"
        Desc="Aktiviert Windows Game Mode. CPU/GPU-Ressourcen werden fuer das aktive Spiel priorisiert."
        Action={
            reg add "HKCU\Software\Microsoft\GameBar" /v AllowAutoGameMode /t REG_DWORD /d 1 /f|Out-Null
            reg add "HKCU\Software\Microsoft\GameBar" /v AutoGameModeEnabled /t REG_DWORD /d 1 /f|Out-Null
            Write-Log "Game Mode enabled"
        }
    },
    [PSCustomObject]@{
        Name="Disable Xbox Game Bar"; Category="Gaming"; Group="In-Game Boosts"
        Desc="Deaktiviert die Xbox Game Bar (Win+G). Verhindert Ressourcenverbrauch im Hintergrund."
        Action={
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 0 /f|Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v AllowGameDVR /t REG_DWORD /d 0 /f|Out-Null
            Write-Log "Xbox Game Bar disabled"
        }
    },
    [PSCustomObject]@{
        Name="CPU Priority for Games (Win32Priority)"; Category="Gaming"; Group="In-Game Boosts"
        Desc="Setzt Win32PrioritySeparation auf 26. Windows gibt aktiven Spielen mehr CPU-Zeit."
        Action={
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v Win32PrioritySeparation /t REG_DWORD /d 26 /f|Out-Null
            Write-Log "CPU Priority for gaming set"
        }
    },
    [PSCustomObject]@{
        Name="MMCSS Gaming Profile (High Priority)"; Category="Gaming"; Group="In-Game Boosts"
        Desc="Setzt MMCSS-Profile fuer Spiele auf High Priority. Verbessert Audio und Timer-Interrupts."
        Action={
            $p="HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
            reg add $p /v "GPU Priority" /t REG_DWORD /d 8 /f|Out-Null
            reg add $p /v "Priority" /t REG_DWORD /d 6 /f|Out-Null
            reg add $p /v "Scheduling Category" /t REG_SZ /d High /f|Out-Null
            Write-Log "MMCSS Gaming profile set"
        }
    },
    [PSCustomObject]@{
        Name="Disable Fullscreen Optimizations"; Category="Gaming"; Group="In-Game Boosts"
        Desc="Erzwingt echtes Fullscreen global. Niedrigerer Input-Lag."
        Action={
            reg add "HKCU\System\GameConfigStore" /v GameDVR_FSEBehaviorMode /t REG_DWORD /d 2 /f|Out-Null
            reg add "HKCU\System\GameConfigStore" /v GameDVR_HonorUserFSEBehaviorMode /t REG_DWORD /d 1 /f|Out-Null
            reg add "HKCU\System\GameConfigStore" /v GameDVR_FSEBehavior /t REG_DWORD /d 2 /f|Out-Null
            Write-Log "Fullscreen Optimizations disabled"
        }
    },
    [PSCustomObject]@{
        Name="Disable Windows Update during Gaming"; Category="Gaming"; Group="In-Game Boosts"
        Desc="Verhindert dass Windows Update waehrend Gaming stoert oder Neustart erzwingt."
        Action={
            reg add "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v ActiveHoursStart /t REG_DWORD /d 8 /f|Out-Null
            reg add "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v ActiveHoursEnd /t REG_DWORD /d 3 /f|Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoRebootWithLoggedOnUsers /t REG_DWORD /d 1 /f|Out-Null
            Write-Log "WU suppressed during gaming"
        }
    },
    [PSCustomObject]@{
        Name="Disable Background App Throttling"; Category="Gaming"; Group="In-Game Boosts"
        Desc="Deaktiviert automatisches Drosseln von Hintergrund-Apps (z.B. Discord) waehrend des Spielens."
        Action={
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled /t REG_DWORD /d 0 /f|Out-Null
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v DisableDynamicTick /t REG_DWORD /d 1 /f|Out-Null
            Write-Log "Background App Throttling disabled"
        }
    },
    [PSCustomObject]@{
        Name="Enable DirectX 12 Optimization"; Category="Gaming"; Group="In-Game Boosts"
        Desc="Aktiviert DX12 Command Buffer Reuse und Allow Tearing. Verbessert Frame-Pacing."
        Action={
            reg add "HKLM\SOFTWARE\Microsoft\DirectX" /v D3D12_ENABLE_UNSAFE_COMMAND_BUFFER_REUSE /t REG_DWORD /d 1 /f|Out-Null
            reg add "HKLM\SOFTWARE\Microsoft\DirectX" /v D3D12_ALLOW_TEARING /t REG_DWORD /d 1 /f|Out-Null
            Write-Log "DX12 Optimization enabled"
        }
    },

    # ── GAMING / GPU & DRIVER ───────────────────────────────────────
    [PSCustomObject]@{
        Name="NVIDIA Low Latency Mode (Reflex)"; Category="Gaming"; Group="GPU & Driver"
        Desc="Aktiviert NVIDIA Ultra Low Latency Mode. Render-Queue auf 1 Frame. Nur fuer NVIDIA GPUs."
        Action={
            if($IsNVIDIA){
                reg add "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak" /v NVLatency /t REG_DWORD /d 1 /f|Out-Null
                Write-Log "NVIDIA Low Latency enabled"
            } else { Write-Log "NVIDIA Low Latency skipped (GPU: $GPU)" }
        }
    },
    [PSCustomObject]@{
        Name="Enable MSI Mode (Message Signaled Interrupts)"; Category="Gaming"; Group="GPU & Driver"
        Desc="Aktiviert MSI-Modus fuer GPU. Reduziert Interrupt-Latenz. Reboot empfohlen."
        Action={
            $g=Get-WmiObject Win32_VideoController|Where-Object{$_.Name -notmatch "Microsoft"}|Select-Object -First 1
            if($g){
                reg add "HKLM\SYSTEM\CurrentControlSet\Enum\$($g.PNPDeviceID)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties" /v MSISupported /t REG_DWORD /d 1 /f|Out-Null
                Write-Log "MSI Mode enabled: $($g.Name)"
            }
        }
    },
    [PSCustomObject]@{
        Name="Enable Hardware-Accelerated GPU Scheduling (HAGS)"; Category="Gaming"; Group="GPU & Driver"
        Desc="Aktiviert HAGS. Erfordert RTX 2000+ / RX 5000+."
        Action={
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v HwSchMode /t REG_DWORD /d 2 /f|Out-Null
            Write-Log "HAGS enabled"
        }
    },
    [PSCustomObject]@{
        Name="Clear Shader Cache"; Category="Gaming"; Group="GPU & Driver"
        Desc="Leert NVIDIA/AMD/DX Shader-Cache. Sinnvoll nach Treiberupdates."
        Action={
            if($IsNVIDIA){
                @("$env:LOCALAPPDATA\NVIDIA\DXCache","$env:LOCALAPPDATA\NVIDIA\GLCache")|
                ForEach-Object{if(Test-Path $_){Remove-Item "$_\*" -Recurse -Force -EA SilentlyContinue}}
            }
            if($IsAMD){
                $ac="$env:TEMP\AMD"; if(Test-Path $ac){Remove-Item "$ac\*" -Recurse -Force -EA SilentlyContinue}
            }
            $dx="$env:LOCALAPPDATA\D3DSCache"; if(Test-Path $dx){Remove-Item "$dx\*" -Recurse -Force -EA SilentlyContinue}
            Write-Log "Shader Cache cleared"
        }
    },

    # ── NETWORK ─────────────────────────────────────────────────────
    [PSCustomObject]@{
        Name="Disable Nagle's Algorithm (TCPNoDelay)"; Category="Network"; Group="Latency"
        Desc="Deaktiviert Nagles Algorithmus. Senkt Ping in Online-Spielen spuerbar."
        Action={
            Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\*" |
            ForEach-Object {
                Set-ItemProperty -Path $_.PSPath -Name TcpAckFrequency -Value 1 -Type DWord -EA SilentlyContinue
                Set-ItemProperty -Path $_.PSPath -Name TCPNoDelay -Value 1 -Type DWord -EA SilentlyContinue
            }
            Write-Log "Nagle's Algorithm disabled"
        }
    },
    [PSCustomObject]@{
        Name="Disable Large Send Offload (LSO)"; Category="Network"; Group="Latency"
        Desc="Deaktiviert LSO auf allen Adaptern. Reduziert Ping-Spikes."
        Action={
            Get-NetAdapter|Where-Object{$_.Status -eq "Up"}|ForEach-Object{Disable-NetAdapterLso -Name $_.Name -EA SilentlyContinue}
            Write-Log "LSO disabled"
        }
    },
    [PSCustomObject]@{
        Name="Disable Network Throttling Index"; Category="Network"; Group="Latency"
        Desc="Setzt NetworkThrottlingIndex auf FFFFFFFF. Windows drosselt keinen Netzwerk-Traffic mehr."
        Action={
            reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v NetworkThrottlingIndex /t REG_DWORD /d 0xFFFFFFFF /f|Out-Null
            Write-Log "Network Throttling Index disabled"
        }
    },
    [PSCustomObject]@{
        Name="Set DNS to Cloudflare (1.1.1.1)"; Category="Network"; Group="DNS"
        Desc="Setzt DNS auf Cloudflare 1.1.1.1 / 1.0.0.1. Schnell und datenschutzfreundlich."
        Action={
            Get-NetAdapter|Where-Object{$_.Status -eq "Up"}|ForEach-Object{
                Set-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -ServerAddresses ("1.1.1.1","1.0.0.1") -EA SilentlyContinue
            }
            Write-Log "DNS: Cloudflare 1.1.1.1"
        }
    },
    [PSCustomObject]@{
        Name="Set DNS to Google (8.8.8.8)"; Category="Network"; Group="DNS"
        Desc="Setzt DNS auf Google 8.8.8.8 / 8.8.4.4."
        Action={
            Get-NetAdapter|Where-Object{$_.Status -eq "Up"}|ForEach-Object{
                Set-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -ServerAddresses ("8.8.8.8","8.8.4.4") -EA SilentlyContinue
            }
            Write-Log "DNS: Google 8.8.8.8"
        }
    },
    [PSCustomObject]@{
        Name="Flush DNS Cache"; Category="Network"; Group="DNS"
        Desc="Leert den lokalen DNS-Cache."
        Action={ ipconfig /flushdns|Out-Null; Write-Log "DNS Cache flushed" }
    },
    [PSCustomObject]@{
        Name="Disable TCP Auto-Tuning"; Category="Network"; Group="TCP"
        Desc="Deaktiviert automatische TCP-Fenstergroesse. Kann Latenz-Spikes reduzieren."
        Action={ netsh int tcp set global autotuninglevel=disabled|Out-Null; Write-Log "TCP Auto-Tuning disabled" }
    },
    [PSCustomObject]@{
        Name="Optimize TCP Settings (ECN/SACK)"; Category="Network"; Group="TCP"
        Desc="Deaktiviert ECN und Timestamps, aktiviert RSS."
        Action={
            netsh int tcp set global ecncapability=disabled|Out-Null
            netsh int tcp set global timestamps=disabled|Out-Null
            netsh int tcp set global rss=enabled|Out-Null
            Write-Log "TCP ECN/Timestamps disabled, RSS enabled"
        }
    },
    [PSCustomObject]@{
        Name="Disable QoS Packet Scheduler Limit"; Category="Network"; Group="QoS"
        Desc="Entfernt das 20%-Bandbreitenlimit das Windows fuer QoS reserviert."
        Action={
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched" /v NonBestEffortLimit /t REG_DWORD /d 0 /f|Out-Null
            Write-Log "QoS limit removed"
        }
    },

    # ── RAM & STORAGE ────────────────────────────────────────────────
    [PSCustomObject]@{
        Name="Optimize PageFile (System Managed)"; Category="RAM & Storage"; Group="Memory"
        Desc="Setzt PageFile auf 'Vom System verwaltet'."
        Action={
            $cs=Get-WmiObject Win32_ComputerSystem; $cs.AutomaticManagedPagefile=$true; $cs.Put()|Out-Null
            Write-Log "PageFile: system managed"
        }
    },
    [PSCustomObject]@{
        Name="Clear PageFile on Shutdown"; Category="RAM & Storage"; Group="Memory"
        Desc="Loescht die Auslagerungsdatei beim Herunterfahren."
        Action={
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v ClearPageFileAtShutdown /t REG_DWORD /d 1 /f|Out-Null
            Write-Log "PageFile cleared on shutdown"
        }
    },
    [PSCustomObject]@{
        Name="Disable Memory Compression"; Category="RAM & Storage"; Group="Memory"
        Desc="Deaktiviert Windows Memory Compression. Bei 16 GB+ RAM sinnvoll."
        Action={ Disable-MMAgent -MemoryCompression -EA SilentlyContinue; Write-Log "Memory Compression disabled" }
    },
    [PSCustomObject]@{
        Name="Enable SSD TRIM"; Category="RAM & Storage"; Group="Storage"
        Desc="Stellt sicher dass TRIM fuer SSDs aktiv ist."
        Action={ fsutil behavior set DisableDeleteNotify 0|Out-Null; Write-Log "SSD TRIM enabled" }
    },
    [PSCustomObject]@{
        Name="Disable Scheduled Defragmentation"; Category="RAM & Storage"; Group="Storage"
        Desc="Deaktiviert automatische Defragmentierung. Auf SSDs schaedlich."
        Action={ schtasks /Change /TN "\Microsoft\Windows\Defrag\ScheduledDefrag" /Disable 2>$null|Out-Null; Write-Log "Defrag disabled" }
    },
    [PSCustomObject]@{
        Name="Disable Hibernation"; Category="RAM & Storage"; Group="Storage"
        Desc="Deaktiviert Ruhezustand und loescht hiberfil.sys. Spart Speicherplatz."
        Action={ powercfg -h off|Out-Null; Write-Log "Hibernation disabled" }
    },
    [PSCustomObject]@{
        Name="Clean Temp Files"; Category="RAM & Storage"; Group="Storage"
        Desc="Loescht alle Dateien in %TEMP% und Windows Temp."
        Action={
            Remove-Item "$env:TEMP\*" -Recurse -Force -EA SilentlyContinue
            Remove-Item "$env:SystemRoot\Temp\*" -Recurse -Force -EA SilentlyContinue
            Write-Log "Temp files cleaned"
        }
    },
    [PSCustomObject]@{
        Name="Optimize NVMe Queue Depth"; Category="RAM & Storage"; Group="Storage"
        Desc="Optimiert die Queue Depth fuer NVMe-Laufwerke."
        Action={
            reg add "HKLM\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device" /v "ForcedPhysicalSectorSizeInBytes" /t REG_MULTI_SZ /d "* 4095" /f|Out-Null
            Write-Log "NVMe Queue Depth optimized"
        }
    },
    [PSCustomObject]@{
        Name="Disable Write-Cache Buffer Flushing"; Category="RAM & Storage"; Group="Storage"
        Desc="Deaktiviert erzwungenes Leeren des Schreib-Cache-Puffers. Nur mit USV empfohlen."
        Action={
            Get-WmiObject Win32_DiskDrive|ForEach-Object{
                reg add "HKLM\SYSTEM\CurrentControlSet\Enum\$($_.PNPDeviceID)\Device Parameters\Disk" /v UserWriteCacheSetting /t REG_DWORD /d 1 /f 2>$null|Out-Null
            }
            Write-Log "Write-Cache Buffer Flushing disabled"
        }
    }
)
