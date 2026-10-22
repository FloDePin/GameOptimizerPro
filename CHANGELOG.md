# Changelog

All notable changes to GameOptimizerPro (the PowerShell edition), newest first. The round-by-round logs are folded — click to open.

---

## [1.3] — 2026-10-22

An honesty pass: tweaks that never did anything are gone, the safety net is lighter, and two dashboard tools work properly again.

- **8 tweaks removed** — the five NVIDIA registry tweaks (low latency / "Reflex", threaded optimization, pre-rendered frames, shader cache size, power management: the driver keeps these in its own profile database and never reads those values), *Disable Spatial Sound* (a value Windows doesn't use), *Disable Audio Device Power Save* (undocumented values; *Disable USB Selective Suspend* covers USB) and *Disable Windows Settings Backup* (an organisation-only policy whose 0 equals the default). Now **105 tweaks**; *Revert all* also removes what the old ones left behind.
- **Get Started & Copilot sign-in screens** — Enterprise / Education only, as Microsoft documents it; on Home / Pro the tweak changes nothing and its status stays grey.
- **Restore point only before app removals** — the registry backup still runs before every Apply and Revert. The 24-hour limit Windows puts on restore points is lifted for that one call only (older versions left it off for good).
- **Services manager** — *Enable* brings back the start type a service had before (*Automatic*, *Automatic (delayed)*), not always *Manual*.
- **Snapshot & compare** is kept after a restart, e.g. across a Windows update. Its result text shows again, and a BIOS Guide filter chip keeps its state.
- **README** — "every setting can be undone": app removals and the cleanups are one-way, and it now says so.

<details>
<summary><b>Development log — 1.3</b> (one or two lines per step)</summary>

- **External review** — nine points checked against the code and Microsoft's policy documentation; all confirmed, one with a different cause (the restore-point limit was not in the way — the old code lifted it and never put it back).
- **Tweaks out** — eight removed from every table, the presets (19 / 76 / 91) and the README; *Revert all* removes their values. Only `EnableWindowsBackup = 0` and a frequency of 0 are treated as ours — an organisation's own values stay.
- **Edition check** — `Test-EnterpriseEdition`; the two synthetic test machines now run Pro and Enterprise.
- **Restore point** — only when the selection removes apps; the frequency value goes back to what it was before.
- **Services and snapshot** — original start types and the snapshot are stored in `%LOCALAPPDATA%\GameOptimizerPro`.
- **Found by the app test** — the snapshot / compare buttons and a BIOS filter chip read `$Script:` values inside a closure, where they are empty; they now use the values the closure captured.
- **Tests** — unit tests, static checks, two synthetic PCs (Apply → Check → Revert for every tweak, all presets, 45 scenarios) and the real window offscreen; the real system stays unchanged.

</details>

---

## [1.2] — 2026-10-18

- **Grey dots counted separately** — one-time actions and tweaks that don't apply to this PC (*n/a*) in the counters, the score card and the legend.
- **Telemetry check** needs the DiagTrack service off **and** the policy, so a Windows update that turns the service back on shows up as drift.
- **Network checks** look at every connected physical adapter, not at a Hyper-V / WSL / VPN adapter that happens to come first; NVMe queue depth checks every NVMe drive; Click to Do checks the per-user value too.
- Audio power save touches only device entries; a locked log file can't interrupt a tweak; a direct start without administrator rights restarts itself elevated.

## [1.1] — 2026-10-17

- **New** — *Disable Energy-Efficient Ethernet* (Balanced) and *Disable Interrupt Moderation* (Aggressive): only settings the network driver itself offers, reverted to the driver's default.
- *Set 0.5 ms Timer Resolution* renamed to **Allow Global Timer Resolution (Windows 11)** — it allows system-wide timer requests, it doesn't set a resolution.
- Driver keys with a `*` in their name (`Ndi\params\*EEE`) are read literally.
- New README (English first, German linked), screenshots, MIT license, security policy.

## [1.0] — 2026-10-15

The first public release — Windows & gaming optimizer in a single PowerShell script.

- **111 tweaks in 8 categories**, each with its own revert to the Windows default; 101 with a live status check read straight from Windows.
- **Drift check** at every start: offers to re-apply what a Windows update switched back.
- **Safety net** — restore point and `.reg` backup of every affected key; SHA256-checked installer.
- **Presets** Minimal / Balanced / Aggressive; dashboard (score, refresh-rate check, live monitor, ping test, snapshot & compare), BIOS Guide for 16 platforms, Startup Manager, Services, Backups & Log; English and German.

<details>
<summary><b>Development log — from the first upload to 1.0</b> (one or two lines per round)</summary>

#### Internal versions · May – September 2026

- **First uploads** (2026-05-11) — *WinTweaker* becomes GameOptimizerPro: a WPF window with checkboxes and the one-line installer.
- **Internal 1.1 – 1.1.1** — performance tweaks, the BIOS Guide tab, a dashboard, network tweaks and a ping test; the English README becomes the main one.
- **Installer hardening** — LF line endings pinned via `.gitattributes`, the canonical repository URL.
- **Internal 1.2.0 – 1.2.1** — seven WinUtil essentials, an asynchronous ping test (latency, packet loss, jitter).
- **Internal 1.3.0 – 1.3.3** — Deep Clean, the live resource monitor, seven quality-of-life tweaks, code-review fixes, the monitor's background thread closed cleanly.
- **Internal 1.4.0 – 1.4.3** — presets, the version from one variable, AM4 / AM5 BIOS settings, fixes for non-English Windows (icacls SID, Ultimate Performance), the text & image generation AI tweak, status accuracy from two code reviews.
- **1.0** (2026-09-04) — version reset for the public release; TCP auto-tuning check, TDR revert, the last German dialogs translated.

#### Hardening before the tag · September – October 2026

- **Verify ticks** what is already active; review fixes (DNS over IPv6, ULPS on multi-GPU systems, the ping thread).
- **Dashboard** — optimization score, monitor advisor, drift detection against a baseline.
- **Power tweaks on every power scheme**, so they survive a plan switch.
- **Bug hunts 1 and 2** — Ultimate Performance plans piling up, the Balanced revert on non-English Windows, four always-green power checks, a compare crash, NVMe detection, gaps in the backup; an accurate "MB freed".
- **Windows 11 26H2** — Click to Do, the Settings agent, AI in Paint and Notepad.
- **New interface** in the v2.1 style, the BIOS Guide for every common platform, a start twice as fast with a loading screen, the drift prompt no longer asks twice.
- **Two audits** — live status for the Store / Spatial tweaks, three Windows 11 tweaks, honest edition notes; the GPU pick with an enabled iGPU, reverts to real Windows defaults, a safe hosts-file edit.

</details>
