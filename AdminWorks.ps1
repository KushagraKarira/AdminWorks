<#
================================================================================
  ADMINWORKS PRO v4.1 - Enterprise Windows Administration & Optimization Suite
  Compatible with Windows 10 & Windows 11
================================================================================
#>

# --- [Self-Elevate to Administrator] ---
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList "-ExecutionPolicy Bypass", "-File `"$PSCommandPath`"" -Verb RunAs
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
    CardHover     = [System.Drawing.Color]::FromArgb(38, 46, 64)       # Card Hover
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

# --- [Main Form Window] ---
$Form = New-Object System.Windows.Forms.Form
$Form.Text            = "ADMINWORKS PRO"
$Form.Size            = New-Object System.Drawing.Size(1320, 940)
$Form.BackColor       = $script:Theme.Bg
$Form.StartPosition   = "CenterScreen"
$Form.FormBorderStyle = "None"
$Form.MinimumSize     = New-Object System.Drawing.Size(1150, 780)

try {
    $bf = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic
    $prop = $Form.GetType().GetProperty("DoubleBuffered", $bf)
    if ($prop) { $prop.SetValue($Form, $true, $null) }
} catch {}

# Apply Dark Mode Frame Attribute (Supports Windows 11 and Windows 10)
try {
    $darkValue = 1
    # Try modern DWM attribute 20 (Windows 11 / Windows 10 2004+)
    $res = [NativeMethods]::DwmSetWindowAttribute($Form.Handle, 20, [ref]$darkValue, 4)
    if ($res -ne 0) {
        # Fallback to older DWM attribute 19 (Windows 10 1809/1903)
        [NativeMethods]::DwmSetWindowAttribute($Form.Handle, 19, [ref]$darkValue, 4) | Out-Null
    }
} catch {}

# --- [Header: Brand, System Badge, Search, Window Controls] ---
# Brand Label
$TitleLbl = New-Object System.Windows.Forms.Label -Property @{
    Text      = "⚡ ADMINWORKS"
    Location  = New-Object System.Drawing.Point(22, 14); AutoSize = $true
    ForeColor = $script:Theme.TextMain
    Font      = New-Object System.Drawing.Font($GlobalFont, 12.5, [System.Drawing.FontStyle]::Bold)
}
$TitleSub = New-Object System.Windows.Forms.Label -Property @{
    Text      = "ENTERPRISE SUITE v4.1  •  BY KUSHAGRA KARIRA"
    Location  = New-Object System.Drawing.Point(24, 40); AutoSize = $true
    ForeColor = $script:Theme.AccentGlow
    Font      = New-Object System.Drawing.Font($GlobalFont, 7.5, [System.Drawing.FontStyle]::Bold)
    Cursor    = [System.Windows.Forms.Cursors]::Hand
}
# Make it clickable to open the GitHub repo
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

# Brand Label
$TitleLbl = New-Object System.Windows.Forms.Label -Property @{
    Text      = "⚡ ADMINWORKS"
    Location  = New-Object System.Drawing.Point(22, 14); AutoSize = $true
    ForeColor = $script:Theme.TextMain
    Font      = New-Object System.Drawing.Font($GlobalFont, 12.5, [System.Drawing.FontStyle]::Bold)
}
$TitleSub = New-Object System.Windows.Forms.Label -Property @{
    Text      = "ENTERPRISE SUITE v4.1"
    Location  = New-Object System.Drawing.Point(24, 40); AutoSize = $true
    ForeColor = $script:Theme.AccentGlow
    Font      = New-Object System.Drawing.Font($GlobalFont, 7.5, [System.Drawing.FontStyle]::Bold)
}
$Header.Controls.AddRange(@($TitleLbl, $TitleSub))

# System Info Badge
$LocalIP = "Scanning..."
try {
    $ipObj = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -match 'Dhcp|Manual' -and $_.InterfaceAlias -notmatch 'Loopback|Virtual|vEthernet' } | Select-Object -First 1
    if ($ipObj) { $LocalIP = $ipObj.IPAddress } else { $LocalIP = "No LAN" }
} catch { $LocalIP = "Offline" }

$OSInfo = (Get-CimInstance Win32_OperatingSystem)
$SysBadge = New-Object System.Windows.Forms.Label -Property @{
    Text      = "$($env:COMPUTERNAME)  •  IP: $LocalIP  •  $($OSInfo.Caption)"
    Location  = New-Object System.Drawing.Point(240, 26); Size = New-Object System.Drawing.Size(430, 20)
    ForeColor = $script:Theme.TextMuted; Font = New-Object System.Drawing.Font($GlobalFont, 8.5)
}
$Header.Controls.Add($SysBadge)

# Search Input Container
$SearchPanel = New-Object System.Windows.Forms.Panel -Property @{
    Location  = New-Object System.Drawing.Point(690, 18); Size = New-Object System.Drawing.Size(340, 34)
    BackColor = $script:Theme.Sidebar; Anchor = [System.Windows.Forms.AnchorStyles]"Top, Right"
}
$SearchBox = New-Object System.Windows.Forms.TextBox -Property @{
    BorderStyle = "None"; BackColor = $script:Theme.Sidebar; ForeColor = $script:Theme.TextMain
    Font = New-Object System.Drawing.Font($GlobalFont, 9.5); Location = New-Object System.Drawing.Point(12, 8)
    Width = 315; Text = "🔍 Search tools, tweaks & features..."
}
$SearchBox.Add_GotFocus({ if ($this.Text -eq "🔍 Search tools, tweaks & features...") { $this.Text = ""; $this.ForeColor = $script:Theme.TextMain } })
$SearchBox.Add_LostFocus({ if ([string]::IsNullOrWhiteSpace($this.Text)) { $this.Text = "🔍 Search tools, tweaks & features..."; $this.ForeColor = $script:Theme.TextSubtle } })
$SearchPanel.Controls.Add($SearchBox)
$Header.Controls.Add($SearchPanel)

# Window Controls (Minimize, Maximize, Close)
$CtrlBox = New-Object System.Windows.Forms.Panel -Property @{Dock="Right"; Width=140}
$Header.Controls.Add($CtrlBox)

function New-WindowBtn($Text, $X, $HoverColor, $Action) {
    $B = New-Object System.Windows.Forms.Button -Property @{
        Text = $Text; Size = New-Object System.Drawing.Size(42, 34); 
        Location = New-Object System.Drawing.Point($X, 18); FlatStyle = "Flat"; 
        ForeColor = $script:Theme.TextMuted; Tag = $HoverColor
    }
    $B.FlatAppearance.BorderSize = 0
    $B.Add_Click($Action)
    $B.Add_MouseEnter({ $this.BackColor = $this.Tag; $this.ForeColor = [System.Drawing.Color]::White })
    $B.Add_MouseLeave({ $this.BackColor = [System.Drawing.Color]::Transparent; $this.ForeColor = $script:Theme.TextMuted })
    $CtrlBox.Controls.Add($B)
}
New-WindowBtn "✕" 90 $script:Theme.Danger { $Form.Close() }
New-WindowBtn "⬜" 46 $script:Theme.CardHover { if ($Form.WindowState -eq "Maximized") { $Form.WindowState = "Normal" } else { $Form.WindowState = "Maximized" } }
New-WindowBtn "—" 2 $script:Theme.CardHover { $Form.WindowState = "Minimized" }

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
    Height    = 210
    BackColor = $script:Theme.TerminalBg
    Padding   = New-Object System.Windows.Forms.Padding(20, 6, 20, 14)
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

$LogBox = New-Object System.Windows.Forms.RichTextBox -Property @{
    Dock = "Fill"; BackColor = [System.Drawing.Color]::FromArgb(5, 6, 8)
    ForeColor = $script:Theme.TextMain; BorderStyle = "None"; ReadOnly = $true
    Font = New-Object System.Drawing.Font("Consolas", 9.5)
}
$LogContainer.Controls.Add($LogBox)
$LogBox.BringToFront()

function New-TermBtn($Text, $X, $Action) {
    $Btn = New-Object System.Windows.Forms.Button -Property @{
        Text = $Text; Size = New-Object System.Drawing.Size(85, 24); Location = New-Object System.Drawing.Point($X, 4)
        FlatStyle = "Flat"; BackColor = $script:Theme.Card; ForeColor = $script:Theme.TextMuted
        Font = New-Object System.Drawing.Font($GlobalFont, 7.5, [System.Drawing.FontStyle]::Bold)
        Anchor = [System.Windows.Forms.AnchorStyles]"Top, Right"
    }
    $Btn.FlatAppearance.BorderSize = 0
    $Btn.Add_MouseEnter({ $this.BackColor = $script:Theme.CardHover; $this.ForeColor = $script:Theme.TextMain })
    $Btn.Add_MouseLeave({ $this.BackColor = $script:Theme.Card; $this.ForeColor = $script:Theme.TextMuted })
    $Btn.Add_Click($Action)
    $TermHeader.Controls.Add($Btn)
}

# Collapse/Expand Toggle
$BtnToggleDrawer = New-Object System.Windows.Forms.Button -Property @{
    Text = "▼ COLLAPSE"; Size = New-Object System.Drawing.Size(95, 24); Location = New-Object System.Drawing.Point(870, 4)
    FlatStyle = "Flat"; BackColor = $script:Theme.Card; ForeColor = $script:Theme.AccentGlow
    Font = New-Object System.Drawing.Font($GlobalFont, 7.5, [System.Drawing.FontStyle]::Bold)
    Anchor = [System.Windows.Forms.AnchorStyles]"Top, Right"
}
$BtnToggleDrawer.FlatAppearance.BorderSize = 0
$BtnToggleDrawer.Add_Click({
    if ($LogContainer.Height -gt 40) {
        $LogContainer.Height = 36
        $BtnToggleDrawer.Text = "▲ EXPAND"
    } else {
        $LogContainer.Height = 210
        $BtnToggleDrawer.Text = "▼ COLLAPSE"
    }
})
$TermHeader.Controls.Add($BtnToggleDrawer)

New-TermBtn "CLEAR" 975 { $LogBox.Clear(); Write-Log "Console cleared." "Info" }
New-TermBtn "COPY ALL" 1065 { [System.Windows.Forms.Clipboard]::SetText($LogBox.Text); Write-Log "Console output copied to clipboard." "Success" }
New-TermBtn "EXPORT" 1155 { 
    $Path = "$env:USERPROFILE\Desktop\AdminWorks_Log_$((Get-Date).ToString('yyyy-MM-dd_HHmmss')).txt"
    $LogBox.Text | Out-File -FilePath $Path -Encoding UTF8
    Write-Log "Log successfully exported to: $Path" "Success"
}

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

# --- [Central Work Area & Telemetry] ---
$MainArea = New-Object System.Windows.Forms.Panel -Property @{
    Dock      = "Fill"
    BackColor = $script:Theme.Bg
}
$Form.Controls.Add($MainArea)
$MainArea.BringToFront()

# Telemetry Bar
$TelemetryBar = New-Object System.Windows.Forms.Panel -Property @{
    Dock      = "Top"
    Height    = 66
    BackColor = $script:Theme.SidebarActive
    Padding   = New-Object System.Windows.Forms.Padding(16, 8, 16, 8)
}
$MainArea.Controls.Add($TelemetryBar)

function New-StatWidget($Title, $X, $Width) {
    $P = New-Object System.Windows.Forms.Panel -Property @{
        Location = New-Object System.Drawing.Point($X, 8); Size = New-Object System.Drawing.Size($Width, 48)
        BackColor = $script:Theme.Card
    }
    $LTitle = New-Object System.Windows.Forms.Label -Property @{
        Text = $Title; Location = New-Object System.Drawing.Point(12, 6); AutoSize = $true
        ForeColor = $script:Theme.TextMuted; Font = New-Object System.Drawing.Font($GlobalFont, 7.5, [System.Drawing.FontStyle]::Bold)
    }
    $LVal = New-Object System.Windows.Forms.Label -Property @{
        Text = "--"; Location = New-Object System.Drawing.Point(12, 22); Size = New-Object System.Drawing.Size(($Width - 24), 22)
        ForeColor = $script:Theme.TextMain; Font = New-Object System.Drawing.Font($GlobalFont, 9.5, [System.Drawing.FontStyle]::Bold)
    }
    $P.Controls.AddRange(@($LTitle, $LVal))
    $TelemetryBar.Controls.Add($P)
    return $LVal
}

$StatCPU  = New-StatWidget "CPU LOAD" 20 220
$StatRAM  = New-StatWidget "MEMORY USED" 250 240
$StatDisk = New-StatWidget "SYSTEM DRIVE (C:)" 500 240
$StatUp   = New-StatWidget "SYSTEM UPTIME" 750 240

# --- [Card Engine & Registration Setup] ---
$script:AllCards = New-Object System.Collections.Generic.List[PSObject]
$script:CategoryPanels = @{}
$script:SidebarButtons = @{}

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
        Font      = New-Object System.Drawing.Font($GlobalFont, 10, [System.Drawing.FontStyle]::Bold)
    }

    $DescLbl = New-Object System.Windows.Forms.Label -Property @{
        Text      = $Desc
        Location  = New-Object System.Drawing.Point(14, 54); Size = New-Object System.Drawing.Size(295, 42)
        ForeColor = $script:Theme.TextMuted
        Font      = New-Object System.Drawing.Font($GlobalFont, 8)
    }

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
    }
    $Btn.FlatAppearance.BorderSize = 0
    $Btn.Add_MouseEnter({ if ($this.Enabled) { $this.BackColor = $script:Theme.Accent; $this.ForeColor = [System.Drawing.Color]::White } })
    $Btn.Add_MouseLeave({ if ($this.Enabled) { $this.BackColor = $script:Theme.SidebarActive; $this.ForeColor = $script:Theme.TextMain } })

    # Asynchronous Thread Execution
    $Btn.Add_Click({
        $B = $this
        $OriginalText = $B.Text
        $ActionCode = $B.Tag

        $B.Enabled = $false
        $B.Text = "RUNNING..."
        $B.BackColor = $script:Theme.Warning
        $B.ForeColor = [System.Drawing.Color]::Black

        $PS = [powershell]::Create().AddScript({
            param($CodeStr, $LogBox, $Theme, $BackupDir)
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

            # Helper for Safe Registry Modification with Auto-Backup
            function Backup-RegKey ($KeyPath, $BackupName) {
                try {
                    $ts = (Get-Date).ToString('yyyyMMdd_HHmmss')
                    $file = "$BackupDir\Backup_${BackupName}_$ts.reg"
                    reg export $KeyPath $file /y 2>$null | Out-Null
                    Write-Log "Registry safety backup saved: $file" "Info"
                } catch {}
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
        $Timer.Interval = 400
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

# --- [Sidebar Tabs Definition] ---
$TabList = @(
    @{ Id = "Presets";   Name = "★  Preset Profiles"; Desc = "1-Click Optimization & Configuration Profiles" },
    @{ Id = "Maint";     Name = "⚙  Maintenance";     Desc = "DISM, SFC, Component cleanup, Update fixes" },
    @{ Id = "Perf";      Name = "⚡  Performance";     Desc = "Power plans, CPU priority, latency & RAM tweaks" },
    @{ Id = "Net";       Name = "☁  Network & DNS";   Desc = "DNS benchmarks, Wi-Fi keys, TCP stack & ports" },
    @{ Id = "Privacy";   Name = "🔒  Privacy & Bloat"; Desc = "Telemetry removal, Bing & OEM debloat, AI Recall" },
    @{ Id = "Context";   Name = "▤  Shell & Explorer";Desc = "Context menus, file extensions & UI tweaks" },
    @{ Id = "Hardware";  Name = "⛁  Hardware Audit";  Desc = "SMART drives, RAM banks, battery & GPU stats" },
    @{ Id = "Apps";      Name = "❖  Software Hub";    Desc = "Winget package updater & curated installer" },
    @{ Id = "Admin";     Name = "⚒  Admin Utilities"; Desc = "GodMode, Windows tools hub & System Restore" }
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
    }
    $NavBtn.FlatAppearance.BorderSize = 0
    $NavBtn.Add_Click({
        $TargetId = $this.Tag
        foreach ($k in $script:CategoryPanels.Keys) { $script:CategoryPanels[$k].Visible = ($k -eq $TargetId) }
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

# Real-Time Search Engine
$SearchBox.Add_TextChanged({
    $Query = $SearchBox.Text.Trim().ToLower()
    if ($Query -eq "🔍 search tools, tweaks & features..." -or [string]::IsNullOrWhiteSpace($Query)) {
        foreach ($card in $script:AllCards) { $card.Panel.Visible = $true }
        return
    }
    foreach ($card in $script:AllCards) {
        $Match = ($card.Title.ToLower() -like "*$Query*") -or 
                 ($card.Description.ToLower() -like "*$Query*") -or 
                 ($card.Category.ToLower() -like "*$Query*")
        $card.Panel.Visible = $Match
    }
})

# ==============================================================================
# FEATURE REGISTRATION & PRESETS
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. 1-CLICK PRESET PROFILES
# ------------------------------------------------------------------------------
$P_Presets = $script:CategoryPanels["Presets"]

New-TweakCard $P_Presets "🎮 Gamer Mode Preset" "Preset Profile" "Applies Ultimate Power Plan, disables GameDVR, prioritizes foreground threads & frees RAM." {
    Write-Log "Applying GAMER MODE PRESET..." "Warning"
    powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 | Out-Null
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value 0
    reg add "HKCU\System\GameConfigStore" /v "GameDVR_Enabled" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v "AllowGameDVR" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v Win32PrioritySeparation /t REG_DWORD /d 38 /f | Out-Null
    [System.GC]::Collect()
    Write-Log "Gamer Mode Profile successfully configured and active." "Success"
}

New-TweakCard $P_Presets "🛡️ Privacy Lockdown" "Preset Profile" "Disables telemetry, DiagTrack, Recall AI, Bing Start Search, Ad ID & Edge Background." {
    Write-Log "Applying PRIVACY LOCKDOWN PRESET..." "Warning"
    Stop-Service "DiagTrack", "dmwappushservice" -ErrorAction SilentlyContinue
    Set-Service "DiagTrack", "dmwappushservice" -StartupType Disabled -ErrorAction SilentlyContinue
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy" /v "TailoredExperiencesWithDiagnosticDataEnabled" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v "DisableSearchBoxSuggestions" /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v "BingSearchEnabled" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v "BackgroundModeEnabled" /t REG_DWORD /d 0 /f | Out-Null
    
    # Conditional Windows 11 Recall AI Removal
    $EnvWin11 = ([Environment]::OSVersion.Version.Build -ge 22000)
    if ($EnvWin11 -and (Get-WindowsOptionalFeature -Online -FeatureName "Recall" -ErrorAction SilentlyContinue)) {
        Disable-WindowsOptionalFeature -Online -FeatureName "Recall" -Remove -NoRestart -ErrorAction SilentlyContinue | Out-Null
    }
    
    Write-Log "Privacy Lockdown successfully enforced." "Success"
}

New-TweakCard $P_Presets "🏢 Clean Workstation" "Preset Profile" "Removes consumer bloat, restores classic context menu, enables file extensions & optimizes SMB." {
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
    Write-Log "Clean Workstation profile configured." "Success"
}

New-TweakCard $P_Presets "🔄 Express Maintenance" "Preset Profile" "Runs SSD ReTrim, clears Temp caches, flushes standby RAM & forces Windows time resync." {
    Write-Log "Running EXPRESS MAINTENANCE ROUTINE..." "Warning"
    foreach ($d in @("C", "D")) { if (Test-Path "$d`:\") { Optimize-Volume -DriveLetter $d -ReTrim -Defrag -Verbose 4>&1 | Out-Null } }
    cleanmgr /sagerun:1 | Out-Null
    [System.GC]::Collect()
    w32tm /resync /force | Out-Null
    Write-Log "Express Maintenance completed." "Success"
}

New-TweakCard $P_Presets "⏪ Rollback Last Backup" "Safety" "Restores the most recent registry backup saved in the AdminWorks backup directory." {
    Write-Log "Checking for available registry backups..." "Exec"
    $latest = Get-ChildItem "$BackupDir\*.reg" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
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

New-TweakCard $P_Maint "Repair WMI Repository" "WMI Fix" "Verifies and repairs corrupt Windows Management Instrumentation (WMI) repositories." {
    winmgmt /verifyrepository | ForEach-Object { Write-Log $_ "Info" }
    winmgmt /salvagerepository | ForEach-Object { Write-Log $_ "Warning" }
    Write-Log "WMI repository salvaged and verified." "Success"
}

New-TweakCard $P_Maint "Wipe Event Logs" "Log Cleanup" "Purges all active Windows Event Viewer application, security, and system logs." {
    wevtutil el | ForEach-Object { wevtutil cl "$_"; Write-Log "Cleared: $_" "Info" }
    Write-Log "All Windows Event Logs purged." "Success"
}

New-TweakCard $P_Maint "Reset Print Spooler" "Printer Fix" "Clears stuck printer queue files and restarts the Print Spooler service." {
    Stop-Service Spooler -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:SystemRoot\System32\Spool\Printers\*" -Force -ErrorAction SilentlyContinue
    Start-Service Spooler
    Write-Log "Print Spooler reset and queue cleared." "Success"
}

New-TweakCard $P_Maint "Resync Windows Clock" "Time NTP" "Forces Windows Time service to resync with time.windows.com NTP server." {
    w32tm /config /manualpeerlist:"time.windows.com" /syncfromflags:manual /reliable:YES /update | Out-Null
    Restart-Service w32time -ErrorAction SilentlyContinue
    w32tm /resync /force | ForEach-Object { Write-Log $_ "Info" }
    Write-Log "Time synchronization forced." "Success"
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

New-TweakCard $P_Perf "Never Sleep on AC" "Power Timeout" "Prevents the system, display, and network card from going to sleep while plugged in." {
    powercfg -change -standby-timeout-ac 0
    powercfg -change -monitor-timeout-ac 0
    Write-Log "AC sleep and display timeouts set to NEVER." "Success"
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
            Write-Log "Active LAN Host: IP $($parts[0]) | MAC $($parts[1])" "Info"
        }
    }
    Write-Log "Subnet discovery scan complete." "Success"
}

New-TweakCard $P_Net "Listening Ports & PID" "Diagnostics" "Scans active listening TCP/UDP endpoints and identifies owning processes." {
    $ports = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Select-Object LocalAddress, LocalPort, OwningProcess -Unique | Sort-Object LocalPort
    foreach ($p in ($ports | Select-Object -First 10)) {
        $pName = (Get-Process -Id $p.OwningProcess -ErrorAction SilentlyContinue).ProcessName
        Write-Log "Port $($p.LocalPort) on $($p.LocalAddress) -> Process: $pName (PID: $($p.OwningProcess))" "Info"
    }
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

New-TweakCard $P_Privacy "Block Telemetry in Hosts" "Security" "Appends known telemetry, diagnostic, and ad endpoints to C:\Windows\System32\drivers\etc\hosts." {
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

New-TweakCard $P_Apps "Install / Repair Winget" "Package Manager" "Downloads and forces the installation of the latest Microsoft App Installer (Winget) from GitHub." {
    Write-Log "Downloading latest Winget MSIX Bundle from Microsoft..." "Warning"
    $url = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
    $file = "$env:TEMP\winget.msixbundle"
    try {
        Invoke-WebRequest -Uri $url -OutFile $file -UseBasicParsing
        Write-Log "Installing Winget package..." "Exec"
        Add-AppxPackage -Path $file -ForceUpdateFromAnyVersion -ErrorAction Stop
        Write-Log "Winget (App Installer) successfully installed/repaired." "Success"
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

New-TweakCard $P_Apps "Install WinToys" "System Tweaker" "Installs WinToys, a powerful GUI optimizer and debloater for Windows." {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Write-Log "Winget is missing. Run 'Install / Repair Winget' first." "Error"; return }
    Write-Log "Installing WinToys via Microsoft Store..." "Exec"
    winget install --id 9P8LTPGCBZXD --silent --accept-package-agreements --accept-source-agreements | Out-Null
    Write-Log "WinToys successfully installed." "Success"
}

New-TweakCard $P_Apps "Install 7-Zip" "Essential Tools" "Installs the industry-standard 7-Zip file compression utility." {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Write-Log "Winget is missing." "Error"; return }
    Write-Log "Installing 7-Zip..." "Exec"
    winget install 7zip.7zip --silent --accept-package-agreements --accept-source-agreements | Out-Null
    Write-Log "7-Zip installed." "Success"
}

New-TweakCard $P_Apps "Install PowerToys" "Essential Tools" "Installs Microsoft PowerToys for advanced system utilities and window management." {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Write-Log "Winget is missing." "Error"; return }
    Write-Log "Installing PowerToys..." "Exec"
    winget install Microsoft.PowerToys --silent --accept-package-agreements --accept-source-agreements | Out-Null
    Write-Log "Microsoft PowerToys installed." "Success"
}

New-TweakCard $P_Apps "Install Nerd Fonts" "Developer Fonts" "Installs Cascadia Code & FiraCode Nerd Fonts for terminal aesthetics." {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Write-Log "Winget is missing." "Error"; return }
    Write-Log "Installing Cascadia & FiraCode Nerd Fonts..." "Exec"
    winget install ryanoasis.NerdFonts.CascadiaCode --silent --accept-package-agreements | Out-Null
    winget install ryanoasis.NerdFonts.FiraCode --silent --accept-package-agreements | Out-Null
    Write-Log "Nerd Fonts successfully installed." "Success"
}

New-TweakCard $P_Apps "Install Dev Tools" "Dev Suite" "Installs Git for Windows and Visual Studio Code via Winget." {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Write-Log "Winget is missing." "Error"; return }
    Write-Log "Installing Git & VSCode..." "Exec"
    winget install Git.Git --silent --accept-package-agreements --accept-source-agreements | Out-Null
    winget install Microsoft.VisualStudioCode --silent --accept-package-agreements --accept-source-agreements | Out-Null
    Write-Log "Git and Visual Studio Code installed." "Success"
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

New-TweakCard $P_Admin "Launch Device Manager" "Quick Launcher" "Opens devmgmt.msc directly." {
    Start-Process devmgmt.msc; Write-Log "Device Manager opened." "Success"
}

New-TweakCard $P_Admin "Launch Services Console" "Quick Launcher" "Opens services.msc directly." {
    Start-Process services.msc; Write-Log "Services Management Console opened." "Success"
}

New-TweakCard $P_Admin "Launch Disk Management" "Quick Launcher" "Opens diskmgmt.msc directly." {
    Start-Process diskmgmt.msc; Write-Log "Disk Management Console opened." "Success"
}

New-TweakCard $P_Admin "Defender Quick Scan" "Antivirus" "Updates threat intelligence signatures and launches a Windows Defender scan." {
    Update-MpSignature | Out-Null
    Start-MpScan -ScanType QuickScan | Out-Null
    Write-Log "Microsoft Defender Quick Scan complete." "Success"
}

# --- [Default Selection & Telemetry Loop] ---
$script:SidebarButtons["Presets"].PerformClick()

# Telemetry Timer (Runs Every 2 Seconds)
$TelemetryTimer = New-Object System.Windows.Forms.Timer -Property @{Interval=2000; Enabled=$true}
$TelemetryTimer.Add_Tick({
    try {
        # CPU Load
        $cpu = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
        $StatCPU.Text = "$([math]::Round($cpu, 0))% Utilization"

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
        $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
        $span = (Get-Date) - $boot
        $StatUp.Text = "$($span.Days)d $($span.Hours)h $($span.Minutes)m $($span.Seconds)s"
    } catch {}
})

Write-Log "AdminWorks Pro Suite loaded and ready." "Success"
[void]$Form.ShowDialog()
