<#
.SYNOPSIS
    GameOptimizerPro - Windows & Gaming Optimizer
.DESCRIPTION
    GUI-based PowerShell optimizer with checkboxes and info tooltips.
    Tabs: Windows | Gaming | Network | RAM & Storage |
          Windows 11 | Audio | GPU Tweaks | Power Plan
    Features: Startup Manager, Revert All, DE/EN Language Toggle
.AUTHOR
    FloDePin
.VERSION
    1.2.6
#>

$ErrorActionPreference = "Continue"

# -----------------------------------------
# APP VERSION -- single source of truth. The window title, subtitle and
# startup/close log lines all derive from this, so a version bump only needs
# to change this ONE value (keep it in sync with the .VERSION block above).
# -----------------------------------------
$Script:AppVersion = "1.2.6"

# --- STARTUP LOG (mehrere Orte) ---
$logPaths = @(
    "$env:TEMP\GameOptimizerPro_Startup.txt"
)
$startupLog = $logPaths[0]
$logMsg = "[$(Get-Date -f 'HH:mm:ss')] Script gestartet - PS $($PSVersionTable.PSVersion) - User: $env:USERNAME - IsAdmin: $((([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)))"
foreach ($p in $logPaths) {
    try { $logMsg | Out-File $p -Force -ErrorAction SilentlyContinue } catch { }
}
Write-Host $logMsg -ForegroundColor Cyan

try {

Add-Type -AssemblyName PresentationFramework  -ErrorAction SilentlyContinue
Add-Type -AssemblyName PresentationCore       -ErrorAction SilentlyContinue
Add-Type -AssemblyName WindowsBase            -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.Windows.Forms   -ErrorAction SilentlyContinue
foreach ($p in $logPaths) { try { "[$(Get-Date -f 'HH:mm:ss')] Assemblies geladen" | Out-File $p -Append -ErrorAction SilentlyContinue } catch { } }
Write-Host "[$(Get-Date -f 'HH:mm:ss')] Assemblies geladen" -ForegroundColor DarkGray

# -----------------------------------------
# CONSOLE WINDOW CONTROL (Win32 API)
# Note: On Windows 11 with Windows Terminal as default host, GetConsoleWindow()
# returns a hidden ConPTY window, so ShowWindow cannot control the visible
# terminal. The reliable cleanup is process-based: the installer exits its own
# session after launching, and this script ends its own process on GUI close.
# The early hide below still helps on classic conhost hosts.
# -----------------------------------------
if (-not ([System.Management.Automation.PSTypeName]'Native.Win32Console').Type) {
    Add-Type -Name Win32Console -Namespace Native -MemberDefinition @"
        [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
        [DllImport("user32.dll")]   public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
"@ -ErrorAction SilentlyContinue
}
$Script:ConsoleHwnd = [IntPtr]::Zero
try {
    $Script:ConsoleHwnd = [Native.Win32Console]::GetConsoleWindow()
    if ($Script:ConsoleHwnd -ne [IntPtr]::Zero) {
        [Native.Win32Console]::ShowWindow($Script:ConsoleHwnd, 0) | Out-Null  # SW_HIDE
    }
} catch { }

# -----------------------------------------
# ADMIN CHECK
# -----------------------------------------
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # Started directly (right-click > Run with PowerShell): ask for elevation once and
    # start again as administrator. The message only appears if that is declined, or if
    # the script was not started from a file (irm ... | iex has no path to restart).
    if ($PSCommandPath) {
        try {
            Start-Process powershell.exe -ArgumentList "-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs -WindowStyle Hidden -ErrorAction Stop
            exit
        } catch { }
    }
    [System.Windows.MessageBox]::Show("Please run this script as Administrator!", "GameOptimizerPro - Admin Required", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    exit
}
foreach ($p in $logPaths) { try { "[$(Get-Date -f 'HH:mm:ss')] Admin-Check OK" | Out-File $p -Append -ErrorAction SilentlyContinue } catch { } }
Write-Host "[$(Get-Date -f 'HH:mm:ss')] Admin-Check OK" -ForegroundColor DarkGray

# -----------------------------------------
# SPLASH -- visible within a moment of the launch while hardware detection and the
# status checks run (a few seconds). Closed once the main window has rendered.
# Purely cosmetic: if anything about it fails, startup simply continues without it.
# -----------------------------------------
$Script:Splash = $null
function Set-Splash([string]$Text, [int]$Pct) {
    if (-not $Script:Splash) { return }
    try {
        $Script:SplashText.Text = $Text; $Script:SplashBar.Value = $Pct
        $Script:Splash.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::Background)   # let it repaint
    } catch { }
}
function Close-Splash {
    if ($Script:Splash) { try { $Script:Splash.Close() } catch { }; $Script:Splash = $null }
}
try {
    [xml]$splashXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="GameOptimizerPro" Width="440" Height="152" WindowStyle="None" ResizeMode="NoResize" WindowStartupLocation="CenterScreen"
        Background="#0b0e13" BorderBrush="#242b36" BorderThickness="1" FontFamily="Segoe UI" TextOptions.TextFormattingMode="Display">
    <Grid Margin="26,22,26,22">
        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
        <DockPanel>
            <TextBlock DockPanel.Dock="Right" Text="v$($Script:AppVersion)" FontSize="12" Foreground="#7d8896" VerticalAlignment="Center"/>
            <TextBlock FontSize="20" FontWeight="SemiBold" Foreground="#e6edf3"><Run Text="GameOptimizer"/><Run Text="Pro" Foreground="#e53935"/></TextBlock>
        </DockPanel>
        <TextBlock Grid.Row="1" x:Name="SplashText" Text="Starting ..." FontSize="12.5" Foreground="#98a3b3" VerticalAlignment="Center"/>
        <ProgressBar Grid.Row="2" x:Name="SplashBar" Height="4" Minimum="0" Maximum="100" Value="3" Foreground="#e53935" Background="#1b212b" BorderThickness="0"/>
    </Grid>
</Window>
"@
    $Script:Splash     = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $splashXaml))
    $Script:SplashText = $Script:Splash.FindName("SplashText")
    $Script:SplashBar  = $Script:Splash.FindName("SplashBar")
    $Script:Splash.Show()
    Set-Splash "Detecting hardware ..." 5
} catch { $Script:Splash = $null }

# -----------------------------------------
# HARDWARE DETECTION
# -----------------------------------------
function Get-RegVal($Path, $Name) {
    # -LiteralPath: driver keys like Ndi\params\*EEE contain a '*' -- as a normal path that
    # is a wildcard, matches *EEE, AdvancedEEE, ... and returns a list instead of the value
    try { (Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop).$Name } catch { $null }
}

# The gaming GPU. On AM5 / Intel desktops the iGPU often stays enabled next to the
# graphics card (and laptops have both), and WMI lists the adapters in no fixed order:
# taking the first one could pick the iGPU -- wrong GPU tweaks, MSI mode on the wrong
# device, wrong VRAM. The adapter with the most dedicated VRAM wins, read from the
# driver key of each PRESENT adapter (a removed old card keeps its driver key).
function Select-PrimaryGpu($Ctrls) {
    $best = $null
    foreach ($vc in @($Ctrls | Where-Object { $_.Name -notmatch 'Microsoft' })) {
        $key = $null; $mem = 0L
        $drv = Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Enum\$($vc.PNPDeviceID)" 'Driver'
        if ($drv) {
            $key = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\$drv"
            $q = Get-RegVal $key 'HardwareInformation.qwMemorySize'
            if ($null -eq $q) { $q = Get-RegVal $key 'HardwareInformation.MemorySize' }   # older drivers
            if ($q -is [byte[]]) { $q = if ($q.Length -ge 8) { [BitConverter]::ToInt64($q, 0) } elseif ($q.Length -ge 4) { [BitConverter]::ToUInt32($q, 0) } else { 0 } }
            try { $mem = [int64]$q } catch { $mem = 0L }
        }
        if ($mem -le 0) { try { $mem = [int64]$vc.AdapterRAM } catch { $mem = 0L } }   # WMI value, capped at 4 GB
        $vc | Add-Member -NotePropertyName GpuClassKey -NotePropertyValue $key -Force
        $vc | Add-Member -NotePropertyName VramBytes -NotePropertyValue $mem -Force
        if (-not $best -or $mem -gt $best.VramBytes) { $best = $vc }
    }
    $best
}

# Driver keys of the AMD display adapters. Only the 4-digit subkeys are drivers: the
# class key also holds 'Configuration' / 'Properties', and on mixed systems the
# driver keys of other vendors' GPUs.
function Get-AmdGpuKeys {
    Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -match '^\d{4}$' -and "$(Get-RegVal $_.PSPath 'ProviderName') $(Get-RegVal $_.PSPath 'DriverDesc')" -match 'Advanced Micro Devices|ATI Tech|\bAMD\b|Radeon' }
}

# Advanced driver settings of the physical network adapters, read from each driver's
# own parameter list (Ndi\params). Vendors name the same setting differently (EEE:
# *EEE, EEELinkAdvertisement, EnableGreenEthernet ...), so only keywords a driver
# declares are returned, and only if it lists "0" (= off) as a valid choice.
function Get-NicParams([string]$Setting) {
    $keywords = switch ($Setting) {
        'EEE'                 { '*EEE', 'EEE', 'EEELinkAdvertisement', 'AdvancedEEE', 'EnableGreenEthernet', 'GreenEthernet' }
        'InterruptModeration' { '*InterruptModeration' }
    }
    $netClass = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
    foreach ($a in @(Get-ChildItem $netClass -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' })) {
        if (-not (Get-RegVal $a.PSPath 'NetCfgInstanceId') -or -not (([int64](Get-RegVal $a.PSPath 'Characteristics')) -band 0x4)) { continue }   # physical adapters only
        foreach ($kw in $keywords) {
            $np = Join-Path $a.PSPath "Ndi\params\$kw"
            if ($null -eq (Get-RegVal (Join-Path $np 'enum') '0')) { continue }
            $def = Get-RegVal $np 'default'; $cur = Get-RegVal $a.PSPath $kw
            [pscustomobject]@{ Path = $a.PSPath; Keyword = $kw; Default = $def; Current = $(if ($null -ne $cur) { "$cur" } else { "$def" }) }
        }
    }
}

# The servers of both DNS tweaks (Cloudflare, Google; IPv4 + IPv6)
function Get-ProviderDns { @('1.1.1.1', '1.0.0.1', '2606:4700:4700::1111', '2606:4700:4700::1001', '8.8.8.8', '8.8.4.4', '2001:4860:4860::8888', '2001:4860:4860::8844') }

# Static DNS servers of an adapter (IPv4 + IPv6) as Windows stores them; empty = automatic (DHCP).
# DhcpNameServer is what the router hands out -- that one must not be restored as a static value.
function Get-StaticDns([string]$Guid) {
    $v4 = "$(Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$Guid" 'NameServer')"
    $v6 = "$(Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\Interfaces\$Guid" 'NameServer')"
    @(@($v4 -split '[,\s]+') + @($v6 -split '[,\s]+') | Where-Object { $_ })
}

# What each adapter had before a DNS tweak changed it ("guid|server,server", an empty list =
# automatic), so a revert brings back a Pi-hole or company DNS instead of switching to automatic.
function Read-DnsOriginal {
    $m = @{}
    try { foreach ($l in @(Get-Content $Script:DnsOriginalFile -ErrorAction Stop)) { $p = "$l".Split('|'); if ($p.Count -eq 2 -and $p[0]) { $m[$p[0]] = @($p[1].Split(',') | Where-Object { $_ }) } } } catch { }
    $m
}
function Save-DnsOriginal($Map) {
    try {
        New-Item -ItemType Directory -Path (Split-Path $Script:DnsOriginalFile) -Force -ErrorAction Stop | Out-Null
        Set-Content -Path $Script:DnsOriginalFile -Value @($Map.Keys | Sort-Object | ForEach-Object { "$_|$(@($Map[$_]) -join ',')" }) -Encoding ASCII -ErrorAction Stop
    } catch { Write-Log "DNS: the previous DNS servers could not be saved -- $_" }
}

function Set-ProviderDns([string]$Provider, [string[]]$Servers) {
    $orig = Read-DnsOriginal; $changed = $false
    $ok = 0; $fail = 0
    # The adapters the status check looks at: the physical ones when there are any. A VPN,
    # Hyper-V or WSL adapter keeps its own DNS (company and VPN names resolve through it).
    foreach ($a in @(Get-UpAdapters)) {
        # remember the adapter's own setting once -- not again when switching between the two
        # providers: automatic (empty) or any list with a server of its own (Pi-hole, router,
        # 1.1.1.1 next to a Pi-hole). A list of provider servers only came from a provider tweak.
        $g = "$($a.InterfaceGuid)"
        if ($g -and -not $orig.ContainsKey($g)) {
            $st = @(Get-StaticDns $g)
            if (-not $st.Count -or @($st | Where-Object { (Get-ProviderDns) -notcontains $_ }).Count) { $orig[$g] = $st; $changed = $true }
        }
        try {
            Set-DnsClientServerAddress -InterfaceIndex $a.InterfaceIndex -ServerAddresses $Servers -ErrorAction Stop
            $ok++
        } catch {
            $fail++
            Write-Log "WARNING: DNS ($Provider) failed on '$($a.Name)': $_"
        }
    }
    if ($changed) { Save-DnsOriginal $orig }
    Write-Log "DNS set to $Provider (IPv4 + IPv6) -- $ok adapter(s) OK, $fail failed"
}

# DNS revert, only on adapters that use nothing but this provider's servers: back to what the
# adapter had before (saved servers, or automatic). An adapter with a server of the user's own
# next to the provider's (Pi-hole, router, company network) is left exactly as it is.
function Reset-ProviderDns([string]$Provider, [string[]]$Servers) {
    $orig = Read-DnsOriginal
    $n = 0; $kept = 0; $auto = 0
    foreach ($a in @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" })) {
        $cur = @(Get-DnsClientServerAddress -InterfaceIndex $a.InterfaceIndex -ErrorAction SilentlyContinue | ForEach-Object { $_.ServerAddresses })
        if (-not @($cur | Where-Object { $Servers -contains $_ }).Count) { continue }
        if (@($cur | Where-Object { $Servers -notcontains $_ }).Count) { $kept++; Write-Log "Revert: '$($a.Name)' also uses DNS servers of its own -- left as it is"; continue }
        $g = "$($a.InterfaceGuid)"
        $back = @(if ($g -and $orig.ContainsKey($g)) { $orig[$g] })
        Set-DnsClientServerAddress -InterfaceIndex $a.InterfaceIndex -ResetServerAddresses -ErrorAction SilentlyContinue
        if ($back.Count) { Set-DnsClientServerAddress -InterfaceIndex $a.InterfaceIndex -ServerAddresses $back -ErrorAction SilentlyContinue } else { $auto++ }
        if ($g) { $orig.Remove($g) }
        $n++
    }
    if ($n) {
        Save-DnsOriginal $orig
        if ($auto) { ipconfig /renew 2>$null | Out-Null }   # pick up the router's DNS again
        Clear-DnsClientCache -ErrorAction SilentlyContinue
    }
    Write-Log "Revert: $Provider DNS -- $n adapter(s) back to their previous DNS ($auto automatic), $kept with servers of their own left alone"
}

# Connected adapters the network status checks look at. Physical ones only when there
# are any: Hyper-V / WSL (vEthernet), VPN and other virtual adapters can be listed
# first and would otherwise decide the status. Falls back to every connected adapter.
function Get-UpAdapters {
    $up = @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" })
    $phys = @($up | Where-Object { $_.HardwareInterface })
    if ($phys.Count) { $phys } else { $up }
}

# The apps "Remove Other Bloatware" removes -- the status check looks for the same list,
# so a PC that never had Candy Crush (Windows 11 doesn't ship it) isn't reported as done.
# 1.2.6: only what Windows or the PC maker put there. Apps people install themselves
# (Spotify, Netflix, Disney+, Instagram, TikTok, Facebook, X), the Media Player, Films & TV
# and "Get Help" (Windows' troubleshooters run in it) are no longer on the list.
function Get-BloatPatterns {
    @(
        "king.com.*", "*CandyCrush*", "*BubbleWitch*", "*MarchofEmpires*",
        "Microsoft.News", "Microsoft.BingNews", "Microsoft.BingWeather", "Microsoft.MicrosoftSolitaireCollection",
        "Microsoft.WindowsFeedbackHub", "Microsoft.Todos", "Microsoft.MixedReality.Portal", "Clipchamp.Clipchamp",
        "Microsoft.Getstarted", "Microsoft.PowerAutomateDesktop"
    )
}

# The installed packages "Remove Other Bloatware" would remove (shown before the Apply, used by
# its status check). Windows' own system packages (NonRemovable) don't count.
function Get-BloatApps {
    $pats = Get-BloatPatterns
    @(Get-AppxPackage -AllUsers -ErrorAction Stop | Where-Object { $n = $_.Name; -not $_.NonRemovable -and @($pats | Where-Object { $n -like $_ }).Count })
}

# The packages "Remove Xbox Apps" removes. Exact names: the old "*XboxTCUI*" never matched
# Microsoft.Xbox.TCUI (dot in the name). The Xbox app itself (Microsoft.GamingApp) stays.
function Get-XboxPatterns {
    @("Microsoft.XboxApp", "Microsoft.XboxGameOverlay", "Microsoft.XboxGamingOverlay", "Microsoft.XboxIdentityProvider",
      "Microsoft.XboxSpeechToTextOverlay", "Microsoft.Xbox.TCUI")
}

# The tasks "Disable Scheduled Telemetry Tasks" switches off -- Apply, Revert and the status
# check share this list. Windows 11 24H2+ has no "Microsoft Compatibility Appraiser" /
# "ProgramDataUpdater" any more; the appraiser runs as "... Appraiser Exp" there.
function Get-TelemetryTasks {
    @(
        "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
        "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser Exp",
        "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
        "\Microsoft\Windows\Autochk\Proxy",
        "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
        "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
        "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
        # 1.2.4: feedback prompts, the error-report upload queue, SQM and the power-efficiency
        # analysis (Sqm-Tasks is gone on 26H2 -- missing tasks are skipped)
        "\Microsoft\Windows\Feedback\Siuf\DmClient",
        "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload",
        "\Microsoft\Windows\Windows Error Reporting\QueueReporting",
        "\Microsoft\Windows\PI\Sqm-Tasks",
        "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem",
        # 1.2.6: the compatibility-telemetry tasks WinUtil switches off as well
        "\Microsoft\Windows\Application Experience\MareBackup",
        "\Microsoft\Windows\Application Experience\PcaPatchDbTask",
        "\Microsoft\Windows\Application Experience\StartupAppTask"
    )
}

# Some official policies are only read by Enterprise / Education (and their IoT / LTSC /
# multi-session variants); Home and Pro ignore them.
function Test-EnterpriseEdition {
    (Get-RegVal "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" "EditionID") -match '^(Enterprise|Education|IoTEnterprise|ServerRdsh)'
}

# Windows Update for Business and most Policy CSP settings are read from Pro upwards;
# Home (EditionID Core, CoreN, CoreSingleLanguage, CoreCountrySpecific) ignores them.
function Test-HomeEdition {
    (Get-RegVal "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" "EditionID") -match '^Core'
}

# Audio enhancements through the Windows audio API. Windows 11 refuses direct writes to the
# endpoint stores (MMDevices\...\FxProperties: "requested registry access is not allowed",
# measured on 26H2 with a test value), and the registry also keeps endpoints Windows only
# remembers. The policy-config interface asks the audio endpoint service to write instead,
# like the Sound control panel does. PKEY_AudioEndpoint_Disable_SysFx {1da5d803-...},5 in
# the FX store: 1 = enhancements off, 0 = on.
function Initialize-AudioPolicy {
    if ('GOPAudio.Fx' -as [type]) { return }
    Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace GOPAudio {
  [StructLayout(LayoutKind.Sequential)]
  public struct PROPERTYKEY { public Guid fmtid; public int pid; }

  [StructLayout(LayoutKind.Explicit, Size = 24)]
  public struct PROPVARIANT {
    [FieldOffset(0)] public ushort vt;
    [FieldOffset(8)] public uint uintVal;
    [FieldOffset(8)] public IntPtr ptr;
  }

  [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IMMDeviceEnumerator {
    [PreserveSig] int EnumAudioEndpoints(int dataFlow, int stateMask, out IMMDeviceCollection devices);
  }

  [ComImport, Guid("0BD7A1BE-7A1A-44DB-8397-CC5392387B5E"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IMMDeviceCollection {
    [PreserveSig] int GetCount(out uint count);
    [PreserveSig] int Item(uint index, out IMMDevice device);
  }

  [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IMMDevice {
    [PreserveSig] int Activate(ref Guid iid, int clsCtx, IntPtr p, [MarshalAs(UnmanagedType.IUnknown)] out object iface);
    [PreserveSig] int OpenPropertyStore(int access, out IntPtr props);
    [PreserveSig] int GetId([MarshalAs(UnmanagedType.LPWStr)] out string id);
    [PreserveSig] int GetState(out int state);
  }

  [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMDeviceEnumerator { }

  [ComImport, Guid("F8679F50-850A-41CF-9C72-430F290290C8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IPolicyConfig {
    [PreserveSig] int GetMixFormat([MarshalAs(UnmanagedType.LPWStr)] string dev, IntPtr fmt);
    [PreserveSig] int GetDeviceFormat([MarshalAs(UnmanagedType.LPWStr)] string dev, int bDefault, IntPtr fmt);
    [PreserveSig] int ResetDeviceFormat([MarshalAs(UnmanagedType.LPWStr)] string dev);
    [PreserveSig] int SetDeviceFormat([MarshalAs(UnmanagedType.LPWStr)] string dev, IntPtr ep, IntPtr mix);
    [PreserveSig] int GetProcessingPeriod([MarshalAs(UnmanagedType.LPWStr)] string dev, int bDefault, IntPtr d, IntPtr m);
    [PreserveSig] int SetProcessingPeriod([MarshalAs(UnmanagedType.LPWStr)] string dev, IntPtr p);
    [PreserveSig] int GetShareMode([MarshalAs(UnmanagedType.LPWStr)] string dev, IntPtr m);
    [PreserveSig] int SetShareMode([MarshalAs(UnmanagedType.LPWStr)] string dev, IntPtr m);
    [PreserveSig] int GetPropertyValue([MarshalAs(UnmanagedType.LPWStr)] string dev, int bFxStore, ref PROPERTYKEY key, out PROPVARIANT pv);
    [PreserveSig] int SetPropertyValue([MarshalAs(UnmanagedType.LPWStr)] string dev, int bFxStore, ref PROPERTYKEY key, ref PROPVARIANT pv);
  }

  [ComImport, Guid("870AF99C-171D-4F9E-AF0D-E63DF40C2BC9")] class PolicyConfigClient { }

  public static class Fx {
    [DllImport("ole32.dll")] static extern int PropVariantClear(ref PROPVARIANT pv);

    // eRender = 0; stateMask: DEVICE_STATE_ACTIVE = 1, DEVICE_STATE_UNPLUGGED = 8
    public static string[] RenderIds(int stateMask) {
      var list = new List<string>();
      var en = (IMMDeviceEnumerator)(new MMDeviceEnumerator());
      IMMDeviceCollection col;
      if (en.EnumAudioEndpoints(0, stateMask, out col) != 0) return list.ToArray();
      uint n; col.GetCount(out n);
      for (uint i = 0; i < n; i++) {
        IMMDevice d; if (col.Item(i, out d) != 0) continue;
        string id; if (d.GetId(out id) == 0) list.Add(id);
      }
      return list.ToArray();
    }

    static PROPERTYKEY Key(string fmtid, int pid) { var k = new PROPERTYKEY(); k.fmtid = new Guid(fmtid); k.pid = pid; return k; }

    // the value, -1 when the property isn't set (Windows default), -2 when the service refused
    public static long GetUInt(string id, bool fx, string fmtid, int pid) {
      var pc = (IPolicyConfig)(new PolicyConfigClient());
      var k = Key(fmtid, pid);
      PROPVARIANT pv;
      if (pc.GetPropertyValue(id, fx ? 1 : 0, ref k, out pv) != 0) return -2;
      long r = (pv.vt == 19 || pv.vt == 18 || pv.vt == 3) ? (long)pv.uintVal : -1;   // VT_UI4, VT_UI2, VT_I4
      PropVariantClear(ref pv);
      return r;
    }

    // HRESULT, 0 = written
    public static int SetUInt(string id, bool fx, string fmtid, int pid, uint value) {
      var pc = (IPolicyConfig)(new PolicyConfigClient());
      var k = Key(fmtid, pid);
      var pv = new PROPVARIANT(); pv.vt = 19; pv.uintVal = value;   // VT_UI4
      return pc.SetPropertyValue(id, fx ? 1 : 0, ref k, ref pv);
    }
  }
}
'@
}
# Playback devices that are there: active or unplugged (the jack is empty) -- not the ones
# Windows only remembers.
function Get-AudioRenderIds { Initialize-AudioPolicy; @([GOPAudio.Fx]::RenderIds(1 -bor 8)) }
function Get-AudioFx([string]$Id) { Initialize-AudioPolicy; [GOPAudio.Fx]::GetUInt($Id, $true, '{1da5d803-d492-4edd-8c23-e0c0ffee7f0e}', 5) }
function Set-AudioFx([string]$Id, [uint32]$Value) { Initialize-AudioPolicy; [GOPAudio.Fx]::SetUInt($Id, $true, '{1da5d803-d492-4edd-8c23-e0c0ffee7f0e}', 5, $Value) }

# The WMI results are kept in $Script:VideoCtrls / $Script:GpuObj / $Script:CpuObj and
# reused by the dashboard, so every class is queried only once per start.
try {
    $Script:VideoCtrls = @(Get-WmiObject Win32_VideoController)
    $Script:GpuObj = Select-PrimaryGpu $Script:VideoCtrls
    $GPU = $Script:GpuObj.Name
} catch { $GPU = $null; $Script:VideoCtrls = @(); $Script:GpuObj = $null }
if ([string]::IsNullOrWhiteSpace($GPU)) { $GPU = "Unknown GPU" }

try {
    # Only the properties we need: a full Win32_Processor query also samples the CPU
    # load, which alone costs ~1 s on every start.
    $Script:CpuObj = Get-WmiObject -Query "SELECT Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed FROM Win32_Processor" | Select-Object -First 1
    $CPU = $Script:CpuObj.Name
} catch { $CPU = $null }
if ([string]::IsNullOrWhiteSpace($CPU)) { $CPU = "Unknown CPU" } else { $CPU = ($CPU -replace '\s+', ' ').Trim() }   # WMI pads the name with spaces

try {
    $RAM = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
} catch { $RAM = 0 }

$IsNVIDIA   = $GPU -match "NVIDIA"
$IsAMD      = $GPU -match "AMD|Radeon"

try {
    # Most NVMe drives do NOT say "NVMe" in their model string (e.g. "Samsung SSD
    # 980 PRO 1TB", "WD_BLACK SN850X"), so matching the model alone missed them and
    # silently skipped the NVMe tweak. With the inbox stornvme driver the PNP ID
    # carries VEN_NVME; drives on a vendor driver are caught via the storage
    # stack's BusType (17 = NVMe) matched back by friendly name. MSFT_PhysicalDisk is
    # read straight from WMI -- Get-PhysicalDisk returns the same objects but loads
    # the Storage module first (~0.5 s).
    $nvmeNames = @()
    try { $nvmeNames = @(Get-WmiObject -Namespace "root\Microsoft\Windows\Storage" -Class MSFT_PhysicalDisk -ErrorAction Stop | Where-Object { "$($_.BusType)" -eq "NVMe" -or "$($_.BusType)" -eq "17" } | ForEach-Object { $_.FriendlyName }) } catch { }
    $NVMeDisks = @(Get-WmiObject -Query "SELECT * FROM Win32_DiskDrive" | Where-Object {
        $_.Model -match "NVMe" -or $_.PNPDeviceID -match "VEN_NVME" -or ($nvmeNames -contains $_.Model)
    })
} catch { $NVMeDisks = @() }
$HasNVMe  = $NVMeDisks.Count -gt 0
$NVMeInfo = if ($HasNVMe) { "NVMe: $($NVMeDisks.Count)x" } else { "NVMe: none" }

try {
    $OSInfo  = Get-WmiObject Win32_OperatingSystem -ErrorAction Stop
    $OSBuild = [int]$OSInfo.BuildNumber
    $OSName  = $OSInfo.Caption
} catch { $OSBuild = 0; $OSName = "Unknown OS" }
# Fallback: if WMI failed (OSBuild 0, e.g. on some VMs/locked-down systems),
# read the build straight from the registry so OS detection still works.
if ($OSBuild -lt 10240) {
    try {
        $cv = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction Stop
        if ($cv.CurrentBuildNumber) { $OSBuild = [int]$cv.CurrentBuildNumber }
        if ((-not $OSName) -or $OSName -eq "Unknown OS") { if ($cv.ProductName) { $OSName = $cv.ProductName } }
    } catch { }
}
$IsWin11 = $OSBuild -ge 22000
$IsWin10 = $OSBuild -ge 10240 -and $OSBuild -lt 22000
$OSShort = if ($IsWin11) { "Win11 (Build $OSBuild)" } elseif ($IsWin10) { "Win10 (Build $OSBuild)" } else { $OSName }

# Active network connection (name, adapter, link speed, IPv4 gateway + DNS) via .NET.
# Get-NetIPConfiguration returns the same data but needs ~1.2 s on a cold start.
# Prefers the connection that has a default gateway; read once, then cached.
function Get-NetSummary {
    if ($Script:NetSummary) { return $Script:NetSummary }
    $best = $null
    try {
        foreach ($ni in [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
            if ("$($ni.OperationalStatus)" -ne 'Up' -or "$($ni.NetworkInterfaceType)" -in @('Loopback', 'Tunnel')) { continue }
            $ipp = $ni.GetIPProperties()
            $gw  = @($ipp.GatewayAddresses | Where-Object { "$($_.Address.AddressFamily)" -eq 'InterNetwork' -and "$($_.Address)" -ne '0.0.0.0' } | ForEach-Object { "$($_.Address)" })
            $dns = @($ipp.DnsAddresses | Where-Object { "$($_.AddressFamily)" -eq 'InterNetwork' } | ForEach-Object { "$_" })
            $speed = ''
            if ($ni.Speed -ge 1000000000) { $speed = [string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0:0.#} Gbps', $ni.Speed / 1e9) }
            elseif ($ni.Speed -gt 0)      { $speed = [string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0:0} Mbps', $ni.Speed / 1e6) }
            $info = @{ Name = $ni.Name; Desc = $ni.Description; Speed = $speed; Gateway = $(if ($gw.Count) { $gw[0] }); Dns = $dns }
            if ($gw.Count) { $best = $info; break }
            if (-not $best) { $best = $info }
        }
    } catch { }
    $Script:NetSummary = $best
    return $best
}

$HWInfo  ="GPU: $GPU   |   CPU: $CPU   |   RAM: $RAM GB   |   $NVMeInfo   |   $OSShort"
foreach ($p in $logPaths) { try { "[$(Get-Date -f 'HH:mm:ss')] Hardware erkannt: $HWInfo" | Out-File $p -Append -ErrorAction SilentlyContinue } catch { } }
Write-Host "[$(Get-Date -f 'HH:mm:ss')] Hardware erkannt: $HWInfo" -ForegroundColor DarkGray
Set-Splash "Loading tweak definitions ..." 15

# -----------------------------------------
# LOGGING
# -----------------------------------------
$LogFile = "$env:TEMP\GameOptimizerPro_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
# One log per start -- keep the newest 20, the older ones go
try { Get-ChildItem -Path "$env:TEMP\GameOptimizerPro_*.log" -File -ErrorAction Stop | Sort-Object Name -Descending | Select-Object -Skip 20 | Remove-Item -Force -ErrorAction SilentlyContinue } catch { }
function Write-Log {
    param([string]$Message)
    $entry = "[$(Get-Date -Format 'HH:mm:ss')] $Message"
    # A log line must never break a tweak: if the file is briefly locked (antivirus,
    # an editor holding it open), the line is dropped instead.
    # Three short tries before a line is dropped (antivirus scans hold the file for
    # a few milliseconds at a time).
    for ($try = 0; $try -lt 3; $try++) {
        try { Add-Content -Path $LogFile -Value $entry -ErrorAction Stop; return } catch { Start-Sleep -Milliseconds 40 }
    }
}

# -----------------------------------------
# DEEP CLEAN HELPER
# Deletes everything matching the given paths and returns the number of bytes
# ACTUALLY freed. Files that are locked/in use survive the delete (skipped via
# -ErrorAction SilentlyContinue), so the size is measured before AND after --
# counting only "before" reported locked files (e.g. an open browser's cache)
# as freed although they were still on disk.
# -----------------------------------------
function Get-PathItemsSize {
    param([string]$Path)
    $s = (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer } | Measure-Object -Property Length -Sum).Sum
    return [int64]$s
}
function Clear-PathItems {
    param([string[]]$Paths)
    [int64]$freed = 0
    foreach ($p in $Paths) {
        $before = Get-PathItemsSize $p
        Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue
        $after  = Get-PathItemsSize $p
        # Clamp: an app may write new files meanwhile (after > before) -- never report negative
        if ($before -gt $after) { $freed += ($before - $after) }
    }
    return $freed
}
function Format-FreedMB { param([int64]$Bytes) return ([math]::Round($Bytes / 1MB, 1)).ToString("0.#", [System.Globalization.CultureInfo]::InvariantCulture) }

# -----------------------------------------
# REGISTRY BACKUP
# System Restore Points are frequently skipped by Windows (24h creation-
# frequency limit), so they can't be relied on alone. This exports every
# registry key any tweak touches to .reg files before Apply/Revert, giving
# a always-available, tweak-specific fallback independent of VSS.
# -----------------------------------------
$Script:RegistryBackupRoot = "$env:LOCALAPPDATA\GameOptimizerPro\RegistryBackups"
$Script:DnsOriginalFile = "$env:LOCALAPPDATA\GameOptimizerPro\dns_original.txt"   # see Set-ProviderDns

$Script:RegistryBackupKeys = @(
    "HKCU\AppEvents\Schemes",
    "HKCU\Control Panel",
    "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search",
    "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize",
    "HKCU\SOFTWARE\NVIDIA Corporation\Global\NVTweak",
    "HKCU\SOFTWARE\Policies\Microsoft\Windows\Explorer",
    "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}",
    # Per-folder Explorer view settings (Bags/BagMRU) -- "Disable File Explorer
    # Automatic Folder Discovery" DELETES these trees, so they must be saved first.
    "HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell",
    "HKCU\Software\Microsoft\GameBar",
    "HKCU\Software\Microsoft\Input\TIPC",
    "HKCU\Software\Microsoft\InputPersonalization",
    "HKCU\Software\Microsoft\Lighting",
    "HKCU\Software\Microsoft\Siuf\Rules",
    "HKCU\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\SearchSettings",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot",
    "HKCU\Software\Policies\Microsoft\Windows\WindowsAI",
    "HKCU\System\GameConfigStore",
    "HKLM\SOFTWARE\ATI Technologies\CBT",
    "HKLM\SOFTWARE\Microsoft\Dfrg\BootOptimizeFunction",
    "HKLM\SOFTWARE\Microsoft\DirectX",
    "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia",
    "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore",
    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore",
    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Communications",
    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved",
    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render",
    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection",
    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint",
    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
    "HKLM\SOFTWARE\Policies\Microsoft\Dsh",
    "HKLM\SOFTWARE\Policies\Microsoft\OneDrive",
    "HKLM\SOFTWARE\Policies\Microsoft\Windows",
    "HKLM\SOFTWARE\Policies\WindowsNotepad",
    # Only the parts of HKLM\SYSTEM\CurrentControlSet\Control the tweaks touch -- the whole
    # key is ~35 MB per backup. Two values that sit directly in big keys are saved one by
    # one ($Script:RegistryBackupValues), the AMD driver keys are added at backup time.
    "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}",
    "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e96c-e325-11ce-bfc1-08002be10318}",
    "HKLM\SYSTEM\CurrentControlSet\Control\FeatureManagement\Overrides\8",
    "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem",
    "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers",
    "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling",
    "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl",
    "HKLM\SYSTEM\CurrentControlSet\Control\Remote Assistance",
    "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel",
    "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management",
    "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters",
    "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak",
    "HKLM\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device",
    "HKLM\SYSTEM\CurrentControlSet\Services\usbaudio",
    "HKLM\SYSTEM\CurrentControlSet\Services\usbaudio2",
    "HKU\.DEFAULT\Control Panel\Keyboard"
)
# Single values in keys too big to export whole -- written to _values.reg ("name"=- when the
# value didn't exist, so a double-click also removes what a tweak added)
$Script:RegistryBackupValues = @(
    @("HKLM\SYSTEM\CurrentControlSet\Control", "SvcHostSplitThresholdInKB"),
    @("HKLM\SYSTEM\CurrentControlSet\Control\Session Manager", "DisableWpbtExecution")
)

# Values written by tweaks that were removed because Windows or the driver never read them
# (1.2.1: five NVIDIA registry values, Spatial Sound, Audio Device Power Save, the
# organisation-only Windows Backup policy; 1.2.3: Chat / Teams; 1.2.6: TCP settings, QoS
# limit, NVMe queue depth, the Start menu override, two AMD values and the kernel value of
# the old "Disable Background App Throttling"), plus the restore-point frequency override
# older versions left at 0. Harmless, but Revert All promises a clean state -- so it
# removes them. Returns how many values were removed.
function Remove-RetiredTweakValues {
    $nv = "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak"
    $tcp = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
    # key, value, and the value the old tweak wrote: only exactly that is removed, so an
    # organisation's policy or a setting chosen by hand stays. $null = whatever it holds.
    $targets = @(
        @($nv, 'NVLatency', $null), @($nv, 'ThreadedOptimization', $null), @($nv, 'PrerenderedFrames', $null),
        @($nv, 'PowerMizerEnable', $null), @($nv, 'PowerMizerLevel', $null), @($nv, 'PowerMizerLevelAC', $null),
        @("HKCU:\SOFTWARE\NVIDIA Corporation\Global\NVTweak", 'NvCplCacheShaderMaxSize', $null),
        @("HKLM:\SYSTEM\CurrentControlSet\Services\usbaudio", 'DisableSelectiveSuspend', $null),
        @("HKLM:\SYSTEM\CurrentControlSet\Services\usbaudio2", 'DisableSelectiveSuspend', $null),
        @("HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync", 'EnableWindowsBackup', 0),
        @("HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore", 'SystemRestorePointCreationFrequency', 0),
        @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced", 'TaskbarMn', 0),
        @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Communications", 'ConfigureChatAutoInstall', 0),
        @($tcp, 'SackOpts', 1), @($tcp, 'TcpMaxDupAcks', 2),
        @("HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched", 'NonBestEffortLimit', 0),
        @("HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device", 'IdlePowerEnabled', 0),
        @("HKLM:\SYSTEM\CurrentControlSet\Control\FeatureManagement\Overrides\8\3036241548", 'EnabledState', 1),
        @("HKLM:\SOFTWARE\ATI Technologies\CBT", 'ShaderCacheSizePC', 4294967295),
        @("HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel", 'DisableLowQosTimerResolution', 1)
    )
    foreach ($k in @(Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render" -ErrorAction SilentlyContinue)) { $targets += , @($k.PSPath, 'SpatialAudioMode', $null) }
    foreach ($k in @(Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e96c-e325-11ce-bfc1-08002be10318}" -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' })) { $targets += , @($k.PSPath, 'PowerThrottlingOff', $null) }
    foreach ($dk in @($NVMeDisks)) {
        $dp = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($dk.PNPDeviceID)\Device Parameters"
        $targets += , @("$dp\StorPort", 'QueueDepth', 32); $targets += , @("$dp\Interrupt Management\Affinity Policy", 'DevicePriority', 2)
    }
    foreach ($k in @(Get-AmdGpuKeys)) { $targets += , @($k.PSPath, 'KMD_EnableComputePreemption', 0); $targets += , @($k.PSPath, 'EnableAntiLag', 1) }
    $n = 0
    foreach ($tg in $targets) {
        $v = Get-RegVal $tg[0] $tg[1]
        if ($null -eq $v) { continue }
        if ($null -ne $tg[2]) {
            $u = try { [int64]$v } catch { $null }
            if ($null -ne $u -and $u -lt 0) { $u += 4294967296 }     # a DWORD above 0x7FFFFFFF reads as a negative number
            if ($u -ne [int64]$tg[2]) { continue }
        }
        Remove-ItemProperty -Path $tg[0] -Name $tg[1] -ErrorAction SilentlyContinue
        if ($null -eq (Get-RegVal $tg[0] $tg[1])) { $n++ }
    }
    # The revert of the old "Optimize TCP Settings" switched ECN and TCP timestamps ON --
    # Windows has both off. Only those two, and only when they are on.
    try {
        $ts = Get-NetTCPSetting -SettingName Internet -ErrorAction Stop
        if ("$($ts.EcnCapability)" -eq 'Enabled') { netsh int tcp set global ecncapability=default 2>$null | Out-Null; $n++ }
        if ("$($ts.Timestamps)" -eq 'Enabled') { netsh int tcp set global timestamps=default 2>$null | Out-Null; $n++ }
    } catch { }
    if ($n) { Write-Log "Revert All: removed $n value(s) left behind by retired tweaks" }
    $n
}

function Backup-Registry {
    param([string]$Label = "Backup")
    $stamp     = Get-Date -Format 'yyyyMMdd_HHmmss'
    # "v1-" marks this app's backups: GameOptimizerPro v2 writes to the same folder with the
    # same labels, and only our own are ever pruned below
    $backupDir = Join-Path $Script:RegistryBackupRoot "${stamp}_v1-$Label"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

    # Per-device keys can't be listed statically (their path contains the PNP
    # instance ID): MSI mode writes under the GPU, NVMe queue depth and
    # write-cache flushing write under each disk. Add their Device Parameters.
    $keys = @($Script:RegistryBackupKeys)
    try {
        $devIds  = @(Get-WmiObject Win32_VideoController -ErrorAction Stop | Where-Object { $_.Name -notmatch "Microsoft" } | ForEach-Object { $_.PNPDeviceID })
        $devIds += @(Get-WmiObject -Query "SELECT * FROM Win32_DiskDrive" -ErrorAction Stop | ForEach-Object { $_.PNPDeviceID })
        foreach ($id in ($devIds | Where-Object { $_ } | Select-Object -Unique)) {
            $keys += "HKLM\SYSTEM\CurrentControlSet\Enum\$id\Device Parameters"
        }
    } catch { }
    # AMD driver keys (ULPS, values of retired AMD tweaks) -- not the whole display class (~4 MB)
    try { foreach ($k in @(Get-AmdGpuKeys)) { $keys += ($k.Name -replace '^HKEY_LOCAL_MACHINE', 'HKLM') } } catch { }

    $saved = 0
    $skipped = 0
    $missing = @()
    $hives = @{ HKCU = 'HKEY_CURRENT_USER'; HKLM = 'HKEY_LOCAL_MACHINE'; HKU = 'HKEY_USERS'; HKCR = 'HKEY_CLASSES_ROOT' }
    foreach ($key in $keys) {
        $hv, $rest = $key -split '\\', 2
        $full = if ($hives.ContainsKey($hv)) { "$($hives[$hv])\$rest" } else { $key }
        # A key that isn't there can't be exported -- note it: a tweak may create it
        if (-not (Test-Path -LiteralPath "Registry::$full")) { $missing += $full; $skipped++; continue }
        $base = $key -replace '[\\:\*\?"<>\|]', '_'
        $dest = Join-Path $backupDir "$base.reg"
        # two keys that only differ by '\' vs '_' must not overwrite each other
        for ($i = 2; Test-Path -LiteralPath $dest; $i++) { $dest = Join-Path $backupDir "${base}_$i.reg" }
        try {
            $null = & reg.exe export "$key" "$dest" /y 2>&1
            if ($LASTEXITCODE -eq 0) { $saved++ } else { $skipped++ }
        } catch { $skipped++ }
    }
    # The exports put the saved values back when double-clicked, but can't delete a key a tweak
    # created afterwards -- this file can (keys that didn't exist at backup time).
    if ($missing.Count) {
        $lines = @('Windows Registry Editor Version 5.00', '',
            '; GameOptimizerPro -- keys that did NOT exist when this backup was made.',
            '; Double-click to delete them again (only needed if a tweak created them).',
            '; Values a tweak added to a key that already existed go away with that tweak''s revert.', '')
        $lines += @($missing | ForEach-Object { "[-$_]" })
        try { $lines | Set-Content -LiteralPath (Join-Path $backupDir '_remove-new-keys.reg') -Encoding Unicode -ErrorAction Stop } catch { }
    }
    # Single values (see $Script:RegistryBackupValues): "name"=dword:... or "name"=- when absent
    $vl = @('Windows Registry Editor Version 5.00', '', '; GameOptimizerPro -- single values (a double-click puts them back, "=-" removes one a tweak added).', '')
    foreach ($bv in $Script:RegistryBackupValues) {
        $hv, $rest = $bv[0] -split '\\', 2
        $full = if ($hives.ContainsKey($hv)) { "$($hives[$hv])\$rest" } else { $bv[0] }
        $line = '"{0}"=-' -f $bv[1]
        try {
            $rk = Get-Item -LiteralPath "Registry::$full" -ErrorAction Stop
            $val = $rk.GetValue($bv[1], $null, 'DoNotExpandEnvironmentNames')
            if ($null -ne $val) {
                switch ("$($rk.GetValueKind($bv[1]))") {
                    'DWord'  { $line = '"{0}"=dword:{1:x8}' -f $bv[1], [BitConverter]::ToUInt32([BitConverter]::GetBytes([int32]$val), 0) }
                    'String' { $line = '"{0}"="{1}"' -f $bv[1], ("$val" -replace '\\', '\\' -replace '"', '\"') }
                    default  { $line = $null }
                }
            }
        } catch { }
        if ($line) { $vl += "[$full]"; $vl += $line; $vl += '' }
    }
    try { $vl | Set-Content -LiteralPath (Join-Path $backupDir '_values.reg') -Encoding Unicode -ErrorAction Stop } catch { }
    Write-Log "Registry backup ($Label): $saved keys saved, $($missing.Count) not present yet (listed in _remove-new-keys.reg), $($skipped - $missing.Count) failed -> $backupDir"
    # Keep the newest 20 of this app's backups. Older folders without the "v1-" mark (made
    # before 1.2.6, or by v2 with the same labels) are never deleted here.
    try {
        Get-ChildItem -LiteralPath $Script:RegistryBackupRoot -Directory -ErrorAction Stop | Where-Object { $_.Name -match '^\d{8}_\d{6}_v1-' } | Sort-Object Name -Descending |
            Select-Object -Skip 20 | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue; Write-Log "Old registry backup removed: $($_.Name)" }
    } catch { }
    return $backupDir
}

# -----------------------------------------
# POWER PLAN HELPER
# Windows resets the active power scheme (and its per-setting overrides) on
# reboot on many systems, so a value written only to the active plan appears
# "reverted" after a restart. Writing to EVERY scheme keeps the setting in
# effect no matter which plan Windows activates next. GUIDs are parsed from
# `powercfg /L` (we read the GUID, never the localized plan name -> locale-safe).
# -----------------------------------------
function Get-PowerSchemeGuids {
    $guids = @(foreach ($line in (powercfg /L 2>$null)) {
        if ($line -match '([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})') { $matches[1] }
    })
    if ($guids.Count -eq 0) { $guids = @('SCHEME_CURRENT') }
    $guids
}
function Set-PowerAllSchemes {
    param([string]$Sub, [string]$Setting, [int]$AC, [int]$DC = $AC)
    foreach ($g in (Get-PowerSchemeGuids)) {
        powercfg /SETACVALUEINDEX $g $Sub $Setting $AC 2>$null | Out-Null
        powercfg /SETDCVALUEINDEX $g $Sub $Setting $DC 2>$null | Out-Null
    }
    powercfg /SETACTIVE SCHEME_CURRENT 2>$null | Out-Null
}

# A copy of the Ultimate Performance template: ours (stored GUID) or any other -- the plan
# keeps the template's name resource (powrprof.dll,-19) in every language
function Test-UltimatePlan([string]$Guid) {
    if ($Guid -and $Guid -eq (Get-RegVal "HKLM:\SOFTWARE\GameOptimizerPro" "UltimatePerfGuid")) { return $true }
    "$(Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\$Guid" 'FriendlyName')" -match 'powrprof\.dll,-19,|Ultimate Performance|Ultimative Leistung'
}

# REVERT of a power tweak: back to the Windows default of EACH plan, read from the setting's
# own definition (PowerSettings\<group>\<setting>\DefaultPowerSchemeValues\<plan>). Until 1.2.5
# the reverts wrote one fixed value to every plan -- PCIe "2" (maximum power savings), 30 min
# disk sleep, a 5 % CPU minimum on High performance. A plan Windows has no defaults for gets
# High performance's when it is an Ultimate copy, Balanced's otherwise. The four timeouts
# the "Ultimate Performance Plan" tweak sets to "never" on its own plan are left to it.
function Reset-PowerSetting([string]$Sub, [string]$Setting) {
    $def  = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\$Sub\$Setting\DefaultPowerSchemeValues"
    $bal  = '381b4222-f694-41f0-9685-ff5bb260df2e'; $high = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
    $ult  = Get-RegVal "HKLM:\SOFTWARE\GameOptimizerPro" "UltimatePerfGuid"
    $ultOwned = @('29f6c1db-86da-48c5-9fdb-f2b67b1f44da', '9d7815a6-7ee4-497e-8888-515a05f02364', '3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e', '6738e2c4-e8a5-4a42-b16a-e040e769756e')
    # Windows 11 Balanced defaults, for when the definition can't be read
    $fb = switch ($Setting) {
        '6738e2c4-e8a5-4a42-b16a-e040e769756e' { @(1200, 600) }   # turn off hard disk after
        '3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e' { @(600, 300) }    # turn off display after
        '29f6c1db-86da-48c5-9fdb-f2b67b1f44da' { @(1800, 900) }   # sleep after
        'bd3b718a-0680-4d9d-8ab2-e1d2b4ac806d' { @(1, 0) }        # wake timers
        'ee12f906-d277-404b-b6da-e5fa1a576df5' { @(1, 2) }        # PCI Express link state power management
        '48e6b7a6-50f5-4782-a5d4-53bb8f07e226' { @(1, 1) }        # USB selective suspend
        'd4e98f31-5ffe-4ce1-be31-1b38b384c009' { @(2, 2) }        # USB 3 link power management
        '893dee8e-2bef-41e0-89c6-b55d0929964c' { @(5, 5) }        # minimum processor state
        'bc5038f7-23e0-4960-96da-33abaf5935ec' { @(100, 100) }    # maximum processor state
        default { throw "no Windows default known for power setting $Setting" }
    }
    $n = 0
    foreach ($g in (Get-PowerSchemeGuids)) {
        if ($ult -and $g -eq $ult -and $ultOwned -contains $Setting) { continue }
        $src = if (Test-Path "$def\$g") { $g } elseif (Test-UltimatePlan $g) { $high } else { $bal }
        $ac = Get-RegVal "$def\$src" 'ACSettingIndex'; $dc = Get-RegVal "$def\$src" 'DCSettingIndex'
        if ($null -eq $ac) { $ac = $fb[0] }; if ($null -eq $dc) { $dc = $fb[1] }
        powercfg /SETACVALUEINDEX $g $Sub $Setting $ac 2>$null | Out-Null
        powercfg /SETDCVALUEINDEX $g $Sub $Setting $dc 2>$null | Out-Null
        $n++
    }
    powercfg /SETACTIVE SCHEME_CURRENT 2>$null | Out-Null
    $n
}

# -----------------------------------------
# POWER SETTING READER (for the status checks)
# `powercfg /QUERY` prints the possible-settings block (Minimum / Maximum /
# Increment) BEFORE the two "current AC/DC setting index" lines. Searching the
# whole output for a hex value therefore matches those STATIC lines too:
#   SUB_DISK DISKIDLE   -> "Minimum possible setting: 0x00000000"
#   SUB_SLEEP STANDBYIDLE -> "Minimum possible setting: 0x00000000"
#   SUB_PROCESSOR PROCTHROTTLEMIN/MAX -> "Maximum possible setting: 0x00000064"
# which made those four checks report "active" on every system, even when the
# tweak had never been applied. Only the LAST TWO hex values in the output are
# the current AC and DC indices, and their labels are localized while the hex
# is not -> reading them positionally is both correct and locale-safe.
# Returns the AC index as a lowercase 8-digit hex string, or $null.
# -----------------------------------------
function Get-PowerValueAC {
    # -Hidden: settings Windows hides from Power Options (USB 3 link power management)
    # only show up with /QH
    param([string]$Sub, [string]$Setting, [switch]$Hidden)
    $out = if ($Hidden) { powercfg /QH SCHEME_CURRENT $Sub $Setting 2>$null } else { powercfg /QUERY SCHEME_CURRENT $Sub $Setting 2>$null }
    if (-not $out) { return $null }
    $hex = @($out | ForEach-Object { if ($_ -match '0x([0-9a-fA-F]{8})') { $matches[1] } })
    if ($hex.Count -lt 2) { return $null }
    return $hex[-2].ToLower()
}

# -----------------------------------------
# TWEAK DEFINITIONS
# -----------------------------------------

$AllTweaks = @(

    # == WINDOWS / BLOATWARE ==============================================
    [PSCustomObject]@{
        Name     = "Remove Xbox Apps"
        Desc     = "Entfernt die Xbox Game Bar, den Xbox Identity Provider, Xbox TCUI und das Sprach-Overlay (unter Windows 10 auch die alte Xbox-App). Diese Apps laufen im Hintergrund - auch wenn du keine Xbox hast. ACHTUNG: Danach fehlen die Xbox-Anmeldung für Spiele aus Game Pass und dem Microsoft Store (Xbox Identity Provider), der Xbox-Modus und Aufnahmen mit der Game Bar - bis du die Apps aus dem Microsoft Store neu installierst. Die Xbox-App selbst (Game Pass) bleibt. Steam-, Epic- und andere Spiele laufen normal weiter."
        Category = "Windows"
        Group    = "Bloatware"
        Action   = {
            # -AllUsers on both sides: installed for another account, the app stayed and the
            # status check (which looks at every account) never turned green
            foreach ($app in (Get-XboxPatterns)) { Get-AppxPackage -AllUsers $app | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue }
            Write-Log "Xbox apps removed (Game Bar, Identity Provider, TCUI, speech overlay)"
        }
    },
    [PSCustomObject]@{
        Name     = "Remove Copilot"
        Desc     = "Deaktiviert und entfernt Windows Copilot (KI-Assistent). Verhindert dass Copilot im Hintergrund läuft und Daten sendet."
        Category = "Windows"
        Group    = "Bloatware"
        Action   = {
            reg add "HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f | Out-Null
            Get-AppxPackage -AllUsers "*Copilot*" | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
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
            # Started with -Wait: called directly, the setup returns at once and the status check
            # still found OneDrive. A machine-wide install (Program Files) needs /allusers.
            $machine = @("$env:ProgramFiles\Microsoft OneDrive\OneDrive.exe", "${env:ProgramFiles(x86)}\Microsoft OneDrive\OneDrive.exe") | Where-Object { Test-Path $_ }
            if (Test-Path $onedrive) { Start-Process -FilePath $onedrive -ArgumentList $(if ($machine) { '/uninstall /allusers' } else { '/uninstall' }) -Wait -WindowStyle Hidden }
            reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v OneDrive /f 2>$null
            # Remove the leftover OneDrive entry from the File Explorer sidebar (64-bit + 32-bit)
            reg delete "HKCR\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" /f 2>$null
            reg delete "HKCR\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" /f 2>$null
            Write-Log "OneDrive removed (incl. Explorer sidebar entry)"
        }
    },
    [PSCustomObject]@{
        Name     = "Remove Windows Recall"
        Desc     = "Deaktiviert und entfernt Windows Recall - das KI-Feature, das Screenshots deiner Aktivitäten macht und lokal speichert. Nutzt die offiziellen Microsoft-Richtlinien: Snapshots aus + Recall-Komponente vom System entfernt (vorhandene Snapshots werden gelöscht). Neustart nötig."
        Category = "Windows"
        Group    = "Bloatware"
        Action   = {
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v DisableAIDataAnalysis /t REG_DWORD /d 1 /f | Out-Null
            # Official policy "Allow Recall to be enabled" = 0: Recall becomes unavailable
            # and Windows REMOVES its bits (plus any saved snapshots) at the next restart.
            # DisableAIDataAnalysis alone only stops new snapshots.
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v AllowRecallEnablement /t REG_DWORD /d 0 /f | Out-Null
            Disable-WindowsOptionalFeature -Online -FeatureName "Recall" -NoRestart -ErrorAction SilentlyContinue | Out-Null
            Write-Log "Recall disabled + removal enforced by policy (AllowRecallEnablement=0, takes effect after restart)"
        }
    },
    [PSCustomObject]@{
        Name     = "Remove Other Bloatware"
        Desc     = "Entfernt vorinstallierte Apps, die Windows oder der PC-Hersteller mitbringt: Candy Crush und andere Werbe-Spiele, News, Wetter, Solitaire, Clipchamp, Microsoft To Do, Feedback-Hub, Tipps, Power Automate und das Mixed-Reality-Portal. Was davon auf deinem PC ist und entfernt wird, zeigt die Rückfrage vor dem Anwenden. Apps, die du selbst installiert hast (Spotify, Netflix, Instagram ...), der Media Player und 'Hilfe anfordern' bleiben. Zurück kommen die Apps über den Microsoft Store."
        Category = "Windows"
        Group    = "Bloatware"
        Action   = {
            foreach ($app in (Get-BloatPatterns)) { Get-AppxPackage -AllUsers $app | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue }
            Write-Log "Bloatware removed"
        }
    },
    [PSCustomObject]@{
        Name     = "Stop Auto-Installed Suggested Apps"
        Desc     = "Verhindert, dass Windows vorgeschlagene Apps und Spiele (z.B. Candy Crush, TikTok) still nachinstalliert - auch die von Hersteller und Microsoft vorgesehenen. Wirkt auf allen Editionen inkl. Home und Pro. Bereits installierte Apps bleiben, dafür gibt es 'Remove Other Bloatware'."
        Category = "Windows"
        Group    = "Bloatware"
        Action   = {
            $cdm = "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
            reg add $cdm /v SilentInstalledAppsEnabled /t REG_DWORD /d 0 /f | Out-Null
            reg add $cdm /v OemPreInstalledAppsEnabled /t REG_DWORD /d 0 /f | Out-Null
            reg add $cdm /v PreInstalledAppsEnabled    /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Auto-install of suggested apps disabled (ContentDeliveryManager)"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Tips, Ads & Suggestions"
        Desc     = "Schaltet die Werbung, Tipps und Vorschläge ab, die Windows überall einstreut: Tipp-Benachrichtigungen, die Seiten 'Einrichtung abschließen' und die Willkommensseite nach Updates, Vorschläge in den Einstellungen und im Start, Konto-Hinweise (Microsoft 365, OneDrive-Sicherung) im Start und in den Einstellungen sowie Werbung von Sync-Anbietern im Datei-Explorer. Die Bilder von Windows-Blickpunkt (Spotlight) auf dem Sperrbildschirm bleiben, nur die Tipps darauf verschwinden - den Hauptschalter 'ContentDeliveryAllowed' lässt der Tweak bewusst aus, weil nicht belegt ist, ob er Spotlight mit abschaltet. Wirkt auf allen Editionen. Empfehlungen im Startmenü: 'Disable Recommended in Start Menu'."
        Category = "Windows"
        Group    = "Bloatware"
        Action   = {
            $cdm = "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
            foreach ($v in 'SoftLandingEnabled', 'FeatureManagementEnabled', 'PreInstalledAppsEverEnabled', 'RotatingLockScreenOverlayEnabled', 'SystemPaneSuggestionsEnabled',
                    'SubscribedContent-310093Enabled', 'SubscribedContent-338387Enabled', 'SubscribedContent-338389Enabled', 'SubscribedContent-338393Enabled',
                    'SubscribedContent-353694Enabled', 'SubscribedContent-353696Enabled') {
                reg add $cdm /v $v /t REG_DWORD /d 0 /f | Out-Null
            }
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" /v ScoobeSystemSettingEnabled /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_AccountNotifications /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowSyncProviderNotifications /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications" /v EnableAccountNotifications /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Tips, ads and suggestions disabled (ContentDeliveryManager, account notifications, sync provider ads)"
        }
    },
    [PSCustomObject]@{
        Name     = "Stop OneDrive Folder Backup"
        Desc     = "Verhindert per offizieller OneDrive-Richtlinie, dass OneDrive die Ordner Desktop, Dokumente und Bilder in die Cloud verschiebt ('Ordnersicherung') - auch nicht nach Nachfrage beim Einrichten. Wirkt auf allen Editionen. Schon gesicherte Ordner bleiben in OneDrive; zurückholen geht in OneDrive unter Einstellungen > Synchronisierung und Sicherung. Ohne installiertes OneDrive ändert sich nichts Sichtbares, die Richtlinie greift aber, falls OneDrive zurückkommt."
        Category = "Windows"
        Group    = "Bloatware"
        Action   = {
            reg add "HKLM\SOFTWARE\Policies\Microsoft\OneDrive" /v KFMBlockOptIn /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "OneDrive folder backup (Known Folder Move) blocked by policy"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Get Started & Copilot Sign-in Screens"
        Desc     = "Nur Windows Enterprise / Education: Die 'Get Started'-App startet nicht mehr automatisch, und die Einrichtungs-Werbung für Microsoft 365 Copilot bei der Anmeldung entfällt (diese zweite Richtlinie gibt es bisher nur in Insider-Builds). Home und Pro werten beide Richtlinien laut Microsoft nicht aus -- dort ändert der Tweak nichts und der Status bleibt grau. Copilot selbst bleibt nutzbar."
        Category = "Windows"
        Group    = "Bloatware"
        Action   = {
            if (-not (Test-EnterpriseEdition)) { Write-Log "Get Started / Copilot sign-in screens skipped: these policies only work on Enterprise / Education"; return }
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableGetStarted /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableCopilotPinScreen /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "Get Started and Microsoft 365 Copilot sign-in screens disabled (CloudContent policies)"
        }
    },

    # == WINDOWS / PRIVACY ================================================
    [PSCustomObject]@{
        Name     = "Disable Telemetry & Data Collection"
        Desc     = "Deaktiviert alle Windows-Telemetriedienste (DiagTrack, dmwappushservice). Windows sendet dann keine Nutzungsdaten mehr an Microsoft. Empfohlen für alle Nutzer."
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
        Desc     = "Deaktiviert die Werbe-ID die Windows jedem Nutzer zuweist. Apps können dich dann nicht mehr geräteübergreifend tracken um personalisierte Werbung zu schalten."
        Category = "Windows"
        Group    = "Privacy"
        Action   = {
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" /v DisabledByGroupPolicy /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "Advertising ID disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Text & Image Generation (AI)"
        Desc     = "Deaktiviert die geräteweite Text- und Bildgenerierung (on-device generative KI) für alle Apps per Gruppenrichtlinie (Force Deny). Betrifft nur die lokale KI auf dem Gerät, nicht Cloud-KI-Dienste."
        Category = "Windows"
        Group    = "Privacy"
        Action   = {
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsAccessSystemAIModels /t REG_DWORD /d 2 /f | Out-Null
            Write-Log "Text & Image Generation (on-device AI) disabled for all apps (Force Deny)"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Click to Do & Settings Agent (AI)"
        Desc     = "Schaltet 'Click to Do' ab (KI, die auf Tastendruck einen Screenshot macht und den Bildschirminhalt analysiert) sowie den KI-Agenten in der Suche der Einstellungen (neu in 26H2). Offizielle Microsoft-Richtlinien. Beide Funktionen laufen nur auf Copilot+ PCs mit NPU -- auf anderen PCs ist der Tweak harmlos. Hinweis: Click to Do wird auf allen Editionen abgeschaltet; die Settings-Agent-Richtlinie wertet Windows laut Microsoft nur auf Enterprise/Education aus - auf Home/Pro bleibt der Agent an."
        Category = "Windows"
        Group    = "Privacy"
        Action   = {
            # Official WindowsAI policies (WindowsCopilot.admx). DisableClickToDo exists
            # for machine AND user scope -- set both so a per-user default can't win.
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v DisableClickToDo /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKCU\Software\Policies\Microsoft\Windows\WindowsAI" /v DisableClickToDo /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v DisableSettingsAgent /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "Click to Do + Settings agent disabled (WindowsAI policies)"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable AI in Paint & Notepad"
        Desc     = "Deaktiviert die KI-Funktionen in Paint (Cocreator, Image Creator, generatives Füllen) und in Notepad (Umschreiben/Zusammenfassen per Copilot) über die offiziellen Microsoft-Richtlinien. Beide Apps bleiben ganz normal nutzbar."
        Category = "Windows"
        Group    = "Privacy"
        Action   = {
            $paint = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint"
            reg add $paint /v DisableCocreator      /t REG_DWORD /d 1 /f | Out-Null
            reg add $paint /v DisableImageCreator   /t REG_DWORD /d 1 /f | Out-Null
            reg add $paint /v DisableGenerativeFill /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\WindowsNotepad" /v DisableAIFeatures /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "AI features in Paint (Cocreator/Image Creator/Generative Fill) and Notepad disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Location Tracking"
        Desc     = "Deaktiviert den Windows Standortdienst systemweit. Apps können deinen Standort nicht mehr abfragen - gut für Datenschutz und leicht besser für Performance."
        Category = "Windows"
        Group    = "Privacy"
        Action   = {
            reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v Value /t REG_SZ /d Deny /f | Out-Null
            Stop-Service lfsvc -Force -ErrorAction SilentlyContinue
            Set-Service lfsvc -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Log "Location tracking disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Block Telemetry Hosts (hosts file)"
        Desc     = "Fügt Microsoft Telemetrie-Server in die Windows hosts-Datei ein und blockt sie. Damit können diese Server nicht mehr erreicht werden - auch wenn Telemetry-Services laufen sollten. Hinweis: Microsoft Defender meldet solche Einträge als 'HostsFileHijack' und kann sie wieder entfernen - der Status zeigt das dann an."
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
            $existing  = @()
            if (Test-Path $hostsFile) { $existing = @(Get-Content $hostsFile -ErrorAction Stop) }   # unreadable -> stop, never overwrite blind
            $trimmed   = @($existing | ForEach-Object { $_.Trim() })
            $toAdd     = @($hosts | Where-Object { $trimmed -notcontains $_ })
            if ($toAdd.Count) {
                # Rewrite line by line instead of appending: Add-Content glued the first entry
                # onto the last line when the file didn't end with a line break. Default
                # (ANSI) keeps the bytes of the existing lines.
                try { Set-Content $hostsFile (@($existing) + $toAdd) -Encoding Default -ErrorAction Stop }
                catch { throw "hosts file could not be written (read-only, or locked by an antivirus): $($_.Exception.Message)" }
            }
            Write-Log "Telemetry hosts blocked ($($toAdd.Count) added)"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Scheduled Telemetry Tasks"
        Desc     = "Deaktiviert die geplanten Windows-Aufgaben, die Telemetrie- und Nutzungsdaten sammeln und senden: Kompatibilitäts-Appraiser und die übrigen Kompatibilitäts-Aufgaben (MareBackup, PcaPatchDbTask, StartupAppTask), Programm zur Verbesserung der Benutzerfreundlichkeit (CEIP), Datenträger-Diagnose, Feedback-Abfragen, das Hochladen gesammelter Fehlerberichte und die Energieeffizienz-Analyse. Aufgaben, die es auf diesem Windows nicht gibt, werden übersprungen. Ein großes Windows-Update kann einzelne wieder einschalten - die Drift-Prüfung meldet das."
        Category = "Windows"
        Group    = "Privacy"
        Action   = {
            # Tasks this Windows doesn't have are skipped (schtasks only returns an error code)
            foreach ($task in (Get-TelemetryTasks)) { schtasks /Change /TN $task /Disable 2>$null | Out-Null }
            Write-Log "Telemetry tasks disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Input & Speech Data Collection"
        Desc     = "Schaltet die Datensammlung bei Eingabe und Sprache ab, wie unter Einstellungen > Datenschutz: Online-Spracherkennung, Freihand- und Eingabe-Personalisierung (Windows lernt nicht mehr aus deinem Tippen, Schreiben und deinen Kontakten), 'Freihand- und Eingabeerkennung verbessern', maßgeschneiderte Erfahrungen mit Diagnosedaten und Feedback-Abfragen (Häufigkeit 'Nie', ab Pro zusätzlich per Richtlinie). Websites können deine Sprachliste nicht mehr lesen, und Windows merkt sich nicht mehr, welche Apps du startest - dadurch bleibt 'Meistverwendet' im Startmenü leer. Diktieren mit Win+H kann ohne Online-Spracherkennung eingeschränkt sein. Wirkt auf allen Editionen."
        Category = "Windows"
        Group    = "Privacy"
        Action   = {
            reg add "HKCU\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy" /v HasAccepted /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKCU\Software\Microsoft\InputPersonalization" /v RestrictImplicitTextCollection /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKCU\Software\Microsoft\InputPersonalization" /v RestrictImplicitInkCollection /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKCU\Software\Microsoft\InputPersonalization\TrainedDataStore" /v HarvestContacts /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKCU\Software\Microsoft\Input\TIPC" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy" /v TailoredExperiencesWithDiagnosticDataEnabled /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKCU\Software\Microsoft\Siuf\Rules" /v NumberOfSIUFInPeriod /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_TrackProgs /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKCU\Control Panel\International\User Profile" /v HttpAcceptLanguageOptOut /t REG_DWORD /d 1 /f | Out-Null
            # The feedback policy is read from Pro upwards (Policy CSP Experience); Home uses the frequency above
            if (-not (Test-HomeEdition)) { reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v DoNotShowFeedbackNotifications /t REG_DWORD /d 1 /f | Out-Null }
            Write-Log "Input, inking and speech data collection disabled (speech, personalization, tailored experiences, feedback, app-launch tracking, language list)"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Remote Assistance"
        Desc     = "Schaltet die Windows-Remoteunterstützung ab (Systemeigenschaften > Remote: 'Remoteunterstützungsverbindungen mit diesem Computer zulassen'). Niemand kann sich dann per Einladung auf deinen PC schalten. Remotedesktop, die App 'Remotehilfe' (Quick Assist) und Programme wie AnyDesk oder TeamViewer sind nicht betroffen. Wirkt auf allen Editionen."
        Category = "Windows"
        Group    = "Privacy"
        Action   = {
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\Remote Assistance" /v fAllowToGetHelp /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Remote Assistance disabled"
        }
    },

    # == WINDOWS / PERFORMANCE ============================================
    [PSCustomObject]@{
        Name     = "Ultimate Performance Plan"
        Desc     = "Aktiviert den 'Ultimative Leistung' Energiesparplan und stellt ihn auf 'immer an': die CPU drosselt nicht mehr runter UND der PC geht nicht mehr in den Ruhemodus - Monitor, Festplatten und System bleiben an (kein Timeout). Maximale Performance zu jeder Zeit. Erhöht den Stromverbrauch."
        Category = "Windows"
        Group    = "Performance"
        Action   = {
            # Reuse an existing Ultimate Performance plan instead of duplicating a
            # fresh one on every run -- otherwise each apply piles up another
            # identical "Ultimative Leistung" scheme. Order: our stored GUID, then
            # any Ultimate plan already present; only create one if none exists.
            # GUIDs matched by pattern -> locale-independent.
            $rx       = "([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})"
            $existing = powercfg -list 2>$null
            $stored   = Get-RegVal "HKLM:\SOFTWARE\GameOptimizerPro" "UltimatePerfGuid"
            $guid     = $null
            if ($stored -and (($existing -join " ") -match [regex]::Escape($stored))) {
                $guid = $stored
            } else {
                $line = $existing | Select-String "Ultimate Performance|Ultimative Leistung" | Select-Object -First 1
                if ($line -and $line.ToString() -match $rx) { $guid = $matches[1] }
            }
            if (-not $guid) {
                # None present yet -- create exactly one.
                $out = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
                if (($out -join " ") -match $rx) { $guid = $matches[1] }
            }
            if ($guid) {
                # "Ultimate Performance" = a true always-on desktop plan: never sleep,
                # never turn off the display or disks, no hibernate timeout -- set on
                # THIS plan only (AC + DC). This is what users expect from "max power".
                foreach ($s in @(@("SUB_SLEEP","STANDBYIDLE"), @("SUB_SLEEP","HIBERNATEIDLE"), @("SUB_VIDEO","VIDEOIDLE"), @("SUB_DISK","DISKIDLE"))) {
                    powercfg /SETACVALUEINDEX $guid $s[0] $s[1] 0 2>$null | Out-Null
                    powercfg /SETDCVALUEINDEX $guid $s[0] $s[1] 0 2>$null | Out-Null
                }
                powercfg -setactive $guid 2>$null
                # Remember the activated GUID so the status check works locale-independently
                reg add "HKLM\SOFTWARE\GameOptimizerPro" /v UltimatePerfGuid /t REG_SZ /d $guid /f | Out-Null
                # Clean up EXTRA Ultimate-Performance duplicates from earlier runs (keep
                # the active one). Only touches Ultimate copies -- never Balanced/High
                # Performance/Power Saver, and never the active scheme.
                foreach ($l in ($existing | Select-String "Ultimate Performance|Ultimative Leistung")) {
                    if (($l.ToString() -match $rx) -and ($matches[1] -ne $guid)) { powercfg -delete $matches[1] 2>$null | Out-Null }
                }
                Write-Log "Ultimate Performance Plan activated + never sleep/display-off (GUID: $guid)"
            } else {
                Write-Log "Ultimate Performance Plan: could not create or locate the plan"
            }
        }
    },
    [PSCustomObject]@{
        Name     = "Disable HPET (High Precision Event Timer)"
        Desc     = "Deaktiviert den High Precision Event Timer. Kann die System-Latenz reduzieren und Gaming-Performance verbessern. Auf manchen Systemen sorgt dies für niedrigere Frame-Zeiten."
        Category = "Windows"
        Group    = "Performance"
        Action   = {
            bcdedit /deletevalue useplatformclock 2>$null | Out-Null
            # bcdedit is an .exe: a refusal (Secure Boot / BitLocker policy) is only an exit
            # code, never an exception -- check it, so the Apply reports it as failed.
            foreach ($opt in 'useplatformtick', 'disabledynamictick') {
                $out = bcdedit /set $opt yes 2>&1
                if ($LASTEXITCODE -ne 0) { throw "bcdedit /set $opt failed: $(($out | Out-String).Trim())" }
            }
            Write-Log "HPET disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Allow Global Timer Resolution (Windows 11)"
        Desc     = "Seit Windows 10 2004 gilt eine erhöhte Timer-Auflösung nur noch für das Programm, das sie anfordert - unter Windows 11 nicht einmal, solange es minimiert ist. Das stellt das alte, systemweite Verhalten wieder her. Voraussetzung für Timer-Tools wie TimerResolution oder ISLC; stellt selbst KEINE Auflösung ein - Spiele fordern ihre ca. 1 ms ohnehin selbst an. Neustart nötig."
        Category = "Windows"
        Group    = "Performance"
        Action   = {
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v GlobalTimerResolutionRequests /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "Global timer resolution requests allowed (takes effect after a restart)"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Prefetch & Superfetch"
        Desc     = "Deaktiviert Prefetch und SysMain (Superfetch). Sinnvoll bei SSDs - auf HDDs nicht empfohlen. Reduziert Hintergrund-Schreibzugriffe und leichten RAM-Verbrauch."
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
        Desc     = "Schaltet die Windows-Animationen und visuellen Effekte aus wie 'Fuer optimale Leistung anpassen' (Systemeigenschaften > Leistungsoptionen): Fenster-, Menü- und Taskleisten-Animationen, Ein- und Ausblenden, Schatten unter Fenstern und Mauszeiger, Fensterinhalt beim Ziehen, durchsichtiges Auswahlrechteck und Symbolschatten. Die Kantenglättung der Schrift (ClearType) bleibt an, damit Text scharf bleibt. Vollständig wirksam nach Ab- und wieder Anmelden. Windows reagiert dadurch spürbar direkter - besonders auf schwächeren Systemen."
        Category = "Windows"
        Group    = "Performance"
        Action   = {
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 2 /f | Out-Null
            $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
            Set-ItemProperty $path -Name "TaskbarAnimations" -Value 0
            reg add "HKCU\Control Panel\Desktop\WindowMetrics" /v MinAnimate /t REG_SZ /d 0 /f | Out-Null
            # The single effects: VisualFXSetting alone only moves the radio button. The mask is the
            # "best performance" set (90 12 03 80 10 ...); FontSmoothing (ClearType) is left on.
            reg add "HKCU\Control Panel\Desktop" /v UserPreferencesMask /t REG_BINARY /d 9012038010000000 /f | Out-Null
            reg add "HKCU\Control Panel\Desktop" /v DragFullWindows /t REG_SZ /d 0 /f | Out-Null
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ListviewAlphaSelect /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ListviewShadow /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Visual effects set to performance mode (takes full effect after signing out and in)"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Startup App Delay"
        Desc     = "Windows startet Autostart-Programme nach der Anmeldung erst mit einigen Sekunden Verzögerung. Mit diesem Tweak starten sie sofort - Discord, Steam und Co. sind schneller da, dafür ist der Desktop in den ersten Sekunden etwas träger. Nicht offiziell dokumentiert, aber bis Windows 11 26H2 von Nutzern bestätigt; ein großes Windows-Update kann den Wert entfernen (die Drift-Prüfung meldet das). Wirkt auf allen Editionen."
        Category = "Windows"
        Group    = "Performance"
        Action   = {
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize" /v StartupDelayInMSec /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Startup app delay disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Windows Search Indexing"
        Desc     = "Deaktiviert den Windows Search Indexer (WSearch). Reduziert ständige Festplattenzugriffe im Hintergrund. Suche in Explorer funktioniert weiterhin, aber langsamer ohne Index."
        Category = "Windows"
        Group    = "Performance"
        Action   = {
            Stop-Service WSearch -Force -ErrorAction SilentlyContinue
            Set-Service WSearch -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Log "Windows Search Indexing disabled"
        }
    },

    # == WINDOWS / MOUSE & UI =============================================

    [PSCustomObject]@{
        Name     = "Disable Power Throttling"
        Desc     = "Verhindert dass Windows Prozesse zur Energieeinsparung drosselt (EcoQoS). Nützlich bei Spielen mit mehreren Prozessen -- Hintergrundprozesse des Spiels werden nicht mehr gedrosselt."
        Category = "Windows"
        Group    = "Performance"
        Action   = {
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" /v PowerThrottlingOff /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "Power Throttling disabled (EcoQoS off)"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Bing in Windows Search"
        Desc     = "Deaktiviert die Bing-Integration in der Windows-Suche. Das Startmenü sucht nur noch lokal -- schneller, kein Datenaustausch mit Microsoft bei jeder Suche. Außerdem aus: die Suchhighlights (wechselnde Bilder und Themen im Suchfeld) und die Cloud-Inhaltssuche in OneDrive, Outlook und Bing für Microsoft- und Arbeits-/Schulkonten (Einstellungen > Datenschutz > Suchberechtigungen)."
        Category = "Windows"
        Group    = "Performance"
        Action   = {
            reg add "HKCU\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v DisableSearchBoxSuggestions /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v BingSearchEnabled /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v CortanaConsent /t REG_DWORD /d 0 /f | Out-Null
            $ss = "HKCU\Software\Microsoft\Windows\CurrentVersion\SearchSettings"
            reg add $ss /v IsDynamicSearchBoxEnabled /t REG_DWORD /d 0 /f | Out-Null
            reg add $ss /v IsMSACloudSearchEnabled /t REG_DWORD /d 0 /f | Out-Null
            reg add $ss /v IsAADCloudSearchEnabled /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Bing in Windows Search disabled (plus search highlights and cloud content search)"
        }
    },
    [PSCustomObject]@{
        Name     = "Process Count Reduction (Svchost)"
        Desc     = "Setzt den Svchost-Split-Schwellwert auf die RAM-Größe. Windows teilt Dienste in weniger separate Prozesse auf -- reduziert Hintergrundprozesse spürbar. WARNUNG: Reduziert die Prozess-Isolation -- stürzt ein Dienst ab, kann er andere im selben Host (Audio, Netzwerk etc.) mitreißen. Reboot empfohlen."
        Category = "Windows"
        Group    = "Performance"
        Action   = {
            $ramKB = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1024)
            reg add "HKLM\SYSTEM\CurrentControlSet\Control" /v SvcHostSplitThresholdInKB /t REG_DWORD /d $ramKB /f | Out-Null
            Write-Log ("Svchost split threshold set to " + [math]::Round($ramKB/1024) + " MB (RAM size)")
        }
    },
    [PSCustomObject]@{
        Name     = "Block Background Apps (Policy)"
        Desc     = "Nur ab Windows Pro: Store-Apps (z.B. WhatsApp, Smartphone-Link, Mail, Wetter) dürfen per offizieller Richtlinie nicht mehr im Hintergrund laufen - spart RAM und Hintergrundlast. ACHTUNG: Ihre Benachrichtigungen (z.B. neue WhatsApp-Nachrichten oder SMS über Smartphone-Link) kommen dann erst, wenn die App offen ist. Normale Programme (Steam, Discord, Treiber-Tools) sind nicht betroffen. Unter Home wertet Windows die Richtlinie nicht aus - dort ist der Tweak ausgegraut."
        Category = "Windows"
        Group    = "Performance"
        Action   = {
            if (Test-HomeEdition) { Write-Log "Background apps policy skipped: Windows Home doesn't read it"; return }
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsRunInBackground /t REG_DWORD /d 2 /f | Out-Null
            Write-Log "Store apps blocked from running in the background (LetAppsRunInBackground = Force Deny)"
        }
    },
    [PSCustomObject]@{
        Name     = "Stop Background Apps (All Editions)"
        Desc     = "Store-Apps (z.B. WhatsApp, Smartphone-Link, Mail, Wetter) dürfen für dein Benutzerkonto nicht mehr im Hintergrund laufen - der alte Schalter 'Apps im Hintergrund ausführen', den Windows 11 nicht mehr anzeigt (dort gibt es sonst nur die Einstellung pro App). Wirkt auf allen Editionen, auch Home; ab Pro geht dasselbe per Richtlinie mit 'Block Background Apps (Policy)'. ACHTUNG: Benachrichtigungen dieser Apps (z.B. neue WhatsApp-Nachrichten) kommen erst, wenn die App offen ist. Normale Programme (Steam, Discord, Treiber-Tools) sind nicht betroffen. Wirkt nach Ab- und Anmelden."
        Category = "Windows"
        Group    = "Performance"
        Action   = {
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "Store apps stopped from running in the background (this user account)"
        }
    },

    # == WINDOWS / WINDOWS UPDATE ===========================================
    [PSCustomObject]@{
        Name     = "Exclude Drivers from Windows Update"
        Desc     = "Nur ab Windows Pro: Windows Update installiert keine Treiber mehr (offizielle Richtlinie 'Treiber nicht in Windows-Updates einschließen'). Verhindert, dass Windows z.B. deinen frisch installierten Grafiktreiber durch eine ältere Version ersetzt. Treiber holst du dann selbst beim Hersteller (NVIDIA App, AMD Software, Mainboard-Seite). Sicherheits- und Funktionsupdates kommen weiter. Unter Home wirkungslos - dort ausgegraut."
        Category = "Windows"
        Group    = "Windows Update"
        Action   = {
            if (Test-HomeEdition) { Write-Log "Driver exclusion skipped: Windows Home doesn't read this policy"; return }
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v ExcludeWUDriversInQualityUpdate /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "Windows Update no longer installs drivers"
        }
    },
    [PSCustomObject]@{
        Name     = "Hold Feature Updates (Stay on Current Version)"
        Desc     = "Nur ab Windows Pro: Hält Windows auf der installierten Version fest (z.B. 26H2) - das nächste große Funktionsupdate wird nicht automatisch installiert. Die monatlichen Sicherheitsupdates kommen weiter. Die Version wird beim Anwenden ausgelesen, nicht fest eingetragen. Wichtig: Jede Windows-Version bekommt nur begrenzt Updates (Home und Pro 24 Monate) - rechtzeitig zurücksetzen, damit du nicht ohne Sicherheitsupdates dastehst. Unter Home wirkungslos - dort ausgegraut."
        Category = "Windows"
        Group    = "Windows Update"
        Action   = {
            if (Test-HomeEdition) { Write-Log "Feature update hold skipped: Windows Home doesn't read this policy"; return }
            # read only -- the version is never hard-coded
            $ver = Get-RegVal "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" "DisplayVersion"
            if (-not $ver) { throw "the installed Windows version (DisplayVersion) could not be read" }
            $prod = if ([int](Get-RegVal "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" "CurrentBuildNumber") -ge 22000) { "Windows 11" } else { "Windows 10" }
            $wu = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
            reg add $wu /v TargetReleaseVersion /t REG_DWORD /d 1 /f | Out-Null
            reg add $wu /v ProductVersion /t REG_SZ /d $prod /f | Out-Null
            reg add $wu /v TargetReleaseVersionInfo /t REG_SZ /d $ver /f | Out-Null
            Write-Log "Feature updates held at $prod $ver (security updates continue)"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Automatic Windows Updates"
        Desc     = "Windows lädt und installiert Updates nicht mehr von selbst - auch keine Sicherheitsupdates. Sie kommen nur noch, wenn du unter Einstellungen > Windows Update selbst auf 'Nach Updates suchen' klickst. Dazu Nutzungszeiten von 8 bis 2 Uhr (in dieser Zeit kein automatischer Neustart). Verhindert Downloads und Neustarts beim Spielen, aber: Wer nicht regelmäßig selbst nach Updates sucht, bleibt ohne Sicherheitsupdates. Wer nur keine Neustarts beim Spielen will, stellt besser nur die Nutzungszeiten ein (Einstellungen > Windows Update > Erweiterte Optionen). In keinem Preset."
        Category = "Windows"
        Group    = "Windows Update"
        Action   = {
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /t REG_DWORD /d 2 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v SetActiveHours /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v ActiveHoursStart /t REG_DWORD /d 8 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v ActiveHoursEnd /t REG_DWORD /d 2 /f | Out-Null
            Write-Log "Automatic Windows Updates disabled (updates only when you check yourself, active hours 8-2)"
        }
    },

    # == WINDOWS / CTT ESSENTIALS (parity with Chris Titus Tech WinUtil) ===
    [PSCustomObject]@{
        Name     = "Prevent Device Companion Apps"
        Desc     = "Verhindert, dass Windows Geräte-Metadaten aus dem Netzwerk lädt und automatisch Companion-Apps für angeschlossene Geräte installiert oder vorschlägt. Spart Hintergrund-Traffic und ungewollte App-Installationen."
        Category = "Windows"
        Group    = "CTT Essentials"
        Action   = {
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Device Metadata" /v PreventDeviceMetadataFromNetwork /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "Prevent Device Companion Apps enabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Consumer Features"
        Desc     = "Nur Windows Enterprise / Education: Setzt die offizielle Richtlinie 'Turn off Microsoft consumer experiences' (1:1 aus WinUtil). Home und Pro werten sie laut Microsoft nicht aus -- dort ist der Tweak ausgegraut; dort stoppt 'Stop Auto-Installed Suggested Apps' (Tab Windows, Bloatware) das automatische Nachinstallieren von Vorschlags-Apps."
        Category = "Windows"
        Group    = "CTT Essentials"
        Action   = {
            if (-not (Test-EnterpriseEdition)) { Write-Log "Consumer features policy skipped: only Enterprise / Education read it"; return }
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "Windows Consumer Features disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Windows Platform Binary Table (WPBT)"
        Desc     = "Deaktiviert die Ausführung der Windows Platform Binary Table. Verhindert, dass Mainboard-/OEM-Firmware bei jedem Start heimlich Programme in Windows einschleust. Reiner Sicherheits-Tweak."
        Category = "Windows"
        Group    = "CTT Essentials"
        Action   = {
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v DisableWpbtExecution /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "WPBT execution disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Store Recommended Search Results"
        Desc     = "Sperrt die store.db der Microsoft Store App per Dateiberechtigung. Der Store zeigt dann keine empfohlenen/gesponserten Suchergebnisse mehr an. Vollständig reversibel."
        Category = "Windows"
        Group    = "CTT Essentials"
        Action   = {
            $storeDb = "$env:LocalAppData\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalState\store.db"
            if (Test-Path $storeDb) {
                icacls "$storeDb" /deny "*S-1-1-0:F" 2>$null | Out-Null
                Write-Log "Store recommended search results disabled (store.db locked)"
            } else {
                Write-Log "Store search tweak skipped: store.db not found"
            }
        }
    },
    [PSCustomObject]@{
        Name     = "Disable File Explorer Automatic Folder Discovery"
        Desc     = "Setzt alle Ordner auf 'Allgemeine Elemente'. Der Explorer verschwendet dann keine Zeit mehr damit, Ordnertypen automatisch zu erkennen -- öffnet große Ordner deutlich schneller. Abmelden/Neustart nötig."
        Category = "Windows"
        Group    = "CTT Essentials"
        Action   = {
            $bags   = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags"
            $bagMRU = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\BagMRU"
            Remove-Item -Path $bags   -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $bagMRU -Recurse -Force -ErrorAction SilentlyContinue
            $allFolders = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell"
            if (-not (Test-Path $allFolders)) { New-Item -Path $allFolders -Force | Out-Null }
            New-ItemProperty -Path $allFolders -Name "FolderType" -Value "NotSpecified" -PropertyType String -Force | Out-Null
            Write-Log "File Explorer automatic folder discovery disabled (all folders = General)"
        }
    },
    [PSCustomObject]@{
        Name     = "Run Disk Cleanup"
        Desc     = "Führt die Windows-Datenträgerbereinigung automatisch aus (cleanmgr /VERYLOWDISK) und räumt zusätzlich alte Windows-Update-Komponenten per DISM auf. Einmalige Aktion, kann 5-15 Minuten dauern - das Fenster bleibt dabei bedienbar, die Statusleiste zählt die Sekunden mit."
        Category = "Windows"
        Group    = "CTT Essentials"
        Action   = {
            # cleanmgr shows its result dialog at the end -- keep its window visible, or it waits forever
            $c = Invoke-ProcessWithUi "cleanmgr.exe" "/d C: /VERYLOWDISK" "Disk Cleanup (cleanmgr)" 1800 -Visible
            $d = Invoke-ProcessWithUi "Dism.exe" "/online /Cleanup-Image /StartComponentCleanup /ResetBase" "Component cleanup (DISM)" 3600
            Write-Log "Disk Cleanup executed (cleanmgr exit $c, DISM exit $d$(if ($d -eq 3010) { ' -- restart needed' }))"
        }
    },

    # == WINDOWS / QUALITY OF LIFE (CTT WinUtil parity) ===================
    [PSCustomObject]@{
        Name     = "Show File Extensions"
        Desc     = "Blendet Dateiendungen im Explorer ein (z.B. .exe, .txt, .jpg). Wichtig für Sicherheit -- getarnte Dateien wie 'foto.jpg.exe' werden so sofort erkennbar."
        Category = "Windows"
        Group    = "Quality of Life"
        Action   = {
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "File extensions shown in Explorer"
        }
    },
    [PSCustomObject]@{
        Name     = "Show Hidden Files"
        Desc     = "Zeigt versteckte Dateien und Ordner im Explorer an. Nützlich um AppData, Config-Dateien und versteckte Ordner zu sehen."
        Category = "Windows"
        Group    = "Quality of Life"
        Action   = {
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Hidden /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "Hidden files shown in Explorer"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Reserved Storage"
        Desc     = "Deaktiviert den reservierten Speicher, den Windows für Updates zurücklegt (~7 GB). Gibt den Platz auf der Systemplatte frei. Windows verwaltet Updates danach dynamisch."
        Category = "Windows"
        Group    = "Quality of Life"
        Action   = {
            try { Set-WindowsReservedStorageState -State Disabled -ErrorAction Stop; Write-Log "Reserved storage disabled (~7 GB freed)" }
            catch { Write-Log "Reserved storage could not be disabled: $($_.Exception.Message)" }
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Storage Sense"
        Desc     = "Deaktiviert Storage Sense (automatische Speicherbereinigung). Windows löscht dann nicht mehr eigenmächtig temporäre Dateien oder Papierkorb-Inhalte -- du behältst die volle Kontrolle."
        Category = "Windows"
        Group    = "Quality of Life"
        Action   = {
            reg add "HKLM\Software\Policies\Microsoft\Windows\StorageSense" /v AllowStorageSenseGlobal /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Storage Sense disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Num Lock on Startup"
        Desc     = "Aktiviert NumLock automatisch beim Systemstart und am Login-Bildschirm. Praktisch, wenn du den Ziffernblock direkt nutzen willst."
        Category = "Windows"
        Group    = "Quality of Life"
        Action   = {
            reg add "HKCU\Control Panel\Keyboard" /v InitialKeyboardIndicators /t REG_SZ /d 2147483650 /f | Out-Null
            reg add "HKU\.DEFAULT\Control Panel\Keyboard" /v InitialKeyboardIndicators /t REG_SZ /d 2147483650 /f | Out-Null
            Write-Log "NumLock enabled on startup"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Lock Screen"
        Desc     = "Deaktiviert den Sperrbildschirm. Beim Start/Aufwachen geht es direkt zum Login-Feld -- spart einen Klick bzw. Wisch."
        Category = "Windows"
        Group    = "Quality of Life"
        Action   = {
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization" /v NoLockScreen /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "Lock screen disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Enable Long Paths"
        Desc     = "Aktiviert Pfade länger als 260 Zeichen. Hilfreich bei tiefen Ordnerstrukturen, Game-Mods, Node-Projekten usw. -- verhindert 'Pfad zu lang'-Fehler."
        Category = "Windows"
        Group    = "Quality of Life"
        Action   = {
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v LongPathsEnabled /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "Long paths enabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Mouse Acceleration"
        Desc     = "Deaktiviert die Mausbeschleunigung (Enhance Pointer Precision). Wichtig für FPS-Spiele: Deine Mausbewegung wird 1:1 übertragen ohne dynamische Verstärkung."
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
        Desc     = "Deaktiviert den Sticky Keys Dialog (der beim 5x Shift-Drücken aufpoppt). Verhindert ungewollte Unterbrechungen mitten im Spiel."
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
        Desc     = "Aktiviert den dunklen Modus für Windows und Apps systemweit. Schont die Augen bei langen Sessions - besonders nachts beim Gaming."
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
        Desc     = "Deaktiviert die Transparenz-Effekte in Taskleiste und Startmenü. Spart GPU-Ressourcen und reduziert leicht den RAM-Verbrauch."
        Category = "Windows"
        Group    = "Mouse & UI"
        Action   = {
            reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Transparency disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Alt+Tab Without Browser Tabs"
        Desc     = "Alt+Tab zeigt nur noch Fenster, keine einzelnen Edge-Tabs mehr (Einstellungen > System > Multitasking > 'Registerkarten aus Apps anzeigen': keine). Wirkt auf allen Editionen."
        Category = "Windows"
        Group    = "Mouse & UI"
        Action   = {
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v MultiTaskingAltTabFilter /t REG_DWORD /d 3 /f | Out-Null
            Write-Log "Alt+Tab shows windows only (no browser tabs)"
        }
    },

    # == GAMING / IN-GAME BOOSTS ==========================================
    [PSCustomObject]@{
        Name     = "Enable Game Mode"
        Desc     = "Aktiviert den Windows Game Mode. Windows priorisiert dann CPU/GPU-Ressourcen für das aktive Spiel und unterdrückt Windows Update Neustarts während du spielst."
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
        Desc     = "Deaktiviert die Xbox Game Bar (Win+G Overlay). Verhindert dass die Game Bar im Hintergrund läuft und Ressourcen verbraucht. Die Xbox-Taste am Controller öffnet die Game Bar nicht mehr. Game Mode bleibt davon unberührt."
        Category = "Gaming"
        Group    = "In-Game Boosts"
        Action   = {
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v AllowGameDVR /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKCU\Software\Microsoft\GameBar" /v UseNexusForGameBarEnabled /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Xbox Game Bar disabled (incl. the controller's Xbox button)"
        }
    },
    [PSCustomObject]@{
        Name     = "CPU Priority for Games (Win32Priority)"
        Desc     = "Setzt Win32PrioritySeparation auf 26 (Hex). Windows gibt dann aktiven Spielen deutlich mehr CPU-Zeit und reduziert Hintergrundprozesse. Spuerbar bei CPU-limitierten Spielen."
        Category = "Gaming"
        Group    = "In-Game Boosts"
        Action   = {
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v Win32PrioritySeparation /t REG_DWORD /d 26 /f | Out-Null
            Write-Log "CPU Priority set for gaming"
        }
    },
    [PSCustomObject]@{
        Name     = "MMCSS Gaming Profile (High Priority)"
        Desc     = "Setzt die Multimedia Class Scheduler Service (MMCSS) Profile für Spiele auf High Priority. Windows priorisiert dann Audio und Timer-Interrupts für besseres Gaming-Erlebnis."
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
        Desc     = "Deaktiviert die Windows Fullscreen Optimizations global. Manche Spiele laufen im 'Borderless Windowed' statt echtem Fullscreen - dieser Tweak erzwingt echtes Fullscreen für niedrigeren Input-Lag."
        Category = "Gaming"
        Group    = "In-Game Boosts"
        Action   = {
            reg add "HKCU\System\GameConfigStore" /v GameDVR_FSEBehaviorMode /t REG_DWORD /d 2 /f | Out-Null
            reg add "HKCU\System\GameConfigStore" /v GameDVR_HonorUserFSEBehaviorMode /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKCU\System\GameConfigStore" /v GameDVR_FSEBehavior /t REG_DWORD /d 2 /f | Out-Null
            Write-Log "Fullscreen Optimizations disabled"
        }
    },

    # == GAMING / GPU & DRIVER ============================================
    [PSCustomObject]@{
        Name     = "Enable MSI Mode (Message Signaled Interrupts)"
        Desc     = "Aktiviert MSI-Modus (Message Signaled Interrupts) für die primäre GPU. Reduziert Interrupt-Latenz erheblich. Standard-Windows nutzt Line-Based Interrupts - MSI ist moderner und schneller. Reboot empfohlen."
        Category = "Gaming"
        Group    = "GPU & Driver"
        Action   = {
            $gpuDev = $Script:GpuObj   # the gaming GPU (see Select-PrimaryGpu), not just the first adapter
            if ($gpuDev) {
                $pnpId   = $gpuDev.PNPDeviceID
                $regPath = "HKLM\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
                reg add "$regPath" /v MSISupported /t REG_DWORD /d 1 /f | Out-Null
                Write-Log "MSI Mode enabled for: $($gpuDev.Name)"
            }
        }
    },
    [PSCustomObject]@{
        Name     = "Enable Hardware-Accelerated GPU Scheduling (HAGS)"
        Desc     = "Aktiviert HAGS - Windows übergibt das GPU-Scheduling direkt an die Hardware statt an die Software. Reduziert CPU-Overhead und leicht den Input-Lag. Erfordert NVIDIA RTX 2000+ oder AMD RX 5000+ und Windows 10 2004+. Auf aktuellen Windows-11-PCs meist schon an; DLSS Frame Generation braucht es. Revert stellt den Zustand von vorher wieder her."
        Category = "Gaming"
        Group    = "GPU & Driver"
        Action   = {
            # Remember what was set before (once), so the revert puts exactly that back (0 = no value)
            if ($null -eq (Get-RegVal "HKLM:\SOFTWARE\GameOptimizerPro" "HwSchModeBefore")) {
                $cur = Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode"
                reg add "HKLM\SOFTWARE\GameOptimizerPro" /v HwSchModeBefore /t REG_DWORD /d $(if ($null -eq $cur) { 0 } else { [int]$cur }) /f | Out-Null
            }
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v HwSchMode /t REG_DWORD /d 2 /f | Out-Null
            Write-Log "HAGS enabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Clear Shader Cache"
        Desc     = "Leert den NVIDIA bzw. AMD Shader-Cache auf der Festplatte. Erzwingt beim nächsten Spielstart eine frische Kompilierung der Shader. Sinnvoll nach Treiberupdates oder bei Grafikfehlern."
        Category = "Gaming"
        Group    = "GPU & Driver"
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
    [PSCustomObject]@{
        Name     = "Increase GPU Timeout Tolerance (TDR)"
        Desc     = "Erhöht die GPU-Timeout-Toleranz (TDR-Delay von 2s auf 10s). Windows setzt den Grafiktreiber dann nicht mehr vorschnell zurück, wenn die GPU unter Volllast kurz nicht antwortet -- reduziert Blackscreens/Treiber-Resets in fordernden Spielen und beim Übertakten. Hinweis: erhoeht nicht die FPS, sondern die Stabilität."
        Category = "Gaming"
        Group    = "GPU & Driver"
        Action   = {
            # Raise the GPU timeout (TDR) delay so Windows doesn't reset the driver
            # prematurely under heavy load. NOTE: the old D3D12_* values under
            # HKLM\SOFTWARE\Microsoft\DirectX were removed -- the D3D12 runtime never
            # read them (those names are process env-vars, not registry keys).
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v TdrDelay /t REG_DWORD /d 10 /f | Out-Null
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v TdrDdiDelay /t REG_DWORD /d 10 /f | Out-Null
            Write-Log "GPU TDR timeout raised (TdrDelay/TdrDdiDelay = 10s)"
        }
    },

    # == NETWORK / LATENCY ================================================
    [PSCustomObject]@{
        Name     = "Disable Nagle's Algorithm (TCPNoDelay)"
        Desc     = "Deaktiviert Nagles Algorithmus auf allen Netzwerkadaptern. Nagle bündelt kleine Datenpakete um Effizienz zu steigern - auf Kosten von Latenz. Deaktivieren senkt Ping in Online-Spielen spürbar."
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
        Desc     = "Deaktiviert Large Send Offload auf allen aktiven Netzwerkadaptern. LSO kann auf manchen Systemen zu Ping-Spikes führen. Deaktivieren hilft bei instabilem Ping in Online-Spielen."
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
        Desc     = "Deaktiviert den Windows Network Throttling Index, der Netzwerkpakete bei hoher CPU-Last drosselt. Besonders wirksam bei latenzsensitivem Gaming, wenn die CPU ausgelastet ist. Setzt dazu SystemResponsiveness auf 10 (der kleinste Wert, den Windows annimmt; kleinere Werte behandelt Windows wie 20)."
        Category = "Network"
        Group    = "Latency"
        Action   = {
            reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v NetworkThrottlingIndex /t REG_DWORD /d 0xffffffff /f | Out-Null
            # 10, not 0: Windows treats values below 10 as 20 (= its default) -- Microsoft, MMCSS docs
            reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v SystemResponsiveness /t REG_DWORD /d 10 /f | Out-Null
            # Ownership marker for the shared SystemResponsiveness value (see reverts)
            reg add "HKLM\SOFTWARE\GameOptimizerPro" /v SR_NetworkThrottle /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "Network Throttling Index disabled"
        }
    },

    # == NETWORK / DNS ====================================================
    [PSCustomObject]@{
        Name     = "Set DNS to Cloudflare (1.1.1.1)"
        Desc     = "Setzt den DNS-Server auf Cloudflare 1.1.1.1 / 1.0.0.1 (IPv4) plus die passenden IPv6-Server (2606:4700:4700::1111/::1001), damit auch IPv6-Anfragen über Cloudflare laufen. Einer der schnellsten und datenschutzfreundlichsten DNS-Anbieter weltweit. Revert bringt die DNS-Server zurück, die vorher eingestellt waren (z.B. ein Pi-hole) - oder 'automatisch'."
        Category = "Network"
        Group    = "DNS"
        Action   = {
            Set-ProviderDns 'Cloudflare' @('1.1.1.1', '1.0.0.1', '2606:4700:4700::1111', '2606:4700:4700::1001')
        }
    },
    [PSCustomObject]@{
        Name     = "Set DNS to Google (8.8.8.8)"
        Desc     = "Setzt den DNS-Server auf Google 8.8.8.8 / 8.8.4.4 (IPv4) plus die passenden IPv6-Server (2001:4860:4860::8888/::8844), damit auch IPv6-Anfragen über Google laufen. Global verteilt, sehr schnell und zuverlässig. Alternative zu Cloudflare. Revert bringt die DNS-Server zurück, die vorher eingestellt waren (z.B. ein Pi-hole) - oder 'automatisch'."
        Category = "Network"
        Group    = "DNS"
        Action   = {
            Set-ProviderDns 'Google' @('8.8.8.8', '8.8.4.4', '2001:4860:4860::8888', '2001:4860:4860::8844')
        }
    },
    [PSCustomObject]@{
        Name     = "Flush DNS Cache"
        Desc     = "Leert den lokalen DNS-Cache. Sinnvoll nach DNS-Änderungen oder bei Verbindungsproblemen. Schnell und ohne Nebenwirkungen."
        Category = "Network"
        Group    = "DNS"
        Action   = {
            ipconfig /flushdns | Out-Null
            Write-Log "DNS Cache flushed"
        }
    },

    # == NETWORK / TCP ====================================================
    [PSCustomObject]@{
        Name     = "Disable TCP Auto-Tuning"
        Desc     = "Schaltet die automatische Größe des TCP-Empfangsfensters ab - es bleibt dann bei 64 KB. ACHTUNG: Das bremst Downloads stark: Bei 20 ms Ping sind höchstens etwa 26 MBit/s möglich, bei 40 ms etwa 13 MBit/s - egal wie schnell dein Anschluss ist. Für den Ping in Spielen bringt es nichts Messbares. Nur zum Testen, wenn ein Router oder Netzwerk mit Auto-Tuning Probleme macht; in keinem Preset."
        Category = "Network"
        Group    = "TCP"
        Action   = {
            netsh int tcp set global autotuninglevel=disabled | Out-Null
            Write-Log "TCP Auto-Tuning disabled"
        }
    },

    # == NETWORK / QOS ====================================================

    # == NETWORK / ADAPTER =================================================
    [PSCustomObject]@{
        Name     = "Disable Network Adapter Power Saving"
        Desc     = "Deaktiviert 'Computer kann Gerät ausschalten um Strom zu sparen' für alle physischen Netzwerkadapter (LAN, WLAN). Verhindert Verbindungsabbrüche und Latenz-Spitzen durch Energiesparfunktionen des Adapters."
        Category = "Network"
        Group    = "Adapter"
        Action   = {
            # Physical adapters only (NCF_PHYSICAL) -- the same set the status check looks
            # at; virtual miniports (VPN, Hyper-V, Bluetooth PAN) have no power saving to
            # turn off. The revert still cleans every adapter, also after older versions.
            $netClass = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
            Get-ChildItem $netClass -ErrorAction SilentlyContinue | ForEach-Object {
                if ((Get-ItemProperty $_.PSPath -Name "NetCfgInstanceId" -ErrorAction SilentlyContinue) -and (([int64](Get-RegVal $_.PSPath "Characteristics")) -band 0x4)) {
                    Set-ItemProperty -Path $_.PSPath -Name "PnPCapabilities" -Value 24 -Type DWord -Force -ErrorAction SilentlyContinue
                }
            }
            Write-Log "Network adapter power saving disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Delivery Optimization (P2P Windows Update)"
        Desc     = "Deaktiviert Windows Delivery Optimization. Windows lädt Updates nur noch direkt von Microsoft statt Bandbreite mit anderen PCs im Netzwerk/Internet zu teilen (P2P). Verhindert unerwartete Bandbreitennutzung während des Spielens."
        Category = "Network"
        Group    = "Adapter"
        Action   = {
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" /v DODownloadMode /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Delivery Optimization (P2P updates) disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Energy-Efficient Ethernet"
        Desc     = "Schaltet Energy-Efficient Ethernet (EEE, 'Green Ethernet') an allen LAN-Adaptern ab, die es anbieten. Mit EEE geht die Leitung in Sendepausen in einen Stromsparzustand und muss für das nächste Paket erst aufwachen - das kann kleine Latenzspitzen geben. Kostet am Desktop praktisch nichts. Geändert wird nur, was der Treiber selbst als Einstellung anbietet. Wirkt nach einem Neustart."
        Category = "Network"
        Group    = "Adapter"
        Action   = {
            $ps = @(Get-NicParams 'EEE')
            foreach ($n in $ps) { Set-ItemProperty -Path $n.Path -Name $n.Keyword -Value "0" -Type String -ErrorAction Stop }
            Write-Log $(if ($ps.Count) { "Energy-Efficient Ethernet disabled ($($ps.Count) driver setting(s): $(@($ps | ForEach-Object { $_.Keyword } | Select-Object -Unique) -join ', '))" } else { "Energy-Efficient Ethernet: no adapter offers it -- nothing changed" })
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Interrupt Moderation"
        Desc     = "Der Netzwerkadapter meldet jedes Paket sofort, statt mehrere zu sammeln und gebündelt zu melden. Senkt die Netzwerk-Latenz um Bruchteile einer Millisekunde, erzeugt aber bei hohen Download-Raten deutlich mehr CPU-Last. Gedacht für Online-Spiele - wer oft große Downloads hat oder streamt, lässt es besser an. Geändert wird nur, was der Treiber selbst anbietet. Wirkt nach einem Neustart."
        Category = "Network"
        Group    = "Adapter"
        Action   = {
            $ps = @(Get-NicParams 'InterruptModeration')
            foreach ($n in $ps) { Set-ItemProperty -Path $n.Path -Name $n.Keyword -Value "0" -Type String -ErrorAction Stop }
            Write-Log $(if ($ps.Count) { "Interrupt Moderation disabled on $($ps.Count) adapter(s)" } else { "Interrupt Moderation: no adapter offers it -- nothing changed" })
        }
    },

    # == RAM & STORAGE / PAGE FILE ========================================
    [PSCustomObject]@{
        Name     = "Optimize PageFile (System Managed)"
        Desc     = "Setzt die PageFile-Verwaltung auf automatisch durch Windows. Windows passt die Auslagerungsdatei dynamisch an den RAM-Bedarf an - verhindert sowohl zu kleine als auch zu große PageFiles."
        Category = "RAM & Storage"
        Group    = "Page File"
        Action   = {
            $cs = Get-WmiObject -Class Win32_ComputerSystem -EnableAllPrivileges
            $cs.AutomaticManagedPagefile = $true
            $cs.Put() | Out-Null
            Write-Log "PageFile set to system managed"
        }
    },
    [PSCustomObject]@{
        Name     = "Clear PageFile on Shutdown"
        Desc     = "Loescht die Auslagerungsdatei bei jedem Herunterfahren. Verhindert dass sensible Daten im Speicher nach dem Neustart noch auf der Festplatte liegen. Gut für Datenschutz. Macht den Shutdown minimal langsamer."
        Category = "RAM & Storage"
        Group    = "Page File"
        Action   = {
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v ClearPageFileAtShutdown /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "PageFile cleared on shutdown enabled"
        }
    },

    # == RAM & STORAGE / MEMORY ===========================================
    [PSCustomObject]@{
        Name     = "Disable Memory Compression"
        Desc     = "Deaktiviert die RAM-Komprimierung in Windows. Memory Compression verbraucht CPU-Ressourcen um RAM-Inhalte zu komprimieren. Bei ausreichend RAM (16GB+) bringt Deaktivieren weniger CPU-Last während des Spielens."
        Category = "RAM & Storage"
        Group    = "Memory"
        Action   = {
            try {
                Disable-MMAgent -MemoryCompression -ErrorAction Stop
                Write-Log "Memory Compression disabled"
            } catch {
                Write-Log "Memory Compression could not be disabled (Windows 24h limit, already disabled, or unsupported build): $_"
            }
        }
    },

    # == RAM & STORAGE / SSD ==============================================
    [PSCustomObject]@{
        Name     = "Enable SSD TRIM"
        Desc     = "Aktiviert TRIM für alle angeschlossenen SSDs. TRIM informiert die SSD über nicht mehr benötigte Datenblöcke - haelt die SSD-Performance langfristig auf hohem Niveau und verlängert die Lebensdauer."
        Category = "RAM & Storage"
        Group    = "SSD & NVMe"
        Action   = {
            fsutil behavior set DisableDeleteNotify 0 | Out-Null
            Write-Log "SSD TRIM enabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Scheduled Defragmentation"
        Desc     = "Schaltet die wöchentliche Aufgabe 'Laufwerke optimieren' ab. Auf Festplatten (HDD) ist das die Defragmentierung, auf SSDs nur ein 'Retrim', das der SSD die freien Blöcke meldet - Windows defragmentiert SSDs nicht. Nur sinnvoll, wenn du die Optimierung selbst anstoßen willst (Laufwerke optimieren > Optimieren); für SSDs nicht zu empfehlen. In keinem Preset."
        Category = "RAM & Storage"
        Group    = "SSD & NVMe"
        Action   = {
            schtasks /Change /TN "\Microsoft\Windows\Defrag\ScheduledDefrag" /Disable 2>$null | Out-Null
            reg add "HKLM\SOFTWARE\Microsoft\Dfrg\BootOptimizeFunction" /v Enable /t REG_SZ /d N /f | Out-Null
            Write-Log "Scheduled Defragmentation disabled"
        }
    },

    # == RAM & STORAGE / MAINTENANCE ======================================
    [PSCustomObject]@{
        Name     = "Disable Write-Cache Buffer Flushing"
        Desc     = "Deaktiviert das erzwungene Leeren des Schreibcache-Puffers bei SSDs. Verbessert die Schreibgeschwindigkeit spürbar (wie das Häkchen im Geräte-Manager). Bei Stromausfall können noch nicht geschriebene Daten verloren gehen - nur für Desktop-PCs mit stabiler Stromversorgung bzw. USV."
        Category = "RAM & Storage"
        Group    = "SSD & NVMe"
        Action   = {
            $disks = Get-WmiObject -Query "SELECT * FROM Win32_DiskDrive" |
                Where-Object {
                    $_.MediaType -eq 3 -or $_.MediaType -eq 4 -or
                    $_.MediaType -eq 'Fixed hard disk media' -or $null -eq $_.MediaType
                }
            if (-not $disks) {
                Write-Log "Write-Cache: no disks found -- skipped"
            } else {
                $count = 0
                foreach ($disk in $disks) {
                    $pnpId   = $disk.PNPDeviceID
                    $regPath = "HKLM\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters\Disk"
                    # Device Manager > Policies: "Enable write caching" (UserWriteCacheSetting)
                    # must be on for "Turn off write-cache buffer flushing" (CacheIsPowerProtected)
                    reg add "$regPath" /v UserWriteCacheSetting /t REG_DWORD /d 1 /f | Out-Null
                    reg add "$regPath" /v CacheIsPowerProtected /t REG_DWORD /d 1 /f | Out-Null
                    $count++
                }
                Write-Log ("Write-Cache Buffer Flushing disabled (" + $count + " disks updated)")
            }
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Hibernation"
        Desc     = "Deaktiviert den Ruhezustand (Hibernate) und löscht hiberfil.sys. Gibt mehrere GB Speicherplatz frei (rund 40 % des RAMs). Damit ist auch der Schnellstart aus - er braucht den Ruhezustand; Windows fährt dann komplett herunter und startet ein paar Sekunden länger. Empfohlen für Desktop-PCs."
        Category = "RAM & Storage"
        Group    = "Maintenance"
        Action   = {
            powercfg /hibernate off 2>$null | Out-Null
            Write-Log "Hibernation disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Clean Temp Files"
        Desc     = "Loescht alle Dateien in %TEMP%, Windows\Temp und Prefetch-Ordner. Gibt Festplattenplatz frei und kann den Boot-Vorgang leicht beschleunigen. Laufende Anwendungen werden nicht beeinflusst."
        Category = "RAM & Storage"
        Group    = "Maintenance"
        Action   = {
            $tempPaths = @(
                $env:TEMP,
                "$env:SystemRoot\Temp",
                "$env:SystemRoot\Prefetch"
            )
            foreach ($path in $tempPaths) {
                if (Test-Path $path) {
                    # Skip GameOptimizerPro's own files in %TEMP% (this session's log,
                    # the startup log, the downloaded script) -- deleting them wiped the
                    # log of the very run the user may want to open afterwards.
                    Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                        Where-Object { $_.Name -notlike "GameOptimizerPro*" } |
                        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
            Write-Log "Temp files cleaned"
        }
    },

    # == RAM & STORAGE / DEEP CLEAN (Kudu-style multi-category cleanup) ====
    [PSCustomObject]@{
        Name     = "Clean Browser Caches"
        Desc     = "Leert die Caches von Chrome, Edge und Firefox (nur Cache, keine Passwörter/Verlauf/Lesezeichen). Gibt oft mehrere hundert MB frei. Browser sollten geschlossen sein."
        Category = "RAM & Storage"
        Group    = "Deep Clean"
        Action   = {
            $freed = Clear-PathItems @(
                "$env:LOCALAPPDATA\Google\Chrome\User Data\*\Cache\*",
                "$env:LOCALAPPDATA\Google\Chrome\User Data\*\Code Cache\*",
                "$env:LOCALAPPDATA\Microsoft\Edge\User Data\*\Cache\*",
                "$env:LOCALAPPDATA\Microsoft\Edge\User Data\*\Code Cache\*",
                "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles\*\cache2\*"
            )
            Write-Log ("Browser caches cleaned (~" + (Format-FreedMB $freed) + " MB freed)")
        }
    },
    [PSCustomObject]@{
        Name     = "Clean Windows Update Cache"
        Desc     = "Loescht den heruntergeladenen Windows-Update-Cache (SoftwareDistribution\Download). Sicher -- Windows lädt bei Bedarf neu. Der Update-Dienst wird kurz gestoppt und wieder gestartet."
        Category = "RAM & Storage"
        Group    = "Deep Clean"
        Action   = {
            Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
            $freed = Clear-PathItems @("$env:SystemRoot\SoftwareDistribution\Download\*")
            Start-Service wuauserv -ErrorAction SilentlyContinue
            Write-Log ("Windows Update cache cleaned (~" + (Format-FreedMB $freed) + " MB freed)")
        }
    },
    [PSCustomObject]@{
        Name     = "Clean Thumbnail Cache"
        Desc     = "Loescht die Thumbnail-Datenbank des Explorers. Windows baut sie bei Bedarf neu auf. Behebt oft fehlerhafte/veraltete Vorschaubilder und gibt Platz frei."
        Category = "RAM & Storage"
        Group    = "Deep Clean"
        Action   = {
            $freed = Clear-PathItems @("$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db")
            Write-Log ("Thumbnail cache cleaned (~" + (Format-FreedMB $freed) + " MB freed)")
        }
    },
    [PSCustomObject]@{
        Name     = "Empty Recycle Bin"
        Desc     = "Leert den Papierkorb aller Laufwerke endgültig. Achtung: gelöschte Dateien sind danach nicht mehr wiederherstellbar."
        Category = "RAM & Storage"
        Group    = "Deep Clean"
        Action   = {
            try { Clear-RecycleBin -Force -ErrorAction Stop; Write-Log "Recycle Bin emptied" }
            catch { Write-Log "Recycle Bin already empty or not accessible" }
        }
    },
    [PSCustomObject]@{
        Name     = "Clean Prefetch Data"
        Desc     = "Loescht die Prefetch-Dateien (.pf). Windows baut sie beim nächsten Start neu auf. Kann bei veralteten Einträgen helfen -- der erste Boot danach ist minimal langsamer."
        Category = "RAM & Storage"
        Group    = "Deep Clean"
        Action   = {
            $freed = Clear-PathItems @("$env:SystemRoot\Prefetch\*.pf")
            Write-Log ("Prefetch data cleaned (~" + (Format-FreedMB $freed) + " MB freed)")
        }
    },
    [PSCustomObject]@{
        Name     = "Clean System Logs & Crash Dumps"
        Desc     = "Loescht Windows-Temp, CBS-Logs, Crash-Dumps und Fehlerbericht-Dateien. Rein diagnostische Dateien -- gefahrlos zu entfernen, gibt oft spürbar Platz frei."
        Category = "RAM & Storage"
        Group    = "Deep Clean"
        Action   = {
            $freed = Clear-PathItems @(
                "$env:SystemRoot\Temp\*",
                "$env:SystemRoot\Logs\CBS\*.log",
                "$env:SystemRoot\Minidump\*",
                "$env:LOCALAPPDATA\CrashDumps\*",
                "$env:ProgramData\Microsoft\Windows\WER\ReportQueue\*",
                "$env:ProgramData\Microsoft\Windows\WER\ReportArchive\*"
            )
            Write-Log ("System logs & crash dumps cleaned (~" + (Format-FreedMB $freed) + " MB freed)")
        }
    },

    # == WINDOWS 11 SPECIFIC ==============================================
    [PSCustomObject]@{
        Name     = "Restore Classic Right-Click Menu"
        Desc     = "WIN11: Stellt das klassische Windows 10 Rechtsklick-Menü wieder her. Das neue Win11-Menü versteckt viele Optionen hinter 'Weitere Optionen anzeigen'. Wirkt nach Neustart des Explorers."
        Category = "Windows 11"
        Group    = "Taskbar & Shell"
        Action   = {
            # NO `/d ""` here: Windows PowerShell 5.1 drops empty-string arguments when
            # calling native programs, so reg.exe received `/d /f`, stored the literal
            # text "/f" and -- because /f was consumed as data -- prompted
            # "Overwrite (Yes/No)?" on every re-apply. In the hidden GUI process nobody
            # can answer, so Apply hung forever. `/ve /f` alone writes an empty default.
            reg add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /ve /f | Out-Null
            Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
            Write-Log "Win11: Classic right-click menu restored"
        }
    },
    [PSCustomObject]@{
        Name     = "Left-Align Taskbar"
        Desc     = "WIN11: Verschiebt die Taskleisten-Icons nach links (wie Windows 10). Windows 11 zentriert Icons standardmäßig. Wirkt nach Explorer-Neustart."
        Category = "Windows 11"
        Group    = "Taskbar & Shell"
        Action   = {
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarAl /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Win11: Taskbar left-aligned"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Widgets"
        Desc     = "WIN11: Deaktiviert das Widgets-Panel (Wetter, News, Aktien). Widgets laufen als MSN-Browser im Hintergrund und verbrauchen RAM. Icon wird aus der Taskleiste entfernt."
        Category = "Windows 11"
        Group    = "Taskbar & Shell"
        Action   = {
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarDa /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /v AllowNewsAndInterests /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Win11: Widgets disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Recommended in Start Menu"
        Desc     = "WIN11: Leert den 'Empfohlen'-Bereich im Startmenü auf allen Editionen: keine zuletzt geöffneten Dateien und keine Tipps oder App-Empfehlungen mehr (das betrifft auch 'Zuletzt verwendet' im Datei-Explorer und die Sprunglisten der Taskleiste). Ganz ausgeblendet wird der Bereich per Richtlinie - laut Microsoft ab Pro; unter Home bleibt er leer stehen."
        Category = "Windows 11"
        Group    = "Start Menu"
        Action   = {
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v HideRecommendedSection /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_TrackDocs /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_IrisRecommendations /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Win11: Recommended section in Start Menu disabled (policy + recent files + recommendations)"
        }
    },
    [PSCustomObject]@{
        Name     = "Enable End Task in Taskbar"
        Desc     = "WIN11: Aktiviert 'Task beenden' direkt im Rechtsklick-Menü der Taskleiste. Beendet hängende Prozesse ohne Task-Manager öffnen zu müssen."
        Category = "Windows 11"
        Group    = "Taskbar & Shell"
        Action   = {
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings" /v TaskbarEndTask /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "Win11: End Task in taskbar enabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Snap Layout Hover Menu"
        Desc     = "WIN11: Deaktiviert das Snap Layout-Popup das erscheint wenn man mit der Maus über den Maximieren-Button fährt. Verhindert ungewolltes Snappen beim Gaming."
        Category = "Windows 11"
        Group    = "Window Management"
        Action   = {
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v EnableSnapAssistFlyout /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Win11: Snap Layout hover menu disabled"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Dynamic Lighting"
        Desc     = "WIN11: Schaltet die Dynamische Beleuchtung von Windows ab (Einstellungen > Personalisierung > Dynamische Beleuchtung). Sonst greift Windows auf RGB-Tastaturen, -Mäuse und -Beleuchtung zu und kann sich mit der Hersteller-Software (iCUE, Armoury Crate, G HUB, SignalRGB) streiten - Effekte flackern oder werden überschrieben. Wer RGB nur über Windows steuert, lässt sie an."
        Category = "Windows 11"
        Group    = "Devices"
        Action   = {
            reg add "HKCU\Software\Microsoft\Lighting" /v AmbientLightingEnabled /t REG_DWORD /d 0 /f | Out-Null
            Write-Log "Win11: Dynamic Lighting disabled"
        }
    },

    # == AUDIO ============================================================
    [PSCustomObject]@{
        Name     = "Disable Audio Enhancements"
        Desc     = "Schaltet die Audioverbesserungen (Bass Boost, Raumklang, Equalizer, Lautheitsausgleich) für alle angeschlossenen Wiedergabegeräte ab - über die Windows-Audio-Schnittstelle, wie die Sound-Systemsteuerung. Den direkten Weg über die Registry sperrt Windows 11 inzwischen, ältere Versionen dieses Tweaks liefen deshalb ins Leere. Reduziert Audio-Latenz und CPU-Last von audiodg.exe. Später angeschlossene Geräte: Tweak erneut anwenden (die Drift-Prüfung meldet sie)."
        Category = "Audio"
        Group    = "Latency & Quality"
        Action   = {
            # Active and unplugged playback devices as Windows sees them; written through the audio
            # service and read back -- only real successes count
            $ids = @(Get-AudioRenderIds)
            if (-not $ids.Count) { Write-Log "Audio Enhancements: Windows reports no playback device"; return }
            $ok = 0; $bad = @()
            foreach ($id in $ids) {
                $hr = Set-AudioFx $id 1
                if ($hr -eq 0 -and (Get-AudioFx $id) -eq 1) { $ok++ } else { $bad += $(if ($hr -ne 0) { '0x{0:X8}' -f $hr } else { 'not read back' }) }
            }
            Write-Log "Audio Enhancements disabled on $ok of $($ids.Count) playback device(s) (Windows audio API)"
            if ($bad.Count) { throw "Windows refused the setting on $($bad.Count) of $($ids.Count) playback device(s) ($($bad[0]))" }
        }
    },
    [PSCustomObject]@{
        Name     = "Optimize MMCSS Audio Profile"
        Desc     = "Optimiert das Multimedia Class Scheduler Profil für Audio. Setzt Audio auf 'Latency Sensitive' mit hoher Scheduling-Priorität. Reduziert Audio-Stottern und Knacken unter CPU-Last."
        Category = "Audio"
        Group    = "Latency & Quality"
        Action   = {
            $audioPath = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Audio"
            reg add $audioPath /v "Latency Sensitive" /t REG_SZ /d "True" /f | Out-Null
            reg add $audioPath /v "Priority" /t REG_DWORD /d 6 /f | Out-Null
            reg add $audioPath /v "Scheduling Category" /t REG_SZ /d "High" /f | Out-Null
            reg add $audioPath /v "SFIO Priority" /t REG_SZ /d "High" /f | Out-Null
            Write-Log "MMCSS Audio profile optimized (Latency Sensitive, High Priority)"
        }
    },
    [PSCustomObject]@{
        Name     = "Set Audio Service High Priority"
        Desc     = "Gibt Audio, Spielen und anderen Multimedia-Aufgaben mehr CPU-Zeit: SystemResponsiveness wird von 20 auf 10 gesetzt, dann reserviert Windows nur noch 10 % statt 20 % der CPU für Hintergrundaufgaben. 10 ist der kleinste Wert, den Windows annimmt - kleinere Werte (früher 0) behandelt Windows laut Microsoft wie 20, also wie ohne Tweak. Hilft gegen Audio-Aussetzer, wenn andere Prozesse die CPU belasten - spürbar bei Gaming und Streaming gleichzeitig."
        Category = "Audio"
        Group    = "Latency & Quality"
        Action   = {
            # 10, not 0: Windows treats values below 10 as 20 (= its default) -- Microsoft, MMCSS docs
            reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v SystemResponsiveness /t REG_DWORD /d 10 /f | Out-Null
            # Ownership marker for the shared SystemResponsiveness value (see reverts)
            reg add "HKLM\SOFTWARE\GameOptimizerPro" /v SR_AudioPriority /t REG_DWORD /d 1 /f | Out-Null
            Write-Log "SystemResponsiveness set to 10 (the most CPU time Windows gives multimedia and games)"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Windows Sound Scheme"
        Desc     = "Deaktiviert alle Windows-Systemklänge (Start, Fehler, Benachrichtigungen usw.). Keine unerwarteten Sound-Unterbrechungen mehr während Gaming oder Streaming."
        Category = "Audio"
        Group    = "System Sounds"
        Action   = {
            reg add "HKCU\AppEvents\Schemes" /ve /t REG_SZ /d ".None" /f | Out-Null
            # The scheme NAME alone silences nothing: Windows plays whatever each event's
            # ".Current" entry points to. Empty them all -- exactly what the Sound control
            # panel does when you pick "No Sounds". (Each ".Default" keeps the stock sound.)
            $n = 0
            Get-ChildItem "HKCU:\AppEvents\Schemes\Apps" -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.PSChildName -eq ".Current" } |
                ForEach-Object { Set-ItemProperty -Path $_.PSPath -Name "(default)" -Value "" -ErrorAction SilentlyContinue; $n++ }
            Write-Log "Windows Sound Scheme disabled (.None, $n event sounds silenced)"
        }
    },

    # == GPU TWEAKS (AMD) =================================================
    [PSCustomObject]@{
        Name     = "AMD: Disable ULPS (Ultra Low Power State)"
        Desc     = "AMD only: Deaktiviert Ultra Low Power State. ULPS versetzt inaktive GPUs (Multi-GPU) in extremen Stromsparmodus und kann beim Aufwachen zu Stottern führen. Auch bei Single-GPU sinnvoll deaktivieren."
        Category = "GPU Tweaks"
        Group    = "AMD"
        Action   = {
            if ($IsAMD) {
                foreach ($k in @(Get-AmdGpuKeys)) {
                    Set-ItemProperty -Path $k.PSPath -Name "EnableULPS" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $k.PSPath -Name "EnableULPS_NA" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                }
                Write-Log "AMD: ULPS disabled"
            } else { Write-Log "GPU Tweak skipped: no AMD GPU detected ($GPU)" }
        }
    },

    # == POWER PLAN =======================================================
    [PSCustomObject]@{
        Name     = "Disable USB Selective Suspend"
        Desc     = "Deaktiviert USB Selective Suspend global. Windows schickt dann keine USB-Geräte mehr in den Schlafmodus. Verhindert Verbindungsabbrüche bei USB-Maus, Headset und Controllern unter Last."
        Category = "Power Plan"
        Group    = "USB & PCI"
        Action   = {
            Set-PowerAllSchemes "2a737441-1930-4402-8d77-b2bebba308a3" "48e6b7a6-50f5-4782-a5d4-53bb8f07e226" 0
            Write-Log "USB Selective Suspend disabled (all power schemes)"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable USB 3 Link Power Management"
        Desc     = "Schaltet die Stromsparzustände der USB-3-Verbindungen (U1/U2) in allen Energieplänen ab. Die Verbindung zu USB-3-Geräten (Headset-DACs, Capture-Karten, externe SSDs, VR-Brillen) muss dann nicht erst aufwachen - hilft gegen Aussetzer und kurze Ruckler. Ergänzt 'Disable USB Selective Suspend' (das schickt ganze Geräte schlafen, dies nur die Verbindung). Windows blendet diese Einstellung in den Energieoptionen aus. Etwas mehr Stromverbrauch."
        Category = "Power Plan"
        Group    = "USB & PCI"
        Action   = {
            Set-PowerAllSchemes "2a737441-1930-4402-8d77-b2bebba308a3" "d4e98f31-5ffe-4ce1-be31-1b38b384c009" 0
            Write-Log "USB 3 link power management disabled (all power schemes)"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable PCI-E Link State Power Management"
        Desc     = "Deaktiviert PCI-E ASPM (Active State Power Management). Verhindert dass die GPU ihre PCI-Express-Verbindung in den Stromsparmodus versetzt. Reduziert GPU-Latenzschwankungen unter Last."
        Category = "Power Plan"
        Group    = "USB & PCI"
        Action   = {
            Set-PowerAllSchemes "SUB_PCIEXPRESS" "ASPM" 0
            Write-Log "PCI-E Link State Power Management disabled (all power schemes)"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Hard Disk Sleep"
        Desc     = "Setzt die Festplatten-Schlaf-Zeit auf 0 (niemals). Verhindert das bekannte Stottern nach länger Inaktivität wenn eine HDD/SSD aus dem Schlaf aufwacht. Empfohlen für Gaming-PCs."
        Category = "Power Plan"
        Group    = "Storage"
        Action   = {
            Set-PowerAllSchemes "SUB_DISK" "DISKIDLE" 0
            Write-Log "Hard Disk Sleep disabled (timeout = 0, all power schemes)"
        }
    },
    [PSCustomObject]@{
        Name     = "Set Display Sleep = 15 Minutes"
        Desc     = "Setzt den Monitor-Schlaf-Timer auf 15 Minuten (AC) und 5 Minuten (Akku). Verhindert dass der Monitor mitten im Spielen abschaltet, spart aber trotzdem Energie bei längerer Pause."
        Category = "Power Plan"
        Group    = "Display"
        Action   = {
            Set-PowerAllSchemes "SUB_VIDEO" "VIDEOIDLE" 900 300
            Write-Log "Display Sleep set to 15 min AC / 5 min DC (all power schemes)"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Sleep (System)"
        Desc     = "Deaktiviert den System-Schlafmodus komplett. Der PC schläft nicht mehr nach Inaktivität ein. Empfohlen für Desktop-PCs die im Hintergrund laufen sollen (z.B. Downloads, Server)."
        Category = "Power Plan"
        Group    = "Sleep"
        Action   = {
            Set-PowerAllSchemes "SUB_SLEEP" "STANDBYIDLE" 0
            Write-Log "System Sleep disabled (all power schemes)"
        }
    },
    [PSCustomObject]@{
        Name     = "Disable Wake Timers"
        Desc     = "Geplante Aufgaben (z.B. Neustarts nach Windows-Updates und die automatische Wartung) dürfen den PC nicht mehr aus dem Energiesparmodus wecken - kein PC mehr, der nachts von allein anspringt. Aufwecken per Maus, Tastatur oder Netzwerk (Wake-on-LAN) bleibt. Gilt für alle Energiepläne; spielt nur eine Rolle, wenn der PC in den Energiesparmodus geht."
        Category = "Power Plan"
        Group    = "Sleep"
        Action   = {
            Set-PowerAllSchemes "SUB_SLEEP" "RTCWAKE" 0
            Write-Log "Wake timers disabled (all power schemes)"
        }
    },
    [PSCustomObject]@{
        Name     = "CPU Minimum Processor State = 100%"
        Desc     = "Setzt den minimalen CPU-Zustand auf 100%. Die CPU läuft dann ständig mit voller Taktrate ohne herunterzuregeln. Eliminiert die kurze Verzögerung beim Hochregeln von Idle  --  wichtig für konstante FPS."
        Category = "Power Plan"
        Group    = "CPU"
        Action   = {
            Set-PowerAllSchemes "SUB_PROCESSOR" "PROCTHROTTLEMIN" 100
            Write-Log "CPU Minimum Processor State set to 100% (all power schemes)"
        }
    },
    [PSCustomObject]@{
        Name     = "CPU Maximum Processor State = 100%"
        Desc     = "Setzt den maximalen CPU-Zustand auf 100% und stellt sicher dass Windows die CPU nie künstlich deckelt. Relevant auf Laptops und Systemen mit aggressiver Thermal-Policy."
        Category = "Power Plan"
        Group    = "CPU"
        Action   = {
            Set-PowerAllSchemes "SUB_PROCESSOR" "PROCTHROTTLEMAX" 100
            Write-Log "CPU Maximum Processor State set to 100% (all power schemes)"
        }
    }
)

# -----------------------------------------
# REVERT ACTIONS  --  Windows Defaults
# Keyed by tweak Name. Run by BtnRevertAll.
# -----------------------------------------
$RevertActions = @{

    # == BLOATWARE (apps removed  --  registry parts only) ===================
    "Remove Xbox Apps" = {
        Write-Log "Revert Xbox Apps: removed apps stay removed -- reinstall them from the Microsoft Store (Xbox app, Game Bar) or use System Restore"
    }
    "Remove Copilot" = {
        reg delete "HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /f 2>$null
        Write-Log "Revert Copilot: policy removed -- the Copilot app comes back from the Microsoft Store"
    }
    "Remove OneDrive" = {
        Write-Log "Revert OneDrive: stays removed -- reinstall it with OneDriveSetup.exe (Windows\System32) or from microsoft.com"
    }
    "Remove Windows Recall" = {
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v DisableAIDataAnalysis /f 2>$null
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v AllowRecallEnablement /f 2>$null
        Write-Log "Revert Recall: policies removed (Recall can be re-added via Windows Features / Windows Update)"
    }
    "Remove Other Bloatware" = {
        Write-Log "Revert Bloatware: removed apps stay removed -- reinstall the ones you want from the Microsoft Store"
    }
    "Stop Auto-Installed Suggested Apps" = {
        # Windows ships these three values as 1 (auto-install allowed)
        $cdm = "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
        reg add $cdm /v SilentInstalledAppsEnabled /t REG_DWORD /d 1 /f | Out-Null
        reg add $cdm /v OemPreInstalledAppsEnabled /t REG_DWORD /d 1 /f | Out-Null
        reg add $cdm /v PreInstalledAppsEnabled    /t REG_DWORD /d 1 /f | Out-Null
        Write-Log "Revert: auto-install of suggested apps restored to the Windows default"
    }
    "Disable Tips, Ads & Suggestions" = {
        # Not set = the Windows default (on)
        $cdm = "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
        foreach ($v in 'SoftLandingEnabled', 'FeatureManagementEnabled', 'PreInstalledAppsEverEnabled', 'RotatingLockScreenOverlayEnabled', 'SystemPaneSuggestionsEnabled',
                'SubscribedContent-310093Enabled', 'SubscribedContent-338387Enabled', 'SubscribedContent-338389Enabled', 'SubscribedContent-338393Enabled',
                'SubscribedContent-353694Enabled', 'SubscribedContent-353696Enabled') {
            reg delete $cdm /v $v /f 2>$null
        }
        reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" /v ScoobeSystemSettingEnabled /f 2>$null
        reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_AccountNotifications /f 2>$null
        reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowSyncProviderNotifications /f 2>$null
        reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications" /v EnableAccountNotifications /f 2>$null
        Write-Log "Revert: tips, ads and suggestions back to the Windows default (values removed)"
    }
    "Stop OneDrive Folder Backup" = {
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\OneDrive" /v KFMBlockOptIn /f 2>$null
        Write-Log "Revert: OneDrive folder backup allowed again (policy removed)"
    }
    "Disable Get Started & Copilot Sign-in Screens" = {
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableGetStarted /f 2>$null
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableCopilotPinScreen /f 2>$null
        Write-Log "Revert: Get Started and Copilot sign-in screens restored (policies removed)"
    }

    # == PRIVACY ==========================================================
    "Disable Power Throttling" = {
        reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" /v PowerThrottlingOff /f 2>$null
        Write-Log "Revert: Power Throttling re-enabled (EcoQoS on)"
    }
    "Disable Bing in Windows Search" = {
        reg delete "HKCU\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v DisableSearchBoxSuggestions /f 2>$null
        reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v BingSearchEnabled /f 2>$null
        reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v CortanaConsent /f 2>$null
        $ss = "HKCU\Software\Microsoft\Windows\CurrentVersion\SearchSettings"
        reg delete $ss /v IsDynamicSearchBoxEnabled /f 2>$null
        reg delete $ss /v IsMSACloudSearchEnabled /f 2>$null
        reg delete $ss /v IsAADCloudSearchEnabled /f 2>$null
        Write-Log "Revert: Bing in Windows Search re-enabled (values removed -- Windows default)"
    }
    "Process Count Reduction (Svchost)" = {
        # Windows ships 0x380000 = 3,670,016 KB (3.5 GB). Until 1.2.5 this wrote 380000 decimal (~370 MB).
        reg add "HKLM\SYSTEM\CurrentControlSet\Control" /v SvcHostSplitThresholdInKB /t REG_DWORD /d 3670016 /f | Out-Null
        Write-Log "Revert: Svchost split threshold back to the Windows default (0x380000 = 3.5 GB)"
    }
    "Disable Startup App Delay" = {
        reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize" /v StartupDelayInMSec /f 2>$null
        Write-Log "Revert: startup app delay back to the Windows default"
    }
    "Block Background Apps (Policy)" = {
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsRunInBackground /f 2>$null
        Write-Log "Revert: background apps policy removed (user decides again)"
    }
    "Stop Background Apps (All Editions)" = {
        reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled /f 2>$null
        # the undocumented kernel value the old "Disable Background App Throttling" (until 1.2.5) wrote too
        reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v DisableLowQosTimerResolution /f 2>$null
        Write-Log "Revert: Store apps may run in the background again"
    }

    # == WINDOWS UPDATE ====================================================
    "Exclude Drivers from Windows Update" = {
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v ExcludeWUDriversInQualityUpdate /f 2>$null
        Write-Log "Revert: Windows Update may install drivers again"
    }
    "Hold Feature Updates (Stay on Current Version)" = {
        $wu = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        reg delete $wu /v TargetReleaseVersion /f 2>$null
        reg delete $wu /v ProductVersion /f 2>$null
        reg delete $wu /v TargetReleaseVersionInfo /f 2>$null
        Write-Log "Revert: feature updates no longer held"
    }

    # == WINDOWS / CTT ESSENTIALS ==========================================
    "Prevent Device Companion Apps" = {
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\Device Metadata" /v PreventDeviceMetadataFromNetwork /f 2>$null
        Write-Log "Revert: Device Companion Apps re-enabled"
    }
    "Disable Consumer Features" = {
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /f 2>$null
        Write-Log "Revert: Windows Consumer Features re-enabled"
    }
    "Disable Windows Platform Binary Table (WPBT)" = {
        reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v DisableWpbtExecution /f 2>$null
        Write-Log "Revert: WPBT execution restored to Windows default"
    }
    "Disable Store Recommended Search Results" = {
        $storeDb = "$env:LocalAppData\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalState\store.db"
        # Remove only the Deny entry again -- /grant would leave an extra explicit Allow behind
        if (Test-Path $storeDb) { icacls "$storeDb" /remove:d "*S-1-1-0" 2>$null | Out-Null }
        Write-Log "Revert: Store recommended search results re-enabled (store.db unlocked)"
    }
    "Disable File Explorer Automatic Folder Discovery" = {
        $bags   = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags"
        $bagMRU = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\BagMRU"
        Remove-Item -Path $bags   -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $bagMRU -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log "Revert: File Explorer folder view database reset (auto-discovery restored)"
    }
    "Run Disk Cleanup" = {
        Write-Log "Revert: Run Disk Cleanup is a one-time cleanup action -- nothing to revert"
    }

    # == WINDOWS / QUALITY OF LIFE ========================================
    "Show File Extensions" = {
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 1 /f | Out-Null
        Write-Log "Revert: File extensions hidden again (Windows default)"
    }
    "Show Hidden Files" = {
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Hidden /t REG_DWORD /d 2 /f | Out-Null
        Write-Log "Revert: Hidden files hidden again (Windows default)"
    }
    "Disable Reserved Storage" = {
        try { Set-WindowsReservedStorageState -State Enabled -ErrorAction Stop; Write-Log "Revert: Reserved storage re-enabled" }
        catch { Write-Log "Revert: Reserved storage could not be re-enabled: $($_.Exception.Message)" }
    }
    "Disable Storage Sense" = {
        reg delete "HKLM\Software\Policies\Microsoft\Windows\StorageSense" /v AllowStorageSenseGlobal /f 2>$null
        Write-Log "Revert: Storage Sense policy removed (user setting restored)"
    }
    "Num Lock on Startup" = {
        reg add "HKCU\Control Panel\Keyboard" /v InitialKeyboardIndicators /t REG_SZ /d 2147483648 /f | Out-Null
        reg add "HKU\.DEFAULT\Control Panel\Keyboard" /v InitialKeyboardIndicators /t REG_SZ /d 2147483648 /f | Out-Null
        Write-Log "Revert: NumLock on startup disabled"
    }
    "Disable Lock Screen" = {
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization" /v NoLockScreen /f 2>$null
        Write-Log "Revert: Lock screen re-enabled"
    }
    "Enable Long Paths" = {
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v LongPathsEnabled /t REG_DWORD /d 0 /f | Out-Null
        Write-Log "Revert: Long paths disabled (Windows default)"
    }

    "Disable Telemetry & Data Collection" = {
        # Start type FIRST: Start-Service on a still-Disabled service fails silently, so
        # the old order left telemetry stopped until the next reboot. Defaults:
        # DiagTrack = Automatic, dmwappushservice = Manual (trigger-started by Windows).
        Set-Service DiagTrack -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service DiagTrack -ErrorAction SilentlyContinue
        Set-Service dmwappushservice -StartupType Manual -ErrorAction SilentlyContinue
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /f 2>$null
        reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v AllowTelemetry /f 2>$null
        Write-Log "Revert: Telemetry services re-enabled"
    }
    "Disable Activity History" = {
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v EnableActivityFeed /f 2>$null
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v PublishUserActivities /f 2>$null
        Write-Log "Revert: Activity History policy keys removed (default = enabled)"
    }
    "Disable Advertising ID" = {
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /t REG_DWORD /d 1 /f | Out-Null
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" /v DisabledByGroupPolicy /f 2>$null
        Write-Log "Revert: Advertising ID re-enabled"
    }
    "Disable Text & Image Generation (AI)" = {
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsAccessSystemAIModels /f 2>$null
        Write-Log "Revert: Text & Image Generation policy removed (back to user control)"
    }
    "Disable Click to Do & Settings Agent (AI)" = {
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v DisableClickToDo /f 2>$null
        reg delete "HKCU\Software\Policies\Microsoft\Windows\WindowsAI" /v DisableClickToDo /f 2>$null
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v DisableSettingsAgent /f 2>$null
        Write-Log "Revert: Click to Do + Settings agent policies removed (Windows default)"
    }
    "Disable AI in Paint & Notepad" = {
        $paint = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint"
        reg delete $paint /v DisableCocreator /f 2>$null
        reg delete $paint /v DisableImageCreator /f 2>$null
        reg delete $paint /v DisableGenerativeFill /f 2>$null
        reg delete "HKLM\SOFTWARE\Policies\WindowsNotepad" /v DisableAIFeatures /f 2>$null
        Write-Log "Revert: Paint + Notepad AI policies removed (Windows default)"
    }
    "Disable Location Tracking" = {
        reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v Value /t REG_SZ /d Allow /f | Out-Null
        Set-Service lfsvc -StartupType Manual -ErrorAction SilentlyContinue
        Start-Service lfsvc -ErrorAction SilentlyContinue
        Write-Log "Revert: Location tracking re-enabled"
    }
    "Block Telemetry Hosts (hosts file)" = {
        $hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
        $blocked = @(
            "0.0.0.0 telemetry.microsoft.com","0.0.0.0 vortex.data.microsoft.com",
            "0.0.0.0 vortex-win.data.microsoft.com","0.0.0.0 telecommand.telemetry.microsoft.com",
            "0.0.0.0 oca.telemetry.microsoft.com","0.0.0.0 sqm.telemetry.microsoft.com",
            "0.0.0.0 watson.telemetry.microsoft.com","0.0.0.0 redir.metaservices.microsoft.com",
            "0.0.0.0 choice.microsoft.com","0.0.0.0 df.telemetry.microsoft.com",
            "0.0.0.0 reports.wes.df.telemetry.microsoft.com","0.0.0.0 wes.df.telemetry.microsoft.com"
        )
        if (-not (Test-Path $hostsFile)) { Write-Log "Revert: no hosts file -- nothing to remove"; return }
        # -ErrorAction Stop: if the file can't be read (locked), an empty result must
        # never be written back -- that would wipe the whole hosts file
        $lines = @(Get-Content $hostsFile -ErrorAction Stop)
        $clean = @($lines | Where-Object { $blocked -notcontains $_.Trim() })
        if ($clean.Count -ne $lines.Count) {
            try { Set-Content $hostsFile $clean -Encoding Default -ErrorAction Stop }
            catch { throw "hosts file could not be written (read-only, or locked by an antivirus): $($_.Exception.Message)" }
        }
        Write-Log "Revert: Telemetry host entries removed from hosts file ($($lines.Count - $clean.Count) lines)"
    }
    "Disable Scheduled Telemetry Tasks" = {
        foreach ($task in (Get-TelemetryTasks)) { schtasks /Change /TN $task /Enable 2>$null | Out-Null }
        Write-Log "Revert: Telemetry scheduled tasks re-enabled"
    }
    "Disable Input & Speech Data Collection" = {
        reg delete "HKCU\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy" /v HasAccepted /f 2>$null
        # Windows writes these three at setup with exactly these values
        reg add "HKCU\Software\Microsoft\InputPersonalization" /v RestrictImplicitTextCollection /t REG_DWORD /d 0 /f | Out-Null
        reg add "HKCU\Software\Microsoft\InputPersonalization" /v RestrictImplicitInkCollection /t REG_DWORD /d 0 /f | Out-Null
        reg add "HKCU\Software\Microsoft\InputPersonalization\TrainedDataStore" /v HarvestContacts /t REG_DWORD /d 1 /f | Out-Null
        reg delete "HKCU\Software\Microsoft\Input\TIPC" /v Enabled /f 2>$null
        reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy" /v TailoredExperiencesWithDiagnosticDataEnabled /f 2>$null
        reg delete "HKCU\Software\Microsoft\Siuf\Rules" /v NumberOfSIUFInPeriod /f 2>$null
        reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_TrackProgs /f 2>$null
        reg delete "HKCU\Control Panel\International\User Profile" /v HttpAcceptLanguageOptOut /f 2>$null
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v DoNotShowFeedbackNotifications /f 2>$null
        Write-Log "Revert: input, inking and speech settings back to the Windows default"
    }
    "Disable Remote Assistance" = {
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Remote Assistance" /v fAllowToGetHelp /t REG_DWORD /d 1 /f | Out-Null
        Write-Log "Revert: Remote Assistance allowed again (Windows default)"
    }

    # == PERFORMANCE ======================================================
    "Ultimate Performance Plan" = {
        # "Balanced" is a built-in scheme with a fixed, well-known GUID on every
        # Windows install -- use it directly instead of matching the display
        # name, which is localized (e.g. "Ausbalanciert" on German Windows) and
        # would silently fail to find the plan on non-English systems.
        $balancedGuid = "381b4222-f694-41f0-9685-ff5bb260df2e"
        if (powercfg -list | Select-String ([regex]::Escape($balancedGuid))) {
            powercfg -setactive $balancedGuid
            Write-Log "Revert: Power plan set back to Balanced"
        } else {
            # Fallback: built-in scheme was removed/recreated -- try matching by name
            # (DE/EN). Extract the GUID by pattern, not by column index: the "GUID:"
            # label is localized ("Energieschema-GUID:") so Split()[3] lands on the
            # wrong token on non-English Windows.
            $match = powercfg -list | Select-String "Balanced|Ausbalanciert" | Select-Object -First 1
            if ($match -and $match.ToString() -match "([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})") {
                $guid = $matches[1]
                powercfg -setactive $guid
                Write-Log "Revert: Power plan set back to Balanced (matched by name, GUID: $guid)"
            } else {
                Write-Log "Revert WARNING: Balanced power plan not found -- could not revert power plan"
            }
        }
        reg delete "HKLM\SOFTWARE\GameOptimizerPro" /v UltimatePerfGuid /f 2>$null
    }
    "Disable HPET (High Precision Event Timer)" = {
        # Remove all three BCD entries instead of forcing useplatformclock=true.
        # The Windows default is that NONE of them are set (the kernel picks the
        # timer source itself); explicitly forcing the platform clock on is a
        # known DPC-latency regression, i.e. worse than the untweaked state.
        bcdedit /deletevalue useplatformclock 2>$null | Out-Null
        bcdedit /deletevalue useplatformtick 2>$null | Out-Null
        bcdedit /deletevalue disabledynamictick 2>$null | Out-Null
        Write-Log "Revert: HPET/timer BCD entries removed (Windows default restored)"
    }
    "Allow Global Timer Resolution (Windows 11)" = {
        reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v GlobalTimerResolutionRequests /f 2>$null
        Write-Log "Revert: Timer resolution key removed (Windows default restored)"
    }
    "Disable Prefetch & Superfetch" = {
        Set-Service SysMain -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service SysMain -ErrorAction SilentlyContinue
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnablePrefetcher /t REG_DWORD /d 3 /f | Out-Null
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnableSuperfetch /t REG_DWORD /d 3 /f | Out-Null
        Write-Log "Revert: SysMain + Prefetch re-enabled"
    }
    "Optimize Visual Effects (Performance Mode)" = {
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 0 /f | Out-Null
        $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Set-ItemProperty $path -Name "TaskbarAnimations" -Value 1 -ErrorAction SilentlyContinue
        reg add "HKCU\Control Panel\Desktop\WindowMetrics" /v MinAnimate /t REG_SZ /d 1 /f | Out-Null
        # Windows 11 defaults for the single effects
        reg add "HKCU\Control Panel\Desktop" /v UserPreferencesMask /t REG_BINARY /d 9E1E078012000000 /f | Out-Null
        reg add "HKCU\Control Panel\Desktop" /v DragFullWindows /t REG_SZ /d 1 /f | Out-Null
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ListviewAlphaSelect /t REG_DWORD /d 1 /f | Out-Null
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ListviewShadow /t REG_DWORD /d 1 /f | Out-Null
        Write-Log "Revert: Visual effects set back to Windows default (takes full effect after signing out and in)"
    }
    "Disable Windows Search Indexing" = {
        Set-Service WSearch -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service WSearch -ErrorAction SilentlyContinue
        Write-Log "Revert: Windows Search Indexing re-enabled"
    }

    # == MOUSE & UI =======================================================
    "Disable Mouse Acceleration" = {
        reg add "HKCU\Control Panel\Mouse" /v MouseSpeed /t REG_SZ /d 1 /f | Out-Null
        reg add "HKCU\Control Panel\Mouse" /v MouseThreshold1 /t REG_SZ /d 6 /f | Out-Null
        reg add "HKCU\Control Panel\Mouse" /v MouseThreshold2 /t REG_SZ /d 10 /f | Out-Null
        Write-Log "Revert: Mouse acceleration restored (Windows default)"
    }
    "Disable Sticky Keys" = {
        reg add "HKCU\Control Panel\Accessibility\StickyKeys" /v Flags /t REG_SZ /d 510 /f | Out-Null
        reg add "HKCU\Control Panel\Accessibility\Keyboard Response" /v Flags /t REG_SZ /d 126 /f | Out-Null
        reg add "HKCU\Control Panel\Accessibility\ToggleKeys" /v Flags /t REG_SZ /d 62 /f | Out-Null
        Write-Log "Revert: Sticky Keys restored (Windows default)"
    }
    "Enable Dark Mode" = {
        reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v AppsUseLightTheme /t REG_DWORD /d 1 /f | Out-Null
        reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v SystemUsesLightTheme /t REG_DWORD /d 1 /f | Out-Null
        Write-Log "Revert: Light Mode restored"
    }
    "Disable Transparency Effects" = {
        reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 1 /f | Out-Null
        Write-Log "Revert: Transparency effects re-enabled"
    }
    "Alt+Tab Without Browser Tabs" = {
        reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v MultiTaskingAltTabFilter /f 2>$null
        Write-Log "Revert: Alt+Tab shows browser tabs again (Windows default)"
    }

    # == GAMING  --  IN-GAME BOOSTS ==========================================
    "Enable Game Mode" = {
        # Back to the Windows default -- and that is Game Mode ON (no value). Writing 0
        # here switched Game Mode off, worse than before the tweak.
        reg delete "HKCU\Software\Microsoft\GameBar" /v AllowAutoGameMode /f 2>$null
        reg delete "HKCU\Software\Microsoft\GameBar" /v AutoGameModeEnabled /f 2>$null
        Write-Log "Revert: Game Mode back to the Windows default (on)"
    }
    "Disable Xbox Game Bar" = {
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 1 /f | Out-Null
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v AllowGameDVR /f 2>$null
        reg delete "HKCU\Software\Microsoft\GameBar" /v UseNexusForGameBarEnabled /f 2>$null
        Write-Log "Revert: Xbox Game Bar re-enabled"
    }
    "CPU Priority for Games (Win32Priority)" = {
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v Win32PrioritySeparation /t REG_DWORD /d 2 /f | Out-Null
        Write-Log "Revert: Win32PrioritySeparation restored to default (2)"
    }
    "MMCSS Gaming Profile (High Priority)" = {
        reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "GPU Priority" /t REG_DWORD /d 8 /f | Out-Null
        reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "Priority" /t REG_DWORD /d 2 /f | Out-Null
        reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "Scheduling Category" /t REG_SZ /d Medium /f | Out-Null
        Write-Log "Revert: MMCSS Gaming profile restored to default"
    }
    "Disable Fullscreen Optimizations" = {
        reg delete "HKCU\System\GameConfigStore" /v GameDVR_FSEBehaviorMode /f 2>$null
        reg delete "HKCU\System\GameConfigStore" /v GameDVR_HonorUserFSEBehaviorMode /f 2>$null
        reg delete "HKCU\System\GameConfigStore" /v GameDVR_FSEBehavior /f 2>$null
        Write-Log "Revert: Fullscreen Optimizations keys removed (Windows default)"
    }
    "Disable Automatic Windows Updates" = {
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /f 2>$null
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /f 2>$null
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v SetActiveHours /f 2>$null
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v ActiveHoursStart /f 2>$null
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v ActiveHoursEnd /f 2>$null
        Write-Log "Revert: Windows Update policies removed (auto-update default restored)"
    }

    # == GAMING  --  GPU & DRIVER ============================================
    "Enable MSI Mode (Message Signaled Interrupts)" = {
        $gpuDev = $Script:GpuObj
        if ($gpuDev) {
            $pnpId   = $gpuDev.PNPDeviceID
            $regPath = "HKLM\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
            # Delete the value rather than writing 0: most current GPU drivers use MSI
            # by default when the value is absent, so forcing 0 would leave the card on
            # line-based interrupts -- worse than the untweaked state. Same convention
            # as the other GPU reverts in this file.
            reg delete "$regPath" /v MSISupported /f 2>$null
            Write-Log "Revert: MSI Mode key removed for $($gpuDev.Name) (driver default)"
        }
    }
    "Enable Hardware-Accelerated GPU Scheduling (HAGS)" = {
        # Back to what was set before the Apply (saved since 1.2.6). Without a saved value the
        # value is removed and Windows decides again -- on current GPUs that is ON (DLSS Frame
        # Generation needs it). Until 1.2.5 this wrote 1 = off.
        $b = Get-RegVal "HKLM:\SOFTWARE\GameOptimizerPro" "HwSchModeBefore"
        if ($null -ne $b -and $b -ne 0) { reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v HwSchMode /t REG_DWORD /d $b /f | Out-Null }
        else { reg delete "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v HwSchMode /f 2>$null }
        reg delete "HKLM\SOFTWARE\GameOptimizerPro" /v HwSchModeBefore /f 2>$null
        Write-Log "Revert: HAGS back to $(if ($null -ne $b -and $b -ne 0) { "the setting from before ($b)" } else { 'the Windows default (value removed)' })"
    }
    "Clear Shader Cache" = {
        Write-Log "Revert: Shader Cache cleared  --  nothing to restore (cache rebuilds automatically)"
    }
    "Increase GPU Timeout Tolerance (TDR)" = {
        reg delete "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v TdrDelay /f 2>$null
        reg delete "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v TdrDdiDelay /f 2>$null
        Write-Log "Revert: TDR timeout keys removed (TdrDelay/TdrDdiDelay)"
    }

    # == NETWORK  --  LATENCY ================================================
    "Disable Nagle's Algorithm (TCPNoDelay)" = {
        $adapters = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\*"
        foreach ($adapter in $adapters) {
            $path = $adapter.PSPath
            Remove-ItemProperty -Path $path -Name "TcpAckFrequency" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $path -Name "TCPNoDelay" -ErrorAction SilentlyContinue
        }
        Write-Log "Revert: Nagle keys removed (default restored)"
    }
    "Disable Large Send Offload (LSO)" = {
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
        foreach ($adapter in $adapters) {
            Enable-NetAdapterLso -Name $adapter.Name -ErrorAction SilentlyContinue
        }
        Write-Log "Revert: LSO re-enabled on all active adapters"
    }
    "Disable Network Throttling Index" = {
        reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v NetworkThrottlingIndex /t REG_DWORD /d 10 /f | Out-Null
        reg delete "HKLM\SOFTWARE\GameOptimizerPro" /v SR_NetworkThrottle /f 2>$null
        # Restore the SHARED SystemResponsiveness to default only if the Audio-priority
        # tweak isn't still relying on it (both tweaks set it to 0).
        if (-not (Get-RegVal "HKLM:\SOFTWARE\GameOptimizerPro" "SR_AudioPriority")) {
            reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v SystemResponsiveness /t REG_DWORD /d 20 /f | Out-Null
        }
        Write-Log "Revert: Network Throttling Index restored to default (10)"
    }

    # == NETWORK  --  DNS ====================================================
    "Set DNS to Cloudflare (1.1.1.1)" = { Reset-ProviderDns 'Cloudflare' @('1.1.1.1', '1.0.0.1', '2606:4700:4700::1111', '2606:4700:4700::1001') }
    "Set DNS to Google (8.8.8.8)"     = { Reset-ProviderDns 'Google' @('8.8.8.8', '8.8.4.4', '2001:4860:4860::8888', '2001:4860:4860::8844') }
    "Flush DNS Cache" = {
        Write-Log "Revert: DNS Flush  --  nothing to restore"
    }

    # == NETWORK  --  TCP ====================================================
    "Disable TCP Auto-Tuning" = {
        netsh int tcp set global autotuninglevel=normal 2>$null | Out-Null
        Write-Log "Revert: TCP Auto-Tuning restored to normal"
    }

    # == NETWORK  --  QOS ====================================================

    # == NETWORK  --  ADAPTER ================================================
    "Disable Network Adapter Power Saving" = {
        $netClass = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
        Get-ChildItem $netClass -ErrorAction SilentlyContinue | ForEach-Object {
            if (Get-ItemProperty $_.PSPath -Name "NetCfgInstanceId" -ErrorAction SilentlyContinue) {
                Remove-ItemProperty -Path $_.PSPath -Name "PnPCapabilities" -Force -ErrorAction SilentlyContinue
            }
        }
        Write-Log "Revert: Network adapter power saving restored to Windows default"
    }
    "Disable Delivery Optimization (P2P Windows Update)" = {
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" /v DODownloadMode /f 2>$null
        Write-Log "Revert: Delivery Optimization (P2P updates) restored to Windows default"
    }
    # Back to each driver's own default (the 'default' in its Ndi\params)
    "Disable Energy-Efficient Ethernet" = {
        foreach ($n in @(Get-NicParams 'EEE')) { if ($null -ne $n.Default) { Set-ItemProperty -Path $n.Path -Name $n.Keyword -Value "$($n.Default)" -Type String -ErrorAction Stop } }
        Write-Log "Revert: Energy-Efficient Ethernet back to the driver default"
    }
    "Disable Interrupt Moderation" = {
        foreach ($n in @(Get-NicParams 'InterruptModeration')) { if ($null -ne $n.Default) { Set-ItemProperty -Path $n.Path -Name $n.Keyword -Value "$($n.Default)" -Type String -ErrorAction Stop } }
        Write-Log "Revert: Interrupt Moderation back to the driver default"
    }

    # == RAM & STORAGE ====================================================
    "Optimize PageFile (System Managed)" = {
        Write-Log "Revert: PageFile was set to System Managed  --  already the Windows default"
    }
    "Clear PageFile on Shutdown" = {
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v ClearPageFileAtShutdown /t REG_DWORD /d 0 /f | Out-Null
        Write-Log "Revert: ClearPageFileAtShutdown set back to 0 (disabled)"
    }
    "Disable Memory Compression" = {
        try {
            Enable-MMAgent -MemoryCompression -ErrorAction Stop
            Write-Log "Revert: Memory Compression re-enabled"
        } catch {
            Write-Log "Revert: Memory Compression re-enable failed: $_"
        }
    }
    "Enable SSD TRIM" = {
        Write-Log "Revert: SSD TRIM is the Windows default  --  no revert needed"
    }
    "Disable Scheduled Defragmentation" = {
        schtasks /Change /TN "\Microsoft\Windows\Defrag\ScheduledDefrag" /Enable 2>$null | Out-Null
        reg delete "HKLM\SOFTWARE\Microsoft\Dfrg\BootOptimizeFunction" /v Enable /f 2>$null
        Write-Log "Revert: Scheduled Defragmentation re-enabled"
    }
    "Disable Write-Cache Buffer Flushing" = {
        $disks = Get-WmiObject -Query "SELECT * FROM Win32_DiskDrive" |
            Where-Object { $_.MediaType -eq 3 -or $_.MediaType -eq 4 -or
                           $_.MediaType -eq 'Fixed hard disk media' -or $null -eq $_.MediaType }
        foreach ($disk in $disks) {
            $pnpId   = $disk.PNPDeviceID
            $regPath = "HKLM\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters\Disk"
            # Remove both values = the drive's own default. Writing 0 to UserWriteCacheSetting
            # turned write caching OFF -- slower than before the tweak.
            reg delete "$regPath" /v CacheIsPowerProtected /f 2>$null
            reg delete "$regPath" /v UserWriteCacheSetting /f 2>$null
        }
        Write-Log "Revert: write-cache buffer flushing back to the Windows default (on)"
    }
    "Disable Hibernation" = {
        powercfg /hibernate on 2>$null | Out-Null
        Write-Log "Revert: Hibernation re-enabled"
    }
    "Clean Temp Files" = {
        Write-Log "Revert: Temp files were deleted  --  nothing to restore"
    }

    # == RAM & STORAGE / DEEP CLEAN (one-time cleanups -- nothing to revert) ==
    "Clean Browser Caches" = {
        Write-Log "Revert: Browser caches were cleared  --  nothing to restore (rebuild automatically)"
    }
    "Clean Windows Update Cache" = {
        Write-Log "Revert: Windows Update cache was cleared  --  Windows re-downloads as needed"
    }
    "Clean Thumbnail Cache" = {
        Write-Log "Revert: Thumbnail cache was cleared  --  Windows rebuilds it automatically"
    }
    "Empty Recycle Bin" = {
        Write-Log "Revert: Recycle Bin was emptied  --  deleted files cannot be restored"
    }
    "Clean Prefetch Data" = {
        Write-Log "Revert: Prefetch data was cleared  --  Windows rebuilds it on next boots"
    }
    "Clean System Logs & Crash Dumps" = {
        Write-Log "Revert: System logs & crash dumps were deleted  --  nothing to restore"
    }

    # == WINDOWS 11 =====================================================
    "Restore Classic Right-Click Menu" = {
        # Only when the tweak is in place -- otherwise "Revert all" restarts Explorer for nothing
        if (-not (Test-Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}")) { Write-Log "Revert: classic right-click menu was not set -- nothing to do"; return }
        reg delete "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" /f 2>$null
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Write-Log "Revert: Win11 new right-click menu restored"
    }
    "Left-Align Taskbar" = {
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarAl /t REG_DWORD /d 1 /f | Out-Null
        Write-Log "Revert: Taskbar alignment set back to center (Win11 default)"
    }
    "Disable Widgets" = {
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarDa /t REG_DWORD /d 1 /f | Out-Null
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /v AllowNewsAndInterests /f 2>$null
        Write-Log "Revert: Widgets re-enabled"
    }
    "Disable Recommended in Start Menu" = {
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v HideRecommendedSection /f 2>$null
        reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_TrackDocs /f 2>$null
        reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_IrisRecommendations /f 2>$null
        Write-Log "Revert: Recommended section in Start Menu re-enabled"
    }
    "Enable End Task in Taskbar" = {
        reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings" /v TaskbarEndTask /f 2>$null
        Write-Log "Revert: End Task in taskbar disabled (key removed)"
    }
    "Disable Snap Layout Hover Menu" = {
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v EnableSnapAssistFlyout /t REG_DWORD /d 1 /f | Out-Null
        Write-Log "Revert: Snap Layout hover menu re-enabled"
    }
    "Disable Dynamic Lighting" = {
        reg add "HKCU\Software\Microsoft\Lighting" /v AmbientLightingEnabled /t REG_DWORD /d 1 /f | Out-Null
        Write-Log "Revert: Dynamic Lighting re-enabled (Windows default)"
    }

    # == AUDIO ============================================================
    "Disable Audio Enhancements" = {
        $n = 0
        foreach ($id in @(Get-AudioRenderIds)) { if ((Set-AudioFx $id 0) -eq 0) { $n++ } }
        Write-Log "Revert: Audio Enhancements re-enabled on $n playback device(s) (Windows audio API)"
    }
    "Optimize MMCSS Audio Profile" = {
        $audioPath = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Audio"
        reg delete $audioPath /v "Latency Sensitive" /f 2>$null      # not there on a stock Windows
        reg add $audioPath /v "Priority" /t REG_DWORD /d 6 /f | Out-Null   # Windows default (2 is the Games task)
        reg add $audioPath /v "Scheduling Category" /t REG_SZ /d "Medium" /f | Out-Null
        reg add $audioPath /v "SFIO Priority" /t REG_SZ /d "Normal" /f | Out-Null
        Write-Log "Revert: MMCSS Audio profile restored to defaults"
    }
    "Set Audio Service High Priority" = {
        reg delete "HKLM\SOFTWARE\GameOptimizerPro" /v SR_AudioPriority /f 2>$null
        # Restore the SHARED SystemResponsiveness to default only if the Network-throttle
        # tweak isn't still relying on it (both tweaks set it to 0).
        if (-not (Get-RegVal "HKLM:\SOFTWARE\GameOptimizerPro" "SR_NetworkThrottle")) {
            reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v SystemResponsiveness /t REG_DWORD /d 20 /f | Out-Null
        }
        Write-Log "Revert: SystemResponsiveness restored (unless still in use by another tweak)"
    }
    "Disable Windows Sound Scheme" = {
        # ".Default" is the scheme KEY of "Windows Default" (that text is only its display
        # name -- the old revert wrote it as the key, which doesn't exist). Copy every
        # event's stock sound from ".Default" back into ".Current".
        reg add "HKCU\AppEvents\Schemes" /ve /t REG_SZ /d ".Default" /f | Out-Null
        $n = 0
        Get-ChildItem "HKCU:\AppEvents\Schemes\Apps" -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.PSChildName -eq ".Current" } |
            ForEach-Object {
                $def = (Get-ItemProperty -Path (Join-Path $_.PSParentPath ".Default") -ErrorAction SilentlyContinue)."(default)"
                if ($null -ne $def) { Set-ItemProperty -Path $_.PSPath -Name "(default)" -Value $def -ErrorAction SilentlyContinue; $n++ }
            }
        Write-Log "Revert: Sound Scheme set back to Windows Default ($n event sounds restored)"
    }

    # == GPU TWEAKS (AMD) =================================================
    "AMD: Disable ULPS (Ultra Low Power State)" = {
        if ($IsAMD) {
            foreach ($k in @(Get-AmdGpuKeys)) {
                Set-ItemProperty -Path $k.PSPath -Name "EnableULPS" -Value 1 -Type DWord -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $k.PSPath -Name "EnableULPS_NA" -Value 1 -Type DWord -ErrorAction SilentlyContinue
            }
            Write-Log "Revert: AMD ULPS re-enabled"
        }
    }

    # == POWER PLAN =======================================================
    "Disable USB Selective Suspend" = {
        $n = Reset-PowerSetting "2a737441-1930-4402-8d77-b2bebba308a3" "48e6b7a6-50f5-4782-a5d4-53bb8f07e226"
        Write-Log "Revert: USB Selective Suspend back to the Windows default of each power plan ($n plan(s))"
    }
    "Disable USB 3 Link Power Management" = {
        $n = Reset-PowerSetting "2a737441-1930-4402-8d77-b2bebba308a3" "d4e98f31-5ffe-4ce1-be31-1b38b384c009"
        Write-Log "Revert: USB 3 link power management back to the Windows default of each power plan ($n plan(s))"
    }
    "Disable PCI-E Link State Power Management" = {
        $n = Reset-PowerSetting "501a4d13-42af-4429-9fd1-a8218c268e20" "ee12f906-d277-404b-b6da-e5fa1a576df5"
        Write-Log "Revert: PCI-E link state power management back to the Windows default of each power plan ($n plan(s))"
    }
    "Disable Hard Disk Sleep" = {
        $n = Reset-PowerSetting "0012ee47-9041-4b5d-9b77-535fba8b1442" "6738e2c4-e8a5-4a42-b16a-e040e769756e"
        Write-Log "Revert: hard disk sleep back to the Windows default of each power plan ($n plan(s))"
    }
    "Set Display Sleep = 15 Minutes" = {
        $n = Reset-PowerSetting "7516b95f-f776-4464-8c53-06167f40cc99" "3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e"
        Write-Log "Revert: display sleep back to the Windows default of each power plan ($n plan(s))"
    }
    "Disable Sleep (System)" = {
        $n = Reset-PowerSetting "238c9fa8-0aad-41ed-83f4-97be242c8f20" "29f6c1db-86da-48c5-9fdb-f2b67b1f44da"
        Write-Log "Revert: system sleep back to the Windows default of each power plan ($n plan(s))"
    }
    "Disable Wake Timers" = {
        $n = Reset-PowerSetting "238c9fa8-0aad-41ed-83f4-97be242c8f20" "bd3b718a-0680-4d9d-8ab2-e1d2b4ac806d"
        Write-Log "Revert: wake timers back to the Windows default of each power plan ($n plan(s))"
    }
    "CPU Minimum Processor State = 100%" = {
        $n = Reset-PowerSetting "54533251-82be-4824-96c1-47b60b740d00" "893dee8e-2bef-41e0-89c6-b55d0929964c"
        Write-Log "Revert: CPU minimum processor state back to the Windows default of each power plan ($n plan(s))"
    }
    "CPU Maximum Processor State = 100%" = {
        $n = Reset-PowerSetting "54533251-82be-4824-96c1-47b60b740d00" "bc5038f7-23e0-4960-96da-33abaf5935ec"
        Write-Log "Revert: CPU maximum processor state back to the Windows default of each power plan ($n plan(s))"
    }
}

# -----------------------------------------
# TWEAK STATUS CHECK FUNCTIONS
# Returns $true = aktiv, $false = nicht aktiv, $null = unbekannt
# -----------------------------------------
# (Get-RegVal is defined at the top -- hardware detection needs it at startup)

# State of a scheduled task via the Task Scheduler COM API (read-only): 'Disabled',
# 'Ready' (= enabled) or $null if the task doesn't exist. Get-ScheduledTask returns
# the same but needs ~350 ms per call (it loads a module and lists every task).
function Get-TaskState([string]$Path, [string]$Name) {
    try {
        if (-not $Script:TaskSvc) { $svc = New-Object -ComObject Schedule.Service; $svc.Connect(); $Script:TaskSvc = $svc }
        $task = $Script:TaskSvc.GetFolder($Path).GetTask($Name)
        if ($task.Enabled) { 'Ready' } else { 'Disabled' }
    } catch { $null }
}

$CheckFunctions = @{

    # BLOATWARE
    # Every package the Apply removes, for every account (Microsoft.XboxGameCallableUI is part of Windows)
    "Remove Xbox Apps"                   = { $pats = Get-XboxPatterns; $null -eq (Get-AppxPackage -AllUsers "Microsoft.Xbox*" -EA Stop | Where-Object { $pats -contains $_.Name -and -not $_.NonRemovable } | Select-Object -First 1) }
    # Check the APP, not the policy: Microsoft marks TurnOffWindowsCopilot as deprecated
    # and it doesn't apply to the new Copilot app -- the policy could stay green while
    # an update had quietly reinstalled Copilot. NonRemovable system packages are
    # skipped because the Apply can't remove them either.
    "Remove Copilot"                     = { $null -eq (Get-AppxPackage -AllUsers "*Copilot*" -EA SilentlyContinue | Where-Object { -not $_.NonRemovable } | Select-Object -First 1) }
    # per-user install (AppData) or machine-wide (Program Files)
    "Remove OneDrive"                    = { -not (@("$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe", "$env:ProgramFiles\Microsoft OneDrive\OneDrive.exe", "${env:ProgramFiles(x86)}\Microsoft OneDrive\OneDrive.exe") | Where-Object { Test-Path $_ }) }
    "Remove Windows Recall"              = { ((Get-RegVal "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis") -eq 1) -and ((Get-RegVal "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "AllowRecallEnablement") -eq 0) }
    # Active when none of the removable apps from the list is installed for any user
    "Remove Other Bloatware"             = { @(Get-BloatApps).Count -eq 0 }
    "Stop Auto-Installed Suggested Apps" = {
        $cdm = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
        ((Get-RegVal $cdm "SilentInstalledAppsEnabled") -eq 0) -and ((Get-RegVal $cdm "OemPreInstalledAppsEnabled") -eq 0) -and ((Get-RegVal $cdm "PreInstalledAppsEnabled") -eq 0)
    }
    "Disable Tips, Ads & Suggestions" = {
        $cdm = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
        $adv = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        $want = @(foreach ($v in 'SoftLandingEnabled', 'FeatureManagementEnabled', 'PreInstalledAppsEverEnabled', 'RotatingLockScreenOverlayEnabled', 'SystemPaneSuggestionsEnabled',
                'SubscribedContent-310093Enabled', 'SubscribedContent-338387Enabled', 'SubscribedContent-338389Enabled', 'SubscribedContent-338393Enabled',
                'SubscribedContent-353694Enabled', 'SubscribedContent-353696Enabled') { , @($cdm, $v) })
        $want += , @("HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement", "ScoobeSystemSettingEnabled")
        $want += , @($adv, "Start_AccountNotifications")
        $want += , @($adv, "ShowSyncProviderNotifications")
        $want += , @("HKCU:\Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications", "EnableAccountNotifications")
        # count what isn't 0 -- "not set" is the Windows default (on) and counts too
        $bad = 0
        foreach ($w in $want) { $v = Get-RegVal $w[0] $w[1]; if (($null -eq $v) -or ($v -ne 0)) { $bad++ } }
        $bad -eq 0
    }
    "Stop OneDrive Folder Backup" = { (Get-RegVal "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive" "KFMBlockOptIn") -eq 1 }
    "Disable Get Started & Copilot Sign-in Screens" = { if (-not (Test-EnterpriseEdition)) { return $null }; ((Get-RegVal "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableGetStarted") -eq 1) -and ((Get-RegVal "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableCopilotPinScreen") -eq 1) }

    # PRIVACY
    "Disable Power Throttling" = { (Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" "PowerThrottlingOff") -eq 1 }
    "Disable Bing in Windows Search" = {
        $ss = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"
        ((Get-RegVal "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions") -eq 1) -and
        ((Get-RegVal $ss "IsDynamicSearchBoxEnabled") -eq 0) -and ((Get-RegVal $ss "IsMSACloudSearchEnabled") -eq 0) -and ((Get-RegVal $ss "IsAADCloudSearchEnabled") -eq 0)
    }
    # Active when the threshold is at least the RAM size (what the Apply writes) and not the Windows
    # default 0x380000 = 3,670,016 KB -- "> 380000" was true on every untouched Windows
    "Process Count Reduction (Svchost)" = { $v = Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Control" "SvcHostSplitThresholdInKB"; $ram = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1024); ($null -ne $v) -and ($ram -gt 0) -and ([int64]$v -ne 3670016) -and ([int64]$v -ge $ram) }
    "Disable Startup App Delay" = { (Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize" "StartupDelayInMSec") -eq 0 }
    "Block Background Apps (Policy)" = { if (Test-HomeEdition) { return $null }; (Get-RegVal "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsRunInBackground") -eq 2 }
    "Stop Background Apps (All Editions)" = { (Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled") -eq 1 }

    # WINDOWS UPDATE
    "Exclude Drivers from Windows Update" = { if (Test-HomeEdition) { return $null }; (Get-RegVal "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "ExcludeWUDriversInQualityUpdate") -eq 1 }
    "Hold Feature Updates (Stay on Current Version)" = {
        if (Test-HomeEdition) { return $null }
        $wu = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        ((Get-RegVal $wu "TargetReleaseVersion") -eq 1) -and [bool](Get-RegVal $wu "TargetReleaseVersionInfo") -and [bool](Get-RegVal $wu "ProductVersion")
    }

    # CTT ESSENTIALS
    "Prevent Device Companion Apps" = { (Get-RegVal "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata" "PreventDeviceMetadataFromNetwork") -eq 1 }
    "Disable Consumer Features" = { if (-not (Test-EnterpriseEdition)) { return $null }; (Get-RegVal "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures") -eq 1 }
    "Disable Windows Platform Binary Table (WPBT)" = { (Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" "DisableWpbtExecution") -eq 1 }
    # Apply puts a Deny ACE for Everyone (SID S-1-1-0) on store.db. SDDL writes
    # Everyone as the locale-independent alias WD, so this works on every language.
    # If Windows doesn't let us read the ACL, the status stays unknown (null).
    "Disable Store Recommended Search Results" = {
        $storeDb = "$env:LocalAppData\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalState\store.db"
        if (-not (Test-Path $storeDb)) { return $null }
        try { [bool]([regex]::IsMatch((Get-Acl -LiteralPath $storeDb -ErrorAction Stop).Sddl, '\(D;[^)]*;;;WD\)')) } catch { $null }
    }
    "Disable File Explorer Automatic Folder Discovery" = { (Get-RegVal "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell" "FolderType") -eq "NotSpecified" }
    "Run Disk Cleanup" = { $null }

    # QUALITY OF LIFE
    "Show File Extensions"               = { (Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt") -eq 0 }
    "Show Hidden Files"                  = { (Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden") -eq 1 }
    "Disable Reserved Storage"           = { try { (Get-WindowsReservedStorageState -ErrorAction Stop).ReservedStorageState -eq "Disabled" } catch { $null } }
    "Disable Storage Sense"              = { (Get-RegVal "HKLM:\Software\Policies\Microsoft\Windows\StorageSense" "AllowStorageSenseGlobal") -eq 0 }
    # Windows rewrites this value at every sign-out with the CURRENT keyboard state
    # ("2" when NumLock was on), so test the NumLock bit (2), not the exact string --
    # comparing against "2147483650" reported the tweak as reverted after every reboot.
    "Num Lock on Startup"                = { $v = Get-RegVal "HKCU:\Control Panel\Keyboard" "InitialKeyboardIndicators"; $n = 0L; if ($null -ne $v -and [int64]::TryParse("$v", [ref]$n)) { ($n -band 2) -ne 0 } else { $false } }
    "Disable Lock Screen"                = { (Get-RegVal "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" "NoLockScreen") -eq 1 }
    "Enable Long Paths"                  = { (Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "LongPathsEnabled") -eq 1 }

    # Both halves of the Apply: Home/Pro treat AllowTelemetry=0 like 1 (0 is Enterprise
    # only), so the stopped DiagTrack service is what really counts there -- an update
    # that turns it back on must show as drift even while the policy value is still set.
    "Disable Telemetry & Data Collection" = { $s = Get-Service DiagTrack -EA SilentlyContinue; ((-not $s) -or $s.StartType -eq "Disabled") -and ((Get-RegVal "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry") -eq 0) }
    "Disable Activity History"           = { (Get-RegVal "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableActivityFeed") -eq 0 }
    "Disable Advertising ID"             = { (Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled") -eq 0 }
    "Disable Text & Image Generation (AI)" = { (Get-RegVal "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessSystemAIModels") -eq 2 }
    "Disable Click to Do & Settings Agent (AI)" = { ((Get-RegVal "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableClickToDo") -eq 1) -and ((Get-RegVal "HKCU:\Software\Policies\Microsoft\Windows\WindowsAI" "DisableClickToDo") -eq 1) -and ((Get-RegVal "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableSettingsAgent") -eq 1) }
    "Disable AI in Paint & Notepad"      = { $p = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint"; ((Get-RegVal $p "DisableCocreator") -eq 1) -and ((Get-RegVal $p "DisableImageCreator") -eq 1) -and ((Get-RegVal $p "DisableGenerativeFill") -eq 1) -and ((Get-RegVal "HKLM:\SOFTWARE\Policies\WindowsNotepad" "DisableAIFeatures") -eq 1) }
    "Disable Location Tracking"          = { $s = Get-Service lfsvc -EA SilentlyContinue; ((Get-RegVal "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" "Value") -eq "Deny") -and ((-not $s) -or $s.StartType -eq "Disabled") }
    # -match on an ARRAY returns the matching lines, not a bool -- the dot logic only
    # understands $true/$false, so this used to show "unknown" forever. Cast to bool,
    # anchor the pattern so a commented-out line doesn't count.
    "Block Telemetry Hosts (hosts file)" = { $h = Get-Content "$env:SystemRoot\System32\drivers\etc\hosts" -EA SilentlyContinue; if ($null -eq $h) { $null } else { [bool](@($h) -match '^\s*0\.0\.0\.0\s+telemetry\.microsoft\.com\s*$') } }
    "Disable Scheduled Telemetry Tasks"  = {
        # Every task this Windows has must be off; the ones it doesn't have (24H2+) don't count
        $st = @(Get-TelemetryTasks | ForEach-Object { $i = $_.LastIndexOf('\'); Get-TaskState $_.Substring(0, $i) $_.Substring($i + 1) } | Where-Object { $_ })
        if (-not $st.Count) { return $null }
        @($st | Where-Object { $_ -ne 'Disabled' }).Count -eq 0
    }
    "Disable Input & Speech Data Collection" = {
        # what every edition reads, plus the feedback policy from Pro up (the Apply writes it there)
        $want = @(
            @("HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy", "HasAccepted", 0),
            @("HKCU:\Software\Microsoft\InputPersonalization", "RestrictImplicitTextCollection", 1),
            @("HKCU:\Software\Microsoft\InputPersonalization", "RestrictImplicitInkCollection", 1),
            @("HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore", "HarvestContacts", 0),
            @("HKCU:\Software\Microsoft\Input\TIPC", "Enabled", 0),
            @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy", "TailoredExperiencesWithDiagnosticDataEnabled", 0),
            @("HKCU:\Software\Microsoft\Siuf\Rules", "NumberOfSIUFInPeriod", 0),
            @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "Start_TrackProgs", 0),
            @("HKCU:\Control Panel\International\User Profile", "HttpAcceptLanguageOptOut", 1))
        if (-not (Test-HomeEdition)) { $want += , @("HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection", "DoNotShowFeedbackNotifications", 1) }
        # count deviations -- a missing value ($null) is a deviation too, never "done"
        @($want | Where-Object { $v = Get-RegVal $_[0] $_[1]; ($null -eq $v) -or ($v -ne $_[2]) }).Count -eq 0
    }
    "Disable Remote Assistance" = { (Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" "fAllowToGetHelp") -eq 0 }

    # PERFORMANCE
    "Ultimate Performance Plan"          = { $g = Get-RegVal "HKLM:\SOFTWARE\GameOptimizerPro" "UltimatePerfGuid"; $a = (powercfg /getactivescheme 2>$null) -join " "; ($g -and $a -match [regex]::Escape($g)) -or ($a -match "Ultimate Performance|Ultimative Leistung") }
    "Disable HPET (High Precision Event Timer)" = {
        # HPET is applied via bcdedit (useplatformtick/disabledynamictick), not the
        # timer-resolution registry key -- so read the real BCD state here. bcdedit
        # prints element names + Yes/No in English regardless of Windows locale.
        $b = bcdedit /enum "{current}" 2>$null
        if (-not $b) { return $null }
        ($b -match 'useplatformtick\s+Yes') -and ($b -match 'disabledynamictick\s+Yes')
    }
    "Allow Global Timer Resolution (Windows 11)"         = { (Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "GlobalTimerResolutionRequests") -eq 1 }
    # SysMain switched off (a stopped service starts again at the next boot) and Prefetch off
    "Disable Prefetch & Superfetch"      = { $s = Get-Service SysMain -EA SilentlyContinue; ((-not $s) -or $s.StartType -eq "Disabled") -and ((Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" "EnablePrefetcher") -eq 0) }
    "Optimize Visual Effects (Performance Mode)" = {
        $adv = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        $m = @(Get-RegVal "HKCU:\Control Panel\Desktop" "UserPreferencesMask")
        ((Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting") -eq 2) -and
        ((Get-RegVal $adv "TaskbarAnimations") -eq 0) -and ((Get-RegVal "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate") -eq "0") -and
        ((Get-RegVal "HKCU:\Control Panel\Desktop" "DragFullWindows") -eq "0") -and ((Get-RegVal $adv "ListviewAlphaSelect") -eq 0) -and ((Get-RegVal $adv "ListviewShadow") -eq 0) -and
        ($m.Count -ge 4) -and ($m[0] -eq 0x90) -and ($m[1] -eq 0x12) -and ($m[2] -eq 0x03) -and ($m[3] -eq 0x80)
    }
    "Disable Windows Search Indexing"    = { (($s=Get-Service WSearch -EA SilentlyContinue) -and $s.StartType -eq "Disabled") }

    # MOUSE & UI
    "Disable Mouse Acceleration"         = { (Get-RegVal "HKCU:\Control Panel\Mouse" "MouseSpeed") -eq "0" }
    "Disable Sticky Keys"                = { (Get-RegVal "HKCU:\Control Panel\Accessibility\StickyKeys" "Flags") -eq "506" }
    "Enable Dark Mode"                   = { (Get-RegVal "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme") -eq 0 }
    "Disable Transparency Effects"       = { (Get-RegVal "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency") -eq 0 }
    "Alt+Tab Without Browser Tabs"       = { (Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "MultiTaskingAltTabFilter") -eq 3 }

    # GAMING IN-GAME
    "Enable Game Mode"                   = { (Get-RegVal "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled") -ne 0 }   # no value = Windows default = on
    "Disable Xbox Game Bar"              = { ((Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled") -eq 0) -and ((Get-RegVal "HKCU:\Software\Microsoft\GameBar" "UseNexusForGameBarEnabled") -eq 0) }
    "CPU Priority for Games (Win32Priority)" = { (Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation") -eq 26 }
    "MMCSS Gaming Profile (High Priority)" = { (Get-RegVal "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Scheduling Category") -eq "High" }
    "Disable Fullscreen Optimizations"   = { (Get-RegVal "HKCU:\System\GameConfigStore" "GameDVR_FSEBehaviorMode") -eq 2 }
    "Disable Automatic Windows Updates" = { (Get-RegVal "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "NoAutoUpdate") -eq 1 }

    # GAMING GPU
    "Enable MSI Mode (Message Signaled Interrupts)" = {
        $g = $Script:GpuObj
        if (-not $g) { return $null }
        (Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Enum\$($g.PNPDeviceID)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties" "MSISupported") -eq 1
    }
    "Enable Hardware-Accelerated GPU Scheduling (HAGS)" = { (Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode") -eq 2 }
    "Clear Shader Cache"                 = { $null }
    "Increase GPU Timeout Tolerance (TDR)"    = { (Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "TdrDelay") -eq 10 }

    # NETWORK
    "Disable Nagle's Algorithm (TCPNoDelay)" = {
        $ifaces = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\*" -EA SilentlyContinue
        ($ifaces | Where-Object { $_.TCPNoDelay -eq 1 } | Select-Object -First 1) -ne $null
    }
    # Network checks: every connected physical adapter (Get-UpAdapters), like the Apply
    "Disable Large Send Offload (LSO)"   = {
        $lso = @(Get-UpAdapters | ForEach-Object { Get-NetAdapterLso -Name $_.Name -EA SilentlyContinue } | Where-Object { $_ })
        if (-not $lso.Count) { return $null }   # no connected adapter offers LSO
        @($lso | Where-Object { $_.IPv4Enabled -or $_.IPv6Enabled }).Count -eq 0
    }
    "Disable Network Throttling Index"   = { (Get-RegVal "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex") -eq 4294967295 }
    # IPv4 AND IPv6: an adapter whose IPv6 DNS still comes from the router only half uses the provider
    "Set DNS to Cloudflare (1.1.1.1)" = {
        $ad = @(Get-UpAdapters); if (-not $ad.Count) { return $null }
        @($ad | Where-Object {
            $v4 = @((Get-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -AddressFamily IPv4 -EA SilentlyContinue).ServerAddresses)
            $v6 = @((Get-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -AddressFamily IPv6 -EA SilentlyContinue).ServerAddresses)
            ($v4 -notcontains "1.1.1.1") -or ($v6.Count -and ($v6 -notcontains "2606:4700:4700::1111"))
        }).Count -eq 0
    }
    # IPv4 AND IPv6: an adapter whose IPv6 DNS still comes from the router only half uses the provider
    "Set DNS to Google (8.8.8.8)" = {
        $ad = @(Get-UpAdapters); if (-not $ad.Count) { return $null }
        @($ad | Where-Object {
            $v4 = @((Get-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -AddressFamily IPv4 -EA SilentlyContinue).ServerAddresses)
            $v6 = @((Get-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -AddressFamily IPv6 -EA SilentlyContinue).ServerAddresses)
            ($v4 -notcontains "8.8.8.8") -or ($v6.Count -and ($v6 -notcontains "2001:4860:4860::8888"))
        }).Count -eq 0
    }
    "Flush DNS Cache"                    = { $null }
    "Disable TCP Auto-Tuning"            = { (Get-NetTCPSetting -SettingName Internet -EA SilentlyContinue).AutoTuningLevelLocal -eq "Disabled" }
    "Disable Network Adapter Power Saving" = {
        # Physical adapters only (NCF_PHYSICAL = 0x4 in Characteristics): virtual ones
        # (WAN Miniport, Wi-Fi Direct, Bluetooth PAN, ...) have no power saving that
        # matters, and some get re-created without the value -- which made the tweak
        # look reverted on every start.
        $netClass = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
        $adapters = @(Get-ChildItem $netClass -ErrorAction SilentlyContinue | Where-Object { (Get-ItemProperty $_.PSPath -Name "NetCfgInstanceId" -EA SilentlyContinue) -and (([int64](Get-RegVal $_.PSPath "Characteristics")) -band 0x4) })
        if (-not $adapters) { return $null }
        $off = @($adapters | Where-Object { (Get-RegVal $_.PSPath "PnPCapabilities") -eq 24 })
        $off.Count -eq $adapters.Count
    }
    "Disable Delivery Optimization (P2P Windows Update)" = { (Get-RegVal "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" "DODownloadMode") -eq 0 }
    # No adapter offers the setting -> unknown (grey), not "inactive"
    "Disable Energy-Efficient Ethernet"  = { $ps = @(Get-NicParams 'EEE'); if (-not $ps.Count) { return $null }; @($ps | Where-Object { $_.Current -ne '0' }).Count -eq 0 }
    "Disable Interrupt Moderation"       = { $ps = @(Get-NicParams 'InterruptModeration'); if (-not $ps.Count) { return $null }; @($ps | Where-Object { $_.Current -ne '0' }).Count -eq 0 }

    # RAM & STORAGE
    "Optimize PageFile (System Managed)" = { (($cs=Get-WmiObject Win32_ComputerSystem -EA SilentlyContinue) -and $cs.AutomaticManagedPagefile -eq $true) }
    "Clear PageFile on Shutdown"         = { (Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "ClearPageFileAtShutdown") -eq 1 }
    "Disable Memory Compression"         = {
        try { $m = Get-MMAgent -EA Stop; -not $m.MemoryCompression } catch { $null }
    }
    # Current Windows prints TWO lines (NTFS + ReFS) -> -match returned an array and the
    # dot stayed "unknown". Read the NTFS line (older builds print a single line).
    "Enable SSD TRIM"                    = {
        $q = @(fsutil behavior query DisableDeleteNotify 2>$null)
        $line = @($q | Where-Object { $_ -match 'NTFS' }) + @($q | Where-Object { $_ -match '=' }) | Select-Object -First 1
        if (-not $line) { $null } else { $line -match '=\s*0\b' }
    }
    "Disable Scheduled Defragmentation"  = { (Get-TaskState "\Microsoft\Windows\Defrag" "ScheduledDefrag") -eq "Disabled" }
    "Disable Write-Cache Buffer Flushing" = {
        # The Apply writes to every fixed disk -- active only if every one has it
        $d = @(Get-WmiObject -Query "SELECT * FROM Win32_DiskDrive" -EA SilentlyContinue | Where-Object { $null -eq $_.MediaType -or $_.MediaType -eq 3 -or $_.MediaType -eq 4 -or $_.MediaType -eq 'Fixed hard disk media' })
        if (-not $d.Count) { return $null }
        $on = @($d | Where-Object { (Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Enum\$($_.PNPDeviceID)\Device Parameters\Disk" "CacheIsPowerProtected") -eq 1 })
        $on.Count -eq $d.Count
    }
    "Disable Hibernation"                = { -not (Test-Path "$env:SystemDrive\hiberfil.sys") }
    "Clean Temp Files"                   = { $null }

    # DEEP CLEAN (one-time actions -- status is always "unknown")
    "Clean Browser Caches"               = { $null }
    "Clean Windows Update Cache"          = { $null }
    "Clean Thumbnail Cache"              = { $null }
    "Empty Recycle Bin"                  = { $null }
    "Clean Prefetch Data"                = { $null }
    "Clean System Logs & Crash Dumps"    = { $null }

    # WINDOWS 11
    "Restore Classic Right-Click Menu"   = { Test-Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" }
    "Left-Align Taskbar"                 = { (Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAl") -eq 0 }
    "Disable Widgets"                    = {
        # The machine policy turns Widgets off completely. On 24H2+ Windows blocks writing
        # TaskbarDa (User Choice Protection Driver), so the policy is what counts there.
        ((Get-RegVal "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests") -eq 0) -or ((Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa") -eq 0)
    }
    "Disable Recommended in Start Menu"  = {
        $adv = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        ((Get-RegVal "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "HideRecommendedSection") -eq 1) -and ((Get-RegVal $adv "Start_TrackDocs") -eq 0) -and ((Get-RegVal $adv "Start_IrisRecommendations") -eq 0)
    }
    "Enable End Task in Taskbar"         = { (Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings" "TaskbarEndTask") -eq 1 }
    "Disable Snap Layout Hover Menu"     = { (Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "EnableSnapAssistFlyout") -eq 0 }
    "Disable Dynamic Lighting"           = { (Get-RegVal "HKCU:\Software\Microsoft\Lighting" "AmbientLightingEnabled") -eq 0 }

    # AUDIO
    "Disable Audio Enhancements"         = {
        # The same devices the Apply writes to (active + unplugged, as Windows sees them),
        # read through the audio service. Count the deviations: 0 (on), -1 (not set = Windows
        # default, on) and -2 (unreadable) all count -- never "-not (...)", a 0 would pass.
        $ids = @(Get-AudioRenderIds)
        if (-not $ids.Count) { return $null }
        @($ids | Where-Object { (Get-AudioFx $_) -ne 1 }).Count -eq 0
    }
    "Optimize MMCSS Audio Profile"       = { (Get-RegVal "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Audio" "Latency Sensitive") -eq "True" }
    # the marker AND the value itself (another program or an update can set it back)
    # the marker AND the value itself: 10 (Windows treats anything below 10 -- the 0 older versions
    # wrote -- like its default 20)
    "Set Audio Service High Priority"    = { ((Get-RegVal "HKLM:\SOFTWARE\GameOptimizerPro" "SR_AudioPriority") -eq 1) -and ((Get-RegVal "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness") -eq 10) }
    "Disable Windows Sound Scheme"       = {
        # Active only if the scheme is ".None" AND no event still points to a sound file
        # (the name alone doesn't silence anything -- see the Apply).
        try {
            if ((Get-ItemProperty "HKCU:\AppEvents\Schemes" -EA Stop)."(default)" -ne ".None") { return $false }
            $loud = Get-ChildItem "HKCU:\AppEvents\Schemes\Apps" -Recurse -EA SilentlyContinue |
                Where-Object { $_.PSChildName -eq ".Current" -and (Get-ItemProperty $_.PSPath -EA SilentlyContinue)."(default)" } |
                Select-Object -First 1
            $null -eq $loud
        } catch { $null }
    }

    # GPU AMD
    "AMD: Disable ULPS (Ultra Low Power State)" = {
        if (-not $IsAMD) { return $null }
        # Check EVERY AMD card that has an EnableULPS value (the Apply writes to all of
        # them). On multi-GPU systems (iGPU + dGPU) checking only the first card would
        # show a false green if another card still has ULPS enabled.
        $vals = @(Get-AmdGpuKeys | ForEach-Object { Get-RegVal $_.PSPath "EnableULPS" } | Where-Object { $null -ne $_ })
        if ($vals.Count -eq 0) { return $null }
        -not ($vals | Where-Object { $_ -ne 0 })
    }

    # POWER PLAN
    # Read ONLY the current AC index (see Get-PowerValueAC) -- searching the whole
    # powercfg output would also hit its static Minimum/Maximum-possible lines.
    "Disable USB Selective Suspend"      = { $v = Get-PowerValueAC "2a737441-1930-4402-8d77-b2bebba308a3" "48e6b7a6-50f5-4782-a5d4-53bb8f07e226"; if ($null -eq $v) { $null } else { $v -eq "00000000" } }
    "Disable USB 3 Link Power Management" = { $v = Get-PowerValueAC "2a737441-1930-4402-8d77-b2bebba308a3" "d4e98f31-5ffe-4ce1-be31-1b38b384c009" -Hidden; if ($null -eq $v) { $null } else { $v -eq "00000000" } }
    "Disable PCI-E Link State Power Management" = { $v = Get-PowerValueAC "SUB_PCIEXPRESS" "ASPM"; if ($null -eq $v) { $null } else { $v -eq "00000000" } }
    "Disable Hard Disk Sleep"            = { $v = Get-PowerValueAC "SUB_DISK" "DISKIDLE"; if ($null -eq $v) { $null } else { $v -eq "00000000" } }
    "Set Display Sleep = 15 Minutes"     = { $v = Get-PowerValueAC "SUB_VIDEO" "VIDEOIDLE"; if ($null -eq $v) { $null } else { $v -eq "00000384" } }
    "Disable Sleep (System)"             = { $v = Get-PowerValueAC "SUB_SLEEP" "STANDBYIDLE"; if ($null -eq $v) { $null } else { $v -eq "00000000" } }
    "Disable Wake Timers"                = { $v = Get-PowerValueAC "SUB_SLEEP" "RTCWAKE"; if ($null -eq $v) { $null } else { $v -eq "00000000" } }
    "CPU Minimum Processor State = 100%" = { $v = Get-PowerValueAC "SUB_PROCESSOR" "PROCTHROTTLEMIN"; if ($null -eq $v) { $null } else { $v -eq "00000064" } }
    "CPU Maximum Processor State = 100%" = { $v = Get-PowerValueAC "SUB_PROCESSOR" "PROCTHROTTLEMAX"; if ($null -eq $v) { $null } else { $v -eq "00000064" } }
}

# -----------------------------------------
# SANITY CHECK
# A $CheckFunctions entry must be a read-only status check, never a copy of
# its $RevertActions entry -- that exact copy-paste mistake once caused
# "Disable Power Throttling", "Disable Bing in Windows Search" and
# "Process Count Reduction (Svchost)" to silently undo themselves every time
# the tweak list was built (i.e. on every app start), with no user action.
# This compares scriptblock bodies at startup and neutralizes (-> returns
# $null / "unknown") any CheckFunction found identical to its RevertAction,
# so a future copy-paste bug can never again execute revert logic as a
# side effect of simply displaying a status dot.
# -----------------------------------------
$Script:SanityCheckFailures = @()
foreach ($key in @($CheckFunctions.Keys)) {
    if ($RevertActions.ContainsKey($key)) {
        $checkBody  = $CheckFunctions[$key].ToString().Trim()
        $revertBody = $RevertActions[$key].ToString().Trim()
        if ($checkBody -eq $revertBody) {
            $Script:SanityCheckFailures += $key
            $CheckFunctions[$key] = { $null }
        }
    }
}
if ($Script:SanityCheckFailures.Count -gt 0) {
    $msg = "SANITY CHECK FAILED: $($Script:SanityCheckFailures.Count) CheckFunctions were identical to their RevertActions and have been neutralized: $($Script:SanityCheckFailures -join ', ')"
    Write-Log $msg
    Write-Host "[$(Get-Date -f 'HH:mm:ss')] $msg" -ForegroundColor Red
}

# -----------------------------------------
# LANGUAGE SUPPORT  --  EN Descriptions
# $TweakDescEN keyed by tweak Name
# -----------------------------------------
$LangState = @{ Current = "EN" }  # Reference type -- shared across all closures
$Script:TweakDots = @{}           # tweakName -> dot Border (for Verify button re-check)

# -----------------------------------------
# CENTRAL UI STRING TABLE  --  full DE/EN switch
# Every static UI label lives here, keyed by string id.
# Get-UIString "id" returns the text in the current language.
# -----------------------------------------
$Script:UIStrings = @{
    # Status bar
    "status_ready"      = @{ EN = "Ready -- pick a preset or tick tweaks, then click 'Apply selected'.";     DE = "Bereit -- Preset wählen oder Tweaks anhaken, dann 'Apply selected' klicken." }

    # Startup Manager
    "sw_title"          = @{ EN = "Startup Manager";       DE = "Autostart-Manager" }
    "sw_col_select"     = @{ EN = "Select";                DE = "Auswahl" }
    "sw_col_name"       = @{ EN = "Name";                  DE = "Name" }
    "sw_col_command"    = @{ EN = "Command";               DE = "Befehl" }
    "sw_col_location"   = @{ EN = "Location";              DE = "Ort" }
    "sw_col_status"     = @{ EN = "Status";                DE = "Status" }
    "sw_col_delay"      = @{ EN = "Boot Delay";            DE = "Boot-Verzögerung" }
    "sw_btn_disable"    = @{ EN = "Disable Selected";      DE = "Auswahl deaktivieren" }
    "sw_btn_enable"     = @{ EN = "Enable Selected";       DE = "Auswahl aktivieren" }
    "sw_btn_refresh"    = @{ EN = "Refresh";               DE = "Aktualisieren" }
    "sw_btn_close"      = @{ EN = "Close";                 DE = "Schliessen" }
    "sw_loading"        = @{ EN = "Loading startup data...";  DE = "Lade Autostart-Daten..." }
    "sw_legend"         = @{ EN = "items  |  Green = fast (<1s)  |  Orange = medium (1-3s)  |  Red = slow (>3s)  |  Hover Boot Delay for details";
                             DE = "Einträge  |  Grün = schnell (<1s)  |  Orange = mittel (1-3s)  |  Rot = langsam (>3s)  |  Boot-Verzögerung für Details" }
    "sw_none_sel"       = @{ EN = "No items selected.";       DE = "Keine Einträge ausgewählt." }
    "sw_disabled_msg"   = @{ EN = "items disabled. Takes effect on next login.";  DE = "Einträge deaktiviert. Wirkt beim nächsten Login." }
    "sw_enabled_msg"    = @{ EN = "items enabled. Takes effect on next login.";   DE = "Einträge aktiviert. Wirkt beim nächsten Login." }

    # Services Manager
    "svc_title"         = @{ EN = "Services Manager";     DE = "Dienste-Manager" }
    "svc_subtitle"      = @{ EN = "Disable unnecessary Windows services for better performance and privacy.";
                             DE = "Deaktiviere unnötige Windows-Dienste für bessere Performance und Datenschutz." }
    "svc_legend_safe"   = @{ EN = "Safe to disable";      DE = "Sicher deaktivierbar" }
    "svc_legend_caution"= @{ EN = "Caution -- system service"; DE = "Vorsicht -- Systemdienst" }
    "svc_legend_done"   = @{ EN = "Already disabled";     DE = "Bereits deaktiviert" }
    "svc_col_sel"       = @{ EN = "Sel";                  DE = "Ausw" }
    "svc_col_name"      = @{ EN = "Service Name";         DE = "Dienstname" }
    "svc_col_desc"      = @{ EN = "Description";          DE = "Beschreibung" }
    "svc_col_status"    = @{ EN = "Status";               DE = "Status" }
    "svc_col_starttype" = @{ EN = "Start Type";           DE = "Starttyp" }
    "svc_col_category"  = @{ EN = "Category";             DE = "Kategorie" }
    "svc_col_safe"      = @{ EN = "Safe";                 DE = "Sicher" }
    "svc_btn_disable"   = @{ EN = "Disable Selected";     DE = "Auswahl deaktivieren" }
    "svc_btn_enable"    = @{ EN = "Enable Selected";      DE = "Auswahl aktivieren" }
    "svc_btn_refresh"   = @{ EN = "Refresh";              DE = "Aktualisieren" }
    "svc_btn_close"     = @{ EN = "Close";                DE = "Schliessen" }
    "svc_found"         = @{ EN = "services found  |  Green = safe to disable  |  Red = system service (caution)";
                             DE = "Dienste gefunden  |  Grün = sicher deaktivierbar  |  Rot = Systemdienst (Vorsicht)" }
    "svc_none_sel"      = @{ EN = "No services selected.";  DE = "Keine Dienste ausgewählt." }
    "svc_disabled_msg"  = @{ EN = "service(s) disabled. Full effect after restart.";  DE = "Dienst(e) deaktiviert. Wirkt nach Neustart vollstaendig." }
    "svc_enabled_msg"   = @{ EN = "service(s) back to the start type they had before (Manual if unknown).";  DE = "Dienst(e) auf die vorherige Starteinstellung zurückgesetzt (Manuell, wenn unbekannt)." }

    # Status words (managers)
    "word_enabled"      = @{ EN = "Enabled";      DE = "Aktiviert" }
    "word_disabled"     = @{ EN = "Disabled";     DE = "Deaktiviert" }
    "word_running"      = @{ EN = "Running";      DE = "Laeuft" }
    "word_stopped"      = @{ EN = "Stopped";      DE = "Gestoppt" }
    "word_automatic"    = @{ EN = "Automatic";    DE = "Automatisch" }
    "word_manual"       = @{ EN = "Manual";       DE = "Manuell" }
    "word_unknown"      = @{ EN = "Unknown";      DE = "Unbekannt" }
}

function Get-UIString {
    param([string]$Id)
    # UI language is permanently English. The DE/EN toggle only affects the
    # "?" info-popup descriptions, not the interface labels.
    if ($Script:UIStrings.ContainsKey($Id)) {
        return $Script:UIStrings[$Id]["EN"]
    }
    return $Id
}

$TweakDescEN = @{
    "Disable Power Throttling"            = "Prevents Windows from throttling processes for energy savings (EcoQoS). Useful for games with multiple processes -- background game processes are no longer throttled."
    "Disable Bing in Windows Search" = "Disables Bing integration in Windows Search. Start menu searches only locally -- faster, no data exchange with Microsoft on every search. Also off: search highlights (changing pictures and topics in the search box) and cloud content search in OneDrive, Outlook and Bing for Microsoft and work/school accounts (Settings > Privacy > Search permissions)."
    "Process Count Reduction (Svchost)"   = "Sets the Svchost split threshold to your RAM size. Windows combines services into fewer separate processes -- noticeably reduces background process count. WARNING: reduces process isolation -- if one service crashes it can take down others in the same host (audio, network etc.). Reboot recommended."
    "Block Background Apps (Policy)" = "Pro and up only: an official policy stops Store apps (e.g. WhatsApp, Phone Link, Mail, Weather) from running in the background -- saves RAM and background load. WARNING: their notifications (e.g. new WhatsApp messages or texts through Phone Link) only arrive while the app is open. Regular programs (Steam, Discord, driver tools) are not affected. Windows Home doesn't read the policy -- greyed out there."
    "Stop Background Apps (All Editions)" = "Store apps (e.g. WhatsApp, Phone Link, Mail, Weather) may no longer run in the background for your user account -- the old 'Let apps run in the background' switch Windows 11 no longer shows (there is only the per-app setting otherwise). Works on every edition, Home included; from Pro up the same is done by policy with 'Block Background Apps (Policy)'. WARNING: notifications of these apps (e.g. new WhatsApp messages) only arrive while the app is open. Normal programs (Steam, Discord, driver tools) are not affected. Takes effect after signing out and in."
    "Exclude Drivers from Windows Update" = "Pro and up only: Windows Update no longer installs drivers (official policy 'Do not include drivers with Windows Updates'). Stops Windows from replacing, say, your freshly installed graphics driver with an older one. You then get drivers from the maker yourself (NVIDIA App, AMD Software, the board's website). Security and feature updates keep coming. No effect on Home -- greyed out there."
    "Hold Feature Updates (Stay on Current Version)" = "Pro and up only: keeps Windows on the installed version (e.g. 26H2) -- the next big feature update is not installed automatically. Monthly security updates keep coming. The version is read when you apply, never hard-coded. Important: every Windows version only gets updates for a limited time (Home and Pro 24 months) -- revert in time so you are not left without security updates. No effect on Home -- greyed out there."
    "Disable Automatic Windows Updates" = "Windows no longer downloads and installs updates on its own -- security updates included. They only come when you click 'Check for updates' under Settings > Windows Update yourself. Also sets active hours 8:00 to 2:00 (no automatic restart in that time). Stops downloads and restarts while gaming, but: if you don't check for updates yourself regularly, you go without security updates. If you only want no restarts while gaming, set just the active hours (Settings > Windows Update > Advanced options). In no preset."
    "Prevent Device Companion Apps"       = "Stops Windows from downloading device metadata from the network and auto-installing or suggesting companion apps for connected devices. Saves background traffic and unwanted app installs."
    "Disable Consumer Features" = "Enterprise / Education only: sets the official 'Turn off Microsoft consumer experiences' policy (1:1 from WinUtil). According to Microsoft, Home and Pro don't read it -- greyed out there; on those editions 'Stop Auto-Installed Suggested Apps' (Windows tab, Bloatware) stops the silent installs of suggested apps."
    "Disable Windows Platform Binary Table (WPBT)" = "Disables execution of the Windows Platform Binary Table, preventing motherboard/OEM firmware from silently injecting programs into Windows at every boot. Pure security tweak."
    "Disable Store Recommended Search Results" = "Locks the Microsoft Store's store.db via file permissions so the Store stops showing recommended/sponsored search results. Fully reversible."
    "Disable File Explorer Automatic Folder Discovery" = "Sets every folder to 'General items' so Explorer stops auto-detecting folder types -- opens large folders noticeably faster. Sign out / restart required."
    "Run Disk Cleanup"                    = "Runs Windows Disk Cleanup automatically (cleanmgr /VERYLOWDISK) and additionally cleans up old Windows Update components via DISM. One-time action, can take 5-15 minutes -- the window stays usable and the status bar counts the seconds."
    "Show File Extensions"                        = "Shows file extensions in Explorer (e.g. .exe, .txt, .jpg). Important for security -- disguised files like 'photo.jpg.exe' become immediately visible."
    "Show Hidden Files"                           = "Shows hidden files and folders in Explorer. Useful for seeing AppData, config files and hidden folders."
    "Disable Reserved Storage"                    = "Disables the reserved storage Windows sets aside for updates (~7 GB). Frees that space on the system drive. Windows then manages updates dynamically."
    "Disable Storage Sense"                       = "Disables Storage Sense (automatic disk cleanup). Windows will no longer delete temp files or Recycle Bin contents on its own -- you keep full control."
    "Num Lock on Startup"                         = "Enables NumLock automatically at system startup and on the login screen. Handy if you want to use the numpad right away."
    "Disable Lock Screen"                         = "Disables the lock screen. On start/wake it goes straight to the login field -- saves a click or swipe."
    "Enable Long Paths"                           = "Enables paths longer than 260 characters. Helpful for deep folder structures, game mods, Node projects etc. -- prevents 'path too long' errors."
    "Remove Xbox Apps" = "Removes the Xbox Game Bar, Xbox Identity Provider, Xbox TCUI and the speech overlay (on Windows 10 also the old Xbox app). These apps run in the background even without an Xbox. WARNING: afterwards the Xbox sign-in for Game Pass and Microsoft Store games (Xbox Identity Provider), Xbox mode and Game Bar recordings are missing until you reinstall the apps from the Microsoft Store. The Xbox app itself (Game Pass) stays. Steam, Epic and other games keep working."
    "Remove Copilot"                              = "Disables and removes Windows Copilot AI assistant. Prevents Copilot from running in the background and sending data."
    "Remove OneDrive"                             = "Completely uninstalls OneDrive including autostart and Explorer integration. Local files remain untouched."
    "Remove Windows Recall"                       = "Disables AND removes Windows Recall  --  the AI feature that takes screenshots of your activity. Uses Microsoft's official policies: snapshots off + Recall component removed from the system (existing snapshots are deleted). Restart required."
    "Remove Other Bloatware"                      = "Removes pre-installed apps Windows or the PC maker put there: Candy Crush and other promoted games, News, Weather, Solitaire, Clipchamp, Microsoft To Do, Feedback Hub, Tips, Power Automate and the Mixed Reality Portal. The confirmation before applying lists which of them are on your PC. Apps you installed yourself (Spotify, Netflix, Instagram ...), the Media Player and Get Help stay. The apps come back through the Microsoft Store."
    "Stop Auto-Installed Suggested Apps"          = "Stops Windows from silently installing suggested apps and games (e.g. Candy Crush, TikTok), including the ones planned by the PC maker and Microsoft. Works on every edition including Home and Pro. Apps already installed stay -- use 'Remove Other Bloatware' for those."
    "Disable Tips, Ads & Suggestions" = "Turns off the ads, tips and suggestions Windows sprinkles everywhere: tip notifications, the 'finish setting up' pages and the welcome page after updates, suggestions in Settings and Start, account notices (Microsoft 365, OneDrive backup) in Start and Settings, and sync-provider ads in File Explorer. Windows Spotlight pictures on the lock screen stay, only the tips on them go -- the tweak deliberately leaves the master switch 'ContentDeliveryAllowed' alone, because it is not documented whether it also turns Spotlight off. Works on every edition. Recommendations in Start: 'Disable Recommended in Start Menu'."
    "Stop OneDrive Folder Backup" = "Uses the official OneDrive policy to stop OneDrive from moving Desktop, Documents and Pictures into the cloud ('folder backup') -- not even after asking during setup. Works on every edition. Folders that are already backed up stay in OneDrive; you get them back in OneDrive under Settings > Sync and backup. Without OneDrive installed nothing visible changes, but the policy applies if OneDrive comes back."
    "Disable Get Started & Copilot Sign-in Screens" = "Enterprise / Education only: the 'Get Started' app no longer launches automatically, and the Microsoft 365 Copilot setup promotion at sign-in is gone (that second policy only exists in Insider builds so far). According to Microsoft, Home and Pro ignore both policies -- there the tweak changes nothing and its status stays grey. Copilot itself stays usable."
    "Disable Telemetry & Data Collection"         = "Disables all Windows telemetry services (DiagTrack, dmwappushservice). Windows stops sending usage data to Microsoft."
    "Disable Activity History"                    = "Disables Windows Timeline/Activity History. Windows stops tracking which apps and files you open."
    "Disable Advertising ID"                      = "Disables the advertising ID Windows assigns each user. Apps can no longer track you across devices for targeted ads."
    "Disable Text & Image Generation (AI)"        = "Disables device-wide Text and Image Generation (on-device generative AI) for all apps via policy (Force Deny). Affects only local on-device AI, not cloud AI services."
    "Disable Click to Do & Settings Agent (AI)"   = "Turns off 'Click to Do' (AI that takes a screenshot on demand and analyzes what's on screen) and the AI agent in the Settings search (new in 26H2). Official Microsoft policies. Both only run on Copilot+ PCs with an NPU -- harmless on other PCs. Note: Click to Do is turned off on every edition; according to Microsoft, Windows only honours the Settings-agent policy on Enterprise/Education - on Home/Pro the agent stays on."
    "Disable AI in Paint & Notepad"               = "Disables the AI features in Paint (Cocreator, Image Creator, Generative Fill) and in Notepad (Copilot rewrite/summarize) via Microsoft's official policies. Both apps keep working normally."
    "Disable Location Tracking"                   = "Disables the Windows location service system-wide. Apps can no longer request your location."
    "Block Telemetry Hosts (hosts file)"          = "Adds Microsoft telemetry servers to the Windows hosts file, blocking them even if telemetry services are still running. Note: Microsoft Defender reports such entries as 'HostsFileHijack' and may remove them again - the status shows it if that happens."
    "Disable Scheduled Telemetry Tasks" = "Disables the scheduled Windows tasks that collect and send telemetry and usage data: the compatibility appraiser and the other compatibility tasks (MareBackup, PcaPatchDbTask, StartupAppTask), the Customer Experience Improvement Program (CEIP), disk diagnostics, feedback prompts, the upload of collected error reports and the power efficiency analysis. Tasks this Windows doesn't have are skipped. A big Windows update can switch single ones back on -- the drift check reports it."
    "Disable Input & Speech Data Collection" = "Turns off data collection for input and speech, as under Settings > Privacy: online speech recognition, inking & typing personalization (Windows no longer learns from your typing, handwriting and contacts), 'improve inking and typing', tailored experiences with diagnostic data and feedback prompts (frequency 'Never', from Pro also by policy). Websites can no longer read your language list, and Windows stops tracking which apps you start -- so 'Most used' in Start stays empty. Dictation with Win+H can be limited without online speech recognition. Works on every edition."
    "Disable Remote Assistance" = "Turns off Windows Remote Assistance (System Properties > Remote: 'Allow Remote Assistance connections to this computer'). Nobody can connect to your PC through an invitation any more. Remote Desktop, the Quick Assist app and tools like AnyDesk or TeamViewer are not affected. Works on every edition."
    "Ultimate Performance Plan"                   = "Activates the 'Ultimate Performance' power plan and sets it to always-on: Windows stops throttling CPU cores AND the PC no longer sleeps -- display, disks and system stay on (no timeout). Maximum performance at all times. Increases power consumption."
    "Disable HPET (High Precision Event Timer)"   = "Disables the High Precision Event Timer. Can reduce system latency and improve gaming performance on some systems with lower frame times."
    "Allow Global Timer Resolution (Windows 11)"                  = "Since Windows 10 2004 a raised timer resolution only applies to the program that requests it - on Windows 11 not even while that program is minimized. This restores the old system-wide behavior. It is the prerequisite for timer tools such as TimerResolution or ISLC; it does NOT set a resolution by itself - games request their ~1 ms anyway. Restart required."
    "Disable Prefetch & Superfetch"               = "Disables Prefetch and SysMain (Superfetch). Recommended for SSDs  --  not for HDDs. Reduces background disk writes and RAM usage."
    "Optimize Visual Effects (Performance Mode)" = "Turns off the Windows animations and visual effects like 'Adjust for best performance' (System Properties > Performance Options): window, menu and taskbar animations, fades, shadows under windows and the mouse pointer, window contents while dragging, the translucent selection rectangle and icon label shadows. Font smoothing (ClearType) stays on so text stays sharp. Takes full effect after signing out and in again. Windows feels noticeably snappier, especially on weaker systems."
    "Disable Startup App Delay" = "Windows starts autostart programs a few seconds after you sign in. With this tweak they start right away -- Discord, Steam and co. are there sooner, the desktop is a little slower in the first seconds instead. Not officially documented, but confirmed by users up to Windows 11 26H2; a big Windows update can remove the value (the drift check reports it). Works on every edition."
    "Disable Windows Search Indexing"             = "Disables the Windows Search Indexer (WSearch). Reduces constant background disk activity. Search still works but slower without index."
    "Disable Mouse Acceleration"                  = "Disables mouse acceleration (Enhance Pointer Precision). Essential for FPS games: mouse movement maps 1:1 without dynamic amplification."
    "Disable Sticky Keys"                         = "Disables the Sticky Keys dialog (triggered by pressing Shift 5 times). Prevents unwanted interruptions mid-game."
    "Enable Dark Mode"                            = "Enables dark mode for Windows and apps system-wide. Easier on the eyes during long gaming sessions, especially at night."
    "Disable Transparency Effects"                = "Disables transparency effects in taskbar and Start menu. Saves GPU resources and slightly reduces RAM usage."
    "Alt+Tab Without Browser Tabs" = "Alt+Tab shows windows only, no single Edge tabs any more (Settings > System > Multitasking > 'Show tabs from apps when snapping or pressing Alt+Tab': don't show tabs). Works on every edition."
    "Enable Game Mode"                            = "Enables Windows Game Mode. Windows prioritizes CPU/GPU resources for the active game and suppresses Windows Update restarts while gaming."
    "Disable Xbox Game Bar" = "Disables the Xbox Game Bar (Win+G overlay). Prevents the Game Bar from running in the background consuming resources. The Xbox button on a controller no longer opens the Game Bar. Game Mode remains unaffected."
    "CPU Priority for Games (Win32Priority)"      = "Sets Win32PrioritySeparation to 26. Windows gives active games significantly more CPU time and reduces background process priority."
    "MMCSS Gaming Profile (High Priority)"        = "Sets Multimedia Class Scheduler (MMCSS) profiles for games to High Priority. Better audio and timer interrupt handling while gaming."
    "Disable Fullscreen Optimizations"            = "Disables Windows Fullscreen Optimizations globally. Forces true exclusive fullscreen for lower input lag in games."
    "Enable MSI Mode (Message Signaled Interrupts)" = "Enables MSI mode for the primary GPU. Significantly reduces interrupt latency compared to Line-Based Interrupts. Reboot recommended."
    "Enable Hardware-Accelerated GPU Scheduling (HAGS)" = "Enables HAGS -- Windows hands GPU scheduling directly to the hardware instead of the software. Reduces CPU overhead and slightly lowers input lag. Needs NVIDIA RTX 2000+ or AMD RX 5000+ and Windows 10 2004+. Usually on already on current Windows 11 PCs; DLSS Frame Generation needs it. Revert puts back what was set before."
    "Clear Shader Cache"                          = "Clears the NVIDIA/AMD shader cache on disk. Forces fresh shader compilation on next game launch. Useful after driver updates or graphical glitches."
    "Increase GPU Timeout Tolerance (TDR)"             = "Raises the GPU timeout tolerance (TDR delay 2s -> 10s) so Windows doesn't reset the graphics driver prematurely when the GPU stalls briefly under heavy load. Reduces black-screens / driver resets in demanding games and when overclocking. Note: improves stability, not FPS."
    "Disable Nagle's Algorithm (TCPNoDelay)"      = "Disables Nagle's Algorithm on all network adapters. Nagle buffers small packets at the cost of latency. Disabling noticeably reduces ping in online games."
    "Disable Large Send Offload (LSO)"            = "Disables Large Send Offload on all active network adapters. Can reduce ping spikes on some systems in online games."
    "Disable Network Throttling Index"            = "Disables Windows' network throttling index, which slows down network packets under high CPU load. Most useful for latency-sensitive gaming while the CPU is busy. Also sets SystemResponsiveness to 10 (the smallest value Windows accepts; smaller values are treated like 20)."
    "Set DNS to Cloudflare (1.1.1.1)"            = "Sets DNS to Cloudflare 1.1.1.1 / 1.0.0.1 (IPv4) plus the matching IPv6 servers (2606:4700:4700::1111/::1001) so IPv6 lookups also go through Cloudflare. One of the fastest and most privacy-friendly DNS providers worldwide. Revert brings back the DNS servers you had before (e.g. a Pi-hole) -- or automatic."
    "Set DNS to Google (8.8.8.8)"                = "Sets DNS to Google 8.8.8.8 / 8.8.4.4 (IPv4) plus the matching IPv6 servers (2001:4860:4860::8888/::8844) so IPv6 lookups also go through Google. Globally distributed, fast and reliable. Alternative to Cloudflare. Revert brings back the DNS servers you had before (e.g. a Pi-hole) -- or automatic."
    "Flush DNS Cache"                             = "Clears the local DNS cache. Useful after DNS changes or connection issues. Fast and has no side effects."
    "Disable TCP Auto-Tuning"                     = "Turns off the automatic size of the TCP receive window -- it then stays at 64 KB. WARNING: this slows downloads down a lot: at 20 ms ping at most about 26 Mbit/s, at 40 ms about 13 Mbit/s -- no matter how fast your connection is. It brings nothing measurable for the ping in games. Only for testing when a router or network has trouble with auto-tuning; in no preset."
    "Disable Network Adapter Power Saving"        = "Disables 'Allow the computer to turn off this device to save power' for all physical network adapters (Ethernet, Wi-Fi). Prevents dropped connections and latency spikes caused by adapter power management."
    "Disable Energy-Efficient Ethernet"           = "Turns off Energy-Efficient Ethernet (EEE, 'Green Ethernet') on every wired adapter that offers it. With EEE the link drops into a power-saving state during pauses and has to wake up for the next packet, which can cause small latency spikes. Costs practically nothing on a desktop. Only settings the driver itself offers are changed. Takes effect after a restart."
    "Disable Interrupt Moderation"                = "The network adapter reports every packet right away instead of collecting several and reporting them together. Lowers network latency by a fraction of a millisecond, but causes noticeably more CPU load at high download rates. Meant for online games - if you often download big files or stream, better leave it on. Only settings the driver itself offers are changed. Takes effect after a restart."
    "Disable Delivery Optimization (P2P Windows Update)" = "Disables Windows Delivery Optimization. Windows only downloads updates directly from Microsoft instead of sharing bandwidth with other PCs on your network/the internet (P2P). Prevents unexpected bandwidth usage while gaming."
    "Optimize PageFile (System Managed)"          = "Sets the pagefile to system managed. Windows dynamically adjusts it to RAM needs  --  prevents both too-small and too-large pagefiles."
    "Clear PageFile on Shutdown"                  = "Clears the pagefile on every shutdown. Prevents sensitive data from remaining on disk after reboot. Good for privacy."
    "Disable Memory Compression"                  = "Disables RAM compression in Windows. Saves CPU cycles during gaming. Recommended when you have enough RAM (16GB+)."
    "Enable SSD TRIM"                             = "Enables TRIM for all connected SSDs. Informs the SSD about unused blocks  --  maintains SSD performance long-term and extends lifespan."
    "Disable Scheduled Defragmentation"           = "Turns off the weekly 'Optimize drives' task. On hard disks (HDD) that is defragmentation, on SSDs only a 'retrim' that tells the SSD which blocks are free -- Windows does not defragment SSDs. Only useful if you want to start the optimization yourself (Optimize drives > Optimize); not recommended for SSDs. In no preset."
    "Disable Write-Cache Buffer Flushing"         = "Disables forced write-cache buffer flushing for SSDs. Noticeably improves write speed (same as the checkbox in Device Manager). If the power fails, data not yet written can be lost - desktop PCs with stable power or a UPS only."
    "Disable Hibernation"                         = "Disables hibernate and deletes hiberfil.sys. Frees several GB of disk space (about 40 % of your RAM). Fast Startup goes off too -- it needs hibernation; Windows then shuts down completely and starts a few seconds slower. Recommended for desktop PCs."
    "Clean Temp Files"                            = "Deletes all files in %TEMP%, Windows\Temp and Prefetch folders. Frees disk space and can slightly speed up boot."
    "Clean Browser Caches"                        = "Clears the caches of Chrome, Edge and Firefox (cache only -- no passwords/history/bookmarks). Often frees several hundred MB. Browsers should be closed."
    "Clean Windows Update Cache"                   = "Deletes the downloaded Windows Update cache (SoftwareDistribution\Download). Safe -- Windows re-downloads as needed. The update service is briefly stopped and restarted."
    "Clean Thumbnail Cache"                        = "Deletes the Explorer thumbnail database. Windows rebuilds it on demand. Fixes broken/outdated thumbnails and frees space."
    "Empty Recycle Bin"                           = "Permanently empties the Recycle Bin on all drives. Warning: deleted files can no longer be recovered afterwards."
    "Clean Prefetch Data"                         = "Deletes the Prefetch files (.pf). Windows rebuilds them on the next boot. Can help with stale entries -- the first boot afterwards is marginally slower."
    "Clean System Logs & Crash Dumps"             = "Deletes Windows temp, CBS logs, crash dumps and error-report files. Purely diagnostic data -- safe to remove, often frees noticeable space."
    "Restore Classic Right-Click Menu"            = "WIN11: Restores the Windows 10 classic right-click menu. No more 'Show more options' click needed to access common options."
    "Left-Align Taskbar"                          = "WIN11: Moves taskbar icons to the left like Windows 10. Windows 11 centers icons by default. Takes effect after Explorer restart."
    "Disable Widgets"                             = "WIN11: Disables the Widgets panel (Weather, News, Stocks). Widgets run as an MSN browser process in the background consuming RAM."
    "Disable Recommended in Start Menu" = "WIN11: Empties the 'Recommended' section in Start on every edition: no recently opened files and no tips or app recommendations (this also clears 'Recent' in File Explorer and the taskbar jump lists). Hiding the section completely takes a policy -- according to Microsoft from Pro up; on Home the empty section stays."
    "Enable End Task in Taskbar"                  = "WIN11: Enables 'End Task' directly in the taskbar right-click menu. Kill unresponsive processes without opening Task Manager."
    "Disable Snap Layout Hover Menu"              = "WIN11: Disables the Snap Layout popup when hovering over the maximize button. Prevents accidental snapping while gaming."
    "Disable Dynamic Lighting" = "WIN11: Turns off Windows Dynamic Lighting (Settings > Personalization > Dynamic Lighting). Otherwise Windows takes control of RGB keyboards, mice and lighting and can fight the maker's software (iCUE, Armoury Crate, G HUB, SignalRGB) -- effects flicker or get overwritten. Leave it on if you control RGB through Windows only."
    "Disable Audio Enhancements" = "Turns off audio enhancements (Bass Boost, surround, equalizer, loudness equalization) for all connected playback devices -- through the Windows audio interface, like the Sound control panel. Windows 11 blocks the direct registry route, so older versions of this tweak changed nothing. Reduces audio latency and audiodg.exe CPU load. Devices you connect later: apply again (the drift check reports them)."
    "Optimize MMCSS Audio Profile"                = "Optimizes Multimedia Class Scheduler profile for audio. Sets Latency Sensitive with High scheduling priority. Reduces audio stuttering under CPU load."
    "Set Audio Service High Priority"             = "Gives audio, games and other multimedia tasks more CPU time: SystemResponsiveness goes from 20 to 10, so Windows reserves only 10 % instead of 20 % of the CPU for background tasks. 10 is the smallest value Windows accepts -- smaller values (0 in older versions) are treated like 20 according to Microsoft, i.e. like no tweak at all. Helps against audio dropouts while other processes load the CPU -- noticeable when gaming and streaming at once."
    "Disable Windows Sound Scheme"                = "Disables all Windows system sounds (startup, errors, notifications). No unexpected sound interruptions during gaming or streaming."
    "AMD: Disable ULPS (Ultra Low Power State)"   = "AMD only: Disables Ultra Low Power State. ULPS puts inactive GPUs into extreme power saving and can cause stuttering on wake. Also useful for single GPU."
    "Disable USB Selective Suspend"               = "Disables USB Selective Suspend globally. Windows no longer puts USB devices to sleep. Prevents disconnections with USB mice, headsets and controllers under load."
    "Disable USB 3 Link Power Management" = "Turns off the power-saving states of USB 3 links (U1/U2) in every power plan. The link to USB 3 devices (headset DACs, capture cards, external SSDs, VR headsets) no longer has to wake up first -- helps against dropouts and short stutters. Complements 'Disable USB Selective Suspend' (that one puts whole devices to sleep, this one only the link). Windows hides this setting in Power Options. Slightly higher power use."
    "Disable PCI-E Link State Power Management"   = "Disables PCI-E ASPM. Prevents the GPU from putting its PCI Express connection into power saving mode. Reduces GPU latency spikes under load."
    "Disable Hard Disk Sleep"                     = "Sets disk sleep timeout to never (0). Prevents the known stuttering after inactivity when an HDD/SSD wakes from sleep."
    "Set Display Sleep = 15 Minutes"              = "Sets monitor sleep timer to 15 minutes (AC) and 5 minutes (battery). Prevents monitor from turning off mid-game while still saving power on breaks."
    "Disable Sleep (System)"                      = "Completely disables system sleep mode. The PC never sleeps after inactivity. Recommended for desktop PCs running downloads or servers in the background."
    "Disable Wake Timers" = "Scheduled tasks (e.g. restarts after Windows updates and automatic maintenance) can no longer wake the PC from sleep -- no more PC that starts up by itself at night. Waking by mouse, keyboard or network (Wake-on-LAN) still works. Applies to every power plan; only matters if the PC goes to sleep."
    "CPU Minimum Processor State = 100%"          = "Sets minimum CPU state to 100%. CPU always runs at full clock speed without throttling. Eliminates the brief ramp-up delay from idle  --  important for consistent FPS."
    "CPU Maximum Processor State = 100%"          = "Sets maximum CPU state to 100%. Ensures Windows never artificially caps the CPU. Relevant on laptops and systems with aggressive thermal policies."
}
# -----------------------------------------
foreach ($p in $logPaths) { try { "[$(Get-Date -f 'HH:mm:ss')] Tweaks definiert ($($AllTweaks.Count) Stück)" | Out-File $p -Append -ErrorAction SilentlyContinue } catch { } }
Write-Host "[$(Get-Date -f 'HH:mm:ss')] Tweaks definiert ($($AllTweaks.Count) Stück)" -ForegroundColor DarkGray
foreach ($p in $logPaths) { try { "[$(Get-Date -f 'HH:mm:ss')] XAML wird geladen..." | Out-File $p -Append -ErrorAction SilentlyContinue } catch { } }
Write-Host "[$(Get-Date -f 'HH:mm:ss')] XAML wird geladen..." -ForegroundColor DarkGray
Set-Splash "Building the interface ..." 22

[xml]$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="GameOptimizerPro v$($Script:AppVersion) -- by FloDePin"
        Width="1360" Height="880" MinWidth="1120" MinHeight="680"
        WindowStartupLocation="CenterScreen" Background="#0b0e13" FontFamily="Segoe UI"
        TextOptions.TextFormattingMode="Display" UseLayoutRounding="True">

    <Window.Resources>
        <!-- Design tokens follow GameOptimizerPro v2.1 (ui/theme.py) -->
        <Style TargetType="Button" x:Key="GopBtn">
            <Setter Property="Background" Value="#1b212b"/>
            <Setter Property="Foreground" Value="#e6edf3"/>
            <Setter Property="BorderBrush" Value="#313b4a"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Padding" Value="14,7"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="9" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Bd" Property="Opacity" Value="0.86"/></Trigger>
                            <Trigger Property="IsPressed" Value="True"><Setter TargetName="Bd" Property="Opacity" Value="0.7"/></Trigger>
                            <Trigger Property="IsEnabled" Value="False"><Setter TargetName="Bd" Property="Opacity" Value="0.4"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="Button" x:Key="LinkBtn">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#b3bdcb"/>
            <Setter Property="FontSize" Value="11.5"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="Transparent" Padding="2,2"><ContentPresenter VerticalAlignment="Center"/></Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter Property="Foreground" Value="#ffffff"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="Button" x:Key="NavBtn">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Grid>
                            <Border Background="{TemplateBinding Background}" CornerRadius="8"/>
                            <Border x:Name="Hv" Background="#ffffff" CornerRadius="8" Opacity="0"/>
                            <ContentPresenter Margin="12,0,0,0" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Hv" Property="Opacity" Value="0.045"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="Button" x:Key="TabBtn">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#b3bdcb"/>
            <Setter Property="FontSize" Value="12.5"/>
            <Setter Property="Padding" Value="11,5"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Grid>
                            <Border Background="{TemplateBinding Background}" CornerRadius="7"/>
                            <Border x:Name="Hv" Background="#ffffff" CornerRadius="7" Opacity="0"/>
                            <ContentPresenter Margin="{TemplateBinding Padding}" VerticalAlignment="Center"/>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Hv" Property="Opacity" Value="0.05"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="CheckBox" x:Key="GopCheck">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="CheckBox">
                        <Grid Width="18" Height="18" Background="Transparent">
                            <Border x:Name="Bx" CornerRadius="4" BorderThickness="1.5" BorderBrush="#4f5a69" Background="Transparent"/>
                            <TextBlock x:Name="Mk" Text="&#xE73E;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="11"
                                       Foreground="#ffffff" HorizontalAlignment="Center" VerticalAlignment="Center" Visibility="Collapsed"/>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Bx" Property="BorderBrush" Value="#7d8896"/></Trigger>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="Bx" Property="Background" Value="#3b82f6"/>
                                <Setter TargetName="Bx" Property="BorderBrush" Value="#3b82f6"/>
                                <Setter TargetName="Mk" Property="Visibility" Value="Visible"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.35"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="TextBox" x:Key="SearchBox">
            <Setter Property="Foreground" Value="#e6edf3"/>
            <Setter Property="CaretBrush" Value="#e6edf3"/>
            <Setter Property="FontSize" Value="12.5"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TextBox">
                        <Border x:Name="Bd" Background="#10141b" BorderBrush="#242b36" BorderThickness="1" CornerRadius="8" Padding="30,6,8,6">
                            <ScrollViewer x:Name="PART_ContentHost" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Bd" Property="BorderBrush" Value="#3b82f6"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="ToolTip">
            <Setter Property="Background" Value="#1b212b"/>
            <Setter Property="Foreground" Value="#e6edf3"/>
            <Setter Property="BorderBrush" Value="#313b4a"/>
            <Setter Property="MaxWidth" Value="520"/>
            <Setter Property="ContentTemplate">
                <Setter.Value>
                    <DataTemplate><TextBlock Text="{Binding}" TextWrapping="Wrap"/></DataTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="ScrollBar">
            <Setter Property="Width" Value="10"/>
            <Setter Property="MinWidth" Value="10"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ScrollBar">
                        <Grid Background="Transparent">
                            <Track x:Name="PART_Track" IsDirectionReversed="True">
                                <Track.Thumb>
                                    <Thumb>
                                        <Thumb.Template>
                                            <ControlTemplate TargetType="Thumb"><Border CornerRadius="4" Background="#313b4a" Margin="2,0,2,0"/></ControlTemplate>
                                        </Thumb.Template>
                                    </Thumb>
                                </Track.Thumb>
                            </Track>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="Orientation" Value="Horizontal">
                    <Setter Property="Width" Value="Auto"/>
                    <Setter Property="MinWidth" Value="0"/>
                    <Setter Property="Height" Value="10"/>
                    <Setter Property="Template">
                        <Setter.Value>
                            <ControlTemplate TargetType="ScrollBar">
                                <Grid Background="Transparent">
                                    <Track x:Name="PART_Track">
                                        <Track.Thumb>
                                            <Thumb>
                                                <Thumb.Template>
                                                    <ControlTemplate TargetType="Thumb"><Border CornerRadius="4" Background="#313b4a" Margin="0,2,0,2"/></ControlTemplate>
                                                </Thumb.Template>
                                            </Thumb>
                                        </Track.Thumb>
                                    </Track>
                                </Grid>
                            </ControlTemplate>
                        </Setter.Value>
                    </Setter>
                </Trigger>
            </Style.Triggers>
        </Style>
    </Window.Resources>

    <Grid Background="#0b0e13">
        <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="32"/></Grid.RowDefinitions>
        <Grid>
            <Grid.ColumnDefinitions><ColumnDefinition Width="224"/><ColumnDefinition Width="1"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>

            <!-- ============ SIDEBAR ============ -->
            <DockPanel Background="#0e1218">
                <StackPanel DockPanel.Dock="Top" Orientation="Horizontal" Margin="16,18,0,20">
                    <Border Width="38" Height="38" CornerRadius="10" Background="#31181d">
                        <TextBlock Text="&#xE945;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="17" Foreground="#00d9ff"
                                   HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Border>
                    <StackPanel Margin="11,0,0,0" VerticalAlignment="Center">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Text="GameOptimizer" FontSize="14.5" FontWeight="SemiBold" Foreground="#e6edf3"/>
                            <TextBlock Text="Pro" FontSize="14.5" FontWeight="SemiBold" Foreground="#e53935"/>
                        </StackPanel>
                        <TextBlock Name="SubtitleText" Text="v$($Script:AppVersion) - by FloDePin" FontSize="11" Foreground="#7d8896"/>
                    </StackPanel>
                </StackPanel>

                <StackPanel DockPanel.Dock="Bottom" Margin="0,0,0,12">
                    <Border Background="#151a22" BorderBrush="#242b36" BorderThickness="1" CornerRadius="10" Padding="14,12" Margin="14,0,14,12">
                        <StackPanel>
                            <TextBlock Text="SYSTEM" FontSize="10" FontWeight="SemiBold" Foreground="#4f5a69" Margin="0,0,0,6"/>
                            <TextBlock Name="HwInfoText" Text="Detecting hardware..." FontSize="12" Foreground="#e6edf3" LineHeight="18" TextTrimming="CharacterEllipsis"/>
                        </StackPanel>
                    </Border>
                    <Grid Margin="16,0,14,0">
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                            <Ellipse Width="7" Height="7" Fill="#22c55e" Margin="0,0,6,0"/>
                            <TextBlock Text="Administrator" FontSize="11" Foreground="#22c55e"/>
                        </StackPanel>
                        <Button Name="BtnLang" Style="{StaticResource GopBtn}" HorizontalAlignment="Right" Padding="10,4" FontSize="11.5"
                                ToolTip="Switches the tweak and BIOS descriptions between English and German. The interface itself stays English."/>
                    </Grid>
                </StackPanel>

                <StackPanel>
                    <Grid Height="38" Margin="0,1,0,1">
                        <Border Name="NavBarDashboard" Width="3" HorizontalAlignment="Left" Margin="0,7,0,7" CornerRadius="0,2,2,0" Visibility="Hidden"/>
                        <Button Name="NavDashboard" Style="{StaticResource NavBtn}" Margin="12,0,12,0">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock Name="NavIcoDashboard" Text="&#xEC4A;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="15" Width="28" VerticalAlignment="Center"/>
                                <TextBlock Name="NavTxtDashboard" Text="Dashboard" FontSize="13.5" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                    </Grid>
                    <Grid Height="38" Margin="0,1,0,1">
                        <Border Name="NavBarTweaks" Width="3" HorizontalAlignment="Left" Margin="0,7,0,7" CornerRadius="0,2,2,0" Visibility="Hidden"/>
                        <Button Name="NavTweaks" Style="{StaticResource NavBtn}" Margin="12,0,12,0">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock Name="NavIcoTweaks" Text="&#xE9F5;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="15" Width="28" VerticalAlignment="Center"/>
                                <TextBlock Name="NavTxtTweaks" Text="Tweaks" FontSize="13.5" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                    </Grid>
                    <Grid Height="38" Margin="0,1,0,1">
                        <Border Name="NavBarPresets" Width="3" HorizontalAlignment="Left" Margin="0,7,0,7" CornerRadius="0,2,2,0" Visibility="Hidden"/>
                        <Button Name="NavPresets" Style="{StaticResource NavBtn}" Margin="12,0,12,0">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock Name="NavIcoPresets" Text="&#xE734;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="15" Width="28" VerticalAlignment="Center"/>
                                <TextBlock Name="NavTxtPresets" Text="Presets" FontSize="13.5" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                    </Grid>
                    <Grid Height="38" Margin="0,1,0,1">
                        <Border Name="NavBarBios" Width="3" HorizontalAlignment="Left" Margin="0,7,0,7" CornerRadius="0,2,2,0" Visibility="Hidden"/>
                        <Button Name="NavBios" Style="{StaticResource NavBtn}" Margin="12,0,12,0">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock Name="NavIcoBios" Text="&#xE950;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="15" Width="28" VerticalAlignment="Center"/>
                                <TextBlock Name="NavTxtBios" Text="BIOS Guide" FontSize="13.5" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                    </Grid>
                    <Grid Height="38" Margin="0,1,0,1">
                        <Button Name="BtnStartup" Style="{StaticResource NavBtn}" Margin="12,0,12,0" ToolTip="Opens the Startup Manager in its own window">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock Text="&#xE7E8;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="15" Width="28" Foreground="#7d8896" VerticalAlignment="Center"/>
                                <TextBlock Text="Startup Manager" FontSize="13.5" Foreground="#b3bdcb" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                    </Grid>
                    <Grid Height="38" Margin="0,1,0,1">
                        <Button Name="BtnServices" Style="{StaticResource NavBtn}" Margin="12,0,12,0" ToolTip="Opens the Services Manager in its own window">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock Text="&#xE90F;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="15" Width="28" Foreground="#7d8896" VerticalAlignment="Center"/>
                                <TextBlock Text="Services" FontSize="13.5" Foreground="#b3bdcb" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                    </Grid>
                    <Grid Height="38" Margin="0,1,0,1">
                        <Border Name="NavBarBackups" Width="3" HorizontalAlignment="Left" Margin="0,7,0,7" CornerRadius="0,2,2,0" Visibility="Hidden"/>
                        <Button Name="NavBackups" Style="{StaticResource NavBtn}" Margin="12,0,12,0">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock Name="NavIcoBackups" Text="&#xE81C;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="15" Width="28" VerticalAlignment="Center"/>
                                <TextBlock Name="NavTxtBackups" Text="Backups &amp; Log" FontSize="13.5" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                    </Grid>
                </StackPanel>
            </DockPanel>
            <Border Grid.Column="1" Background="#242b36"/>

            <!-- ============ PAGES ============ -->
            <Grid Grid.Column="2">
                <ScrollViewer Name="PageDashboard" Visibility="Collapsed" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="26,22,22,16">
                    <StackPanel Name="DashboardPanel"/>
                </ScrollViewer>

                <DockPanel Name="PageTweaks" Visibility="Collapsed" Margin="26,22,22,10">
                    <StackPanel DockPanel.Dock="Top">
                        <Grid Margin="0,0,4,18">
                            <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                            <Border Width="3" CornerRadius="2" Background="#e53935" Margin="0,2,16,2"/>
                            <StackPanel Grid.Column="1">
                                <TextBlock Text="Tweaks" FontSize="26" FontWeight="SemiBold" Foreground="#e6edf3"/>
                                <TextBlock Text="Every tweak can be undone &#183; live status where Windows reports it" FontSize="12.5" Foreground="#7d8896" Margin="0,3,0,0" TextTrimming="CharacterEllipsis"/>
                            </StackPanel>
                            <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center">
                                <Button Name="BtnSelectAll" Style="{StaticResource GopBtn}" Content="All" Margin="8,0,0,0"/>
                                <Button Name="BtnDeselectAll" Style="{StaticResource GopBtn}" Content="None" Margin="8,0,0,0"/>
                                <Button Name="BtnApply" Style="{StaticResource GopBtn}" Background="#e53935" BorderBrush="#e53935" Foreground="#ffffff" Margin="8,0,0,0">
                                    <StackPanel Orientation="Horizontal">
                                        <TextBlock Text="&#xE768;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="13" Margin="0,0,7,0" VerticalAlignment="Center"/>
                                        <TextBlock Text="Apply selected" FontWeight="SemiBold"/>
                                    </StackPanel>
                                </Button>
                                <Button Name="BtnRevertSel" Style="{StaticResource GopBtn}" Margin="8,0,0,0" ToolTip="Sets only the ticked tweaks back to the Windows default">
                                    <StackPanel Orientation="Horizontal">
                                        <TextBlock Text="&#xE7A7;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="13" Margin="0,0,7,0" VerticalAlignment="Center"/>
                                        <TextBlock Text="Revert selected"/>
                                    </StackPanel>
                                </Button>
                                <Button Name="BtnRevertAll" Style="{StaticResource GopBtn}" Background="#f59e0b" BorderBrush="#f59e0b" Foreground="#1a1205" Margin="8,0,0,0">
                                    <StackPanel Orientation="Horizontal">
                                        <TextBlock Text="&#xE7A7;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="13" Margin="0,0,7,0" VerticalAlignment="Center"/>
                                        <TextBlock Text="Revert all" FontWeight="SemiBold"/>
                                    </StackPanel>
                                </Button>
                            </StackPanel>
                        </Grid>
                        <Grid Margin="0,0,4,12">
                            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="230"/></Grid.ColumnDefinitions>
                            <Border HorizontalAlignment="Left" CornerRadius="9" Background="#1b212b" Padding="3">
                                <StackPanel Name="CatTabs" Orientation="Horizontal"/>
                            </Border>
                            <Grid Grid.Column="1" VerticalAlignment="Center">
                                <TextBox Name="SearchBox" Style="{StaticResource SearchBox}"/>
                                <TextBlock Text="&#xE721;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="12" Foreground="#4f5a69" Margin="11,0,0,0" VerticalAlignment="Center" IsHitTestVisible="False"/>
                                <TextBlock Name="SearchHint" Text="Search tweaks ..." FontSize="12.5" Foreground="#4f5a69" Margin="31,0,0,0" VerticalAlignment="Center" IsHitTestVisible="False"/>
                            </Grid>
                        </Grid>
                        <Grid Margin="2,0,6,12">
                            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                <Ellipse Width="7" Height="7" Fill="#22c55e" Margin="0,0,5,0"/>
                                <TextBlock Text="active (verified)" FontSize="11.5" Foreground="#22c55e" Margin="0,0,16,0"/>
                                <Ellipse Width="7" Height="7" Stroke="#4f5a69" StrokeThickness="1.4" Margin="0,0,5,0"/>
                                <TextBlock Text="inactive" FontSize="11.5" Foreground="#7d8896" Margin="0,0,16,0"/>
                                <Ellipse Width="7" Height="7" Fill="#4f5a69" Margin="0,0,5,0"/>
                                <TextBlock Text="one-time / n/a" FontSize="11.5" Foreground="#7d8896" ToolTip="Grey: one-time actions (nothing lasting to check) and tweaks that don't apply to this PC, e.g. AMD tweaks on an NVIDIA card"/>
                            </StackPanel>
                            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                                <TextBlock Name="CountsText" FontSize="11.5" Foreground="#b3bdcb" Margin="0,0,16,0" VerticalAlignment="Center"/>
                                <Button Name="BtnVerify" Style="{StaticResource LinkBtn}" ToolTip="Re-checks the live status of every tweak and ticks the ones that are already active">
                                    <StackPanel Orientation="Horizontal">
                                        <TextBlock Text="&#xE72C;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="12" Margin="0,0,6,0" VerticalAlignment="Center"/>
                                        <TextBlock Text="Verify status" FontSize="12" FontWeight="SemiBold" Foreground="#e6edf3"/>
                                    </StackPanel>
                                </Button>
                            </StackPanel>
                        </Grid>
                    </StackPanel>
                    <ScrollViewer Name="TweakScroll" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                        <StackPanel Name="TweakHost" Margin="0,0,6,0">
                            <StackPanel Name="WindowsPanel"/>
                            <StackPanel Name="GamingPanel"/>
                            <StackPanel Name="NetworkPanel"/>
                            <StackPanel Name="RamStoragePanel"/>
                            <StackPanel Name="Win11Panel"/>
                            <StackPanel Name="AudioPanel"/>
                            <StackPanel Name="GpuPanel"/>
                            <StackPanel Name="PowerPanel"/>
                            <TextBlock Name="SearchEmpty" Text="No tweak matches this search." FontSize="13" Foreground="#7d8896" Margin="4,20,0,0" Visibility="Collapsed"/>
                        </StackPanel>
                    </ScrollViewer>
                </DockPanel>

                <ScrollViewer Name="PagePresets" Visibility="Collapsed" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="26,22,22,16">
                    <StackPanel Name="PresetsPanel"/>
                </ScrollViewer>

                <Grid Name="PageBios" Visibility="Collapsed" Margin="26,22,22,10">
                    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                    <Grid Margin="0,0,4,18">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                        <Border Width="3" CornerRadius="2" Background="#f59e0b" Margin="0,2,16,2"/>
                        <StackPanel Grid.Column="1">
                            <TextBlock Text="BIOS Guide" FontSize="26" FontWeight="SemiBold" Foreground="#e6edf3"/>
                            <TextBlock Text="Every platform with the BIOS settings that matter and the menu path for your board maker -- yours is detected and pre-selected. Read-only: you set everything in the BIOS yourself."
                                       FontSize="12.5" Foreground="#7d8896" Margin="0,3,0,0" TextWrapping="Wrap"/>
                        </StackPanel>
                        <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center" Margin="16,0,0,0">
                            <TextBlock Name="BiosDetectStatus" FontSize="12" Foreground="#7d8896" VerticalAlignment="Center" Margin="0,0,12,0"/>
                            <Button Name="BtnBiosDetect" Style="{StaticResource GopBtn}" Background="#f59e0b" BorderBrush="#f59e0b" Foreground="#1a1205">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xE72C;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="13" Margin="0,0,7,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Check system state" FontWeight="SemiBold"/>
                                </StackPanel>
                            </Button>
                        </StackPanel>
                    </Grid>
                    <Grid Grid.Row="1">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="262"/><ColumnDefinition Width="16"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                        <Border Background="#151a22" BorderBrush="#242b36" BorderThickness="1" CornerRadius="10" Padding="8,10,4,10" VerticalAlignment="Top">
                            <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                                <StackPanel Name="BiosPlatformList" Margin="0,0,4,0"/>
                            </ScrollViewer>
                        </Border>
                        <ScrollViewer Grid.Column="2" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                            <StackPanel Name="BiosPanel" Margin="0,0,6,0"/>
                        </ScrollViewer>
                    </Grid>
                </Grid>

                <ScrollViewer Name="PageBackups" Visibility="Collapsed" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="26,22,22,16">
                    <StackPanel Name="BackupsPanel"/>
                </ScrollViewer>
            </Grid>
        </Grid>

        <!-- ============ STATUS BAR ============ -->
        <Border Grid.Row="1" Background="#0e1218" BorderBrush="#242b36" BorderThickness="0,1,0,0" Padding="16,0,16,0">
            <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                <DockPanel VerticalAlignment="Center">
                    <Ellipse Width="7" Height="7" Fill="#22c55e" Margin="0,0,8,0" DockPanel.Dock="Left"/>
                    <TextBlock Name="StatusText" Text="Ready" FontSize="11.5" Foreground="#b3bdcb" TextTrimming="CharacterEllipsis"/>
                </DockPanel>
                <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center" Margin="16,0,0,0">
                    <Button Name="BtnOpenBackups" Style="{StaticResource LinkBtn}" Margin="0,0,18,0">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Text="&#xE81C;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="12" Margin="0,0,6,0" VerticalAlignment="Center"/>
                            <TextBlock Text="Registry backups"/>
                        </StackPanel>
                    </Button>
                    <Button Name="BtnOpenLog" Style="{StaticResource LinkBtn}">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Text="&#xE838;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="12" Margin="0,0,6,0" VerticalAlignment="Center"/>
                            <TextBlock Text="Open log"/>
                        </StackPanel>
                    </Button>
                </StackPanel>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

# Parse XAML  --  own try/catch so a XAML error stays visible
try {
    $Reader = New-Object System.Xml.XmlNodeReader $XAML
    $Window = [Windows.Markup.XamlReader]::Load($Reader)
    foreach ($p in $logPaths) { try { "[$(Get-Date -f 'HH:mm:ss')] XAML geladen, Fenster erstellt" | Out-File $p -Append -ErrorAction SilentlyContinue } catch { } }
    Write-Host "[$(Get-Date -f 'HH:mm:ss')] XAML geladen, Fenster erstellt" -ForegroundColor DarkGray
} catch {
    Close-Splash
    foreach ($p in $logPaths) { try { "[$(Get-Date -f 'HH:mm:ss')] XAML FEHLER: $_" | Out-File $p -Append -ErrorAction SilentlyContinue } catch { } }
    Write-Host "[$(Get-Date -f 'HH:mm:ss')] XAML FEHLER: $_" -ForegroundColor DarkGray
    [System.Windows.Forms.MessageBox]::Show(
        "XAML load error:`n$_`n`nDetails: $startupLog",
        "GameOptimizerPro - XAML Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit
}

# Fit the window into small screens (e.g. 1366x768 laptops) instead of overflowing them
try {
    $wa = [System.Windows.SystemParameters]::WorkArea
    if ($wa.Width -lt ($Window.Width + 20))  { $Window.Width  = [math]::Max(960, $wa.Width - 20);  $Window.MinWidth  = [math]::Min($Window.MinWidth,  $Window.Width) }
    if ($wa.Height -lt ($Window.Height + 20)) { $Window.Height = [math]::Max(600, $wa.Height - 20); $Window.MinHeight = [math]::Min($Window.MinHeight, $Window.Height) }
} catch { }

# Get controls
$HwInfoText     = $Window.FindName("HwInfoText")
$SubtitleText   = $Window.FindName("SubtitleText")
$WindowsPanel   = $Window.FindName("WindowsPanel")
$GamingPanel    = $Window.FindName("GamingPanel")
$NetworkPanel   = $Window.FindName("NetworkPanel")
$RamStoragePanel= $Window.FindName("RamStoragePanel")
$Win11Panel     = $Window.FindName("Win11Panel")
$AudioPanel     = $Window.FindName("AudioPanel")
$GpuPanel       = $Window.FindName("GpuPanel")
$PowerPanel     = $Window.FindName("PowerPanel")
$BiosPanel      = $Window.FindName("BiosPanel")
$BiosPlatformList = $Window.FindName("BiosPlatformList")
$BiosDetectStatus = $Window.FindName("BiosDetectStatus")
$BtnBiosDetect  = $Window.FindName("BtnBiosDetect")
$DashboardPanel = $Window.FindName("DashboardPanel")
$PresetsPanel   = $Window.FindName("PresetsPanel")
$BackupsPanel   = $Window.FindName("BackupsPanel")
$BtnApply       = $Window.FindName("BtnApply")
$BtnSelectAll   = $Window.FindName("BtnSelectAll")
$BtnDeselect    = $Window.FindName("BtnDeselectAll")
$BtnOpenLog     = $Window.FindName("BtnOpenLog")
$BtnOpenBackups = $Window.FindName("BtnOpenBackups")
$BtnServices    = $Window.FindName("BtnServices")
$BtnVerify      = $Window.FindName("BtnVerify")
$BtnRevertAll   = $Window.FindName("BtnRevertAll")
$BtnRevertSel   = $Window.FindName("BtnRevertSel")
$BtnStartup     = $Window.FindName("BtnStartup")
$BtnLang        = $Window.FindName("BtnLang")
$StatusText     = $Window.FindName("StatusText")
$CatTabs        = $Window.FindName("CatTabs")
$SearchBox      = $Window.FindName("SearchBox")
$SearchHint     = $Window.FindName("SearchHint")
$SearchEmpty    = $Window.FindName("SearchEmpty")
$CountsText     = $Window.FindName("CountsText")
$TweakScroll    = $Window.FindName("TweakScroll")

# =============================================================================
# DESIGN SYSTEM  --  tokens + element builders (GameOptimizerPro v2.1 look)
# =============================================================================
$Script:UI = @{
    APP = '#0b0e13'; SIDE = '#0e1218'; CARD = '#151a22'; CARD2 = '#1b212b'; INPUT = '#10141b'; BORDER = '#242b36'; BORDER2 = '#313b4a'
    TEXT = '#e6edf3'; TEXT2 = '#b3bdcb'; DIM = '#7d8896'; MUTED = '#4f5a69'; DESC = '#98a3b3'
    RED = '#e53935'; CYAN = '#00b4d8'; ACC = '#00d9ff'; AMBER = '#f59e0b'; GREEN = '#22c55e'; BLUE = '#3b82f6'
    VIOLET = '#a78bfa'; ORANGE = '#f97316'; WIN = '#4f9cf9'; WIN11 = '#60a5fa'; NV = '#76b900'; ERR = '#ef4444'; SLATE = '#9ca3af'
}
$Script:IconFont   = New-Object Windows.Media.FontFamily("Segoe Fluent Icons, Segoe MDL2 Assets")
$Script:Mid        = " $([char]0x00B7) "     # separator dot (kept out of the source: script stays ASCII)
$Script:EmDash     = " $([char]0x2014) "     # em dash for display
$Script:BrushCache = @{}
$Script:BtnStyle   = $Window.FindResource("GopBtn")
$Script:CheckStyle = $Window.FindResource("GopCheck")
$Script:TabStyle   = $Window.FindResource("TabBtn")

function Brush([string]$Hex) {
    if (-not $Script:BrushCache.ContainsKey($Hex)) {
        $b = New-Object Windows.Media.SolidColorBrush ([Windows.Media.ColorConverter]::ConvertFromString($Hex))
        $b.Freeze(); $Script:BrushCache[$Hex] = $b
    }
    $Script:BrushCache[$Hex]
}
function Mix-Hex([string]$A, [string]$B, [double]$T) {
    $ca = [Windows.Media.ColorConverter]::ConvertFromString($A); $cb = [Windows.Media.ColorConverter]::ConvertFromString($B)
    '#{0:x2}{1:x2}{2:x2}' -f [int][math]::Round($ca.R + ($cb.R - $ca.R) * $T), [int][math]::Round($ca.G + ($cb.G - $ca.G) * $T), [int][math]::Round($ca.B + ($cb.B - $ca.B) * $T)
}
function Th { param([double[]]$V) if ($V.Count -eq 1) { New-Object Windows.Thickness($V[0]) } else { New-Object Windows.Thickness($V[0], $V[1], $V[2], $V[3]) } }
function New-Text {
    param([string]$Text, [double]$Size = 13, [string]$Color = $Script:UI.TEXT, [string]$Weight = 'Normal', [switch]$Wrap, [double[]]$Margin, [switch]$Mono)
    $tb = New-Object Windows.Controls.TextBlock
    $tb.Text = $Text; $tb.FontSize = $Size; $tb.Foreground = Brush $Color; $tb.FontWeight = $Weight
    if ($Wrap) { $tb.TextWrapping = [Windows.TextWrapping]::Wrap }
    if ($Margin) { $tb.Margin = Th $Margin }
    if ($Mono) { $tb.FontFamily = New-Object Windows.Media.FontFamily("Consolas") }
    $tb.VerticalAlignment = 'Center'
    $tb
}
function New-Icon {
    param([int]$Glyph, [double]$Size = 14, [string]$Color = $Script:UI.DIM, [double[]]$Margin)
    $tb = New-Object Windows.Controls.TextBlock
    $tb.Text = [string][char]$Glyph; $tb.FontFamily = $Script:IconFont; $tb.FontSize = $Size; $tb.Foreground = Brush $Color
    $tb.VerticalAlignment = 'Center'
    if ($Margin) { $tb.Margin = Th $Margin }
    $tb
}
function New-HStack { param([object[]]$Children, [double[]]$Margin)
    $sp = New-Object Windows.Controls.StackPanel; $sp.Orientation = 'Horizontal'
    foreach ($c in $Children) { if ($c) { $sp.Children.Add($c) | Out-Null } }
    if ($Margin) { $sp.Margin = Th $Margin }
    $sp
}
function New-VStack { param([object[]]$Children, [double[]]$Margin)
    $sp = New-Object Windows.Controls.StackPanel
    foreach ($c in $Children) { if ($c) { $sp.Children.Add($c) | Out-Null } }
    if ($Margin) { $sp.Margin = Th $Margin }
    $sp
}
function New-Card {
    param($Child, [double[]]$Margin = @(0, 0, 0, 14), [double[]]$Padding = @(18, 16, 18, 16), [string]$Background = $Script:UI.CARD)
    $b = New-Object Windows.Controls.Border
    $b.Background = Brush $Background; $b.BorderBrush = Brush $Script:UI.BORDER; $b.BorderThickness = Th 1
    $b.CornerRadius = New-Object Windows.CornerRadius(10); $b.Padding = Th $Padding; $b.Margin = Th $Margin
    $b.Child = $Child
    $b
}
function New-CardTitle {
    param([string]$Title, [string]$Accent, $Right)
    $g = New-Object Windows.Controls.Grid; $g.Margin = Th 0, 0, 0, 12
    $bar = New-Object Windows.Controls.Border; $bar.Width = 3; $bar.Height = 16; $bar.CornerRadius = New-Object Windows.CornerRadius(2)
    $bar.Background = Brush $Accent; $bar.Margin = Th 0, 0, 10, 0
    $g.Children.Add((New-HStack @($bar, (New-Text $Title 15 $Script:UI.TEXT 'SemiBold')))) | Out-Null
    if ($Right) { $Right.HorizontalAlignment = 'Right'; $g.Children.Add($Right) | Out-Null }
    $g
}
function New-Badge {
    param([string]$Text, [string]$Fg, [string]$Bg, [int]$Glyph = 0)
    $b = New-Object Windows.Controls.Border
    $b.CornerRadius = New-Object Windows.CornerRadius(4); $b.Background = Brush $Bg; $b.Padding = Th 6, 1, 6, 2
    $b.Margin = Th 0, 0, 0, 3; $b.HorizontalAlignment = 'Right'
    $ic = if ($Glyph) { New-Icon $Glyph 10 $Fg @(0, 0, 4, 0) } else { $null }
    $b.Child = New-HStack @($ic, (New-Text $Text 11 $Fg))
    $b
}
function New-Bar {
    param([double]$Pct, [string]$Color, [double]$Height = 6)
    $g = New-Object Windows.Controls.Grid; $g.Height = $Height
    $track = New-Object Windows.Controls.Border; $track.CornerRadius = New-Object Windows.CornerRadius($Height / 2)
    $track.Background = Brush (Mix-Hex $Script:UI.CARD '#ffffff' 0.07)
    $g.Children.Add($track) | Out-Null
    $inner = New-Object Windows.Controls.Grid
    $c1 = New-Object Windows.Controls.ColumnDefinition; $c2 = New-Object Windows.Controls.ColumnDefinition
    $inner.ColumnDefinitions.Add($c1); $inner.ColumnDefinitions.Add($c2)
    $fill = New-Object Windows.Controls.Border; $fill.CornerRadius = New-Object Windows.CornerRadius($Height / 2); $fill.Background = Brush $Color
    $inner.Children.Add($fill) | Out-Null
    $g.Children.Add($inner) | Out-Null
    $g.Tag = @{ C1 = $c1; C2 = $c2; Fill = $fill }
    Set-Bar $g $Pct
    $g
}
function Set-Bar($Bar, [double]$Pct, [string]$Color) {
    $p = [math]::Max(0, [math]::Min(100, $Pct))
    $Bar.Tag.C1.Width = New-Object Windows.GridLength([math]::Max(0.0001, $p), [Windows.GridUnitType]::Star)
    $Bar.Tag.C2.Width = New-Object Windows.GridLength([math]::Max(0.0001, 100 - $p), [Windows.GridUnitType]::Star)
    if ($Color) { $Bar.Tag.Fill.Background = Brush $Color }
}
function New-Btn {
    param([string]$Label, [string]$Bg = $Script:UI.CARD2, [string]$Fg = $Script:UI.TEXT, [int]$Glyph = 0, [switch]$Bold, [double[]]$Margin = @(8, 0, 0, 0))
    $btn = New-Object Windows.Controls.Button
    $btn.Style = $Script:BtnStyle; $btn.Background = Brush $Bg; $btn.Foreground = Brush $Fg
    $btn.BorderBrush = Brush $(if ($Bg -eq $Script:UI.CARD2) { $Script:UI.BORDER2 } else { $Bg })
    $btn.Margin = Th $Margin
    $ic = if ($Glyph) { New-Icon $Glyph 13 $Fg @(0, 0, 7, 0) } else { $null }
    $btn.Content = New-HStack @($ic, (New-Text $Label 13 $Fg $(if ($Bold) { 'SemiBold' } else { 'Normal' })))
    $btn
}
function New-PageHeader {
    param([string]$Title, [string]$Sub, [string]$Accent, [object[]]$Right)
    $g = New-Object Windows.Controls.Grid; $g.Margin = Th 0, 0, 4, 18
    foreach ($w in @('Auto', '*', 'Auto')) {
        $cd = New-Object Windows.Controls.ColumnDefinition
        $cd.Width = if ($w -eq '*') { New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star) } else { [Windows.GridLength]::Auto }
        $g.ColumnDefinitions.Add($cd)
    }
    $bar = New-Object Windows.Controls.Border; $bar.Width = 3; $bar.CornerRadius = New-Object Windows.CornerRadius(2)
    $bar.Background = Brush $Accent; $bar.Margin = Th 0, 2, 16, 2
    $g.Children.Add($bar) | Out-Null
    # (not "$sub": PowerShell names are case-insensitive, that would be the [string] parameter $Sub)
    $subBlock = New-Text $Sub 12.5 $Script:UI.DIM 'Normal' -Wrap -Margin 0, 3, 0, 0
    $txt = New-VStack @((New-Text $Title 26 $Script:UI.TEXT 'SemiBold'), $subBlock)
    [Windows.Controls.Grid]::SetColumn($txt, 1); $g.Children.Add($txt) | Out-Null
    if ($Right) {
        $r = New-HStack $Right; $r.VerticalAlignment = 'Center'; $r.Margin = Th 16, 0, 0, 0
        [Windows.Controls.Grid]::SetColumn($r, 2); $g.Children.Add($r) | Out-Null
    }
    $g
}
function New-SectionTitle {
    param([string]$Text, [string]$Color, [string]$RightText = '', [double[]]$Margin = @(0, 6, 0, 8))
    $g = New-Object Windows.Controls.Grid; $g.Margin = Th $Margin
    foreach ($w in @('Auto', '*', 'Auto')) {
        $cd = New-Object Windows.Controls.ColumnDefinition
        $cd.Width = if ($w -eq '*') { New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star) } else { [Windows.GridLength]::Auto }
        $g.ColumnDefinitions.Add($cd)
    }
    $g.Children.Add((New-Text $Text.ToUpper() 11.5 $Color 'SemiBold')) | Out-Null
    $line = New-Object Windows.Controls.Border; $line.Height = 1; $line.Background = Brush $Script:UI.BORDER; $line.Margin = Th 12, 0, 12, 0
    $line.VerticalAlignment = 'Center'; [Windows.Controls.Grid]::SetColumn($line, 1); $g.Children.Add($line) | Out-Null
    $right = New-Text $RightText 11.5 $Script:UI.DIM
    [Windows.Controls.Grid]::SetColumn($right, 2); $g.Children.Add($right) | Out-Null
    $g.Tag = $right
    $g
}
function New-Banner {
    param([string]$Text, [string]$Color, [int]$Glyph = 0xE946)
    $b = New-Object Windows.Controls.Border
    $b.Background = Brush (Mix-Hex $Script:UI.APP $Color 0.10); $b.BorderBrush = Brush (Mix-Hex $Script:UI.APP $Color 0.35)
    $b.BorderThickness = Th 1; $b.CornerRadius = New-Object Windows.CornerRadius(8); $b.Padding = Th 12, 8, 12, 8; $b.Margin = Th 0, 0, 0, 12
    $g = New-Object Windows.Controls.DockPanel
    $ic = New-Icon $Glyph 13 $Color @(0, 1, 10, 0); $ic.VerticalAlignment = 'Top'
    [Windows.Controls.DockPanel]::SetDock($ic, 'Left'); $g.Children.Add($ic) | Out-Null
    $g.Children.Add((New-Text $Text 12 $Color 'Normal' -Wrap)) | Out-Null
    $b.Child = $g
    $b
}
function New-Grid2 {
    # Two equal columns; Add-Grid2 places elements row by row (heights follow the content)
    $g = New-Object Windows.Controls.Grid
    foreach ($i in 0, 1) { $cd = New-Object Windows.Controls.ColumnDefinition; $cd.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star); $g.ColumnDefinitions.Add($cd) }
    $g.Tag = @{ N = 0 }
    $g
}
function Add-Grid2($Grid, $Element) {
    $n = $Grid.Tag.N
    if ($n % 2 -eq 0) { $rd = New-Object Windows.Controls.RowDefinition; $rd.Height = [Windows.GridLength]::Auto; $Grid.RowDefinitions.Add($rd) }
    [Windows.Controls.Grid]::SetRow($Element, [math]::Floor($n / 2)); [Windows.Controls.Grid]::SetColumn($Element, $n % 2)
    $Element.Margin = if ($n % 2 -eq 0) { Th 0, 0, 6, 12 } else { Th 6, 0, 0, 12 }
    $Grid.Children.Add($Element) | Out-Null
    $Grid.Tag.N = $n + 1
}

# Sidebar system card (four short lines)
$gpuShort = ($GPU -replace '^(NVIDIA|AMD|Intel\(R\))\s+', '' -replace '^GeForce\s+', '' -replace '\(TM\)|\(R\)', '').Trim()
$cpuShort = ($CPU -replace '\(TM\)|\(R\)', '' -replace '\s+\d+-Core Processor', '' -replace '\s+CPU\s+@.*$', '' -replace '\s{2,}', ' ').Trim()
$osLine   = if ($IsWin11 -or $IsWin10) { "$(if ($IsWin11) { 'Win 11' } else { 'Win 10' })$($Script:Mid)Build $OSBuild" } else { $OSShort }
$HwInfoText.Text = "$gpuShort`n$cpuShort`n$RAM GB RAM$($Script:Mid)$NVMeInfo`n$osLine"
$HwInfoText.ToolTip = "GPU: $GPU`nCPU: $CPU`nRAM: $RAM GB`n$NVMeInfo`n$OSShort"
$SubtitleText.Text = "v$($Script:AppVersion)$($Script:Mid)by FloDePin"

# =============================================================================
# TWEAK ROWS
# =============================================================================
$CheckBoxMap         = @{}   # Name -> CheckBox
$Script:TweakState   = @{}   # Name -> active | inactive | unknown
$Script:CheckRaw     = @{}   # Name -> T (returned $true) | F (anything else) | E (threw); latest result, reused by the drift check
$Script:SplashRows   = 0     # rows built so far (splash progress)
$Script:TweakBadges  = @{}   # Name -> "active" badge
$Script:TweakRows    = @{}   # Name -> @{ Card; Desc; Tweak }
$Script:GroupHeaders = @()   # @{ Root; Names; Cat }
$Script:CatNotices   = @()   # banners hidden while searching
$Script:OneTimeNames = @($CheckFunctions.Keys | Where-Object { $CheckFunctions[$_].ToString().Trim() -eq '$null' })
$Script:RestartTweaks = @("Remove Windows Recall", "Disable HPET (High Precision Event Timer)", "Allow Global Timer Resolution (Windows 11)",
    "Process Count Reduction (Svchost)", "Enable MSI Mode (Message Signaled Interrupts)", "Enable Hardware-Accelerated GPU Scheduling (HAGS)",
    "Disable Write-Cache Buffer Flushing", "Disable Windows Platform Binary Table (WPBT)", "Disable Memory Compression",
    "Disable Energy-Efficient Ethernet", "Disable Interrupt Moderation")
# Take effect after signing out and in (a restart does it too)
$Script:SignOutTweaks = @("Optimize Visual Effects (Performance Mode)", "Stop Background Apps (All Editions)", "Disable File Explorer Automatic Folder Discovery")
$Script:EnterpriseOnly = @("Disable Get Started & Copilot Sign-in Screens", "Disable Consumer Features")
# Policies Windows reads from Pro upwards (Policy CSP: Pro / Enterprise / Education) -- greyed out on Home
$Script:ProOnly = @("Block Background Apps (Policy)", "Exclude Drivers from Windows Update", "Hold Feature Updates (Stay on Current Version)")
$Script:AppRemovals = @("Remove Xbox Apps", "Remove Copilot", "Remove OneDrive", "Remove Windows Recall", "Remove Other Bloatware")

function Get-TweakDesc($Tweak) {
    $d = if ($LangState.Current -eq "DE") { $Tweak.Desc } elseif ($TweakDescEN.ContainsKey($Tweak.Name)) { $TweakDescEN[$Tweak.Name] } else { $Tweak.Desc }
    $d -replace '\s+--\s+', $Script:EmDash
}

function New-TweakRow {
    param($Tweak)
    $U = $Script:UI
    $name = $Tweak.Name
    $isWin11Only = ($Tweak.Category -eq "Windows 11") -and (-not $IsWin11)
    $isWrongGPU  = ($Tweak.Group -eq "AMD") -and (-not $IsAMD)
    # Policies Windows only reads on Enterprise / Education -- not selectable on Home / Pro
    $isEntOnly   = ($Script:EnterpriseOnly -contains $name) -and (-not (Test-EnterpriseEdition))
    $isProOnly   = ($Script:ProOnly -contains $name) -and (Test-HomeEdition)

    $card = New-Object Windows.Controls.Border
    $card.Background = Brush $U.CARD; $card.BorderBrush = Brush $U.BORDER; $card.BorderThickness = Th 1
    $card.CornerRadius = New-Object Windows.CornerRadius(8); $card.Padding = Th 14, 9, 12, 9; $card.Margin = Th 0, 0, 0, 6

    $grid = New-Object Windows.Controls.Grid
    foreach ($w in 22, 32) { $cd = New-Object Windows.Controls.ColumnDefinition; $cd.Width = New-Object Windows.GridLength($w); $grid.ColumnDefinitions.Add($cd) }
    $cd = New-Object Windows.Controls.ColumnDefinition; $cd.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star); $grid.ColumnDefinitions.Add($cd)
    $cd = New-Object Windows.Controls.ColumnDefinition; $cd.Width = [Windows.GridLength]::Auto; $grid.ColumnDefinitions.Add($cd)

    $dot = New-Object Windows.Shapes.Ellipse; $dot.Width = 8; $dot.Height = 8; $dot.VerticalAlignment = 'Center'; $dot.HorizontalAlignment = 'Left'
    $grid.Children.Add($dot) | Out-Null

    $cb = New-Object Windows.Controls.CheckBox; $cb.Style = $Script:CheckStyle; $cb.Tag = $name; $cb.VerticalAlignment = 'Center'
    [Windows.Controls.Grid]::SetColumn($cb, 1); $grid.Children.Add($cb) | Out-Null

    $desc = New-Text (Get-TweakDesc $Tweak) 12 $U.DESC 'Normal' -Wrap -Margin 0, 2, 0, 0
    $desc.MaxHeight = 34; $desc.TextTrimming = [Windows.TextTrimming]::CharacterEllipsis; $desc.ToolTip = (Get-TweakDesc $Tweak)
    $text = New-VStack @((New-Text $name 13.5 $U.TEXT 'SemiBold'), $desc) @(2, 0, 14, 0)
    # Long descriptions (with their warnings) can be opened in the row, not only in the tooltip.
    # Shown for texts longer than about two lines in the current language (see Set-DescLanguage).
    $more = $null
    $en = if ($TweakDescEN.ContainsKey($name)) { $TweakDescEN[$name] } else { '' }
    if ([math]::Max($Tweak.Desc.Length, $en.Length) -gt 240) {
        $more = New-Text 'Show more' 11.5 $U.ACC 'SemiBold' -Margin 0, 2, 0, 0
        $more.Cursor = [System.Windows.Input.Cursors]::Hand; $more.HorizontalAlignment = 'Left'
        $more.Visibility = $(if ((Get-TweakDesc $Tweak).Length -gt 240) { 'Visible' } else { 'Collapsed' })
        $descRef = $desc
        # Handled: the click must not also tick the row's checkbox
        $more.Add_MouseLeftButtonUp({ param($s, $e) $e.Handled = $true
            if ($descRef.MaxHeight -lt 1000) { $descRef.MaxHeight = [double]::PositiveInfinity; $s.Text = 'Show less' } else { $descRef.MaxHeight = 34; $s.Text = 'Show more' } }.GetNewClosure())
        $text.Children.Add($more) | Out-Null
    }
    $text.VerticalAlignment = 'Center'; $text.Cursor = [System.Windows.Input.Cursors]::Hand; $text.Background = [Windows.Media.Brushes]::Transparent
    [Windows.Controls.Grid]::SetColumn($text, 2); $grid.Children.Add($text) | Out-Null
    $cbRef = $cb
    $text.Add_MouseLeftButtonUp({ if ($cbRef.IsEnabled) { $cbRef.IsChecked = -not ($cbRef.IsChecked -eq $true) } }.GetNewClosure())

    $badges = New-VStack @(); $badges.VerticalAlignment = 'Center'; $badges.MinWidth = 96
    if ($Script:AppRemovals -contains $name)   { $badges.Children.Add((New-Badge 'removes app' $U.AMBER (Mix-Hex $U.CARD $U.AMBER 0.14) 0xE74D)) | Out-Null }
    if ($Script:RestartTweaks -contains $name) { $badges.Children.Add((New-Badge 'restart' $U.AMBER (Mix-Hex $U.CARD $U.AMBER 0.14) 0xE7BA)) | Out-Null }
    if ($isWrongGPU)  { $badges.Children.Add((New-Badge 'AMD only' $U.SLATE $U.CARD2 0xE7BA)) | Out-Null }
    if ($isEntOnly)   { $badges.Children.Add((New-Badge 'Enterprise only' $U.SLATE $U.CARD2 0xE7BA)) | Out-Null }
    if ($isProOnly)   { $badges.Children.Add((New-Badge 'Pro and up' $U.SLATE $U.CARD2 0xE7BA)) | Out-Null }
    if ($isWin11Only) { $badges.Children.Add((New-Badge 'Windows 11 only' $U.SLATE $U.CARD2 0xE7BA)) | Out-Null }
    if ($Script:OneTimeNames -contains $name) { $badges.Children.Add((New-Badge 'one-time' $U.TEXT2 $U.CARD2 0xE72C)) | Out-Null }
    $active = New-Badge 'active' $U.GREEN (Mix-Hex $U.CARD $U.GREEN 0.16) 0xE73E; $active.Visibility = 'Collapsed'
    $badges.Children.Add($active) | Out-Null
    [Windows.Controls.Grid]::SetColumn($badges, 3); $grid.Children.Add($badges) | Out-Null

    if ($isWin11Only -or $isWrongGPU -or $isEntOnly -or $isProOnly) { $cb.IsEnabled = $false; $card.Opacity = 0.55 }
    $card.Child = $grid

    $CheckBoxMap[$name]           = $cb
    $Script:TweakDots[$name]      = $dot
    $Script:TweakBadges[$name]    = $active
    $Script:TweakRows[$name]      = @{ Card = $card; Desc = $desc; Tweak = $Tweak; More = $more }
    Update-TweakDot $dot $name | Out-Null
    return $card
}

# Shared status update (build time, Verify, Apply, Revert): dot + "active" badge + state table
function Update-TweakDot($dot, $tweakName) {
    $state = "unknown"
    if ($CheckFunctions.ContainsKey($tweakName)) {
        try {
            $isActive = & $CheckFunctions[$tweakName]
            if ($isActive -eq $true) { $state = "active" } elseif ($isActive -eq $false) { $state = "inactive" }
            $Script:CheckRaw[$tweakName] = $(if ($isActive -eq $true) { 'T' } elseif ($isActive -is [bool]) { 'F' } else { 'N' })
        } catch { $state = "unknown"; $Script:CheckRaw[$tweakName] = 'E' }
    }
    $Script:TweakState[$tweakName] = $state
    switch ($state) {
        "active"   { $dot.Fill = Brush $Script:UI.GREEN; $dot.Stroke = $null; $dot.ToolTip = "Active -- this tweak is in effect" }
        "inactive" { $dot.Fill = [Windows.Media.Brushes]::Transparent; $dot.Stroke = Brush $Script:UI.MUTED; $dot.StrokeThickness = 1.5; $dot.ToolTip = "Not active" }
        default    { $dot.Fill = Brush $Script:UI.MUTED; $dot.Stroke = $null
                     $dot.ToolTip = $(if ($Script:OneTimeNames -contains $tweakName) { "One-time action -- nothing lasting to check" } else { "Status unknown right now -- not applicable to this PC, or Windows didn't answer (e.g. busy installing updates). Verify checks again." }) }
    }
    if ($Script:TweakBadges.ContainsKey($tweakName)) { $Script:TweakBadges[$tweakName].Visibility = $(if ($state -eq "active") { 'Visible' } else { 'Collapsed' }) }
    return $state
}

function Set-DescLanguage {
    foreach ($r in $Script:TweakRows.Values) {
        $d = Get-TweakDesc $r.Tweak; $r.Desc.Text = $d; $r.Desc.ToolTip = $d
        if ($r.More) { $r.Desc.MaxHeight = 34; $r.More.Text = 'Show more'; $r.More.Visibility = $(if ($d.Length -gt 240) { 'Visible' } else { 'Collapsed' }) }
    }
}

# =============================================================================
# CATEGORY TABS, SEARCH, COUNTERS
# =============================================================================
$Script:Cats = @(
    @{ Key = 'Windows';       Label = 'Windows';       Color = $Script:UI.WIN;    Panel = $WindowsPanel }
    @{ Key = 'Gaming';        Label = 'Gaming';        Color = $Script:UI.AMBER;  Panel = $GamingPanel }
    @{ Key = 'Network';       Label = 'Network';       Color = $Script:UI.CYAN;   Panel = $NetworkPanel }
    @{ Key = 'RAM & Storage'; Label = 'RAM & Storage'; Color = $Script:UI.GREEN;  Panel = $RamStoragePanel }
    @{ Key = 'Windows 11';    Label = 'Windows 11';    Color = $Script:UI.WIN11;  Panel = $Win11Panel }
    @{ Key = 'Audio';         Label = 'Audio';         Color = $Script:UI.VIOLET; Panel = $AudioPanel }
    @{ Key = 'GPU Tweaks';    Label = 'GPU';           Color = $Script:UI.NV;     Panel = $GpuPanel }
    @{ Key = 'Power Plan';    Label = 'Power';         Color = $Script:UI.ORANGE; Panel = $PowerPanel }
)
$Script:CurrentCat = 'Windows'

function Select-Category([string]$Key) {
    $Script:CurrentCat = $Key
    foreach ($c in $Script:Cats) {
        $on = ($c.Key -eq $Key)
        $c.Tab.Background = if ($on) { Brush $c.Color } else { [Windows.Media.Brushes]::Transparent }
        $c.TabLabel.Foreground = Brush $(if ($on) { '#ffffff' } else { $Script:UI.TEXT2 })
        $c.TabLabel.FontWeight = $(if ($on) { 'SemiBold' } else { 'Normal' })
        $c.TabCount.Foreground = Brush $(if ($on) { (Mix-Hex $c.Color '#ffffff' 0.75) } else { $Script:UI.MUTED })
    }
    if ($SearchBox.Text) { $SearchBox.Text = '' } else { Apply-TweakFilter }
    $TweakScroll.ScrollToTop()
}

function Test-Contains([string]$Haystack, [string]$Needle) { $Haystack -and $Haystack.IndexOf($Needle, [StringComparison]::OrdinalIgnoreCase) -ge 0 }

function Apply-TweakFilter {
    $q = $SearchBox.Text.Trim()
    $SearchHint.Visibility = $(if ($SearchBox.Text) { 'Collapsed' } else { 'Visible' })
    if (-not $q) {
        foreach ($c in $Script:Cats) { $c.Panel.Visibility = $(if ($c.Key -eq $Script:CurrentCat) { 'Visible' } else { 'Collapsed' }); $c.Title.Visibility = 'Collapsed' }
        foreach ($r in $Script:TweakRows.Values) { $r.Card.Visibility = 'Visible' }
        foreach ($h in $Script:GroupHeaders) { $h.Root.Visibility = 'Visible' }
        foreach ($n in $Script:CatNotices) { $n.Visibility = 'Visible' }
        $SearchEmpty.Visibility = 'Collapsed'
        return
    }
    $hits = 0
    foreach ($r in $Script:TweakRows.Values) {
        $t = $r.Tweak
        $m = (Test-Contains $t.Name $q) -or (Test-Contains (Get-TweakDesc $t) $q) -or (Test-Contains $t.Group $q)
        $r.Card.Visibility = $(if ($m) { 'Visible' } else { 'Collapsed' }); if ($m) { $hits++ }
    }
    foreach ($h in $Script:GroupHeaders) {
        $any = @($h.Names | Where-Object { $Script:TweakRows[$_].Card.Visibility -eq 'Visible' }).Count
        $h.Root.Visibility = $(if ($any) { 'Visible' } else { 'Collapsed' })
    }
    foreach ($n in $Script:CatNotices) { $n.Visibility = 'Collapsed' }
    foreach ($c in $Script:Cats) {
        $any = @($AllTweaks | Where-Object { $_.Category -eq $c.Key -and $Script:TweakRows[$_.Name].Card.Visibility -eq 'Visible' }).Count
        $c.Panel.Visibility = $(if ($any) { 'Visible' } else { 'Collapsed' }); $c.Title.Visibility = 'Visible'
    }
    $SearchEmpty.Visibility = $(if ($hits) { 'Collapsed' } else { 'Visible' })
    $StatusText.Text = "$hits tweak(s) match '$q' (all categories)"
}

# Grey dots are two different things: one-time actions (nothing lasting to check) and
# checks without an answer on this PC (AMD tweaks on an NVIDIA card, no NVMe drive,
# no adapter offering EEE ...). Counted separately so neither is called the other.
function Get-StateCounts {
    $c = @{ Active = 0; Inactive = 0; OneTime = 0; NA = 0 }
    foreach ($k in @($Script:TweakState.Keys)) {
        switch ($Script:TweakState[$k]) {
            'active'   { $c.Active++ }
            'inactive' { $c.Inactive++ }
            default    { if ($Script:OneTimeNames -contains $k) { $c.OneTime++ } else { $c.NA++ } }
        }
    }
    $c
}

function Update-Counts {
    $c = Get-StateCounts
    $CountsText.Text = "$($c.Active) active$($Script:Mid)$($c.Inactive) inactive$($Script:Mid)$($c.OneTime) one-time" + $(if ($c.NA) { "$($Script:Mid)$($c.NA) n/a" } else { "" })
    foreach ($h in $Script:GroupHeaders) {
        $on = @($h.Names | Where-Object { $Script:TweakState[$_] -eq 'active' }).Count
        $h.Root.Tag.Text = "$($h.Names.Count) tweaks$($Script:Mid)$on active"
    }
    if (Get-Command Update-ScoreCard -ErrorAction SilentlyContinue)   { Update-ScoreCard }
    if (Get-Command Update-PresetCards -ErrorAction SilentlyContinue) { Update-PresetCards }
}

function Invoke-Verify {
    if ($Script:Busy) { return }
    Set-Busy $true
    try {
    $StatusText.Text = "Verifying tweak status..."
    $Window.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::Render)
    $active = 0; $inactive = 0; $unknown = 0; $i = 0; $n = @($AllTweaks).Count
    foreach ($tweak in $AllTweaks) {
        $i++
        if ($i % 12 -eq 0) { Set-Status "Verifying tweak status ... $i / $n" }
        if ($Script:TweakDots.ContainsKey($tweak.Name)) {
            $result = Update-TweakDot $Script:TweakDots[$tweak.Name] $tweak.Name
            switch ($result) {
                "active" {
                    $active++
                    # Tick the checkbox for tweaks detected as already active (green dot).
                    # Purely additive -- a manual selection on inactive tweaks is left alone.
                    if ($CheckBoxMap.ContainsKey($tweak.Name) -and $CheckBoxMap[$tweak.Name].IsEnabled) { $CheckBoxMap[$tweak.Name].IsChecked = $true }
                }
                "inactive" { $inactive++ }
                default    { $unknown++ }
            }
        }
    }
    Update-Counts
    $checkable = $active + $inactive
    $c = Get-StateCounts
    $StatusText.Text = "Verify complete: $active of $checkable checkable tweaks active (ticked)$($Script:Mid)$($c.OneTime) one-time actions" + $(if ($c.NA) { "$($Script:Mid)$($c.NA) not applicable here" } else { "" }) + "$($Script:Mid)verified $(Get-Date -Format 'HH:mm')"
    } finally { Set-Busy $false }
}

# =============================================================================
# NAVIGATION
# =============================================================================
$Script:Pages = [ordered]@{
    dashboard = @{ Page = $Window.FindName("PageDashboard"); Btn = $Window.FindName("NavDashboard"); Bar = $Window.FindName("NavBarDashboard"); Ico = $Window.FindName("NavIcoDashboard"); Txt = $Window.FindName("NavTxtDashboard"); Color = $Script:UI.RED }
    tweaks    = @{ Page = $Window.FindName("PageTweaks");    Btn = $Window.FindName("NavTweaks");    Bar = $Window.FindName("NavBarTweaks");    Ico = $Window.FindName("NavIcoTweaks");    Txt = $Window.FindName("NavTxtTweaks");    Color = $Script:UI.RED }
    presets   = @{ Page = $Window.FindName("PagePresets");   Btn = $Window.FindName("NavPresets");   Bar = $Window.FindName("NavBarPresets");   Ico = $Window.FindName("NavIcoPresets");   Txt = $Window.FindName("NavTxtPresets");   Color = $Script:UI.AMBER }
    bios      = @{ Page = $Window.FindName("PageBios");      Btn = $Window.FindName("NavBios");      Bar = $Window.FindName("NavBarBios");      Ico = $Window.FindName("NavIcoBios");      Txt = $Window.FindName("NavTxtBios");      Color = $Script:UI.AMBER }
    backups   = @{ Page = $Window.FindName("PageBackups");   Btn = $Window.FindName("NavBackups");   Bar = $Window.FindName("NavBarBackups");   Ico = $Window.FindName("NavIcoBackups");   Txt = $Window.FindName("NavTxtBackups");   Color = $Script:UI.VIOLET }
}
$Script:CurrentPage = ''
function Show-Page([string]$Key) {
    foreach ($k in $Script:Pages.Keys) {
        $p = $Script:Pages[$k]; $on = ($k -eq $Key)
        $p.Page.Visibility = $(if ($on) { 'Visible' } else { 'Collapsed' })
        $p.Btn.Background  = if ($on) { Brush (Mix-Hex $Script:UI.SIDE $p.Color 0.16) } else { [Windows.Media.Brushes]::Transparent }
        $p.Bar.Background  = Brush $p.Color
        $p.Bar.Visibility  = $(if ($on) { 'Visible' } else { 'Hidden' })
        $p.Ico.Foreground  = Brush $(if ($on) { $p.Color } else { $Script:UI.DIM })
        $p.Txt.Foreground  = Brush $(if ($on) { '#ffffff' } else { $Script:UI.TEXT2 })
        $p.Txt.FontWeight  = $(if ($on) { 'SemiBold' } else { 'Normal' })
    }
    $Script:CurrentPage = $Key
    if ($Key -eq 'bios' -and -not $Script:BiosDetectDone -and (Get-Command Invoke-BiosDetect -ErrorAction SilentlyContinue)) { Invoke-BiosDetect }
    if ($Key -eq 'backups' -and (Get-Command Build-BackupsPage -ErrorAction SilentlyContinue)) { Build-BackupsPage }
}
foreach ($k in @($Script:Pages.Keys)) {
    $key = $k
    $Script:Pages[$k].Btn.Add_Click({ Show-Page $key }.GetNewClosure())
}

# =============================================================================
# BUILD TWEAK PAGE  (category tabs + panels + rows)
# =============================================================================
foreach ($c in $Script:Cats) {
    $cat = $c
    $count = @($AllTweaks | Where-Object { $_.Category -eq $cat.Key }).Count
    $lbl = New-Text $cat.Label 12.5 $Script:UI.TEXT2
    $cnt = New-Text " $count" 11.5 $Script:UI.MUTED 'Normal' -Margin 3, 1, 0, 0
    $tab = New-Object Windows.Controls.Button
    $tab.Style = $Script:TabStyle; $tab.Content = New-HStack @($lbl, $cnt)
    $tab.Add_Click({ Select-Category $cat.Key }.GetNewClosure())
    $CatTabs.Children.Add($tab) | Out-Null
    $c.Tab = $tab; $c.TabLabel = $lbl; $c.TabCount = $cnt

    $panel = $c.Panel
    $title = New-Text $c.Label.ToUpper() 13 $c.Color 'SemiBold' -Margin 0, 10, 0, 6
    $title.Visibility = 'Collapsed'
    $panel.Children.Add($title) | Out-Null
    $c.Title = $title

    if ($c.Key -eq 'Windows 11') {
        $n = if ($IsWin11) { New-Banner "Windows 11 (build $OSBuild) detected -- all tweaks in this tab are available." $Script:UI.GREEN 0xE73E }
             else { New-Banner "Windows 10 detected (build $OSBuild) -- these tweaks need Windows 11 and are disabled." $Script:UI.AMBER 0xE7BA }
        $panel.Children.Add($n) | Out-Null; $Script:CatNotices += $n
    }
    if ($c.Key -eq 'GPU Tweaks') {
        # NVIDIA keeps its driver settings in its own profile database (NVIDIA app / Control
        # Panel), not in registry values a script could set -- so this tab is AMD only.
        $n = if ($IsAMD) { New-Banner "$GPU detected -- the AMD driver tweaks below are available." $Script:UI.RED 0xE7F4 }
             elseif ($IsNVIDIA) { New-Banner "$GPU detected -- these tweaks are for AMD cards only. NVIDIA keeps its driver settings in the NVIDIA app, not in the registry." $Script:UI.NV 0xE7F4 }
             else { New-Banner "$GPU detected -- these tweaks are for AMD cards only." $Script:UI.AMBER 0xE7F4 }
        $panel.Children.Add($n) | Out-Null; $Script:CatNotices += $n
    }
    if ($c.Key -eq 'Network') {
        try {
            $ns = Get-NetSummary
            $txt = if ($ns) { "$($ns.Name): $($ns.Desc)$(if ($ns.Speed) { " ($($ns.Speed))" })$($Script:Mid)gateway $(if ($ns.Gateway) { $ns.Gateway } else { 'unknown' })$($Script:Mid)DNS $(if ($ns.Dns.Count) { $ns.Dns -join ', ' } else { 'unknown' })" } else { "No active network adapter detected." }
        } catch { $txt = "Network info unavailable." }
        $n = New-Banner "$txt  (Ping test: Dashboard)" $Script:UI.CYAN 0xE839
        $panel.Children.Add($n) | Out-Null; $Script:CatNotices += $n
    }

    $groups = $AllTweaks | Where-Object { $_.Category -eq $cat.Key } | Select-Object -ExpandProperty Group -Unique
    $first = $true
    foreach ($group in $groups) {
        $names = @($AllTweaks | Where-Object { $_.Category -eq $cat.Key -and $_.Group -eq $group } | ForEach-Object { $_.Name })
        $hdr = New-SectionTitle $group $Script:UI.WIN11 '' $(if ($first) { @(0, 2, 0, 8) } else { @(0, 10, 0, 8) })
        $first = $false
        $panel.Children.Add($hdr) | Out-Null
        $Script:GroupHeaders += @{ Root = $hdr; Names = $names; Cat = $cat.Key }
        foreach ($tweak in ($AllTweaks | Where-Object { $_.Category -eq $cat.Key -and $_.Group -eq $group })) {
            $panel.Children.Add((New-TweakRow $tweak)) | Out-Null
            $Script:SplashRows++
            if ($Script:SplashRows % 4 -eq 0) { Set-Splash "Checking tweak status ... $($Script:SplashRows) / $($AllTweaks.Count)" (25 + [int](60 * $Script:SplashRows / $AllTweaks.Count)) }
        }
    }
}
$SearchBox.Add_TextChanged({ Apply-TweakFilter })

# -----------------------------------------
# BASELINE / DRIFT DETECTION
# Windows updates silently revert tweaks over time. On each Apply we snapshot
# which tweaks are currently active into a small file in AppData; on the next
# launch we re-check that snapshot and offer to re-apply anything Windows put
# back. This runs ONLY when the app is launched -- no background process, no
# service, no autostart. It just makes re-running the one-liner smarter.
# -----------------------------------------
# Stored as plain text, one tweak name per line (tweak names never contain
# newlines) -- avoids PowerShell 5.1's ConvertTo-Json single/nested-array quirks.
$Script:BaselineFile = "$env:LOCALAPPDATA\GameOptimizerPro\baseline.txt"

# Tweaks renamed in 1.2.6 -- their old names in a baseline or a saved selection still count
$Script:RenamedTweaks = @{
    'Disable Windows Update during Gaming' = 'Disable Automatic Windows Updates'
    'Disable Background App Throttling'    = 'Stop Background Apps (All Editions)'
}

# Services Manager: the start type a service had before "Disable" here, so "Enable" brings
# back exactly that instead of always "Manual" (Print Spooler & co. start automatically by
# default). One line per service: name=auto|delayed-auto|demand
$Script:SvcOriginalFile = "$env:LOCALAPPDATA\GameOptimizerPro\services_original.txt"

# Snapshot & compare is kept on disk, so a comparison survives a restart -- e.g. a snapshot
# before a Windows update, compared after it. Line 1 = time, then one name=T|F|N per tweak.
$Script:SnapshotFile = "$env:LOCALAPPDATA\GameOptimizerPro\snapshot.txt"
function Save-Snapshot($Snap) {
    try {
        New-Item -ItemType Directory -Path (Split-Path $Script:SnapshotFile) -Force -ErrorAction Stop | Out-Null
        $lines = @("# " + $Snap.Time.ToString('yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture)) +
                 @($Snap.States.Keys | Sort-Object | ForEach-Object { $v = $Snap.States[$_]; "$_=" + $(if ($v -eq $true) { 'T' } elseif ($v -eq $false) { 'F' } else { 'N' }) })
        $lines | Set-Content $Script:SnapshotFile -Encoding UTF8 -ErrorAction Stop
        $true
    } catch { Write-Log "Snapshot could not be saved: $_"; $false }
}
function Read-Snapshot {
    try {
        $lines = @(Get-Content $Script:SnapshotFile -ErrorAction Stop)
        if (-not $lines.Count -or $lines[0] -notmatch '^# (\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)$') { return $null }
        $time = [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture)
        $states = @{}
        foreach ($l in ($lines | Select-Object -Skip 1)) {
            if ($l -match '^(.+)=([TFN])$') { $states[$Matches[1]] = $(if ($Matches[2] -eq 'T') { $true } elseif ($Matches[2] -eq 'F') { $false } else { $null }) }
        }
        @{ Time = $time; States = $states }
    } catch { $null }
}
function Get-SvcStartMode([string]$Name) {
    $k = "HKLM:\SYSTEM\CurrentControlSet\Services\$Name"
    switch ("$(Get-RegVal $k 'Start')") {
        '2'   { if ((Get-RegVal $k 'DelayedAutostart') -eq 1) { 'delayed-auto' } else { 'auto' } }
        '3'   { 'demand' }
        '4'   { 'disabled' }
        default { $null }
    }
}
function Read-SvcOriginal {
    $m = @{}
    try { foreach ($l in @(Get-Content $Script:SvcOriginalFile -ErrorAction Stop)) { if ($l -match '^([^=]+)=(auto|delayed-auto|demand)$') { $m[$Matches[1]] = $Matches[2] } } } catch { }
    $m
}
function Save-SvcOriginal($Map) {
    try {
        New-Item -ItemType Directory -Path (Split-Path $Script:SvcOriginalFile) -Force -ErrorAction Stop | Out-Null
        @($Map.Keys | Sort-Object | ForEach-Object { "$_=$($Map[$_])" }) | Set-Content $Script:SvcOriginalFile -Encoding ASCII -ErrorAction Stop
    } catch { Write-Log "Services Manager: original start types could not be saved -- $_" }
}

# The baseline lists the tweaks THIS APP applied (line 1: "# GameOptimizerPro v<version>").
# Until 1.2.5 it listed every tweak that was active after an Apply -- also settings Windows or
# the user had made themselves -- and "Revert all" set every tweak back, applied or not.
function Read-Baseline {
    $r = @{ Version = $null; Names = @() }
    if (-not (Test-Path $Script:BaselineFile)) { return $r }
    try { $lines = @(Get-Content $Script:BaselineFile -ErrorAction Stop) } catch { return $r }
    $map = $Script:RenamedTweaks
    $known = @($AllTweaks | ForEach-Object { $_.Name })
    foreach ($l in $lines) {
        $t = "$l".Trim()
        if (-not $t) { continue }
        if ($t -match '^#\s*GameOptimizerPro\s+v?([0-9][0-9.]*)') { $r.Version = $matches[1]; continue }
        if ($t.StartsWith('#')) { continue }
        if ($map -and $map.ContainsKey($t)) { $t = $map[$t] }
        if ($known.Count -and $known -notcontains $t) { continue }     # removed in a later version
        $r.Names += $t
    }
    $r.Names = @($r.Names | Select-Object -Unique)
    $r
}
function Write-Baseline([string[]]$Names) {
    try {
        $dir = Split-Path $Script:BaselineFile
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Set-Content -Path $Script:BaselineFile -Value (@("# GameOptimizerPro v$($Script:AppVersion)") + @($Names | Where-Object { $_ } | Select-Object -Unique)) -Encoding UTF8 -ErrorAction Stop
        $true
    } catch { Write-Log "Baseline save failed: $_"; $false }
}
function Save-Baseline {
    # Adds the tweaks an Apply just put in effect to the list of what this app applied
    param([string[]]$Add)
    $names = @(@((Read-Baseline).Names) + @($Add | Where-Object { $_ }) | Select-Object -Unique)
    if (Write-Baseline $names) { Write-Log "Baseline saved ($($names.Count) tweaks applied by this app)" }
}

# The user declined re-applying these at launch, or set them back: stop tracking them, so the
# same question doesn't come back on every start. The next Apply records them again.
function Remove-FromBaseline([string[]]$Names) {
    if (-not (Test-Path $Script:BaselineFile)) { return }
    $keep = @((Read-Baseline).Names | Where-Object { $Names -notcontains $_ })
    if (Write-Baseline $keep) { Write-Log "Baseline: no longer tracking (re-apply declined or reverted): $($Names -join ', ')" }
}

# Current status of one tweak, read fresh ($true only when its check says so)
function Test-TweakActive([string]$Name) {
    if (-not $CheckFunctions.ContainsKey($Name)) { return $false }
    try { (& $CheckFunctions[$Name]) -eq $true } catch { $false }
}

# System Protection (System Restore) for the Windows drive: $true on, $false off. Windows lists
# the protected volumes in SPP\Clients -- the value System Properties > System Protection reads --
# as volume paths ("\\?\Volume{guid}\..."). Without it no restore point can be created.
function Test-SystemProtection {
    $list = @(Get-RegVal "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SPP\Clients" '{09F7EDC5-294E-4180-AF6A-FB0E6A0E9513}' | Where-Object { $_ })
    if (-not $list.Count) { return $false }
    $vol = try { "$((Get-CimInstance Win32_Volume -Filter "DriveLetter='$env:SystemDrive'" -ErrorAction Stop).DeviceID)" } catch { '' }
    $guid = if ($vol -match '(\{[0-9a-fA-F-]+\})') { $matches[1] } else { $null }
    [bool]@($list | Where-Object { ($guid -and "$_".IndexOf($guid, [StringComparison]::OrdinalIgnoreCase) -ge 0) -or "$_".IndexOf("($env:SystemDrive", [StringComparison]::OrdinalIgnoreCase) -ge 0 }).Count
}

function Get-DriftedTweaks {
    # -Known: check results already gathered this session (Name -> T/F/N/E, see
    # $Script:CheckRaw), so the launch check doesn't run every check a second time.
    # Only a definite $false counts as reverted: "can't read it right now" ($null,
    # e.g. while Windows Update servicing locks the reserved-storage API) is not.
    param([hashtable]$Known = @{})
    $drifted = @()
    foreach ($n in (Read-Baseline).Names) {
        if ($Known.ContainsKey($n)) { if ($Known[$n] -eq 'F') { $drifted += $n }; continue }
        if ($CheckFunctions.ContainsKey($n)) {
            try { $r = & $CheckFunctions[$n]; if ($r -is [bool] -and -not $r) { $drifted += $n } } catch { }
        }
    }
    return $drifted
}

# =============================================================================
# BIOS GUIDE  --  every desktop platform since Intel 8th gen / AMD Ryzen 1000,
# with the menu path per board maker (ported from GameOptimizerPro v2.1
# core/bios_guide.py). Detection only PRE-SELECTS platform + board maker;
# every profile can be opened. Read-only: nothing here changes the PC.
# =============================================================================
$Script:BiosVendors = [ordered]@{ asus = 'ASUS'; msi = 'MSI'; gigabyte = 'Gigabyte'; asrock = 'ASRock'; other = 'Other / unknown' }

function New-BiosSetting {
    param([string]$Key, [string]$Cat, [string]$Name, [string]$Rec, [string]$Def, [string]$Path, [string]$Expl, [string]$ExplDE,
          [string]$Risk = 'safe', [string]$Impact = 'medium', [string]$Detect = '', [hashtable]$Paths = @{})
    [pscustomobject]@{ Key = $Key; Cat = $Cat; Name = $Name; Rec = $Rec; Def = $Def; Path = $Path; Expl = $Expl; ExplDE = $ExplDE
                       Risk = $Risk; Impact = $Impact; Detect = $Detect; Paths = $Paths }
}

function BS-MemoryProfile([string]$Brand, [string]$Ddr, [string]$Target, [string]$Note = '', [string]$NoteDE = '') {
    $amd = $Brand -eq 'amd'
    $name = if ($amd) { if ($Ddr -eq 'DDR5') { 'EXPO profile' } else { 'D.O.C.P. / A-XMP profile' } } else { 'XMP profile' }
    $paths = if ($amd) { @{
        asus = "Ai Tweaker -> Ai Overclock Tuner -> $(if ($Ddr -eq 'DDR5') { 'EXPO I' } else { 'D.O.C.P.' })"
        msi = 'OC -> A-XMP / EXPO -> Profile 1 (or the EXPO / A-XMP switch in EZ Mode)'
        gigabyte = 'Tweaker -> Extreme Memory Profile (X.M.P.) / EXPO -> Profile1 (also in Easy Mode)'
        asrock = 'OC Tweaker -> DRAM Profile Configuration -> DRAM Profile Setting -> EXPO/XMP profile 1' }
    } else { @{
        asus = 'Ai Tweaker -> Ai Overclock Tuner -> XMP I'
        msi = 'OC -> Extreme Memory Profile (XMP) -> Profile 1 (or the XMP switch in EZ Mode)'
        gigabyte = 'Tweaker -> Extreme Memory Profile (X.M.P.) -> Profile1 (also in Easy Mode)'
        asrock = 'OC Tweaker -> DRAM Profile Configuration -> XMP profile 1' } }
    New-BiosSetting -Key 'memory_profile' -Cat 'Memory' -Name $name -Rec "Profile 1 ($Target)" -Def 'Off -- JEDEC base clock' `
        -Path 'OC / Tweaker menu -> memory profile (EXPO or XMP / DOCP) -> Profile 1' `
        -Expl ("Without a profile the RAM only runs at the slow $Ddr base clock -- the biggest free gain in the BIOS, especially for the 1% lows in CPU-heavy games. " + $(if ($Note) { "$Note " }) + "If the PC won't boot or crashes afterwards: try profile 2 or one speed step lower; many boards reset themselves after 3 failed boots.") `
        -ExplDE ("Ohne Profil läuft der RAM nur mit dem langsamen $Ddr-Standardtakt -- der größte kostenlose Gewinn im BIOS, vor allem für die 1-%-Lows in CPU-lastigen Spielen. " + $(if ($NoteDE) { "$NoteDE " }) + "Startet der PC danach nicht oder gibt es Abstürze: Profil 2 oder ein Takt-Schritt niedriger; viele Boards setzen nach 3 Fehlstarts selbst zurück.") `
        -Risk 'safe' -Impact 'high' -Detect 'expo_xmp' -Paths $paths
}
function BS-Rebar([string]$Brand, [string]$Note = '', [string]$NoteDE = '') {
    New-BiosSetting -Key 'rebar' -Cat 'GPU' -Name 'Resizable BAR (+ Above 4G Decoding)' -Rec 'Above 4G Decoding = Enabled, Re-Size BAR Support = Enabled' -Def 'Disabled' `
        -Path 'PCI / IO settings -> Above 4G Decoding = Enabled -> Re-Size BAR Support = Enabled' `
        -Expl ("Lets the CPU address the whole video memory at once instead of 256 MB chunks. NVIDIA uses it for the games it is enabled for in the driver; on AMD cards it is called Smart Access Memory and works almost everywhere. Requires CSM off (UEFI boot). $Note").Trim() `
        -ExplDE ("Die CPU darf den ganzen Grafikspeicher auf einmal ansprechen statt in 256-MB-Häppchen. NVIDIA nutzt es für die Spiele, für die es im Treiber freigegeben ist; bei AMD-Karten heißt es 'Smart Access Memory' und wirkt fast überall. Voraussetzung: CSM aus (UEFI-Start). $NoteDE").Trim() `
        -Risk 'safe' -Impact 'high' -Detect 'rebar' -Paths @{
            asus = 'Advanced -> PCI Subsystem Settings -> Above 4G Decoding = Enabled -> Re-Size BAR Support = Enabled'
            msi = 'Settings -> Advanced -> PCIe/PCI Sub-system Settings -> Above 4G memory/Crypto Currency mining = Enabled -> Re-Size BAR Support = Enabled'
            gigabyte = 'Settings -> IO Ports -> Above 4G Decoding = Enabled -> Re-Size BAR Support = Auto/Enabled'
            asrock = "Advanced -> PCI Configuration -> Above 4G Decoding = Enabled -> Re-Size BAR Support$(if ($Brand -eq 'amd') { ' (on AMD boards also called C.A.M.)' }) = Enabled" }
}
function BS-Csm {
    New-BiosSetting -Key 'csm' -Cat 'Boot' -Name 'CSM (legacy boot) off' -Rec 'Disabled (pure UEFI boot)' -Def 'Auto / Enabled depending on the board' `
        -Path 'Boot -> CSM (Compatibility Support Module) -> Disabled' `
        -Expl 'The old legacy BIOS mode. Off is required for Resizable BAR and Secure Boot. IMPORTANT: only turn it off if Windows is installed in UEFI mode -- check with msinfo32 -> BIOS Mode: UEFI. If it says Legacy, Windows will not boot without CSM.' `
        -ExplDE "Der alte Legacy-BIOS-Modus. Aus = Voraussetzung für Resizable BAR und Secure Boot. WICHTIG: nur ausschalten, wenn Windows im UEFI-Modus installiert ist -- prüfen mit msinfo32 -> 'BIOS-Modus: UEFI'. Steht dort 'Legacy', startet Windows ohne CSM nicht." `
        -Risk 'moderate' -Impact 'medium' -Detect 'csm' -Paths @{
            asus = 'Boot -> CSM (Compatibility Support Module) -> Launch CSM = Disabled'
            msi = 'Settings -> Advanced -> Windows OS Configuration -> BIOS UEFI/CSM Mode = UEFI'
            gigabyte = 'Boot -> CSM Support = Disabled'
            asrock = 'Boot -> CSM (Compatibility Support Module) -> CSM = Disabled' }
}
function BS-SecureBoot {
    New-BiosSetting -Key 'secure_boot' -Cat 'Boot' -Name 'Secure Boot' -Rec 'Enabled' -Def 'often Disabled (or Other OS)' `
        -Path 'Boot / Security -> Secure Boot = Enabled' `
        -Expl 'No FPS gain, but more and more games require it: Valorant/Vanguard on Windows 11, Battlefield 6, Call of Duty and other anti-cheats will not start without Secure Boot. Needs CSM off. If the BIOS reports missing keys: Restore Factory Keys / Install default Secure Boot keys.' `
        -ExplDE "Bringt keine FPS, ist aber für immer mehr Spiele Pflicht: Valorant/Vanguard unter Windows 11, Battlefield 6, Call of Duty und weitere Anti-Cheats starten ohne Secure Boot nicht. Braucht CSM aus. Meldet das BIOS fehlende Schlüssel: 'Restore Factory Keys' bzw. 'Install default Secure Boot keys'." `
        -Risk 'safe' -Impact 'medium' -Detect 'secure_boot' -Paths @{
            asus = 'Boot -> Secure Boot -> OS Type = Windows UEFI mode'
            msi = 'Settings -> Security -> Secure Boot -> Secure Boot = Enabled'
            gigabyte = 'Boot -> Secure Boot -> Secure Boot = Enabled'
            asrock = 'Security -> Secure Boot -> Secure Boot = Enabled' }
}
function BS-BiosUpdate([string]$What, [string]$WhatDE, [string]$Risk = 'safe', [string]$Impact = 'medium') {
    New-BiosSetting -Key 'bios_update' -Cat 'Boot' -Name 'Keep the BIOS up to date' -Rec 'latest version from the board maker' -Def 'factory version' `
        -Path "BIOS flash tool -- file from the board's support page on a FAT32 USB stick" `
        -Expl "$What Before flashing, note your EXPO/XMP setting (everything is reset to defaults afterwards) and never switch the PC off while it flashes." `
        -ExplDE "$WhatDE Vor dem Flashen das EXPO/XMP-Profil notieren (danach ist alles auf Standard) und den PC währenddessen nicht ausschalten." `
        -Risk $Risk -Impact $Impact -Paths @{
            asus = 'Tool -> ASUS EZ Flash 3 Utility (file on a USB stick)'
            msi = 'M-FLASH (start screen, bottom left) -- file on a USB stick'
            gigabyte = 'Q-Flash (F8) -- file on a USB stick'
            asrock = 'Tool -> Instant Flash -- file on a USB stick' }
}
function BS-AutoInstall {
    New-BiosSetting -Key 'autoinstall' -Cat 'Boot' -Name 'Board maker auto-install off' -Rec 'Disabled' -Def 'Enabled' `
        -Path 'Maker menu -> automatic installation of board software = Disabled' `
        -Expl 'Otherwise the board silently installs vendor software, background services and driver downloaders on the first Windows start (Armoury Crate, MSI Center, GIGABYTE Control Center ...). Get the drivers you need directly from the maker''s website.' `
        -ExplDE 'Sonst installiert das Board beim ersten Windows-Start ungefragt Hersteller-Software, Hintergrunddienste und Treiber-Downloader (Armoury Crate, MSI Center, GIGABYTE Control Center ...). Treiber bei Bedarf direkt von der Hersteller-Seite laden.' `
        -Risk 'safe' -Impact 'low' -Paths @{
            asus = 'Tool -> ASUS Armoury Crate -> Download & Install ARMOURY CRATE app = Disabled'
            msi = 'Settings -> Advanced -> MSI Driver Utility Installer = Disabled'
            gigabyte = 'Settings -> GIGABYTE Utilities Downloader Configuration -> Disabled'
            asrock = 'Tool -> Auto Driver Installer = Disabled' }
}
function BS-PcieGpu {
    New-BiosSetting -Key 'pcie_gpu' -Cat 'GPU' -Name 'PCIe speed of the graphics card slot' -Rec 'Auto' -Def 'Auto' `
        -Path 'PCIe settings of the GPU slot (e.g. PCIEX16_1 Link Speed / PCI_E1 Gen Switch) = Auto' `
        -Expl 'On Auto the card uses the fastest mode that slot and card support. Only on black screens, flickering or no signal after installing a card (especially RTX 50 / PCIe 5.0 with a riser cable) set it one step lower (Gen 4) -- costs practically nothing in games.' `
        -ExplDE "Auf Auto nimmt die Karte die schnellste Stufe, die Slot und Karte können. Nur bei Schwarzbild, Bildaussetzern oder 'kein Signal' nach dem Einbau (vor allem RTX 50 / PCIe 5.0 mit Riser-Kabel) eine Stufe fest einstellen (Gen 4) -- kostet in Spielen praktisch nichts." `
        -Risk 'safe' -Impact 'low'
}
$Script:AmdPboPaths = @{
    asus = 'Ai Tweaker -> Precision Boost Overdrive (AM4: Advanced -> AMD Overclocking -> Precision Boost Overdrive)'
    msi = 'OC -> Advanced CPU Configuration -> AMD Overclocking -> Precision Boost Overdrive'
    gigabyte = 'Tweaker -> Advanced CPU Settings -> Precision Boost Overdrive (or Settings -> AMD Overclocking)'
    asrock = 'Advanced -> AMD Overclocking -> Precision Boost Overdrive' }
$Script:AmdCoPaths = @{
    asus = 'Ai Tweaker -> Precision Boost Overdrive -> Curve Optimizer -> All Cores -> Negative'
    msi = 'OC -> Advanced CPU Configuration -> AMD Overclocking -> Precision Boost Overdrive -> Advanced -> Curve Optimizer'
    gigabyte = 'Tweaker -> Advanced CPU Settings -> Precision Boost Overdrive -> Curve Optimizer'
    asrock = 'Advanced -> AMD Overclocking -> Precision Boost Overdrive -> Curve Optimizer' }
function BS-Pbo([string]$Kind) {
    $t = @{
        zen5     = @('Enabled (PBO limits: Motherboard)', 'moderate', 'medium',
                     'Lets the CPU draw more power and boost higher for longer. Usually 1-3 % in games, more in multi-core loads -- but warmer. Worth it with a good cooler; together with the Curve Optimizer it gains the most.',
                     'Laesst die CPU mehr Strom ziehen und länger hoch boosten. In Spielen meist 1-3 %, in Mehrkern-Last mehr -- dafür wärmer. Mit einem guten Kühler sinnvoll; zusammen mit dem Curve Optimizer bringt es am meisten.')
        zen5_x3d = @('Enabled (+ up to +200 MHz Boost Override)', 'moderate', 'medium',
                     'Unlike the 7000X3D, the 9000X3D are unlocked: PBO with Curve Optimizer and up to +200 MHz Boost Override is allowed. Keep an eye on temperatures (the cache now sits under the cores, so cooling is better than on Zen 4).',
                     'Die 9000X3D sind -- anders als die 7000X3D -- offen: PBO mit Curve Optimizer und bis zu +200 MHz Boost Override ist erlaubt. Temperaturen im Blick behalten (der Cache sitzt jetzt unter den Kernen, die Kühlung ist dadurch besser als bei Zen 4).')
        zen4_x3d = @('Advanced -> Curve Optimizer only (limits: Auto)', 'moderate', 'medium',
                     'On the 7000X3D clocks and power limits are locked -- PBO only works through the Curve Optimizer (negative = less voltage -> more boost at the same temperature).',
                     'Bei den 7000X3D sind Takt und Leistungsgrenzen gesperrt -- PBO wirkt nur über den Curve Optimizer (negativ = weniger Spannung -> mehr Boost bei gleicher Temperatur).')
        zen4     = @('Enabled', 'moderate', 'medium',
                     'More boost under load; little in games, clearly more in multi-core loads. Ryzen 7000 quickly reaches 95 C -- that is by design, but with the Curve Optimizer the CPU stays cooler.',
                     'Mehr Boost unter Last; in Spielen wenig, in Mehrkern-Last deutlich. Ryzen 7000 wird schnell 95 Grad heiß -- das ist bei ihnen gewollt, aber mit Curve Optimizer bleibt die CPU kuehler.')
        zen3     = @('Enabled', 'moderate', 'medium',
                     'More boost under load. Together with a negative Curve Optimizer the best lever on Ryzen 5000.',
                     'Mehr Boost unter Last. Zusammen mit einem negativen Curve Optimizer der beste Hebel bei Ryzen 5000.')
        zen2     = @('Auto / Enabled', 'moderate', 'low',
                     'On Ryzen 3000 PBO gains little (mostly < 2 %) -- it can stay on if the cooler copes.',
                     'Bei Ryzen 3000 bringt PBO nur wenig (meist < 2 %) -- kann an bleiben, wenn der Kühler reicht.')
    }[$Kind]
    New-BiosSetting -Key 'pbo' -Cat 'CPU' -Name 'Precision Boost Overdrive (PBO)' -Rec $t[0] -Def 'Auto (= off)' `
        -Path 'Advanced -> AMD Overclocking -> Precision Boost Overdrive' -Expl $t[3] -ExplDE $t[4] -Risk $t[1] -Impact $t[2] -Paths $Script:AmdPboPaths
}
function BS-CurveOptimizer([string]$Rec, [string]$Expl, [string]$ExplDE) {
    New-BiosSetting -Key 'curve_optimizer' -Cat 'CPU' -Name 'Curve Optimizer (undervolting)' -Rec $Rec -Def '0 (off)' `
        -Path 'AMD Overclocking -> Precision Boost Overdrive -> Curve Optimizer' `
        -Expl "$Expl Test stability afterwards (e.g. OCCT or CoreCycler, also at idle -- instability often shows while browsing, not under load)." `
        -ExplDE "$ExplDE Danach stabil testen (z. B. OCCT oder CoreCycler, auch im Leerlauf -- Instabilität zeigt sich oft beim Surfen, nicht unter Last)." `
        -Risk 'moderate' -Impact 'medium' -Paths $Script:AmdCoPaths
}
function BS-Fclk([string]$Value, [string]$Expl, [string]$ExplDE) {
    New-BiosSetting -Key 'fclk' -Cat 'Memory' -Name 'Infinity Fabric (FCLK)' -Rec $Value -Def 'Auto' `
        -Path 'AMD Overclocking -> DDR and Infinity Fabric Frequency/Timings -> Infinity Fabric Frequency and Dividers -> FCLK' `
        -Expl "$Expl If crashes or USB dropouts appear afterwards: back to Auto." -ExplDE "$ExplDE Gibt es danach Abstürze oder USB-Aussetzer: zurück auf Auto." `
        -Risk 'moderate' -Impact 'medium' -Paths @{ asus = 'Ai Tweaker -> FCLK Frequency'; msi = 'OC -> FCLK Frequency' }
}
function BS-Mcr {
    New-BiosSetting -Key 'mcr' -Cat 'Memory' -Name 'Memory Context Restore' -Rec 'Enabled' -Def 'Auto (usually off)' `
        -Path 'Advanced -> AMD CBS -> UMC Common Options -> DDR Options -> DDR Memory Features -> Memory Context Restore' `
        -Expl 'Skips the long memory training on every start (DDR5 on AM5 otherwise shows 20-60 s of black screen). Newer BIOS versions make this stable; if boot problems or crashes after waking appear: back to Auto.' `
        -ExplDE 'Spart das lange Speichertraining bei jedem Start (DDR5 auf AM5 sonst 20-60 s schwarzer Bildschirm). Neuere BIOS-Versionen machen das stabil; gibt es danach Startprobleme oder Abstürze nach dem Aufwachen: wieder Auto.' `
        -Risk 'moderate' -Impact 'low' -Paths @{
            asus = 'Ai Tweaker -> DRAM Timing Control -> Memory Context Restore'
            msi = 'OC -> Advanced DRAM Configuration -> Memory Context Restore'
            gigabyte = 'Tweaker -> Advanced Memory Settings -> Memory Context Restore' }
}
function BS-CStatesAmd {
    New-BiosSetting -Key 'cstates' -Cat 'Power' -Name 'Global C-State Control' -Rec 'leave Auto / Enabled' -Def 'Auto' `
        -Path 'Advanced -> AMD CBS -> CPU Common Options -> Global C-state Control' `
        -Expl 'Often recommended off for lower latency -- on Ryzen that gains practically nothing in games, but costs idle power and can lower the single-core boost (the highest boost needs sleeping neighbour cores). So leave it on.' `
        -ExplDE "Oft wird 'aus für weniger Latenz' empfohlen -- bei Ryzen bringt das in Spielen praktisch nichts, kostet aber Strom im Leerlauf und kann den Einkern-Boost senken (der höchste Boost braucht schlafende Nachbarkerne). Also an lassen." `
        -Risk 'safe' -Impact 'low' -Paths @{
            msi = 'OC -> Advanced CPU Configuration -> Global C-state Control'
            gigabyte = 'Tweaker -> Advanced CPU Settings -> Global C-state Control' }
}
function BS-IgpuOff([bool]$Apu = $false) {
    if ($Apu) {
        return New-BiosSetting -Key 'igpu' -Cat 'GPU' -Name 'iGPU video memory (UMA Frame Buffer)' -Rec 'without a graphics card: 2-4 GB; with a graphics card: iGPU off' -Def 'Auto (often 512 MB)' `
            -Path 'Advanced -> AMD CBS -> NBIO Common Options -> GFX Configuration -> UMA Frame buffer Size' `
            -Expl 'If you game on the integrated graphics, a larger fixed video memory gives many games more headroom (enough RAM provided -- 32 GB recommended). With a dedicated graphics card, turn the iGPU off.' `
            -ExplDE 'Spielst du über die integrierte Grafik, gibt ein größerer fester Grafikspeicher vielen Spielen mehr Luft (genug RAM vorausgesetzt -- 32 GB empfohlen). Mit dedizierter Grafikkarte die iGPU ausschalten.' `
            -Risk 'safe' -Impact 'medium'
    }
    New-BiosSetting -Key 'igpu' -Cat 'GPU' -Name 'Integrated graphics (iGPU) off' -Rec 'Disabled (only with a graphics card)' -Def 'Auto / Enabled' `
        -Path 'Advanced -> AMD CBS -> NBIO Common Options -> GFX Configuration -> iGPU Configuration = iGPU Disabled' `
        -Expl 'Ryzen 7000/9000 have a small iGPU. With a dedicated graphics card you do not need it; off saves a little power and memory and stops programs from picking the wrong GPU. Make sure the monitor is connected to the graphics card.' `
        -ExplDE 'Ryzen 7000/9000 haben eine kleine iGPU. Mit dedizierter Grafikkarte braucht man sie nicht; aus spart etwas Strom und Arbeitsspeicher und verhindert, dass Programme die falsche GPU wählen. Monitor dann unbedingt an der Grafikkarte anschließen.' `
        -Risk 'moderate' -Impact 'low' -Paths @{
            asus = 'Advanced -> NB Configuration -> Integrated Graphics = Disabled'
            msi = 'Settings -> Advanced -> Integrated Graphics Configuration -> Integrated Graphics = Disabled'
            gigabyte = 'Settings -> IO Ports -> Integrated Graphics = Disabled' }
}
function BS-CppcX3d {
    New-BiosSetting -Key 'x3d_cppc' -Cat 'CPU' -Name 'Core scheduling on X3D with two CCDs' -Rec 'CPPC Dynamic Preferred Cores = Auto (Driver)' -Def 'Auto' `
        -Path 'Advanced -> AMD CBS -> SMU Common Options -> CPPC Dynamic Preferred Cores' `
        -Expl "Only 7900X3D/7950X3D/9900X3D/9950X3D: games should run on the CCD with the 3D cache. AMD's chipset driver handles that together with Windows Game Mode and the Xbox Game Bar -- leave the BIOS on Auto and install the current chipset driver. On 7800X3D/9800X3D (one CCD) there is nothing to do." `
        -ExplDE 'Nur 7900X3D/7950X3D/9900X3D/9950X3D: Spiele sollen auf dem CCD mit dem 3D-Cache laufen. Das übernimmt AMDs Chipsatz-Treiber zusammen mit dem Windows-Spielmodus und der Xbox Game Bar -- im BIOS auf Auto lassen, aktuellen Chipsatz-Treiber installieren. Bei 7800X3D/9800X3D (ein CCD) gibt es nichts zu tun.' `
        -Risk 'safe' -Impact 'medium'
}
function BS-IntelDefault([string]$Gen) {
    $t = @{
        rpl = @('Intel Default Settings = Performance (i9-K: PL1 = PL2 = 253 W, ICCMax 307 A)',
                "Many boards ran 13th/14th gen without power limits -- together with the Vmin Shift bug that caused crashes and permanently damaged CPUs. Intel's Performance profile (Extreme only for i9-K with a very good cooler) is the safe state; in games it costs practically nothing.",
                "Viele Boards ließen 13./14. Gen ohne Leistungsgrenze laufen -- zusammen mit dem Vmin-Shift-Fehler führte das zu Abstürzen und dauerhaft geschädigten CPUs. Intels Vorgabe 'Performance' (bzw. 'Extreme' nur für i9-K mit sehr gutem Kühler) ist der sichere Stand; in Spielen kostet sie praktisch nichts.")
        adl = @('PL1 / PL2 per Intel (e.g. i9-12900K: 125 W / 241 W)',
                "The board default is often unlimited -- that gains little in games but makes the CPU very hot. Intel's values are listed on ark.intel.com.",
                "Board-Standard ist oft 'unbegrenzt' -- das bringt in Spielen kaum etwas, macht die CPU aber sehr heiß. Intels Werte stehen auf ark.intel.com.")
        arl = @('Intel Default Settings = Performance',
                "Intel's recommended state for Core Ultra 200S; some boards start with unlimited power.",
                "Der von Intel empfohlene Stand für Core Ultra 200S; manche Boards starten mit 'unbegrenzt'.")
    }[$Gen]
    New-BiosSetting -Key 'intel_power' -Cat 'Power' -Name 'Power limits (Intel Default Settings)' -Rec $t[0] -Def 'unlimited on many boards' `
        -Path 'CPU / OC menu -> Intel Default Settings or Long/Short Duration Power Limit (PL1/PL2)' -Expl $t[1] -ExplDE $t[2] `
        -Risk $(if ($Gen -eq 'rpl') { 'safe' } else { 'moderate' }) -Impact 'medium' -Paths @{
            asus = 'Ai Tweaker -> Intel Default Settings (older BIOS: Internal CPU Power Management -> PL1/PL2)'
            msi = 'OC -> Intel Default Settings (older BIOS: Advanced CPU Configuration -> Long/Short Duration Power Limit)'
            gigabyte = 'Tweaker -> Intel Default Settings (older BIOS: Advanced CPU Settings -> Turbo Power Limits)'
            asrock = 'OC Tweaker -> CPU Configuration -> Intel Default Settings or Long/Short Duration Power Limit' }
}
function BS-Mce {
    New-BiosSetting -Key 'mce' -Cat 'CPU' -Name 'Multi-Core Enhancement' -Rec 'Auto (performance) -- if too hot: Disabled' -Def 'Auto / Enabled' `
        -Path 'OC menu -> Multi-Core Enhancement' `
        -Expl "Runs all cores at the single-core turbo (outside Intel's spec). A few percent more performance, but clearly more heat -- with a weak cooler choose Disabled." `
        -ExplDE 'Laesst alle Kerne mit dem Einkern-Turbo laufen (außerhalb von Intels Vorgabe). Ein paar Prozent mehr Leistung, dafür deutlich mehr Wärme -- mit schwachem Kühler Disabled wählen.' `
        -Risk 'moderate' -Impact 'low' -Paths @{
            asus = 'Ai Tweaker -> ASUS MultiCore Enhancement'
            msi = 'OC -> Enhanced Turbo'
            gigabyte = 'Tweaker -> Advanced CPU Settings -> Enhanced Multi-Core Performance'
            asrock = 'OC Tweaker -> CPU Configuration -> Multi Core Enhancement' }
}
function BS-200SBoost {
    New-BiosSetting -Key '200s_boost' -Cat 'Memory' -Name 'Intel 200S Boost' -Rec 'Enabled (with matching RAM)' -Def 'Disabled' `
        -Path 'OC menu -> Intel 200S Boost (BIOS with microcode 0x114 or newer)' `
        -Expl "Intel's official, warranty-covered overclock for Core Ultra 200S: faster die-to-die / NGU links and RAM up to DDR5-8000. Gains a few percent in games -- Arrow Lake's biggest weakness is memory latency." `
        -ExplDE 'Intels offizielle, von der Garantie gedeckte Übertaktung für Core Ultra 200S: schnellere Verbindung zwischen den Kacheln (D2D/NGU) und RAM bis DDR5-8000. Bringt in Spielen einige Prozent -- die größte Schwäche von Arrow Lake ist die Speicher-Latenz.' `
        -Risk 'safe' -Impact 'medium' -Paths @{
            asus = 'Ai Tweaker -> Intel(R) 200S Boost'; msi = 'OC -> Intel 200S Boost'; gigabyte = 'Tweaker -> Intel 200S Boost'; asrock = 'OC Tweaker -> Intel 200S Boost' }
}
function BS-ECores {
    New-BiosSetting -Key 'ecores' -Cat 'CPU' -Name 'E-Cores' -Rec 'leave Enabled' -Def 'Enabled' -Path 'CPU configuration -> Active Efficient Cores = All' `
        -Expl 'Disabling E-cores used to help some games. With Windows 11 and Thread Director games land on the P-cores today; disabling costs performance in everything else. Only test it for a single game with problems (old anti-cheats).' `
        -ExplDE 'Früher half das Abschalten der E-Cores manchen Spielen. Mit Windows 11 und dem Thread Director landen Spiele heute auf den P-Cores; abschalten kostet Leistung bei allem anderen. Nur bei einem einzelnen Spiel mit Problemen (alte Anti-Cheats) testen.' `
        -Risk 'safe' -Impact 'low'
}
function BS-Am5Base([string]$Zen) {
    @(
        (BS-MemoryProfile 'amd' 'DDR5' 'DDR5-6000 CL30 is the sweet spot' 'AM5 runs best with DDR5-6000 to -6400 in 1:1 mode (UCLK = MCLK).' 'AM5 läuft am besten mit DDR5-6000 bis -6400 im 1:1-Modus (UCLK = MCLK).'),
        (BS-Fclk $(if ($Zen -eq 'zen5') { '2000 MHz (Zen 5 often 2100)' } else { '2000 MHz' }) 'The link between cores and memory controller. With DDR5-6000, 2000 MHz is usual and stable; Auto often leaves 1733-1800 MHz.' 'Die Verbindung zwischen Kernen und Speicher-Controller. Bei DDR5-6000 sind 2000 MHz üblich und stabil; Auto lässt oft 1733-1800 MHz liegen.'),
        (BS-Mcr), (BS-CStatesAmd), (BS-Rebar 'amd'), (BS-PcieGpu), (BS-IgpuOff $false), (BS-Csm), (BS-SecureBoot),
        (BS-BiosUpdate 'New AGESA versions bring noticeably shorter boot times, better RAM support and performance fixes on AM5 (Zen 5: the 2-core latency update).' "Neue AGESA-Versionen bringen bei AM5 spürbar kürzere Startzeiten, besseren RAM-Support und Leistungs-Fixes (Zen 5: '2-Kern-Latenz'-Update)."),
        (BS-AutoInstall)
    )
}
function New-BiosProfile([string]$Id, [string]$Name, [string]$Short, [string]$Cpus, [string]$Platform, [string]$Brand, [object[]]$Settings, [string]$Notes = '', [string]$NotesDE = '') {
    [pscustomobject]@{ Id = $Id; Name = $Name; Short = $Short; Cpus = $Cpus; Platform = $Platform; Brand = $Brand; Settings = @($Settings); Notes = $Notes; NotesDE = $NotesDE }
}
$amCO1 = 'Lowers temperature and raises boost.'; $amCO1DE = 'Senkt Temperatur und hebt den Boost.'
$am4Rebar = 'AM4 needs a BIOS from 2021 or newer for this.'; $am4RebarDE = 'AM4 braucht dafür ein BIOS von 2021 oder neuer.'
$Script:BiosProfiles = @(
    (New-BiosProfile 'am5_zen5_x3d' 'AMD Ryzen 9000X3D (Zen 5 + 3D V-Cache) -- AM5' 'Ryzen 9000X3D' 'Ryzen 7 9800X3D, Ryzen 9 9900X3D, 9950X3D' 'AM5 -- X870E / X870 / B850 / B840 / X670E / X670 / B650 / A620' 'amd' `
        (@((BS-Pbo 'zen5_x3d'), (BS-CurveOptimizer 'All Cores, Negative 15-25' 'Most 9800X3D handle -15 to -25; less voltage = more boost at the same temperature.' 'Die meisten 9800X3D vertragen -15 bis -25; weniger Spannung = mehr Boost bei gleicher Temperatur.'), (BS-CppcX3d)) + (BS-Am5Base 'zen5')) `
        'The best gaming CPU family -- the 3D cache does most of the work. Enabling EXPO is a must, PBO / Curve Optimizer are fine-tuning.' 'Die beste Gaming-CPU-Familie -- der 3D-Cache macht den größten Teil der Arbeit. EXPO aktivieren ist Pflicht, PBO/Curve Optimizer sind Feinschliff.'),
    (New-BiosProfile 'am5_zen5' 'AMD Ryzen 9000 (Zen 5) -- AM5' 'Ryzen 9000' 'Ryzen 5 9600(X), Ryzen 7 9700X, Ryzen 9 9900X, 9950X' 'AM5 -- X870E / X870 / B850 / B840 / X670E / X670 / B650 / A620' 'amd' `
        (@((BS-Pbo 'zen5'), (BS-CurveOptimizer 'All Cores, Negative 10-20' 'Zen 5 usually handles -10 to -20.' 'Zen 5 verträgt meist -10 bis -20.')) + (BS-Am5Base 'zen5')) `
        'The 9600X/9700X ship with a 65 W limit; PBO (or the 105 W mode of some BIOS versions) raises it -- in games that gains little.' '9600X/9700X kommen ab Werk mit 65-W-Grenze; PBO (oder der 105-W-Modus mancher BIOS) hebt sie an -- in Spielen bringt das nur wenig.'),
    (New-BiosProfile 'am5_zen4_x3d' 'AMD Ryzen 7000X3D (Zen 4 + 3D V-Cache) -- AM5' 'Ryzen 7000X3D' 'Ryzen 7 7800X3D, Ryzen 9 7900X3D, 7950X3D' 'AM5 -- X870E / X870 / B850 / X670E / X670 / B650 / A620' 'amd' `
        (@((BS-Pbo 'zen4_x3d'), (BS-CurveOptimizer 'All Cores, Negative 15-30' 'The only lever on the 7000X3D: less voltage lets them boost higher.' 'Der einzige Hebel bei den 7000X3D: weniger Spannung lässt sie höher boosten.'), (BS-CppcX3d)) + (BS-Am5Base 'zen4')) `
        'Important: keep the BIOS current -- early versions allowed too-high SoC voltages (burnt 7800X3D in 2023). Current BIOS versions cap the SoC voltage at 1.3 V or less.' 'Wichtig: BIOS aktuell halten -- frühe Versionen ließen zu hohe SoC-Spannungen zu (2023 durchgebrannte 7800X3D). Aktuelle BIOS begrenzen die SoC-Spannung auf höchstens 1,3 V.'),
    (New-BiosProfile 'am5_zen4' 'AMD Ryzen 7000 (Zen 4) -- AM5' 'Ryzen 7000' 'Ryzen 5 7600(X), Ryzen 7 7700(X), Ryzen 9 7900(X), 7950X' 'AM5 -- X870E / X870 / B850 / X670E / X670 / B650 / A620' 'amd' `
        (@((BS-Pbo 'zen4'), (BS-CurveOptimizer 'All Cores, Negative 10-20' 'Lowers temperature and raises boost -- the best lever on Ryzen 7000.' 'Senkt Temperatur und hebt den Boost -- bei Ryzen 7000 der beste Hebel.')) + (BS-Am5Base 'zen4'))),
    (New-BiosProfile 'am5_apu' 'AMD Ryzen 8000G / 8000F (Zen 4 APU) -- AM5' 'Ryzen 8000G / 8000F' 'Ryzen 5 8500G / 8600G, Ryzen 7 8700G, Ryzen 5 8400F, Ryzen 7 8700F' 'AM5 -- B650 / A620 / X670 / B850' 'amd' `
        @((BS-MemoryProfile 'amd' 'DDR5' 'DDR5-6000 or faster' 'If you game on the integrated graphics, fast RAM matters even more -- the iGPU has no memory of its own.' 'Spielst du über die integrierte Grafik, ist schneller RAM besonders wichtig -- die iGPU hat keinen eigenen Speicher.'),
          (BS-IgpuOff $true), (BS-Pbo 'zen4'), (BS-CurveOptimizer 'All Cores, Negative 10-20' $amCO1 $amCO1DE), (BS-Mcr), (BS-CStatesAmd), (BS-Rebar 'amd'), (BS-PcieGpu), (BS-Csm), (BS-SecureBoot),
          (BS-BiosUpdate 'New AGESA versions improve RAM support and boot times.' 'Neue AGESA-Versionen verbessern RAM-Support und Startzeiten.'), (BS-AutoInstall)) `
        'The 8000G/8000F have PCIe 4.0 and -- on 8500G/8400F -- fewer lanes; for a fast graphics card a Ryzen 7000/9000 is the better choice.' 'Die 8000G/8000F haben PCIe 4.0 und -- bei 8500G/8400F -- weniger Lanes; für eine schnelle Grafikkarte ist ein Ryzen 7000/9000 die bessere Wahl.'),
    (New-BiosProfile 'am4_zen3_x3d' 'AMD Ryzen 5000X3D (Zen 3 + 3D V-Cache) -- AM4' 'Ryzen 5000X3D' 'Ryzen 5 5600X3D, Ryzen 7 5700X3D, 5800X3D' 'AM4 -- X570 / B550 / X470 / B450 / A520' 'amd' `
        @((BS-MemoryProfile 'amd' 'DDR4' 'DDR4-3600 CL16 is the sweet spot'),
          (BS-Fclk '1800 MHz (with DDR4-3600)' '1:1 with the RAM: DDR4-3600 -> FCLK 1800, DDR4-3800 -> 1900.' '1:1 mit dem RAM: DDR4-3600 -> FCLK 1800, DDR4-3800 -> 1900.'),
          (BS-CurveOptimizer 'only if offered: All Cores, Negative 15-30' 'The 5000X3D are locked; newer BIOS versions (AGESA 1.2.0.8+) partly offer the Curve Optimizer, MSI calls it Kombo Strike (OC menu, level 1-3).' "Die 5000X3D sind gesperrt; neuere BIOS (AGESA 1.2.0.8+) bieten den Curve Optimizer teils an, MSI nennt es 'Kombo Strike' (OC-Menü, Stufe 1-3)."),
          (BS-Rebar 'amd' $am4Rebar $am4RebarDE), (BS-PcieGpu), (BS-Csm), (BS-SecureBoot),
          (BS-BiosUpdate 'For 5000X3D on older boards a BIOS update is mandatory (AGESA 1.2.0.x).' 'Fuer 5000X3D auf älteren Boards ist ein BIOS-Update Pflicht (AGESA 1.2.0.x).'), (BS-AutoInstall)) `
        'PBO and clock overclocking are locked on the 5000X3D -- EXPO/XMP and FCLK 1:1 are the most important points.' 'PBO und Takt-Übertaktung sind bei den 5000X3D gesperrt -- EXPO/XMP und FCLK 1:1 sind die wichtigsten Punkte.'),
    (New-BiosProfile 'am4_zen3' 'AMD Ryzen 5000 (Zen 3) -- AM4' 'Ryzen 5000' 'Ryzen 5 5500 / 5600(X), Ryzen 7 5700X / 5800X, Ryzen 9 5900X / 5950X' 'AM4 -- X570 / B550 / X470 / B450 / A520' 'amd' `
        @((BS-MemoryProfile 'amd' 'DDR4' 'DDR4-3600 CL16 is the sweet spot'),
          (BS-Fclk '1800 MHz (with DDR4-3600)' '1:1 with the RAM: DDR4-3600 -> FCLK 1800, DDR4-3800 -> 1900 (not every CPU manages 1900).' '1:1 mit dem RAM: DDR4-3600 -> FCLK 1800, DDR4-3800 -> 1900 (nicht jede CPU schafft 1900).'),
          (BS-Pbo 'zen3'),
          (BS-CurveOptimizer 'All Cores, Negative 10-20 (better: per core)' 'Zen 3 responds strongly to the Curve Optimizer; the two best cores usually take less.' 'Zen 3 reagiert stark auf den Curve Optimizer; die besten zwei Kerne vertragen meist weniger.'),
          (BS-Rebar 'amd' $am4Rebar $am4RebarDE), (BS-PcieGpu), (BS-Csm), (BS-SecureBoot),
          (BS-BiosUpdate 'On 400-series boards a BIOS update is mandatory for Ryzen 5000; newer AGESA versions fix USB dropouts.' 'Auf 400er-Boards ist ein BIOS-Update für Ryzen 5000 Pflicht; neuere AGESA-Versionen beheben USB-Aussetzer.'), (BS-AutoInstall))),
    (New-BiosProfile 'am4_apu' 'AMD Ryzen 5000G / 4000G / 3000G / 2000G (APU) -- AM4' 'Ryzen 5000G - 2000G (APU)' 'Ryzen 3 5300G, Ryzen 5 5600G / 4600G / 3400G / 2400G, Ryzen 7 5700G' 'AM4 -- B550 / A520 / X570 / B450 / A320' 'amd' `
        @((BS-MemoryProfile 'amd' 'DDR4' 'DDR4-3600 or faster' 'The iGPU uses system RAM as video memory -- fast RAM helps it the most.' 'Die iGPU nutzt den Arbeitsspeicher als Grafikspeicher -- schneller RAM bringt ihr am meisten.'),
          (BS-IgpuOff $true),
          (BS-Fclk '1800-2000 MHz' 'The APUs often manage FCLK 2000 (DDR4-4000 1:1).' 'Die APUs schaffen oft FCLK 2000 (DDR4-4000 1:1).'),
          (BS-Rebar 'amd' 'On the APUs only with 5000G and a current BIOS.' 'Bei den APUs nur mit 5000G und aktuellem BIOS.'), (BS-PcieGpu), (BS-Csm), (BS-SecureBoot),
          (BS-BiosUpdate 'New AGESA versions improve APU support.' 'Neue AGESA-Versionen verbessern den APU-Support.'), (BS-AutoInstall)) `
        '5600G/5700G only have PCIe 3.0 -- not ideal for a fast graphics card.' '5600G/5700G haben nur PCIe 3.0 -- für eine schnelle Grafikkarte nicht ideal.'),
    (New-BiosProfile 'am4_zen2' 'AMD Ryzen 3000 (Zen 2) -- AM4' 'Ryzen 3000' 'Ryzen 5 3600(X), Ryzen 7 3700X / 3800X, Ryzen 9 3900X / 3950X' 'AM4 -- X570 / B550 / X470 / B450' 'amd' `
        @((BS-MemoryProfile 'amd' 'DDR4' 'DDR4-3600 CL16'),
          (BS-Fclk '1800 MHz (with DDR4-3600)' 'Zen 2 almost always manages 1800 MHz 1:1, 1866-1900 only rarely.' 'Zen 2 schafft fast immer 1800 MHz 1:1, 1866-1900 nur selten.'),
          (BS-Pbo 'zen2'),
          (BS-Rebar 'amd' 'Ryzen 3000 supports it since 2021 on 400/500-series boards -- BIOS update required.' 'Ryzen 3000 unterstützt es seit 2021 auf 400er/500er-Boards -- BIOS-Update nötig.'),
          (BS-PcieGpu), (BS-Csm), (BS-SecureBoot),
          (BS-BiosUpdate 'Resizable BAR and the Windows 11 TPM need a BIOS from 2021 or newer.' 'Fuer Resizable BAR und Windows-11-TPM ist ein BIOS ab 2021 nötig.'), (BS-AutoInstall))),
    (New-BiosProfile 'am4_zen1' 'AMD Ryzen 1000 / 2000 (Zen / Zen+) -- AM4' 'Ryzen 1000 / 2000' 'Ryzen 5 1600 / 2600, Ryzen 7 1700 / 2700X' 'AM4 -- X470 / B450 / X370 / B350' 'amd' `
        @((BS-MemoryProfile 'amd' 'DDR4' 'DDR4-3200 (Zen+: often 3466)' 'Zen/Zen+ are picky with RAM -- if the profile does not work, lower the speed one step.' 'Zen/Zen+ sind beim RAM wählerisch -- klappt das Profil nicht, den Takt eine Stufe senken.'),
          (BS-PcieGpu), (BS-Csm), (BS-SecureBoot),
          (BS-BiosUpdate 'Newer BIOS versions clearly improve RAM compatibility.' 'Neuere BIOS-Versionen verbessern die RAM-Kompatibilität deutlich.'), (BS-AutoInstall)) `
        'Resizable BAR does not exist for Ryzen 1000/2000. A Ryzen 5000(X3D) usually fits the same board after a BIOS update -- the biggest jump for little money.' 'Resizable BAR gibt es für Ryzen 1000/2000 nicht. Ein Ryzen 5000(X3D) passt meist mit BIOS-Update in dasselbe Board -- der größte Sprung für wenig Geld.'),
    (New-BiosProfile 'lga1851_arl' 'Intel Core Ultra 200S (Arrow Lake) -- LGA1851' 'Core Ultra 200S' 'Core Ultra 5 245K / 225, Core Ultra 7 265K, Core Ultra 9 285K' 'LGA1851 -- Z890 / B860 / H810' 'intel' `
        @((BS-MemoryProfile 'intel' 'DDR5' 'DDR5-6400 to -8000 (CUDIMM)' 'Arrow Lake benefits a lot from fast RAM; from DDR5-8000 CUDIMM modules are worth it.' 'Arrow Lake profitiert stark von schnellem RAM; ab DDR5-8000 lohnen CUDIMM-Module.'),
          (BS-200SBoost), (BS-IntelDefault 'arl'), (BS-Rebar 'intel'), (BS-PcieGpu), (BS-Csm), (BS-SecureBoot),
          (BS-BiosUpdate 'Mandatory on Arrow Lake: the BIOS with microcode 0x114 (or newer) fixes the weak gaming performance at launch and brings 200S Boost.' "Pflicht bei Arrow Lake: das BIOS mit Microcode 0x114 (oder neuer) behebt die schwache Spieleleistung zum Start und bringt '200S Boost'." 'safe' 'high'),
          (BS-AutoInstall)) `
        'Core Ultra 200S have no Hyper-Threading. Keep Windows up to date -- the performance fixes came together with Windows updates.' 'Core Ultra 200S haben kein Hyper-Threading. Windows aktuell halten -- die Leistungs-Fixes kamen zusammen mit Windows-Updates.'),
    (New-BiosProfile 'lga1700_rpl' 'Intel Core 13th / 14th gen (Raptor Lake) -- LGA1700' 'Core 13th / 14th gen' 'Core i5-13400 - 14600K, Core i7-13700K / 14700K, Core i9-13900K / 14900K' 'LGA1700 -- Z790 / B760 / H770 / Z690 / B660' 'intel' `
        @((BS-BiosUpdate 'VERY IMPORTANT: BIOS with microcode 0x12F (or newer) -- fixes the Vmin Shift that can make 13th/14th gen CPUs (especially i7/i9) permanently unstable. Do not keep using older BIOS versions.' "SEHR WICHTIG: BIOS mit Microcode 0x12F (oder neuer) -- behebt den 'Vmin Shift', der 13./14.-Gen-CPUs (vor allem i7/i9) dauerhaft instabil machen kann. Aeltere BIOS-Versionen nicht weiter verwenden." 'safe' 'high'),
          (BS-IntelDefault 'rpl'),
          (BS-MemoryProfile 'intel' 'DDR5' 'DDR5-6000 to -7200 (DDR4 boards: DDR4-3600)'),
          (BS-ECores), (BS-Rebar 'intel'), (BS-PcieGpu), (BS-Csm), (BS-SecureBoot), (BS-AutoInstall)) `
        'Crashes in games (out of video memory, shader errors) are a typical sign of the Vmin Shift on 13th/14th gen -- first BIOS update + Intel Default Settings, then optimize further. Intel extended the warranty of these CPUs.' "Abstürze in Spielen ('Out of video memory', Shader-Fehler) sind bei 13./14. Gen ein typisches Zeichen für den Vmin-Shift -- erst BIOS-Update + Intel Default Settings, dann weiter optimieren. Intel hat die Garantie dieser CPUs verlängert."),
    (New-BiosProfile 'lga1700_adl' 'Intel Core 12th gen (Alder Lake) -- LGA1700' 'Core 12th gen' 'Core i3-12100, Core i5-12400 / 12600K, Core i7-12700K, Core i9-12900K' 'LGA1700 -- Z690 / B660 / H670 / H610 (also Z790 / B760)' 'intel' `
        @((BS-MemoryProfile 'intel' 'DDR5' 'DDR5-6000 (DDR4 boards: DDR4-3600 in Gear 1)'),
          (BS-IntelDefault 'adl'), (BS-ECores), (BS-Rebar 'intel'), (BS-PcieGpu), (BS-Csm), (BS-SecureBoot),
          (BS-BiosUpdate 'Newer BIOS versions clearly improve DDR5 support.' 'Neuere BIOS-Versionen verbessern den DDR5-Support deutlich.'), (BS-AutoInstall)) `
        'On Windows 10 the Thread Director distributes the cores worse -- Windows 11 gets noticeably more out of 12th gen.' 'Unter Windows 10 verteilt der Thread Director die Kerne schlechter -- Windows 11 holt bei 12. Gen spürbar mehr heraus.'),
    (New-BiosProfile 'lga1200' 'Intel Core 10th / 11th gen (Comet / Rocket Lake) -- LGA1200' 'Core 10th / 11th gen' 'Core i5-10400 - 11600K, Core i7-10700K / 11700K, Core i9-10900K / 11900K' 'LGA1200 -- Z590 / B560 / H570 / Z490 / B460 / H410' 'intel' `
        @((BS-MemoryProfile 'intel' 'DDR4' 'DDR4-3200 to -3600 (11th gen: Gear 1)' 'On 11th gen keep the memory controller in Gear 1 -- Gear 2 costs latency.' "Bei 11. Gen den Speicher-Controller im 'Gear 1' lassen -- Gear 2 kostet Latenz."),
          (BS-Mce),
          (BS-Rebar 'intel' 'Officially from 11th gen on 500-series boards; many Z490 boards added it for 10th gen via BIOS update.' 'Offiziell ab 11. Gen auf 500er-Boards; viele Z490-Boards haben es per BIOS-Update für 10. Gen nachgereicht.'),
          (BS-PcieGpu), (BS-Csm), (BS-SecureBoot),
          (BS-BiosUpdate 'Resizable BAR and the Windows 11 TPM need a BIOS from 2021 or newer.' 'Fuer Resizable BAR und Windows-11-TPM ist ein BIOS ab 2021 nötig.'), (BS-AutoInstall))),
    (New-BiosProfile 'lga1151' 'Intel Core 8th / 9th gen (Coffee Lake) -- LGA1151' 'Core 8th / 9th gen' 'Core i5-8400 - 9600K, Core i7-8700K / 9700K, Core i9-9900K' 'LGA1151 v2 -- Z390 / Z370 / B365 / B360 / H370' 'intel' `
        @((BS-MemoryProfile 'intel' 'DDR4' 'DDR4-3200'), (BS-Mce), (BS-PcieGpu), (BS-Csm), (BS-SecureBoot),
          (BS-BiosUpdate 'Newer BIOS versions contain security microcode and partly Resizable BAR (only some Z390 boards, unofficial).' 'Neuere BIOS-Versionen enthalten Sicherheits-Microcode und teils Resizable BAR (nur manche Z390-Boards, inoffiziell).'), (BS-AutoInstall)) `
        'Resizable BAR is only official from Intel 10th/11th gen.' 'Resizable BAR gibt es offiziell erst ab Intel 10./11. Gen.'),
    (New-BiosProfile 'generic' 'Other / unknown platform -- basics' 'Other / unknown' 'any desktop CPU' 'any board' 'any' `
        @((New-BiosSetting -Key 'memory_profile' -Cat 'Memory' -Name 'XMP / EXPO / DOCP profile' -Rec 'Profile 1' -Def 'Off -- JEDEC base clock' `
              -Path 'OC / Tweaker menu -> memory profile -> Profile 1' -Expl 'Without a profile the RAM only runs at the base clock -- the biggest free gain in the BIOS.' `
              -ExplDE 'Ohne Profil läuft der RAM nur mit dem Standardtakt -- der größte kostenlose Gewinn im BIOS.' -Risk 'safe' -Impact 'high' -Detect 'expo_xmp'),
          (BS-Rebar 'any'), (BS-PcieGpu), (BS-Csm), (BS-SecureBoot),
          (BS-BiosUpdate 'Newer BIOS versions improve RAM compatibility and security.' 'Neuere BIOS-Versionen verbessern RAM-Kompatibilität und Sicherheit.'), (BS-AutoInstall)) `
        "Laptops: most laptop BIOSes do not offer these options -- there the maker's performance mode (e.g. Turbo / Performance) in the maker's tool matters most." "Laptops: Die meisten Laptop-BIOS bieten diese Optionen nicht -- dort lohnt vor allem der Hersteller-Leistungsmodus (z. B. 'Turbo'/'Performance') im Hersteller-Tool.")
)

# -- Matching (CPU name -> profile id, board manufacturer -> vendor key) --------
function Get-BiosProfileId([string]$CpuName) {
    $c = ((($CpuName -replace '\(TM\)', ' ' -replace '\(R\)', ' ').ToUpper()) -split '\s+' | Where-Object { $_ }) -join ' '
    if ($c -notmatch 'THREADRIPPER' -and $c -match 'RYZEN\s+(?:\d\s+)?(?:PRO\s+)?(\d{4})(X3D|XT|X|GT|GE|G|F|E)?\b') {
        # mobile Ryzen ("7840HS", "5600H") never matches: no word boundary after the digits.
        # GT = the 2024 AM4 APU refresh (5600GT / 5500GT).
        $num = [int]$matches[1]; $suf = "$($matches[2])"; $series = [math]::Floor($num / 1000)
        $apu = $suf -in @('G', 'GE', 'GT')
        switch ($series) {
            9 { return $(if ($suf -eq 'X3D') { 'am5_zen5_x3d' } else { 'am5_zen5' }) }
            8 { return 'am5_apu' }
            7 { return $(if ($suf -eq 'X3D') { 'am5_zen4_x3d' } else { 'am5_zen4' }) }
            5 { if ($suf -eq 'X3D') { return 'am4_zen3_x3d' }; return $(if ($apu) { 'am4_apu' } else { 'am4_zen3' }) }
            4 { return $(if ($apu) { 'am4_apu' } else { 'generic' }) }
            3 { return $(if ($apu) { 'am4_apu' } else { 'am4_zen2' }) }
            { $_ -in 1, 2 } { return $(if ($apu) { 'am4_apu' } else { 'am4_zen1' }) }
        }
        return 'generic'
    }
    if ($c -match 'ULTRA\s+[3579]\s+(\d{3})([A-Z]{0,2})\b') {
        $num = [int]$matches[1]; $suf = "$($matches[2])"
        if ($num -ge 200 -and $num -lt 300 -and $suf -in @('', 'K', 'KF', 'F', 'T')) { return 'lga1851_arl' }
        return 'generic'                     # Core Ultra mobile (1xxH/U, 2xxV/H)
    }
    if ($c -match '\bI[3579]-(\d{4,5})([A-Z]{0,2})\b') {
        $digits = $matches[1]; $suf = "$($matches[2])"
        if ($suf -in @('H', 'HS', 'HX', 'U', 'P', 'Y', 'HK', 'G7', 'V') -or $suf.StartsWith('H')) { return 'generic' }
        $gen = if ($digits.Length -eq 5) { [int]$digits.Substring(0, 2) } else { [int]$digits.Substring(0, 1) }
        if ($gen -in 13, 14) { return 'lga1700_rpl' }
        if ($gen -eq 12) { return 'lga1700_adl' }
        if ($gen -in 10, 11) { return 'lga1200' }
        if ($gen -in 8, 9) { return 'lga1151' }
    }
    'generic'
}
function Get-BiosVendor([string]$Manufacturer) {
    $m = "$Manufacturer".ToUpper()
    if ($m -match 'ASUS') { return 'asus' }
    if ($m -match 'MICRO-STAR' -or $m.StartsWith('MSI')) { return 'msi' }
    if ($m -match 'GIGABYTE') { return 'gigabyte' }
    if ($m -match 'ASROCK') { return 'asrock' }
    'other'
}

# -- Detection: what Windows can REALLY tell about BIOS settings (read-only) ---
# expo_xmp: RAM clock vs. the JEDEC ceiling of its DDR type; rebar: NVIDIA BAR1
# aperture via nvidia-smi (256 MB = off, whole VRAM = on); secure_boot: the state
# Windows records; csm: legacy boot = on, UEFI + Secure Boot = off. Everything
# else stays "not detectable" (grey) instead of a guess.
function Get-BiosDetection {
    $r = @{}
    try {
        $m = Get-CimInstance Win32_PhysicalMemory -ErrorAction Stop | Sort-Object ConfiguredClockSpeed -Descending | Select-Object -First 1
        $speed = [int]$m.ConfiguredClockSpeed; $mtype = [int]$m.SMBIOSMemoryType
        $ddr = if ($mtype -eq 34) { 'DDR5' } elseif ($mtype -eq 26) { 'DDR4' } elseif ($mtype -eq 24) { 'DDR3' } elseif ($speed -gt 4000) { 'DDR5' } else { 'DDR4' }
        # Some older SMBIOS tables give the clock (MHz) instead of the data rate (MT/s),
        # e.g. 1600 for DDR4-3200. Below the lowest real rate of the type it can only be that.
        if ($speed -gt 0 -and (($ddr -eq 'DDR5' -and $speed -lt 3200) -or ($ddr -eq 'DDR4' -and $speed -le 1600) -or ($ddr -eq 'DDR3' -and $speed -le 800))) { $speed *= 2 }
        # JEDEC rates = no profile, up to the highest one desktop CPUs run without EXPO/XMP.
        # Above that, or at a rate JEDEC doesn't define (DDR4-3000, -2800 ...), only a
        # profile sets the RAM there. AT the top rate (DDR4-3200, DDR5-5600) both are
        # possible -- that stays "not detectable" instead of a guess. +-2: boards report
        # 2667 for 2666 and the like.
        $jedec = @{ DDR3 = @(800, 1066, 1333, 1600); DDR4 = @(1600, 1866, 2133, 2400, 2666, 2933, 3200); DDR5 = @(3200, 3600, 4000, 4400, 4800, 5200, 5600) }[$ddr]
        $top = $jedec[-1]
        $isJedec = @($jedec | Where-Object { [math]::Abs($_ - $speed) -le 2 }).Count -gt 0
        if ($speed -gt $top + 2) { $r['expo_xmp'] = @{ Active = $true; Note = "RAM runs at $ddr-$speed -- above the JEDEC base clock, the profile is active" } }
        elseif ($speed -gt 0 -and -not $isJedec) { $r['expo_xmp'] = @{ Active = $true; Note = "RAM runs at $ddr-$speed -- not a JEDEC base clock, so the profile is active" } }
        elseif ($speed -gt 0 -and $speed -lt $top - 2) { $r['expo_xmp'] = @{ Active = $false; Note = "RAM only runs at $ddr-$speed (base clock) -- enable the profile in the BIOS" } }
    } catch { }
    $fw = "$env:firmware_type".ToLower()
    $sb = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State' -Name UEFISecureBootEnabled -ErrorAction SilentlyContinue).UEFISecureBootEnabled
    if ($null -ne $sb) { $r['secure_boot'] = @{ Active = ("$sb" -eq '1'); Note = $(if ("$sb" -eq '1') { 'Secure Boot is on' } else { 'Secure Boot is off' }) } }
    elseif ($fw -eq 'legacy') { $r['secure_boot'] = @{ Active = $false; Note = 'Windows boots in legacy mode -- Secure Boot needs UEFI' } }
    if ($fw -eq 'legacy') { $r['csm'] = @{ Active = $false; Note = 'Windows is installed in legacy mode -- only turn CSM off after converting Windows to UEFI (MBR2GPT)' } }
    elseif ($fw -eq 'uefi' -and "$sb" -eq '1') { $r['csm'] = @{ Active = $true; Note = 'UEFI boot with Secure Boot -- CSM is definitely off' } }
    if ($IsNVIDIA) {
        try {
            $smi = Get-Command nvidia-smi.exe -ErrorAction Stop
            $q = @(& $smi.Source -q -d MEMORY 2>$null)
            $bar1 = $null; $fb = $null; $sect = ''
            foreach ($line in $q) {
                if ($line -match '^\s*BAR1 Memory Usage') { $sect = 'bar1'; continue }
                if ($line -match '^\s*FB Memory Usage') { $sect = 'fb'; continue }
                if ($line -match '^\s*Total\s*:\s*(\d+)\s*MiB') { if ($sect -eq 'bar1' -and $null -eq $bar1) { $bar1 = [int]$matches[1] } elseif ($sect -eq 'fb' -and $null -eq $fb) { $fb = [int]$matches[1] } }
            }
            if ($bar1) {
                if ($bar1 -gt 512) { $r['rebar'] = @{ Active = $true; Note = "Resizable BAR is on -- the CPU sees $([math]::Round($bar1 / 1024)) GB of video memory at once" } }
                else { $r['rebar'] = @{ Active = $false; Note = "Resizable BAR is off -- only a $bar1 MB window$(if ($fb) { " (video memory $([math]::Round($fb / 1024)) GB)" })" } }
            }
        } catch { }
    }
    $r
}

# -- BIOS page UI -----------------------------------------------------------------
$Script:BiosCats = @(
    @{ Key = 'Memory'; Label = 'Memory'; Color = $Script:UI.VIOLET }, @{ Key = 'CPU'; Label = 'CPU'; Color = $Script:UI.ACC },
    @{ Key = 'GPU'; Label = 'GPU'; Color = $Script:UI.GREEN }, @{ Key = 'Power'; Label = 'Power'; Color = $Script:UI.AMBER },
    @{ Key = 'Boot'; Label = 'Boot & security'; Color = $Script:UI.SLATE })
$boardInfo = try { Get-WmiObject Win32_BaseBoard -ErrorAction Stop | Select-Object -First 1 } catch { $null }
$Script:Bios = @{
    Detected       = Get-BiosProfileId $CPU
    DetectedVendor = Get-BiosVendor "$($boardInfo.Manufacturer)"
    Board          = "$(("$($boardInfo.Manufacturer)" -replace ' Technology Co\., Ltd\.| Co\., Ltd\.| Corporation| Computer INC\.', '')) $($boardInfo.Product)".Trim()
    Results        = @{}
    Filters        = @{ Memory = $true; CPU = $true; GPU = $true; Power = $true; Boot = $true }
    OnlyTodo       = $false
    Items          = @{}
    VendorBtns     = @{}
}
$Script:Bios.Profile = $Script:Bios.Detected
$Script:Bios.Vendor  = $Script:Bios.DetectedVendor
$Script:BiosDetectDone = $false

function Get-BiosProfile([string]$Id) { $Script:BiosProfiles | Where-Object { $_.Id -eq $Id } | Select-Object -First 1 }

function Build-BiosPlatformList {
    $BiosPlatformList.Children.Clear()
    $groups = [ordered]@{ 'AMD AM5' = 'am5_'; 'AMD AM4' = 'am4_'; 'Intel' = 'lga'; 'Other' = 'generic' }
    $first = $true
    foreach ($g in $groups.Keys) {
        $hdr = New-Text $g.ToUpper() 10.5 $Script:UI.MUTED 'SemiBold' -Margin 10, $(if ($first) { 2 } else { 12 }), 0, 4
        $first = $false
        $BiosPlatformList.Children.Add($hdr) | Out-Null
        foreach ($p in ($Script:BiosProfiles | Where-Object { $_.Id.StartsWith($groups[$g]) })) {
            $pid2 = $p.Id
            $txt = New-Text $p.Short 12.5 $Script:UI.TEXT2
            $content = New-HStack @($txt)
            if ($pid2 -eq $Script:Bios.Detected) { $content.Children.Add((New-Badge 'yours' $Script:UI.GREEN (Mix-Hex $Script:UI.CARD $Script:UI.GREEN 0.16))) | Out-Null; $content.Children[1].Margin = Th 8, 0, 0, 0; $content.Children[1].VerticalAlignment = 'Center' }
            $btn = New-Object Windows.Controls.Button
            $btn.Style = $Window.FindResource("NavBtn"); $btn.Height = 32; $btn.Content = $content; $btn.ToolTip = "$($p.Name)`n$($p.Cpus)"
            $btn.Add_Click({ Select-BiosProfile $pid2 }.GetNewClosure())
            $BiosPlatformList.Children.Add($btn) | Out-Null
            $Script:Bios.Items[$pid2] = @{ Btn = $btn; Txt = $txt }
        }
    }
}
function Select-BiosProfile([string]$Id) { $Script:Bios.Profile = $Id; Update-BiosPlatformList; Render-BiosPage }
function Select-BiosVendor([string]$Key) { $Script:Bios.Vendor = $Key; Render-BiosPage }
function Update-BiosPlatformList {
    foreach ($id in $Script:Bios.Items.Keys) {
        $it = $Script:Bios.Items[$id]; $on = ($id -eq $Script:Bios.Profile)
        $it.Btn.Background = if ($on) { Brush (Mix-Hex $Script:UI.CARD $Script:UI.AMBER 0.18) } else { [Windows.Media.Brushes]::Transparent }
        $it.Txt.Foreground = Brush $(if ($on) { '#ffffff' } else { $Script:UI.TEXT2 })
        $it.Txt.FontWeight = $(if ($on) { 'SemiBold' } else { 'Normal' })
    }
}
function Test-BiosDone($Setting) {
    if ($Script:Bios.Profile -ne $Script:Bios.Detected -or -not $Setting.Detect) { return $false }
    $r = $Script:Bios.Results[$Setting.Detect]
    [bool]($r -and $r.Active)
}
function New-ToggleChip([string]$Label, [string]$Color, [bool]$On, [scriptblock]$OnClick) {
    $b = New-Object Windows.Controls.Button
    $b.Style = $Script:TabStyle; $b.Margin = Th 0, 0, 6, 0
    $dot = New-Object Windows.Shapes.Ellipse; $dot.Width = 7; $dot.Height = 7; $dot.Margin = Th 0, 0, 6, 0; $dot.VerticalAlignment = 'Center'
    if ($On) { $dot.Fill = Brush $Color } else { $dot.Stroke = Brush $Script:UI.MUTED; $dot.StrokeThickness = 1.3 }
    $b.Content = New-HStack @($dot, (New-Text $Label 12 $(if ($On) { $Script:UI.TEXT } else { $Script:UI.DIM })))
    $b.Background = if ($On) { Brush (Mix-Hex $Script:UI.CARD $Color 0.16) } else { Brush $Script:UI.CARD2 }
    $b.Add_Click($OnClick)
    $b
}
function Get-BiosText($Setting) { if ($LangState.Current -eq 'DE' -and $Setting.ExplDE) { $Setting.ExplDE } else { $Setting.Expl } }

function Render-BiosPage {
    $U = $Script:UI; $B = $Script:Bios
    $p = Get-BiosProfile $B.Profile
    $isMine = ($p.Id -eq $B.Detected)
    $BiosPanel.Children.Clear()

    # ---- selection card ----
    $top = New-VStack @()
    $top.Children.Add((New-Text "CPU: $CPU$($Script:Mid)Board: $($B.Board)$($Script:Mid)GPU: $GPU" 11.5 $U.ACC 'Normal' -Wrap -Margin 0, 0, 0, 12)) | Out-Null
    $top.Children.Add((New-Text 'Board maker (for the menu paths)' 12.5 $U.TEXT2 'SemiBold' -Margin 0, 0, 0, 6)) | Out-Null
    $vend = New-Object Windows.Controls.Border; $vend.CornerRadius = New-Object Windows.CornerRadius(9); $vend.Background = Brush $U.CARD2; $vend.Padding = Th 3; $vend.HorizontalAlignment = 'Left'
    $vs = New-HStack @()
    foreach ($k in $Script:BiosVendors.Keys) {
        $key = $k; $on = ($k -eq $B.Vendor)
        $label = $Script:BiosVendors[$k] + $(if ($k -eq $B.DetectedVendor -and $k -ne 'other') { '  (yours)' } else { '' })
        $vb = New-Object Windows.Controls.Button; $vb.Style = $Script:TabStyle
        $vb.Content = New-Text $label 12.5 $(if ($on) { '#ffffff' } else { $U.TEXT2 }) $(if ($on) { 'SemiBold' } else { 'Normal' })
        $vb.Background = if ($on) { Brush $U.AMBER } else { [Windows.Media.Brushes]::Transparent }
        if ($on) { $vb.Content.Foreground = Brush '#1a1205' }
        $vb.Add_Click({ Select-BiosVendor $key }.GetNewClosure())
        $vs.Children.Add($vb) | Out-Null
    }
    $vend.Child = $vs; $top.Children.Add($vend) | Out-Null
    $top.Children.Add((New-Text "$($p.Name)$($Script:Mid)$($p.Cpus)$($Script:Mid)$($p.Platform)" 12.5 $U.TEXT2 'Normal' -Wrap -Margin 0, 12, 0, 0)) | Out-Null
    if (-not $isMine) { $top.Children.Add((New-Text 'Not your detected platform -- shown for reference; the live status only applies to your own platform.' 12 $U.AMBER 'Normal' -Wrap -Margin 0, 4, 0, 0)) | Out-Null }

    $filt = New-HStack @() @(0, 12, 0, 0)
    $filt.Children.Add((New-Text 'Show:' 12 $U.DIM 'Normal' -Margin 0, 0, 8, 0)) | Out-Null
    foreach ($c in $Script:BiosCats) {
        $ck = $c.Key
        $filt.Children.Add((New-ToggleChip $c.Label $c.Color $B.Filters[$ck] { $B.Filters[$ck] = -not $B.Filters[$ck]; Render-BiosPage }.GetNewClosure())) | Out-Null
    }
    $sep = New-Object Windows.Controls.Border; $sep.Width = 1; $sep.Height = 18; $sep.Background = Brush $U.BORDER; $sep.Margin = Th 4, 0, 10, 0
    $filt.Children.Add($sep) | Out-Null
    $filt.Children.Add((New-ToggleChip "Only what's left to do" $U.ERR $B.OnlyTodo { $Script:Bios.OnlyTodo = -not $Script:Bios.OnlyTodo; Render-BiosPage })) | Out-Null
    $top.Children.Add($filt) | Out-Null

    $leg = New-HStack @() @(0, 12, 0, 0)
    foreach ($l in @(@($U.GREEN, 'already set'), @($U.ERR, 'still to set'), @('#6b7280', 'not detectable from Windows'))) {
        $e = New-Object Windows.Shapes.Ellipse; $e.Width = 7; $e.Height = 7; $e.Fill = Brush $l[0]; $e.Margin = Th 0, 0, 5, 0; $e.VerticalAlignment = 'Center'
        $leg.Children.Add($e) | Out-Null; $leg.Children.Add((New-Text $l[1] 11.5 $l[0] 'Normal' -Margin 0, 0, 14, 0)) | Out-Null
    }
    $top.Children.Add($leg) | Out-Null
    $top.Children.Add((New-Text 'Menu names differ between BIOS versions -- the BIOS search (ASUS: F9, MSI: Ctrl+F, Gigabyte: Ctrl+F in Advanced Mode) finds a setting by its name.' 11.5 $U.DIM 'Normal' -Wrap -Margin 0, 8, 0, 0)) | Out-Null
    $BiosPanel.Children.Add((New-Card $top)) | Out-Null

    $notes = if ($LangState.Current -eq 'DE' -and $p.NotesDE) { $p.NotesDE } else { $p.Notes }
    if ($notes) { $BiosPanel.Children.Add((New-Banner $notes $U.AMBER 0xE946)) | Out-Null }

    # ---- detection summary in the header ----
    if ($isMine -and $Script:BiosDetectDone) {
        $keys = @($p.Settings | Where-Object { $_.Detect } | ForEach-Object { $_.Detect } | Select-Object -Unique)
        $found = @($keys | Where-Object { $B.Results.ContainsKey($_) })
        $ok = @($found | Where-Object { $B.Results[$_].Active }).Count
        $BiosDetectStatus.Text = if ($found.Count) { "$ok/$($found.Count) detectable settings already set" } else { '' }
        $BiosDetectStatus.Foreground = Brush $(if ($found.Count -and $ok -eq $found.Count) { $U.GREEN } else { $U.AMBER })
    } elseif (-not $isMine) { $BiosDetectStatus.Text = '' }

    # ---- setting cards per category ----
    $shown = 0
    foreach ($c in $Script:BiosCats) {
        if (-not $B.Filters[$c.Key]) { continue }
        $list = @($p.Settings | Where-Object { $_.Cat -eq $c.Key })
        if ($B.OnlyTodo) { $list = @($list | Where-Object { -not (Test-BiosDone $_) }) }
        if (-not $list.Count) { continue }
        $BiosPanel.Children.Add((New-SectionTitle $c.Label $c.Color '' $(if ($shown) { @(0, 8, 0, 10) } else { @(0, 2, 0, 10) }))) | Out-Null
        $grid = New-Grid2
        foreach ($s in $list) { Add-Grid2 $grid (New-BiosCard $s $c.Color $isMine); $shown++ }
        $BiosPanel.Children.Add($grid) | Out-Null
    }
    if (-not $shown) {
        $msg = if ($B.OnlyTodo) { 'All detectable settings are already set!' } else { 'No settings in the chosen areas.' }
        $BiosPanel.Children.Add((New-Text $msg 13 $(if ($B.OnlyTodo) { $U.GREEN } else { $U.DIM }) 'SemiBold' -Margin 4, 20, 0, 0)) | Out-Null
    }
}
function New-BiosCard($S, [string]$Color, [bool]$IsMine) {
    $U = $Script:UI
    $det = if ($S.Detect -and $IsMine) { $Script:Bios.Results[$S.Detect] } else { $null }
    if ($null -eq $det) {
        $stCol = '#6b7280'
        $stTip = if ($IsMine -or -not $S.Detect) { 'Not detectable from Windows -- check in the BIOS' } else { 'Status only for your detected platform' }
    } elseif ($det.Active) { $stCol = $U.GREEN; $stTip = $det.Note } else { $stCol = $U.ERR; $stTip = $det.Note }

    $v = New-VStack @()
    $head = New-Object Windows.Controls.Grid
    $c0 = New-Object Windows.Controls.ColumnDefinition; $c0.Width = [Windows.GridLength]::Auto; $head.ColumnDefinitions.Add($c0)
    $c1 = New-Object Windows.Controls.ColumnDefinition; $c1.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star); $head.ColumnDefinitions.Add($c1)
    $c2 = New-Object Windows.Controls.ColumnDefinition; $c2.Width = [Windows.GridLength]::Auto; $head.ColumnDefinitions.Add($c2)
    $dot = New-Object Windows.Shapes.Ellipse; $dot.Width = 9; $dot.Height = 9; $dot.Fill = Brush $stCol; $dot.Margin = Th 0, 5, 10, 0; $dot.VerticalAlignment = 'Top'
    $head.Children.Add($dot) | Out-Null
    $nm = New-VStack @((New-Text $S.Name 13.5 $U.TEXT 'SemiBold' -Wrap), (New-Text $stTip 11 $stCol 'Normal' -Wrap -Margin 0, 2, 0, 0))
    [Windows.Controls.Grid]::SetColumn($nm, 1); $head.Children.Add($nm) | Out-Null
    $impCol = @{ high = '#ef4444'; medium = '#f59e0b'; low = '#22c55e' }[$S.Impact]
    $riskCol = @{ safe = '#22c55e'; moderate = '#f59e0b'; advanced = '#ef4444' }[$S.Risk]
    $bd = New-VStack @((New-Badge "$($S.Impact) impact" $impCol (Mix-Hex $U.CARD $impCol 0.15)), (New-Badge $S.Risk $riskCol (Mix-Hex $U.CARD $riskCol 0.15))) @(10, 0, 0, 0)
    [Windows.Controls.Grid]::SetColumn($bd, 2); $head.Children.Add($bd) | Out-Null
    $v.Children.Add($head) | Out-Null

    $val = New-Object Windows.Controls.Border; $val.Background = Brush $U.CARD2; $val.CornerRadius = New-Object Windows.CornerRadius(6); $val.Padding = Th 10, 6, 10, 7; $val.Margin = Th 0, 10, 0, 8
    $val.Child = New-VStack @((New-Text "Default: $($S.Def)" 11.5 $U.DIM 'Normal' -Wrap), (New-Text "Recommended: $($S.Rec)" 12.5 $Color 'SemiBold' -Wrap -Margin 0, 2, 0, 0))
    $v.Children.Add($val) | Out-Null

    $vk = $Script:Bios.Vendor
    $path = if ($S.Paths.ContainsKey($vk)) { $S.Paths[$vk] } else { $S.Path }
    $who = if ($S.Paths.ContainsKey($vk)) { $Script:BiosVendors[$vk] } elseif ($LangState.Current -eq 'DE') { 'Alle Boards' } else { 'All boards' }
    $pl = New-Object Windows.Controls.DockPanel; $pl.Margin = Th 0, 0, 0, 6
    $pin = New-Icon 0xE707 12 $U.VIOLET @(0, 1, 6, 0); $pin.VerticalAlignment = 'Top'
    [Windows.Controls.DockPanel]::SetDock($pin, 'Left'); $pl.Children.Add($pin) | Out-Null
    $pl.Children.Add((New-Text "${who}: $path" 11.5 $U.VIOLET 'Normal' -Wrap)) | Out-Null
    $v.Children.Add($pl) | Out-Null
    $v.Children.Add((New-Text (Get-BiosText $S) 12 $U.TEXT2 'Normal' -Wrap)) | Out-Null

    $card = New-Card $v @(0, 0, 0, 0) @(14, 12, 14, 12)
    $card.VerticalAlignment = 'Stretch'
    $card
}
function Invoke-BiosDetect {
    $BtnBiosDetect.IsEnabled = $false
    $BiosDetectStatus.Text = 'Reading system state ...'; $BiosDetectStatus.Foreground = Brush $Script:UI.DIM
    $Window.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::Render)
    try { $Script:Bios.Results = Get-BiosDetection } catch { $Script:Bios.Results = @{} }
    $Script:BiosDetectDone = $true
    $BtnBiosDetect.IsEnabled = $true
    Render-BiosPage
}
$BtnBiosDetect.Add_Click({ Invoke-BiosDetect })

# =============================================================================
# DASHBOARD PAGE  --  hardware, optimization score, live monitor, ping test,
# snapshot / compare, safety net. Score + counters come from the status table
# the tweak rows already filled (no second round of checks at startup).
# =============================================================================
$Script:Dash = @{}
$Script:PingState = @{ Ps = $null; Rs = $null }    # shared by the ping closures and the close handler

function Open-BackupFolder {
    if (Test-Path $Script:RegistryBackupRoot) { Start-Process explorer.exe $Script:RegistryBackupRoot }
    else { [System.Windows.MessageBox]::Show("No registry backups yet. Apply or revert some tweaks first.", "Backups", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null }
}
function Open-LogFile {
    if (Test-Path $LogFile) { Start-Process notepad.exe $LogFile }
    else { [System.Windows.MessageBox]::Show("No log file yet. Apply some tweaks first.", "Log", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null }
}
function Get-BackupSummary {
    $dirs = @(Get-ChildItem $Script:RegistryBackupRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending)
    if (-not $dirs) { return @{ Count = 0; Last = 'none yet' } }
    $last = $dirs[0].Name -replace '^(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})\d{2}_(?:v1-)?(.+)$', '$3.$2.$1 $4:$5 ($6)'
    @{ Count = $dirs.Count; Last = $last }
}
function Get-BaselineSummary {
    if (Test-Path $Script:BaselineFile) {
        $n = @((Read-Baseline).Names).Count
        "$n tweaks applied$($Script:Mid)saved $((Get-Item $Script:BaselineFile).LastWriteTime.ToString('dd.MM.yyyy HH:mm'))"
    } else { 'created after the first Apply' }
}

# Memory integrity (HVCI), virtualization-based security and drive encryption of C: -- read
# only, never switched by the tool. Win32_DeviceGuard is readable without admin:
# SecurityServicesRunning contains 2 = HVCI; VirtualizationBasedSecurityStatus 0 off,
# 1 enabled but not running, 2 running. The shell's BitLocker property needs no admin
# either: 1 on, 2 off, 3 encrypting, 4 decrypting, 5 suspended, 6 on (locked).
# Newer release on GitHub? Asked once per start on a background thread -- the window never
# waits, and a missing connection only means no notice. Nothing is sent but the request.
function Start-UpdateCheck {
    $st = @{ Ps = $null; Rs = $null; Handle = $null; Ticks = 0 }
    try {
        $st.Rs = [runspacefactory]::CreateRunspace(); $st.Rs.ApartmentState = 'MTA'; $st.Rs.Open()
        $st.Ps = [powershell]::Create(); $st.Ps.Runspace = $st.Rs
        [void]$st.Ps.AddScript({
            try {
                [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
                $r = Invoke-RestMethod -Uri 'https://api.github.com/repos/FloDePin/GameOptimizerPro/releases/latest' -Headers @{ 'User-Agent' = 'GameOptimizerPro' } -TimeoutSec 8 -UseBasicParsing
                "$($r.tag_name)"
            } catch { '' }
        })
        $st.Handle = $st.Ps.BeginInvoke()
    } catch { return }
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(500)
    $timer.Add_Tick({
        $st.Ticks++
        if (-not $st.Handle.IsCompleted -and $st.Ticks -lt 40) { return }
        $timer.Stop()
        $tag = ''
        try { if ($st.Handle.IsCompleted) { $tag = "$(@($st.Ps.EndInvoke($st.Handle))[0])" } } catch { }
        try { $st.Ps.Dispose(); $st.Rs.Close(); $st.Rs.Dispose() } catch { }
        Show-UpdateNotice $tag
    }.GetNewClosure())
    $timer.Start()
}
function Show-UpdateNotice([string]$Tag) {
    $new = $null; $have = $null
    if (-not ([version]::TryParse(($Tag -replace '^v', ''), [ref]$new) -and [version]::TryParse($Script:AppVersion, [ref]$have) -and $new -gt $have)) { return }
    $Script:Dash.UpdateText.Text = "GameOptimizerPro $Tag is available $($Script:EmDash.Trim()) you have v$($Script:AppVersion). Run the install command again to update."
    $Script:Dash.UpdateCard.Visibility = 'Visible'
    Write-Log "Update check: $Tag is available (this is v$($Script:AppVersion))"
}

function Get-SecurityStatus {
    $dg = try { Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard -ErrorAction Stop } catch { $null }
    $hv = if ($dg) { @($dg.SecurityServicesRunning) } else { $null }
    $mi = if ($null -eq $hv) {
        @{ Value = 'not readable'; Warn = $false; Hint = 'Windows Security > Device security > Core isolation shows it.' }
    } elseif ($hv -contains 2) {
        @{ Value = 'on'; Warn = $true; Hint = 'Protects against malicious drivers; in some games it costs a few percent. Switch it in Windows Security > Device security > Core isolation -- your call.' }
    } else {
        @{ Value = 'off'; Warn = $false; Hint = 'Windows updates (KB5127936 and later) can switch it on -- worth a look after big updates.' }
    }
    $bl = try { [int](New-Object -ComObject Shell.Application).NameSpace('C:').Self.ExtendedProperty('System.Volume.BitLockerProtection') } catch { -1 }
    $hint = 'Software encryption costs SSD speed on some drives. Keep the recovery key (account.microsoft.com/devices/recoverykey). Settings > Privacy & security > Device encryption.'
    $dr = switch ($bl) {
        { $_ -in 1, 6 } { @{ Value = 'encrypted (BitLocker / device encryption)'; Warn = $true; Hint = $hint } }
        3 { @{ Value = 'encrypting right now'; Warn = $true; Hint = $hint } }
        4 { @{ Value = 'decrypting right now'; Warn = $false; Hint = 'Leave the PC on until it is done.' } }
        5 { @{ Value = 'encrypted, protection paused'; Warn = $true; Hint = $hint } }
        2 { @{ Value = 'not encrypted'; Warn = $false; Hint = 'Since 24H2 a clean install often encrypts the drive by itself -- this one is not.' } }
        default { @{ Value = 'unknown'; Warn = $false; Hint = 'Settings > Privacy & security > Device encryption shows it.' } }
    }
    # VBS can keep running with memory integrity off (Credential Guard, System Guard, a policy)
    $vs = switch ($(if ($dg) { [int]$dg.VirtualizationBasedSecurityStatus } else { -1 })) {
        2 { if ($hv -contains 2) { @{ Value = 'running (with memory integrity)'; Warn = $true; Hint = 'Comes with memory integrity -- see above.' } }
            else { @{ Value = 'running, although memory integrity is off'; Warn = $true; Hint = 'Something else keeps the Windows hypervisor on (Credential Guard, System Guard, a policy); in CPU-heavy games that can still cost a little. System Information (msinfo32) lists what runs.' } } }
        1 { @{ Value = 'enabled, not running'; Warn = $false; Hint = 'Switched on but not active -- usually CPU virtualization (SVM / VT-x) is off in the BIOS.' } }
        0 { @{ Value = 'off'; Warn = $false; Hint = 'The Windows hypervisor security layer is not running.' } }
        default { @{ Value = 'not readable'; Warn = $false; Hint = 'System Information (msinfo32) shows it under "Virtualization-based security".' } }
    }
    @(([pscustomobject]@{ Label = 'Memory integrity'; Value = $mi.Value; Warn = $mi.Warn; Hint = $mi.Hint }),
      ([pscustomobject]@{ Label = 'VBS'; Value = $vs.Value; Warn = $vs.Warn; Hint = $vs.Hint }),
      ([pscustomobject]@{ Label = 'Drive C:'; Value = $dr.Value; Warn = $dr.Warn; Hint = $dr.Hint }))
}

function New-HwCard([int]$Glyph, [string]$Color, [string]$Label, [string]$Value, [string]$Sub) {
    $v = New-VStack @((New-HStack @((New-Icon $Glyph 14 $Color @(0, 0, 8, 0)), (New-Text $Label 11.5 $Script:UI.DIM)) @(0, 0, 0, 8)),
                      (New-Text $Value 14 $Script:UI.TEXT 'SemiBold' -Wrap), (New-Text $Sub 11.5 $Script:UI.DIM 'Normal' -Wrap -Margin 0, 4, 0, 0))
    New-Card $v @(0, 0, 12, 14) @(16, 14, 16, 14)
}
function New-LiveRow([string]$Label, [string]$Color) {
    $g = New-Object Windows.Controls.Grid; $g.Margin = Th 0, 6, 0, 0
    foreach ($w in 70, -1, 120) { $cd = New-Object Windows.Controls.ColumnDefinition; $cd.Width = if ($w -lt 0) { New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star) } else { New-Object Windows.GridLength($w) }; $g.ColumnDefinitions.Add($cd) }
    $g.Children.Add((New-Text $Label 12.5 $Script:UI.TEXT2)) | Out-Null
    $bar = New-Bar 0 $Color 7; $bar.VerticalAlignment = 'Center'; [Windows.Controls.Grid]::SetColumn($bar, 1); $g.Children.Add($bar) | Out-Null
    $val = New-Text '--' 12.5 $Color 'Normal' -Mono; $val.HorizontalAlignment = 'Right'; [Windows.Controls.Grid]::SetColumn($val, 2); $g.Children.Add($val) | Out-Null
    @{ Root = $g; Bar = $bar; Val = $val }
}

function Build-DashboardPage {
    $U = $Script:UI; $D = $Script:Dash
    $DashboardPanel.Children.Clear()
    $DashboardPanel.Children.Add((New-PageHeader 'Dashboard' 'System overview, optimization score and live values' $U.RED)) | Out-Null

    # ---- hardware cards ----
    $cpuO = $Script:CpuObj                                   # read once at startup
    $gpuO = $Script:GpuObj                                   # the gaming GPU, not the iGPU (Select-PrimaryGpu)
    $memO = @(Get-WmiObject Win32_PhysicalMemory -ErrorAction SilentlyContinue)
    $vram = 0
    try { $vram = [math]::Round([int64]$gpuO.VramBytes / 1GB) } catch { }
    $ddr = switch ([int]($memO | Select-Object -First 1).SMBIOSMemoryType) { 34 { 'DDR5' } 26 { 'DDR4' } 24 { 'DDR3' } default { '' } }
    $hw = New-Object Windows.Controls.Grid; $hw.Margin = Th 0, 0, -12, 0
    foreach ($i in 0..3) { $cd = New-Object Windows.Controls.ColumnDefinition; $cd.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star); $hw.ColumnDefinitions.Add($cd) }
    $cards = @(
        (New-HwCard 0xEEA1 $U.RED 'CPU' $CPU "$($cpuO.NumberOfCores) cores / $($cpuO.NumberOfLogicalProcessors) threads$($Script:Mid)$($cpuO.MaxClockSpeed) MHz"),
        (New-HwCard 0xE7F4 $(if ($IsAMD) { $U.RED } elseif ($IsNVIDIA) { $U.NV } else { $U.WIN }) 'GPU' $GPU "$(if ($vram) { "$vram GB VRAM$($Script:Mid)" })driver $($gpuO.DriverVersion)"),
        (New-HwCard 0xE950 $U.VIOLET 'RAM' "$RAM GB $ddr".Trim() "$($memO.Count) module(s)$($Script:Mid)$(($memO | Select-Object -First 1).ConfiguredClockSpeed) MHz"),
        (New-HwCard 0xEDA2 $U.AMBER 'Board / OS' $Script:Bios.Board "$OSShort$($Script:Mid)$NVMeInfo")
    )
    for ($i = 0; $i -lt 4; $i++) { [Windows.Controls.Grid]::SetColumn($cards[$i], $i); $hw.Children.Add($cards[$i]) | Out-Null }
    $DashboardPanel.Children.Add($hw) | Out-Null

    # ---- newer version available (hidden until the background check finds one) ----
    $D.UpdateText = New-Text '' 12.5 $U.TEXT 'SemiBold' -Wrap
    $upBtn = New-Btn 'Open release page' $U.CARD2 $U.TEXT 0xE8A7 -Margin 12, 0, 0, 0
    $upBtn.Add_Click({ try { Start-Process 'https://github.com/FloDePin/GameOptimizerPro/releases/latest' } catch { } })
    $upRow = New-Object Windows.Controls.DockPanel
    [Windows.Controls.DockPanel]::SetDock($upBtn, 'Right'); $upRow.Children.Add($upBtn) | Out-Null
    $upRow.Children.Add((New-HStack @((New-Icon 0xE896 15 $U.GREEN @(0, 0, 10, 0)), $D.UpdateText))) | Out-Null
    $D.UpdateCard = New-Card $upRow @(0, 0, 0, 14)
    $D.UpdateCard.Visibility = 'Collapsed'
    $DashboardPanel.Children.Add($D.UpdateCard) | Out-Null
    Start-UpdateCheck

    # ---- optimization score ----
    $verifyBtn = New-Btn 'Verify again' $U.CARD2 $U.TEXT 0xE72C -Margin 0, 0, 0, 0
    $verifyBtn.Add_Click({ Invoke-Verify })
    $D.ScorePct  = New-Text '-- %' 30 $U.GREEN 'Bold' -Mono
    $D.ScoreLine = New-Text '' 13 $U.TEXT 'SemiBold'
    $D.ScoreSub  = New-Text '' 11.5 $U.DIM
    $D.ScoreBar  = New-Bar 0 $U.GREEN 8
    $mon = New-VStack @() @(0, 12, 0, 0)
    $mi = 1
    foreach ($m in @($Script:VideoCtrls | Where-Object { $_.CurrentRefreshRate })) {
        # WMI reports fractional modes rounded down (143.98 Hz -> 143, max 144)
        $atMax = ([int]$m.CurrentRefreshRate + 1) -ge [int]$m.MaxRefreshRate
        $adv = if ($atMax) { "  $($Script:EmDash.Trim()) maximum, nothing to do" } else { "  $($Script:EmDash.Trim()) can do $($m.MaxRefreshRate) Hz! Set it in Windows: Display settings > Advanced display > Refresh rate" }
        $mon.Children.Add((New-HStack @((New-Icon 0xE7F4 13 $U.CYAN @(0, 0, 10, 0)), (New-Text "Monitor $mi$(if ($mi -eq 1) { ' (primary)' })" 12.5 $U.TEXT 'SemiBold'),
            (New-Text "   $($m.CurrentHorizontalResolution) x $($m.CurrentVerticalResolution) @ $($m.CurrentRefreshRate) Hz" 12.5 $U.TEXT2),
            (New-Text $adv 12.5 $(if ($atMax) { $U.DIM } else { $U.AMBER }))) @(0, 3, 0, 0))) | Out-Null
        $mi++
    }
    # Two Windows security features that cost performance -- shown only, never switched here
    foreach ($s in @(Get-SecurityStatus)) {
        $mon.Children.Add((New-HStack @((New-Icon 0xE72E 13 $U.SLATE @(0, 0, 10, 0)), (New-Text $s.Label 12.5 $U.TEXT 'SemiBold'),
            (New-Text "   $($s.Value)" 12.5 $(if ($s.Warn) { $U.AMBER } else { $U.TEXT2 }))) @(0, 6, 0, 0))) | Out-Null
        $mon.Children.Add((New-Text ($s.Hint -replace '\s+--\s+', $Script:EmDash) 11.5 $U.DIM 'Normal' -Wrap -Margin 23, 1, 0, 0)) | Out-Null
    }
    $scoreBody = New-VStack @(
        (New-CardTitle 'Optimization score' $U.RED $verifyBtn),
        (New-HStack @($D.ScorePct, (New-VStack @($D.ScoreLine, $D.ScoreSub) @(14, 2, 0, 0))) @(0, 0, 0, 10)),
        $D.ScoreBar, $mon)
    $DashboardPanel.Children.Add((New-Card $scoreBody)) | Out-Null

    # ---- live monitor + network latency ----
    $row = New-Object Windows.Controls.Grid
    foreach ($i in 0, 1) { $cd = New-Object Windows.Controls.ColumnDefinition; $cd.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star); $row.ColumnDefinitions.Add($cd) }
    $lr = @{ Cpu = (New-LiveRow 'CPU' $U.RED); Ram = (New-LiveRow 'RAM' $U.VIOLET); Disk = (New-LiveRow 'Disk' $U.AMBER); Net = (New-LiveRow 'Network' $U.CYAN) }
    $liveBody = New-VStack @((New-CardTitle 'Live monitor' $U.CYAN (New-Text 'updates every 1.5 s, background thread' 11 $U.DIM)), $lr.Cpu.Root, $lr.Ram.Root, $lr.Disk.Root, $lr.Net.Root)
    $liveCard = New-Card $liveBody @(0, 0, 7, 14); $row.Children.Add($liveCard) | Out-Null

    $gwAddr = try { (Get-NetSummary).Gateway } catch { $null }
    $pingRows = New-VStack @()
    $pingInfo = New-Text "10 pings per target: average latency, packet loss and jitter. Gateway $(if ($gwAddr) { $gwAddr } else { 'unknown' })." 12 $U.DIM 'Normal' -Wrap -Margin 0, 0, 0, 4
    $pingRows.Children.Add($pingInfo) | Out-Null
    $pingBtn = New-Btn 'Run test' $U.ACC '#071018' 0xE768 -Bold -Margin 0, 0, 0, 0
    $pingBody = New-VStack @((New-CardTitle 'Network latency' $U.BLUE $pingBtn), $pingRows)
    $pingCard = New-Card $pingBody @(7, 0, 0, 14); [Windows.Controls.Grid]::SetColumn($pingCard, 1); $row.Children.Add($pingCard) | Out-Null
    $DashboardPanel.Children.Add($row) | Out-Null

    $capturedGateway = $gwAddr; $pstate = $Script:PingState; $U2 = $U
    $pingBtn.Add_Click({
        $pingBtn.IsEnabled = $false
        $pingRows.Children.Clear()
        $wait = New-Object Windows.Controls.TextBlock; $wait.Text = "Testing (10 pings per target -- the window stays responsive) ..."; $wait.FontSize = 12.5
        $wait.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.ColorConverter]::ConvertFromString($U2.DIM))
        $pingRows.Children.Add($wait) | Out-Null
        $tgts = New-Object System.Collections.ArrayList
        if ($capturedGateway) { [void]$tgts.Add(@{ Name = "Gateway ($capturedGateway)"; Host = $capturedGateway }) }
        [void]$tgts.Add(@{ Name = "Cloudflare (1.1.1.1)"; Host = "1.1.1.1" })
        [void]$tgts.Add(@{ Name = "Google (8.8.8.8)"; Host = "8.8.8.8" })
        # Pings run on a background runspace so the WPF thread never freezes. State lives in a
        # shared hashtable (not $Script:) so the close handler can always clean it up.
        $sync = [hashtable]::Synchronized(@{ Done = $false; Rows = @() })
        $pstate.Rs = [runspacefactory]::CreateRunspace(); $pstate.Rs.ApartmentState = "MTA"; $pstate.Rs.Open()
        $pstate.Rs.SessionStateProxy.SetVariable("sync", $sync); $pstate.Rs.SessionStateProxy.SetVariable("tgts", $tgts)
        $pstate.Ps = [powershell]::Create(); $pstate.Ps.Runspace = $pstate.Rs
        [void]$pstate.Ps.AddScript({
            $inv = [System.Globalization.CultureInfo]::InvariantCulture; $count = 10; $rows = @()
            foreach ($t in $tgts) {
                $replies = @(Test-Connection -ComputerName $t.Host -Count $count -ErrorAction SilentlyContinue)
                $recv = $replies.Count
                if ($recv -eq 0) { $rows += , @($t.Name, 'unreachable (100% loss)', -1); continue }
                $loss = [math]::Round((($count - $recv) / $count) * 100, 0)
                $rtts = @($replies | ForEach-Object { [double]$_.ResponseTime })
                $avgV = [math]::Round(($rtts | Measure-Object -Average).Average, 1)
                $jit = 0.0
                if ($rtts.Count -ge 2) { $diffs = for ($j = 1; $j -lt $rtts.Count; $j++) { [math]::Abs($rtts[$j] - $rtts[$j - 1]) }; $jit = [math]::Round(($diffs | Measure-Object -Average).Average, 1) }
                $rows += , @($t.Name, ("{0} ms  |  loss {1}%  |  jitter {2} ms" -f $avgV.ToString("0.#", $inv), $loss, $jit.ToString("0.#", $inv)), $avgV)
            }
            $sync.Rows = $rows; $sync.Done = $true
        })
        $handle = $pstate.Ps.BeginInvoke()
        $timer = New-Object System.Windows.Threading.DispatcherTimer; $timer.Interval = [TimeSpan]::FromMilliseconds(300)
        $timer.Add_Tick({
            if (-not $sync.Done) { return }
            $timer.Stop()
            try { $pstate.Ps.EndInvoke($handle) } catch { }
            try { $pstate.Ps.Dispose() } catch { }
            try { $pstate.Rs.Close(); $pstate.Rs.Dispose() } catch { }
            $pstate.Ps = $null; $pstate.Rs = $null
            $pingRows.Children.Clear()
            foreach ($r in $sync.Rows) {
                $col = if ($r[2] -lt 0) { $U2.ERR } elseif ($r[2] -lt 15) { $U2.GREEN } elseif ($r[2] -lt 40) { $U2.AMBER } else { $U2.ERR }
                $g = New-Object Windows.Controls.Grid; $g.Margin = New-Object Windows.Thickness(0, 6, 0, 0)
                $c0 = New-Object Windows.Controls.ColumnDefinition; $c1 = New-Object Windows.Controls.ColumnDefinition; $c1.Width = [Windows.GridLength]::Auto
                $g.ColumnDefinitions.Add($c0); $g.ColumnDefinitions.Add($c1)
                $a = New-Object Windows.Controls.TextBlock; $a.Text = $r[0]; $a.FontSize = 12.5; $a.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.ColorConverter]::ConvertFromString($U2.TEXT2))
                $b = New-Object Windows.Controls.TextBlock; $b.Text = $r[1]; $b.FontSize = 12.5; $b.FontFamily = New-Object Windows.Media.FontFamily("Consolas")
                $b.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.ColorConverter]::ConvertFromString($col))
                [Windows.Controls.Grid]::SetColumn($b, 1); $g.Children.Add($a) | Out-Null; $g.Children.Add($b) | Out-Null
                $pingRows.Children.Add($g) | Out-Null
            }
            $pingBtn.IsEnabled = $true
        }.GetNewClosure())
        $timer.Start()
    }.GetNewClosure())

    # ---- snapshot / compare + safety net ----
    $row2 = New-Object Windows.Controls.Grid
    foreach ($i in 0, 1) { $cd = New-Object Windows.Controls.ColumnDefinition; $cd.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star); $row2.ColumnDefinitions.Add($cd) }
    $btnSnapshot = New-Btn 'Take snapshot' $U.VIOLET '#120a24' 0xE895 -Bold -Margin 0, 0, 0, 0
    $btnCompare  = New-Btn 'Compare' $U.CARD2 $U.TEXT
    $resultPanel = New-VStack @() @(0, 10, 0, 0)
    $snapBody = New-VStack @((New-CardTitle 'Snapshot & compare' $U.VIOLET),
        (New-Text 'Take a snapshot, apply or revert tweaks (or install a Windows update), then compare: every tweak whose status changed is listed. The snapshot is kept after a restart.' 12.5 $U.DIM 'Normal' -Wrap -Margin 0, 0, 0, 12),
        (New-HStack @($btnSnapshot, $btnCompare)), $resultPanel)
    $snapCard = New-Card $snapBody @(0, 0, 7, 14); $row2.Children.Add($snapCard) | Out-Null

    $D.SafeBackup = New-Text '' 12.5 $U.TEXT 'SemiBold'; $D.SafeBase = New-Text '' 12.5 $U.TEXT 'SemiBold'
    $safeRow = {
        param([int]$G, [string]$C, [string]$L, $ValueBlock)
        $gr = New-Object Windows.Controls.Grid; $gr.Margin = Th 0, 5, 0, 0
        $gr.Children.Add((New-HStack @((New-Icon $G 13 $C @(0, 0, 10, 0)), (New-Text $L 12.5 $Script:UI.TEXT2)))) | Out-Null
        $ValueBlock.HorizontalAlignment = 'Right'; $gr.Children.Add($ValueBlock) | Out-Null
        $gr
    }
    $safeBody = New-VStack @((New-CardTitle 'Safety net' $U.GREEN),
        (& $safeRow 0xEA18 $U.GREEN 'Restore point before app removals' $(if (Test-SystemProtection) { New-Text "on ($env:SystemDrive protected)" 12.5 $U.TEXT 'SemiBold' } else { New-Text "System Protection off $($Script:EmDash.Trim()) asked first" 12.5 $U.AMBER 'SemiBold' })),
        (& $safeRow 0xE81C $U.VIOLET 'Last registry backup' $D.SafeBackup),
        (& $safeRow 0xE895 $U.CYAN 'Drift baseline' $D.SafeBase))
    $safeCard = New-Card $safeBody @(7, 0, 0, 14); [Windows.Controls.Grid]::SetColumn($safeCard, 1); $row2.Children.Add($safeCard) | Out-Null
    $DashboardPanel.Children.Add($row2) | Out-Null

    $snapState = @{ Snap = (Read-Snapshot) }
    if ($snapState.Snap) { $resultPanel.Children.Add((New-Text "Saved snapshot from $($snapState.Snap.Time.ToString('dd.MM.yyyy HH:mm')) -- click Compare." 12 $U.DIM)) | Out-Null }
    $btnSnapshot.Add_Click({
        $states = @{}
        foreach ($tweak in $AllTweaks) { if ($CheckFunctions.ContainsKey($tweak.Name)) { try { $states[$tweak.Name] = & $CheckFunctions[$tweak.Name] } catch { $states[$tweak.Name] = $null } } }
        $snapState.Snap = @{ Time = Get-Date; States = $states }
        $kept = Save-Snapshot $snapState.Snap
        $resultPanel.Children.Clear()
        $resultPanel.Children.Add((New-Text ("Snapshot taken at $((Get-Date).ToString('HH:mm:ss')) -- $($states.Count) tweaks recorded" + $(if ($kept) { ", kept after a restart." } else { " (could not be saved -- only until the app closes)." })) 12 $U.GREEN -Wrap)) | Out-Null
    }.GetNewClosure())
    $btnCompare.Add_Click({
        $resultPanel.Children.Clear()
        if (-not $snapState.Snap) { $resultPanel.Children.Add((New-Text "No snapshot yet -- click 'Take snapshot' first." 12 $U.AMBER)) | Out-Null; return }
        $since = if ($snapState.Snap.Time.Date -eq (Get-Date).Date) { $snapState.Snap.Time.ToString('HH:mm:ss') } else { $snapState.Snap.Time.ToString('dd.MM.yyyy HH:mm') }
        $resultPanel.Children.Add((New-Text "Changes since $($since):" 12 $U.TEXT 'SemiBold' -Margin 0, 0, 0, 4)) | Out-Null
        $changeCount = 0
        foreach ($tweak in $AllTweaks) {
            if (-not $CheckFunctions.ContainsKey($tweak.Name) -or -not $snapState.Snap.States.ContainsKey($tweak.Name)) { continue }
            $before = $snapState.Snap.States[$tweak.Name]
            try { $after = & $CheckFunctions[$tweak.Name] } catch { $after = $null }
            if ($before -ne $after) {
                $changeCount++
                # No hashtable lookup with a $null key here (illegal in a PowerShell hash literal)
                $lblBefore = if ($null -eq $before) { "unknown" } elseif ($before -eq $true) { "active" } else { "inactive" }
                $lblAfter  = if ($null -eq $after)  { "unknown" } elseif ($after  -eq $true) { "active" } else { "inactive" }
                $resultPanel.Children.Add((New-Text "$($tweak.Name): $lblBefore -> $lblAfter" 12 $U.TEXT2 -Margin 0, 1, 0, 1)) | Out-Null
            }
        }
        if ($changeCount -eq 0) { $resultPanel.Children.Add((New-Text "No changes detected since the snapshot." 12 $U.DIM)) | Out-Null }
    }.GetNewClosure())

    # ---- live monitor sampler: CIM perf classes on a BACKGROUND runspace; the UI timer only reads ----
    $monData = [hashtable]::Synchronized(@{ Run = $true; Ready = $false; Cpu = 0.0; RamPct = 0.0; RamUsedGB = 0.0; RamTotGB = 0.0; Disk = 0.0; NetMbps = 0.0 })
    $monRs = [runspacefactory]::CreateRunspace(); $monRs.ApartmentState = "MTA"; $monRs.ThreadOptions = "ReuseThread"; $monRs.Open()
    $monRs.SessionStateProxy.SetVariable("monData", $monData)
    $monPs = [powershell]::Create(); $monPs.Runspace = $monRs
    [void]$monPs.AddScript({
        while ($monData.Run) {
            try {
                $monData.Cpu = [double](Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction SilentlyContinue).PercentProcessorTime
                $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
                if ($os -and $os.TotalVisibleMemorySize) {
                    $monData.RamPct    = [double]((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100)
                    $monData.RamUsedGB = [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB), 1)
                    $monData.RamTotGB  = [math]::Round(($os.TotalVisibleMemorySize / 1MB), 1)
                }
                $monData.Disk    = [math]::Min([double](Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk -Filter "Name='_Total'" -ErrorAction SilentlyContinue).PercentDiskTime, 100)
                $netBps          = (Get-CimInstance Win32_PerfFormattedData_Tcpip_NetworkInterface -ErrorAction SilentlyContinue | Measure-Object -Property BytesTotalPersec -Sum).Sum
                $monData.NetMbps = [math]::Round(($netBps * 8 / 1MB), 1)
                $monData.Ready   = $true
            } catch { }
            # Sleep in short chunks so setting Run=$false stops the loop within ~100 ms
            for ($i = 0; $i -lt 15 -and $monData.Run; $i++) { Start-Sleep -Milliseconds 100 }
        }
    })
    $monHandle = $monPs.BeginInvoke()
    $pstate2 = $Script:PingState
    $Window.Add_Closed({
        $monData.Run = $false
        try { $monPs.EndInvoke($monHandle) } catch { }
        try { $monPs.Dispose() } catch { }
        try { $monRs.Close(); $monRs.Dispose() } catch { }
        # A ping test still running when the window closes: stop + dispose its runspace too
        try { if ($pstate2.Ps) { $pstate2.Ps.Stop(); $pstate2.Ps.Dispose(); $pstate2.Ps = $null } } catch { }
        try { if ($pstate2.Rs) { $pstate2.Rs.Close(); $pstate2.Rs.Dispose(); $pstate2.Rs = $null } } catch { }
    }.GetNewClosure())
    $monTimer = New-Object System.Windows.Threading.DispatcherTimer
    $monTimer.Interval = [TimeSpan]::FromMilliseconds(750)
    $monTimer.Add_Tick({
        if (-not $monData.Ready) { return }
        $inv = [System.Globalization.CultureInfo]::InvariantCulture
        Set-Bar $lr.Cpu.Bar $monData.Cpu;    $lr.Cpu.Val.Text  = "{0} %" -f [int]$monData.Cpu
        Set-Bar $lr.Ram.Bar $monData.RamPct; $lr.Ram.Val.Text  = "{0} %  {1} GB" -f [int]$monData.RamPct, ([double]$monData.RamUsedGB).ToString("0.#", $inv)
        Set-Bar $lr.Disk.Bar $monData.Disk;  $lr.Disk.Val.Text = "{0} %" -f [int]$monData.Disk
        Set-Bar $lr.Net.Bar ([math]::Min(100, $monData.NetMbps)); $lr.Net.Val.Text = "{0} Mbps" -f ([double]$monData.NetMbps).ToString("0.#", $inv)
    }.GetNewClosure())
    $monTimer.Start()
}

function Update-ScoreCard {
    $D = $Script:Dash; if (-not $D.ScorePct) { return }
    # Measured against the recommended preset (Balanced) -- tweaks outside it (riskier ones, the
    # two DNS providers that exclude each other) don't move it, so 100 % is reachable
    $sc = Get-StateCounts
    $set = @($Script:PresetBalanced | Where-Object { $Script:TweakState[$_] -eq 'active' -or $Script:TweakState[$_] -eq 'inactive' })
    $a = @($set | Where-Object { $Script:TweakState[$_] -eq 'active' }).Count
    $c = $set.Count
    $score = if ($c) { [math]::Round($a / $c * 100) } else { 0 }
    $col = if ($score -ge 80) { $Script:UI.GREEN } elseif ($score -ge 50) { $Script:UI.AMBER } else { $Script:UI.ERR }
    $D.ScorePct.Text = "$score %"; $D.ScorePct.Foreground = Brush $col
    $D.ScoreLine.Text = "$a of $c tweaks of the recommended Balanced preset are active"
    $D.ScoreSub.Text = "All tweaks: $($sc.Active) active$($Script:Mid)$($sc.Inactive) inactive" + $(if ($sc.NA) { "$($Script:Mid)$($sc.NA) not applicable here" } else { "" }) + "$($Script:Mid)drift check at every start"
    Set-Bar $D.ScoreBar $score $col
    $bk = Get-BackupSummary
    $D.SafeBackup.Text = $bk.Last
    $D.SafeBase.Text = Get-BaselineSummary
}

# =============================================================================
# PRESETS PAGE
# =============================================================================
$Script:PresetView = @{ Cards = @{}; Cats = @{}; Preview = 'Balanced' }

function Get-PresetList([string]$Name) {
    switch ($Name) { 'Minimal' { $Script:PresetMinimal } 'Balanced' { $Script:PresetBalanced } default { $Script:PresetAggressive } }
}
function Show-PresetPreview([string]$Name) { $Script:PresetView.Preview = $Name; Update-PresetCards }

function Build-PresetsPage {
    $U = $Script:UI; $V = $Script:PresetView
    $PresetsPanel.Children.Clear()
    $vb = New-Btn 'Verify status' $U.CARD2 $U.TEXT 0xE72C -Margin 0, 0, 0, 0
    $vb.Add_Click({ Invoke-Verify })
    $PresetsPanel.Children.Add((New-PageHeader 'Presets' 'One click ticks a set of tweaks -- nothing changes until you press Apply selected (a registry backup comes first, plus a restore point if apps are removed).' $U.AMBER @($vb))) | Out-Null

    $defs = @(
        @{ Name = 'Minimal';    Color = $U.GREEN; Fg = '#ffffff'; Desc = 'Safe basics only: privacy, gaming priority, network latency. No app removal, nothing you would miss. Ideal first run.' }
        @{ Name = 'Balanced';   Color = $U.AMBER; Fg = '#1a1205'; Desc = 'Minimal + Ultimate Performance, HPET / timer, GPU and audio tweaks, light debloat (Copilot, Recall, tips & ads) and the Windows AI and privacy switches. The recommended all-round setup.' }
        @{ Name = 'Aggressive'; Color = $U.RED;   Fg = '#ffffff'; Desc = 'Everything: + Xbox / OneDrive removal, no background Store apps, no drivers from Windows Update, no hibernation, no memory compression. For experienced users -- removed apps need System Restore.' }
    )
    $grid = New-Object Windows.Controls.Grid; $grid.Margin = Th 0, 0, -14, 0
    foreach ($i in 0..2) { $cd = New-Object Windows.Controls.ColumnDefinition; $cd.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star); $grid.ColumnDefinitions.Add($cd) }
    $col = 0
    foreach ($d in $defs) {
        $name = $d.Name
        $dot = New-Object Windows.Shapes.Ellipse; $dot.Width = 20; $dot.Height = 20; $dot.Fill = Brush $d.Color; $dot.Margin = Th 0, 0, 12, 0
        $sub = New-Text '' 12 $d.Color
        $bar = New-Bar 0 $d.Color 4
        $sel = New-Btn 'Select' $d.Color $d.Fg 0 -Bold -Margin 0, 0, 0, 0
        $prev = New-Btn 'Preview' $U.CARD2 $U.TEXT
        $prev.Add_Click({ Show-PresetPreview $name }.GetNewClosure())
        $desc = New-Text $d.Desc 12.5 $U.DESC 'Normal' -Wrap -Margin 0, 12, 0, 14
        $desc.MinHeight = 52
        $body = New-VStack @((New-HStack @($dot, (New-VStack @((New-Text $name 15 $U.TEXT 'SemiBold'), $sub))) @(0, 0, 0, 10)), $bar, $desc, (New-HStack @($sel, $prev)))
        $card = New-Card $body @(0, 0, 14, 14); [Windows.Controls.Grid]::SetColumn($card, $col); $grid.Children.Add($card) | Out-Null
        $V.Cards[$name] = @{ Sub = $sub; Bar = $bar; Card = $card; Color = $d.Color }
        switch ($name) { 'Minimal' { $Script:BtnPresetMin = $sel } 'Balanced' { $Script:BtnPresetBal = $sel } 'Aggressive' { $Script:BtnPresetAgg = $sel } }
        $col++
    }
    $PresetsPanel.Children.Add($grid) | Out-Null

    # ---- your own selection: save the ticked tweaks to a file, tick them again later or on another PC ----
    $exp = New-Btn 'Save ticked tweaks ...' $U.CARD2 $U.TEXT 0xE74E -Margin 0, 0, 8, 0
    $imp = New-Btn 'Load a list ...' $U.CARD2 $U.TEXT 0xE8E5 -Margin 0, 0, 0, 0
    $exp.Add_Click({
        $names = @($AllTweaks | Where-Object { $CheckBoxMap[$_.Name].IsChecked -eq $true } | ForEach-Object { $_.Name })
        if (-not $names.Count) { Set-Status 'Nothing ticked -- tick the tweaks you want to keep in the list first.'; return }
        $dlg = New-Object Microsoft.Win32.SaveFileDialog
        $dlg.Filter = 'Text file (*.txt)|*.txt'; $dlg.FileName = "GameOptimizerPro-selection-$(Get-Date -Format 'yyyyMMdd').txt"
        if (-not $dlg.ShowDialog($Window)) { return }
        try {
            @("# GameOptimizerPro v$($Script:AppVersion) -- ticked tweaks, one per line ($(Get-Date -Format 'yyyy-MM-dd'))") + $names | Set-Content -LiteralPath $dlg.FileName -Encoding UTF8 -ErrorAction Stop
            Set-Status "$($names.Count) ticked tweaks saved to $($dlg.FileName)"; Write-Log "Selection exported: $($names.Count) tweaks -> $($dlg.FileName)"
        } catch { Set-Status "Could not save the list: $($_.Exception.Message)" }
    })
    $imp.Add_Click({
        $dlg = New-Object Microsoft.Win32.OpenFileDialog
        $dlg.Filter = 'Text file (*.txt)|*.txt|All files (*.*)|*.*'
        if (-not $dlg.ShowDialog($Window)) { return }
        try { $lines = @(Get-Content -LiteralPath $dlg.FileName -Encoding UTF8 -ErrorAction Stop | ForEach-Object { "$_".Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') }) }
        catch { Set-Status "Could not read the list: $($_.Exception.Message)"; return }
        $lines = @($lines | ForEach-Object { if ($Script:RenamedTweaks.ContainsKey($_)) { $Script:RenamedTweaks[$_] } else { $_ } })
        $unknown = @($lines | Where-Object { -not $CheckBoxMap.ContainsKey($_) })
        Set-Preset $lines 'Custom list'
        if ($unknown.Count) { $StatusText.Text += " $($unknown.Count) name(s) from the list don't exist in this version." }
        Write-Log "Selection imported from $($dlg.FileName): $($lines.Count) names, $($unknown.Count) unknown"
        Show-Preset-Result
    })
    $own = New-VStack @((New-CardTitle 'Your own selection' $U.VIOLET),
        (New-Text 'Save the tweaks you ticked to a text file and tick them again later -- after a reinstall or on a second PC. Loading only ticks; nothing changes until you press Apply selected. Tweaks this PC cannot use are skipped.' 12.5 $U.DESC 'Normal' -Wrap -Margin 0, 0, 0, 12),
        (New-HStack @($exp, $imp)))
    $PresetsPanel.Children.Add((New-Card $own @(0, 0, 0, 14))) | Out-Null

    $PresetsPanel.Children.Add((New-SectionTitle 'Status by category' $U.WIN11 '' @(0, 4, 0, 10))) | Out-Null
    $cg = New-Object Windows.Controls.Grid; $cg.Margin = Th 0, 0, -12, 0
    foreach ($i in 0..3) { $cd = New-Object Windows.Controls.ColumnDefinition; $cd.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star); $cg.ColumnDefinitions.Add($cd) }
    foreach ($i in 0, 1) { $rd = New-Object Windows.Controls.RowDefinition; $rd.Height = [Windows.GridLength]::Auto; $cg.RowDefinitions.Add($rd) }
    $icons = @(0xE7F8, 0xE7FC, 0xE839, 0xEDA2, 0xE7F4, 0xE767, 0xEEA1, 0xE945)
    for ($i = 0; $i -lt $Script:Cats.Count; $i++) {
        $c = $Script:Cats[$i]; $catKey = $c.Key
        $cnt = New-Text '' 12.5 $c.Color 'SemiBold'; $cnt.HorizontalAlignment = 'Right'
        $hdr = New-Object Windows.Controls.Grid; $hdr.Margin = Th 0, 0, 0, 8
        $hdr.Children.Add((New-HStack @((New-Icon $icons[$i] 14 $c.Color @(0, 0, 9, 0)), (New-Text $c.Label 13 $U.TEXT 'SemiBold')))) | Out-Null
        $hdr.Children.Add($cnt) | Out-Null
        $bar = New-Bar 0 $c.Color 4
        $card = New-Card (New-VStack @($hdr, $bar)) @(0, 0, 12, 12) @(14, 12, 14, 12)
        $card.Cursor = [System.Windows.Input.Cursors]::Hand
        $card.ToolTip = "Open the $($c.Label) tweaks"
        $card.Add_MouseLeftButtonUp({ Show-Page 'tweaks'; Select-Category $catKey }.GetNewClosure())
        [Windows.Controls.Grid]::SetRow($card, [math]::Floor($i / 4)); [Windows.Controls.Grid]::SetColumn($card, $i % 4)
        $cg.Children.Add($card) | Out-Null
        $V.Cats[$catKey] = @{ Cnt = $cnt; Bar = $bar }
    }
    $PresetsPanel.Children.Add($cg) | Out-Null

    $V.PreviewTitle = New-Text '' 15 $U.TEXT 'SemiBold'
    $V.PreviewWrap = New-Object Windows.Controls.WrapPanel
    $ptitle = New-Object Windows.Controls.Grid; $ptitle.Margin = Th 0, 0, 0, 12
    $bar2 = New-Object Windows.Controls.Border; $bar2.Width = 3; $bar2.Height = 16; $bar2.CornerRadius = New-Object Windows.CornerRadius(2); $bar2.Background = Brush $U.AMBER; $bar2.Margin = Th 0, 0, 10, 0
    $V.PreviewBar = $bar2
    $ptitle.Children.Add((New-HStack @($bar2, $V.PreviewTitle))) | Out-Null
    $lg = New-Text "green = already active$($Script:Mid)grey = would be applied" 11.5 $U.DIM; $lg.HorizontalAlignment = 'Right'
    $ptitle.Children.Add($lg) | Out-Null
    $PresetsPanel.Children.Add((New-Card (New-VStack @($ptitle, $V.PreviewWrap)) @(0, 4, 0, 14))) | Out-Null

    $drift = New-HStack @((New-Icon 0xEA18 16 $U.GREEN @(0, 0, 12, 0)),
        (New-VStack @((New-Text 'Drift check' 13.5 $U.TEXT 'SemiBold'), (New-Text 'At every start the tool compares your last Apply with the live state and offers to re-apply what a Windows update reset. No background process, no autostart.' 12 $U.DIM 'Normal' -Wrap))))
    $PresetsPanel.Children.Add((New-Card $drift)) | Out-Null
}

function Update-PresetCards {
    $V = $Script:PresetView; if (-not $V.PreviewWrap) { return }
    foreach ($name in 'Minimal', 'Balanced', 'Aggressive') {
        $list = @(Get-PresetList $name)
        $chk = @($list | Where-Object { $Script:TweakState[$_] -and $Script:TweakState[$_] -ne 'unknown' })
        $on = @($chk | Where-Object { $Script:TweakState[$_] -eq 'active' }).Count
        $c = $V.Cards[$name]
        $c.Sub.Text = "$on/$($chk.Count) active$($Script:Mid)$($list.Count) tweaks"
        Set-Bar $c.Bar $(if ($chk.Count) { $on / $chk.Count * 100 } else { 0 })
        $c.Card.BorderBrush = Brush $(if ($name -eq $V.Preview) { (Mix-Hex $Script:UI.CARD $c.Color 0.55) } else { $Script:UI.BORDER })
    }
    foreach ($c in $Script:Cats) {
        $names = @($AllTweaks | Where-Object { $_.Category -eq $c.Key } | ForEach-Object { $_.Name })
        $chk = @($names | Where-Object { $Script:TweakState[$_] -and $Script:TweakState[$_] -ne 'unknown' })
        $on = @($chk | Where-Object { $Script:TweakState[$_] -eq 'active' }).Count
        $V.Cats[$c.Key].Cnt.Text = "$on/$($chk.Count)"
        Set-Bar $V.Cats[$c.Key].Bar $(if ($chk.Count) { $on / $chk.Count * 100 } else { 0 })
    }
    $pv = $V.Preview
    $V.PreviewTitle.Text = "Preview: $pv"
    $V.PreviewBar.Background = Brush $V.Cards[$pv].Color
    $V.PreviewWrap.Children.Clear()
    foreach ($t in ($AllTweaks | Where-Object { (Get-PresetList $pv) -contains $_.Name })) {
        $s = $Script:TweakState[$t.Name]
        $e = New-Object Windows.Shapes.Ellipse; $e.Width = 6; $e.Height = 6; $e.Margin = Th 0, 0, 6, 0; $e.VerticalAlignment = 'Center'
        $e.Fill = Brush $(if ($s -eq 'active') { $Script:UI.GREEN } else { $Script:UI.MUTED })
        $chip = New-Object Windows.Controls.Border
        $chip.CornerRadius = New-Object Windows.CornerRadius(6); $chip.Background = Brush $Script:UI.CARD2; $chip.BorderBrush = Brush $Script:UI.BORDER
        $chip.BorderThickness = Th 1; $chip.Padding = Th 8, 3, 8, 3; $chip.Margin = Th 0, 0, 6, 6
        $chip.Child = New-HStack @($e, (New-Text $t.Name 11.5 $Script:UI.TEXT2))
        if ($CheckBoxMap.ContainsKey($t.Name) -and -not $CheckBoxMap[$t.Name].IsEnabled) { $chip.Opacity = 0.45; $chip.ToolTip = 'Not available on this PC -- skipped' }
        $V.PreviewWrap.Children.Add($chip) | Out-Null
    }
}

# =============================================================================
# BACKUPS & LOG PAGE
# =============================================================================
function Build-BackupsPage {
    $U = $Script:UI
    $BackupsPanel.Children.Clear()
    $BackupsPanel.Children.Add((New-PageHeader 'Backups & Log' 'Everything GameOptimizerPro changes is backed up first -- here are the backups, the log and the ways back.' $U.VIOLET)) | Out-Null
    $grid = New-Grid2
    $bk = Get-BackupSummary
    $mk = {
        param([string]$Title, [string]$Accent, [string]$Text, [object[]]$Extra, $Button)
        $v = New-VStack @((New-CardTitle $Title $Accent), (New-Text $Text 12.5 $Script:UI.TEXT2 'Normal' -Wrap))
        foreach ($x in $Extra) { if ($x) { $v.Children.Add($x) | Out-Null } }
        if ($Button) { $Button.HorizontalAlignment = 'Left'; $Button.Margin = Th 0, 12, 0, 0; $v.Children.Add($Button) | Out-Null }
        $c = New-Card $v @(0, 0, 0, 0); $c.VerticalAlignment = 'Stretch'; $c
    }
    $b1 = New-Btn 'Open backup folder' $U.VIOLET '#120a24' 0xE838 -Bold; $b1.Add_Click({ Open-BackupFolder })
    Add-Grid2 $grid (& $mk 'Registry backups' $U.VIOLET 'Before every Apply and Revert, every registry key a tweak touches is exported to .reg files. Double-click one to put the saved values back; _remove-new-keys.reg deletes keys that did not exist yet, _values.reg holds two single values. Values a tweak added to an existing key go away with its revert. The newest 20 backups of this app are kept (those of GameOptimizerPro v2 in the same folder are left alone).' @(
        (New-Text "$($bk.Count) backup(s)$($Script:Mid)last: $($bk.Last)" 12 $U.DIM 'Normal' -Wrap -Margin 0, 8, 0, 0),
        (New-Text $Script:RegistryBackupRoot 11.5 $U.MUTED 'Normal' -Wrap -Mono -Margin 0, 4, 0, 0)) $b1)
    $b2 = New-Btn 'Open log' $U.CARD2 $U.TEXT 0xE838; $b2.Add_Click({ Open-LogFile })
    Add-Grid2 $grid (& $mk 'Log' $U.CYAN 'Every action of this session is written to a log file -- what was applied, what failed and why.' @(
        (New-Text $LogFile 11.5 $U.MUTED 'Normal' -Wrap -Mono -Margin 0, 8, 0, 0)) $b2)
    $b3 = New-Btn 'Open System Restore' $U.CARD2 $U.TEXT 0xE7A7
    $b3.Add_Click({ try { Start-Process "rstrui.exe" } catch { [System.Windows.MessageBox]::Show("Could not open System Restore (rstrui.exe). Run it manually: Start -> type rstrui", "Error") | Out-Null } })
    Add-Grid2 $grid (& $mk 'System Restore' $U.GREEN 'A restore point is created before every Apply that removes apps; if System Protection is off, you are asked first. Removed apps also come back through the Microsoft Store. Everything else has its own revert and is in the registry backup.' @() $b3)
    $b4 = New-Btn 'Revert all ...' $U.AMBER '#1a1205' 0xE7A7 -Bold
    $b4.Add_Click({ $BtnRevertAll.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent))) })
    Add-Grid2 $grid (& $mk 'Revert all' $U.AMBER 'Sets every tweak GameOptimizerPro applied back to the Windows default -- no reboot needed. Settings you made yourself stay. Removed apps come back through the Microsoft Store or System Restore.' @() $b4)
    Add-Grid2 $grid (& $mk 'Drift check' $U.WIN11 'After every Apply the active tweaks are recorded. At every start the tool checks whether a Windows update reset any of them and offers to re-apply them -- no background process, no autostart.' @(
        (New-Text "Baseline: $(Get-BaselineSummary)" 12 $U.DIM 'Normal' -Wrap -Margin 0, 8, 0, 0)) $null)
    $BackupsPanel.Children.Add($grid) | Out-Null
}

# =============================================================================
# LANGUAGE (descriptions only -- the interface stays English)
# =============================================================================
function Update-LangButton {
    $BtnLang.Content = New-HStack @((New-Icon 0xE774 12 $Script:UI.TEXT2 @(0, 0, 6, 0)), (New-Text "Info: $($LangState.Current)" 11.5 $Script:UI.TEXT 'SemiBold'))
}

# -----------------------------------------
# PRESETS (cumulative: Minimal subset of Balanced subset of Aggressive)
# One-time/destructive actions (Deep Clean, Empty Recycle Bin, Run Disk
# Cleanup, Clear Shader Cache, Clean Temp Files, Flush DNS) and the DNS
# provider tweaks (Cloudflare vs Google conflict) are deliberately NEVER
# part of a preset -- those stay a conscious manual choice.
# -----------------------------------------
$Script:PresetMinimal = @(
    "Disable Telemetry & Data Collection","Disable Activity History","Disable Advertising ID",
    "Disable Location Tracking","Disable Scheduled Telemetry Tasks",
    "Prevent Device Companion Apps","Disable Consumer Features","Disable Windows Platform Binary Table (WPBT)",
    "Disable Power Throttling",
    "Enable Game Mode","CPU Priority for Games (Win32Priority)","MMCSS Gaming Profile (High Priority)","Disable Fullscreen Optimizations",
    "Disable Mouse Acceleration","Show File Extensions",
    "Disable Nagle's Algorithm (TCPNoDelay)","Disable Network Throttling Index",
    "Disable Delivery Optimization (P2P Windows Update)"
)
$Script:PresetBalanced = $Script:PresetMinimal + @(
    "Remove Copilot","Remove Windows Recall","Remove Other Bloatware",
    "Stop Auto-Installed Suggested Apps","Disable Tips, Ads & Suggestions","Stop OneDrive Folder Backup","Disable Get Started & Copilot Sign-in Screens",
    "Disable Click to Do & Settings Agent (AI)","Disable AI in Paint & Notepad","Disable Text & Image Generation (AI)",
    "Block Telemetry Hosts (hosts file)","Disable Input & Speech Data Collection","Disable Remote Assistance",
    "Ultimate Performance Plan","Disable HPET (High Precision Event Timer)","Allow Global Timer Resolution (Windows 11)",
    "Disable Prefetch & Superfetch","Optimize Visual Effects (Performance Mode)","Disable Startup App Delay","Disable Bing in Windows Search",
    "Disable Store Recommended Search Results","Disable File Explorer Automatic Folder Discovery",
    "Disable Xbox Game Bar",
    "Enable MSI Mode (Message Signaled Interrupts)","Enable Hardware-Accelerated GPU Scheduling (HAGS)","Increase GPU Timeout Tolerance (TDR)",
    "AMD: Disable ULPS (Ultra Low Power State)",
    "Disable Audio Enhancements","Optimize MMCSS Audio Profile","Set Audio Service High Priority","Disable Windows Sound Scheme",
    "Disable Large Send Offload (LSO)","Disable Network Adapter Power Saving","Disable Energy-Efficient Ethernet",
    "Disable Sticky Keys","Enable Dark Mode","Disable Transparency Effects",
    "Restore Classic Right-Click Menu","Left-Align Taskbar","Disable Widgets","Disable Recommended in Start Menu","Enable End Task in Taskbar","Disable Snap Layout Hover Menu",
    "Show Hidden Files","Num Lock on Startup","Enable Long Paths",
    "Optimize PageFile (System Managed)","Enable SSD TRIM",
    "Disable USB Selective Suspend","Disable USB 3 Link Power Management","Disable PCI-E Link State Power Management","Disable Hard Disk Sleep","Disable Wake Timers","CPU Minimum Processor State = 100%","CPU Maximum Processor State = 100%"
)
$Script:PresetAggressive = $Script:PresetBalanced + @(
    "Remove Xbox Apps","Remove OneDrive","Block Background Apps (Policy)","Stop Background Apps (All Editions)","Exclude Drivers from Windows Update",
    "Disable Windows Search Indexing","Process Count Reduction (Svchost)","Disable Interrupt Moderation",
    "Disable Memory Compression","Disable Write-Cache Buffer Flushing","Disable Hibernation","Clear PageFile on Shutdown",
    "Disable Reserved Storage","Disable Storage Sense","Disable Lock Screen",
    "Disable Sleep (System)"
)
# NOTE: "Set Display Sleep = 15 Minutes" is deliberately NOT part of any preset.
# It writes VIDEOIDLE to every scheme and would overwrite the "never turn the
# display off" value that "Ultimate Performance Plan" (in Balanced/Aggressive)
# sets on its own plan -- the display would sleep again despite the Ultimate
# plan promising otherwise. Both remain selectable manually; the Apply handler
# warns when the two are combined.
# Also in no preset: 'Hold Feature Updates' (a choice with an end date -- revert it in
# time), 'Alt+Tab Without Browser Tabs' and 'Disable Dynamic Lighting' (taste / RGB setup),
# and since 1.2.6 'Disable Automatic Windows Updates' (no security updates unless you look
# yourself), 'Disable TCP Auto-Tuning' (caps downloads at the 64 KB window) and 'Disable
# Scheduled Defragmentation' (on SSDs it only stops the weekly retrim).

function Set-Preset {
    param([string[]]$Names, [string]$Label)
    foreach ($cb in $CheckBoxMap.Values) { $cb.IsChecked = $false }
    $sel = 0; $skipped = 0
    foreach ($n in $Names) {
        if ($CheckBoxMap.ContainsKey($n)) {
            if ($CheckBoxMap[$n].IsEnabled) { $CheckBoxMap[$n].IsChecked = $true; $sel++ }
            else { $skipped++ }
        }
    }
    $StatusText.Text = "Preset '$Label': $sel tweaks ticked$(if ($skipped) { " ($skipped skipped -- not available on this PC)" }). Review the list, then click 'Apply selected'."
}

# =============================================================================
# BUILD THE PAGES  (here, because the Presets page needs the preset lists above)
# =============================================================================
Set-Splash "Building the dashboard ..." 88
Build-DashboardPage
Build-PresetsPage
Build-BiosPlatformList
Update-BiosPlatformList
Render-BiosPage
Update-LangButton
Update-Counts
Select-Category 'Windows'
Show-Page 'dashboard'

# -----------------------------------------
# UI HELPERS FOR LONG OPERATIONS
# Apply, Revert All and Verify run on the UI thread. Set-Status paints a new status
# text right away (otherwise it only shows up once the work is done), and Set-Busy
# locks the action buttons so a second click can't start a nested run.
# -----------------------------------------
$Script:Busy = $false
function Set-Status([string]$Text) {
    $StatusText.Text = $Text
    try { $Window.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::Render) } catch { }
}
function Set-Busy([bool]$On) {
    $Script:Busy = $On
    foreach ($b in @($BtnApply, $BtnRevertAll, $BtnRevertSel, $BtnVerify, $BtnSelectAll, $BtnDeselect, $Script:BtnPresetMin, $Script:BtnPresetBal, $Script:BtnPresetAgg)) {
        if ($b) { $b.IsEnabled = -not $On }
    }
}
# Checkpoint-Computer can take 10-60 s (Volume Shadow Copy). It runs on a background
# runspace while the window keeps repainting, so Windows never marks the app as
# "Not responding". Throws, like Checkpoint-Computer, if no point could be created.
function New-RestorePoint([string]$Description) {
    # Windows creates at most one point per 24 h. Lift that limit for this one call and
    # put the old setting back afterwards; 0 is what older versions left behind for good,
    # so it is treated like "not set".
    $srKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore"
    $oldFreq = Get-RegVal $srKey "SystemRestorePointCreationFrequency"
    Set-ItemProperty -Path $srKey -Name "SystemRestorePointCreationFrequency" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    $ps = [powershell]::Create()
    try {
        [void]$ps.AddScript({ param($d) Checkpoint-Computer -Description $d -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop }).AddArgument($Description)
        $handle = $ps.BeginInvoke()
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while (-not $handle.IsCompleted) {
            Set-Status ("Creating restore point ... {0} s" -f [int]$sw.Elapsed.TotalSeconds)
            Start-Sleep -Milliseconds 150
        }
        $null = $ps.EndInvoke($handle)
        if ($ps.Streams.Error.Count) { throw $ps.Streams.Error[0] }
    } finally {
        $ps.Dispose()
        if ($null -eq $oldFreq -or $oldFreq -eq 0) { Remove-ItemProperty -Path $srKey -Name "SystemRestorePointCreationFrequency" -ErrorAction SilentlyContinue }
        else { Set-ItemProperty -Path $srKey -Name "SystemRestorePointCreationFrequency" -Value $oldFreq -Type DWord -ErrorAction SilentlyContinue }
    }
}
# Long external tools (DISM /ResetBase can take 5-15 minutes) run hidden while the window
# keeps answering and the status bar counts the seconds -- no "Not responding". Stops the
# tool after $TimeoutSec and throws, so the Apply reports it. Returns the exit code.
function Invoke-ProcessWithUi([string]$FilePath, [string]$Arguments, [string]$What, [int]$TimeoutSec = 1800, [switch]$Visible) {
    $p = Start-Process -FilePath $FilePath -ArgumentList $Arguments -WindowStyle $(if ($Visible) { 'Normal' } else { 'Hidden' }) -PassThru -ErrorAction Stop
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while (-not $p.HasExited) {
        if ($sw.Elapsed.TotalSeconds -gt $TimeoutSec) {
            try { $p.Kill() } catch { }
            throw "$What did not finish within $([int]($TimeoutSec / 60)) minutes and was stopped"
        }
        Set-Status ("$What ... {0} s" -f [int]$sw.Elapsed.TotalSeconds)
        try { $Window.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::Background) } catch { }
        Start-Sleep -Milliseconds 200
    }
    $p.ExitCode
}
# Re-reads every tweak's status (dots, counts, $Script:CheckRaw) with a visible progress
function Update-AllDots([string]$Label) {
    $i = 0; $n = @($AllTweaks).Count
    foreach ($tweak in $AllTweaks) {
        $i++
        if ($i % 12 -eq 0) { Set-Status "$Label $i / $n ..." }
        if ($Script:TweakDots.ContainsKey($tweak.Name)) { Update-TweakDot $Script:TweakDots[$tweak.Name] $tweak.Name | Out-Null }
    }
    Update-Counts
}

# -----------------------------------------
# BUTTON EVENTS
# -----------------------------------------
$BtnSelectAll.Add_Click({
    # Only what is shown (the open tab, or the search hits) and selectable on this PC --
    # never greyed-out tweaks (Windows 11 only, AMD only, Enterprise only, Pro and up).
    $shown = @($Script:Cats | Where-Object { $_.Panel.Visibility -eq 'Visible' } | ForEach-Object { $_.Key })
    $cfBefore = $CheckBoxMap["Set DNS to Cloudflare (1.1.1.1)"].IsChecked -eq $true
    $n = 0
    foreach ($r in $Script:TweakRows.Values) {
        $cb = $CheckBoxMap[$r.Tweak.Name]
        if ($cb.IsEnabled -and $r.Card.Visibility -eq 'Visible' -and $shown -contains $r.Tweak.Category) { $cb.IsChecked = $true; $n++ }
    }
    # The two DNS tweaks exclude each other (the one applied last would win): keep the
    # one that was ticked before, Cloudflare if neither was
    $cf = $CheckBoxMap["Set DNS to Cloudflare (1.1.1.1)"]; $gg = $CheckBoxMap["Set DNS to Google (8.8.8.8)"]
    if ($cf.IsChecked -and $gg.IsChecked) { $drop = if ($cfBefore) { $gg } else { $cf }; $drop.IsChecked = $false; $n-- }
    $StatusText.Text = "$n tweaks ticked (the ones shown and available on this PC). Review them, then click 'Apply selected'."
})

$BtnDeselect.Add_Click({
    foreach ($cb in $CheckBoxMap.Values) { $cb.IsChecked = $false }
})

# Preset buttons live on the Presets page; after selecting, jump to the tweak list
# so the user sees what got ticked and where "Apply selected" is.
$BtnPresetMin.Add_Click({ Set-Preset $Script:PresetMinimal "Minimal"; Show-Preset-Result })
$BtnPresetBal.Add_Click({ Set-Preset $Script:PresetBalanced "Balanced"; Show-Preset-Result })
$BtnPresetAgg.Add_Click({
    $r = [System.Windows.MessageBox]::Show(
        "The 'Aggressive' preset also selects app removals (OneDrive, Xbox, Recall, bloatware) and aggressive tweaks.`n`nRemoved apps don't come back with 'Revert all' -- reinstall them from the Microsoft Store (OneDrive: its installer) or use System Restore.`n`nSelect the aggressive preset now? (Nothing is applied until you click 'Apply selected'.)",
        "GameOptimizerPro -- Aggressive Preset",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning)
    if ($r -eq [System.Windows.MessageBoxResult]::Yes) { Set-Preset $Script:PresetAggressive "Aggressive"; Show-Preset-Result }
})
function Show-Preset-Result {
    if ($SearchBox.Text) { $SearchBox.Text = '' }
    Show-Page 'tweaks'
}

$BtnOpenLog.Add_Click({ Open-LogFile })
$BtnOpenBackups.Add_Click({ Open-BackupFolder })
$BtnVerify.Add_Click({ Invoke-Verify })

$BtnApply.Add_Click({
    if ($Script:Busy) { return }
    $selected = @($AllTweaks | Where-Object { $CheckBoxMap[$_.Name].IsEnabled -and $CheckBoxMap[$_.Name].IsChecked -eq $true })

    if ($selected.Count -eq 0) {
        [System.Windows.MessageBox]::Show("No tweaks selected!", "GameOptimizerPro", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    # Tweaks already in effect are left alone. Running them again re-deleted every folder view,
    # restarted Explorer and asked for a restore point for apps that were long gone (after
    # "Verify" every active tweak is ticked). One-time actions (cleanups) always run.
    $already = @($selected | Where-Object { $Script:OneTimeNames -notcontains $_.Name -and (Test-TweakActive $_.Name) })
    $selected = @($selected | Where-Object { $already -notcontains $_ })
    if ($selected.Count -eq 0) {
        [System.Windows.MessageBox]::Show("All $($already.Count) ticked tweak(s) are already active -- nothing to do.", "GameOptimizerPro", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
        return
    }

    # DNS conflict check  --  warn if both Cloudflare AND Google DNS are selected
    $dnsCloudflare = $selected | Where-Object { $_.Name -like "*Cloudflare*" }
    $dnsGoogle     = $selected | Where-Object { $_.Name -like "*Google*" }
    if ($dnsCloudflare -and $dnsGoogle) {
        $dnsWarn = [System.Windows.MessageBox]::Show(
            "DNS Conflict detected!`n`nYou selected both:`n  - Set DNS to Cloudflare (1.1.1.1)`n  - Set DNS to Google (8.8.8.8)`n`nOnly the LAST one applied will be active.`nRecommendation: select only one DNS tweak.`n`nContinue anyway?",
            "GameOptimizerPro -- DNS Conflict",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Warning
        )
        if ($dnsWarn -ne [System.Windows.MessageBoxResult]::Yes) { return }
    }

    # Power conflict check -- "Ultimate Performance Plan" sets the display timeout
    # to "never" on its own plan, while "Set Display Sleep = 15 Minutes" writes 15
    # min to EVERY scheme and runs later, so it silently wins.
    $ultPlan  = $selected | Where-Object { $_.Name -eq "Ultimate Performance Plan" }
    $dispSlp  = $selected | Where-Object { $_.Name -eq "Set Display Sleep = 15 Minutes" }
    if ($ultPlan -and $dispSlp) {
        $pwrWarn = [System.Windows.MessageBox]::Show(
            "Power conflict detected!`n`nYou selected both:`n  - Ultimate Performance Plan (keeps the display ON permanently)`n  - Set Display Sleep = 15 Minutes`n`nThe display-sleep tweak is applied last and wins, so your screen WILL still turn off after 15 minutes.`nRecommendation: select only one of the two.`n`nContinue anyway?",
            "GameOptimizerPro -- Power Conflict",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Warning
        )
        if ($pwrWarn -ne [System.Windows.MessageBoxResult]::Yes) { return }
    }

    # A restore point only when apps are removed: System Restore is one way to bring them back
    # (the Microsoft Store the other). Everything else has its own revert plus the registry
    # backup, and Checkpoint-Computer costs 10-60 s.
    $removals = @($selected | Where-Object { $Script:AppRemovals -contains $_.Name })
    $protection = if ($removals.Count) { Test-SystemProtection } else { $null }
    $safetyNote = if ($removals.Count) {
        "WARNING -- this removes apps / Windows components:`n  - " + (@($removals | ForEach-Object { $_.Name }) -join "`n  - ") +
        "`nThey come back through the Microsoft Store (OneDrive: its installer) or System Restore. " +
        $(if ($protection) { "A restore point and a registry backup are created first." } else { "System Protection is OFF for $env:SystemDrive -- you are asked about the restore point next." })
    } else { "A registry backup is saved first." }
    # what "Remove Other Bloatware" takes on THIS PC
    $bloatNote = ""
    if ($selected | Where-Object { $_.Name -eq "Remove Other Bloatware" }) {
        $found = @(try { Get-BloatApps | ForEach-Object { $_.Name -replace '^Microsoft\.', '' } | Select-Object -Unique } catch { })
        $bloatNote = "`n`n'Remove Other Bloatware' removes on this PC: " + $(if ($found.Count) { (@($found | Select-Object -First 14) -join ', ') + $(if ($found.Count -gt 14) { " and $($found.Count - 14) more" }) } else { "nothing (none of those apps is installed)" })
    }
    $skipNote = if ($already.Count) { "`n`n$($already.Count) ticked tweak(s) are already active and are left as they are." } else { "" }
    $confirm = [System.Windows.MessageBox]::Show(
        "Apply $($selected.Count) tweak(s)?`n`n$safetyNote$bloatNote$skipNote",
        "GameOptimizerPro -- Confirm",
        [System.Windows.MessageBoxButton]::YesNo,
        $(if ($removals.Count) { [System.Windows.MessageBoxImage]::Warning } else { [System.Windows.MessageBoxImage]::Question })
    )
    if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

    # System Protection off = no restore point possible. Until 1.2.5 that only went to the log
    # and the apps were removed anyway, while the dashboard said "on".
    $makePoint = [bool]$removals.Count
    if ($removals.Count -and -not $protection) {
        $sp = [System.Windows.MessageBox]::Show(
            "System Protection is off for $env:SystemDrive, so Windows can't create a restore point.`n`nYes = turn System Protection on for $env:SystemDrive (Windows uses a few percent of the drive for it) and create the restore point`nNo = remove the apps without a restore point (they come back through the Microsoft Store)`nCancel = stop, nothing is changed",
            "GameOptimizerPro -- No restore point possible",
            [System.Windows.MessageBoxButton]::YesNoCancel,
            [System.Windows.MessageBoxImage]::Warning)
        if ($sp -eq [System.Windows.MessageBoxResult]::Cancel) { return }
        if ($sp -eq [System.Windows.MessageBoxResult]::Yes) {
            try { Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop; Write-Log "System Protection turned on for $env:SystemDrive" }
            catch { Write-Log "System Protection could not be turned on: $_" }
        } else { $makePoint = $false; Write-Log "No restore point: System Protection is off and the user chose to go on without" }
    }

    Set-Busy $true
    try {
    if ($makePoint) {
        Set-Status "Creating restore point..."
        try {
            New-RestorePoint "GameOptimizerPro Backup"
            Write-Log "Restore point created (app removals selected)"
            Set-Status "Restore point created. Backing up registry..."
        } catch {
            Write-Log "Restore point could not be created: $_"
            $rp = [System.Windows.MessageBox]::Show(
                "The restore point could not be created:`n$($_.Exception.Message)`n`nRemove the apps anyway? They come back through the Microsoft Store (OneDrive: its installer).`n`nNo = stop, nothing is changed.",
                "GameOptimizerPro -- Restore point failed",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Warning)
            if ($rp -ne [System.Windows.MessageBoxResult]::Yes) { Set-Status "Stopped -- nothing was changed."; return }
            Set-Status "Backing up registry..."
        }
    } else {
        Write-Log "No restore point for this Apply (no app removals, or declined)"
        Set-Status "Backing up registry..."
    }

    # Registry backup (independent of restore-point success -- always runs)
    $Script:LastBackupDir = Backup-Registry -Label "PreApply"
    Set-Status "Registry backup saved. Applying tweaks..."

    # Apply tweaks
    $done  = 0
    $total = $selected.Count
    $failedNames = @()
    foreach ($tweak in $selected) {
        Set-Status "Applying: $($tweak.Name) ($done/$total)..."
        try {
            & $tweak.Action
            Write-Log "OK: $($tweak.Name)"
        } catch {
            Write-Log "FAILED: $($tweak.Name) -- $_"
            $failedNames += $tweak.Name
        }
        $done++
    }

    # Refresh ALL status dots, not just the applied ones: a tweak can change others
    # (the Ultimate Performance plan switches the active scheme, so every power
    # tweak's status changes with it).
    Update-AllDots "Checking the result:"
    # External tools (reg, bcdedit, powercfg ...) refuse silently and Windows policies can
    # override a value -- so trust the status check, not just the absence of an error.
    # Tweaks that only take effect after a restart are not counted here.
    $notActive = @($selected | Where-Object { $failedNames -notcontains $_.Name -and $Script:RestartTweaks -notcontains $_.Name -and $Script:TweakState[$_.Name] -eq 'inactive' } | ForEach-Object { $_.Name })
    foreach ($nm in $notActive) { Write-Log "NOT ACTIVE after Apply: $nm (Windows reports it as not in effect)" }
    $okCount = $total - $failedNames.Count - $notActive.Count
    Set-Status "Done! $okCount of $total tweaks applied$(if ($failedNames.Count + $notActive.Count) { " -- $($failedNames.Count + $notActive.Count) not in effect, see the log" })$(if ($already.Count) { " ($($already.Count) were already active)" }). Log: $LogFile"
    $listOf = { param($names) $s = @($names | Select-Object -First 8) -join "`n  - "; if (@($names).Count -gt 8) { $s += "`n  ... and $(@($names).Count - 8) more" }; "  - $s" }
    $problems = ""
    if ($failedNames.Count) { $problems += "`n`nFailed (details in the log):`n" + (& $listOf $failedNames) }
    if ($notActive.Count)   { $problems += "`n`nApplied, but Windows reports them as not in effect (often a policy, antivirus or a driver without that option -- see the log):`n" + (& $listOf $notActive) }

    # Record what THIS app applied (in effect now; restart tweaks count once applied) -- the
    # drift check at the next start and "Revert all" work from this list
    $applied = @($selected | Where-Object { $Script:OneTimeNames -notcontains $_.Name -and $failedNames -notcontains $_.Name -and $notActive -notcontains $_.Name } | ForEach-Object { $_.Name })
    Save-Baseline -Add $applied

    # A restart / sign-out only matters for some tweaks -- no question after a cleanup
    $needRestart = @($selected | Where-Object { $failedNames -notcontains $_.Name -and ($Script:RestartTweaks -contains $_.Name -or $Script:SignOutTweaks -contains $_.Name) } | ForEach-Object { $_.Name })
    [System.Windows.MessageBox]::Show(
        "$okCount of $total tweaks applied.$(if ($already.Count) { " $($already.Count) ticked tweak(s) were already active." })$problems$(if ($needRestart.Count) { "`n`nSome of them take effect after a restart (or signing out and in)." })`nLog saved to:`n$LogFile`n`nRegistry backup (.reg files) saved to:`n$Script:LastBackupDir",
        "GameOptimizerPro -- Done",
        [System.Windows.MessageBoxButton]::OK,
        $(if ($problems) { [System.Windows.MessageBoxImage]::Warning } else { [System.Windows.MessageBoxImage]::Information })
    )

    if ($needRestart.Count) {
        $restart = [System.Windows.MessageBox]::Show(
            "These take effect after a restart:`n" + (& $listOf $needRestart) + "`n`nRestart now?",
            "GameOptimizerPro -- Restart recommended",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question
        )
        if ($restart -eq [System.Windows.MessageBoxResult]::Yes) {
            Restart-Computer -Force
        }
    }
    } finally { Set-Busy $false }
})

# -----------------------------------------
# REVERT ALL BUTTON
# -----------------------------------------
$BtnRevertAll.Add_Click({
    if ($Script:Busy) { return }

    # Only what THIS app applied (the baseline): until 1.2.5 every one of the tweaks was set
    # back, also never applied ones -- light mode, location on, hibernation on, folder views
    # deleted, the power plans' timeouts rewritten.
    $catOf = @{}; foreach ($t in $AllTweaks) { $catOf[$t.Name] = $t.Category }
    $cands = @((Read-Baseline).Names | Where-Object { $RevertActions.ContainsKey($_) -and -not ($catOf[$_] -eq 'Windows 11' -and -not $IsWin11) })
    $appRemoved = @($cands | Where-Object { $Script:AppRemovals -contains $_ })

    # Step 1: Let user choose: System Restore or Quick Registry Reset
    $choice = [System.Windows.MessageBox]::Show(
        "REVERT ALL  --  Undo GameOptimizerPro Changes`n`n" +
        "Choose how to revert:`n`n" +
        "  YES  ->  System Restore`n" +
        "           - Only needed to bring back removed apps`n" +
        "             (they also come back through the Microsoft Store)`n" +
        "           - Point 'GameOptimizerPro Backup' (made before app removals)`n" +
        "           - Opens the Windows wizard, your PC reboots (~5-10 min)`n`n" +
        "  NO   ->  Quick Reset (Recommended)`n" +
        "           - The $($cands.Count) tweak(s) GameOptimizerPro applied on this PC go back`n" +
        "             to the Windows default; settings you made yourself stay`n" +
        "           - No reboot required`n" +
        "           - Removed apps (OneDrive, Xbox etc.) stay removed`n`n" +
        "  CANCEL  ->  Do nothing",
        "GameOptimizerPro  --  Revert All",
        [System.Windows.MessageBoxButton]::YesNoCancel,
        [System.Windows.MessageBoxImage]::Warning
    )

    if ($choice -eq [System.Windows.MessageBoxResult]::Cancel) { return }

    # Option A: Open System Restore wizard
    if ($choice -eq [System.Windows.MessageBoxResult]::Yes) {
        try {
            Start-Process "rstrui.exe"
        } catch {
            [System.Windows.MessageBox]::Show(
                "Could not open System Restore (rstrui.exe).`nRun it manually via: Start -> type 'rstrui'",
                "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            return
        }
        [System.Windows.MessageBox]::Show(
            "Windows System Restore is opening.`n`n" +
            "In the wizard, select the restore point:`n" +
            "  'GameOptimizerPro Backup'`n`n" +
            "Then follow the on-screen steps.`n" +
            "Your PC will restart automatically to complete the restore.",
            "System Restore  --  Instructions",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        )
        return
    }

    # Option B: Quick Registry Reset
    $list = (@($cands | Select-Object -First 12 | ForEach-Object { "  - $_" }) -join "`n") + $(if ($cands.Count -gt 12) { "`n  ... and $($cands.Count - 12) more" } else { '' })
    $confirm = [System.Windows.MessageBox]::Show(
        "Quick Registry Reset`n`n" +
        $(if ($cands.Count) { "These $($cands.Count) tweak(s) GameOptimizerPro applied go back to the Windows default:`n$list`n`n" }
          else { "GameOptimizerPro has no record of tweaks it applied on this PC (the record starts with the first Apply). To set single tweaks back, tick them and use 'Revert selected'.`n`n" }) +
        "Leftovers of tweaks removed in earlier versions are cleaned up as well.`n" +
        $(if ($appRemoved.Count) { "Removed apps don't come back this way -- reinstall them from the Microsoft Store (OneDrive: its installer) or use System Restore.`n" }) +
        "`nA registry backup is saved first. Continue?",
        "GameOptimizerPro  --  Confirm Quick Reset",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )
    if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

    Set-Busy $true
    try {
    # No restore point here: reverting removes nothing, and every value it touches is in
    # the registry backup below.
    Set-Status "Backing up registry..."
    $Script:LastBackupDir = Backup-Registry -Label "PreRevert"
    Set-Status "Registry backup saved. Starting revert..."

    $done = 0; $failedNames = @()
    foreach ($tweakName in $cands) {
        Set-Status "Reverting [$done/$($cands.Count)]: $tweakName..."
        try { & $RevertActions[$tweakName]; Write-Log "Revert OK: $tweakName" }
        catch { Write-Log "Revert FAILED: $tweakName -- $_"; $failedNames += $tweakName }
        $done++
    }
    $retired = 0
    try { $retired = Remove-RetiredTweakValues } catch { Write-Log "Retired tweak values could not be removed: $_" }

    # The record keeps only what could not be set back. Keeping the rest would make the drift
    # check on the NEXT launch offer to re-apply exactly what the user just undid.
    try {
        if ($failedNames.Count) { $null = Write-Baseline $failedNames }
        elseif (Test-Path $Script:BaselineFile) { Remove-Item $Script:BaselineFile -Force -ErrorAction Stop }
        Write-Log "Baseline updated after Revert All ($($failedNames.Count) left)"
    } catch { Write-Log "Baseline could not be cleared: $_" }

    # Refresh the status dots so they reflect the reverted state (Apply does the same)
    Update-AllDots "Checking the result:"

    $ok = $cands.Count - $failedNames.Count
    Set-Status "Revert complete! $ok of $($cands.Count) tweaks set back$(if ($retired) { ", $retired leftover value(s) removed" }). Log: $LogFile"
    Write-Log "Revert All complete: $ok set back, $($failedNames.Count) failed, $retired leftover value(s) of retired tweaks removed"

    [System.Windows.MessageBox]::Show(
        "Quick Registry Reset complete!`n`n" +
        "$ok of $($cands.Count) tweak(s) set back to the Windows default." +
        $(if ($retired) { "`n$retired leftover value(s) of tweaks removed in earlier versions cleaned up." } else { "" }) +
        $(if ($failedNames.Count) { "`n`nFailed (see the log):`n  - " + ($failedNames -join "`n  - ") } else { "" }) +
        $(if ($appRemoved.Count) { "`n`nRemoved apps stay removed: " + ($appRemoved -join ', ') + " -- reinstall them from the Microsoft Store (OneDrive: its installer) or use System Restore." } else { "" }) +
        "`n`nSome changes require a restart to take effect.`nLog: $LogFile`n`nPre-revert registry backup (.reg files):`n$Script:LastBackupDir",
        "GameOptimizerPro  --  Revert Complete",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Information
    )
    } finally { Set-Busy $false }
})

# Revert only the ticked tweaks -- e.g. Bing search back after a preset, without "Revert all"
$BtnRevertSel.Add_Click({
    if ($Script:Busy) { return }
    $selected = @($AllTweaks | Where-Object { $CheckBoxMap[$_.Name].IsEnabled -and $CheckBoxMap[$_.Name].IsChecked -eq $true })
    if (-not $selected.Count) { Set-Status "Tick the tweaks you want to set back first, then click 'Revert selected'."; return }
    $names = @($selected | ForEach-Object { $_.Name })
    $list = (@($names | Select-Object -First 15 | ForEach-Object { "  - $_" }) -join "`n") + $(if ($names.Count -gt 15) { "`n  ... and $($names.Count - 15) more" } else { '' })
    $removals = @($names | Where-Object { $Script:AppRemovals -contains $_ })
    $oneTime  = @($names | Where-Object { $Script:OneTimeNames -contains $_ })
    $r = [System.Windows.MessageBox]::Show(
        "Set $($names.Count) ticked tweak(s) back to the Windows default?`n`n$list" +
        $(if ($removals.Count) { "`n`nRemoved apps don't come back this way -- reinstall them from the Microsoft Store (OneDrive: its installer) or use System Restore:`n  - " + ($removals -join "`n  - ") } else { '' }) +
        $(if ($oneTime.Count) { "`n`nOne-time actions (cleanups) have nothing to undo:`n  - " + ($oneTime -join "`n  - ") } else { '' }) +
        "`n`nA registry backup is saved first.",
        "GameOptimizerPro  --  Revert selected",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question)
    if ($r -ne [System.Windows.MessageBoxResult]::Yes) { return }

    Set-Busy $true
    try {
        Set-Status "Backing up registry..."
        $Script:LastBackupDir = Backup-Registry -Label "PreRevertSelected"
        $done = 0; $failed = @()
        foreach ($t in $selected) {
            if (-not $RevertActions.ContainsKey($t.Name)) { continue }
            Set-Status "Reverting: $($t.Name) ..."
            try { & $RevertActions[$t.Name]; $done++; Write-Log "Revert OK: $($t.Name)" }
            catch { $failed += $t.Name; Write-Log "Revert FAILED: $($t.Name) -- $_" }
            if ($Script:TweakDots.ContainsKey($t.Name)) { Update-TweakDot $Script:TweakDots[$t.Name] $t.Name | Out-Null }
            $CheckBoxMap[$t.Name].IsChecked = $false
        }
        Update-Counts
        # the next start must not offer them again as "reset by a Windows update"
        Remove-FromBaseline $names
        Set-Status "$done of $($names.Count) tweak(s) set back to the Windows default$(if ($failed.Count) { " -- $($failed.Count) failed, see the log" }). Log: $LogFile"
        if ($failed.Count) {
            [System.Windows.MessageBox]::Show("These could not be set back (details in the log):`n`n  - " + ($failed -join "`n  - ") + "`n`nLog: $LogFile",
                "GameOptimizerPro  --  Revert selected", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        }
    } finally { Set-Busy $false }
})

$BtnLang.Add_Click({
    # The interface stays permanently English. This toggle switches the language
    # of the tweak descriptions and the BIOS Guide explanations (DE/EN).
    $LangState.Current  = if ($LangState.Current -eq "EN") { "DE" } else { "EN" }
    Update-LangButton
    Set-DescLanguage
    Render-BiosPage
    if ($SearchBox.Text) { Apply-TweakFilter }
    $StatusText.Text = if ($LangState.Current -eq "DE") { "Descriptions now in German. The interface stays English." } else { "Descriptions now in English." }
})

# -----------------------------------------
# STARTUP MANAGER
# -----------------------------------------
# -----------------------------------------
# STARTUP DELAY DATA (Windows Event Log)
# Event 101 of Diagnostics-Performance: "this application took longer than usual to start" --
# fields Name, Path, TotalTime, DegradationTime. Windows only logs programs that slowed the
# boot down, so most autostarts have no entry. Until 1.2.5 this read event 902 with field
# names that don't exist there, and the column never showed anything.
# Returns hashtable: { "process.exe" -> slowest start time in ms }
# -----------------------------------------
function Get-StartupDelays {
    $delays = @{}
    try {
        $events = Get-WinEvent -FilterHashtable @{ LogName = "Microsoft-Windows-Diagnostics-Performance/Operational"; Id = 101 } -MaxEvents 300 -ErrorAction Stop
        foreach ($evt in $events) {
            try {
                $data = ([xml]$evt.ToXml()).Event.EventData.Data
                $name = "$(($data | Where-Object { $_.Name -eq 'Name' }).'#text')"
                $path = "$(($data | Where-Object { $_.Name -eq 'Path' }).'#text')"
                $ms   = [int]"$(($data | Where-Object { $_.Name -eq 'TotalTime' }).'#text')"
                $exe  = $(if ($path) { [System.IO.Path]::GetFileName($path) } else { $name }).ToLower()
                if ($exe -and $ms -gt 0 -and (-not $delays.ContainsKey($exe) -or $delays[$exe] -lt $ms)) { $delays[$exe] = $ms }
            } catch { }
        }
    } catch { }
    return $delays
}

function Get-DelayColor($ms) {
    if     ($ms -gt 3000) { return [Windows.Media.Color]::FromRgb(220, 50,  50)  }  # rot > 3s
    elseif ($ms -gt 1000) { return [Windows.Media.Color]::FromRgb(255, 160, 0)   }  # orange 1-3s
    elseif ($ms -gt 0)    { return [Windows.Media.Color]::FromRgb(0,   200, 80)  }  # gruen < 1s
    else                  { return [Windows.Media.Color]::FromRgb(100, 100, 100) }  # grau: keine Daten
}

function Get-DelayLabel($ms) {
    if     ($ms -gt 3000) { return "Slow: $('{0:0.0}' -f ($ms/1000))s" }
    elseif ($ms -gt 1000) { return "Med:  $('{0:0.0}' -f ($ms/1000))s" }
    elseif ($ms -gt 0)    { return "Fast: $('{0:0.0}' -f ($ms/1000))s" }
    else                  { return "No data" }
}

function Get-StartupEntries {
    $entries = [System.Collections.Generic.List[PSCustomObject]]::new()
    $sources = @(
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
           Loc  = "HKCU\Run"
           App  = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
           Loc  = "HKLM\Run"
           App  = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" },
        @{ Path = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
           Loc  = "HKLM\Run32"
           App  = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32" }
    )
    foreach ($src in $sources) {
        if (-not (Test-Path $src.Path)) { continue }
        try {
            Get-ItemProperty $src.Path | ForEach-Object {
                $_.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" } | ForEach-Object {
                    $name    = $_.Name
                    $cmd     = if ($_.Value -and $_.Value.Length -gt 65) { $_.Value.Substring(0,62)+"..." } else { $_.Value }
                    $enabled = $true
                    if (Test-Path $src.App) {
                        # first byte odd = switched off (03 by the user, 07 / 0B by others), even = on
                        $av = Get-ItemProperty $src.App -Name $name -ErrorAction SilentlyContinue
                        if ($av -and $av.$name -and ($av.$name[0] -band 1)) { $enabled = $false }
                    }
                    $entries.Add([PSCustomObject]@{
                        Name        = $name
                        Command     = $cmd
                        FullCmd     = $_.Value
                        Location    = $src.Loc
                        Status      = if ($enabled) { "Enabled" } else { "Disabled" }
                        RegPath     = $src.Path
                        ApprovedPath = $src.App
                    })
                }
            }
        } catch { }
    }

    # Physical startup FOLDERS (.lnk shortcuts) -- e.g. Discord, Spotify.
    # Many apps auto-start from here instead of the Run keys. Disable/enable
    # uses the same StartupApproved binary-flag mechanism as Task Manager,
    # under the StartupFolder subkey, so the existing handlers work unchanged.
    $folderSources = @(
        @{ Path = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
           Loc  = "Startup Folder"
           App  = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder" },
        @{ Path = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"
           Loc  = "Startup Folder (All)"
           App  = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder" }
    )
    $wsh = $null
    foreach ($fsrc in $folderSources) {
        if (-not (Test-Path $fsrc.Path)) { continue }
        try {
            Get-ChildItem -Path $fsrc.Path -Filter *.lnk -Force -ErrorAction SilentlyContinue | ForEach-Object {
                $name   = $_.Name
                $target = $_.FullName
                try {
                    if (-not $wsh) { $wsh = New-Object -ComObject WScript.Shell }
                    $tp = $wsh.CreateShortcut($_.FullName).TargetPath
                    if ($tp) { $target = $tp }
                } catch { }
                $cmd = if ($target.Length -gt 65) { $target.Substring(0,62)+"..." } else { $target }
                $enabled = $true
                if (Test-Path $fsrc.App) {
                    $av = Get-ItemProperty $fsrc.App -Name $name -ErrorAction SilentlyContinue
                    if ($av -and $av.$name -and ($av.$name[0] -band 1)) { $enabled = $false }
                }
                $entries.Add([PSCustomObject]@{
                    Name         = $name
                    Command      = $cmd
                    FullCmd      = $target
                    Location     = $fsrc.Loc
                    Status       = if ($enabled) { "Enabled" } else { "Disabled" }
                    RegPath      = $fsrc.Path
                    ApprovedPath = $fsrc.App
                })
            }
        } catch { }
    }

    # Startup tasks of Store apps (Spotify, WhatsApp, Teams ...) -- Task Manager lists them, the
    # Run keys don't. State 2 = on, 0 / 1 = off; 3 / 4 = set by a policy (left alone).
    $sad = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData"
    foreach ($pkg in @(Get-ChildItem $sad -ErrorAction SilentlyContinue)) {
        foreach ($tk in @(Get-ChildItem $pkg.PSPath -ErrorAction SilentlyContinue)) {
            $state = Get-RegVal $tk.PSPath 'State'
            if ($null -eq $state -or $state -eq 3 -or $state -eq 4) { continue }
            $entries.Add([PSCustomObject]@{
                Name         = ($pkg.PSChildName -replace '_[^_]+$', '')
                Command      = "Store app startup task ($($tk.PSChildName))"
                FullCmd      = $pkg.PSChildName
                Location     = "Store app"
                Status       = if ($state -eq 2) { "Enabled" } else { "Disabled" }
                RegPath      = $tk.PSPath
                ApprovedPath = $tk.PSPath
                Kind         = 'StoreTask'
            })
        }
    }
    return $entries
}

$BtnStartup.Add_Click({
    # Build sub-window XAML
    [xml]$swXml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="GameOptimizerPro  --  Startup Manager"
        Height="540" Width="920"
        WindowStartupLocation="CenterScreen"
        Background="#0b0e13" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" FontFamily="Segoe UI" TextOptions.TextFormattingMode="Display">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Foreground" Value="#ffffff"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}" CornerRadius="9" Padding="12,0">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Bd" Property="Opacity" Value="0.86"/></Trigger>
                            <Trigger Property="IsPressed" Value="True"><Setter TargetName="Bd" Property="Opacity" Value="0.7"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="CheckBox">
                        <Grid Width="18" Height="18" Background="Transparent" HorizontalAlignment="Left">
                            <Border x:Name="Bx" CornerRadius="4" BorderThickness="1.5" BorderBrush="#4f5a69" Background="Transparent"/>
                            <TextBlock x:Name="Mk" Text="&#xE73E;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="11" Foreground="#ffffff"
                                       HorizontalAlignment="Center" VerticalAlignment="Center" Visibility="Collapsed"/>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Bx" Property="BorderBrush" Value="#7d8896"/></Trigger>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="Bx" Property="Background" Value="#3b82f6"/>
                                <Setter TargetName="Bx" Property="BorderBrush" Value="#3b82f6"/>
                                <Setter TargetName="Mk" Property="Visibility" Value="Visible"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="ToolTip">
            <Setter Property="Background" Value="#1b212b"/>
            <Setter Property="Foreground" Value="#e6edf3"/>
            <Setter Property="BorderBrush" Value="#313b4a"/>
        </Style>
        <Style TargetType="ScrollBar">
            <Setter Property="Width" Value="10"/>
            <Setter Property="MinWidth" Value="10"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ScrollBar">
                        <Grid Background="Transparent">
                            <Track x:Name="PART_Track" IsDirectionReversed="True">
                                <Track.Thumb>
                                    <Thumb>
                                        <Thumb.Template>
                                            <ControlTemplate TargetType="Thumb"><Border CornerRadius="4" Background="#313b4a" Margin="2,0,2,0"/></ControlTemplate>
                                        </Thumb.Template>
                                    </Thumb>
                                </Track.Thumb>
                            </Track>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Grid Margin="14">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <TextBlock Grid.Row="0" Name="SwTitle" Text="Startup Manager" FontSize="18" FontWeight="Bold"
                   Foreground="#e6edf3" Margin="0,0,0,4"/>
        <Border Grid.Row="1" Background="#151a22" CornerRadius="6" Padding="8,5" Margin="0,0,0,10">
            <StackPanel Orientation="Horizontal">
                <TextBlock Name="SwColSelect" Text="Select" Foreground="#7d8896" FontSize="11" Width="38"/>
                <TextBlock Name="SwColName" Text="Name" Foreground="#7d8896" FontSize="11" FontWeight="Bold" Width="165"/>
                <TextBlock Name="SwColCommand" Text="Command" Foreground="#7d8896" FontSize="11" FontWeight="Bold" Width="280"/>
                <TextBlock Name="SwColLocation" Text="Location" Foreground="#7d8896" FontSize="11" FontWeight="Bold" Width="90"/>
                <TextBlock Name="SwColStatus" Text="Status" Foreground="#7d8896" FontSize="11" FontWeight="Bold" Width="75"/>
                <TextBlock Name="SwColDelay" Text="Boot Delay" Foreground="#7d8896" FontSize="11" FontWeight="Bold" Width="110"/>
            </StackPanel>
        </Border>
        <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto">
            <StackPanel Name="SwList"/>
        </ScrollViewer>
        <TextBlock Grid.Row="3" Name="SwStatus" Text="" Foreground="#b3bdcb"
                   FontSize="11" FontFamily="Consolas" Margin="0,8,0,4"/>
        <WrapPanel Grid.Row="4" HorizontalAlignment="Center">
            <Button Name="SwBtnDisable" Content="Disable Selected"  Width="155" Height="32"
                    Margin="6,0" Background="#e53935" Foreground="White" FontWeight="Bold" BorderThickness="0" Cursor="Hand"/>
            <Button Name="SwBtnEnable"  Content="Enable Selected"   Width="155" Height="32"
                    Margin="6,0" Background="#16a34a" Foreground="White" FontWeight="Bold" BorderThickness="0" Cursor="Hand"/>
            <Button Name="SwBtnRefresh" Content="Refresh"           Width="100" Height="32"
                    Margin="6,0" Background="#1b212b" Foreground="White" FontWeight="Bold" BorderThickness="0" Cursor="Hand"/>
            <Button Name="SwBtnClose"   Content="Close"             Width="100" Height="32"
                    Margin="6,0" Background="#313b4a"    Foreground="White" FontWeight="Bold" BorderThickness="0" Cursor="Hand"/>
        </WrapPanel>
    </Grid>
</Window>
"@
    $swReader = New-Object System.Xml.XmlNodeReader $swXml
    $sw       = [Windows.Markup.XamlReader]::Load($swReader)

    $swList      = $sw.FindName("SwList")
    $swStatus    = $sw.FindName("SwStatus")
    $swDisable   = $sw.FindName("SwBtnDisable")
    $swEnable    = $sw.FindName("SwBtnEnable")
    $swRefresh   = $sw.FindName("SwBtnRefresh")
    $swClose     = $sw.FindName("SwBtnClose")

    # --- Localize Startup Manager labels to current language ---
    $sw.Title = "GameOptimizerPro  --  " + (Get-UIString "sw_title")
    ($sw.FindName("SwTitle")).Text       = Get-UIString "sw_title"
    ($sw.FindName("SwColSelect")).Text   = Get-UIString "sw_col_select"
    ($sw.FindName("SwColName")).Text     = Get-UIString "sw_col_name"
    ($sw.FindName("SwColCommand")).Text  = Get-UIString "sw_col_command"
    ($sw.FindName("SwColLocation")).Text = Get-UIString "sw_col_location"
    ($sw.FindName("SwColStatus")).Text   = Get-UIString "sw_col_status"
    ($sw.FindName("SwColDelay")).Text    = Get-UIString "sw_col_delay"
    $swDisable.Content = Get-UIString "sw_btn_disable"
    $swEnable.Content  = Get-UIString "sw_btn_enable"
    $swRefresh.Content = Get-UIString "sw_btn_refresh"
    $swClose.Content   = Get-UIString "sw_btn_close"

    $swCbMap     = @{}   # name -> @{Cb=checkbox; Item=psobject}

    function Build-StartupRows {
        $swList.Children.Clear()
        $swCbMap.Clear()
        $swStatus.Text = Get-UIString "sw_loading"
        $allEntries = Get-StartupEntries
        $bootDelays  = Get-StartupDelays
        foreach ($entry in $allEntries) {
            $row             = New-Object Windows.Controls.StackPanel
            $row.Orientation = "Horizontal"
            $row.Margin      = New-Object Windows.Thickness(0,2,0,2)

            $cb              = New-Object Windows.Controls.CheckBox
            $cb.Width        = 38
            $cb.VerticalAlignment = "Center"

            $tbName          = New-Object Windows.Controls.TextBlock
            $tbName.Text     = $entry.Name
            $tbName.Width    = 165
            $tbName.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(220,220,220))
            $tbName.VerticalAlignment = "Center"
            $tbName.ToolTip  = $entry.FullCmd

            $tbCmd           = New-Object Windows.Controls.TextBlock
            $tbCmd.Text      = $entry.Command
            $tbCmd.Width     = 280
            $tbCmd.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(150,150,150))
            $tbCmd.VerticalAlignment = "Center"
            $tbCmd.ToolTip   = $entry.FullCmd

            $tbLoc           = New-Object Windows.Controls.TextBlock
            $tbLoc.Text      = $entry.Location
            $tbLoc.Width     = 90
            $tbLoc.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(170,170,170))
            $tbLoc.VerticalAlignment = "Center"

            $tbStatus        = New-Object Windows.Controls.TextBlock
            $tbStatus.Text   = if ($entry.Status -eq "Enabled") { Get-UIString "word_enabled" } else { Get-UIString "word_disabled" }
            $tbStatus.Width  = 75
            $tbStatus.FontWeight = "SemiBold"
            $tbStatus.VerticalAlignment = "Center"
            if ($entry.Status -eq "Enabled") {
                $tbStatus.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(0,200,100))
            } else {
                $tbStatus.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(220,80,80))
            }

            # Boot delay column
            # Derive the executable the boot log reports. Split('"')[0] was EMPTY for
            # quoted paths ("C:\...\app.exe" -x) and kept the arguments for unquoted ones
            # (C:\...\app.exe --flag), so almost no entry ever matched its delay data.
            $exeName = ""
            try {
                $fc = ([string]$entry.FullCmd).Trim()
                if ($fc.StartsWith('"')) { $exePath = $fc.Split('"')[1] }
                else {
                    $ix = $fc.ToLower().IndexOf(".exe")
                    $exePath = if ($ix -ge 0) { $fc.Substring(0, $ix + 4) } else { $fc }
                }
                $exeName = [System.IO.Path]::GetFileName($exePath.Trim()).ToLower()
            } catch { $exeName = "" }
            if ($exeName -eq "") { $exeName = $entry.Name.ToLower() + ".exe" }
            $delayMs  = if ($bootDelays.ContainsKey($exeName)) { $bootDelays[$exeName] } else { 0 }

            $tbDelay  = New-Object Windows.Controls.TextBlock
            $tbDelay.Width  = 110
            $tbDelay.Text   = if ($entry.Status -eq "Disabled") { Get-UIString "word_disabled" } else { Get-DelayLabel $delayMs }
            $tbDelay.FontSize    = 11
            $tbDelay.FontWeight  = "SemiBold"
            $tbDelay.VerticalAlignment = "Center"
            $tbDelay.Foreground  = if ($entry.Status -eq "Disabled") {
                New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(100,100,100))
            } else {
                New-Object Windows.Media.SolidColorBrush (Get-DelayColor $delayMs)
            }
            $tbDelay.ToolTip = if ($delayMs -gt 0) {
                "Slowest measured start: $delayMs ms`nSource: Windows boot performance log (event 101)"
            } else {
                "No delay logged for this program.`nWindows only logs programs that slowed the boot down."
            }

            $row.Children.Add($cb)       | Out-Null
            $row.Children.Add($tbName)   | Out-Null
            $row.Children.Add($tbCmd)    | Out-Null
            $row.Children.Add($tbLoc)    | Out-Null
            $row.Children.Add($tbStatus) | Out-Null
            $row.Children.Add($tbDelay)  | Out-Null
            $swList.Children.Add($row)   | Out-Null

            # Key by location + name: the same app often appears in two places (HKCU\Run
            # and HKLM\Run, or both startup folders). Keyed by name alone, the second row
            # overwrote the first and ticking the first one silently did nothing.
            $swCbMap["$($entry.Location)|$($entry.Name)"] = @{ Cb = $cb; Item = $entry; StatusTb = $tbStatus }
        }
        $swStatus.Text = "$($allEntries.Count) " + (Get-UIString "sw_legend")
    }

    Build-StartupRows

    # Switch one entry: Store app startup tasks through their State value (like Task Manager),
    # everything else through StartupApproved (first byte 3 = off, 2 = on). Only real successes count.
    $setStartup = {
        param($item, [bool]$On)
        if ($item.Kind -eq 'StoreTask') {
            Set-ItemProperty -Path $item.RegPath -Name 'State' -Value $(if ($On) { 2 } else { 1 }) -Type DWord -ErrorAction Stop
        } else {
            if (-not (Test-Path $item.ApprovedPath)) { New-Item -Path $item.ApprovedPath -Force -ErrorAction Stop | Out-Null }
            $bytes = [byte[]]($(if ($On) { 2 } else { 3 }), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
            Set-ItemProperty -Path $item.ApprovedPath -Name $item.Name -Value $bytes -Type Binary -ErrorAction Stop
        }
    }
    $swDisable.Add_Click({
        $sel = $swCbMap.Values | Where-Object { $_.Cb.IsChecked -eq $true }
        if (-not $sel) { $swStatus.Text = Get-UIString "sw_none_sel"; return }
        $count = 0; $fail = 0
        foreach ($entry in $sel) {
            try { & $setStartup $entry.Item $false; $count++; Write-Log "Startup Manager: Disabled '$($entry.Item.Name)'" }
            catch { $fail++; Write-Log "Startup Manager: could not disable '$($entry.Item.Name)' -- $_" }
        }
        Build-StartupRows   # status, colours and the boot-delay column straight away, not only after Refresh
        $swStatus.Text = "$count " + (Get-UIString "sw_disabled_msg") + $(if ($fail) { " -- $fail failed, see the log" } else { "" })
    })
    $swEnable.Add_Click({
        $sel = $swCbMap.Values | Where-Object { $_.Cb.IsChecked -eq $true }
        if (-not $sel) { $swStatus.Text = Get-UIString "sw_none_sel"; return }
        $count = 0; $fail = 0
        foreach ($entry in $sel) {
            try { & $setStartup $entry.Item $true; $count++; Write-Log "Startup Manager: Enabled '$($entry.Item.Name)'" }
            catch { $fail++; Write-Log "Startup Manager: could not enable '$($entry.Item.Name)' -- $_" }
        }
        Build-StartupRows
        $swStatus.Text = "$count " + (Get-UIString "sw_enabled_msg") + $(if ($fail) { " -- $fail failed, see the log" } else { "" })
    })
    $swRefresh.Add_Click({ Build-StartupRows })
    $swClose.Add_Click({  $sw.Close() })

    $sw.Owner = $Window; $sw.WindowStartupLocation = "CenterOwner"   # on the app's monitor, never behind it
    $sw.ShowDialog() | Out-Null
})

# =============================================================================
# SERVICES MANAGER
# =============================================================================
$BtnServices.Add_Click({

    # Curated list: Name -> @{ Desc; Safe; Category }
    $KnownServices = @{
        "DiagTrack"              = @{ Desc="Telemetry & Diagnostics -- sends usage data to Microsoft.";        Safe=$true;  Cat="Privacy" }
        "dmwappushservice"       = @{ Desc="WAP Push Message Routing -- part of the telemetry infrastructure.";     Safe=$true;  Cat="Privacy" }
        "SysMain"                = @{ Desc="Superfetch -- preloads apps into RAM. Unnecessary on SSDs.";            Safe=$true;  Cat="Performance" }
        "WSearch"                = @{ Desc="Windows Search -- indexes your drives. High CPU/disk load.";       Safe=$true;  Cat="Performance" }
        "RemoteRegistry"         = @{ Desc="Remote Registry -- allows remote access to the registry. Security risk."; Safe=$true;  Cat="Security" }
        "Fax"                    = @{ Desc="Fax service -- used by almost nobody.";                 Safe=$true;  Cat="Bloat" }
        "MapsBroker"             = @{ Desc="Maps Broker -- for the Windows Maps app. Rarely used.";             Safe=$true;  Cat="Bloat" }
        "RetailDemo"             = @{ Desc="Retail Demo Service -- only for store demo devices.";              Safe=$true;  Cat="Bloat" }
        "WerSvc"                 = @{ Desc="Windows Error Reporting -- sends crash reports to Microsoft."; Safe=$true;  Cat="Privacy" }
        "XblGameSave"            = @{ Desc="Xbox cloud saves -- Game Pass / Microsoft Store games need it. Unneeded if you only play on Steam, Epic & co."; Safe=$true;  Cat="Bloat" }
        "XblAuthManager"         = @{ Desc="Xbox sign-in -- Game Pass / Microsoft Store games and achievements need it. Unneeded for Steam, Epic & co."; Safe=$true;  Cat="Bloat" }
        "XboxNetApiSvc"          = @{ Desc="Xbox networking -- multiplayer in Game Pass / Microsoft Store games needs it.";            Safe=$true;  Cat="Bloat" }
        "xbgm"                   = @{ Desc="Xbox game monitoring -- used by Game Pass / Microsoft Store games.";                       Safe=$true;  Cat="Bloat" }
        "Spooler"                = @{ Desc="Print Spooler -- only needed if a printer is connected.";      Safe=$false; Cat="System" }
        "BITS"                   = @{ Desc="Background Intelligent Transfer -- the Windows Update downloader.";   Safe=$false; Cat="System" }
        "wuauserv"               = @{ Desc="Windows Update -- automatic updates. Be careful disabling this!"; Safe=$false; Cat="System" }
        "TabletInputService"     = @{ Desc="Touch keyboard, emoji panel (Win+.) and handwriting -- some input languages need it; on Windows 10 typing in the Start search can stop working without it."; Safe=$false; Cat="System" }
        "WMPNetworkSvc"          = @{ Desc="Windows Media Player Network -- media sharing on the network.";    Safe=$true;  Cat="Bloat" }
        "lfsvc"                  = @{ Desc="Geolocation Service -- location requests from apps.";            Safe=$true;  Cat="Privacy" }
        "SharedAccess"           = @{ Desc="Internet Connection Sharing -- only needed for ICS/hotspot."; Safe=$true;  Cat="Network" }
        "PhoneSvc"               = @{ Desc="Phone Service -- telephony features. Rarely needed.";         Safe=$true;  Cat="Bloat" }
        "wisvc"                  = @{ Desc="Windows Insider Service -- on an Insider build the Insider updates stop without it. Not needed on normal Windows."; Safe=$false; Cat="System" }
        "WpcMonSvc"              = @{ Desc="Parental Controls -- family safety monitoring.";                  Safe=$true;  Cat="Bloat" }
        "CscService"             = @{ Desc="Offline Files -- cached offline access. Usually unnecessary.";       Safe=$true;  Cat="Performance" }
        "TrkWks"                 = @{ Desc="Distributed Link Tracking -- tracks moved files.";     Safe=$true;  Cat="Performance" }
        "WdiServiceHost"         = @{ Desc="Diagnostic Service Host -- Windows diagnostic tools.";             Safe=$true;  Cat="Bloat" }
        "icssvc"                 = @{ Desc="Windows Mobile Hotspot -- mobile hotspot. Usually unnecessary.";     Safe=$true;  Cat="Bloat" }
        "vmicvss"                = @{ Desc="Hyper-V VSS -- only for Hyper-V VMs.";                          Safe=$true;  Cat="Bloat" }
        "HvHost"                 = @{ Desc="Hyper-V Host -- only for Hyper-V VMs.";                          Safe=$true;  Cat="Bloat" }
    }

    # Build XAML sub-window
    [xml]$svcXml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="GameOptimizerPro  --  Services Manager"
        Height="600" Width="980"
        WindowStartupLocation="CenterScreen"
        Background="#0b0e13" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" FontFamily="Segoe UI" TextOptions.TextFormattingMode="Display">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Foreground" Value="#ffffff"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}" CornerRadius="9" Padding="12,0">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Bd" Property="Opacity" Value="0.86"/></Trigger>
                            <Trigger Property="IsPressed" Value="True"><Setter TargetName="Bd" Property="Opacity" Value="0.7"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="CheckBox">
                        <Grid Width="18" Height="18" Background="Transparent" HorizontalAlignment="Left">
                            <Border x:Name="Bx" CornerRadius="4" BorderThickness="1.5" BorderBrush="#4f5a69" Background="Transparent"/>
                            <TextBlock x:Name="Mk" Text="&#xE73E;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="11" Foreground="#ffffff"
                                       HorizontalAlignment="Center" VerticalAlignment="Center" Visibility="Collapsed"/>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Bx" Property="BorderBrush" Value="#7d8896"/></Trigger>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="Bx" Property="Background" Value="#3b82f6"/>
                                <Setter TargetName="Bx" Property="BorderBrush" Value="#3b82f6"/>
                                <Setter TargetName="Mk" Property="Visibility" Value="Visible"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="ToolTip">
            <Setter Property="Background" Value="#1b212b"/>
            <Setter Property="Foreground" Value="#e6edf3"/>
            <Setter Property="BorderBrush" Value="#313b4a"/>
        </Style>
        <Style TargetType="ScrollBar">
            <Setter Property="Width" Value="10"/>
            <Setter Property="MinWidth" Value="10"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ScrollBar">
                        <Grid Background="Transparent">
                            <Track x:Name="PART_Track" IsDirectionReversed="True">
                                <Track.Thumb>
                                    <Thumb>
                                        <Thumb.Template>
                                            <ControlTemplate TargetType="Thumb"><Border CornerRadius="4" Background="#313b4a" Margin="2,0,2,0"/></ControlTemplate>
                                        </Thumb.Template>
                                    </Thumb>
                                </Track.Thumb>
                            </Track>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Grid Margin="14">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Title -->
        <StackPanel Grid.Row="0" Margin="0,0,0,10">
            <TextBlock Name="SvcTitle" Text="Services Manager" FontSize="18" FontWeight="Bold" Foreground="#e6edf3"/>
            <TextBlock Name="SvcSubtitle" Text="Deaktiviere unnötige Windows-Dienste für bessere Performance und Datenschutz."
                       FontSize="11" Foreground="#7d8896" Margin="0,2,0,0"/>
        </StackPanel>

        <!-- Legend -->
        <WrapPanel Grid.Row="1" Margin="0,0,0,10">
            <Border Background="#14281c" CornerRadius="4" Padding="8,4" Margin="0,0,6,0">
                <StackPanel Orientation="Horizontal">
                    <Ellipse Width="8" Height="8" Fill="#22c55e" VerticalAlignment="Center" Margin="0,0,5,0"/>
                    <TextBlock Name="SvcLegSafe" Text="Sicher deaktivierbar" FontSize="11" Foreground="#b3bdcb" VerticalAlignment="Center"/>
                </StackPanel>
            </Border>
            <Border Background="#2a161a" CornerRadius="4" Padding="8,4" Margin="0,0,6,0">
                <StackPanel Orientation="Horizontal">
                    <Ellipse Width="8" Height="8" Fill="#e53935" VerticalAlignment="Center" Margin="0,0,5,0"/>
                    <TextBlock Name="SvcLegCaution" Text="Vorsicht -- Systemdienst" FontSize="11" Foreground="#b3bdcb" VerticalAlignment="Center"/>
                </StackPanel>
            </Border>
            <Border Background="#1b212b" CornerRadius="4" Padding="8,4">
                <StackPanel Orientation="Horizontal">
                    <Ellipse Width="8" Height="8" Fill="#555" VerticalAlignment="Center" Margin="0,0,5,0"/>
                    <TextBlock Name="SvcLegDone" Text="Bereits deaktiviert" FontSize="11" Foreground="#b3bdcb" VerticalAlignment="Center"/>
                </StackPanel>
            </Border>
        </WrapPanel>

        <!-- Column headers -->
        <Border Grid.Row="2" Background="#151a22" CornerRadius="6" Padding="8,6" Margin="0,0,0,4">
            <StackPanel Orientation="Horizontal">
                <TextBlock Name="SvcColSel" Text="Sel"         Foreground="#7d8896" FontSize="11" Width="34"/>
                <TextBlock Name="SvcColName" Text="Service Name" Foreground="#7d8896" FontSize="11" FontWeight="Bold" Width="160"/>
                <TextBlock Name="SvcColDesc" Text="Beschreibung" Foreground="#7d8896" FontSize="11" FontWeight="Bold" Width="310"/>
                <TextBlock Name="SvcColStatus" Text="Status"      Foreground="#7d8896" FontSize="11" FontWeight="Bold" Width="85"/>
                <TextBlock Name="SvcColStart" Text="Starttyp"    Foreground="#7d8896" FontSize="11" FontWeight="Bold" Width="95"/>
                <TextBlock Name="SvcColCat" Text="Kategorie"   Foreground="#7d8896" FontSize="11" FontWeight="Bold" Width="90"/>
                <TextBlock Name="SvcColSafe" Text="Sicher"      Foreground="#7d8896" FontSize="11" FontWeight="Bold" Width="60"/>
            </StackPanel>
        </Border>

        <!-- Service list -->
        <ScrollViewer Grid.Row="3" VerticalScrollBarVisibility="Auto">
            <StackPanel Name="SvcList"/>
        </ScrollViewer>

        <!-- Status bar -->
        <TextBlock Grid.Row="4" Name="SvcStatus" Text="" Foreground="#b3bdcb"
                   FontSize="11" FontFamily="Consolas" Margin="0,8,0,4"/>

        <!-- Buttons -->
        <WrapPanel Grid.Row="5" HorizontalAlignment="Center">
            <Button Name="SvcBtnDisable" Content="Disable Selected"  Width="155" Height="32"
                    Margin="6,0" Background="#e53935" Foreground="White" FontWeight="Bold" BorderThickness="0" Cursor="Hand"/>
            <Button Name="SvcBtnEnable"  Content="Enable Selected"   Width="155" Height="32"
                    Margin="6,0" Background="#16a34a" Foreground="White" FontWeight="Bold" BorderThickness="0" Cursor="Hand"/>
            <Button Name="SvcBtnRefresh" Content="Refresh"           Width="100" Height="32"
                    Margin="6,0" Background="#1b212b" Foreground="White" FontWeight="Bold" BorderThickness="0" Cursor="Hand"/>
            <Button Name="SvcBtnClose"   Content="Close"             Width="100" Height="32"
                    Margin="6,0" Background="#313b4a"    Foreground="White" FontWeight="Bold" BorderThickness="0" Cursor="Hand"/>
        </WrapPanel>
    </Grid>
</Window>
"@

    $svcReader  = New-Object System.Xml.XmlNodeReader $svcXml
    $svcWin     = [Windows.Markup.XamlReader]::Load($svcReader)
    $svcList    = $svcWin.FindName("SvcList")
    $svcStatus  = $svcWin.FindName("SvcStatus")
    $svcDisable = $svcWin.FindName("SvcBtnDisable")
    $svcEnable  = $svcWin.FindName("SvcBtnEnable")
    $svcRefresh = $svcWin.FindName("SvcBtnRefresh")
    $svcClose   = $svcWin.FindName("SvcBtnClose")

    # --- Localize Services Manager labels to current language ---
    $svcWin.Title = "GameOptimizerPro  --  " + (Get-UIString "svc_title")
    ($svcWin.FindName("SvcTitle")).Text      = Get-UIString "svc_title"
    ($svcWin.FindName("SvcSubtitle")).Text   = Get-UIString "svc_subtitle"
    ($svcWin.FindName("SvcLegSafe")).Text    = Get-UIString "svc_legend_safe"
    ($svcWin.FindName("SvcLegCaution")).Text = Get-UIString "svc_legend_caution"
    ($svcWin.FindName("SvcLegDone")).Text    = Get-UIString "svc_legend_done"
    ($svcWin.FindName("SvcColSel")).Text     = Get-UIString "svc_col_sel"
    ($svcWin.FindName("SvcColName")).Text    = Get-UIString "svc_col_name"
    ($svcWin.FindName("SvcColDesc")).Text    = Get-UIString "svc_col_desc"
    ($svcWin.FindName("SvcColStatus")).Text  = Get-UIString "svc_col_status"
    ($svcWin.FindName("SvcColStart")).Text   = Get-UIString "svc_col_starttype"
    ($svcWin.FindName("SvcColCat")).Text     = Get-UIString "svc_col_category"
    ($svcWin.FindName("SvcColSafe")).Text    = Get-UIString "svc_col_safe"
    $svcDisable.Content = Get-UIString "svc_btn_disable"
    $svcEnable.Content  = Get-UIString "svc_btn_enable"
    $svcRefresh.Content = Get-UIString "svc_btn_refresh"
    $svcClose.Content   = Get-UIString "svc_btn_close"
    $svcCbMap   = @{}   # serviceName -> @{ Cb; Safe }

    function Build-ServiceRows {
        $svcList.Children.Clear()
        $svcCbMap.Clear()
        $count = 0

        # Get all known services that exist on this system
        foreach ($svcName in ($KnownServices.Keys | Sort-Object)) {
            $info = $KnownServices[$svcName]
            try {
                $svc = Get-Service -Name $svcName -ErrorAction Stop
            } catch { continue }
            $count++

            $startType = try {
                (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\$svcName" -ErrorAction Stop).Start
            } catch { 3 }
            $startLabel = switch ($startType) { 2{Get-UIString "word_automatic"} 3{Get-UIString "word_manual"} 4{Get-UIString "word_disabled"} default{Get-UIString "word_unknown"} }
            $isDisabled = ($startType -eq 4)
            $isRunning  = ($svc.Status -eq "Running")

            # Row
            $row = New-Object Windows.Controls.StackPanel
            $row.Orientation = "Horizontal"
            $row.Margin      = New-Object Windows.Thickness(0,2,0,2)

            # Checkbox
            $cb       = New-Object Windows.Controls.CheckBox
            $cb.Width = 34
            $cb.VerticalAlignment = "Center"
            $cb.IsEnabled = $true

            # Safety dot
            $dot      = New-Object Windows.Shapes.Ellipse
            $dot.Width  = 8
            $dot.Height = 8
            $dot.VerticalAlignment = "Center"
            $dot.Margin = New-Object Windows.Thickness(0,0,6,0)
            if ($isDisabled) {
                $dot.Fill = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(85,85,85))
                $dot.ToolTip = Get-UIString "svc_legend_done"
            } elseif ($info.Safe) {
                $dot.Fill = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(0,200,83))
                $dot.ToolTip = Get-UIString "svc_legend_safe"
            } else {
                $dot.Fill = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(233,69,96))
                $dot.ToolTip = Get-UIString "svc_legend_caution"
            }

            # Name
            $tbName = New-Object Windows.Controls.TextBlock
            $tbName.Text  = $svc.DisplayName
            $tbName.Width = 160
            $tbName.FontSize = 12
            $tbName.Foreground = if ($isDisabled) {
                New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(90,90,90))
            } else {
                New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(220,220,220))
            }
            $tbName.VerticalAlignment = "Center"
            $tbName.ToolTip = "Service name: $svcName"
            $tbName.TextTrimming = "CharacterEllipsis"

            # Description
            $tbDesc = New-Object Windows.Controls.TextBlock
            $tbDesc.Text  = $info.Desc
            $tbDesc.Width = 310
            $tbDesc.FontSize = 11
            $tbDesc.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(150,150,150))
            $tbDesc.VerticalAlignment = "Center"
            $tbDesc.TextTrimming = "CharacterEllipsis"
            $tbDesc.ToolTip = $info.Desc

            # Status
            $tbStatus = New-Object Windows.Controls.TextBlock
            $tbStatus.Text  = if ($isRunning) { Get-UIString "word_running" } else { Get-UIString "word_stopped" }
            $tbStatus.Width = 85
            $tbStatus.FontSize = 11
            $tbStatus.FontWeight = "SemiBold"
            $tbStatus.VerticalAlignment = "Center"
            $tbStatus.Foreground = if ($isRunning) {
                New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(0,200,83))
            } else {
                New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(130,130,130))
            }

            # Start type
            $tbStart = New-Object Windows.Controls.TextBlock
            $tbStart.Text  = $startLabel
            $tbStart.Width = 95
            $tbStart.FontSize = 11
            $tbStart.VerticalAlignment = "Center"
            $tbStart.Foreground = if ($isDisabled) {
                New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(233,69,96))
            } else {
                New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(170,170,170))
            }

            # Category
            $tbCat = New-Object Windows.Controls.TextBlock
            $tbCat.Text  = $info.Cat
            $tbCat.Width = 90
            $tbCat.FontSize = 10
            $tbCat.VerticalAlignment = "Center"
            $tbCat.Foreground = switch ($info.Cat) {
                "Privacy"     { New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(0,212,170)) }
                "Performance" { New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(255,160,0)) }
                "Security"    { New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(233,69,96)) }
                "Bloat"       { New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(150,100,200)) }
                default       { New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(130,130,130)) }
            }

            # Safe label
            $tbSafe = New-Object Windows.Controls.TextBlock
            $tbSafe.Text  = if ($info.Safe) { "Yes" } else { "No" }
            $tbSafe.Width = 60
            $tbSafe.FontSize = 11
            $tbSafe.FontWeight = "SemiBold"
            $tbSafe.VerticalAlignment = "Center"
            $tbSafe.Foreground = if ($info.Safe) {
                New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(0,200,83))
            } else {
                New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(233,69,96))
            }

            $row.Children.Add($cb)       | Out-Null
            $row.Children.Add($dot)      | Out-Null
            $row.Children.Add($tbName)   | Out-Null
            $row.Children.Add($tbDesc)   | Out-Null
            $row.Children.Add($tbStatus) | Out-Null
            $row.Children.Add($tbStart)  | Out-Null
            $row.Children.Add($tbCat)    | Out-Null
            $row.Children.Add($tbSafe)   | Out-Null
            $svcList.Children.Add($row)  | Out-Null

            $svcCbMap[$svcName] = @{ Cb = $cb; Safe = $info.Safe; StatusTb = $tbStatus; StartTb = $tbStart }
        }
        $svcStatus.Text = "$count " + (Get-UIString "svc_found")
    }

    Build-ServiceRows

    $svcDisable.Add_Click({
        $sel = $svcCbMap.GetEnumerator() | Where-Object { $_.Value.Cb.IsChecked -eq $true }
        if (-not $sel) { $svcStatus.Text = Get-UIString "svc_none_sel"; return }
        # Services marked Safe=$false (Windows Update, BITS, Print Spooler) break core
        # features when disabled. The red dot alone is easy to miss -- confirm first.
        $risky = @($sel | Where-Object { -not $_.Value.Safe } | ForEach-Object { $_.Key })
        if ($risky.Count -gt 0) {
            $r = [System.Windows.MessageBox]::Show(
                "You selected $($risky.Count) system service(s) marked as NOT safe to disable:`n`n  - " + ($risky -join "`n  - ") + "`n`nDisabling Windows Update / BITS stops all Windows updates (including security fixes); disabling the Print Spooler stops all printing.`n`nDisable them anyway?",
                "GameOptimizerPro -- System services",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Warning)
            if ($r -ne [System.Windows.MessageBoxResult]::Yes) { return }
        }
        $orig = Read-SvcOriginal
        $count = 0
        foreach ($entry in $sel) {
            $name = $entry.Key
            $mode = Get-SvcStartMode $name
            try {
                Stop-Service -Name $name -Force -ErrorAction SilentlyContinue
                Set-Service  -Name $name -StartupType Disabled -ErrorAction Stop
                # the first Disable wins -- disabling again must not record "disabled"
                if ($mode -and $mode -ne 'disabled' -and -not $orig.ContainsKey($name)) { $orig[$name] = $mode }
                $entry.Value.StatusTb.Text       = Get-UIString "word_stopped"
                $entry.Value.StatusTb.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(130,130,130))
                $entry.Value.StartTb.Text        = Get-UIString "word_disabled"
                $entry.Value.StartTb.Foreground  = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(233,69,96))
                $entry.Value.Cb.IsChecked        = $false
                Write-Log "Services Manager: Disabled '$name'"
                $count++
            } catch {
                Write-Log "Services Manager: Failed to disable '$name' -- $_"
            }
        }
        Save-SvcOriginal $orig
        Build-ServiceRows   # status colour, dot and name straight away, not only after Refresh
        $svcStatus.Text = "$count " + (Get-UIString "svc_disabled_msg")
    })

    $svcEnable.Add_Click({
        $sel = $svcCbMap.GetEnumerator() | Where-Object { $_.Value.Cb.IsChecked -eq $true }
        if (-not $sel) { $svcStatus.Text = Get-UIString "svc_none_sel"; return }
        $orig = Read-SvcOriginal
        $count = 0
        foreach ($entry in $sel) {
            $name = $entry.Key
            # back to the start type it had before "Disable" here -- Manual if unknown
            $mode = if ($orig.ContainsKey($name)) { $orig[$name] } else { 'demand' }
            try {
                $out = sc.exe config $name start= $mode 2>&1
                if ($LASTEXITCODE -ne 0) { throw "sc.exe config: $($out -join ' ')" }
                $orig.Remove($name)
                if ($mode -ne 'demand') {
                    Start-Service -Name $name -ErrorAction SilentlyContinue
                    if ((Get-Service -Name $name -ErrorAction SilentlyContinue).Status -eq 'Running') { $entry.Value.StatusTb.Text = Get-UIString "word_running" }
                }
                $entry.Value.StartTb.Text        = Get-UIString $(if ($mode -eq 'demand') { "word_manual" } else { "word_automatic" })
                $entry.Value.StartTb.Foreground  = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(170,170,170))
                $entry.Value.Cb.IsChecked        = $false
                Write-Log "Services Manager: Enabled '$name' (start type: $mode)"
                $count++
            } catch {
                Write-Log "Services Manager: Failed to enable '$name' -- $_"
            }
        }
        Save-SvcOriginal $orig
        Build-ServiceRows
        $svcStatus.Text = "$count " + (Get-UIString "svc_enabled_msg")
    })

    $svcRefresh.Add_Click({ Build-ServiceRows })
    $svcClose.Add_Click({  $svcWin.Close() })

    $svcWin.Owner = $Window; $svcWin.WindowStartupLocation = "CenterOwner"   # on the app's monitor, never behind it
    $svcWin.ShowDialog() | Out-Null
    # The services switched here also decide some tweak dots -- refresh them right away
    foreach ($n in 'Disable Telemetry & Data Collection', 'Disable Location Tracking', 'Disable Prefetch & Superfetch', 'Disable Windows Search Indexing') {
        if ($Script:TweakDots.ContainsKey($n)) { Update-TweakDot $Script:TweakDots[$n] $n | Out-Null }
    }
    Update-Counts
})


# -----------------------------------------
# LAUNCH
# -----------------------------------------
$StatusText.Text    = Get-UIString "status_ready"

Write-Log "GameOptimizerPro v$($Script:AppVersion) started | $HWInfo"
foreach ($p in $logPaths) { try { "[$(Get-Date -f 'HH:mm:ss')] Alles OK  --  ShowDialog wird aufgerufen" | Out-File $p -Append -ErrorAction SilentlyContinue } catch { } }
Write-Host "[$(Get-Date -f 'HH:mm:ss')] Alles OK  --  ShowDialog wird aufgerufen" -ForegroundColor DarkGray

# Console was already hidden at startup (where the host allows it).

Set-Splash "Almost done ..." 97
$Window.Add_ContentRendered({ Close-Splash })   # main window is on screen -> splash goes

# --- Baseline drift check: did a Windows update revert tweaks you applied before? ---
# Runs only at launch (no background process). If the last-applied snapshot has
# tweaks that are no longer active, offer to re-apply them.
try {
    $blv = (Read-Baseline).Version
    $drifted = Get-DriftedTweaks -Known $Script:CheckRaw
    if ($drifted.Count -gt 0) {
        Close-Splash
        $list = ($drifted | ForEach-Object { " - $_" }) -join "`n"
        # Who reset them can't be told apart. A newer app version can also check more settings
        # of a tweak than the one that applied it (1.2.6: DNS also over IPv6, Prefetch, ...).
        $why = if ($blv -ne $Script:AppVersion) {
            "A Windows update, another program or a change in Settings switched them back -- or this version of GameOptimizerPro (v$($Script:AppVersion)) checks more of their settings than the version you applied them with$(if ($blv) { " (v$blv)" })."
        } else { "A Windows update, another program or a change in Settings switched them back." }
        $r = [System.Windows.MessageBox]::Show(
            "$($drifted.Count) tweak(s) GameOptimizerPro applied are no longer fully in effect:`n`n$list`n`n$why`n`nRe-apply them now? (A registry backup is created first.)`n`nNo = keep the current settings -- you won't be asked about these again.",
            "GameOptimizerPro -- Tweaks no longer in effect",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Warning)
        if ($r -eq [System.Windows.MessageBoxResult]::Yes) {
            Backup-Registry -Label "PreDriftReapply" | Out-Null
            $reapplied = 0
            foreach ($name in $drifted) {
                $t = $AllTweaks | Where-Object { $_.Name -eq $name } | Select-Object -First 1
                if ($t) {
                    try { & $t.Action; $reapplied++; Write-Log "Drift re-apply OK: $name" }
                    catch { Write-Log "Drift re-apply FAILED: $name -- $_" }
                }
            }
            # The list was built before the re-apply -- refresh those rows + counts first, then the
            # baseline (keeps its entries, gets this version's header)
            foreach ($name in $drifted) { if ($Script:TweakDots.ContainsKey($name)) { Update-TweakDot $Script:TweakDots[$name] $name | Out-Null } }
            Update-Counts
            Save-Baseline -Add @()
            [System.Windows.MessageBox]::Show(
                "Re-applied $reapplied tweak(s). A restart may be needed for some to take effect.",
                "GameOptimizerPro",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information) | Out-Null
        } else {
            Remove-FromBaseline $drifted
        }
    }
} catch { Write-Log "Drift check skipped: $_" }

$Window.ShowDialog() | Out-Null

# -----------------------------------------
# GUI CLOSED (clean exit)  --  terminate this PowerShell process so no
# console window (visible or hidden) is left behind. Works on both classic
# conhost and Windows Terminal: when the hosted process ends, the host
# closes the window/tab itself.
# Note: this only runs on a clean close. If the script crashes, the catch
# block below keeps the process alive so the error MessageBox can be read.
# -----------------------------------------
Write-Log "GameOptimizerPro v$($Script:AppVersion) closed by user"
Stop-Process -Id $PID -Force -ErrorAction SilentlyContinue

} catch {
    $errMsg  = $_.Exception.Message
    $errLine = $_.InvocationInfo.ScriptLineNumber
    $errFull = "STARTUP ERROR line $errLine : $errMsg"
    try { if ($Script:Splash) { $Script:Splash.Close() } } catch { }
    Write-Host $errFull -ForegroundColor Red
    foreach ($p in $logPaths) {
        try { "[$(Get-Date -f 'HH:mm:ss')] $errFull" | Out-File $p -Append -ErrorAction SilentlyContinue } catch { }
    }
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        [System.Windows.Forms.MessageBox]::Show(
            "$errFull`n`nLog files:`n$($logPaths -join "`n")",
            "GameOptimizerPro - Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    } catch {
        Write-Host "MessageBox failed: $_" -ForegroundColor Red
        Read-Host "Error above  --  press Enter to exit"
    }
}
