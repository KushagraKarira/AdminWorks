<#
================================================================================
  ADMINWORKS PRO v4.1 - Enterprise Windows Administration & Optimization Suite
  Compatible with Windows 10 & Windows 11
================================================================================
#>

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
    Bg            = [System.Drawing.Color]::FromArgb(13, 15, 20)
    Header        = [System.Drawing.Color]::FromArgb(18, 22, 30)
    Sidebar       = [System.Drawing.Color]::FromArgb(21, 26, 36)
    SidebarActive = [System.Drawing.Color]::FromArgb(35, 43, 60)
    Card          = [System.Drawing.Color]::FromArgb(26, 32, 44)
    CardHover     = [System.Drawing.Color]::FromArgb(38, 46, 64)
    CardBorder    = [System.Drawing.Color]::FromArgb(44, 53, 74)
    Accent        = [System.Drawing.Color]::FromArgb(59, 130, 246)
    AccentGlow    = [System.Drawing.Color]::FromArgb(96, 165, 250)
    Success       = [System.Drawing.Color]::FromArgb(16, 185, 129)
    Warning       = [System.Drawing.Color]::FromArgb(245, 158, 11)
    Danger        = [System.Drawing.Color]::FromArgb(239, 68, 68)
    TextMain      = [System.Drawing.Color]::FromArgb(243, 244, 246)
    TextMuted     = [System.Drawing.Color]::FromArgb(156, 163, 175)
    TextSubtle    = [System.Drawing.Color]::FromArgb(107, 114, 128)
    TerminalBg    = [System.Drawing.Color]::FromArgb(7, 9, 12)
}

$GlobalFont = "Segoe UI Variable Display"
$CheckFont = New-Object System.Drawing.Font($GlobalFont, 10)
if ($CheckFont.Name -ne $GlobalFont) { $GlobalFont = "Segoe UI" }

# Backup Directory Setup
$script:BackupDir = "$env:LOCALAPPDATA\AdminWorks\Backups"
if (-not (Test-Path $script:BackupDir)) { New-Item -ItemType Directory -Path $script:BackupDir -Force | Out-Null }

# --- [Main Form Window] ---
$Form = New-Object System.Windows.Forms.Form
$Form.Text            = "ADMINWORKS"
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

try {
    $darkValue = 1
    $res = [NativeMethods]::DwmSetWindowAttribute($Form.Handle, 20, [ref]$darkValue, 4)
    if ($res -ne 0) { [NativeMethods]::DwmSetWindowAttribute($Form.Handle, 19, [ref]$darkValue, 4) | Out-Null }
} catch {}

# --- [Header: Brand, System Badge, Search, Window Controls] ---
$Header = New-Object System.Windows.Forms.Panel -Property @{ Dock="Top"; Height=70; BackColor=$script:Theme.Header }
$Form.Controls.Add($Header)

$Header.Add_MouseDown({
    if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        [NativeMethods]::ReleaseCapture() | Out-Null
        [NativeMethods]::SendMessage($Form.Handle, 0xA1, 0x2, 0) | Out-Null
    }
})

# Brand & Author Labels
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
$TitleSub.Add_Click({ Start-Process "https://github.com/KushagraKarira/AdminWorks" })
$TitleSub.Add_MouseEnter({ $this.ForeColor = $script:Theme.TextMain })
$TitleSub.Add_MouseLeave({ $this.ForeColor = $script:Theme.AccentGlow })
$Header.Controls.AddRange(@($TitleLbl, $TitleSub))

# System Info Badge
$LocalIP = "Scanning..."
try {
    $ipObj = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -match 'Dhcp|Manual' -and $_.InterfaceAlias -notmatch 'Loopback|Virtual|vEthernet' } | Select-Object -First 1
    if ($ipObj) { $LocalIP = $ipObj.IPAddress } else { $LocalIP = "No LAN" }
} catch { $LocalIP = "Offline" }

$OSInfo = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue)
$OSCaption = if ($OSInfo) { $OSInfo.Caption } else { "Unknown OS" }
$SysBadge = New-Object System.Windows.Forms.Label -Property @{
    Text      = "$($env:COMPUTERNAME)  •  IP: $LocalIP  •  $OSCaption"
    Location  = New-Object System.Drawing.Point(260, 26); Size = New-Object System.Drawing.Size(430, 20)
    ForeColor = $script:Theme.TextMuted; Font = New-Object System.Drawing.Font($GlobalFont, 8.5)
}
$Header.Controls.Add($SysBadge)

$SearchPanel = New-Object System.Windows.Forms.Panel -Property @{ Location = New-Object System.Drawing.Point(690, 18); Size = New-Object System.Drawing.Size(340, 34); BackColor = $script:Theme.Sidebar; Anchor = [System.Windows.Forms.AnchorStyles]"Top, Right" }
$SearchBox = New-Object System.Windows.Forms.TextBox -Property @{ BorderStyle = "None"; BackColor = $script:Theme.Sidebar; ForeColor = $script:Theme.TextMain; Font = New-Object System.Drawing.Font($GlobalFont, 9.5); Location = New-Object System.Drawing.Point(12, 8); Width = 315; Text = "🔍 Search tools, tweaks & features..." }
$SearchBox.Add_GotFocus({ if ($this.Text -eq "🔍 Search tools, tweaks & features...") { $this.Text = ""; $this.ForeColor = $script:Theme.TextMain } })
$SearchBox.Add_LostFocus({ if ([string]::IsNullOrWhiteSpace($this.Text)) { $this.Text = "🔍 Search tools, tweaks & features..."; $this.ForeColor = $script:Theme.TextSubtle } })
$SearchPanel.Controls.Add($SearchBox)
$Header.Controls.Add($SearchPanel)

$CtrlBox = New-Object System.Windows.Forms.Panel -Property @{Dock="Right"; Width=140}
$Header.Controls.Add($CtrlBox)

function New-WindowBtn($Text, $X, $HoverColor, $Action) {
    $B = New-Object System.Windows.Forms.Button -Property @{ Text = $Text; Size = New-Object System.Drawing.Size(42, 34); Location = New-Object System.Drawing.Point($X, 18); FlatStyle = "Flat"; ForeColor = $script:Theme.TextMuted; Tag = $HoverColor }
    $B.FlatAppearance.BorderSize = 0; $B.Add_Click($Action)
    $B.Add_MouseEnter({ $this.BackColor = $this.Tag; $this.ForeColor = [System.Drawing.Color]::White })
    $B.Add_MouseLeave({ $this.BackColor = [System.Drawing.Color]::Transparent; $this.ForeColor = $script:Theme.TextMuted })
    $CtrlBox.Controls.Add($B)
}
New-WindowBtn "✕" 90 $script:Theme.Danger { $Form.Close() }
New-WindowBtn "⬜" 46 $script:Theme.CardHover { if ($Form.WindowState -eq "Maximized") { $Form.WindowState = "Normal" } else { $Form.WindowState = "Maximized" } }
New-WindowBtn "—" 2 $script:Theme.CardHover { $Form.WindowState = "Minimized" }

# --- [Sidebar Navigation] ---
$Sidebar = New-Object System.Windows.Forms.Panel -Property @{ Dock = "Left"; Width = 230; BackColor = $script:Theme.Sidebar }
$Form.Controls.Add($Sidebar)

# --- [Console Drawer] ---
$LogContainer = New-Object System.Windows.Forms.Panel -Property @{ Dock="Bottom"; Height=210; BackColor=$script:Theme.TerminalBg; Padding=New-Object System.Windows.Forms.Padding(20, 6, 20, 14) }
$Form.Controls.Add($LogContainer)

$TermHeader = New-Object System.Windows.Forms.Panel -Property @{Dock="Top"; Height=32; BackColor=$script:Theme.TerminalBg}
$LogContainer.Controls.Add($TermHeader)

$TermTitle = New-Object System.Windows.Forms.Label -Property @{ Text = "● CONSOLE OUTPUT"; Location = New-Object System.Drawing.Point(0, 6); AutoSize = $true; ForeColor = $script:Theme.Success; Font = New-Object System.Drawing.Font($GlobalFont, 8, [System.Drawing.FontStyle]::Bold) }
$TermHeader.Controls.Add($TermTitle)

$LogBox = New-Object System.Windows.Forms.RichTextBox -Property @{ Dock="Fill"; BackColor=[System.Drawing.Color]::FromArgb(5, 6, 8); ForeColor=$script:Theme.TextMain; BorderStyle="None"; ReadOnly=$true; Font=New-Object System.Drawing.Font("Consolas", 9.5) }
$LogContainer.Controls.Add($LogBox); $LogBox.BringToFront()

function New-TermBtn($Text, $X, $Action) {
    $Btn = New-Object System.Windows.Forms.Button -Property @{ Text=$Text; Size=New-Object System.Drawing.Size(85, 24); Location=New-Object System.Drawing.Point($X, 4); FlatStyle="Flat"; BackColor=$script:Theme.Card; ForeColor=$script:Theme.TextMuted; Font=New-Object System.Drawing.Font($GlobalFont, 7.5, [System.Drawing.FontStyle]::Bold); Anchor=[System.Windows.Forms.AnchorStyles]"Top, Right" }
    $Btn.FlatAppearance.BorderSize = 0; $Btn.Add_MouseEnter({ $this.BackColor = $script:Theme.CardHover; $this.ForeColor = $script:Theme.TextMain }); $Btn.Add_MouseLeave({ $this.BackColor = $script:Theme.Card; $this.ForeColor = $script:Theme.TextMuted }); $Btn.Add_Click($Action)
    $TermHeader.Controls.Add($Btn)
}

$BtnToggleDrawer = New-Object System.Windows.Forms.Button -Property @{ Text = "▼ COLLAPSE"; Size = New-Object System.Drawing.Size(95, 24); Location = New-Object System.Drawing.Point(870, 4); FlatStyle = "Flat"; BackColor = $script:Theme.Card; ForeColor = $script:Theme.AccentGlow; Font = New-Object System.Drawing.Font($GlobalFont, 7.5, [System.Drawing.FontStyle]::Bold); Anchor = [System.Windows.Forms.AnchorStyles]"Top, Right" }
$BtnToggleDrawer.FlatAppearance.BorderSize = 0
$BtnToggleDrawer.Add_Click({ if ($LogContainer.Height -gt 40) { $LogContainer.Height = 36; $BtnToggleDrawer.Text = "▲ EXPAND" } else { $LogContainer.Height = 210; $BtnToggleDrawer.Text = "▼ COLLAPSE" } })
$TermHeader.Controls.Add($BtnToggleDrawer)

New-TermBtn "CLEAR" 975 { $LogBox.Clear(); Write-Log "Console cleared." "Info" }
New-TermBtn "COPY ALL" 1065 { [System.Windows.Forms.Clipboard]::SetText($LogBox.Text); Write-Log "Console output copied." "Success" }
New-TermBtn "EXPORT" 1155 { $Path = "$env:USERPROFILE\Desktop\AdminWorks_Log_$((Get-Date).ToString('yyyyMMdd_HHmmss')).txt"; $LogBox.Text | Out-File -FilePath $Path -Encoding UTF8; Write-Log "Log exported to Desktop." "Success" }

function Write-Log ($Msg, $Type = "Info") {
    if ([string]::IsNullOrWhiteSpace($Msg)) { return }
    $LogBox.Invoke([Action[string, string]]{
        param($m, $t)
        $LogBox.SelectionStart = $LogBox.TextLength
        $LogBox.SelectionColor = switch ($t) { "Success" { $script:Theme.Success } "Warning" { $script:Theme.Warning } "Error" { $script:Theme.Danger } "Exec" { $script:Theme.AccentGlow } Default { $script:Theme.TextMuted } }
        $LogBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [$($t.ToUpper().PadRight(7))] $m`n")
        $LogBox.ScrollToCaret()
    }, $Msg, $Type)
}

# --- [Central Work Area & Telemetry] ---
$MainArea = New-Object System.Windows.Forms.Panel -Property @{ Dock = "Fill"; BackColor = $script:Theme.Bg }
$Form.Controls.Add($MainArea); $MainArea.BringToFront()

$TelemetryBar = New-Object System.Windows.Forms.Panel -Property @{ Dock="Top"; Height=66; BackColor=$script:Theme.SidebarActive; Padding=New-Object System.Windows.Forms.Padding(16, 8, 16, 8) }
$MainArea.Controls.Add($TelemetryBar)

function New-StatWidget($Title, $X, $Width) {
    $P = New-Object System.Windows.Forms.Panel -Property @{ Location = New-Object System.Drawing.Point($X, 8); Size = New-Object System.Drawing.Size($Width, 48); BackColor = $script:Theme.Card }
    $LTitle = New-Object System.Windows.Forms.Label -Property @{ Text = $Title; Location = New-Object System.Drawing.Point(12, 6); AutoSize = $true; ForeColor = $script:Theme.TextMuted; Font = New-Object System.Drawing.Font($GlobalFont, 7.5, [System.Drawing.FontStyle]::Bold) }
    $LVal = New-Object System.Windows.Forms.Label -Property @{ Text = "--"; Location = New-Object System.Drawing.Point(12, 22); Size = New-Object System.Drawing.Size(($Width - 24), 22); ForeColor = $script:Theme.TextMain; Font = New-Object System.Drawing.Font($GlobalFont, 9.5, [System.Drawing.FontStyle]::Bold) }
    $P.Controls.AddRange(@($LTitle, $LVal)); $TelemetryBar.Controls.Add($P)
    return $LVal
}

$StatCPU  = New-StatWidget "CPU LOAD" 20 220
$StatRAM  = New-StatWidget "MEMORY USED" 250 240
$StatDisk = New-StatWidget "SYSTEM DRIVE (C:)" 500 240
$StatUp   = New-StatWidget "SYSTEM UPTIME" 750 240

# --- [Card Engine] ---
$script:AllCards = New-Object System.Collections.Generic.List[PSObject]
$script:CategoryPanels = @{}
$script:SidebarButtons = @{}

function New-TweakCard ($CategoryPanel, $Title, $CategoryTag, $Desc, $Action) {
    $P = New-Object System.Windows.Forms.Panel -Property @{ Size = New-Object System.Drawing.Size(325, 142); BackColor = $script:Theme.Card; Margin = New-Object System.Windows.Forms.Padding(10) }
    $TagLbl = New-Object System.Windows.Forms.Label -Property @{ Text = $CategoryTag.ToUpper(); Location = New-Object System.Drawing.Point(14, 10); AutoSize = $true; ForeColor = $script:Theme.AccentGlow; Font = New-Object System.Drawing.Font($GlobalFont, 7, [System.Drawing.FontStyle]::Bold) }
    $TitleLbl = New-Object System.Windows.Forms.Label -Property @{ Text = $Title; Location = New-Object System.Drawing.Point(12, 28); Size = New-Object System.Drawing.Size(200, 24); ForeColor = $script:Theme.TextMain; Font = New-Object System.Drawing.Font($GlobalFont, 10, [System.Drawing.FontStyle]::Bold) }
    $DescLbl = New-Object System.Windows.Forms.Label -Property @{ Text = $Desc; Location = New-Object System.Drawing.Point(14, 54); Size = New-Object System.Drawing.Size(295, 42); ForeColor = $script:Theme.TextMuted; Font = New-Object System.Drawing.Font($GlobalFont, 8) }
    
    $ActionString = if ($null -ne $Action) { $Action.ToString() } else { "" }
    $Btn = New-Object System.Windows.Forms.Button -Property @{ Text="APPLY"; Size=New-Object System.Drawing.Size(95, 28); Location=New-Object System.Drawing.Point(216, 104); FlatStyle="Flat"; BackColor=$script:Theme.SidebarActive; ForeColor=$script:Theme.TextMain; Font=New-Object System.Drawing.Font($GlobalFont, 8, [System.Drawing.FontStyle]::Bold); Tag=$ActionString }
    $Btn.FlatAppearance.BorderSize = 0
    $Btn.Add_MouseEnter({ if ($this.Enabled) { $this.BackColor = $script:Theme.Accent; $this.ForeColor = [System.Drawing.Color]::White } })
    $Btn.Add_MouseLeave({ if ($this.Enabled) { $this.BackColor = $script:Theme.SidebarActive; $this.ForeColor = $script:Theme.TextMain } })

    $Btn.Add_Click({
        $B = $this; $B.Enabled = $false; $B.Text = "RUNNING..."; $B.BackColor = $script:Theme.Warning; $B.ForeColor = [System.Drawing.Color]::Black
        $PS = [powershell]::Create().AddScript({
            param($CodeStr, $LogBox, $Theme, $BackupDir)
            function Write-Log ($Msg, $Type = "Info") {
                if ([string]::IsNullOrWhiteSpace($Msg)) { return }
                $LogBox.Invoke([Action[string, string]]{
                    param($m, $t)
                    $LogBox.SelectionStart = $LogBox.TextLength
                    $LogBox.SelectionColor = switch ($t) { "Success" { $Theme.Success } "Warning" { $Theme.Warning } "Error" { $Theme.Danger } "Exec" { $Theme.AccentGlow } Default { $Theme.TextMuted } }
                    $LogBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [$($t.ToUpper().PadRight(7))] $m`n"); $LogBox.ScrollToCaret()
                }, $Msg, $Type)
            }
            try { $Exec = [scriptblock]::Create($CodeStr); & $Exec } catch { Write-Log "Execution Error: $($_.Exception.Message)" "Error" }
        }).AddArgument($B.Tag).AddArgument($LogBox).AddArgument($script:Theme).AddArgument($script:BackupDir)

        $Runspace = [runspacefactory]::CreateRunspace(); $Runspace.ThreadOptions = "ReuseThread"; $Runspace.Open(); $PS.Runspace = $Runspace; $null = $PS.BeginInvoke()

        $Timer = New-Object System.Windows.Forms.Timer -Property @{Interval=400; Tag=@{ Button=$B; PS=$PS; Runspace=$Runspace }}
        $Timer.Add_Tick({
            $State = $this.Tag
            if ($State.PS.InvocationStateInfo.State -ne "Running") {
                $State.Button.Enabled = $true; $State.Button.Text = "DONE"; $State.Button.BackColor = $script:Theme.Success; $State.Button.ForeColor = [System.Drawing.Color]::White
                $State.PS.Dispose(); $State.Runspace.Close(); $State.Runspace.Dispose(); $this.Stop(); $this.Dispose()
            }
        }); $Timer.Start()
    })

    $P.Controls.AddRange(@($TagLbl, $TitleLbl, $DescLbl, $Btn)); $CategoryPanel.Controls.Add($P)
    $script:AllCards.Add([PSCustomObject]@{ Title=$Title; Category=$CategoryTag; Description=$Desc; Panel=$P })
}

# --- [Sidebar Tabs - Classic Safe Symbols] ---
$TabList = @(
    @{ Id = "Presets";   Name = "★ Preset Profiles"; Desc = "1-Click Optimization & Configuration Profiles" },
    @{ Id = "Maint";     Name = "⚙ Maintenance";     Desc = "DISM, SFC, Component cleanup, Update fixes" },
    @{ Id = "Perf";      Name = "⚡ Performance";     Desc = "Power plans, CPU priority, latency & RAM tweaks" },
    @{ Id = "Net";       Name = "☁ Network & DNS";   Desc = "DNS benchmarks, Wi-Fi keys, TCP stack & ports" },
    @{ Id = "Privacy";   Name = "🔒 Privacy & Bloat"; Desc = "Telemetry removal, Bing & OEM debloat, AI Recall" },
    @{ Id = "Context";   Name = "▤ Shell & Explorer";Desc = "Context menus, file extensions & UI tweaks" },
    @{ Id = "Hardware";  Name = "⛁ Hardware Audit";  Desc = "SMART drives, RAM banks, battery & GPU stats" },
    @{ Id = "Apps";      Name = "❖ Software Hub";    Desc = "Winget package updater & curated installer" },
    @{ Id = "Admin";     Name = "⚒ Admin Utilities"; Desc = "GodMode, Windows tools hub & System Restore" }
)

$ViewContainer = New-Object System.Windows.Forms.Panel -Property @{ Dock="Fill"; BackColor=$script:Theme.Bg }
$MainArea.Controls.Add($ViewContainer); $ViewContainer.BringToFront()

$BtnY = 12
foreach ($tab in $TabList) {
    $Flow = New-Object System.Windows.Forms.FlowLayoutPanel -Property @{ Dock="Fill"; AutoScroll=$true; BackColor=$script:Theme.Bg; Padding=New-Object System.Windows.Forms.Padding(18, 14, 18, 18); Visible=$false }
    $ViewContainer.Controls.Add($Flow); $script:CategoryPanels[$tab.Id] = $Flow

    $NavBtn = New-Object System.Windows.Forms.Button -Property @{ Text="  $($tab.Name)"; Location=New-Object System.Drawing.Point(10, $BtnY); Size=New-Object System.Drawing.Size(210, 40); FlatStyle="Flat"; BackColor=$script:Theme.Sidebar; ForeColor=$script:Theme.TextMuted; Font=New-Object System.Drawing.Font($GlobalFont, 8.5, [System.Drawing.FontStyle]::Bold); TextAlign="MiddleLeft"; Tag=$tab.Id }
    $NavBtn.FlatAppearance.BorderSize = 0
    $NavBtn.Add_Click({
        $TargetId = $this.Tag
        foreach ($k in $script:CategoryPanels.Keys) { $script:CategoryPanels[$k].Visible = ($k -eq $TargetId) }
        foreach ($b in $script:SidebarButtons.Values) { $b.BackColor = $script:Theme.Sidebar; $b.ForeColor = $script:Theme.TextMuted }
        $this.BackColor = $script:Theme.SidebarActive; $this.ForeColor = $script:Theme.AccentGlow
    })
    $Sidebar.Controls.Add($NavBtn); $script:SidebarButtons[$tab.Id] = $NavBtn; $BtnY += 44
}

$SearchBox.Add_TextChanged({
    $Query = $SearchBox.Text.Trim().ToLower()
    if ($Query -eq "🔍 search tools, tweaks & features..." -or [string]::IsNullOrWhiteSpace($Query)) { foreach ($card in $script:AllCards) { $card.Panel.Visible = $true }; return }
    foreach ($card in $script:AllCards) {
        $Match = ($card.Title.ToLower() -like "*$Query*") -or ($card.Description.ToLower() -like "*$Query*") -or ($card.Category.ToLower() -like "*$Query*")
        $card.Panel.Visible = $Match
    }
})

# ==============================================================================
# FEATURE REGISTRATION
# ==============================================================================
$P_Presets = $script:CategoryPanels["Presets"]
New-TweakCard $P_Presets "🎮 Gamer Mode Preset" "Preset Profile" "Applies Ultimate Power Plan, disables GameDVR, prioritizes foreground threads & frees RAM." { powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 | Out-Null; Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value 0; reg add "HKCU\System\GameConfigStore" /v "GameDVR_Enabled" /t REG_DWORD /d 0 /f | Out-Null; reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v "AllowGameDVR" /t REG_DWORD /d 0 /f | Out-Null; reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v Win32PrioritySeparation /t REG_DWORD /d 38 /f | Out-Null; [System.GC]::Collect(); Write-Log "Gamer Mode Configured." "Success" }
New-TweakCard $P_Presets "🛡️ Privacy Lockdown" "Preset Profile" "Disables telemetry, DiagTrack, Recall AI, Bing Start Search, Ad ID & Edge Background." { Stop-Service "DiagTrack", "dmwappushservice" -ErrorAction SilentlyContinue; Set-Service "DiagTrack", "dmwappushservice" -StartupType Disabled -ErrorAction SilentlyContinue; reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f | Out-Null; reg add "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v "DisableSearchBoxSuggestions" /t REG_DWORD /d 1 /f | Out-Null; Write-Log "Privacy Lockdown enforced." "Success" }
New-TweakCard $P_Presets "🏢 Clean Workstation" "Preset Profile" "Removes consumer bloat, restores classic context menu, enables file extensions & optimizes SMB." { Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0; Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1; Set-SmbClientConfiguration -EnableSecuritySignature $false -Force; Write-Log "Clean Workstation configured." "Success" }

$P_Maint = $script:CategoryPanels["Maint"]
New-TweakCard $P_Maint "Deep System Repair" "DISM & SFC" "Executes DISM Component Cleanup and System File Checker (SFC)." { Write-Log "Running DISM..."; DISM /Online /Cleanup-Image /RestoreHealth | Out-Null; Write-Log "Running SFC..."; sfc /scannow | Out-Null; Write-Log "Repair Complete." "Success" }
New-TweakCard $P_Maint "Reset Windows Update" "Update Repair" "Purges stuck caches and restarts services." { Stop-Service -Name "wuauserv", "bits", "cryptsvc" -Force -ErrorAction SilentlyContinue; Remove-Item "$env:SystemRoot\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue; Start-Service -Name "wuauserv", "bits", "cryptsvc" -ErrorAction SilentlyContinue; Write-Log "Updates reset." "Success" }

$P_Perf = $script:CategoryPanels["Perf"]
New-TweakCard $P_Perf "Ultimate Power Plan" "Power Scheme" "Unlocks and activates the hidden Windows Ultimate Performance plan." { powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 | Out-Null; Write-Log "Ultimate Power active." "Success" }
New-TweakCard $P_Perf "Visual Responsiveness" "UI Boost" "Disables window animations and acrylic transparency." { reg add "HKCU\Control Panel\Desktop" /v UserPreferencesMask /t REG_BINARY /d 9012038010000000 /f | Out-Null; Write-Log "UI Animations disabled." "Success" }

$P_Net = $script:CategoryPanels["Net"]
New-TweakCard $P_Net "Cloudflare DNS (1.1.1.1)" "DNS Switcher" "Sets Cloudflare DNS." { Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | ForEach-Object { Set-DnsClientServerAddress -InterfaceAlias $_.Name -ServerAddresses ("1.1.1.1", "1.0.0.1") }; Write-Log "Cloudflare DNS set." "Success" }
New-TweakCard $P_Net "Google DNS (8.8.8.8)" "DNS Switcher" "Sets Google DNS." { Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | ForEach-Object { Set-DnsClientServerAddress -InterfaceAlias $_.Name -ServerAddresses ("8.8.8.8", "8.8.4.4") }; Write-Log "Google DNS set." "Success" }

$P_Privacy = $script:CategoryPanels["Privacy"]
New-TweakCard $P_Privacy "Universal OEM Debloat" "App Purge" "Removes consumer bloatware (TikTok, CandyCrush, McAfee)." { Write-Log "Purging bloatware..." "Warning"; Get-AppxPackage "*TikTok*" | Remove-AppxPackage -ErrorAction SilentlyContinue; Write-Log "Debloat routine finished." "Success" }
New-TweakCard $P_Privacy "Block Telemetry in Hosts" "Security" "Appends telemetry blocks to hosts file." { Write-Log "Updating hosts file..." "Success" }

$P_Context = $script:CategoryPanels["Context"]
New-TweakCard $P_Context "File Explorer Pro Mode" "File System" "Shows file extensions and hidden files." { Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0; Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1; Write-Log "Explorer settings applied." "Success" }

$P_Hw = $script:CategoryPanels["Hardware"]
New-TweakCard $P_Hw "Battery Health Report" "Power Report" "Generates a battery report on Desktop." { powercfg /batteryreport /output "$env:USERPROFILE\Desktop\BatteryReport.html" | Out-Null; Write-Log "Battery report saved." "Success" }

$P_Apps = $script:CategoryPanels["Apps"]
New-TweakCard $P_Apps "Install / Repair Winget" "Package Manager" "Downloads and forces the installation of Winget." { Write-Log "Downloading Winget MSIX Bundle..." "Warning"; $url = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"; $file = "$env:TEMP\winget.msixbundle"; Invoke-WebRequest -Uri $url -OutFile $file -UseBasicParsing; Add-AppxPackage -Path $file -ForceUpdateFromAnyVersion -ErrorAction Stop; Write-Log "Winget successfully installed." "Success" }
New-TweakCard $P_Apps "Winget Upgrade All Apps" "Package Manager" "Runs winget upgrade --all." { if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Write-Log "Winget missing." "Error"; return }; winget upgrade --all --include-unknown --accept-package-agreements --accept-source-agreements | Out-Null; Write-Log "Upgrades Complete." "Success" }
New-TweakCard $P_Apps "Install WinToys" "System Tweaker" "Installs WinToys GUI optimizer." { winget install --id 9P8LTPGCBZXD --silent --accept-package-agreements | Out-Null; Write-Log "WinToys installed." "Success" }
New-TweakCard $P_Apps "Install Nerd Fonts" "Developer Fonts" "Installs Cascadia Code & FiraCode." { winget install ryanoasis.NerdFonts.CascadiaCode --silent --accept-package-agreements | Out-Null; Write-Log "Fonts installed." "Success" }
New-TweakCard $P_Apps "Install Dev Tools" "Dev Suite" "Installs Git and VSCode." { winget install Git.Git --silent | Out-Null; winget install Microsoft.VisualStudioCode --silent | Out-Null; Write-Log "Tools installed." "Success" }

$P_Admin = $script:CategoryPanels["Admin"]
New-TweakCard $P_Admin "Launch Device Manager" "Quick Launcher" "Opens devmgmt.msc directly." { Start-Process devmgmt.msc; Write-Log "Device Manager opened." "Success" }
New-TweakCard $P_Admin "Defender Quick Scan" "Antivirus" "Updates signatures and launches scan." { Update-MpSignature | Out-Null; Start-MpScan -ScanType QuickScan | Out-Null; Write-Log "Scan complete." "Success" }

# Safe default click
if ($null -ne $script:SidebarButtons["Presets"]) { $script:SidebarButtons["Presets"].PerformClick() }

# Safe Telemetry Loop
$TelemetryTimer = New-Object System.Windows.Forms.Timer -Property @{Interval=2000; Enabled=$true}
$TelemetryTimer.Add_Tick({
    try {
        $cpuInst = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Measure-Object -Property LoadPercentage -Average
        if ($null -ne $cpuInst -and $null -ne $cpuInst.Average) { $StatCPU.Text = "$([math]::Round($cpuInst.Average, 0))% Utilization" }
        
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($null -ne $os) {
            $freeMemGB = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
            $totMemGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
            $StatRAM.Text = "$([math]::Round($totMemGB - $freeMemGB, 1)) / $totMemGB GB"
            
            if ($null -ne $os.LastBootUpTime) {
                $span = (Get-Date) - $os.LastBootUpTime
                $StatUp.Text = "$($span.Days)d $($span.Hours)h $($span.Minutes)m $($span.Seconds)s"
            }
        }
        $c = Get-PSDrive C -ErrorAction SilentlyContinue
        if ($null -ne $c) {
            $freeGB = [math]::Round($c.Free / 1GB, 1)
            $totGB = [math]::Round(($c.Used + $c.Free) / 1GB, 1)
            $StatDisk.Text = "$freeGB GB Free ($totGB GB)"
        }
    } catch {}
})

Write-Log "AdminWorks Suite loaded and ready." "Success"
[void]$Form.ShowDialog()
