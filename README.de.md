# ⚡ GameOptimizerPro v1.0

> **Windows & Gaming Optimizer** — by FloDePin

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)
![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D6?logo=windows)
![License](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/Version-1.0-red)

🇬🇧 [English](README.md) | 🇩🇪 **Deutsch**

---

## 🚀 Quick Start (One-Liner)

Öffne **PowerShell als Administrator** und führe aus:

```powershell
irm https://raw.githubusercontent.com/FloDePin/GameOptimizerPro/main/install.ps1 | iex
```

---



## 📸 Visual Preview

### GUI Übersicht
Die Oberfläche folgt dem Design von GameOptimizerPro v2.1:
- 🎨 **Dark-Mode UI** — WPF/XAML mit Seitenleiste: Dashboard · Tweaks · Presets · BIOS Guide · Startup Manager · Services · Backups & Log
- 📊 **Dashboard** — Hardware-Karten, Optimierungs-Score, Live-Monitor, Ping-Test, Snapshot & Vergleich
- 🗂️ **Tweak-Liste** — 8 Kategorie-Tabs, Suche über alle Tweaks, Status-Punkt + Badges pro Tweak, Beschreibung direkt unter jedem Tweak (DE/EN)
- 🎚️ **Presets-Seite** — Vorschau jedes Presets (grün = schon aktiv), Status pro Kategorie
- 🔧 **BIOS Guide** — 16 Plattformen (AM5 / AM4 / Intel) mit dem Menüpfad für ASUS, MSI, Gigabyte und ASRock; deine Plattform wird erkannt und vorausgewählt

---

## ✨ Features

| Tab | Features | Description |
|-----|----------|-------------|
| 🎚️ Presets | 3 Stufen | Ein-Klick **Minimal / Balanced / Aggressive** Tweak-Auswahl (kumulativ, sicher als Standard) |
| 🪟 Windows | 43 Tweaks | Debloat, Datenschutz, Performance-Tweaks + CTT Essentials + Quality of Life |
| 🎮 Gaming | 12 Tweaks | Game Mode, Game Bar, MMCSS, CPU-Priorität, Vollbild-Optimierungen, MSI-Modus, HAGS |
| 🌐 Network | 11 Tweaks | Nagle, LSO, DNS, TCP-Tuning, QoS, Adapter Power Saving, Delivery Optimization |
| 💾 RAM & Storage | 15 Tweaks | Auslagerungsdatei, Speicherkomprimierung, Ruhezustand, SSD/NVMe-Tweaks, Temp-Bereinigung + Deep Clean (6 Tools, zeigt freigegebene MB) |
| 🪟 Windows 11 | 7 Tweaks | Klassisches Rechtsklick-Menü, Taskleiste links, Widgets, Chat-Icon, Start-Empfehlungen, Task beenden, Snap-Hover-Menü |
| 🔊 Audio | 6 Tweaks | Audio-Verbesserungen, MMCSS-Audio-Profil, Dienst-Priorität, Sound-Schema, Spatial Sound, Geräte-Energie |
| 🎮 GPU Tweaks | 7 Tweaks | 4 NVIDIA + 3 AMD Tweaks, GPU-Erkennung, Brand-Grauausblendung |
| ⚡ Power Plan | 7 Tweaks | USB, PCI-E, HDD, Display, Sleep, CPU Min/Max |
| 📊 **Dashboard** | ✅ | Hardware-Karten, Optimierungs-Score + Monitor-Check (Auflösung/Hz), Live-Monitor (CPU/RAM/Disk/Netz), Ping-Test (Latenz, Paketverlust, Jitter), Snapshot & Vergleich, Status des Sicherheitsnetzes |
| 🔧 **BIOS Guide** | 16 Plattformen | AM5 / AM4 / Intel LGA1851 / 1700 / 1200 / 1151 + generisch, Menüpfade für ASUS / MSI / Gigabyte / ASRock, Live-Check von EXPO/XMP, Resizable BAR, CSM und Secure Boot |
| 🚀 Startup Manager | ✅ | Eigenes Fenster, HKCU/HKLM/Run32 + Autostart-Ordner, Disable/Enable/Refresh |
| 🗄️ Backups & Log | ✅ | Registry-Backups, Log, Systemwiederherstellung, Revert all und Drift-Check an einem Ort |
| 🌍 Language DE/EN | ✅ | 108 Tweak-Beschreibungen + der komplette BIOS Guide auf Deutsch und Englisch, live umschaltbar |

---

## 🪟 Windows Tab - 43 Tweaks

### 🧹 Debloat & System Cleanup
- **Remove Cortana** — Entfernt den Windows Sprachassistenten
- **Remove Xbox Apps** — Deaktiviert Xbox und Gaming-bezogene Apps
- **Remove Microsoft Teams (Personal)** — Entfernt die persönliche Teams-Installation
- **Remove Copilot** — Deaktiviert Windows Copilot
- **Remove OneDrive** — Entfernt die OneDrive-Integration
- **Remove Windows Recall** — Deaktiviert und entfernt Windows Recall (offizielle Richtlinie; vorhandene Snapshots werden gelöscht)
- **Remove Other Bloatware** — Entfernt zusätzliche vorinstallierte Bloatware

### 🔐 Privacy-Einstellungen
- **Disable Telemetry & Data Collection** — Deaktiviert Datenerfassung
- **Disable Activity History** — Deaktiviert die Aktivitätsverlauf-Speicherung
- **Disable Click to Do & Settings Agent (AI)** — Schaltet die KI-Bildschirmanalyse und den KI-Agenten in der Einstellungen-Suche ab (Copilot+ PCs)
- **Disable AI in Paint & Notepad** — Offizielle Richtlinien für Cocreator, Image Creator, generatives Füllen und Notepad-KI

### 📦 Windows 11 & 10 Optimization
- **OS-Scan** — Scannt das Betriebssystem auf Optimierungspotenziale
- **Win11 Tweaks** — Spezialisierte Optimierungen für Windows 11
- **Win10 Grauausblendung + Banner** — Optimierte Darstellung für Windows 10-Kompatibilität

### ⚡ Performance-Tweaks
- **Disable Power Throttling** — Verhindert, dass Windows Gaming-Prozesse per EcoQoS drosselt
- **Disable Bing in Windows Search** — Startmenü sucht nur noch lokal, kein Datenaustausch mit Microsoft
- **Process Count Reduction (Svchost)** — Weniger Hintergrundprozesse durch erhöhten Split-Threshold

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
- **Registry-Integration** — HKCU/HKLM/Run32-Einträge + beide Autostart-Ordner
- **3-State-Management** — Disable/Enable/Refresh Funktionalität
- **Schnelle Kontrolle** — Starten/Stoppen von Auto-Start-Programmen

---

## 🔧 BIOS Guide

### 🎯 Alle gängigen Plattformen, nicht nur ein Setup
Der BIOS Guide deckt **16 Plattformen** ab. Deine CPU und dein Board-Hersteller werden erkannt und vorausgewählt; jede andere Plattform lässt sich als Referenz öffnen:

| Plattform | Profile |
|-----------|---------|
| **AMD AM5** | Ryzen 9000X3D · Ryzen 9000 · Ryzen 7000X3D · Ryzen 7000 · Ryzen 8000G / 8000F |
| **AMD AM4** | Ryzen 5000X3D · Ryzen 5000 · Ryzen 5000G–2000G (APU) · Ryzen 3000 · Ryzen 1000 / 2000 |
| **Intel** | Core Ultra 200S (LGA1851) · Core 13./14. Gen · Core 12. Gen (LGA1700) · Core 10./11. Gen (LGA1200) · Core 8./9. Gen (LGA1151) |
| **Sonstige** | Generisches Profil für Laptops, Threadripper und unbekannte CPUs |

### 📋 Was jede Einstellungs-Karte zeigt
- **Standard vs. empfohlener Wert** — z. B. „Default: Off → Recommended: Profile 1 (DDR5-6000 CL30)“
- **Menüpfad für deinen Board-Hersteller** — ASUS, MSI, Gigabyte, ASRock (umschaltbar; generischer Pfad für andere Boards)
- **Wirkung + Risiko-Badge** — hohe / mittlere / geringe Wirkung, sicher / moderat
- **Erklärung auf Deutsch oder Englisch** — was die Einstellung macht und was zu tun ist, wenn der PC danach nicht startet
- **Plattform-spezifische Einstellungen** — EXPO/XMP/DOCP, Resizable BAR, CSM, Secure Boot, BIOS-Update (inkl. Vmin-Shift-Fix für 13./14. Gen), PBO, Curve Optimizer, FCLK, Memory Context Restore, C-States, Kern-Zuteilung bei X3D mit zwei CCDs, iGPU, Intel-Default-Settings-Power-Limits, MCE, E-Cores, 200S Boost, Auto-Installer des Board-Herstellers, PCIe-Slot-Geschwindigkeit
- **Filter** — Memory / CPU / GPU / Power / Boot & Security, dazu „nur was noch zu tun ist“

### 🔍 Live-Check aus Windows
Vier Einstellungen werden direkt aus Windows gelesen (ohne Admin-Rechte): **EXPO/XMP** (RAM-Takt vs. JEDEC-Basistakt), **Resizable BAR** (NVIDIA), **CSM / UEFI** und **Secure Boot**. Grüner Punkt = schon gesetzt, rot = noch zu tun.

### 📖 Read-Only Ratgeber
- Keine automatischen Änderungen — der BIOS Guide schreibt nie etwas
- Die BIOS-Änderungen machst du selbst, mit dem Menüpfad direkt auf der Karte

---

## 🌍 Language Toggle - DE/EN

### 🗣️ Zweisprachige Tweak-Beschreibungen (DE/EN)
- **108 Tweak-Beschreibungen auf Deutsch & Englisch** — direkt unter jedem Tweak (voller Text als Tooltip)
- **BIOS Guide auf Deutsch & Englisch** — alle Erklärungen und Hinweise
- **Toggle-Button** — „Info: DE / EN“ in der Seitenleiste schaltet alles live um, kein Neustart
- **Interface-Beschriftungen bleiben Englisch** — der Umschalter betrifft die Beschreibungen, nicht die UI-Elemente

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
- ⚠️ **Intel Arc** — Alle allgemeinen Tweaks funktionieren; die NVIDIA/AMD-spezifischen GPU-Tweaks sind ausgegraut

### CPU Kompatibilität (BIOS Guide)
- ✅ **AMD AM5** — Ryzen 7000 / 7000X3D / 8000G / 9000 / 9000X3D
- ✅ **AMD AM4** — Ryzen 1000 / 2000 / 3000 / 5000 / 5000X3D und die G-APUs
- ✅ **Intel** — Core 8.–14. Gen und Core Ultra 200S (Desktop)
- ⚠️ **Laptops, Threadripper, andere CPUs** — BIOS Guide zeigt das generische Profil

---

## 🛡️ Safety & Security

✅ **System Restore Point** — Wird vor allen Tweaks automatisch erstellt  
✅ **Registry-Backup** — Vor jedem Apply/Revert werden alle betroffenen Registry-Keys zusätzlich als `.reg`-Dateien nach `%LOCALAPPDATA%\GameOptimizerPro\RegistryBackups\` exportiert (unabhängig vom System Restore Point, der Windows' 24h-Limit unterliegt)  
✅ **Detailliertes Logging** — Alle Aktionen werden in `%TEMP%\GameOptimizerPro_*.log` protokolliert  
✅ **Hardware Detection** — GPU-spezifische Tweaks werden automatisch gefiltert  
✅ **BIOS Guide Read-Only** — Keine automatischen Systemänderungen durch den BIOS Guide  
✅ **Vollständig reversibel** — Alle Tweaks können über System Restore oder das Registry-Backup rückgängig gemacht werden  
✅ **Checksum-Verifizierung** — `install.ps1` prüft den Download gegen den in [CHECKSUMS.txt](CHECKSUMS.txt) veröffentlichten SHA256-Hash, bevor das Skript mit Admin-Rechten läuft  
✅ **Keine Malware** — Open-Source, vollständig überprüfbar

---

## 🎨 GUI Features

- **Moderne Dark-Mode UI** — Basierend auf WPF/XAML, Design-Tokens aus GameOptimizerPro v2.1
- **Seitenleiste** — Dashboard | Tweaks | Presets | BIOS Guide | Startup Manager | Services | Backups & Log
- **8 Kategorie-Tabs + Suche** — die Suche findet Tweaks über alle Kategorien hinweg
- **Status auf einen Blick** — grüner Punkt = aktiv, Ring = inaktiv, grau = einmalige Aktion; Badges für „removes app“, „restart“, „NVIDIA only“, „Windows 11 only“
- **Beschreibung direkt sichtbar** — jeder Tweak erklärt sich unter seinem Namen; ein Klick auf den Text setzt den Haken
- **Bulk-Auswahl** — All / None Buttons, Presets mit Vorschau
- **Live Logging** — Log-Datei und Registry-Backups mit einem Klick in der Statusleiste
- **Hardware Info** — GPU, CPU, RAM, Board, OS und Monitor auf dem Dashboard

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

### Problem: BIOS Guide zeigt die falsche Plattform
**Lösung:**
- Wähle links deine Plattform und oben deinen Board-Hersteller — jedes Profil ist manuell wählbar
- Laptops, Threadripper und unbekannte CPUs bekommen bewusst das generische Profil
- „Check system state“ liest EXPO/XMP, Resizable BAR, CSM und Secure Boot neu ein

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

### v1.0 — Erste öffentliche Veröffentlichung
Ein vollständiger, gehärteter Windows- & Gaming-Optimierer. Jeder Tweak hat volles **Apply + Revert + Live-Status-Check**, und jedes Apply legt zuerst einen **Systemwiederherstellungspunkt** und ein **`.reg`-Registry-Backup** an (gespeichert unter `%LOCALAPPDATA%\GameOptimizerPro\RegistryBackups`, sicher vor der Temp-Bereinigung).

**Tweak-Bibliothek (108 Tweaks, alle reversibel):**
- 🪟 **Windows** — Debloat, Privatsphäre, Performance, CTT-Essentials & Quality-of-Life-Tweaks, inkl. Abschalten der geräteweiten generativen KI (Text- & Bildgenerierung), Click to Do, des KI-Agenten in den Einstellungen und der KI in Paint & Notepad
- 🎮 **Gaming & GPU** — MSI-Modus, HAGS, NVIDIA/AMD-Treiber-Tweaks, GPU-Timeout-Toleranz (TDR), Shader-Cache-Tools
- 🌐 **Netzwerk** — Latenz (Nagle/LSO/Throttling), DNS (Cloudflare/Google), TCP-Tuning, QoS, Adapter-Energie
- 🔊 **Audio** — MMCSS/Audio-Priorität, Spatial Sound, Sound-Schema & Geräte-Energie
- 💾 **RAM & Speicher** — Auslagerungsdatei, Write-Cache, plus **Deep Clean** (6 Cleanup-Tools, jedes zeigt die freigegebenen MB)
- ⚡ **Energieplan** — Ultimate Performance, HPET, 0,5-ms-Timer-Auflösung

**Tools & UX:**
- 🎨 **Neue Oberfläche im Stil von GameOptimizerPro v2.1** — Seitenleiste, Dashboard mit Optimierungs-Score, Tweak-Liste mit Suche, Status-Punkten, Badges und DE/EN-Beschreibung direkt am Tweak
- 🎚️ **Presets** — Minimal / Balanced / Aggressive (kumulativ; destruktive Aktionen werden nie automatisch ausgewählt), mit Vorschau jedes Presets
- 📊 **Dashboard** mit **Live-Ressourcen-Monitor** (CPU/RAM/Disk/Netzwerk auf Background-Runspace, kein UI-Ruckeln)
- 📶 **Ping-Test** über 3 Ziele — durchschnittliche Latenz, Paketverlust % und Jitter
- 🧰 **BIOS-Guide** — 16 Plattformen (AM5 / AM4 / Intel), Menüpfade für ASUS / MSI / Gigabyte / ASRock, Live-Check von EXPO/XMP, Resizable BAR, CSM und Secure Boot; read-only
- 🚀 **Autostart-Manager** — deckt Run-Keys und Autostart-Ordner ab

**Sicherheit & Robustheit:**
- 🛡️ Startup-**Sanity-Check** verhindert, dass ein Status-Check je mit einer Revert-Aktion verwechselt wird
- 🌍 Durchgängig **locale-unabhängig** (SIDs, feste GUIDs, CIM-Perf-Counter) — funktioniert auf nicht-englischem Windows
- 🔒 **SHA256-Integritätskette** — `install.ps1` pinnt den veröffentlichten Hash und prüft ihn gegen `CHECKSUMS.txt`, bevor irgendetwas mit Admin-Rechten läuft
- ✅ Verifiziert: **108/108** Tweaks haben Apply + Revert + Status-Check, keine Kollisionen


---

## ⚠️ Disclaimer

**Use at your own risk.** Bitte überprüfe das Script vor der Ausführung.  
Ein System Restore Point wird automatisch vor Änderungen erstellt.  
Der Autor haftet nicht für Systemschäden durch unsachgemäße Verwendung.

---

## 💡 Tipps für maximale Performance

1. **Starte mit Safety** — Erst einige Tweaks testen, dann mehr hinzufügen
2. **Debloat aktivieren** — Entferne unnötige vorinstallierte Apps für schnelleres System
3. **Performance-Tweaks nutzen** — Besonders Power Throttling & Bing-Deaktivierung
4. **GPU-Tweaks aktivieren** — Automatische Erkennung deiner GPU für beste Ergebnisse
5. **BIOS Guide vor Hardware-Tuning** — Lese die Empfehlungen vor BIOS-Änderungen
6. **Power Plan optimieren** — Passe die Einstellungen nach deinen Bedürfnissen an
7. **Audio-Tweaks für Gaming** — Reduziere Audio-Latenz
8. **Startup Manager nutzen** — Beschleunige den Boot durch Startup-Optimierung
9. **NVIDIA/AMD Treiber aktuell halten** — Macht mehr aus als die meisten Tweaks
10. **Nach GPU Tweaks neustarten** — GPU-Optimierungen brauchen einen Reboot
11. **Logs überprüfen** — Bei Problemen die Log-Datei ansehen für Fehlerdetails
12. **System Restore nutzen** — Alle Tweaks können jederzeit rückgängig gemacht werden

---

## 🤝 Beitrag & Feedback

### Bugs melden
Falls du einen Bug findest, erstelle bitte einen [Issue](https://github.com/FloDePin/GameOptimizerPro/issues)

### Feature-Wünsche
Hast du eine Idee für ein neues Feature? [Teile es mit uns!](https://github.com/FloDePin/GameOptimizerPro/issues)

### Support
- 📧 E-Mail: flodepin@googlemail.com
- 🐛 GitHub Issues: [Issues](https://github.com/FloDePin/GameOptimizerPro/issues)

---

## 📋 Geplante Features für zukünftige Versionen

- 🎮 **Gaming Boost Profile** — Vordefinierte Optimierungsprofile für beliebte Games
- 💾 **Disk Cleanup** — Automatische Speicherbereinigung
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
