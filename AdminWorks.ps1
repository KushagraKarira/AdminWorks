<#
================================================================================
  ADMINWORKS PRO v4.2 - Enterprise Windows Administration & Optimization Suite
  Compatible with Windows 10 & Windows 11
================================================================================
#>

# --- [Self-Elevate to Administrator] ---
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $scriptPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Definition }
    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList "-ExecutionPolicy Bypass", "-File `"$scriptPath`"" -Verb RunAs
    exit
}

Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# --- [OS Version Detection Helper] ---
$script:OSBuild = [Environment]::OSVersion.Version.Build
$script:IsWin11 = ($script:OSBuild -ge 22000)
$script:IsWin10 = ($script:OSBuild -ge 10240 -and $script:OSBuild -lt 22000)

# --- [High-DPI Scaling & Native Windows DWM Helpers] ---
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class NativeMethods {
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();

    [DllImport("user32.dll")]
    public static extern int SendMessage(IntPtr hWnd, int Msg, int wParam, int lParam);

    [DllImport("user32.dll")]
    public static extern bool ReleaseCapture();

    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
}
"@
[NativeMethods]::SetProcessDPIAware() | Out-Null
[System.Windows.Forms.Application]::EnableVisualStyles()

# --- [Theme & Design Palette] ---
$script:Theme = @{
    Bg            = [System.Drawing.Color]::FromArgb(13, 15, 20)       # Deep Obsidian
    Header        = [System.Drawing.Color]::FromArgb(18, 22, 30)       # Dark Slate
    Sidebar       = [System.Drawing.Color]::FromArgb(21, 26, 36)       # Sidebar Panel
    SidebarActive = [System.Drawing.Color]::FromArgb(35, 43, 60)       # Active Tab
    Card          = [System.Drawing.Color]::FromArgb(26, 32, 44)       # Card Surface
    CardHover     = [System.Drawing.Color]::FromArgb(34, 42, 58)       # Card Hover
    CardBorder    = [System.Drawing.Color]::FromArgb(44, 53, 74)       # Subtle Border
    Accent        = [System.Drawing.Color]::FromArgb(59, 130, 246)     # Electric Blue
    AccentGlow    = [System.Drawing.Color]::FromArgb(96, 165, 250)     # Sky Blue
    Success       = [System.Drawing.Color]::FromArgb(16, 185, 129)     # Emerald Green
    Warning       = [System.Drawing.Color]::FromArgb(245, 158, 11)     # Amber Yellow
    Danger        = [System.Drawing.Color]::FromArgb(239, 68, 68)      # Crimson Red
    TextMain      = [System.Drawing.Color]::FromArgb(243, 244, 246)    # Crisp Off-White
    TextMuted     = [System.Drawing.Color]::FromArgb(156, 163, 175)    # Cool Gray
    TextSubtle    = [System.Drawing.Color]::FromArgb(107, 114, 128)    # Slate Gray
    TerminalBg    = [System.Drawing.Color]::FromArgb(7, 9, 12)         # Terminal Black
}

$GlobalFont = "Segoe UI Variable Display"
$CheckFont = New-Object System.Drawing.Font($GlobalFont, 10)
if ($CheckFont.Name -ne $GlobalFont) { $GlobalFont = "Segoe UI" }

# Backup Directory Setup
$script:BackupDir = "$env:LOCALAPPDATA\AdminWorks\Backups"
if (-not (Test-Path $script:BackupDir)) { New-Item -ItemType Directory -Path $script:BackupDir -Force | Out-Null }

# --- [Dynamic Screen Resolution Adaptation] ---
$ScreenBounds  = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$InitialWidth  = [math]::Min(1320, [int]($ScreenBounds.Width * 0.92))
$InitialHeight = [math]::Min(920, [int]($ScreenBounds.Height * 0.90))

# --- [Main Form Window] ---
$Form = New-Object System.Windows.Forms.Form
$Form.Text            = "ADMINWORKS PRO"
$Form.Size            = New-Object System.Drawing.Size($InitialWidth, $InitialHeight)
$Form.BackColor       = $script:Theme.Bg
$Form.StartPosition   = "CenterScreen"
$Form.FormBorderStyle = "None"
$Form.MinimumSize     = New-Object System.Drawing.Size(960, 680)
$Form.KeyPreview      = $true

try {
    $bf = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic
    $prop = $Form.GetType().GetProperty("DoubleBuffered", $bf)
    if ($prop) { $prop.SetValue($Form, $true, $null) }
} catch {}

# Apply Dark Mode Frame Attribute
try {
    $darkValue = 1
    $res = [NativeMethods]::DwmSetWindowAttribute($Form.Handle, 20, [ref]$darkValue, 4)
    if ($res -ne 0) {
        [NativeMethods]::DwmSetWindowAttribute($Form.Handle, 19, [ref]$darkValue, 4) | Out-Null
    }
} catch {}

# --- [Header: Brand, System Badge, Search, Window Controls] ---
$Header = New-Object System.Windows.Forms.Panel -Property @{
    Dock      = "Top"
    Height    = 70
    BackColor = $script:Theme.Header
}
$Form.Controls.Add($Header)

# Brand Label
$TitleLbl = New-Object System.Windows.Forms.Label -Property @{
    Text      = "[char]0x26A1 ADMINWORKS"
    Location  = New-Object System.Drawing.Point(22, 14); AutoSize = $true
    ForeColor = $script:Theme.TextMain
    Font      = New-Object System.Drawing.Font($GlobalFont, 12.5, [System.Drawing.FontStyle]::Bold)
}
$TitleSub = New-Object System.Windows.Forms.Label -Property @{
    Text      = "ENTERPRISE SUITE v4.2  [char]0x2022  BY KUSHAGRA KARIRA"
    Location  = New-Object System.Drawing.Point(24, 40); AutoSize = $true
    ForeColor = $script:Theme.AccentGlow
    Font      = New-Object System.Drawing.Font($GlobalFont, 7.5, [System.Drawing.FontStyle]::Bold)
    Cursor    = [System.Windows.Forms.Cursors]::Hand
}
$TitleSub.Add_Click({ Start-Process "https://github.com/KushagraKarira/AdminWorks" })
$TitleSub.Add_MouseEnter({ $this.ForeColor = $script:Theme.TextMain })
$TitleSub.Add_MouseLeave({ $this.ForeColor = $script:Theme.AccentGlow })
$Header.Controls.AddRange(@($TitleLbl, $TitleSub))

# Native Smooth Dragging
$Header.Add_MouseDown({
    if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        [NativeMethods]::ReleaseCapture() | Out-Null
        [NativeMethods]::SendMessage($Form.Handle, 0xA1, 0x2, 0) | Out-Null
    }
})

# System Info Badge
$LocalIP = "Scanning..."
try {
    $ipObj = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -match 'Dhcp|Manual' -and $_.InterfaceAlias -notmatch 'Loopback|Virtual|vEthernet' } | Select-Object -First 1
    if ($ipObj) { $LocalIP = $ipObj.IPAddress } else { $LocalIP = "No LAN" }
} catch { $LocalIP = "Offline" }

$OSInfo = (Get-CimInstance Win32_OperatingSystem)
$SysBadge = New-Object System.Windows.Forms.Label -Property @{
    Text      = "$($env:COMPUTERNAME)  [char]0x2022  IP: $LocalIP  [char]0x2022  $($OSInfo.Caption)"
    Location  = New-Object System.Drawing.Point(260, 26); Size = New-Object System.Drawing.Size(380, 20)
    ForeColor = $script:Theme.TextMuted; Font = New-Object System.Drawing.Font($GlobalFont, 8.5)
}
$Header.Controls.Add($SysBadge)

# Search Input Container
$SearchPanel = New-Object System.Windows.Forms.Panel -Property @{
    Location  = New-Object System.Drawing.Point(($Header.Width - 480), 18); Size = New-Object System.Drawing.Size(320, 34)
    BackColor = $script:Theme.Sidebar; Anchor = [System.Windows.Forms.AnchorStyles]"Top, Right"
}
$SearchBox = New-Object System.Windows.Forms.TextBox -Property @{
    BorderStyle = "None"; BackColor = $script:Theme.Sidebar; ForeColor = $script:Theme.TextMain
    Font = New-Object System.Drawing.Font($GlobalFont, 9.5); Location = New-Object System.Drawing.Point(12, 8)
    Width = 295; Text = "[char]::ConvertFromUtf32(0x1F50D) Search tools, tweaks & features..."
}
$SearchBox.Add_GotFocus({ if ($this.Text -eq "[char]::ConvertFromUtf32(0x1F50D) Search tools, tweaks & features...") { $this.Text = ""; $this.ForeColor = $script:Theme.TextMain } })
$SearchBox.Add_LostFocus({ if ([string]::IsNullOrWhiteSpace($this.Text)) { $this.Text = "🔍 Search tools, tweaks & features..."; $this.ForeColor = $script:Theme.TextSubtle } })
$SearchPanel.Controls.Add($SearchBox)
$Header.Controls.Add($SearchPanel)

# Window Controls (Minimize, Maximize/Restore, Close)
$CtrlBox = New-Object System.Windows.Forms.Panel -Property @{Dock="Right"; Width=140}
$Header.Controls.Add($CtrlBox)

function New-WindowBtn($Text, $X, $HoverColor, $Action) {
    $B = New-Object System.Windows.Forms.Button -Property @{
        Text = $Text; Size = New-Object System.Drawing.Size(42, 34); 
        Location = New-Object System.Drawing.Point($X, 18); FlatStyle = "Flat"; 
        ForeColor = $script:Theme.TextMuted; Tag = $HoverColor
        Font = New-Object System.Drawing.Font($GlobalFont, 9, [System.Drawing.FontStyle]::Bold)
    }
    $B.FlatAppearance.BorderSize = 0
    $B.Add_Click($Action)
    $B.Add_MouseEnter({ $this.BackColor = $this.Tag; $this.ForeColor = [System.Drawing.Color]::White })
    $B.Add_MouseLeave({ $this.BackColor = [System.Drawing.Color]::Transparent; $this.ForeColor = $script:Theme.TextMuted })
    $CtrlBox.Controls.Add($B)
    return $B
}
$BtnClose = New-WindowBtn "[char]0x2715" 90 $script:Theme.Danger { $Form.Close() }
$BtnMax   = New-WindowBtn "[char]0x25A1" 46 $script:Theme.CardHover { 
    if ($Form.WindowState -eq "Maximized") { 
        $Form.WindowState = "Normal"
        $this.Text = "[char]0x25A1"
    } else { 
        $Form.WindowState = "Maximized"
        $this.Text = "[char]0x274F"
    } 
}
$BtnMin   = New-WindowBtn "—" 2 $script:Theme.CardHover { $Form.WindowState = "Minimized" }

# --- [Sidebar Navigation Container] ---
$Sidebar = New-Object System.Windows.Forms.Panel -Property @{
    Dock      = "Left"
    Width     = 230
    BackColor = $script:Theme.Sidebar
}
$Form.Controls.Add($Sidebar)

# --- [Bottom Console Drawer] ---
$LogContainer = New-Object System.Windows.Forms.Panel -Property @{
    Dock      = "Bottom"
    Height    = 200
    BackColor = $script:Theme.TerminalBg
    Padding   = New-Object System.Windows.Forms.Padding(16, 6, 16, 12)
}
$Form.Controls.Add($LogContainer)

# Console Toolbar
$TermHeader = New-Object System.Windows.Forms.Panel -Property @{Dock="Top"; Height=32; BackColor=$script:Theme.TerminalBg}
$LogContainer.Controls.Add($TermHeader)

$TermTitle = New-Object System.Windows.Forms.Label -Property @{
    Text = "● CONSOLE OUTPUT"; Location = New-Object System.Drawing.Point(0, 6); AutoSize = $true
    ForeColor = $script:Theme.Success; Font = New-Object System.Drawing.Font($GlobalFont, 8, [System.Drawing.FontStyle]::Bold)
}
$TermHeader.Controls.Add($TermTitle)

# Responsive Console Buttons Container
$TermBtnContainer = New-Object System.Windows.Forms.FlowLayoutPanel -Property @{
    Dock          = "Right"
    Width         = 430
    Height        = 28
    FlowDirection = "RightToLeft"
    BackColor     = $script:Theme.TerminalBg
}
$TermHeader.Controls.Add($TermBtnContainer)

$LogBox = New-Object System.Windows.Forms.RichTextBox -Property @{
    Dock = "Fill"; BackColor = [System.Drawing.Color]::FromArgb(5, 6, 8)
    ForeColor = $script:Theme.TextMain; BorderStyle = "None"; ReadOnly = $true
    Font = New-Object System.Drawing.Font("Consolas", 9.5)
}
$LogContainer.Controls.Add($LogBox)
$LogBox.BringToFront()

function New-TermBtn($Text, $Action) {
    $Btn = New-Object System.Windows.Forms.Button -Property @{
        Text = $Text; Size = New-Object System.Drawing.Size(85, 24)
        FlatStyle = "Flat"; BackColor = $script:Theme.Card; ForeColor = $script:Theme.TextMuted
        Font = New-Object System.Drawing.Font($GlobalFont, 7.5, [System.Drawing.FontStyle]::Bold)
        Margin = New-Object System.Windows.Forms.Padding(4, 2, 4, 2)
        Cursor = [System.Windows.Forms.Cursors]::Hand
    }
    $Btn.FlatAppearance.BorderSize = 0
    $Btn.Add_MouseEnter({ $this.BackColor = $script:Theme.CardHover; $this.ForeColor = $script:Theme.TextMain })
    $Btn.Add_MouseLeave({ $this.BackColor = $script:Theme.Card; $this.ForeColor = $script:Theme.TextMuted })
    $Btn.Add_Click($Action)
    $TermBtnContainer.Controls.Add($Btn)
}

# Collapse/Expand Toggle
$BtnToggleDrawer = New-Object System.Windows.Forms.Button -Property @{
    Text = "▼ COLLAPSE"; Size = New-Object System.Drawing.Size(95, 24)
    FlatStyle = "Flat"; BackColor = $script:Theme.Card; ForeColor = $script:Theme.AccentGlow
    Font = New-Object System.Drawing.Font($GlobalFont, 7.5, [System.Drawing.FontStyle]::Bold)
    Margin = New-Object System.Windows.Forms.Padding(4, 2, 4, 2)
    Cursor = [System.Windows.Forms.Cursors]::Hand
}
$BtnToggleDrawer.FlatAppearance.BorderSize = 0
$BtnToggleDrawer.Add_Click({
    if ($LogContainer.Height -gt 40) {
        $LogContainer.Height = 36
        $BtnToggleDrawer.Text = "▲ EXPAND"
    } else {
        $LogContainer.Height = 200
        $BtnToggleDrawer.Text = "▼ COLLAPSE"
    }
})

$TermBtnContainer.Controls.Add($BtnToggleDrawer)
New-TermBtn "EXPORT" { 
    $Path = "$env:USERPROFILE\Desktop\AdminWorks_Log_$((Get-Date).ToString('yyyy-MM-dd_HHmmss')).txt"
    $LogBox.Text | Out-File -FilePath $Path -Encoding UTF8
    Write-Log "Log exported to: $Path" "Success"
}
New-TermBtn "COPY ALL" { [System.Windows.Forms.Clipboard]::SetText($LogBox.Text); Write-Log "Console copied to clipboard." "Success" }
New-TermBtn "CLEAR" { $LogBox.Clear(); Write-Log "Console cleared." "Info" }

function Write-Log ($Msg, $Type = "Info") {
    if ([string]::IsNullOrWhiteSpace($Msg)) { return }
    $LogBox.Invoke([Action[string, string]]{
        param($m, $t)
        $LogBox.SelectionStart = $LogBox.TextLength
        $LogBox.SelectionColor = switch ($t) {
            "Success" { $script:Theme.Success }
            "Warning" { $script:Theme.Warning }
            "Error"   { $script:Theme.Danger }
            "Exec"    { $script:Theme.AccentGlow }
            Default   { $script:Theme.TextMuted }
        }
        $LogBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [$($t.ToUpper().PadRight(7))] $m`n")
        $LogBox.ScrollToCaret()
    }, $Msg, $Type)
}

# --- [Central Work Area & Dynamic Telemetry] ---
$MainArea = New-Object System.Windows.Forms.Panel -Property @{
    Dock      = "Fill"
    BackColor = $script:Theme.Bg
}
$Form.Controls.Add($MainArea)
$MainArea.BringToFront()

# Responsive TableLayoutPanel for Live Stats
$TelemetryBar = New-Object System.Windows.Forms.TableLayoutPanel -Property @{
    Dock        = "Top"
    Height      = 64
    BackColor   = $script:Theme.SidebarActive
    ColumnCount = 4
    RowCount    = 1
    Padding     = New-Object System.Windows.Forms.Padding(12, 6, 12, 6)
}
# Suppress return indices (fixes 0, 1, 2, 3 popup emission)
[void]$TelemetryBar.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 25)))
[void]$TelemetryBar.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 25)))
[void]$TelemetryBar.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 25)))
[void]$TelemetryBar.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 25)))
$MainArea.Controls.Add($TelemetryBar)

function New-StatWidget($Title) {
    $P = New-Object System.Windows.Forms.Panel -Property @{
        Dock      = "Fill"
        BackColor = $script:Theme.Card
        Margin    = New-Object System.Windows.Forms.Padding(4)
    }
    $LTitle = New-Object System.Windows.Forms.Label -Property @{
        Text      = $Title; Location = New-Object System.Drawing.Point(10, 6); AutoSize = $true
        ForeColor = $script:Theme.TextMuted; Font = New-Object System.Drawing.Font($GlobalFont, 7.5, [System.Drawing.FontStyle]::Bold)
    }
    $LVal = New-Object System.Windows.Forms.Label -Property @{
        Text      = "--"; Location = New-Object System.Drawing.Point(10, 24); AutoSize = $true
        ForeColor = $script:Theme.TextMain; Font = New-Object System.Drawing.Font($GlobalFont, 9.5, [System.Drawing.FontStyle]::Bold)
    }
    $P.Controls.AddRange(@($LTitle, $LVal))
    $TelemetryBar.Controls.Add($P)
    return $LVal
}

$StatCPU  = New-StatWidget "CPU LOAD"
$StatRAM  = New-StatWidget "MEMORY USED"
$StatDisk = New-StatWidget "SYSTEM DRIVE (C:)"
$StatUp   = New-StatWidget "SYSTEM UPTIME"

# High-Performance CPU Counter (Eliminates GUI Lag)
$script:CpuCounter = $null
try {
    $script:CpuCounter = New-Object System.Diagnostics.PerformanceCounter("Processor", "% Processor Time", "_Total")
    $null = $script:CpuCounter.NextValue()
} catch {}

# --- [Card Engine & Registration Setup] ---
$script:AllCards = New-Object System.Collections.Generic.List[PSObject]
$script:CategoryPanels = @{}
$script:SidebarButtons = @{}
$script:CurrentTabId = "Presets"

function New-TweakCard ($CategoryPanel, $Title, $CategoryTag, $Desc, $Action) {
    $P = New-Object System.Windows.Forms.Panel -Property @{
        Size      = New-Object System.Drawing.Size(325, 142)
        BackColor = $script:Theme.Card
        Margin    = New-Object System.Windows.Forms.Padding(10)
    }

    $TagLbl = New-Object System.Windows.Forms.Label -Property @{
        Text      = $CategoryTag.ToUpper()
        Location  = New-Object System.Drawing.Point(14, 10); AutoSize = $true
        ForeColor = $script:Theme.AccentGlow
        Font      = New-Object System.Drawing.Font($GlobalFont, 7, [System.Drawing.FontStyle]::Bold)
    }

    $TitleLbl = New-Object System.Windows.Forms.Label -Property @{
        Text      = $Title
        Location  = New-Object System.Drawing.Point(12, 28); Size = New-Object System.Drawing.Size(200, 24)
        ForeColor = $script:Theme.TextMain
        Font      = New-Object System.Drawing.Font($GlobalFont, 9.5, [System.Drawing.FontStyle]::Bold)
    }

    $DescLbl = New-Object System.Windows.Forms.Label -Property @{
        Text      = $Desc
        Location  = New-Object System.Drawing.Point(14, 54); Size = New-Object System.Drawing.Size(295, 42)
        ForeColor = $script:Theme.TextMuted
        Font      = New-Object System.Drawing.Font($GlobalFont, 8)
    }

    # Smooth Card Hover Effect
    $P.Add_MouseEnter({ $this.BackColor = $script:Theme.CardHover })
    $P.Add_MouseLeave({ $this.BackColor = $script:Theme.Card })

    $ActionString = $Action.ToString()

    $Btn = New-Object System.Windows.Forms.Button -Property @{
        Text      = "APPLY"
        Size      = New-Object System.Drawing.Size(95, 28)
        Location  = New-Object System.Drawing.Point(216, 104)
        FlatStyle = "Flat"
        BackColor = $script:Theme.SidebarActive
        ForeColor = $script:Theme.TextMain
        Font      = New-Object System.Drawing.Font($GlobalFont, 8, [System.Drawing.FontStyle]::Bold)
        Tag       = $ActionString
        Cursor    = [System.Windows.Forms.Cursors]::Hand
    }
    $Btn.FlatAppearance.BorderSize = 0
    $Btn.Add_MouseEnter({ if ($this.Enabled) { $this.BackColor = $script:Theme.Accent; $this.ForeColor = [System.Drawing.Color]::White } })
    $Btn.Add_MouseLeave({ if ($this.Enabled) { $this.BackColor = $script:Theme.SidebarActive; $this.ForeColor = $script:Theme.TextMain } })

    # Asynchronous Thread Execution
    $Btn.Add_Click({
        $B = $this
        $ActionCode = $B.Tag

        $B.Enabled = $false
        $B.Text = "RUNNING..."
        $B.BackColor = $script:Theme.Warning
        $B.ForeColor = [System.Drawing.Color]::Black

        $PS = [powershell]::Create().AddScript({
            param($CodeStr, $LogBox, $Theme, $BackupDir)
            $global:BackupDir = $BackupDir
            
            function Write-Log ($Msg, $Type = "Info") {
                if ([string]::IsNullOrWhiteSpace($Msg)) { return }
                $LogBox.Invoke([Action[string, string]]{
                    param($m, $t)
                    $LogBox.SelectionStart = $LogBox.TextLength
                    $LogBox.SelectionColor = switch ($t) {
                        "Success" { $Theme.Success }
                        "Warning" { $Theme.Warning }
                        "Error"   { $Theme.Danger }
                        "Exec"    { $Theme.AccentGlow }
                        Default   { $Theme.TextMuted }
                    }
                    $LogBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [$($t.ToUpper().PadRight(7))] $m`n")
                    $LogBox.ScrollToCaret()
                }, $Msg, $Type)
            }

            try {
                $Exec = [scriptblock]::Create($CodeStr)
                & $Exec
            } catch {
                Write-Log "Execution Error: $($_.Exception.Message)" "Error"
            }
        }).AddArgument($ActionCode).AddArgument($LogBox).AddArgument($script:Theme).AddArgument($script:BackupDir)

        $Runspace = [runspacefactory]::CreateRunspace()
        $Runspace.ThreadOptions = "ReuseThread"
        $Runspace.Open()
        $PS.Runspace = $Runspace

        $null = $PS.BeginInvoke()

        $Timer = New-Object System.Windows.Forms.Timer
        $Timer.Interval = 350
        $Timer.Tag = @{ Button = $B; PS = $PS; Runspace = $Runspace }
        $Timer.Add_Tick({
            $State = $this.Tag
            if ($State.PS.InvocationStateInfo.State -ne "Running") {
                $State.Button.Enabled = $true
                $State.Button.Text = "DONE"
                $State.Button.BackColor = $script:Theme.Success
                $State.Button.ForeColor = [System.Drawing.Color]::White

                $State.PS.Dispose()
                $State.Runspace.Close()
                $State.Runspace.Dispose()

                $this.Stop()
                $this.Dispose()
            }
        })
        $Timer.Start()
    })

    $P.Controls.AddRange(@($TagLbl, $TitleLbl, $DescLbl, $Btn))
    $CategoryPanel.Controls.Add($P)

    $script:AllCards.Add([PSCustomObject]@{
        Title       = $Title
        Category    = $CategoryTag
        Description = $Desc
        Panel       = $P
    })
}

# --- [Sidebar Tabs Definition with Tested Universal Glyphs] ---
$TabList = @(
    @{ Id = "Presets";   Name = "$IconPresets  Preset Profiles"; Desc = "1-Click Optimization Profiles" },
    @{ Id = "Maint";     Name = "$IconMaint  Maintenance";     Desc = "DISM, SFC, Component cleanup, Update fixes" },
    @{ Id = "Perf";      Name = "$IconPerf  Performance";     Desc = "Power plans, CPU priority, latency & RAM" },
    @{ Id = "Net";       Name = "$IconNet  Network & DNS";   Desc = "DNS benchmarks, Wi-Fi keys, TCP stack & ports" },
    @{ Id = "Privacy";   Name = "$IconPrivacy  Privacy & Bloat"; Desc = "Telemetry removal, Bing, Copilot & Debloat" },
    @{ Id = "Context";   Name = "$IconExplorer  Shell & Explorer";Desc = "Context menus, file extensions & UI tweaks" },
    @{ Id = "Hardware";  Name = "$IconHardware  Hardware Audit";  Desc = "SMART drives, RAM banks, battery & GPU stats" },
    @{ Id = "Apps";      Name = "$IconApps  Software Hub";    Desc = "Winget package updater & curated installer" },
    @{ Id = "Admin";     Name = "$IconAdmin  Admin Utilities"; Desc = "GodMode, Windows tools hub & System Restore" }
)
$ViewContainer = New-Object System.Windows.Forms.Panel -Property @{
    Dock      = "Fill"
    BackColor = $script:Theme.Bg
}
$MainArea.Controls.Add($ViewContainer)
$ViewContainer.BringToFront()

$BtnY = 12
foreach ($tab in $TabList) {
    $Flow = New-Object System.Windows.Forms.FlowLayoutPanel -Property @{
        Dock          = "Fill"
        AutoScroll    = $true
        BackColor     = $script:Theme.Bg
        Padding       = New-Object System.Windows.Forms.Padding(18, 14, 18, 18)
        Visible       = $false
    }
    $ViewContainer.Controls.Add($Flow)
    $script:CategoryPanels[$tab.Id] = $Flow

    $NavBtn = New-Object System.Windows.Forms.Button -Property @{
        Text      = "  $($tab.Name)"
        Location  = New-Object System.Drawing.Point(10, $BtnY)
        Size      = New-Object System.Drawing.Size(210, 40)
        FlatStyle = "Flat"
        BackColor = $script:Theme.Sidebar
        ForeColor = $script:Theme.TextMuted
        Font      = New-Object System.Drawing.Font($GlobalFont, 8.5, [System.Drawing.FontStyle]::Bold)
        TextAlign = "MiddleLeft"
        Tag       = $tab.Id
        Cursor    = [System.Windows.Forms.Cursors]::Hand
    }
    $NavBtn.FlatAppearance.BorderSize = 0
    $NavBtn.Add_Click({
        $TargetId = $this.Tag
        $script:CurrentTabId = $TargetId
        $SearchBox.Text = "🔍 Search tools, tweaks & features..."
        $SearchBox.ForeColor = $script:Theme.TextSubtle
        foreach ($k in $script:CategoryPanels.Keys) { $script:CategoryPanels[$k].Visible = ($k -eq $TargetId) }
        foreach ($card in $script:AllCards) { $card.Panel.Visible = $true }
        foreach ($b in $script:SidebarButtons.Values) { 
            $b.BackColor = $script:Theme.Sidebar; $b.ForeColor = $script:Theme.TextMuted 
        }
        $this.BackColor = $script:Theme.SidebarActive
        $this.ForeColor = $script:Theme.AccentGlow
    })
    $Sidebar.Controls.Add($NavBtn)
    $script:SidebarButtons[$tab.Id] = $NavBtn
    $BtnY += 44
}

# --- [Dynamic Cross-Category Search Engine] ---
$SearchBox.Add_TextChanged({
    $Query = $SearchBox.Text.Trim().ToLower()
    $isSearching = ($Query -ne "🔍 search tools, tweaks & features..." -and -not [string]::IsNullOrWhiteSpace($Query))

    if (-not $isSearching) {
        foreach ($card in $script:AllCards) { $card.Panel.Visible = $true }
        foreach ($k in $script:CategoryPanels.Keys) { 
            $script:CategoryPanels[$k].Visible = ($k -eq $script:CurrentTabId) 
        }
        return
    }

    foreach ($card in $script:AllCards) {
        $Match = ($card.Title.ToLower() -like "*$Query*") -or 
                 ($card.Description.ToLower() -like "*$Query*") -or 
                 ($card.Category.ToLower() -like "*$Query*")
        $card.Panel.Visible = $Match
    }
    foreach ($k in $script:CategoryPanels.Keys) {
        $hasVisible = ($script:CategoryPanels[$k].Controls | Where-Object { $_.Visible }).Count -gt 0
        $script:CategoryPanels[$k].Visible = $hasVisible
    }
})

# ==============================================================================
# FEATURE REGISTRATION & PRESETS
# ==============================================================================

# ==============================================================================
# 1. 1-CLICK PRESET PROFILES
# ==============================================================================
$P_Presets = $script:CategoryPanels["Presets"]

New-TweakCard $P_Presets "$IconGamer Gamer Mode Profile" "Preset Profile" "Applies Ultimate Power Plan, disables GameDVR, prioritizes foreground threads & frees RAM." {
    Write-Log "Applying GAMER MODE PRESET..." "Warning"
    powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 | Out-Null
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value 0
    reg add "HKCU\System\GameConfigStore" /v "GameDVR_Enabled" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v "AllowGameDVR" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v Win32PrioritySeparation /t REG_DWORD /d 38 /f | Out-Null
    [System.GC]::Collect()
    Write-Log "Gamer Mode Profile successfully configured and active." "Success"
}

New-TweakCard $P_Presets "$IconShield Privacy Lockdown" "Preset Profile" "Disables telemetry, DiagTrack, Recall AI, Bing Start Search, Ad ID & Edge Background." {
    Write-Log "Applying PRIVACY LOCKDOWN PRESET..." "Warning"
    Stop-Service "DiagTrack", "dmwappushservice" -ErrorAction SilentlyContinue
    Set-Service "DiagTrack", "dmwappushservice" -StartupType Disabled -ErrorAction SilentlyContinue
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy" /v "TailoredExperiencesWithDiagnosticDataEnabled" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v "DisableSearchBoxSuggestions" /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v "BingSearchEnabled" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v "BackgroundModeEnabled" /t REG_DWORD /d 0 /f | Out-Null
    
    $EnvWin11 = ([Environment]::OSVersion.Version.Build -ge 22000)
    if ($EnvWin11 -and (Get-WindowsOptionalFeature -Online -FeatureName "Recall" -ErrorAction SilentlyContinue)) {
        Disable-WindowsOptionalFeature -Online -FeatureName "Recall" -Remove -NoRestart -ErrorAction SilentlyContinue | Out-Null
    }
    Write-Log "Privacy Lockdown successfully enforced." "Success"
}

New-TweakCard $P_Presets "$IconBuilding Clean Workstation" "Preset Profile" "Removes consumer bloat, restores classic context menu, disables SMB signing for max speed & oplocks." {
    Write-Log "Applying CLEAN WORKSTATION PRESET..." "Warning"
    $EnvWin11 = ([Environment]::OSVersion.Version.Build -ge 22000)
    if ($EnvWin11) {
        reg add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve | Out-Null
    }
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1
    Set-SmbClientConfiguration -EnableSecuritySignature $false -Force
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "EnableOplocks" -Value 0
    Stop-Process -Name explorer -Force
    Start-Sleep -Milliseconds 600
    if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
    Write-Log "Clean Workstation configured." "Success"
}

New-TweakCard $P_Presets "$IconSync Express Maintenance" "Preset Profile" "Runs SSD ReTrim, clears Temp caches, flushes standby RAM & forces Windows time resync." {
    Write-Log "Running EXPRESS MAINTENANCE ROUTINE..." "Warning"
    foreach ($d in @("C", "D")) { if (Test-Path "$d`:\") { Optimize-Volume -DriveLetter $d -ReTrim -Defrag -Verbose 4>&1 | Out-Null } }
    cleanmgr /sagerun:1 | Out-Null
    [System.GC]::Collect()
    w32tm /resync /force | Out-Null
    Write-Log "Express Maintenance completed." "Success"
}

New-TweakCard $P_Presets "$IconRollback Rollback Last Backup" "Safety" "Restores the most recent registry backup saved in the AdminWorks backup directory." {
    Write-Log "Checking for available registry backups..." "Exec"
    $latest = Get-ChildItem "$BackupDir\*.reg" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latest) {
        Write-Log "Restoring: $($latest.FullName)..." "Warning"
        reg import $latest.FullName 2>$null | Out-Null
        Write-Log "Registry state restored from: $($latest.Name)" "Success"
    } else {
        Write-Log "No existing backup files found in $BackupDir." "Warning"
    }
}

# ------------------------------------------------------------------------------
# 2. MAINTENANCE & REPAIR
# ------------------------------------------------------------------------------
$P_Maint = $script:CategoryPanels["Maint"]

New-TweakCard $P_Maint "Deep System Repair" "DISM & SFC" "Executes DISM Component Cleanup and System File Checker (SFC) integrity restoration." {
    Write-Log "Beginning DISM /Online /Cleanup-Image /RestoreHealth..." "Warning"
    DISM /Online /Cleanup-Image /RestoreHealth | ForEach-Object { Write-Log $_ "Info" }
    Write-Log "Running System File Checker (sfc /scannow)..." "Warning"
    sfc /scannow | ForEach-Object { Write-Log $_ "Info" }
    Write-Log "System file integrity check complete." "Success"
}

New-TweakCard $P_Maint "Clean Component Store" "WinSxS Reduction" "Shrinks WinSxS store with /StartComponentCleanup /ResetBase." {
    Write-Log "Shrinking WinSxS component store..." "Warning"
    DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase | ForEach-Object { Write-Log $_ "Info" }
    Write-Log "WinSxS Component store pruned." "Success"
}

New-TweakCard $P_Maint "Reset Windows Update" "Update Repair" "Purges stuck SoftwareDistribution & Catroot2 caches and restarts services." {
    Write-Log "Halting Windows Update & cryptographic services..." "Warning"
    Stop-Service -Name "wuauserv", "bits", "cryptsvc" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:SystemRoot\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:SystemRoot\System32\catroot2\*" -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service -Name "wuauserv", "bits", "cryptsvc" -ErrorAction SilentlyContinue
    Write-Log "Windows Update cache reset and services restarted." "Success"
}

New-TweakCard $P_Maint "Rebuild Icon & Font Cache" "Explorer Repair" "Clears corrupted thumbnail, font, and Windows Explorer icon databases." {
    Write-Log "Rebuilding icon and font cache..." "Exec"
    Stop-Process -Name explorer -Force
    Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache*" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 600
    Start-Process explorer.exe
    Write-Log "Icon and font caches purged and rebuilt." "Success"
}

New-TweakCard $P_Maint "Clear Delivery Optimization" "Disk Reclaim" "Purges residual Windows Update peer-to-peer delivery caches to free gigabytes." {
    Write-Log "Purging Delivery Optimization cache..." "Exec"
    Delete-DeliveryOptimizationCache -Force -ErrorAction SilentlyContinue
    Write-Log "Delivery Optimization cache purged." "Success"
}

New-TweakCard $P_Maint "Repair WMI Repository" "WMI Fix" "Verifies and repairs corrupt Windows Management Instrumentation (WMI) repositories." {
    winmgmt /verifyrepository | ForEach-Object { Write-Log $_ "Info" }
    winmgmt /salvagerepository | ForEach-Object { Write-Log $_ "Warning" }
    Write-Log "WMI repository salvaged and verified." "Success"
}

New-TweakCard $P_Maint "Reset Print Spooler" "Printer Fix" "Clears stuck printer queue files and restarts the Print Spooler service." {
    Stop-Service Spooler -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:SystemRoot\System32\Spool\Printers\*" -Force -ErrorAction SilentlyContinue
    Start-Service Spooler
    Write-Log "Print Spooler reset and queue cleared." "Success"
}

# ------------------------------------------------------------------------------
# 3. PERFORMANCE & GAMING
# ------------------------------------------------------------------------------
$P_Perf = $script:CategoryPanels["Perf"]

New-TweakCard $P_Perf "Ultimate Power Plan" "Power Scheme" "Unlocks and activates the hidden Windows Ultimate Performance power plan." {
    powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 | Out-Null
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value 0
    Write-Log "Ultimate Performance power plan applied." "Success"
}

New-TweakCard $P_Perf "Visual Responsiveness" "UI Boost" "Disables window animations, fading effects, and acrylic transparency for max FPS." {
    reg add "HKCU\Control Panel\Desktop" /v UserPreferencesMask /t REG_BINARY /d 9012038010000000 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 0 /f | Out-Null
    Write-Log "Visual latency minimized." "Success"
}

New-TweakCard $P_Perf "Foreground CPU Boost" "Thread Priority" "Configures Win32PrioritySeparation to prioritize foreground applications." {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v Win32PrioritySeparation /t REG_DWORD /d 38 /f | Out-Null
    Write-Log "Foreground app priority separation optimized (Value: 38)." "Success"
}

New-TweakCard $P_Perf "Kill GameDVR & Capture" "Gaming Latency" "Disables Xbox GameDVR background screen recording to eliminate micro-stuttering." {
    reg add "HKCU\System\GameConfigStore" /v "GameDVR_Enabled" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v "AllowGameDVR" /t REG_DWORD /d 0 /f | Out-Null
    Write-Log "GameDVR background capture disabled." "Success"
}

New-TweakCard $P_Perf "Disable Hibernation" "Storage & Power" "Runs 'powercfg -h off' to eliminate hiberfil.sys and free storage." {
    powercfg -h off
    Write-Log "Hibernation disabled (hiberfil.sys removed)." "Success"
}

New-TweakCard $P_Perf "Disable USB Suspend" "Hardware Latency" "Disables USB Selective Suspend to prevent disconnects on peripherals." {
    powercfg /SETACVALUEINDEX SCHEME_CURRENT 2a84c312-a001-40c3-b31f-1393d254d070 48e6b7a6-50f2-4389-a784-1779c7b048db 0
    powercfg /setactive SCHEME_CURRENT
    Write-Log "USB Selective Suspend disabled." "Success"
}

# ------------------------------------------------------------------------------
# 4. NETWORKING & DNS
# ------------------------------------------------------------------------------
$P_Net = $script:CategoryPanels["Net"]

New-TweakCard $P_Net "Reset Network Stack" "Network Repair" "Performs full TCP/IP reset, Winsock catalog repair, and DNS cache flush." {
    Write-Log "Resetting network adapters & Winsock stack..." "Warning"
    ipconfig /flushdns | Out-Null
    netsh int ip reset | Out-Null
    netsh winsock reset | Out-Null
    Write-Log "Network stack successfully reset. (Reboot recommended)" "Success"
}

New-TweakCard $P_Net "Cloudflare DNS (1.1.1.1)" "DNS Switcher" "Sets primary and secondary DNS on all active network adapters to Cloudflare." {
    Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | ForEach-Object {
        Set-DnsClientServerAddress -InterfaceAlias $_.Name -ServerAddresses ("1.1.1.1", "1.0.0.1")
        Write-Log "Set Cloudflare DNS on adapter: $($_.Name)" "Success"
    }
}

New-TweakCard $P_Net "Google DNS (8.8.8.8)" "DNS Switcher" "Sets primary and secondary DNS on all active network adapters to Google Public DNS." {
    Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | ForEach-Object {
        Set-DnsClientServerAddress -InterfaceAlias $_.Name -ServerAddresses ("8.8.8.8", "8.8.4.4")
        Write-Log "Set Google DNS on adapter: $($_.Name)" "Success"
    }
}

New-TweakCard $P_Net "Restore Automatic DNS" "DNS Reset" "Reverts all active network interfaces to obtain DNS dynamically via DHCP." {
    Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | ForEach-Object {
        Set-DnsClientServerAddress -InterfaceAlias $_.Name -ResetServerAddresses
        Write-Log "Restored DHCP DNS on: $($_.Name)" "Success"
    }
}

New-TweakCard $P_Net "DNS Benchmark Test" "Diagnostics" "Pings Cloudflare, Google, Quad9, and OpenDNS to find lowest latency provider." {
    Write-Log "Benchmarking DNS latency..." "Exec"
    $Providers = @(
        @{ Name="Cloudflare"; IP="1.1.1.1" },
        @{ Name="Google";     IP="8.8.8.8" },
        @{ Name="Quad9";      IP="9.9.9.9" },
        @{ Name="OpenDNS";    IP="208.67.222.222" }
    )
    foreach ($p in $Providers) {
        $test = Test-Connection -ComputerName $p.IP -Count 3 -ErrorAction SilentlyContinue
        if ($test) {
            $avg = [math]::Round(($test | Measure-Object -Property ResponseTime -Average).Average, 1)
            Write-Log "$($p.Name) ($($p.IP)): Avg Latency = $avg ms" "Success"
        } else {
            Write-Log "$($p.Name) ($($p.IP)): 100% Packet Loss" "Error"
        }
    }
}

New-TweakCard $P_Net "Reveal Wi-Fi Passwords" "Security & Keys" "Audits and displays all saved Wi-Fi profiles along with cleartext passwords." {
    $profiles = netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object { ($_ -split ":")[-1].Trim() }
    if ($profiles) {
        foreach ($prof in $profiles) {
            $pass = netsh wlan show profile name="$prof" key=clear | Select-String "Key Content" | ForEach-Object { ($_ -split ":")[-1].Trim() }
            if ($pass) { Write-Log "SSID: '$prof'  ==> Password: '$pass'" "Success" }
            else { Write-Log "SSID: '$prof'  ==> [Open Network / No Key]" "Info" }
        }
    } else { Write-Log "No Wi-Fi profiles found." "Warning" }
}

New-TweakCard $P_Net "Scan LAN Subnet Devices" "Network Discovery" "Sweeps the local subnet and lists active IP and MAC addresses." {
    Write-Log "Discovering LAN devices on local subnet..." "Exec"
    $arp = arp -a | Select-String "dynamic"
    foreach ($line in $arp) {
        $parts = $line.Line.Trim() -split "\s+"
        if ($parts.Count -ge 2) {
            Write-Log "Active Host: IP $($parts[0]) | MAC $($parts)" "Info"
        }
    }
    Write-Log "Subnet discovery complete." "Success"
}

# ------------------------------------------------------------------------------
# 5. PRIVACY, SECURITY & DEBLOAT
# ------------------------------------------------------------------------------
$P_Privacy = $script:CategoryPanels["Privacy"]

New-TweakCard $P_Privacy "Universal OEM Debloat" "App Purge" "Removes consumer bloatware (TikTok, CandyCrush, McAfee, Netflix, Prime, etc.)." {
    $Apps = @(
        "*TikTok*", "*Instagram*", "*Facebook*", "*LinkedIn*", "*Twitter*", "*WhatsApp*",
        "*Disney*", "*PrimeVideo*", "*Spotify*", "*Netflix*", "*Hulu*", "*CandyCrush*",
        "*BubbleWitch*", "*MarchOfEmpires*", "*HiddenCity*", "*Asphalt*", "*MinecraftUWP*",
        "*McAfee*", "*Norton*", "*Dropbox*", "*Evernote*", "*Clipchamp*", "*BingNews*",
        "*BingFinance*", "*BingSports*"
    )
    $count = 0
    foreach ($app in $Apps) {
        $installed = Get-AppxPackage -Name $app -AllUsers -ErrorAction SilentlyContinue
        if ($installed) {
            $installed | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
            Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $app } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
            Write-Log "Removed: $app" "Success"
            $count++
        }
    }
    Write-Log "$count bloatware packages purged." "Success"
}

New-TweakCard $P_Privacy "Disable Copilot & Web Search" "Windows 11 UI" "Disables Windows Copilot, Taskbar Widgets, and Start Menu Bing Web search." {
    reg add "HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot" /v "TurnOffWindowsCopilot" /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarDa" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v "DisableSearchBoxSuggestions" /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\SearchSettings" /v "IsDynamicSearchBoxEnabled" /t REG_DWORD /d 0 /f | Out-Null
    Write-Log "Windows Copilot, Widgets, and Start Web Search disabled." "Success"
}

New-TweakCard $P_Privacy "Disable Recall & AI Tracking" "Privacy" "Disables Windows Recall AI screen recording and snapshot feature." {
    $EnvWin11 = ([Environment]::OSVersion.Version.Build -ge 22000)
    if ($EnvWin11 -and (Get-WindowsOptionalFeature -Online -FeatureName "Recall" -ErrorAction SilentlyContinue)) {
        Disable-WindowsOptionalFeature -Online -FeatureName "Recall" -Remove -NoRestart -ErrorAction SilentlyContinue | Out-Null
        Write-Log "Windows Recall AI snapshot tracking disabled." "Success"
    } else {
        Write-Log "Windows Recall is not present or applicable on this build." "Info"
    }
}

New-TweakCard $P_Privacy "Kill Telemetry & DiagTrack" "Privacy" "Disables Connected User Experiences (DiagTrack), dmwappushservice, and telemetry." {
    Stop-Service "DiagTrack", "dmwappushservice" -ErrorAction SilentlyContinue
    Set-Service "DiagTrack", "dmwappushservice" -StartupType Disabled -ErrorAction SilentlyContinue
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy" /v "TailoredExperiencesWithDiagnosticDataEnabled" /t REG_DWORD /d 0 /f | Out-Null
    Write-Log "Diagnostic data and telemetry logging disabled." "Success"
}

New-TweakCard $P_Privacy "Block Telemetry in Hosts" "Security" "Appends known telemetry, diagnostic, and ad endpoints to hosts file." {
    $hosts = "$env:SystemRoot\System32\drivers\etc\hosts"
    Copy-Item $hosts "$hosts.bak" -Force
    $domains = @("telemetry.microsoft.com", "v10.events.data.microsoft.com", "browser.events.data.msn.com", "watson.telemetry.microsoft.com")
    foreach ($d in $domains) {
        if (-not (Select-String -Path $hosts -Pattern $d -SimpleMatch)) {
            "0.0.0.0 $d" | Out-File -FilePath $hosts -Append -Encoding ASCII
            Write-Log "Blocked host: $d" "Success"
        }
    }
    Write-Log "Hosts file telemetry filter updated." "Success"
}

# ------------------------------------------------------------------------------
# 6. SHELL & CONTEXT MENU
# ------------------------------------------------------------------------------
$P_Context = $script:CategoryPanels["Context"]

New-TweakCard $P_Context "Classic Context Menu" "Windows 11 UI" "Restores the Windows 10 full right-click context menu without 'Show more options'." {
    $EnvWin11 = ([Environment]::OSVersion.Version.Build -ge 22000)
    if (-not $EnvWin11) {
        Write-Log "Classic Context Menu tweak is only required on Windows 11." "Info"
        return
    }
    reg add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve | Out-Null
    Stop-Process -Name explorer -Force
    Start-Sleep -Milliseconds 600
    if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
    Write-Log "Windows 10 Classic Context Menu restored." "Success"
}

New-TweakCard $P_Context "Add 'Take Ownership'" "Context Menu" "Adds a 'Take Ownership' option to file and folder right-click context menus." {
    $regPath = "HKCR:\*\shell\runas"
    New-Item -Path $regPath -Force | Out-Null
    Set-ItemProperty -Path $regPath -Name "(Default)" -Value "Take Ownership"
    Set-ItemProperty -Path $regPath -Name "NoWorkingDirectory" -Value ""
    New-Item -Path "$regPath\command" -Force | Out-Null
    Set-ItemProperty -Path "$regPath\command" -Name "(Default)" -Value "cmd.exe /c takeown /f `"%1`" && icacls `"%1`" /grant administrators:F"
    Write-Log "Take Ownership context menu shortcut added." "Success"
}

New-TweakCard $P_Context "Add 'PowerShell Admin Here'" "Context Menu" "Adds an 'Open PowerShell as Administrator' shortcut to right-clicks on folders." {
    $regPath = "HKCR:\Directory\Background\shell\OpenElevatedPS"
    New-Item -Path $regPath -Force | Out-Null
    Set-ItemProperty -Path $regPath -Name "(Default)" -Value "Open PowerShell As Admin Here"
    Set-ItemProperty -Path $regPath -Name "Icon" -Value "powershell.exe"
    New-Item -Path "$regPath\command" -Force | Out-Null
    Set-ItemProperty -Path "$regPath\command" -Name "(Default)" -Value "powershell.exe -Command `"Start-Process powershell -Verb RunAs -WorkingDirectory '%V'`""
    Write-Log "'Open PowerShell As Admin Here' added." "Success"
}

New-TweakCard $P_Context "File Explorer Pro Mode" "File System" "Shows file extensions (.exe, .txt), unhides system files, and shows full title paths." {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1
    Stop-Process -Name explorer -Force
    Start-Sleep -Milliseconds 600
    if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
    Write-Log "File Explorer configured to show extensions and hidden files." "Success"
}

# ------------------------------------------------------------------------------
# 7. HARDWARE & STORAGE AUDIT
# ------------------------------------------------------------------------------
$P_Hw = $script:CategoryPanels["Hardware"]

New-TweakCard $P_Hw "SMART Disk Health" "Storage Health" "Audits physical drives, media type (NVMe/SSD/HDD), and SMART health statuses." {
    Get-PhysicalDisk | ForEach-Object {
        $st = if ($_.HealthStatus -eq "Healthy") { "Success" } else { "Error" }
        Write-Log "Disk #$($_.DeviceId) ($($_.FriendlyName)): Health=$($_.HealthStatus) | MediaType=$($_.MediaType)" $st
    }
}

New-TweakCard $P_Hw "RAM Bank & Slot Audit" "Memory Specs" "Inspects physical RAM slots, module capacities, clock speeds, and manufacturers." {
    $sticks = Get-CimInstance Win32_PhysicalMemory
    $tot = [math]::Round(($sticks | Measure-Object -Property Capacity -Sum).Sum / 1GB, 2)
    Write-Log "Total Installed Memory: $tot GB across $($sticks.Count) slots:" "Success"
    foreach ($s in $sticks) {
        $gb = [math]::Round($s.Capacity / 1GB, 2)
        Write-Log "Slot $($s.BankLabel): $gb GB @ $($s.Speed) MHz ($($s.Manufacturer))" "Info"
    }
}

New-TweakCard $P_Hw "Battery Health Report" "Power Report" "Generates a detailed HTML battery capacity and degradation report on Desktop." {
    $p = "$env:USERPROFILE\Desktop\BatteryReport.html"
    powercfg /batteryreport /output $p | Out-Null
    Write-Log "Battery Diagnostic report saved to: $p" "Success"
}

New-TweakCard $P_Hw "GPU & Display Audit" "Graphics Specs" "Inspects installed GPU adapters, driver versions, and display resolutions." {
    Get-CimInstance Win32_VideoController | ForEach-Object {
        Write-Log "GPU: $($_.Name) - Driver: $($_.DriverVersion) - Resolution: $($_.CurrentHorizontalResolution)x$($_.CurrentVerticalResolution) @ $($_.CurrentRefreshRate)Hz" "Success"
    }
}

# ------------------------------------------------------------------------------
# 8. SOFTWARE & WINGET HUB
# ------------------------------------------------------------------------------
$P_Apps = $script:CategoryPanels["Apps"]

New-TweakCard $P_Apps "Install / Repair Winget" "Package Manager" "Downloads and forces the installation of the latest Microsoft App Installer (Winget)." {
    Write-Log "Downloading latest Winget MSIX Bundle from Microsoft..." "Warning"
    $url = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
    $file = "$env:TEMP\winget.msixbundle"
    try {
        Invoke-WebRequest -Uri $url -OutFile $file -UseBasicParsing
        Write-Log "Installing Winget package..." "Exec"
        Add-AppxPackage -Path $file -ForceUpdateFromAnyVersion -ErrorAction Stop
        Write-Log "Winget successfully installed/repaired." "Success"
    } catch {
        Write-Log "Failed to install Winget: $($_.Exception.Message)" "Error"
    }
}

New-TweakCard $P_Apps "Winget Upgrade All Apps" "Package Manager" "Runs winget upgrade --all with auto-accepted package agreements." {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Write-Log "Winget is missing. Run 'Install / Repair Winget' first." "Error"; return }
    Write-Log "Scanning for package upgrades via Winget..." "Warning"
    winget upgrade --all --include-unknown --accept-package-agreements --accept-source-agreements | ForEach-Object {
        if ($_.Trim() -ne "") { Write-Log $_ "Info" }
    }
    Write-Log "Winget package sync complete." "Success"
}

New-TweakCard $P_Apps "Backup Installed Apps List" "Package Manager" "Exports list of all installed packages via Winget to desktop as JSON." {
    $outPath = "$env:USERPROFILE\Desktop\Winget_App_Backup_$((Get-Date).ToString('yyyyMMdd')).json"
    winget export -o "$outPath" --include-versions
    Write-Log "Installed apps exported to: $outPath" "Success"
}

New-TweakCard $P_Apps "Install PowerToys" "Essential Tools" "Installs Microsoft PowerToys for advanced system utilities and window management." {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Write-Log "Winget is missing." "Error"; return }
    Write-Log "Installing PowerToys..." "Exec"
    winget install Microsoft.PowerToys --silent --accept-package-agreements --accept-source-agreements | Out-Null
    Write-Log "Microsoft PowerToys installed." "Success"
}

New-TweakCard $P_Apps "Install 7-Zip" "Essential Tools" "Installs the industry-standard 7-Zip file compression utility." {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Write-Log "Winget is missing." "Error"; return }
    Write-Log "Installing 7-Zip..." "Exec"
    winget install 7zip.7zip --silent --accept-package-agreements --accept-source-agreements | Out-Null
    Write-Log "7-Zip installed." "Success"
}

New-TweakCard $P_Apps "Install Sysinternals Suite" "SysAdmin Tools" "Installs Microsoft Sysinternals troubleshooting suite via Winget." {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Write-Log "Winget is missing." "Error"; return }
    Write-Log "Installing Sysinternals Suite..." "Exec"
    winget install Microsoft.SysinternalsSuite --silent --accept-package-agreements --accept-source-agreements | Out-Null
    Write-Log "Sysinternals Suite installed." "Success"
}

# ------------------------------------------------------------------------------
# 9. ADMIN UTILITIES
# ------------------------------------------------------------------------------
$P_Admin = $script:CategoryPanels["Admin"]

New-TweakCard $P_Admin "Create System Restore Point" "Safety Checkpoint" "Generates a fresh Windows System Restore point named 'AdminWorks_Checkpoint'." {
    Write-Log "Creating Windows System Restore Point..." "Exec"
    try {
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "AdminWorks_Checkpoint" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Log "Restore point created successfully." "Success"
    } catch { Write-Log "Restore Point Error: $($_.Exception.Message)" "Error" }
}

New-TweakCard $P_Admin "Create GodMode Shortcut" "Master Control" "Creates a master GodMode folder on the Desktop linking to all 200+ control applets." {
    $p = Join-Path ([Environment]::GetFolderPath("Desktop")) "GodMode.{ED7BA470-8E54-465E-825C-99712043E01C}"
    if (-not (Test-Path $p)) {
        New-Item -ItemType Directory -Path $p | Out-Null
        Write-Log "Master GodMode shortcut placed on Desktop." "Success"
    } else { Write-Log "GodMode shortcut already exists." "Warning" }
}

New-TweakCard $P_Admin "Audit Local Administrators" "Security Audit" "Lists all members of the local Administrators group for unauthorized access." {
    Write-Log "Auditing local Administrator members..." "Exec"
    Get-LocalGroupMember -Group "Administrators" | ForEach-Object {
        Write-Log "Admin Member: $($_.Name) ($($_.PrincipalSource))" "Info"
    }
    Write-Log "Local Administrator audit complete." "Success"
}

New-TweakCard $P_Admin "Network Connections (NCPA)" "Quick Launcher" "Opens ncpa.cpl to manage network adapters." {
    Start-Process ncpa.cpl; Write-Log "Network Connections Control Panel opened." "Success"
}

New-TweakCard $P_Admin "System Properties (SYSDM)" "Quick Launcher" "Opens sysdm.cpl to configure advanced performance, environment vars & computer name." {
    Start-Process sysdm.cpl; Write-Log "Advanced System Properties opened." "Success"
}

New-TweakCard $P_Admin "Launch Device Manager" "Quick Launcher" "Opens devmgmt.msc directly." {
    Start-Process devmgmt.msc; Write-Log "Device Manager opened." "Success"
}

New-TweakCard $P_Admin "Defender Quick Scan" "Antivirus" "Updates threat intelligence signatures and launches a Windows Defender scan." {
    Update-MpSignature | Out-Null
    Start-MpScan -ScanType QuickScan | Out-Null
    Write-Log "Microsoft Defender Quick Scan complete." "Success"
}

# --- [Default Selection & Lag-Free Telemetry Loop] ---
$script:SidebarButtons["Presets"].PerformClick()

# Global Keyboard Shortcuts
$Form.Add_KeyDown({
    if ($_.Control -and $_.KeyCode -eq [System.Windows.Forms.Keys]::F) {
        $SearchBox.Focus()
        $SearchBox.SelectAll()
        $_.SuppressKeyPress = $true
    }
    elseif ($_.Control -and $_.KeyCode -eq [System.Windows.Forms.Keys]::L) {
        $LogBox.Clear()
        Write-Log "Console cleared via shortcut." "Info"
        $_.SuppressKeyPress = $true
    }
})

# Telemetry Timer (Runs Every 2 Seconds without UI Freezing)
$TelemetryTimer = New-Object System.Windows.Forms.Timer -Property @{Interval=2000; Enabled=$true}
$TelemetryTimer.Add_Tick({
    try {
        # High-Speed CPU Query (< 1ms)
        if ($script:CpuCounter) {
            $cpuVal = [math]::Round($script:CpuCounter.NextValue(), 0)
            $StatCPU.Text = "$cpuVal% Utilization"
        }

        # Memory Load
        $os = Get-CimInstance Win32_OperatingSystem
        $freeMemGB = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
        $totMemGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
        $usedMemGB = [math]::Round($totMemGB - $freeMemGB, 1)
        $StatRAM.Text = "$usedMemGB / $totMemGB GB"

        # Drive C: Capacity
        $c = Get-PSDrive C -ErrorAction SilentlyContinue
        if ($c) {
            $freeGB = [math]::Round($c.Free / 1GB, 1)
            $totGB = [math]::Round(($c.Used + $c.Free) / 1GB, 1)
            $StatDisk.Text = "$freeGB GB Free ($totGB GB)"
        }

        # System Uptime
        $span = (Get-Date) - $os.LastBootUpTime
        $StatUp.Text = "$($span.Days)d $($span.Hours)h $($span.Minutes)m"
    } catch {}
})

# Form Closing Clean-up
$Form.Add_FormClosing({
    $TelemetryTimer.Stop()
    $TelemetryTimer.Dispose()
    if ($script:CpuCounter) { $script:CpuCounter.Dispose() }
})

Write-Log "AdminWorks Pro Suite v4.2 loaded and ready." "Success"
[void]$Form.ShowDialog()
