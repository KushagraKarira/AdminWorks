# --- [Self-Elevate] ---
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList "-ExecutionPolicy Bypass", "-File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# --- [Enable High-DPI Scaling] ---
Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;
public class DPI {
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();
}
"@
[DPI]::SetProcessDPIAware() | Out-Null
[System.Windows.Forms.Application]::EnableVisualStyles()

# --- [Visual Identity & Theme] ---
$script:Theme = @{
    Bg          = [System.Drawing.Color]::FromArgb(10, 10, 12)
    Header      = [System.Drawing.Color]::FromArgb(18, 18, 22)
    Card        = [System.Drawing.Color]::FromArgb(28, 28, 34)
    CardHover   = [System.Drawing.Color]::FromArgb(40, 40, 48)
    Accent      = [System.Drawing.Color]::FromArgb(0, 120, 215) 
    AccentGlow  = [System.Drawing.Color]::FromArgb(0, 180, 255)
    Success     = [System.Drawing.Color]::FromArgb(46, 204, 113)
    Warning     = [System.Drawing.Color]::FromArgb(241, 196, 15)
    Danger      = [System.Drawing.Color]::FromArgb(231, 76, 60)
    TextMain    = [System.Drawing.Color]::FromArgb(240, 240, 240)
    TextMuted   = [System.Drawing.Color]::FromArgb(140, 140, 150)
    Border      = [System.Drawing.Color]::FromArgb(45, 45, 55)
}

$GlobalFont = "Segoe UI Variable Display"
$CheckFont = New-Object System.Drawing.Font($GlobalFont, 10)
if ($CheckFont.Name -ne $GlobalFont) { $GlobalFont = "Segoe UI" }

# --- [Form Setup] ---
$Form = New-Object System.Windows.Forms.Form
$Form.Text            = "ADMINWORKS"
$Form.Size            = New-Object System.Drawing.Size(1250, 1050)
$Form.BackColor       = $script:Theme.Bg
$Form.StartPosition   = "CenterScreen"
$Form.FormBorderStyle = "None"
$Form.MinimumSize     = New-Object System.Drawing.Size(1100, 850)

try {
    $bf = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic
    $prop = $Form.GetType().GetProperty("DoubleBuffered", $bf)
    if ($prop) { $prop.SetValue($Form, $true, $null) }
} catch {}

# --- [Header: Window Controls & Device Info] ---
$Header = New-Object System.Windows.Forms.Panel -Property @{Dock="Top"; Height=85; BackColor=$script:Theme.Header}
$Form.Controls.Add($Header)

$TitleLbl = New-Object System.Windows.Forms.Label -Property @{
    Text      = "⚡ ADMINWORKS"
    Location  = New-Object System.Drawing.Point(25, 15); AutoSize = $true
    ForeColor = $script:Theme.TextMain; Font = New-Object System.Drawing.Font($GlobalFont, 12, [System.Drawing.FontStyle]::Bold)
}
$Header.Controls.Add($TitleLbl)

$LocalIP = "Searching..."
try {
    $ipObj = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -match 'Dhcp|Manual' -and $_.InterfaceAlias -notmatch 'Loopback|Virtual' } | Select-Object -First 1
    if ($ipObj) { $LocalIP = $ipObj.IPAddress } else { $LocalIP = "No LAN" }
} catch { $LocalIP = "Scanning..." }

$OS = (Get-CimInstance Win32_OperatingSystem)
$SysInfoLbl = New-Object System.Windows.Forms.Label -Property @{
    Text      = "$($env:COMPUTERNAME) | IP: $LocalIP | $($OS.Caption)"
    Location  = New-Object System.Drawing.Point(25, 45); Size = New-Object System.Drawing.Size(800, 25)
    ForeColor = $script:Theme.TextMuted; Font = New-Object System.Drawing.Font($GlobalFont, 8, [System.Drawing.FontStyle]::Bold)
}
$Header.Controls.Add($SysInfoLbl)

$UptimeLbl = New-Object System.Windows.Forms.Label -Property @{
    Location  = New-Object System.Drawing.Point(850, 45); Size = New-Object System.Drawing.Size(200, 25)
    ForeColor = $script:Theme.AccentGlow; Font = New-Object System.Drawing.Font($GlobalFont, 8, [System.Drawing.FontStyle]::Bold)
    TextAlign = "TopRight"; Anchor = [System.Windows.Forms.AnchorStyles]"Top, Right"
}
$Header.Controls.Add($UptimeLbl)

$CtrlBox = New-Object System.Windows.Forms.Panel -Property @{Dock="Right"; Width=150}
$Header.Controls.Add($CtrlBox)

function New-WinBtn($Text, $X, $Color, $Action) {
    $B = New-Object System.Windows.Forms.Button -Property @{
        Text = $Text; Size = New-Object System.Drawing.Size(40, 32); 
        Location = New-Object System.Drawing.Point($X, 14); FlatStyle = "Flat"; 
        ForeColor = $script:Theme.TextMuted; Tag = $Color
    }
    $B.FlatAppearance.BorderSize = 0
    $B.Add_Click($Action)
    $B.Add_MouseEnter({ $this.BackColor = $this.Tag; $this.ForeColor = [System.Drawing.Color]::White })
    $B.Add_MouseLeave({ $this.BackColor = [System.Drawing.Color]::Transparent; $this.ForeColor = $script:Theme.TextMuted })
    $CtrlBox.Controls.Add($B)
}
New-WinBtn "✕" 105 $script:Theme.Danger { $Form.Close() }
New-WinBtn "⬜" 60 $script:Theme.CardHover { if ($Form.WindowState -eq "Maximized") { $Form.WindowState = "Normal" } else { $Form.WindowState = "Maximized" } }
New-WinBtn "—" 15 $script:Theme.CardHover { $Form.WindowState = "Minimized" }

# --- [Dashboard Area] ---
$MainArea = New-Object System.Windows.Forms.Panel -Property @{Dock="Fill"; Padding=New-Object System.Windows.Forms.Padding(0)}
$Form.Controls.Add($MainArea)
$MainArea.BringToFront()

$script:DashView = New-Object System.Windows.Forms.Panel -Property @{Dock="Fill"; AutoScroll=$true}
$MainArea.Controls.Add($script:DashView)

# --- [Terminal] ---
$LogContainer = New-Object System.Windows.Forms.Panel -Property @{Dock="Bottom"; Height=220; BackColor=$script:Theme.Bg; Padding=New-Object System.Windows.Forms.Padding(30, 10, 30, 30)}
$Form.Controls.Add($LogContainer)

$LogBox = New-Object System.Windows.Forms.RichTextBox -Property @{
    Dock = "Fill"; BackColor = [System.Drawing.Color]::FromArgb(5, 5, 5);
    ForeColor = $script:Theme.TextMain; BorderStyle = "None"; ReadOnly = $true;
    Font = New-Object System.Drawing.Font("Consolas", 10)
}
$LogContainer.Controls.Add($LogBox)

$BtnExportLog = New-Object System.Windows.Forms.Button -Property @{
    Text = "EXPORT"; Size = New-Object System.Drawing.Size(60, 22); 
    FlatStyle = "Flat"; BackColor = $script:Theme.Header; ForeColor = $script:Theme.TextMuted;
    Font = New-Object System.Drawing.Font($GlobalFont, 7); Anchor = [System.Windows.Forms.AnchorStyles]"Bottom, Right"
}
$BtnExportLog.Location = New-Object System.Drawing.Point(1090, 10) # Placed right next to CLEAR
$BtnExportLog.FlatAppearance.BorderSize = 0
$BtnExportLog.Add_Click({ 
    $Path = "$env:USERPROFILE\Desktop\AdminWorks_Log_$((Get-Date).ToString('yyyy-MM-dd_HHmmss')).txt"
    $LogBox.Text | Out-File -FilePath $Path -Encoding UTF8
    Write-Log "Log exported to: $Path" "Success"
})
$LogContainer.Controls.Add($BtnExportLog)
$BtnExportLog.BringToFront()

function Write-Log ($Msg, $Type = "Info") {
    $LogBox.Invoke([Action[string, string]]{
        param($m, $t)
        if ([string]::IsNullOrWhiteSpace($m)) { return }
        $LogBox.SelectionStart = $LogBox.TextLength
        $LogBox.SelectionColor = switch ($t) {
            "Success" { $script:Theme.Success }
            "Warning" { $script:Theme.Warning }
            "Error"   { $script:Theme.Danger }
            Default   { $script:Theme.AccentGlow }
        }
        $LogBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] » $m`n")
        $LogBox.ScrollToCaret()
    }, $Msg, $Type)
}

# --- [Dashboard Layout Engine] ---
$global:LastY = 20
$global:Col = 0

function New-Section ($Title) {
    if ($global:Col -ne 0) { $global:LastY += 140 }
    $global:Col = 0
    $L = New-Object System.Windows.Forms.Label -Property @{
        Text = $Title.ToUpper(); Location = New-Object System.Drawing.Point(35, $global:LastY);
        Size = New-Object System.Drawing.Size(900, 30); ForeColor = $script:Theme.TextMuted;
        Font = New-Object System.Drawing.Font($GlobalFont, 9, [System.Drawing.FontStyle]::Bold)
    }
    $script:DashView.Controls.Add($L)
    $global:LastY += 40
}

# ----------------------------------------------------
# ASYNC TWEAK EXECUTION ENGINE (Prevents UI Freezing)
# ----------------------------------------------------
function New-Tweak ($Title, $Desc, $Action) {
    $X = 35 + ($global:Col * 320)
    $P = New-Object System.Windows.Forms.Panel -Property @{
        Size = New-Object System.Drawing.Size(305, 125); BackColor = $script:Theme.Card;
        Location = New-Object System.Drawing.Point($X, $global:LastY)
    }
    
    # FIX: Convert the script block to a string immediately while $Action still exists!
    $ActionString = $Action.ToString()

    $B = New-Object System.Windows.Forms.Button -Property @{
        Text = $Title; Dock = "Top"; Height = 65; FlatStyle = "Flat"; ForeColor = $script:Theme.TextMain; 
        Font = New-Object System.Drawing.Font($GlobalFont, 10, [System.Drawing.FontStyle]::Bold); TextAlign = "MiddleLeft";
        Padding = New-Object System.Windows.Forms.Padding(15, 0, 0, 0);
        Tag = $ActionString # Safely store the executable code inside the button object itself
    }
    $B.FlatAppearance.BorderSize = 0
    $B.Add_MouseEnter({ if ($this.Enabled) { $this.Parent.BackColor = $script:Theme.CardHover; $this.ForeColor = $script:Theme.AccentGlow } })
    $B.Add_MouseLeave({ if ($this.Enabled) { $this.Parent.BackColor = $script:Theme.Card; $this.ForeColor = $script:Theme.TextMain } })
    
    # Runspace Execution Logic
    $B.Add_Click({
        $Btn = $this
        $OriginalText = $Btn.Text
        $ActionStr = $Btn.Tag # Retrieve our safe string from the button!
        
        $Btn.Enabled = $false
        $Btn.Text = "$OriginalText (Running...)"
        $Btn.ForeColor = $script:Theme.Warning

        # Create Background PowerShell Instance
        $PS = [powershell]::Create().AddScript({
            param($ActionScript, $LogBox, $Theme)
            
            # Re-inject Write-Log so the background thread can talk to the UI Thread
            function Write-Log ($Msg, $Type = "Info") {
                if ([string]::IsNullOrWhiteSpace($Msg)) { return }
                $LogBox.Invoke([Action[string, string]]{
                    param($m, $t)
                    $LogBox.SelectionStart = $LogBox.TextLength
                    $LogBox.SelectionColor = switch ($t) {
                        "Success" { $Theme.Success }
                        "Warning" { $Theme.Warning }
                        "Error"   { $Theme.Danger }
                        Default   { $Theme.AccentGlow }
                    }
                    $LogBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] » $m`n")
                    $LogBox.ScrollToCaret()
                }, $Msg, $Type)
            }
            
            try { 
                # Re-compile the string back into executable code inside the new thread
                $ExecutableBlock = [scriptblock]::Create($ActionScript)
                & $ExecutableBlock 
            } catch { 
                Write-Log "Error: $($_.Exception.Message)" "Error" 
            }
        }).AddArgument($ActionStr).AddArgument($LogBox).AddArgument($script:Theme)

        $Runspace = [runspacefactory]::CreateRunspace()
        $Runspace.ThreadOptions = "ReuseThread"
        $Runspace.Open()
        $PS.Runspace = $Runspace

        $Handle = $PS.BeginInvoke()
        
        # Bulletproof Timer Logic using the Tag property
        $CheckTimer = New-Object System.Windows.Forms.Timer
        $CheckTimer.Interval = 500
        $CheckTimer.Tag = @{
            Button       = $Btn
            OriginalText = $OriginalText
            PSObj        = $PS
            RunspaceObj  = $Runspace
            ThemeState   = $script:Theme
        }
        $CheckTimer.Add_Tick({
            $State = $this.Tag
            if ($State.PSObj.InvocationStateInfo.State -ne "Running") {
                $State.Button.Enabled = $true
                $State.Button.Text = $State.OriginalText
                $State.Button.ForeColor = $State.ThemeState.TextMain
                $State.Button.Parent.BackColor = $State.ThemeState.Card
                
                $State.PSObj.Dispose()
                $State.RunspaceObj.Close()
                $State.RunspaceObj.Dispose()
                
                $this.Stop()
                $this.Dispose()
            }
        })
        $CheckTimer.Start()
    })

    $L = New-Object System.Windows.Forms.Label -Property @{
        Text = $Desc; Dock = "Bottom"; Height = 55; ForeColor = $script:Theme.TextMuted;
        Font = New-Object System.Drawing.Font($GlobalFont, 8); Padding = New-Object System.Windows.Forms.Padding(15, 0, 10, 0)
    }
    $P.Controls.AddRange(@($L, $B))
    $script:DashView.Controls.Add($P)
    $global:Col++
    if ($global:Col -eq 3) { $global:Col = 0; $global:LastY += 140 }
}

# --- [TWEAK POPULATION] ---
New-Section "Maintenance & Repair"

New-Tweak "Deep Repair" "DISM / SFC restoration cycle." { 
    Write-Log "Repair started... (This may take 10+ minutes)" "Warning"
    Write-Log "--> Running DISM Component Cleanup..." "AccentGlow"
    DISM /Online /Cleanup-Image /RestoreHealth | ForEach-Object { Write-Log $_ "Info" }
    
    Write-Log "--> Running System File Checker..." "AccentGlow"
    sfc /scannow | ForEach-Object { Write-Log $_ "Info" }
    Write-Log "Integrity verified." "Success" 
}

New-Tweak "Software Sync" "Upgrades all installed Winget packages." { 
    Write-Log "Syncing apps (including unknown & agreements)..." "Warning"
    winget upgrade --all --include-unknown --accept-package-agreements --accept-source-agreements | ForEach-Object { 
        # Filter out winget's blank progress bar lines
        if ($_.Trim() -ne "") { Write-Log $_ "Info" }
    }
    Write-Log "Apps synced." "Success" 
}

New-Tweak "OS Patching" "Force install Windows Updates." { 
    Write-Log "Checking and Installing Updates..." "Warning"
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction SilentlyContinue | Out-Null
    Install-Module PSWindowsUpdate -Force -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    
    Write-Log "Downloading and applying patches..." "AccentGlow"
    Get-WindowsUpdate -Install -AcceptAll -IgnoreReboot | ForEach-Object { 
        Write-Log "Update: $($_.Title) - $($_.Result)" "Info" 
    }
    Write-Log "Update cycle complete. Restart may be required." "Success"
}

New-Tweak "Storage Sweep" "ReTrim, Defrag C & D and clear temp." { 
    Write-Log "Optimizing storage..." "Warning"
    
    # Loop through both C and D drives
    foreach ($drive in @("C", "D")) {
        if (Test-Path "$drive`:\") {
            Write-Log "Optimizing Drive $drive..." "AccentGlow"
            Optimize-Volume -DriveLetter $drive -ReTrim -Defrag -Verbose 4>&1 | ForEach-Object { Write-Log $_.ToString() "Info" }
        } else {
            Write-Log "Drive $drive not found. Skipping." "Info"
        }
    }

    Write-Log "Running Disk Cleanup tool..." "AccentGlow"
    cleanmgr /sagerun:1
    Write-Log "Cleanup and defrag complete." "Success" 
}

New-Tweak "Wipe Event Logs" "Clears all Windows Event Viewer logs." { 
    Write-Log "Purging all Event Logs..." "Warning"
    wevtutil el | Foreach-Object { wevtutil cl "$_"; Write-Log "Cleared: $_" "Info" }
    Write-Log "Event logs cleared." "Success"
}

New-Tweak "Reset WU Cache" "Purges stuck Windows Update cache." { 
    Write-Log "Stopping Update services..." "Warning"
    Stop-Service -Name "wuauserv", "bits", "cryptsvc" -Force -ErrorAction SilentlyContinue
    Write-Log "Purging SoftwareDistribution and catroot2..." "AccentGlow"
    Remove-Item "$env:SystemRoot\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:SystemRoot\System32\catroot2\*" -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service -Name "wuauserv", "bits", "cryptsvc" -ErrorAction SilentlyContinue
    Write-Log "Windows Update cache reset and services restarted." "Success"
}

New-Tweak "Rebuild Icon Cache" "Fixes broken, blank, or glitchy app icons." { 
    Write-Log "Clearing Icon & Thumbnail cache..." "Warning"
    Stop-Process -Name explorer -Force
    Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache*" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache*" -Force -ErrorAction SilentlyContinue
    Start-Process explorer.exe
    Write-Log "Icon cache rebuilt." "Success"
}

New-Section "System Performance"
New-Tweak "Gaming Mode" "Ultimate Power & Low Latency UI." { 
    powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 | Out-Null
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value 0
    Write-Log "Performance profile active." "Success"
}
New-Tweak "Visual Boost" "Disable Animations & Transparency." { 
    reg add "HKCU\Control Panel\Desktop" /v UserPreferencesMask /t REG_BINARY /d 9012038010000000 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 0 /f | Out-Null
    Write-Log "Visual effects minimized for speed." "Success"
}
New-Tweak "CPU Lasso" "Priority boost for foreground apps." { 
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options" /v "CpuPriorityClass" /t REG_DWORD /d 3 /f | Out-Null
    Write-Log "CPU Threading optimized." "Success"
}
New-Tweak "Restart Explorer" "Fixes UI glitches & frozen taskbars." { 
    Stop-Process -Name explorer -Force
    Write-Log "Windows Explorer shell restarted." "Success"
}

New-Section "Networking & Connectivity"
New-Tweak "TCP Accelerator" "Tuning TCP/IP global stack." { 
    netsh int tcp set global autotuninglevel=normal; netsh int tcp set global rss=enabled
    Write-Log "TCP stack optimized." "Success"
}
New-Tweak "Cloudflare DNS" "Forces 1.1.1.1 on all adapters." { 
    Get-NetAdapter | Where { $_.Status -eq "Up" } | ForEach {
        Set-DnsClientServerAddress -InterfaceAlias $_.Name -ServerAddresses ("1.1.1.1", "1.0.0.1")
        Set-DnsClientServerAddress -InterfaceAlias $_.Name -ServerAddresses ("2606:4700:4700::1111", "2606:4700:4700::1001") -AddressFamily IPv6
    }
    Write-Log "Cloudflare DNS applied." "Success"
}
New-Tweak "DB LAN Fix" "SMB/Leasing fixes for DB stability." { 
    Set-SmbClientConfiguration -EnableSecuritySignature $false -Force
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "EnableOplocks" -Value 0
    New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\lanmanserver\parameters" -Name "DisableLeasing" -Value 1 -PropertyType DWORD -Force | Out-Null
    Restart-Service -Name "LanmanServer" -Force -ErrorAction SilentlyContinue
    Write-Log "Database LAN & SMB Leasing hardened." "Success"
}
New-Tweak "Adapter Hardening" "Max network stability & hardware buffers." {
    Write-Log "Tuning adapter stability rules..." "Warning"
    $StaticRules = @{ "*Energy*Efficient*"="Disabled"; "*Green*Ethernet*"="Disabled"; "*Advanced EEE*"="Disabled"; "*Idle Power Saving*"="Disabled"; "*Power Saving*"="Disabled"; "*Adaptive Link Speed*"="Disabled"; "*idle power down*"="No Restriction"; "*Battery Mode*"="Not Speed Down"; "*WOL & Shutdown*"="Not Speed Down"; "*Wake on link change*"="Disabled"; "*Wake on Magic*"="Disabled"; "*Wake on pattern*"="Disabled"; "*Large Send Offload*"="Disabled"; "*Recv Segment Coalescing*"="Disabled"; "*ARP Offload*"="Disabled"; "*NS Offload*"="Disabled"; "*Checksum Offload*"="Disabled"; "*Flow Control*"="Disabled"; "*Interrupt Moderation*"="Disabled"; "*Jumbo*"="Disabled" }
    $adapters = Get-NetAdapter -Physical
    if ($adapters) {
        foreach ($adapter in $adapters) {
            $advancedProps = Get-NetAdapterAdvancedProperty -Name $adapter.Name
            foreach ($prop in $advancedProps) {
                foreach ($rule in $StaticRules.GetEnumerator()) {
                    if ($prop.DisplayName -like $rule.Key -and $prop.DisplayValue -ne $rule.Value) {
                        try { Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $prop.DisplayName -DisplayValue $rule.Value -ErrorAction Stop; Write-Log "Set: $($prop.DisplayName) = $($rule.Value)" "Info" } catch {}
                    }
                }
                if ($prop.DisplayName -match "Receive Buffers|Transmit Buffers") {
                    foreach ($val in @("512", "256", "128", "64")) {
                        if ([int]$prop.DisplayValue -ge [int]$val) { break }
                        try { Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $prop.DisplayName -DisplayValue $val -ErrorAction Stop; Write-Log "Maxed: $($prop.DisplayName) = $val" "Info"; break } catch {}
                    }
                }
                if ($prop.DisplayName -match "Receive URBs|Transmit URBs") {
                    foreach ($val in @("64", "32", "16")) {
                        if ([int]$prop.DisplayValue -ge [int]$val) { break }
                        try { Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $prop.DisplayName -DisplayValue $val -ErrorAction Stop; Write-Log "Maxed: $($prop.DisplayName) = $val" "Info"; break } catch {}
                    }
                }
            }
        }
        Write-Log "Adapters locked to maximum stability." "Success"
    } else { Write-Log "No physical adapters found." "Error" }
}
New-Tweak "Network Reset" "Flushes DNS and resets Winsock." { 
    Write-Log "Flushing DNS..." "Warning"
    ipconfig /flushdns | ForEach-Object { Write-Log $_ "Info" }
    netsh winsock reset | ForEach-Object { Write-Log $_ "Info" }
    Write-Log "Network stack reset. Restart recommended." "Success"
}
New-Tweak "Network Diagnostics" "Pings gateway and DNS for latency/loss." { 
    Write-Log "Testing connectivity..." "Warning"
    $Targets = @("1.1.1.1", "8.8.8.8")
    foreach ($ip in $Targets) {
        $ping = Test-Connection -ComputerName $ip -Count 3 -ErrorAction SilentlyContinue
        if ($ping) {
            $avg = ($ping | Measure-Object -Property ResponseTime -Average).Average
            Write-Log "Ping $ip : Success (Avg Latency: $([math]::Round($avg, 1)) ms)" "Success"
        } else {
            Write-Log "Ping $ip : Failed (100% packet loss)" "Error"
        }
    }
}
New-Tweak "Listening Ports" "Dumps all active listening TCP ports." { 
    $Ports = Get-NetTCPConnection -State Listen | Select-Object -Property LocalAddress, LocalPort, OwningProcess -Unique | Sort-Object LocalPort
    Write-Log "Found $($Ports.Count) listening endpoints:" "Warning"
    foreach ($p in ($Ports | Select-Object -First 10)) {
        $proc = (Get-Process -Id $p.OwningProcess -ErrorAction SilentlyContinue).ProcessName
        Write-Log " -> Port $($p.LocalPort) on $($p.LocalAddress) (Process: $proc [PID $($p.OwningProcess)])" "Info"
    }
    if ($Ports.Count -gt 10) { Write-Log "...and $($Ports.Count - 10) more (truncated)." "Info" }
}

New-Section "Power & Hardware"
New-Tweak "Kill Hibernation" "Disables Hibernation to free space." { powercfg -h off; Write-Log "Hibernation disabled." "Success" }
New-Tweak "Never Sleep" "Prevents LAN timeout on AC power." { 
    powercfg -change -standby-timeout-ac 0; powercfg -change -monitor-timeout-ac 0
    Write-Log "AC Power timeouts removed." "Success" 
}
New-Tweak "Battery Health" "Generate Battery Diagnostic Report." { 
    $Path = "$env:USERPROFILE\Desktop\BatteryReport.html"
    powercfg /batteryreport /output $Path | ForEach-Object { Write-Log $_ "Info" }
    Write-Log "Report saved to Desktop." "Success" 
}
New-Tweak "USB Suspend Fix" "Disables OS USB Selective Suspend." {
    powercfg /SETACVALUEINDEX SCHEME_CURRENT 2a84c312-a001-40c3-b31f-1393d254d070 48e6b7a6-50f2-4389-a784-1779c7b048db 0
    powercfg /SETDCVALUEINDEX SCHEME_CURRENT 2a84c312-a001-40c3-b31f-1393d254d070 48e6b7a6-50f2-4389-a784-1779c7b048db 0
    powercfg /setactive SCHEME_CURRENT
    Write-Log "USB Selective Suspend disabled." "Success"
}
New-Tweak "Disk Health" "Checks SMART status for all drives." { 
    Write-Log "Querying physical storage drives..." "Warning"
    Get-PhysicalDisk | ForEach-Object {
        $HealthColor = if ($_.HealthStatus -eq "Healthy") { "Success" } else { "Error" }
        Write-Log "Drive #$($_.DeviceId) ($($_.FriendlyName)): Health=$($_.HealthStatus) | Operational=$($_.OperationalStatus) | Bus=$($_.BusType)" $HealthColor
    }
}
New-Tweak "RAM & Slot Info" "Audits installed memory sticks & speeds." { 
    $RamSticks = Get-CimInstance Win32_PhysicalMemory
    $TotalGB = [math]::Round(($RamSticks | Measure-Object -Property Capacity -Sum).Sum / 1GB, 2)
    Write-Log "Total Installed RAM: $TotalGB GB ($($RamSticks.Count) slots populated)" "Success"
    foreach ($stick in $RamSticks) {
        $StickGB = [math]::Round($stick.Capacity / 1GB, 2)
        Write-Log " -> Bank: $($stick.BankLabel) | $StickGB GB @ $($stick.Speed) MHz ($($stick.Manufacturer))" "Info"
    }
}

New-Section "Admin & Privacy"
New-Tweak "Print Fixer" "Reset Spooler & Clear Queue." { 
    Stop-Service Spooler -Force; Remove-Item "$env:SystemRoot\System32\Spool\Printers\*" -Force; Start-Service Spooler
    Write-Log "Printer services restored." "Success"
}
New-Tweak "OEM Debloat" "Nukes TikTok, CandyCrush, Meta, etc." { 
    # Expanded list of common Windows 10/11 consumer bloatware
    $Apps = @(
        # Social Media & Comms
        "*TikTok*", "*Instagram*", "*Facebook*", "*LinkedIn*", "*Twitter*", "*WhatsApp*",
        # Streaming & Media
        "*Disney*", "*PrimeVideo*", "*Spotify*", "*Netflix*", "*Hulu*",
        # Pre-installed Games
        "*CandyCrush*", "*BubbleWitch*", "*MarchOfEmpires*", "*HiddenCity*", "*Asphalt*", "*MinecraftUWP*",
        # OEM Trials & Third-Party
        "*McAfee*", "*Norton*", "*Dropbox*", "*Evernote*", 
        # Microsoft Consumer Fluff
        "*Clipchamp*", "*BingNews*", "*BingFinance*", "*BingSports*"
    )
    
    Write-Log "Scanning for OEM bloatware..." "Warning"
    $RemovedCount = 0

    foreach ($app in $Apps) { 
        # 1. Check if the app is currently installed
        $installedApp = Get-AppxPackage -Name $app -AllUsers -ErrorAction SilentlyContinue
        
        if ($installedApp) {
            # 2. Uninstall it for all current users
            $installedApp | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
            
            # 3. Nuke it from the Windows image so it doesn't reinstall on new accounts
            Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $app } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
            
            Write-Log "Successfully purged: $app" "Success"
            $RemovedCount++
        }
    }
    
    if ($RemovedCount -eq 0) {
        Write-Log "System is already clean. No bloatware found." "Info"
    } else {
        Write-Log "$RemovedCount bloatware packages permanently purged." "Success"
    }
}
New-Tweak "Recall Nuclear" "Total removal of AI Recall feature." { 
    Disable-WindowsOptionalFeature -Online -FeatureName "Recall" -Remove -NoRestart | ForEach-Object { Write-Log $_ "Info" }
    Write-Log "AI Tracking removed." "Success"
}
New-Tweak "Classic Context" "Restores Win10 right-click menu." { 
    reg add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve | Out-Null
    Stop-Process -Name explorer -Force
    Write-Log "Classic context menu restored." "Success"
}
New-Tweak "Kill Telemetry" "Disables DiagTrack & diagnostic logging." { 
    Write-Log "Disabling Telemetry & Diagnostic tracking..." "Warning"
    Stop-Service "DiagTrack" -ErrorAction SilentlyContinue
    Set-Service "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy" /v "TailoredExperiencesWithDiagnosticDataEnabled" /t REG_DWORD /d 0 /f | Out-Null
    Write-Log "Telemetry and Diagnostics disabled." "Success"
}
New-Tweak "No Bing Search" "Removes Bing & web clutter from Start." { 
    reg add "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v "DisableSearchBoxSuggestions" /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v "BingSearchEnabled" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v "CortanaConsent" /t REG_DWORD /d 0 /f | Out-Null
    Write-Log "Start Menu web search removed (Explorer restart recommended)." "Success"
}
New-Tweak "Explorer Pro" "Shows extensions & hidden files." { 
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSuperHidden" -Value 0
    Stop-Process -Name explorer -Force
    Write-Log "File Explorer set to show extensions and hidden items." "Success"
}
New-Tweak "Create GodMode" "Puts master Control Panel on Desktop." { 
    $Desktop = [Environment]::GetFolderPath("Desktop")
    $GodPath = Join-Path $Desktop "GodMode.{ED7BA470-8E54-465E-825C-99712043E01C}"
    if (-not (Test-Path $GodPath)) {
        New-Item -ItemType Directory -Path $GodPath | Out-Null
        Write-Log "GodMode shortcut created on Desktop." "Success"
    } else {
        Write-Log "GodMode shortcut already exists." "Warning"
    }
}

# --- [Resize/Drag Logic] ---
$global:Dragging = $false; $global:Resizing = $false; $global:MousePos = New-Object System.Drawing.Point
$Grip = New-Object System.Windows.Forms.Panel -Property @{Size=New-Object System.Drawing.Size(20,20); Cursor="SizeNWSE"}
$Grip.Anchor = [System.Windows.Forms.AnchorStyles]"Bottom, Right"
$Grip.Location = New-Object System.Drawing.Point(([int]$Form.Width - 20), ([int]$Form.Height - 20))
$Form.Controls.Add($Grip); $Grip.BringToFront()

$Grip.Add_MouseDown({ $global:Resizing = $true; $global:MousePos = [System.Windows.Forms.Cursor]::Position })
$Grip.Add_MouseUp({ $global:Resizing = $false })
$Header.Add_MouseDown({ $global:Dragging = $true; $global:MousePos = $Form.PointToClient([System.Windows.Forms.Cursor]::Position) })
$Header.Add_MouseUp({ $global:Dragging = $false })

$Timer = New-Object System.Windows.Forms.Timer -Property @{Interval=1000; Enabled=$true}
$Timer.Add_Tick({
    $Boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    $Span = (Get-Date) - $Boot
    $UptimeLbl.Text = "UPTIME: $($Span.Days)d $($Span.Hours)h $($Span.Minutes)m"
})

$DragTimer = New-Object System.Windows.Forms.Timer -Property @{Interval=10; Enabled=$true}
$DragTimer.Add_Tick({
    if ($global:Dragging) { $Form.Location = [System.Drawing.Point]::Subtract([System.Windows.Forms.Cursor]::Position, $global:MousePos) }
    if ($global:Resizing) {
        $CP = [System.Windows.Forms.Cursor]::Position
        $NewWidth = [int]($CP.X - $Form.Left); $NewHeight = [int]($CP.Y - $Form.Top)
        if ($NewWidth -ge 1100 -and $NewHeight -ge 900) { $Form.Size = New-Object System.Drawing.Size($NewWidth, $NewHeight) }
    }
})

[void]$Form.ShowDialog()
