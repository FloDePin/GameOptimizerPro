# ⚡ WinTweaker

> Windows & Gaming Optimizer — PowerShell GUI Tool  
> by [FloDePin](https://github.com/FloDePin)

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)
![Windows](https://img.shields.io/badge/Windows-10%2F11-0078d4?logo=windows)
![License](https://img.shields.io/badge/License-MIT-green)

---

## 🚀 Quick Start (One-Liner)

Öffne **PowerShell als Administrator** und führe aus:

```powershell
irm "https://raw.githubusercontent.com/FloDePin/WinTweaker/main/WinTweaker.ps1" | iex
```

Oder lade die Datei herunter und starte sie direkt:

```powershell
.\WinTweaker.ps1
```

> ⚠️ Muss als **Administrator** ausgeführt werden. Vor dem Full-Run wird automatisch ein **System-Restore-Point** erstellt.

---

## ✨ Features

### 🪟 Windows Tab

| Feature | Was es macht |
|---|---|
| 🗑️ Remove Bloatware | Entfernt 30+ Apps: Cortana, Xbox, Copilot, Recall, OneDrive & mehr |
| 🔒 Privacy & Telemetry | Deaktiviert Windows-Datenschutzoptionen & blockiert Telemetrie-Hosts |
| 🚀 Performance | Ultimate Performance Plan, HAGS, 0.5ms Timer, Page File |
| 🖱️ Mouse & UI | Mausbeschleunigung aus, Sticky Keys aus, Dark Mode, Animationen aus |

### 🎮 Gaming Tab

| Feature | Was es macht |
|---|---|
| 📊 GPU & Driver | MSI Mode, HAGS, NVIDIA Low Latency / AMD Tweaks — **Hardware Auto-Detection** |
| ⚡ In-Game Boosts | Game Mode, 0.5ms Timer, CPU Priority, Fullscreen Optimizations aus, MMCSS High |

### 🌐 Network Tab

| Feature | Was es macht |
|---|---|
| 🌐 Network Tweaks | Nagle aus (TCPNoDelay), Cloudflare DNS (1.1.1.1), QoS 0%, TCP Auto-Tuning, LSO aus |

### ⚙️ System Tab

| Feature | Was es macht |
|---|---|
| 🎯 Full Run | Alle Tweaks auf einmal — mit Restore Point Prompt |
| 💾 Restore Point | Erstellt manuell einen Windows-Wiederherstellungspunkt |

---

## 🔍 Hardware Auto-Detection

Das Script erkennt beim Start automatisch deine Hardware:

```
GPU: NVIDIA GeForce RTX 4090 (24 GB, NVIDIA)  |  CPU: Intel Core i9-13900K  |  RAM: 32 GB
```

Basierend darauf werden die passenden Tweaks gewählt:
- **NVIDIA:** MSI Mode, Low Latency Mode, Shader Cache, HDCP off
- **AMD:** MSI Mode, Shader Cache, Anti-Lag Registry Keys
- **Intel GPU:** MSI Mode + Generic Tweaks
- **Intel CPU / AMD CPU:** Passende Timer & Kernel-Tweaks

---

## 🛡️ Sicherheit

- ✅ Vor dem **Full Run** wird automatisch ein **System-Restore-Point** erstellt
- ✅ Alle Aktionen werden in `%TEMP%\WinTweaker_*.log` geloggt
- ✅ Kein versteckter Code — 100% open source, direkt lesbar
- ✅ Keine externen Downloads oder Dependencies

---

## 📋 Voraussetzungen

- Windows 10 oder Windows 11
- PowerShell 5.1 oder höher
- **Administrator-Rechte** (Script fragt automatisch nach UAC)

---

## 📸 Screenshot

> Dark themed WPF GUI mit 4 Tabs: Windows / Gaming / Network / System  
> Live-Output-Log im unteren Bereich zeigt alle Aktionen in Echtzeit.

---

## ⚙️ Manueller Start (ohne One-Liner)

1. `WinTweaker.ps1` herunterladen
2. Rechtsklick → **"Mit PowerShell ausführen"**  
   oder in einer Admin-PowerShell:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\WinTweaker.ps1
```

---

## 📝 Log-Datei

Nach jeder Session findest du eine Log-Datei unter:
```
C:\Users\DEINNAME\AppData\Local\Temp\WinTweaker_20250511_143022.log
```

---

## ⚠️ Disclaimer

Diese Tweaks verändern Systemeinstellungen und Registry-Werte.  
Nutze das Tool auf eigene Verantwortung. Ein Restore-Point wird empfohlen (automatisch beim Full Run).

---

## 📄 License

MIT — Free to use, modify, and share.

---

*Made with ❤️ by [FloDePin](https://github.com/FloDePin)*
