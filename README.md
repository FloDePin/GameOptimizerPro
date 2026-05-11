# ⚡ WinTweaker v3.0

> **Windows & Gaming Optimizer** — by FloDePin

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)
![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D6?logo=windows)
![License](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/Version-3.0-red)

---

## 🚀 Quick Start (One-Liner)

Open **PowerShell as Administrator** and run:

```powershell
irm https://raw.githubusercontent.com/FloDePin/GameOptimizerPro/main/install.ps1 | iex
```

---

## ✨ Features

| Tab | Tweaks | Description |
|-----|--------|-------------|
| 🪟 Windows | 23 Tweaks | Bloatware, Privacy, Performance, Mouse & UI |
| 🎮 Gaming | 12 Tweaks | Game Mode, GPU, MMCSS, HAGS, MSI, Shader Cache, BG Throttling, DX12 |
| 🌐 Network | 9 Tweaks | Nagle, DNS, TCP, LSO, QoS, Throttling Index, Google DNS |
| 💾 RAM & Storage | 9 Tweaks | PageFile, TRIM, Hibernation, NVMe, Temp Cleanup, Memory Compression |

### 🪟 Windows Tab
- Remove Cortana, Xbox Apps, Teams, Copilot, OneDrive, Recall, Bloatware
- Disable Telemetry, Activity History, Advertising ID, Location Tracking
- Block Telemetry Hosts, Disable Scheduled Tasks
- Ultimate Performance Plan, HPET, Timer Resolution, Superfetch, Visual Effects, Search Indexing
- Mouse Acceleration, Sticky Keys, Dark Mode, Transparency

### 🎮 Gaming Tab
- Game Mode, Xbox Game Bar, CPU Priority, MMCSS High Priority
- Fullscreen Optimizations, NVIDIA Low Latency, MSI Mode, HAGS, Shader Cache
- **NEW:** Disable Windows Update during Gaming
- **NEW:** Disable Background App Throttling
- **NEW:** Enable DirectX 12 Optimization

### 🌐 Network Tab
- Nagle's Algorithm (TCPNoDelay), LSO
- Cloudflare DNS (1.1.1.1), DNS Flush
- TCP Auto-Tuning, QoS Limit
- **NEW:** Disable Network Throttling Index
- **NEW:** Optimize TCP Settings (ECN, SACK, Timestamps)
- **NEW:** Set DNS to Google (8.8.8.8 / 8.8.4.4)

### 💾 RAM & Storage Tab *(NEW)*
- Optimize PageFile (System Managed)
- Clear PageFile on Shutdown
- Disable Memory Compression
- Enable SSD TRIM
- Disable Scheduled Defragmentation
- Disable Hibernation
- Clean Temp Files
- Optimize NVMe Queue Depth
- Disable Write-Cache Buffer Flushing

---

## 📋 Requirements

- Windows 10 / 11
- PowerShell 5.1+
- **Run as Administrator** (required)

---

## 🛡️ Safety

- Creates a **System Restore Point** before applying any tweaks
- Every action is **logged** to `%TEMP%\WinTweaker_*.log`
- Hardware detection — NVIDIA-only tweaks are skipped on AMD/Intel
- All tweaks are **reversible** via System Restore

---

## 📁 Files

| File | Description |
|------|-------------|
| `WinTweaker_v1.ps1` | Main script — GUI optimizer |
| `install.ps1` | One-liner installer / launcher |
| `README.md` | This file |

---

## 📜 Changelog

### v3.0
- 💾 Added: RAM & Storage Tab (9 Tweaks) — PageFile, TRIM, Hibernation, NVMe, Memory Compression, Temp Cleanup
- 🎮 Added: 3 new Gaming Tweaks — Disable WU during Gaming, BG App Throttling, DirectX 12 Optimization
- 🌐 Added: 3 new Network Tweaks — Throttling Index, TCP ECN/SACK, Google DNS
- 🐛 Fixed: `install.ps1` iex-Crash (leading `#` comment caused CommandNotFoundException)
- 🪟 Fixed: Console window now hidden via Win32 API (Kernel32 + User32) on startup
- ✅ Fixed: `?` InfoButtons — Hover effects fully moved to XAML ControlTemplate.Triggers (no more PropertyNotFound errors)

### v2.0
- ✅ Fixed MessageBox enum bug (`"OK"` → `[MessageBoxButton]::OK`)
- 🎮 Added: MMCSS Gaming Profile, Fullscreen Optimizations, HAGS, MSI Mode, Shader Cache
- 🌐 Added: LSO, QoS Limit, TCP Auto-Tuning
- 🎨 XAML `ControlTemplate.Triggers` for buttons and tabs
- 📋 Logging improved

### v1.0
- Initial release with Windows, Gaming, Network tabs

---

## ⚠️ Disclaimer

Use at your own risk. Always review scripts before running them.
A system restore point is created automatically before any changes.

---

*Made with ❤️ by FloDePin*
