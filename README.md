# ⚡ AdminWorks & AdminWorks Pro

**Enterprise Windows Administration & Optimization Suite**

AdminWorks is a powerful, GUI-driven PowerShell suite designed for IT professionals, system administrators, and power users. It provides a centralized dashboard to optimize, maintain, secure, and troubleshoot **Windows 10** and **Windows 11** environments—all without navigating through endless control panels.

---

## ✨ Key Features

AdminWorks Pro categorizes over 40+ system tweaks and tools into an intuitive interface:

* **🎯 1-Click Presets:** Instantly apply full-system configurations like "Gamer Mode", "Privacy Lockdown", or "Clean Workstation".
* **⚙️ Maintenance:** Execute deep system repairs (DISM/SFC), shrink the WinSxS component store, and seamlessly reset a broken Windows Update cache.
* **⚡ Performance:** Unlock the Ultimate Performance power plan, adjust CPU foreground priority, and eliminate hardware/UI latency.
* **☁️ Network & DNS:** Benchmark and apply Cloudflare/Google DNS, discover LAN devices, and audit saved Wi-Fi passwords.
* **🔒 Privacy & Bloatware:** Safely disable Windows 11 AI Recall, block Microsoft telemetry via hosts, and universally purge OEM bloatware.
* **▤ Shell & Explorer:** Restore the classic Windows 10 context menu on Windows 11, add "Take Ownership" shortcuts, and force-reveal hidden file extensions.
* **⛁ Hardware Audit:** Instantly check SMART disk health, physical RAM slot population, and generate battery degradation reports.
* **❖ Software Hub:** Batch-update all installed software silently via Winget, and 1-click install essential dev/admin tools (Sysinternals, VSCode, PowerToys).
* **⚒️ Admin Utilities:** Generate a GodMode desktop shortcut, force Time NTP syncs, and create safety restore points.

---

## 🚀 Installation & Usage

You do not need to install PowerShell modules or use the command line to run this tool. 

1. Navigate to the **[Releases](../../releases)** page.
2. Download the latest `AdminWorksPro.exe` or `AdminWorks.exe`.
3. Right-click the file and select **Run as Administrator**.
   *(Note: The tool will attempt to self-elevate if run normally, but explicit elevation is recommended).*

---

## 🛠️ Building from Source

This project uses **GitHub Actions** and the `ps2exe` module to automatically compile the raw `.ps1` scripts into standalone, GUI-only Windows executables (`-noConsole`).

Whenever a push is made to the `main` branch, the workflow will trigger, compile the scripts, and upload the ready-to-use `.exe` files as Workflow Artifacts. 

To compile manually on your own machine:
1. Open an elevated PowerShell prompt.
2. Run `Install-Module -Name ps2exe -Force`
3. Run `Invoke-ps2exe -inputFile ".\AdminWorksPro.ps1" -outputFile ".\AdminWorksPro.exe" -noConsole`

---

## 💻 System Requirements

* **OS:** Windows 10 (Build 10240+) or Windows 11 (Build 22000+)
* **Engine:** Windows PowerShell 5.1 (Built-in)
* **Dependencies:** `winget` (App Installer) is required for the Software Hub tab.

---

## ⚠️ Disclaimer

*AdminWorks modifies the Windows Registry, disables specific scheduled tasks, and alters system services. While automatic registry backups and system restore points are integrated, please ensure you understand the tweaks you are applying. Use at your own risk.*
