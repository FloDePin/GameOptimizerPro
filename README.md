# ⚡ GameOptimizerPro v1.0

> **Windows & Gaming Optimizer** — by FloDePin

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)
![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D6?logo=windows)
![License](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/Version-1.0-red)

---

## 🚀 Quick Start (One-Liner)

Open **PowerShell as Administrator** and run:

```powershell
irm https://raw.githubusercontent.com/FloDePin/GameOptimizerPro/main/install.ps1 | iex
```

---



## 📸 Visual Preview

### GUI Übersicht
Das Tool bietet eine moderne, benutzerfreundliche Oberfläche mit:
- 🎨 **Dark-Mode UI** — Moderne WPF/XAML Oberfläche
- 🖱️ **Intuitive Navigation** — 6 Tabs für alle Funktionen
- ℹ️ **Info-Buttons** — Detaillierte Erklärungen für jeden Tweak
- 📊 **System Info** — GPU, CPU, RAM Status in Echtzeit

---

## ✨ Features

| Tab | Tweaks | Description |
|-----|--------|-------------|
| 🪟 Windows | 12 Tweaks | Debloat, Datenschutz, Win11-Tweaks, Win10-Grauausblendung + Banner |
| 🔊 Audio | 6 Tweaks | Audio-Tweaks, eigener Tab |
| 🎮 GPU Tweaks | 7 Tweaks | 4 NVIDIA + 3 AMD Tweaks, GPU-Erkennung, Brand-Grauausblendung |
| ⚡ Power Plan | 7 Tweaks | USB, PCI-E, HDD, Display, Sleep, CPU Min/Max |
| 🚀 Startup Manager | ✅ | Eigenes Fenster, HKCU/HKLM/Run32, Disable/Enable/Refresh |
| 🌍 Language DE/EN | ✅ | 80 EN-Beschreibungen, Toggle-Button, live umschaltbar |

---

## 🪟 Windows Tab - 12 Tweaks

### 🧹 Debloat & System Cleanup
- **Remove Cortana** — Entfernt den Windows Sprachassistenten
- **Remove Xbox Apps** — Deaktiviert Xbox und Gaming-bezogene Apps
- **Remove Microsoft Teams (Personal)** — Entfernt die persönliche Teams-Installation
- **Remove Copilot** — Deaktiviert Windows Copilot
- **Remove OneDrive** — Entfernt die OneDrive-Integration
- **Remove Windows Recall** — Deaktiviert Windows Recall Feature
- **Remove Other Bloatware** — Entfernt zusätzliche vorinstallierte Bloatware

### 🔐 Privacy-Einstellungen
- **Disable Telemetry & Data Collection** — Deaktiviert Datenerfassung
- **Disable Activity History** — Deaktiviert die Aktivitätsverlauf-Speicherung

### 📦 Windows 11 & 10 Optimization
- **OS-Scan** — Scannt das Betriebssystem auf Optimierungspotenziale
- **Win11 Tweaks** — Spezialisierte Optimierungen für Windows 11
- **Win10 Grauausblendung + Banner** — Optimierte Darstellung für Windows 10-Kompatibilität

---

## 🔊 Audio Tab - 6 Tweaks

### 🎵 Audio-Optimierungen
- **6 Audio-Tweaks** — Professionelle Audiooptimierungen in eigenem Tab
- Verbesserte Latenz und Wiedergabequalität
- Dediziertes Fenster für Audio-Einstellungen

---

## 🎮 GPU Tweaks Tab - 7 Tweaks

### NVIDIA Optimierungen (4 Tweaks)
- **NVIDIA GPU Detection** — Automatische Erkennung der GPU
- **NVIDIA-spezifische Tweaks** — 4 Optimierungen für NVIDIA-Grafikkarten

### AMD Optimierungen (3 Tweaks)
- **AMD-spezifische Tweaks** — 3 Optimierungen für AMD-Grafikkarten
- **Automatische GPU-Erkennung** — Greyt-out von nicht-kompatiblen Tweaks

### Weitere GPU-Features
- **Brand Grauausblendung** — Nur kompatible GPU-Tweaks werden angezeigt

---

## ⚡ Power Plan Tab - 7 Tweaks

### 🔋 Systemenergie-Optimierungen
- **USB Power Management** — USB-Energieverwaltung optimieren
- **PCI-E Optimierungen** — PCIe-Latenz reduzieren
- **HDD/SSD Tweaks** — Festplatte Energieverwaltung
- **Display Power Tweaks** — Monitor-Energiesparen
- **Sleep Mode Optimierungen** — Verbessertes Schlafverhalten
- **CPU Min/Max Einstellungen** — CPU-Frequenz-Management
- **Umfassende Power Plan Konfiguration** — 7 dedizierte Tweaks

---

## 🚀 Startup Manager

### 🖥️ Startup-Programme verwalten
- **Eigenes Fenster** — Dedizierte UI für Startup-Verwaltung
- **Registry-Integration** — HKCU/HKLM/Run32-Einträge
- **3-State-Management** — Disable/Enable/Refresh Funktionalität
- **Schnelle Kontrolle** — Starten/Stoppen von Auto-Start-Programmen

---

## 🌍 Language Toggle - DE/EN

### 🗣️ Mehrsprachigkeit
- **80+ englische Beschreibungen** — Vollständige EN-Lokalisierung
- **Toggle-Button** — Schneller Wechsel zwischen Deutsch und Englisch
- **Live-Umschaltbar** — Keine Neustart erforderlich
- **Alle Tweaks übersetzt** — Konsistente mehrsprachige UI

---

## 📋 Requirements

- **Windows 10 / 11**
- **PowerShell 5.1+**
- **Run as Administrator** (erforderlich!)
- **Internet Connection** — Für Download (nur beim ersten Start)

---

## ✅ Kompatibilität

### Getestete Windows Versionen
- ✅ **Windows 11 21H2+** — Vollständig getestet
- ✅ **Windows 11 22H2+** — Vollständig getestet
- ✅ **Windows 10 20H2** — Vollständig kompatibel
- ✅ **Windows 10 21H2** — Vollständig kompatibel

### GPU Kompatibilität
- ✅ **NVIDIA** — GeForce RTX Serie (alle modernen GPUs)
- ✅ **AMD** — Radeon RX Serie (alle modernen GPUs)
- ⚠️ **Intel Arc** — Begrenzte Unterstützung (nutzt AMD-Tweaks)

---

## 🛡️ Safety & Security

✅ **System Restore Point** — Wird vor allen Tweaks automatisch erstellt  
✅ **Detailliertes Logging** — Alle Aktionen werden in `%TEMP%\GameOptimizerPro_*.log` protokolliert  
✅ **Hardware Detection** — GPU-spezifische Tweaks werden automatisch gefiltert  
✅ **Vollständig reversibel** — Alle Tweaks können über System Restore rückgängig gemacht werden  
✅ **Keine Malware** — Open-Source, vollständig überprüfbar

---

## 🎨 GUI Features

- **Moderne Dark-Mode UI** — Basierend auf WPF/XAML
- **Info-Buttons (?)** — Hover über `?` für Erklärungen zu jedem Tweak
- **6 Tabs für Kategorien** — Windows | Audio | GPU Tweaks | Power Plan | Startup Manager | Language
- **Bulk Selektionen** — Select All / Deselect All Buttons
- **Live Logging** — Log-Datei kann jederzeit geöffnet werden
- **Hardware Info** — Zeigt GPU, CPU, RAM an
- **Language Toggle** — Deutsch/Englisch Umschaltung

---


## 🆘 Troubleshooting

### Problem: "Execution of scripts is disabled"
**Lösung:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Problem: Script startet nicht
**Lösung:**
- Stelle sicher, dass du **Administrator-Rechte** hast
- Versuche: `powershell -ExecutionPolicy Bypass -File GameOptimizerPro.ps1`

### Problem: GPU-Tweaks funktionieren nicht
**Lösung:**
- Stelle sicher, dass deine GPU-Treiber aktuell sind
- Neustarten nach GPU-Tweaks erforderlich!
- Überprüfe die Log-Datei: `%TEMP%\GameOptimizerPro_*.log`

### Problem: Tweaks wurden nicht angewendet
**Lösung:**
- Neustarten erforderlich für viele Tweaks
- Überprüfe, ob du die Tweaks wirklich aktiviert hast
- Schaue in die Log-Datei für Fehlerdetails

### Problem: System läuft langsamer nach Tweaks
**Lösung:**
- Nutze System Restore um alle Änderungen rückgängig zu machen
- Starte mit weniger Tweaks und teste dann mehr

---

## 📜 Changelog

### v1.0
- 🚀 **Initial release** mit umfangreicher Feature-Liste
- 🪟 **Windows Tab** — 12 Tweaks für OS-Optimierung, Debloat & Datenschutz
- 🔊 **Audio Tab** — 6 dedizierte Audio-Optimierungen
- 🎮 **GPU Tweaks Tab** — 7 Tweaks (4 NVIDIA + 3 AMD) mit automatischer GPU-Erkennung
- ⚡ **Power Plan Tab** — 7 Tweaks für Systemenergie-Optimierung
- 🚀 **Startup Manager** — Verwaltung von Auto-Start-Programmen
- 🌍 **Language Support** — 80+ Beschreibungen in EN, live umschaltbar
- 🌐 **Mehrsprachige UI** — Deutsch und Englisch voll unterstützt

---

## ⚠️ Disclaimer

**Use at your own risk.** Bitte überprüfe das Script vor der Ausführung.  
Ein System Restore Point wird automatisch vor Änderungen erstellt.  
Der Autor haftet nicht für Systemschäden durch unsachgemäße Verwendung.

---

## 💡 Tipps für maximale Performance

1. **Starte mit Safety** — Erst einige Tweaks testen, dann mehr hinzufügen
2. **Debloat aktivieren** — Entferne unnötige vorinstallierte Apps für schnelleres System
3. **GPU-Tweaks aktivieren** — Automatische Erkennung deiner GPU für beste Ergebnisse
4. **Power Plan optimieren** — Passe die Einstellungen nach deinen Bedürfnissen an
5. **Audio-Tweaks für Gaming** — Reduziere Audio-Latenz
6. **Startup Manager nutzen** — Beschleunige den Boot durch Startup-Optimierung
7. **NVIDIA/AMD Treiber aktuell halten** — Macht mehr aus als die meisten Tweaks
8. **Nach GPU Tweaks neustarten** — GPU-Optimierungen brauchen einen Reboot
9. **Logs überprüfen** — Bei Problemen die Log-Datei ansehen für Fehlerdetails
10. **System Restore nutzen** — Alle Tweaks können jederzeit rückgängig gemacht werden

---

## 🤝 Beitrag & Feedback

### Bugs melden
Falls du einen Bug findest, erstelle bitte einen [Issue](https://github.com/FloDePin/GameOptimizerPro/issues)

### Feature-Wünsche
Hast du eine Idee für ein neues Feature? [Teile es mit uns!](https://github.com/FloDePin/GameOptimizerPro/issues)

### Support
- 📧 E-Mail: sixtplage@googlemail.com
- 🐛 GitHub Issues: [Issues](https://github.com/FloDePin/GameOptimizerPro/issues)

---

## 📋 Geplante Features für zukünftige Versionen

- 🎮 **Gaming Boost Profile** — Vordefinierte Optimierungsprofile für beliebte Games
- 🌐 **Network Optimization** — Netzwerk-Latenz reduzieren
- 💾 **Disk Cleanup** — Automatische Speicherbereinigung
- 🔄 **Backup & Restore** — Registry-Backups vor Tweaks
- 🌙 **Auto-Scheduler** — Zeitgesteuerte Optimierungen

---

## 📄 Lizenz

Dieses Projekt ist unter der **MIT License** lizenziert. Siehe [LICENSE](LICENSE) für Details.

---

## 👨‍💻 Über den Autor

**FloDePin** — Windows & Gaming Enthusiast  
Leidenschaft für System-Optimierung und Performance-Tuning

---

*Made with ❤️ by FloDePin*
