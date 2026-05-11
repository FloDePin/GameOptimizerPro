# ⚡ GameOptimizerPro

> **All-in-one Windows & Gaming Optimizer** — PowerShell GUI with checkboxes, info tooltips, hardware auto-detection and restore point backup.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue?logo=powershell)
![Windows](https://img.shields.io/badge/Windows-10%2F11-blue?logo=windows)
![License](https://img.shields.io/badge/License-MIT-green)
![Author](https://img.shields.io/badge/Author-FloDePin-red)

## 📋 Table of Contents

- [Quick Start](#-quick-start)
- [Features](#-features)
- [Safety Features](#️-safety-features)
- [GUI Preview](#-gui-preview)
- [Requirements](#️-requirements)
- [Usage](#-usage)
- [Troubleshooting](#-troubleshooting)
- [Restore & Undo](#-restore--undo)
- [Contributing](#-contributing)
- [License](#-license)
- [Disclaimer](#️-disclaimer)

---

## 🚀 Quick Start

### One-Liner Install

```powershell
irm "https://raw.githubusercontent.com/FloDePin/GameOptimizerPro/main/WinTweaker.ps1" | iex
```

> **⚠️ Run PowerShell as Administrator!**

### Manual Install

1. Download `WinTweaker.ps1` from the [repository](https://github.com/FloDePin/GameOptimizerPro)
2. Open **PowerShell as Administrator**
3. Navigate to the script location
4. Run: `.\WinTweaker.ps1`

---

## ✨ Features

### 🪟 Windows Tab
| Group | Tweaks |
|-------|--------|
| **Bloatware** | Remove Cortana, Xbox Apps, Teams, Copilot, OneDrive, Recall, 25+ more |
| **Privacy** | Disable Telemetry, Activity History, Advertising ID, Location, Block Telemetry Hosts, Disable Scheduled Tasks |
| **Performance** | Ultimate Performance Plan, HPET off, 0.5ms Timer, Prefetch off, Visual Effects, Search Indexing off |
| **Mouse & UI** | Disable Mouse Acceleration, Sticky Keys off, Dark Mode, Transparency off |

### 🎮 Gaming Tab
| Group | Tweaks |
|-------|--------|
| **In-Game Boosts** | Game Mode, Xbox Game Bar off, CPU Priority (Win32), MMCSS High, Fullscreen Optimizations off |
| **GPU & Driver** | NVIDIA Low Latency (auto-skip if no NVIDIA), MSI Mode, HAGS, Shader Cache Cleaner |

### 🌐 Network Tab
| Group | Tweaks |
|-------|--------|
| **Latency** | Nagle off (TCPNoDelay), LSO disabled |
| **DNS** | Cloudflare 1.1.1.1, DNS Cache Flush |
| **TCP** | Auto-Tuning disabled |
| **QoS** | Bandwidth limit removed |

---

## 🛡️ Safety Features

- ✅ **Admin check** — won't run without elevation
- ✅ **Restore Point** created before applying any tweaks
- ✅ **Checkbox system** — apply only what YOU select
- ✅ **? Info button** on every tweak — explains exactly what it does
- ✅ **Log file** saved to `%TEMP%\WinTweaker_TIMESTAMP.log`
- ✅ **Hardware auto-detection** — NVIDIA/AMD tweaks skip automatically on wrong hardware

---

## 📸 GUI Preview

```
┌─────────────────────────────────────────────────────────────┐
│  ⚡ WinTweaker                                               │
│  Windows & Gaming Optimizer — by FloDePin                   │
│  GPU: RTX 4090  |  CPU: i9-13900K  |  RAM: 32 GB           │
├──────────────┬──────────────┬──────────────────────────────┤
│ 🪟 Windows   │ 🎮 Gaming    │ 🌐 Network                   │
├──────────────┴──────────────┴──────────────────────────────┤
│  ── Bloatware                                               │
│  ☑ Remove Cortana                              [?]         │
│  ☑ Remove Xbox Apps                            [?]         │
│  ☑ Remove OneDrive                             [?]         │
│                                                             │
│  ── Privacy                                                 │
│  ☑ Disable Telemetry & Data Collection         [?]         │
│  ☐ Block Telemetry Hosts (hosts file)          [?]         │
│                                                             │
│  [☑ Select All]  [☐ Deselect All]  [✅ Apply Selected]     │
└─────────────────────────────────────────────────────────────┘
```

---

## ⚙️ Requirements

- **Windows 10** (2004+) or **Windows 11**
- **PowerShell 5.1+**
- **Administrator privileges** (script will check automatically)
- Optional: NVIDIA or AMD drivers for GPU optimizations

---

## 📖 Usage

### Running the Script

1. Launch **PowerShell as Administrator**
2. Execute the script (one-liner or manual)
3. The GUI will appear with three tabs: Windows, Gaming, Network
4. Review each tweak by clicking the **[?]** button for descriptions
5. Check the boxes for tweaks you want to apply
6. Click **[✅ Apply Selected]**
7. A system restore point will be created automatically
8. Tweaks will be applied and logged

### Selecting Tweaks

- **Select All** — Enable all tweaks at once
- **Deselect All** — Clear all selections
- **[?] Info Buttons** — Hover or click to see detailed explanations
- **Individual Checkboxes** — Enable/disable specific tweaks

### Hardware Auto-Detection

- NVIDIA-specific tweaks are **skipped on AMD systems** (and vice versa)
- GPU model is detected automatically from WMI
- CPU model and RAM are displayed in the title bar

---

## 🔧 Troubleshooting

### Script won't run?
- **Error**: "cannot be loaded because running scripts is disabled"
  - **Solution**: Run PowerShell as Administrator and execute: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`
  
- **Error**: "Access Denied"
  - **Solution**: Right-click PowerShell and select "Run as Administrator"

### Tweaks not applying?
- Check the log file: `%TEMP%\WinTweaker_TIMESTAMP.log`
- Ensure you have administrator privileges
- Some tweaks require a system restart to take effect

### Script is slow?
- This is normal on first run — restore point creation takes time
- Subsequent runs will be faster

### Specific tweaks causing issues?
- Use the checkbox system to apply tweaks selectively
- Identify problematic tweaks by enabling them one at a time
- Report the issue on GitHub with your log file

---

## 💾 Restore & Undo

### Automatic Restore Point

A **system restore point** is created automatically before applying any tweaks. To restore your system:

1. Press **Win + R**, type `rstrui.exe`, and press Enter
2. Select "Choose a different restore point"
3. Find the restore point created by **WinTweaker** (timestamped)
4. Click "Next" and confirm
5. Your system will restart and revert to the previous state

### Manual Rollback

If you prefer to undo specific tweaks:

1. Check the log file at `%TEMP%\WinTweaker_TIMESTAMP.log`
2. Each tweak shows the Registry key or command executed
3. Manually revert changes in Registry Editor (`regedit`)
4. Or restore your system using the restore point

---

## 🤝 Contributing

Found a bug or have a feature request? [Open an issue](https://github.com/FloDePin/GameOptimizerPro/issues) on GitHub.

**Before reporting**, please:
- Check if the issue already exists
- Include your `WinTweaker_TIMESTAMP.log` file
- Specify your Windows version and hardware configuration

---

## ⚙️ File Structure

```
FloDePin/GameOptimizerPro/
├── WinTweaker.ps1          # Main script (all-in-one)
├── README.md               # This file
└── LICENSE                 # MIT License
```

---

## ⚠️ Disclaimer

Use at your own risk. Always review scripts before running them.

- **No warranty** — This script modifies system settings. We're not responsible for any issues
- **Test first** — Consider testing in a virtual machine before using on production systems
- **Automatic backup** — A restore point is created, but always have backups
- **Review changes** — Read the [?] tooltips to understand what each tweak does

---

## 📄 License

**MIT License** — do whatever you want, credit appreciated.

See the [LICENSE](LICENSE) file for full details.

---

## 👤 Author

**FloDePin** — Windows & Gaming Optimization Enthusiast

[GitHub](https://github.com/FloDePin) | [Repository](https://github.com/FloDePin/GameOptimizerPro)

