<#
================================================================================
  ADMINWORKS PRO - Modern Windows Administration & Optimization Suite
================================================================================
#>

# --- [Self-Elevate to Administrator] ---
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList "-ExecutionPolicy Bypass", "-File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# --- [High-DPI Scaling & Native Window Dragging Helper] ---
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Win32Helper {
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();

    [DllImport("user32.dll")]
    public static extern int SendMessage(IntPtr hWnd, int Msg, int wParam, int lParam);

    [DllImport("user32.dll")]
    public static extern bool ReleaseCapture();
}
"@
[Win32Helper]::SetProcessDPIAware() | Out-Null
[System.Windows.Forms.Application]::EnableVisualStyles()

# --- [Theme & Design Palette] ---
$script:Theme = @{
    Bg          = [System.Drawing.Color]::FromArgb(13, 15, 18)       # #0D0F12 Deep Obsidian
    Header      = [System.Drawing.Color]::FromArgb(19, 22, 28)       # #13161C
    Sidebar     = [System.Drawing.Color]::FromArgb(22, 26, 34)       # #161A22
    SidebarActive = [System.Drawing.Color]::FromArgb(35, 42, 54)     # #232A36
    Card        = [System.Drawing.Color]::FromArgb(27, 32, 42)       # #1B202A
    CardHover   = [System.Drawing.Color]::FromArgb(38, 45, 60)       # #262D3C
    CardBorder  = [System.Drawing.Color]::FromArgb(45, 53, 70)       # #2D3546
    Accent      = [System.Drawing.Color]::FromArgb(59, 130, 246)     # Vibrant Blue
    AccentGlow  = [System.Drawing.Color]::FromArgb(96, 165, 250)     # Sky Blue
    Success     = [System.Drawing.Color]::FromArgb(16, 185, 129)     # Emerald Green
    Warning     = [System.Drawing.Color]::FromArgb(245, 158, 11)     # Amber Yellow
    Danger      = [System.Drawing.Color]::FromArgb(239, 68, 68)      # Crimson Red
    TextMain    = [System.Drawing.Color]::FromArgb(243, 244, 246)    # Near White
    TextMuted   = [System.Drawing.Color]::FromArgb(156, 163, 175)    # Cool Gray
    TextSubtle  = [System.Drawing.Color]::FromArgb(107, 114, 128)    # Darker Gray
    TerminalBg  = [System.Drawing.Color]::FromArgb(8, 10, 12)        # Terminal Black
}

$GlobalFont = "Segoe UI Variable Display"
$CheckFont = New-Object System.Drawing.Font($GlobalFont, 10)
if ($CheckFont.Name -ne $GlobalFont) { $GlobalFont = "Segoe UI" }

# --- [Form Setup] ---
$Form = New-Object System.Windows.Forms.Form
$Form.Text            = "ADMINWORKS PRO"
$Form.Size            = New-Object System.Drawing.Size(1300, 920)
$Form.BackColor       = $script:Theme.Bg
$Form.StartPosition   = "CenterScreen"
$Form.FormBorderStyle = "None"
$Form.MinimumSize     = New-Object System.Drawing.Size(1150, 780)

try {
    $bf = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic
    $prop = $Form.GetType().GetProperty("DoubleBuffered", $bf)
    if ($prop) { $prop.SetValue($Form, $true, $null) }
} catch {}

# --- [Header: Title, Search, System Badge, Window Controls] ---
$Header = New-Object System.Windows.Forms.Panel -Property @{
    Dock      = "Top"
    Height    = 70
    BackColor = $script:Theme.Header
}
$Form.Controls.Add($Header)

# Native Smooth Dragging on Header
$Header.Add_MouseDown({
    if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        [Win32Helper]::ReleaseCapture() | Out-Null
        [Win32Helper]::SendMessage($Form.Handle, 0xA1, 0x2, 0) | Out-Null
    }
})

# Brand Title
$TitleLbl = New-Object System.Windows.Forms.Label -Property @{
    Text      = "⚡ ADMINWORKS"
    Location  = New-Object System.Drawing.Point(22, 14); AutoSize = $true
    ForeColor = $script:Theme.TextMain
    Font      = New-Object System.Drawing.Font($GlobalFont, 12, [System.Drawing.FontStyle]::Bold)
}
$TitleSub = New-Object System.Windows.Forms.Label -Property @{
    Text      = "PRO SUITE v3.0"
    Location  = New-Object System.Drawing.Point(24, 38); AutoSize = $true
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
    Location  = New-Object System.Drawing.Point(230, 26); Size = New-Object System.Drawing.Size(420, 20)
    ForeColor = $script:Theme.TextMuted; Font = New-Object System.Drawing.Font($GlobalFont, 8.5)
}
$Header.Controls.Add($SysBadge)

# Search Box Container
$SearchPanel = New-Object System.Windows.Forms.Panel -Property @{
    Location  = New-Object System.Drawing.Point(670, 18); Size = New-Object System.Drawing.Size(340, 34)
    BackColor = $script:Theme.Sidebar; Anchor = [System.Windows.Forms.AnchorStyles]"Top, Right"
}
$SearchBox = New-Object System.Windows.Forms.TextBox -Property @{
    BorderStyle = "None"; BackColor = $script:Theme.Sidebar; ForeColor = $script:Theme.TextMain
    Font = New-Object System.Drawing.Font($GlobalFont, 9.5); Location = New-Object System.Drawing.Point(12, 8)
    Width = 315; Text = "🔍 Search tools & tweaks..."
}
$SearchBox.Add_GotFocus({ if ($this.Text -eq "🔍 Search tools & tweaks...") { $this.Text = ""; $this.ForeColor = $script:Theme.TextMain } })
$SearchBox.Add_LostFocus({ if ([string]::IsNullOrWhiteSpace($this.Text)) { $this.Text = "🔍 Search tools & tweaks..."; $this.ForeColor = $script:Theme.TextSubtle } })
$SearchPanel.Controls.Add($SearchBox)
$Header.Controls.Add($SearchPanel)

# Window Action Buttons
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

# --- [Sidebar Navigation] ---
$Sidebar = New-Object System.Windows.Forms.Panel -Property @{
    Dock      = "Left"
    Width     = 220
    BackColor = $script:Theme.Sidebar
}
$Form.Controls.Add($Sidebar)

# --- [Bottom Terminal / Console] ---
$LogContainer = New-Object System.Windows.Forms.Panel -Property @{
    Dock      = "Bottom"
    Height    = 210
    BackColor = $script:Theme.TerminalBg
    Padding   = New-Object System.Windows.Forms.Padding(20, 8, 20, 16)
}
$Form.Controls.Add($LogContainer)

# Terminal Toolbar
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
        Text = $Text; Size = New-Object System.Drawing.Size(78, 24); Location = New-Object System.Drawing.Point($X, 4)
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

New-TermBtn "CLEAR" 980 { $LogBox.Clear(); Write-Log "Console cleared." "Info" }
New-TermBtn "COPY ALL" 1065 { [System.Windows.Forms.Clipboard]::SetText($LogBox.Text); Write-Log "Console output copied to clipboard." "Success" }
New-TermBtn "EXPORT" 1150 { 
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

# --- [Main Viewport & Workspace] ---
$MainArea = New-Object System.Windows.Forms.Panel -Property @{
    Dock      = "Fill"
    BackColor = $script:Theme.Bg
    Padding   = New-Object System.Windows.Forms.Padding(0)
}
$Form.Controls.Add($MainArea)
$MainArea.BringToFront()

# Collection of all cards for searching
$script:AllCards = New-Object System.Collections.Generic.List[PSObject]
$script:CategoryPanels = @{}
$script:SidebarButtons = @{}

# --- [Dashboard Telemetry Header Widget] ---
$TelemetryBar = New-Object System.Windows.Forms.Panel -Property @{
    Dock      = "Top"
    Height    = 70
    BackColor = $script:Theme.SidebarActive
    Padding   = New-Object System.Windows.Forms.Padding(20, 10, 20, 10)
}
$MainArea.Controls.Add($TelemetryBar)

function New-StatWidget($Title, $X, $Width) {
    $P = New-Object System.Windows.Forms.Panel -Property @{
        Location = New-Object System.Drawing.Point($X, 10); Size = New-Object System.Drawing.Size($Width, 50)
        BackColor = $script:Theme.Card
    }
    $LTitle = New-Object System.Windows.Forms.Label -Property @{
        Text = $Title; Location = New-Object System.Drawing.Point(12, 6); AutoSize = $true
        ForeColor = $script:Theme.TextMuted; Font = New-Object System.Drawing.Font($GlobalFont, 7.5, [System.Drawing.FontStyle]::Bold)
    }
    $LVal = New-Object System.Windows.Forms.Label -Property @{
        Text = "--"; Location = New-Object System.Drawing.Point(12, 22); Size = New-Object System.Drawing.Size(($Width - 24), 22)
        ForeColor = $script:Theme.TextMain; Font = New-Object System.Drawing.Font($GlobalFont, 10, [System.Drawing.FontStyle]::Bold)
    }
    $P.Controls.AddRange(@($LTitle, $LVal))
    $TelemetryBar.Controls.Add($P)
    return $LVal
}

$StatCPU  = New-StatWidget "CPU UTILIZATION" 20 220
$StatRAM  = New-StatWidget "MEMORY ALLOCATION" 250 240
$StatDisk = New-StatWidget "PRIMARY DISK (C:)" 500 240
$StatUp   = New-StatWidget "SYSTEM UPTIME" 750 240

# --- [Tweak & Card Generator Engine] ---
function New-TweakCard ($CategoryPanel, $Title, $CategoryTag, $Desc, $Action) {
    $P = New-Object System.Windows.Forms.Panel -Property @{
        Size      = New-Object System.Drawing.Size(325, 140)
        BackColor = $script:Theme.Card
        Margin    = New-Object System.Windows.Forms.Padding(12)
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
        Text      = "EXECUTE"
        Size      = New-Object System.Drawing.Size(95, 28)
        Location  = New-Object System.Drawing.Point(216, 102)
        FlatStyle = "Flat"
        BackColor = $script:Theme.SidebarActive
        ForeColor = $script:Theme.TextMain
        Font      = New-Object System.Drawing.Font($GlobalFont, 8, [System.Drawing.FontStyle]::Bold)
        Tag       = $ActionString
    }
    $Btn.FlatAppearance.BorderSize = 0
    $Btn.Add_MouseEnter({ if ($this.Enabled) { $this.BackColor = $script:Theme.Accent; $this.ForeColor = [System.Drawing.Color]::White } })
    $Btn.Add_MouseLeave({ if ($this.Enabled) { $this.BackColor = $script:Theme.SidebarActive; $this.ForeColor = $script:Theme.TextMain } })

    # Asynchronous Runspace Execution
    $Btn.Add_Click({
        $B = $this
        $OriginalText = $B.Text
        $ActionCode = $B.Tag

        $B.Enabled = $false
        $B.Text = "RUNNING..."
        $B.BackColor = $script:Theme.Warning
        $B.ForeColor = [System.Drawing.Color]::Black

        $PS = [powershell]::Create().AddScript({
            param($CodeStr, $LogBox, $Theme)
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
        }).AddArgument($ActionCode).AddArgument($LogBox).AddArgument($script:Theme)

        $Runspace = [runspacefactory]::CreateRunspace()
        $Runspace.ThreadOptions = "ReuseThread"
        $Runspace.Open()
        $PS.Runspace = $Runspace

        $null = $PS.BeginInvoke()

        $Timer = New-Object System.Windows.Forms.Timer
        $Timer.Interval = 400
        $Timer.Tag = @{
            Button   = $B
            OrigText = $OriginalText
            PS       = $PS
            Runspace = $Runspace
        }
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

    # Register for search index
    $script:AllCards.Add([PSCustomObject]@{
        Title       = $Title
        Category    = $CategoryTag
        Description = $Desc
        Panel       = $P
    })
}

# --- [Category Containers Setup] ---
$TabList = @(
    @{ Id = "Dash";      Name = "📊 Dashboard";      Desc = "System health, live specs & immediate actions" },
    @{ Id = "Maint";     Name = "🛠️ Maintenance";    Desc = "DISM, SFC, Component cleanup, Update fixes" },
    @{ Id = "Perf";      Name = "⚡ Performance";    Desc = "Power plans, CPU priority, latency & RAM tweaks" },
    @{ Id = "Net";       Name = "🌐 Network & DNS";  Desc = "DNS benchmarks, Wi-Fi keys, TCP stack & ports" },
    @{ Id = "Privacy";   Name = "🛡️ Privacy & Bloat";Desc = "Telemetry removal, Bing & OEM debloat, AI Recall" },
    @{ Id = "Hardware";  Name = "🔋 Hardware Audit"; Desc = "SMART drives, RAM banks, battery & GPU stats" },
    @{ Id = "Admin";     Name = "🧰 Admin Utilities"; Desc = "GodMode, Windows tools hub & Winget apps" }
)

$ViewContainer = New-Object System.Windows.Forms.Panel -Property @{
    Dock      = "Fill"
    BackColor = $script:Theme.Bg
}
$MainArea.Controls.Add($ViewContainer)
$ViewContainer.BringToFront()

$BtnY = 15
foreach ($tab in $TabList) {
    # Create Scrollable Flow Panel for this Category
    $Flow = New-Object System.Windows.Forms.FlowLayoutPanel -Property @{
        Dock          = "Fill"
        AutoScroll    = $true
        BackColor     = $script:Theme.Bg
        Padding       = New-Object System.Windows.Forms.Padding(20, 15, 20, 20)
        Visible       = $false
    }
    $ViewContainer.Controls.Add($Flow)
    $script:CategoryPanels[$tab.Id] = $Flow

    # Sidebar Navigation Button
    $NavBtn = New-Object System.Windows.Forms.Button -Property @{
        Text      = "  $($tab.Name)"
        Location  = New-Object System.Drawing.Point(10, $BtnY)
        Size      = New-Object System.Drawing.Size(200, 42)
        FlatStyle = "Flat"
        BackColor = $script:Theme.Sidebar
        ForeColor = $script:Theme.TextMuted
        Font      = New-Object System.Drawing.Font($GlobalFont, 9, [System.Drawing.FontStyle]::Bold)
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
    $BtnY += 48
}

# Real-time Card Search Filter
$SearchBox.Add_TextChanged({
    $Query = $SearchBox.Text.Trim().ToLower()
    if ($Query -eq "🔍 search tools & tweaks..." -or [string]::IsNullOrWhiteSpace($Query)) {
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
# TOOL REGISTRATION & FEATURE POPULATION
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. DASHBOARD & QUICK ACTIONS
# ------------------------------------------------------------------------------
$P_Dash = $script:CategoryPanels["Dash"]

New-TweakCard $P_Dash "Create Restore Point" "System Safety" "Creates an instant system restore checkpoint named 'AdminWorks_SafePoint'." {
    Write-Log "Creating Windows System Restore Point..." "Exec"
    try {
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "AdminWorks_SafePoint" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Log "Restore Point created successfully: AdminWorks_SafePoint" "Success"
    } catch {
        Write-Log "Failed to create Restore Point: $($_.Exception.Message)" "Error"
    }
}

New-TweakCard $P_Dash "Restart Explorer" "System UI" "Terminates and restarts explorer.exe to resolve UI freezes and taskbar glitches." {
    Write-Log "Restarting Windows Explorer shell..." "Warning"
    Stop-Process -Name explorer -Force
    Start-Sleep -Seconds 1
    Write-Log "Windows Explorer shell restarted." "Success"
}

New-TweakCard $P_Dash "Flush Standby RAM" "Memory Optimization" "Reclaims standby memory and working set caches without closing active apps." {
    Write-Log "Purging OS working sets and Standby Memory cache..." "Exec"
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    Write-Log "Memory garbage collection invoked." "Success"
}

New-TweakCard $P_Dash "Audit Top Resource Hogs" "Diagnostics" "Lists the top 5 CPU and top 5 RAM consuming active processes." {
    Write-Log "Analyzing top CPU consuming processes..." "Exec"
    Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 | ForEach-Object {
        Write-Log "CPU Hog: $($_.ProcessName) (PID: $($_.Id)) - CPU: $([math]::Round($_.CPU, 1))s" "Warning"
    }
    Write-Log "Analyzing top Memory consuming processes..." "Exec"
    Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 5 | ForEach-Object {
        $mb = [math]::Round($_.WorkingSet64 / 1MB, 1)
        Write-Log "RAM Hog: $($_.ProcessName) (PID: $($_.Id)) - WS: $mb MB" "Warning"
    }
    Write-Log "Process audit complete." "Success"
}

New-TweakCard $P_Dash "System Specs Snapshot" "Hardware" "Audits CPU, BIOS, Secure Boot, GPU, and Total Memory." {
    $cpu = (Get-CimInstance Win32_Processor).Name
    $gpu = (Get-CimInstance Win32_VideoController | Select-Object -First 1).Name
    $bios = Get-CimInstance Win32_BIOS
    $secBoot = Confirm-SecureBootUEFI 2>$null
    Write-Log "CPU: $cpu" "Success"
    Write-Log "GPU: $gpu" "Success"
    Write-Log "BIOS: $($bios.Manufacturer) $($bios.SMBIOSBIOSVersion)" "Info"
    Write-Log "Secure Boot Active: $secBoot" "Info"
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

New-TweakCard $P_Maint "Clean Component Store" "WinSxS Reduction" "Cleans up superseded Windows update components with /StartComponentCleanup /ResetBase." {
    Write-Log "Shrinking WinSxS component store..." "Warning"
    DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase | ForEach-Object { Write-Log $_ "Info" }
    Write-Log "WinSxS Component store pruned." "Success"
}

New-TweakCard $P_Maint "Reset Windows Update" "Update Repair" "Stops BITS & wuauserv, deletes SoftwareDistribution and Catroot2, and restarts services." {
    Write-Log "Halting Windows Update & cryptographic services..." "Warning"
    Stop-Service -Name "wuauserv", "bits", "cryptsvc" -Force -ErrorAction SilentlyContinue
    Write-Log "Purging SoftwareDistribution & Catroot2 caches..." "Exec"
    Remove-Item "$env:SystemRoot\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:SystemRoot\System32\catroot2\*" -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service -Name "wuauserv", "bits", "cryptsvc" -ErrorAction SilentlyContinue
    Write-Log "Windows Update cache reset and services restarted." "Success"
}

New-TweakCard $P_Maint "Repair WMI Repository" "WMI Fix" "Verifies and repairs corrupt Windows Management Instrumentation (WMI) repositories." {
    Write-Log "Checking WMI repository consistency..." "Exec"
    winmgmt /verifyrepository | ForEach-Object { Write-Log $_ "Info" }
    winmgmt /salvagerepository | ForEach-Object { Write-Log $_ "Warning" }
    Write-Log "WMI repository salvaged and verified." "Success"
}

New-TweakCard $P_Maint "Storage Sweep & Defrag" "Disk Cleanup" "Cleans temp files, runs SSD ReTrim, and defragments storage drives." {
    Write-Log "Optimizing attached storage volumes..." "Exec"
    foreach ($d in @("C", "D")) {
        if (Test-Path "$d`:\") {
            Write-Log "Trimming / Optimizing Drive $d`..." "Info"
            Optimize-Volume -DriveLetter $d -ReTrim -Defrag -Verbose 4>&1 | ForEach-Object { Write-Log $_.ToString() "Info" }
        }
    }
    cleanmgr /sagerun:1 | Out-Null
    Write-Log "Storage sweep and volume optimization complete." "Success"
}

New-TweakCard $P_Maint "Wipe Event Logs" "Log Cleanup" "Purges all active Windows Event Viewer application, security, and system logs." {
    Write-Log "Purging all Windows Event Logs..." "Warning"
    wevtutil el | ForEach-Object { wevtutil cl "$_"; Write-Log "Cleared: $_" "Info" }
    Write-Log "All Windows Event Logs purged." "Success"
}

New-TweakCard $P_Maint "Rebuild Icon Cache" "Shell Fix" "Clears corrupted Explorer icon and thumbnail database caches." {
    Write-Log "Rebuilding Icon and Thumbnail cache..." "Warning"
    Stop-Process -Name explorer -Force
    Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache*" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache*" -Force -ErrorAction SilentlyContinue
    Start-Process explorer.exe
    Write-Log "Icon and thumbnail cache rebuilt." "Success"
}

New-TweakCard $P_Maint "Reset Print Spooler" "Printer Fix" "Clears stuck printer queue files and restarts the Print Spooler service." {
    Write-Log "Stopping Spooler service & clearing queue..." "Warning"
    Stop-Service Spooler -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:SystemRoot\System32\Spool\Printers\*" -Force -ErrorAction SilentlyContinue
    Start-Service Spooler
    Write-Log "Print Spooler reset and queue cleared." "Success"
}

New-TweakCard $P_Maint "Resync Windows Clock" "Time NTP" "Forces Windows Time service to resync with time.windows.com NTP server." {
    Write-Log "Resyncing Windows Time service..." "Exec"
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
    Write-Log "Unlocking Ultimate Performance scheme..." "Exec"
    powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 | Out-Null
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value 0
    Write-Log "Ultimate Performance power plan applied." "Success"
}

New-TweakCard $P_Perf "Visual Responsiveness" "UI Boost" "Disables window animations, fading effects, and acrylic transparency for max FPS." {
    reg add "HKCU\Control Panel\Desktop" /v UserPreferencesMask /t REG_BINARY /d 9012038010000000 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 0 /f | Out-Null
    Write-Log "Visual latency minimized." "Success"
}

New-TweakCard $P_Perf "Foreground CPU Boost" "Thread Priority" "Configures Win32PrioritySeparation to prioritize foreground apps and games." {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v Win32PrioritySeparation /t REG_DWORD /d 38 /f | Out-Null
    Write-Log "Foreground app priority separation optimized (Value: 38)." "Success"
}

New-TweakCard $P_Perf "Kill GameDVR & Capture" "Gaming Latency" "Disables Xbox GameDVR background screen recording to eliminate micro-stuttering." {
    reg add "HKCU\System\GameConfigStore" /v "GameDVR_Enabled" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v "AllowGameDVR" /t REG_DWORD /d 0 /f | Out-Null
    Write-Log "GameDVR background capture disabled." "Success"
}

New-TweakCard $P_Perf "Disable Hibernation" "Storage & Power" "Runs 'powercfg -h off' to eliminate hiberfil.sys and free up gigabytes of RAM cache." {
    powercfg -h off
    Write-Log "Hibernation disabled (hiberfil.sys removed)." "Success"
}

New-TweakCard $P_Perf "Never Sleep on AC" "Power Timeout" "Prevents the system, display, and network card from going to sleep while plugged in." {
    powercfg -change -standby-timeout-ac 0
    powercfg -change -monitor-timeout-ac 0
    Write-Log "AC sleep and display timeouts set to NEVER." "Success"
}

New-TweakCard $P_Perf "Disable USB Suspend" "Hardware Latency" "Disables USB Selective Suspend to prevent disconnects and input drops on peripherals." {
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

New-TweakCard $P_Net "Reset DNS to DHCP" "DNS Switcher" "Restores automatic DNS resolution (DHCP) from your router on all adapters." {
    Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | ForEach-Object {
        Set-DnsClientServerAddress -InterfaceAlias $_.Name -ResetServerAddresses
        Write-Log "Reset DNS to DHCP on adapter: $($_.Name)" "Success"
    }
}

New-TweakCard $P_Net "DNS Benchmark Test" "Diagnostics" "Pings Cloudflare, Google, Quad9, and OpenDNS to find the lowest latency provider." {
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
    Write-Log "Auditing saved Wi-Fi network profiles..." "Exec"
    $profiles = netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object { ($_ -split ":")[-1].Trim() }
    if ($profiles) {
        foreach ($prof in $profiles) {
            $pass = netsh wlan show profile name="$prof" key=clear | Select-String "Key Content" | ForEach-Object { ($_ -split ":")[-1].Trim() }
            if ($pass) {
                Write-Log "SSID: '$prof'  ==> Password: '$pass'" "Success"
            } else {
                Write-Log "SSID: '$prof'  ==> [Open Network / No Key]" "Info"
            }
        }
    } else {
        Write-Log "No Wi-Fi profiles found." "Warning"
    }
}

New-TweakCard $P_Net "Listening Ports & PID" "Diagnostics" "Scans active listening TCP/UDP endpoints and identifies the owning process." {
    $ports = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Select-Object LocalAddress, LocalPort, OwningProcess -Unique | Sort-Object LocalPort
    Write-Log "Found $($ports.Count) active listening endpoints:" "Warning"
    foreach ($p in ($ports | Select-Object -First 12)) {
        $pName = (Get-Process -Id $p.OwningProcess -ErrorAction SilentlyContinue).ProcessName
        Write-Log "Port $($p.LocalPort) on $($p.LocalAddress) -> Process: $pName (PID: $($p.OwningProcess))" "Info"
    }
}

New-TweakCard $P_Net "Public IP & Geo Audit" "Diagnostics" "Queries external WAN IP address and internet service provider details." {
    Write-Log "Querying public WAN IP..." "Exec"
    try {
        $ip = (Invoke-RestMethod -Uri "https://api.ipify.org?format=json" -TimeoutSec 5).ip
        Write-Log "Public WAN IP: $ip" "Success"
    } catch {
        Write-Log "Failed to query public IP: $($_.Exception.Message)" "Error"
    }
}

New-TweakCard $P_Net "Full Network Stack Reset" "Stack Repair" "Flushes DNS, resets Winsock, resets TCP/IP stack, and releases/renews DHCP." {
    Write-Log "Executing complete network stack reset..." "Warning"
    ipconfig /flushdns | Out-Null
    netsh winsock reset | Out-Null
    netsh int ip reset | Out-Null
    Write-Log "Winsock and IP stack reset. Restart recommended." "Success"
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
    Write-Log "Scanning and uninstalling bloatware packages..." "Warning"
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

New-TweakCard $P_Privacy "Disable Recall & AI Tracking" "Privacy" "Disables the Windows Recall AI screen recording and snapshot feature." {
    Write-Log "Removing Windows Recall feature..." "Warning"
    Disable-WindowsOptionalFeature -Online -FeatureName "Recall" -Remove -NoRestart -ErrorAction SilentlyContinue | Out-Null
    Write-Log "Windows Recall AI snapshot tracking disabled." "Success"
}

New-TweakCard $P_Privacy "Kill Telemetry & DiagTrack" "Privacy" "Disables Connected User Experiences (DiagTrack), dmwappushservice, and data collection." {
    Write-Log "Disabling telemetry services..." "Warning"
    Stop-Service "DiagTrack", "dmwappushservice" -ErrorAction SilentlyContinue
    Set-Service "DiagTrack", "dmwappushservice" -StartupType Disabled -ErrorAction SilentlyContinue
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy" /v "TailoredExperiencesWithDiagnosticDataEnabled" /t REG_DWORD /d 0 /f | Out-Null
    Write-Log "Diagnostic data and telemetry logging disabled." "Success"
}

New-TweakCard $P_Privacy "No Bing Start Menu Search" "UI Privacy" "Removes Bing web search results and Cortana clutter from the Windows Start Menu." {
    reg add "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v "DisableSearchBoxSuggestions" /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v "BingSearchEnabled" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v "CortanaConsent" /t REG_DWORD /d 0 /f | Out-Null
    Write-Log "Start Menu web search removed." "Success"
}

New-TweakCard $P_Privacy "Disable Edge Background" "Startup Boost" "Prevents Microsoft Edge from running background tabs and pre-loading at boot." {
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v "BackgroundModeEnabled" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v "StartupBoostEnabled" /t REG_DWORD /d 0 /f | Out-Null
    Write-Log "Microsoft Edge background pre-loading disabled." "Success"
}

New-TweakCard $P_Privacy "Classic Context Menu" "Windows 11 UI" "Restores the Windows 10 full right-click context menu without 'Show more options'." {
    reg add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve | Out-Null
    Stop-Process -Name explorer -Force
    Write-Log "Windows 10 Classic Context Menu restored." "Success"
}

New-TweakCard $P_Privacy "File Explorer Pro Mode" "File System" "Shows file extensions (.exe, .txt), unhides system files, and shows full title paths." {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1
    Stop-Process -Name explorer -Force
    Write-Log "File Explorer configured to show extensions and hidden files." "Success"
}

# ------------------------------------------------------------------------------
# 6. HARDWARE & STORAGE AUDIT
# ------------------------------------------------------------------------------
$P_Hw = $script:CategoryPanels["Hardware"]

New-TweakCard $P_Hw "SMART Disk Health" "Storage Health" "Audits physical drives, media type (NVMe/SSD/HDD), and SMART health statuses." {
    Write-Log "Auditing physical storage disks..." "Exec"
    Get-PhysicalDisk | ForEach-Object {
        $st = if ($_.HealthStatus -eq "Healthy") { "Success" } else { "Error" }
        Write-Log "Disk #$($_.DeviceId) ($($_.FriendlyName)): Health=$($_.HealthStatus) | MediaType=$($_.MediaType) | Bus=$($_.BusType)" $st
    }
}

New-TweakCard $P_Hw "RAM Bank & Slot Audit" "Memory Specs" "Inspects physical RAM slots, module capacities, clock speeds, and manufacturers." {
    $sticks = Get-CimInstance Win32_PhysicalMemory
    $tot = [math]::Round(($sticks | Measure-Object -Property Capacity -Sum).Sum / 1GB, 2)
    Write-Log "Total Installed Memory: $tot GB across $($sticks.Count) slots:" "Success"
    foreach ($s in $sticks) {
        $gb = [math]::Round($s.Capacity / 1GB, 2)
        Write-Log "Slot $($s.BankLabel): $gb GB @ $($s.Speed) MHz ($($s.Manufacturer) - Part: $($s.PartNumber.Trim()))" "Info"
    }
}

New-TweakCard $P_Hw "Battery Health Diagnostic" "Power Report" "Generates a detailed HTML battery capacity and degradation report on your Desktop." {
    $p = "$env:USERPROFILE\Desktop\BatteryReport.html"
    powercfg /batteryreport /output $p | Out-Null
    Write-Log "Battery Diagnostic report saved to: $p" "Success"
}

New-TweakCard $P_Hw "GPU & Display Audit" "Graphics Specs" "Inspects installed GPU adapters, driver versions, and display resolutions." {
    Get-CimInstance Win32_VideoController | ForEach-Object {
        Write-Log "GPU: $($_.Name) - Driver Version: $($_.DriverVersion) - Resolution: $($_.CurrentHorizontalResolution)x$($_.CurrentVerticalResolution) @ $($_.CurrentRefreshRate)Hz" "Success"
    }
}

# ------------------------------------------------------------------------------
# 7. ADMIN UTILITIES & APPS
# ------------------------------------------------------------------------------
$P_Admin = $script:CategoryPanels["Admin"]

New-TweakCard $P_Admin "Create GodMode Shortcut" "Master Control" "Creates a master GodMode folder on the Desktop linking to all 200+ control applets." {
    $p = Join-Path ([Environment]::GetFolderPath("Desktop")) "GodMode.{ED7BA470-8E54-465E-825C-99712043E01C}"
    if (-not (Test-Path $p)) {
        New-Item -ItemType Directory -Path $p | Out-Null
        Write-Log "Master GodMode shortcut placed on Desktop." "Success"
    } else {
        Write-Log "GodMode shortcut already exists on Desktop." "Warning"
    }
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

New-TweakCard $P_Admin "Launch Group Policy Editor" "Quick Launcher" "Opens gpedit.msc directly." {
    Start-Process gpedit.msc; Write-Log "Group Policy Editor opened." "Success"
}

New-TweakCard $P_Admin "Defender Quick Scan" "Antivirus" "Updates threat intelligence signatures and launches a Windows Defender scan." {
    Write-Log "Updating Microsoft Defender signatures..." "Exec"
    Update-MpSignature | Out-Null
    Write-Log "Initiating Quick Antivirus Scan..." "Warning"
    Start-MpScan -ScanType QuickScan | Out-Null
    Write-Log "Microsoft Defender Quick Scan complete." "Success"
}

New-TweakCard $P_Admin "Winget Upgrade All Apps" "Package Manager" "Runs winget upgrade --all with auto-accepted package agreements." {
    Write-Log "Scanning for package upgrades via Winget..." "Warning"
    winget upgrade --all --include-unknown --accept-package-agreements --accept-source-agreements | ForEach-Object {
        if ($_.Trim() -ne "") { Write-Log $_ "Info" }
    }
    Write-Log "Winget package sync complete." "Success"
}

# --- [Select Default Tab] ---
$script:SidebarButtons["Dash"].PerformClick()

# --- [Background Live Telemetry Updater (Every 2s)] ---
$TelemetryTimer = New-Object System.Windows.Forms.Timer -Property @{Interval=2000; Enabled=$true}
$TelemetryTimer.Add_Tick({
    try {
        # CPU
        $cpuLoad = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
        $StatCPU.Text = "$([math]::Round($cpuLoad, 0))% Active"

        # RAM
        $os = Get-CimInstance Win32_OperatingSystem
        $freeMemGB = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
        $totMemGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
        $usedMemGB = [math]::Round($totMemGB - $freeMemGB, 1)
        $StatRAM.Text = "$usedMemGB / $totMemGB GB"

        # Disk C:
        $cDrive = Get-PSDrive C -ErrorAction SilentlyContinue
        if ($cDrive) {
            $freeGB = [math]::Round($cDrive.Free / 1GB, 1)
            $totGB = [math]::Round(($cDrive.Used + $cDrive.Free) / 1GB, 1)
            $StatDisk.Text = "$freeGB GB Free ($totGB GB)"
        }

        # Uptime
        $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
        $span = (Get-Date) - $boot
        $StatUp.Text = "$($span.Days)d $($span.Hours)h $($span.Minutes)m $($span.Seconds)s"
    } catch {}
})

Write-Log "AdminWorks Pro Suite loaded and ready." "Success"
[void]$Form.ShowDialog()