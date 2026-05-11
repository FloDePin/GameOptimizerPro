
# ─────────────────────────────────────────
# WPF XAML GUI
# ─────────────────────────────────────────
[xml]$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="GameOptimizerPro v3.0 -- by FloDePin"
        Height="700" Width="820"
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
                            <Trigger Property="IsPressed"   Value="True"><Setter Property="Background" Value="#c73652"/></Trigger>
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
                            <Trigger Property="IsSelected"   Value="True"><Setter TargetName="Border" Property="Background" Value="#e94560"/><Setter Property="Foreground" Value="White"/></Trigger>
                            <Trigger Property="IsMouseOver"  Value="True"><Setter TargetName="Border" Property="Background" Value="#0f3460"/><Setter Property="Foreground" Value="White"/></Trigger>
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
            <TextBlock Text="Windows &amp; Gaming Optimizer -- by FloDePin" FontSize="12" Foreground="#888" Margin="2,2,0,0"/>
        </StackPanel>

        <Border Grid.Row="1" Background="#16213e" CornerRadius="8" Padding="12,8" Margin="0,0,0,12">
            <TextBlock Name="HwInfoText" Text="Detecting hardware..." FontSize="12" Foreground="#00d4aa" FontFamily="Consolas"/>
        </Border>

        <TabControl Grid.Row="2" Background="#16213e" BorderBrush="#333" Padding="0">
            <TabItem Header="[WIN]  Windows">
                <ScrollViewer Background="#1a1a2e" Padding="8">
                    <StackPanel Name="WindowsPanel" Margin="4"/>
                </ScrollViewer>
            </TabItem>
            <TabItem Header="[GAME] Gaming">
                <ScrollViewer Background="#1a1a2e" Padding="8">
                    <StackPanel Name="GamingPanel" Margin="4"/>
                </ScrollViewer>
            </TabItem>
            <TabItem Header="[NET]  Network">
                <ScrollViewer Background="#1a1a2e" Padding="8">
                    <StackPanel Name="NetworkPanel" Margin="4"/>
                </ScrollViewer>
            </TabItem>
            <TabItem Header="[RAM]  RAM &amp; Storage">
                <ScrollViewer Background="#1a1a2e" Padding="8">
                    <StackPanel Name="RamPanel" Margin="4"/>
                </ScrollViewer>
            </TabItem>
        </TabControl>

        <WrapPanel Grid.Row="3" Margin="0,12,0,0" HorizontalAlignment="Center">
            <Button Name="BtnSelectAll"   Content="[x] Select All"   Style="{StaticResource PrimaryBtn}" Margin="6,0"/>
            <Button Name="BtnDeselectAll" Content="[ ] Deselect All" Style="{StaticResource PrimaryBtn}" Margin="6,0"/>
            <Button Name="BtnApply"       Content="Apply Selected"   Style="{StaticResource PrimaryBtn}" Margin="6,0" Background="#e94560"/>
            <Button Name="BtnOpenLog"     Content="[Log] Open Log"   Style="{StaticResource PrimaryBtn}" Margin="6,0"/>
        </WrapPanel>

        <Border Grid.Row="4" Background="#16213e" CornerRadius="6" Padding="10,6" Margin="0,10,0,0">
            <TextBlock Name="StatusText" Text="Ready -- select tweaks and click Apply Selected."
                       Foreground="#aaaaaa" FontSize="12" FontFamily="Consolas"/>
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

# ─────────────────────────────────────────
# BUILD TWEAK ROWS
# ─────────────────────────────────────────
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
    $row             = New-Object Windows.Controls.StackPanel
    $row.Orientation = "Horizontal"
    $row.Margin      = New-Object Windows.Thickness(0,3,0,3)

    $cb                   = New-Object Windows.Controls.CheckBox
    $cb.Content           = $Tweak.Name
    $cb.Tag               = $Tweak.Name
    $cb.VerticalAlignment = "Center"
    $cb.Foreground        = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(221,221,221))
    $cb.FontSize          = 13
    $cb.Margin            = New-Object Windows.Thickness(0,0,8,0)
    $CheckBoxMap[$Tweak.Name] = $cb

    $btn                 = New-Object Windows.Controls.Button
    $btn.Content         = "?"
    $btn.Width           = 22; $btn.Height = 22; $btn.FontSize = 11
    $btn.Background      = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(22,33,62))
    $btn.Foreground      = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(170,170,170))
    $btn.BorderBrush     = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(68,68,68))
    $btn.BorderThickness = New-Object Windows.Thickness(1)
    $btn.Cursor          = [System.Windows.Input.Cursors]::Hand
    $btn.VerticalAlignment = "Center"

    $d = $Tweak.Desc; $n = $Tweak.Name
    $btn.Add_Click({
        [System.Windows.MessageBox]::Show($d,"Info: $n",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information)
    }.GetNewClosure())

    $capturedBtn = $btn
    $btn.Add_MouseEnter({
        $capturedBtn.Background = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(233,69,96))
        $capturedBtn.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(255,255,255))
    }.GetNewClosure())
    $btn.Add_MouseLeave({
        $capturedBtn.Background = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(22,33,62))
        $capturedBtn.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(170,170,170))
    }.GetNewClosure())

    $row.Children.Add($cb)  | Out-Null
    $row.Children.Add($btn) | Out-Null
    return $row
}

$catPanels = @{
    "Windows"       = $WindowsPanel
    "Gaming"        = $GamingPanel
    "Network"       = $NetworkPanel
    "RAM & Storage" = $RamPanel
}

foreach ($cat in @("Windows","Gaming","Network","RAM & Storage")) {
    $panel  = $catPanels[$cat]
    $groups = $AllTweaks | Where-Object { $_.Category -eq $cat } | Select-Object -ExpandProperty Group -Unique
    foreach ($grp in $groups) {
        $panel.Children.Add((New-GroupHeader "-- $grp")) | Out-Null
        $AllTweaks | Where-Object { $_.Category -eq $cat -and $_.Group -eq $grp } |
        ForEach-Object { $panel.Children.Add((New-TweakRow $_)) | Out-Null }
    }
}

# ─────────────────────────────────────────
# BUTTON EVENTS
# ─────────────────────────────────────────
$BtnSelectAll.Add_Click({ foreach ($cb in $CheckBoxMap.Values) { $cb.IsChecked = $true } })
$BtnDeselect.Add_Click({ foreach ($cb in $CheckBoxMap.Values) { $cb.IsChecked = $false } })

$BtnOpenLog.Add_Click({
    if (Test-Path $LogFile) { Start-Process notepad.exe $LogFile }
    else {
        [System.Windows.MessageBox]::Show("No log yet. Apply tweaks first.","Log",
            [System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Information)
    }
})

$BtnApply.Add_Click({
    $selected = $AllTweaks | Where-Object { $CheckBoxMap[$_.Name].IsChecked -eq $true }
    if ($selected.Count -eq 0) {
        [System.Windows.MessageBox]::Show("No tweaks selected!","GameOptimizerPro",
            [System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Warning)
        return
    }

    $confirm = [System.Windows.MessageBox]::Show(
        "Apply $($selected.Count) tweak(s)?`n`nA restore point will be created first.",
        "GameOptimizerPro -- Confirm",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )
    if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

    $StatusText.Text = "Creating restore point..."
    try {
        Checkpoint-Computer -Description "GameOptimizerPro Backup" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Log "Restore point created"
    } catch { Write-Log "Restore point failed: $_" }

    $done = 0; $total = $selected.Count
    foreach ($t in $selected) {
        $StatusText.Text = "Applying: $($t.Name) ($done/$total)..."
        $Window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Render)
        try   { & $t.Action; Write-Log "OK: $($t.Name)" }
        catch { Write-Log "FAILED: $($t.Name) -- $_" }
        $done++
    }

    $StatusText.Text = "Done! $done tweak(s) applied. Log: $LogFile"
    [System.Windows.MessageBox]::Show(
        "$done tweak(s) applied!`n`nSome changes require a restart.`nLog: $LogFile",
        "GameOptimizerPro -- Done",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Information
    )
})

# ─────────────────────────────────────────
# LAUNCH
# ─────────────────────────────────────────
Write-Log "GameOptimizerPro started | $HWInfo"
$Window.ShowDialog() | Out-Null
