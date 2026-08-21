# ⚡ AdminWorks V10

**Enterprise Windows Administration & Optimization Suite**

AdminWorks is a powerful, GUI-driven PowerShell suite designed for IT professionals, system administrators, and power users. It provides a centralized dashboard to optimize, maintain, secure, and troubleshoot **Windows 10** and **Windows 11** environments—all without navigating through endless control panels.

---

## ✨ Key Features

AdminWorks Pro v10 categorizes over **70+ system tweaks, diagnostics, and tools** into an intuitive interface with **state-aware dynamic toggles**:

* **🎯 1-Click Presets:** Instantly apply curated full-system configurations like "Gamer Mode", "Privacy Lockdown", "Clean Workstation", "Express Maintenance", or rollback the latest registry backup.
* **⚙️ Maintenance:** Execute deep system repairs (DISM/SFC), shrink the WinSxS component store, reset broken Windows Update caches, purge all Windows Event Logs, empty all Recycle Bins, and rebuild the search index.
* **⚡ Performance:** Unlock the Ultimate Performance power plan, adjust CPU foreground priority (`Win32PrioritySeparation`), eliminate UI/window transition latency, and toggle Xbox GameDVR background recording and system hibernation.
* **☁️ Network & DNS:** Benchmark and apply Cloudflare/Google DNS, audit listening ports & owning processes, resolve public WAN IP & ISP location, sweep LAN subnets, extract saved Wi-Fi keys, and toggle Remote Desktop (RDP).
* **🔒 Privacy & Bloatware:** Safely disable Windows 11 AI Recall, toggle Microsoft telemetry & `DiagTrack`, block telemetry endpoints in hosts, disable Lock Screen Spotlight ads & tips, toggle Activity History tracking, and universally purge OEM bloatware.
* **▤ Shell & Explorer:** Toggle the classic Windows 10 context menu on Windows 11, add "Take Ownership" and elevated PowerShell right-click shortcuts, toggle Explorer Compact View, and force-reveal hidden files & extensions.
* **⛁ Hardware Audit:** Check S.M.A.R.T. disk health, physical RAM slot population & clock speeds, motherboard & BIOS/UEFI version (with Secure Boot detection), CPU virtualization flags (VT-x/AMD-V), disk sector geometry (4Kn/512e), and generate HTML battery degradation reports.
* **❖ Software Hub:** Batch-update all installed software silently via Winget, export app manifests to JSON, and 1-click install standalone tools (**WinToys**, **VLC Media Player**, **Sumatra PDF**, **PowerToys**, **7-Zip**, **Sysinternals Suite**) as well as complete Developer and SysAdmin bundles.
* **⚒️ Admin Utilities:** Generate a master GodMode shortcut, audit local Administrators and active SMB network shares, check Windows digital activation & product key status, and quick-launch essential management consoles (Services, Event Viewer, Task Scheduler, and Advanced Firewall).

---

## 🚀 Installation & Usage

You do not need to install complex dependencies or use the command line to run this tool. 

1. Navigate to the **[Releases](../../releases)** page.
2. Download the latest `AdminWorks.ps1`.
3. Right-click the file and select **Run as Administrator**.  
   *(Note: The tool will attempt to self-elevate if run normally, but explicit elevation is recommended).*

---

## 🛠️ Building from Source

This project uses **GitHub Actions** and the `ps2exe` module to automatically compile the raw `.ps1` scripts into standalone, GUI-only Windows executables (`-noConsole`).

Whenever a push is made to the `main` branch, the workflow will trigger, compile the scripts, and upload the ready-to-use `.exe` files as Workflow Artifacts. 

To compile manually on your own machine:
1. Open an elevated PowerShell prompt.
2. Run `Install-Module -Name ps2exe -Force`
3. Run `Invoke-ps2exe -inputFile ".\AdminWorks.ps1" -outputFile ".\AdminWorksPro.exe" -noConsole`

---

## 💻 System Requirements

* **OS:** Windows 10 (Build 10240+) or Windows 11 (Build 22000+)
* **Engine:** Windows PowerShell 5.1 (Built-in) or PowerShell 7+
* **Dependencies:** `winget` (Microsoft App Installer) is required for Software Hub package installations (auto-install/repair script included).

---

## ⚠️ Disclaimer

*AdminWorks modifies the Windows Registry, disables specific scheduled tasks, and alters system services. While automatic registry backups and system restore points are integrated, please ensure you understand the tweaks you are applying. Use at your own risk.*
