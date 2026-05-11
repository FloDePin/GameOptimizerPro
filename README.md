# ⚡ GameOptimizerPro

> **All-in-one Windows & Gaming Optimizer** — PowerShell GUI with checkboxes, info tooltips, hardware auto-detection and restore point backup.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue?logo=powershell)
![Windows](https://img.shields.io/badge/Windows-10%2F11-blue?logo=windows)
![License](https://img.shields.io/badge/License-MIT-green)
![Author](https://img.shields.io/badge/Author-FloDePin-red)

---

## 🚀 One-Liner Install

```powershell
irm "https://raw.githubusercontent.com/FloDePin/GameOptimizerPro/main/WinTweaker.ps1" | iex

```

> **Run PowerShell as Administrator!**

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

- Windows 10 (2004+) or Windows 11
- PowerShell 5.1+
- **Run as Administrator**

---

## ⚠️ Disclaimer

Use at your own risk. Always review scripts before running them.  
A system restore point is created automatically before applying tweaks.

---

## 📄 License

MIT — do whatever you want, credit appreciated.
