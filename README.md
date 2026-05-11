# ⚡ WinTweaker
> Windows & Gaming Optimizer — by FloDePin

<p align="center">
  <img src="https://img.shields.io/badge/version-2.0.0-e94560?style=for-the-badge"/>
  <img src="https://img.shields.io/badge/PowerShell-5.1+-0078d4?style=for-the-badge&logo=powershell"/>
  <img src="https://img.shields.io/badge/Windows-10%2F11-0078d4?style=for-the-badge&logo=windows"/>
  <img src="https://img.shields.io/badge/Admin-Required-red?style=for-the-badge"/>
</p>

---

## 🚀 Quick Start (One-Liner)

Open **PowerShell as Administrator** and run:

```powershell
irm https://raw.githubusercontent.com/FloDePin/GameOptimizerPro/main/install.ps1 | iex
```

Or run directly:

```powershell
irm https://raw.githubusercontent.com/FloDePin/GameOptimizerPro/main/WinTweaker_v1.ps1 | iex
```

---

## 📋 Features

### 🪟 Windows Tab
| Group | Tweaks |
|-------|--------|
| **Bloatware** | Remove Cortana, Xbox Apps, Teams, Copilot, OneDrive, Recall, and 20+ pre-installed apps |
| **Privacy** | Disable Telemetry, Activity History, Advertising ID, Location Tracking, block telemetry hosts |
| **Performance** | Ultimate Performance Plan, Disable HPET, 0.5ms Timer, disable Superfetch, Visual Effects |
| **Mouse & UI** | Disable Mouse Acceleration, Sticky Keys, Enable Dark Mode, disable Transparency |

### 🎮 Gaming Tab
| Group | Tweaks |
|-------|--------|
| **In-Game Boosts** | Game Mode, disable Xbox Game Bar, CPU Priority, MMCSS Gaming Profile, Fullscreen Optimizations |
| **GPU & Driver** | NVIDIA Low Latency Mode, MSI Interrupts, HAGS, Clear Shader Cache |

### 🌐 Network Tab
| Group | Tweaks |
|-------|--------|
| **Latency** | Disable Nagle's Algorithm, disable LSO |
| **TCP** | Disable TCP Auto-Tuning |
| **QoS** | Remove QoS bandwidth limit |
| **DNS** | Set Cloudflare 1.1.1.1, Flush DNS Cache |

### 💾 RAM & Storage Tab *(New in v2.0)*
| Group | Tweaks |
|-------|--------|
| **RAM** | Increase Kernel Pool, Disable Memory Compression, Clear Standby Memory, Optimize Pagefile |
| **Storage** | Enable TRIM, Disable 8.3 filenames, Disable Last Access Timestamp, Clean Temp Files, Disk Cleanup |

---

## 🖥️ GUI Features
- **Dark theme** with red accent (#e94560)
- **Hardware detection** — shows GPU, CPU, RAM on startup
- **❓ Info buttons** — click to see what each tweak does
- **Progress bar** — shows live progress during apply
- **Automatic restore point** before applying tweaks
- **Log file** — every action is logged to `%TEMP%\WinTweaker_*.log`
- **Select All / Deselect All** buttons
- **4 Tabs**: Windows | Gaming | Network | RAM & Storage

---

## ⚙️ Requirements
- Windows 10 (2004+) or Windows 11
- PowerShell 5.1 or newer
- **Run as Administrator** (script will prompt if not)

---

## 🔒 Safety
- ✅ Creates a **System Restore Point** before applying any changes
- ✅ Every action is logged to `%TEMP%\WinTweaker_*.log`
- ✅ Open-source — review every tweak in the script
- ✅ GPU-specific tweaks auto-detect your hardware (NVIDIA/AMD)

---

## 📁 Project Structure
```
GameOptimizerPro/
├── WinTweaker_v2.ps1   ← Main optimizer script
├── install.ps1          ← One-liner installer
└── README.md            ← This file
```

---

## 📝 Changelog

### v2.0.0
- ➕ New **RAM & Storage** tab (9 new tweaks)
- ➕ **Progress bar** during apply
- 🐛 Fixed `$btn` closure bug in info button hover effects
- 🎨 Improved XAML button styles via `ControlTemplate.Triggers` (no more `PropertyNotFound`)
- ➕ 5 new Gaming tweaks (MMCSS, MSI Mode, HAGS, Shader Cache, Fullscreen Optimizations)
- ➕ 3 new Network tweaks (LSO, QoS, TCP Auto-Tuning)
- ➕ Automatic log file with timestamps

### v1.0.0
- Initial release with Windows, Gaming, Network tabs

---

## ⚠️ Disclaimer
This script modifies Windows registry and system settings.
While a restore point is created automatically, use at your own risk.
Always review the source code before running scripts from the internet.

---

<p align="center">Made with ❤️ by FloDePin</p>
