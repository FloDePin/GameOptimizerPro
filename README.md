# ⚡ GameOptimizerPro v1.0

> **Windows & Gaming Optimizer** — by FloDePin

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)
![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D6?logo=windows)
![License](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/Version-1.0-red)

🇬🇧 **English** | 🇩🇪 [Deutsch](README.de.md)

---

## 🚀 Quick Start (One-Liner)

Open **PowerShell as Administrator** and run:

```powershell
irm https://raw.githubusercontent.com/FloDePin/GameOptimizerPro/main/install.ps1 | iex
```

---



## 📸 Visual Preview

### GUI Overview
The interface follows the design of GameOptimizerPro v2.1:
- 🎨 **Dark-Mode UI** — WPF/XAML with a sidebar: Dashboard · Tweaks · Presets · BIOS Guide · Startup Manager · Services · Backups & Log
- 📊 **Dashboard** — hardware cards, optimization score, live monitor, ping test, snapshot & compare
- 🗂️ **Tweak list** — 8 category tabs, search across all tweaks, status dot + badges per tweak, description shown right under each tweak (DE/EN)
- 🎚️ **Presets page** — preview of each preset (green = already active), status per category
- 🔧 **BIOS Guide** — 16 platforms (AM5 / AM4 / Intel) with the menu path for ASUS, MSI, Gigabyte and ASRock; your platform is detected and pre-selected

---

## ✨ Features

| Tab | Features | Description |
|-----|----------|-------------|
| 🎚️ Presets | 3 levels | One-click **Minimal / Balanced / Aggressive** tweak selection (cumulative, safe-by-default) |
| 🪟 Windows | 43 Tweaks | Debloat, privacy, performance tweaks + CTT Essentials + Quality of Life |
| 🎮 Gaming | 12 Tweaks | Game Mode, Game Bar, MMCSS, CPU priority, fullscreen optimizations, MSI mode, HAGS |
| 🌐 Network | 11 Tweaks | Nagle, LSO, DNS, TCP tuning, QoS, adapter power saving, delivery optimization |
| 💾 RAM & Storage | 15 Tweaks | Page file, memory compression, hibernation, SSD/NVMe tweaks, temp cleanup + Deep Clean (6 tools, shows MB freed) |
| 🪟 Windows 11 | 7 Tweaks | Classic right-click menu, left taskbar, widgets, chat icon, Start recommendations, End Task, Snap hover menu |
| 🔊 Audio | 6 Tweaks | Audio enhancements, MMCSS audio profile, service priority, sound scheme, spatial sound, device power |
| 🎮 GPU Tweaks | 7 Tweaks | 4 NVIDIA + 3 AMD tweaks, GPU detection, brand grey-out |
| ⚡ Power Plan | 7 Tweaks | USB, PCI-E, HDD, display, sleep, CPU min/max |
| 📊 **Dashboard** | ✅ | Hardware cards, optimization score + monitor check (resolution/Hz), live monitor (CPU/RAM/disk/network), ping test (latency, packet loss, jitter), snapshot & compare, safety-net status |
| 🔧 **BIOS Guide** | 16 platforms | AM5 / AM4 / Intel LGA1851 / 1700 / 1200 / 1151 + generic, menu paths for ASUS / MSI / Gigabyte / ASRock, live check of EXPO/XMP, Resizable BAR, CSM and Secure Boot |
| 🚀 Startup Manager | ✅ | Own window, HKCU/HKLM/Run32 + startup folders, disable/enable/refresh |
| 🗄️ Backups & Log | ✅ | Registry backups, log, System Restore, Revert all and drift check in one place |
| 🌍 Language DE/EN | ✅ | 108 tweak descriptions + the whole BIOS Guide in German and English, switches live |

---

## 🪟 Windows Tab - 43 Tweaks

### 🧹 Debloat & System Cleanup
- **Remove Cortana** — Completely removes Windows' voice assistant
- **Remove Xbox Apps** — Disables Xbox and gaming-related apps
- **Remove Microsoft Teams (Personal)** — Removes the personal Teams installation
- **Remove Copilot** — Disables Windows Copilot
- **Remove OneDrive** — Removes the OneDrive integration
- **Remove Windows Recall** — Disables and removes Windows Recall (official policy; existing snapshots are deleted)
- **Remove Other Bloatware** — Removes additional pre-installed bloatware

### 🔐 Privacy Settings
- **Disable Telemetry & Data Collection** — Disables data collection
- **Disable Activity History** — Disables activity history storage
- **Disable Click to Do & Settings Agent (AI)** — Turns off AI screen analysis and the AI agent in Settings search (Copilot+ PCs)
- **Disable AI in Paint & Notepad** — Official policies for Cocreator, Image Creator, Generative Fill and Notepad AI

### 📦 Windows 11 & 10 Optimization
- **OS Scan** — Scans the operating system for optimization potential
- **Win11 Tweaks** — Specialized optimizations for Windows 11
- **Win10 Grey-out + Banner** — Optimized display for Windows 10 compatibility

### ⚡ Performance Tweaks
- **Disable Power Throttling** — Prevents Windows from throttling gaming processes via EcoQoS
- **Disable Bing in Windows Search** — Start menu searches only locally, no data exchange with Microsoft
- **Process Count Reduction (Svchost)** — Fewer background processes via an increased split threshold

### 🎯 CTT Essentials
Registry keys sourced **1:1 from Chris Titus Tech WinUtil** for guaranteed accuracy:
- **Prevent Device Companion Apps** — Blocks device metadata downloads + auto-suggested companion apps
- **Disable Consumer Features** — Stops auto-installed suggested apps/games in the Start menu
- **Disable Windows Platform Binary Table (WPBT)** — Blocks OEM firmware from injecting programs at boot (Security hardening)
- **Disable Store Recommended Search Results** — Removes sponsored results in the Microsoft Store
- **Enable Start Menu Previous Layout** — Classic Start layout on supported Win11 builds
- **Disable File Explorer Automatic Folder Discovery** — Opens large folders faster
- **Run Disk Cleanup** — Automated cleanmgr + DISM component cleanup

**All 7 tweaks include:** Full Apply/Revert functionality + EN/DE descriptions; 6 of them have a live status check ("Run Disk Cleanup" is a one-time action)

---

## 🔊 Audio Tab - 6 Tweaks

### 🎵 Audio Optimizations
- **6 Audio Tweaks** — Professional audio optimizations in their own tab
- Improved latency and playback quality
- Dedicated window for audio settings

---

## 🎮 GPU Tweaks Tab - 7 Tweaks

### NVIDIA Optimizations (4 Tweaks)
- **NVIDIA GPU Detection** — Automatic GPU detection
- **NVIDIA-Specific Tweaks** — 4 optimizations for NVIDIA graphics cards

### AMD Optimizations (3 Tweaks)
- **AMD-Specific Tweaks** — 3 optimizations for AMD graphics cards
- **Automatic GPU Detection** — Greys out incompatible tweaks

### Additional GPU Features
- **Brand Grey-out** — Only compatible GPU tweaks are shown

---

## ⚡ Power Plan Tab - 7 Tweaks

### 🔋 System Power Optimizations
- **USB Power Management** — Optimizes USB power management
- **PCI-E Optimizations** — Reduces PCIe latency
- **HDD/SSD Tweaks** — Disk power management
- **Display Power Tweaks** — Monitor power saving
- **Sleep Mode Optimizations** — Improved sleep behavior
- **CPU Min/Max Settings** — CPU frequency management
- **Comprehensive Power Plan Configuration** — 7 dedicated tweaks

---

## 🚀 Startup Manager

### 🖥️ Manage Startup Programs
- **Own Window** — Dedicated UI for startup management
- **Registry Integration** — HKCU/HKLM/Run32 entries + both startup folders
- **3-State Management** — Disable/enable/refresh functionality
- **Quick Control** — Start/stop auto-start programs

---

## 🔧 BIOS Guide

### 🎯 Every Common Platform, Not Just One Setup
The BIOS Guide covers **16 platforms**. Your CPU and board maker are detected and pre-selected, and you can open any other platform as a reference:

| Platform | Profiles |
|----------|----------|
| **AMD AM5** | Ryzen 9000X3D · Ryzen 9000 · Ryzen 7000X3D · Ryzen 7000 · Ryzen 8000G / 8000F |
| **AMD AM4** | Ryzen 5000X3D · Ryzen 5000 · Ryzen 5000G–2000G (APU) · Ryzen 3000 · Ryzen 1000 / 2000 |
| **Intel** | Core Ultra 200S (LGA1851) · Core 13th / 14th gen · Core 12th gen (LGA1700) · Core 10th / 11th gen (LGA1200) · Core 8th / 9th gen (LGA1151) |
| **Other** | Generic profile for laptops, Threadripper and unknown CPUs |

### 📋 What Every Setting Card Shows
- **Default vs. recommended value** — e.g. "Default: Off → Recommended: Profile 1 (DDR5-6000 CL30)"
- **Menu path for your board maker** — ASUS, MSI, Gigabyte, ASRock (switchable; a generic path for other boards)
- **Impact + risk badge** — high / medium / low impact, safe / moderate
- **Explanation in German or English** — what the setting does and what to do if the PC doesn't boot afterwards
- **Platform-specific settings** — EXPO/XMP/DOCP, Resizable BAR, CSM, Secure Boot, BIOS update (incl. the 13th/14th gen Vmin Shift fix), PBO, Curve Optimizer, FCLK, Memory Context Restore, C-States, core scheduling on dual-CCD X3D, iGPU, Intel Default Settings power limits, MCE, E-cores, 200S Boost, board-maker auto-install, PCIe slot speed
- **Filters** — Memory / CPU / GPU / Power / Boot & security, plus "only what's left to do"

### 🔍 Live Check From Windows
Four settings are read directly from Windows (no admin rights needed): **EXPO/XMP** (RAM speed vs. JEDEC base clock), **Resizable BAR** (NVIDIA), **CSM / UEFI** and **Secure Boot**. A green dot means already set, red means still to do.

### 📖 Read-Only Guide
- No automatic changes — the BIOS Guide never writes anything
- You make the BIOS changes yourself, with the menu path right on the card

---

## 🌍 Language Toggle - DE/EN

### 🗣️ Bilingual Tweak Descriptions (DE/EN)
- **108 tweak descriptions in German & English** — shown right under each tweak (full text as tooltip)
- **BIOS Guide in German & English** — all explanations and notes
- **Toggle Button** — "Info: DE / EN" in the sidebar switches everything live, no restart
- **Interface labels stay English** — the toggle affects the tweak descriptions, not the UI chrome

---

## 📋 Requirements

- **Windows 10 / 11**
- **PowerShell 5.1+**
- **Run as Administrator** (required!)
- **Internet Connection** — For download (first launch only)

---

## ✅ Compatibility

### Tested Windows Versions
- ✅ **Windows 11 21H2+** — Fully tested
- ✅ **Windows 11 22H2+** — Fully tested
- ✅ **Windows 10 20H2** — Fully compatible
- ✅ **Windows 10 21H2** — Fully compatible

### GPU Compatibility
- ✅ **NVIDIA** — GeForce RTX series (all modern GPUs)
- ✅ **AMD** — Radeon RX series (all modern GPUs)
- ⚠️ **Intel Arc** — All general tweaks work; the NVIDIA/AMD-specific GPU tweaks are greyed out

### CPU Compatibility (BIOS Guide)
- ✅ **AMD AM5** — Ryzen 7000 / 7000X3D / 8000G / 9000 / 9000X3D
- ✅ **AMD AM4** — Ryzen 1000 / 2000 / 3000 / 5000 / 5000X3D and the G-series APUs
- ✅ **Intel** — Core 8th–14th gen and Core Ultra 200S (desktop)
- ⚠️ **Laptops, Threadripper, other CPUs** — BIOS Guide shows the generic profile

---

## 🛡️ Safety & Security

✅ **System Restore Point** — Automatically created before any tweaks are applied  
✅ **Registry Backup** — Before every Apply/Revert, all affected registry keys are additionally exported as `.reg` files to `%LOCALAPPDATA%\GameOptimizerPro\RegistryBackups\` (independent of the System Restore Point limit)  
✅ **Detailed Logging** — All actions are logged to `%TEMP%\GameOptimizerPro_*.log`  
✅ **Hardware Detection** — GPU-specific tweaks are filtered automatically  
✅ **BIOS Guide Read-Only** — No automatic system changes from the BIOS Guide  
✅ **Fully Reversible** — All tweaks can be undone via System Restore or the registry backup  
✅ **Checksum Verification** — `install.ps1` checks the download against the SHA256 hash published in [CHECKSUMS.txt](CHECKSUMS.txt) before running the script with Admin rights  
✅ **No Malware** — Open source, fully auditable

---

## 🎨 GUI Features

- **Modern Dark-Mode UI** — Built on WPF/XAML, design tokens from GameOptimizerPro v2.1
- **Sidebar Navigation** — Dashboard | Tweaks | Presets | BIOS Guide | Startup Manager | Services | Backups & Log
- **8 Category Tabs + Search** — the search finds tweaks across all categories
- **Status at a Glance** — green dot = active, ring = inactive, grey = one-time action; badges for "removes app", "restart", "NVIDIA only", "Windows 11 only"
- **Descriptions Inline** — every tweak explains itself right under its name; a click on the text ticks the box
- **Bulk Selection** — All / None buttons, presets with preview
- **Live Logging** — Log file and registry backups one click away in the status bar
- **Hardware Info** — GPU, CPU, RAM, board, OS and monitor on the dashboard

---


## 🆘 Troubleshooting

### Problem: "Execution of scripts is disabled"
**Solution:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Problem: Script doesn't start
**Solution:**
- Make sure you have **Administrator rights**
- Try: `powershell -ExecutionPolicy Bypass -File GameOptimizerPro.ps1`

### Problem: GPU tweaks don't work
**Solution:**
- Make sure your GPU drivers are up to date
- A restart is required after GPU tweaks!
- Check the log file: `%TEMP%\GameOptimizerPro_*.log`

### Problem: BIOS Guide shows the wrong platform
**Solution:**
- Pick your platform in the list on the left and your board maker at the top — every profile is available manually
- Laptops, Threadripper and unknown CPUs get the generic profile on purpose
- "Check system state" re-reads EXPO/XMP, Resizable BAR, CSM and Secure Boot

### Problem: Tweaks weren't applied
**Solution:**
- A restart is required for many tweaks
- Check whether you actually enabled the tweaks
- Check the log file for error details

### Problem: System runs slower after tweaks
**Solution:**
- Use System Restore to undo all changes
- Start with fewer tweaks and test incrementally

---

## 📜 Changelog

### v1.0 — Initial public release
A complete, hardened Windows & gaming optimizer. Every tweak ships with **Apply + Revert**, and 98 of the 108 also with a **live status check** (the other 10 are one-time cleanups with nothing lasting to check), and each Apply first creates a **System Restore Point** and a **`.reg` registry backup** (stored in `%LOCALAPPDATA%\GameOptimizerPro\RegistryBackups`, safe from temp cleanup).

**Tweak library (108 tweaks, each with a revert; removed apps come back via System Restore):**
- 🪟 **Windows** — debloat, privacy, performance, CTT-Essentials & Quality-of-Life tweaks, including disabling on-device generative AI (Text & Image Generation), Click to Do, the Settings AI agent and AI in Paint & Notepad
- 🎮 **Gaming & GPU** — MSI mode, HAGS, NVIDIA/AMD driver tweaks, GPU timeout (TDR) tolerance, shader-cache tools
- 🌐 **Network** — latency (Nagle/LSO/throttling), DNS (Cloudflare/Google), TCP tuning, QoS, adapter power
- 🔊 **Audio** — MMCSS/audio-priority, spatial sound, sound-scheme & device-power tweaks
- 💾 **RAM & Storage** — page file, write-cache, plus a **Deep Clean** section (6 cleanup tools, each reports the MB it freed)
- ⚡ **Power Plan** — Ultimate Performance, HPET, 0.5 ms timer resolution

**Tools & UX:**
- ⚡ **Fast start** — the window is ready in about half the time (~9 s → ~4.5 s on a test PC), with a loading screen from the first moment
- 🎨 **New interface in the style of GameOptimizerPro v2.1** — sidebar navigation, dashboard with optimization score, tweak list with search, status dots, badges and inline DE/EN descriptions
- 🎚️ **Presets** — Minimal / Balanced / Aggressive (cumulative; destructive actions are never auto-selected), with a preview of every preset
- 📊 **Dashboard** with a **Live Resource Monitor** (CPU/RAM/disk/network on a background runspace, no UI stutter)
- 📶 **Ping Test** across 3 targets — average latency, packet loss % and jitter
- 🧰 **BIOS Guide** — 16 platforms (AM5 / AM4 / Intel), menu paths for ASUS / MSI / Gigabyte / ASRock, live check of EXPO/XMP, Resizable BAR, CSM and Secure Boot; read-only
- 🚀 **Startup Manager** — covers both the Run keys and the Startup folders

**Safety & robustness:**
- 🛡️ Startup **sanity check** guards against a status-check ever being confused with a revert action
- 🌍 **Locale-independent** throughout (SIDs, fixed GUIDs, CIM perf counters) — works on non-English Windows
- 🔒 **SHA256 integrity chain** — `install.ps1` pins the published hash and verifies it against `CHECKSUMS.txt` before running anything with Admin rights
- ✅ Verified: **108/108** tweaks have Apply + Revert, **98** of them a live status check (the other 10 are one-time cleanups), no collisions


---

## ⚠️ Disclaimer

**Use at your own risk.** Please review the script before running it.  
A System Restore Point is automatically created before any changes.  
The author is not liable for system damage caused by improper use.

---

## 💡 Tips for Maximum Performance

1. **Start with Safety** — Test a few tweaks first, then add more
2. **Enable Debloat** — Remove unnecessary pre-installed apps for a faster system
3. **Use Performance Tweaks** — Especially Power Throttling & Bing disable
4. **Enable GPU Tweaks** — Automatic detection of your GPU for the best results
5. **BIOS Guide Before Hardware Tuning** — Read the recommendations before making BIOS changes
6. **Optimize Power Plan** — Adjust the settings to your needs
7. **Audio Tweaks for Gaming** — Reduce audio latency
8. **Use Startup Manager** — Speed up boot time via startup optimization
9. **Keep NVIDIA/AMD Drivers Updated** — Matters more than most tweaks
10. **Restart After GPU Tweaks** — GPU optimizations need a reboot
11. **Check the Logs** — Review the log file for error details if something goes wrong
12. **Use System Restore** — All tweaks can be undone at any time

---

## 🤝 Contributing & Feedback

### Report Bugs
If you find a bug, please open an [Issue](https://github.com/FloDePin/GameOptimizerPro/issues)

### Feature Requests
Have an idea for a new feature? [Share it with us!](https://github.com/FloDePin/GameOptimizerPro/issues)

### Support
- 📧 Email: flodepin@googlemail.com
- 🐛 GitHub Issues: [Issues](https://github.com/FloDePin/GameOptimizerPro/issues)

---

## 📋 Planned Features for Future Versions

- 🎮 **Gaming Boost Profile** — Predefined optimization profiles for popular games
- 💾 **Disk Cleanup** — Automatic disk cleanup
- 🌙 **Auto-Scheduler** — Time-based optimizations

---

## 📄 License

This project is licensed under the **MIT License**. See [LICENSE](LICENSE) for details.

---

## 👨‍💻 About the Author

**FloDePin** — Windows & Gaming Enthusiast  
Passionate about system optimization and performance tuning

---

*Made with ❤️ by FloDePin*
