# ⚡ GameOptimizerPro v3.0

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
| 🌐 Network | 12 Tweaks | Nagle, DNS, TCP, LSO, QoS, Throttling Index, Google DNS |
| 💾 RAM & Storage | 9 Tweaks | PageFile, TRIM, Hibernation, NVMe, Temp Cleanup, Memory Compression |

---

## 🪟 Windows Tab (23 Tweaks)

### 📦 Bloatware Removal (6 Tweaks)
- **Remove Cortana** — Entfernt Cortana vollständig. Reduziert Datenübertragung an Microsoft.
- **Remove Xbox Apps** — Deinstalliert Xbox Game Bar, Identity Provider, TCUI und Overlays.
- **Remove Microsoft Teams (Personal)** — Entfernt Teams Consumer-Version und blockiert Neuinstallation.
- **Remove Copilot** — Deaktiviert und entfernt Windows Copilot komplett.
- **Remove OneDrive** — Vollständige Deinstallation inkl. Explorer-Integration. Lokale Dateien bleiben.
- **Remove Other Bloatware** — Entfernt Candy Crush, TikTok, Disney+, Facebook, Instagram, Spotify, News, Solitaire, Clipchamp, ToDo, Paint3D und mehr.

### 🔒 Privacy (8 Tweaks)
- **Disable Telemetry and Data Collection** — Stoppt DiagTrack und dmwappushservice.
- **Disable Activity History** — Deaktiviert Windows Timeline-Funktion.
- **Disable Advertising ID** — Verhindert geräteübergreifendes Tracking durch Apps.
- **Disable Location Tracking** — Schaltet den Standortdienst systemweit aus.
- **Block Telemetry Hosts** — Blockiert Microsoft-Telemetrie-Server in der hosts-Datei.
- **Disable Scheduled Telemetry Tasks** — Deaktiviert geplante Aufgaben zur Datensammlung.

### ⚡ Performance (6 Tweaks)
- **Ultimate Performance Plan** — Aktiviert Ultimative Leistung. CPU-Kerne werden nicht gedrosselt.
- **Disable HPET** — Kann Latenz reduzieren und Gaming-Performance verbessern.
- **Set 0.5ms Timer Resolution** — Verbessert Frame-Timing und reduziert Input-Lag.
- **Disable Prefetch and Superfetch** — Reduziert Hintergrund-Schreibzugriffe (ideal für SSDs).
- **Optimize Visual Effects (Performance Mode)** — Schaltet alle Animationen aus für schnellere Reaktion.
- **Disable Windows Search Indexing** — Reduziert Festplattenzugriffe im Hintergrund.

### 🖱️ Mouse and UI (3 Tweaks)
- **Disable Mouse Acceleration** — 1:1 Übertragung wichtig für FPS-Spiele.
- **Disable Sticky Keys** — Verhindert ungewollte Unterbrechungen im Spiel.
- **Enable Dark Mode** — Schont die Augen bei langen Gaming-Sessions.
- **Disable Transparency Effects** — Spart GPU-Ressourcen in Taskleiste und Startmenü.

---

## 🎮 Gaming Tab (12 Tweaks)

### 🚀 In-Game Boosts (9 Tweaks)
- **Enable Game Mode** — Priorisiert CPU/GPU für aktive Spiele, blockiert WU-Neustarts.
- **Disable Xbox Game Bar** — Deaktiviert Win+G ohne Game Mode zu beeinflussen.
- **CPU Priority for Games (Win32Priority)** — Gibt aktiven Spielen deutlich mehr CPU-Zeit.
- **MMCSS Gaming Profile (High Priority)** — Priorisiert Audio und Timer-Interrupts.
- **Disable Fullscreen Optimizations** — Reduziert Input-Lag im Vollbildmodus.
- **Disable Windows Update During Gaming** — Verhindert Ressourcenverschwendung durch Windows Update.
- **Disable Background App Throttling** — Verhindert FPS-Drops durch Windows Throttling.
- **Enable DirectX 12 Optimization** — Aktiviert Registry-Optimierungen für bessere GPU-Nutzung in DX12-Spielen.

### 🖥️ GPU and Driver (4 Tweaks)
- **NVIDIA Low Latency Mode (Reflex)** — Ultra Low Latency Mode für NVIDIA GPUs. Render-Queue auf 1 Frame.
- **Enable MSI Mode (Message Signaled Interrupts)** — Reduziert Interrupt-Latenz erheblich. Reboot empfohlen.
- **Enable Hardware-Accelerated GPU Scheduling (HAGS)** — Benötigt NVIDIA RTX 2000+/AMD RX 5000+ und Windows 10 2004+.
- **Clear Shader Cache** — Leert NVIDIA/AMD Shader-Cache. Sinnvoll nach Treiberupdates.

---

## 🌐 Network Tab (12 Tweaks)

### 📡 Latency (3 Tweaks)
- **Disable Nagle's Algorithm (TCPNoDelay)** — Senkt Ping in Online-Spielen.
- **Disable Large Send Offload (LSO)** — Hilft bei instabilem Ping.
- **Disable Network Throttling Index** — Windows begrenzt Netzwerk-Durchsatz nicht mehr künstlich.

### 🔗 DNS (3 Tweaks)
- **Set DNS to Cloudflare (1.1.1.1)** — Schnell und datenschutzfreundlich.
- **Set DNS to Google (8.8.8.8)** — Sehr schnell und global verfügbar.
- **Flush DNS Cache** — Sinnvoll nach DNS-Änderungen oder Verbindungsproblemen.

### 🔌 TCP (2 Tweaks)
- **Disable TCP Auto-Tuning** — Kann Latenz-Spikes reduzieren.
- **Optimize TCP Settings (ECN and SACK)** — Deaktiviert ECN, SACK und TCP Timestamps für niedrigere Latenz.

### 📊 QoS (1 Tweak)
- **Disable QoS Packet Scheduler Limit** — Entfernt das 20%-Bandbreitenlimit das Windows reserviert.

---

## 💾 RAM & Storage Tab (9 Tweaks)

### 🧠 Memory (3 Tweaks)
- **Optimize PageFile (System Managed)** — Windows passt Auslagerungsdatei automatisch an.
- **Clear PageFile on Shutdown** — Verbessert Datenschutz und verhindert Datenlecks.
- **Disable Memory Compression** — Empfohlen ab 16 GB RAM. Reduziert CPU-Last.

### 💿 Storage (5 Tweaks)
- **Enable SSD TRIM** — Hält SSD-Leistung langfristig aufrecht.
- **Disable Scheduled Defragmentation** — Für SSDs schädlich und unnötig.
- **Disable Hibernation** — Spart Speicherplatz in RAM-Größe (hiberfil.sys wird gelöscht).
- **Optimize NVMe Queue Depth** — Verbessert Lese- und Schreibdurchsatz.
- **Disable Write-Cache Buffer Flushing** — Nur für Systeme mit UPS empfohlen.

### 🧹 Maintenance (1 Tweak)
- **Clean Temp Files** — Löscht temporäre Dateien aus TEMP und Windows Temp-Ordner.

---

## 📋 Requirements

- **Windows 10 / 11**
- **PowerShell 5.1+**
- **Run as Administrator** (erforderlich!)

---

## 🛡️ Safety & Security

✅ **System Restore Point** — Wird vor allen Tweaks automatisch erstellt  
✅ **Detailliertes Logging** — Alle Aktionen werden in `%TEMP%\GameOptimizerPro_*.log` protokolliert  
✅ **Hardware Detection** — NVIDIA-only Tweaks werden auf AMD/Intel übersprungen  
✅ **Vollständig reversibel** — Alle Tweaks können über System Restore rückgängig gemacht werden  

---

## 🎨 GUI Features

- **Moderne Dark-Mode UI** — Basierend auf WPF/XAML
- **Info-Buttons (?)** — Hover über `?` für Erklärungen zu jedem Tweak
- **Tabs für Kategorien** — Windows | Gaming | Network | RAM & Storage
- **Bulk Selektionen** — Select All / Deselect All Buttons
- **Live Logging** — Log-Datei kann jederzeit geöffnet werden
- **Hardware Info** — Zeigt GPU, CPU, RAM an

---

## 📁 Files

| File | Description |
|------|-------------|
| `GameOptimizerPro.ps1` | Hauptscript — GUI-Optimizer mit allen Tweaks |
| `install.ps1` | One-Liner Installer / Launcher |
| `README.md` | Diese Datei |

---

## 📜 Changelog

### v3.0
- 💾 **Added:** RAM & Storage Tab (9 Tweaks) — PageFile, TRIM, Hibernation, NVMe, Memory Compression, Temp Cleanup
- 🎮 **Added:** 3 neue Gaming Tweaks — Disable WU during Gaming, BG App Throttling, DirectX 12 Optimization
- 🌐 **Added:** 3 neue Network Tweaks — Throttling Index, TCP ECN/SACK, Google DNS
- 🐛 **Fixed:** `install.ps1` iex-Crash (führendes `#` Comment verursachte CommandNotFoundException)
- 🪟 **Fixed:** Konsolenfenster wird über Win32 API versteckt (Kernel32 + User32)
- ✅ **Fixed:** `?` InfoButtons — Hover-Effekte vollständig zu XAML ControlTemplate.Triggers verschoben

### v2.0
- ✅ **Fixed:** MessageBox enum bug (`"OK"` → `[MessageBoxButton]::OK`)
- 🎮 **Added:** MMCSS Gaming Profile, Fullscreen Optimizations, HAGS, MSI Mode, Shader Cache
- 🌐 **Added:** LSO, QoS Limit, TCP Auto-Tuning
- 🎨 **Improved:** XAML `ControlTemplate.Triggers` für Buttons und Tabs
- 📋 **Enhanced:** Logging-System

### v1.0
- 🚀 Initial release mit Windows, Gaming, Network Tabs

---

## ⚠️ Disclaimer

**Use at your own risk.** Bitte überprüfe das Script vor der Ausführung.  
Ein System Restore Point wird automatisch vor Änderungen erstellt.

---

## 💡 Tipps für maximale Performance

1. **Starte mit Safety** — Erst einige Tweaks testen, dann mehr hinzufügen
2. **Game Mode aktivieren** — Das ist eine der wichtigsten Optimierungen
3. **DNS optimieren** — Merkliche Verbesserung bei instabilem Internet
4. **NVIDIA/AMD Treiber aktuell halten** — Macht mehr aus als die meisten Tweaks
5. **Nach GPU Tweaks neustarten** — MSI Mode und HAGS brauchen einen Reboot

---

*Made with ❤️ by FloDePin*
