# Changelog

All notable changes to GameOptimizerPro (the PowerShell edition), newest first. The round-by-round logs are folded — click to open.

**Version numbers** — the third number counts fixes and tweaks for new Windows builds (1.2.1, 1.2.2, …), the second one a bigger update. The bigger next step is GameOptimizerPro v2, a separate project. 1.2.1 – 1.2.3 were first published as 1.3 – 1.5 and renumbered on 2026-10-30; nothing else changed.

---

## [1.2.6] — 2026-11-14

A full audit of 1.2.5 — every tweak, revert, status check and button read again, and the new parts checked against the PC itself (read only). Everything it found is fixed; tweaks without a documented effect are gone (114 → 108).

- **Revert all only sets back what the app applied** — until now it set every tweak to the Windows default, applied or not: light mode, location on, hibernation on, folder views deleted, the timeouts of every power plan rewritten. It now works from the list of what GameOptimizerPro applied; settings you made yourself stay.
- **Reverts write the real Windows defaults** — the power reverts put back each plan's own default (until now PCIe link state went to *maximum power savings*, disk sleep to 30 min, the CPU minimum to 5 % even on *High performance*); the TCP revert switched ECN and timestamps **on**; the Svchost revert wrote 380000 instead of 0x380000 (≈ 370 MB instead of 3.5 GB) and its status was green on every untouched Windows; the HAGS revert switched HAGS **off** — it now puts back what was set before.
- **Restore point that can't be made is no longer hidden** — the dashboard showed "on" no matter what. With System Protection off, the app now asks before removing apps: turn it on and make the point, go on without, or stop. A failed restore point stops too, unless you say otherwise.
- **Apply leaves active tweaks alone** — running them again deleted every folder view and restarted Explorer each time, and after *Verify* (which ticks everything active) it asked for a restore point for apps that were long gone.
- **SystemResponsiveness 10 instead of 0** — Microsoft: values below 10 are treated as 20, the Windows default. *Set Audio Service High Priority* and *Disable Network Throttling Index* wrote 0, so that part did nothing.
- **DNS status checks IPv6 too** — an adapter whose IPv6 DNS still came from the router showed Cloudflare / Google as active. The DNS tweaks now only change the physical adapters (VPN, Hyper-V and WSL keep theirs), and an own list like "1.1.1.1 + Pi-hole" is remembered for the revert.
- **Removed: 6 tweaks without a documented effect** — *Optimize TCP Settings* (sets Windows defaults), *Disable QoS Packet Scheduler Limit* (the 20 % only apply to programs that reserve bandwidth), *Optimize NVMe Queue Depth*, *Enable Start Menu Previous Layout* (no longer works on current builds), *AMD: Shader Cache* and *AMD: Anti-Lag*. *Revert all* removes what they wrote.
- **Honest names and presets** — *Disable Windows Update during Gaming* is now *Disable Automatic Windows Updates* (it always switched them off for good) and in no preset; *Disable Background App Throttling* is now *Stop Background Apps (All Editions)* (the undocumented kernel value is gone); *Disable TCP Auto-Tuning* (caps downloads at the 64 KB window) and *Disable Scheduled Defragmentation* (on SSDs it only stops the weekly retrim) left the presets.
- **Remove Other Bloatware only removes what Windows put there** — Spotify, Netflix, Instagram & co., the Media Player and *Get Help* are no longer on the list; the confirmation shows what goes on your PC. *Remove Xbox Apps* now really removes Xbox TCUI (the old pattern never matched it); removals cover every account.
- **Smaller fixes** — the Startup Manager shows Store app autostarts, the boot delay Windows logged (it read a wrong event and never showed anything) and counts only real successes; Services marks the Insider service and the touch keyboard service as risky and mentions Game Pass for the Xbox services; long descriptions open with *Show more*; the restart question only comes when a tweak needs it; the score is measured against the Balanced preset; *Disable Hibernation* says that Fast Startup goes off too; three more telemetry tasks (WinUtil parity); real umlauts in the German texts.
- **Backups are ~3 MB instead of ~38 MB** — only the parts of `HKLM\...\Control` the tweaks touch, two single values in `_values.reg`. Only this app's backups are pruned (GameOptimizerPro v2 writes to the same folder).
- **Update notice and installer** — the dashboard says when a newer release is out (one look at GitHub at start, nothing sent). The installer starts exactly the bytes it checked, from a folder only administrators can write to.

<details>
<summary><b>Development log — 1.2.6</b></summary>

- **Checked on the real PC (read only)** — power defaults per plan from `DefaultPowerSchemeValues` (Balanced PCIe 1/2, High performance 0/0, disk 1200 s); the Ultimate plan keeps the template's name resource `powrprof.dll,-19` in every language; System Protection off (`SPP\Clients` empty); a backup into a test folder: 2.6 MB, 65 files, retention 20 with foreign folders untouched; the boot-performance event template (event 101: Name, Path, TotalTime, DegradationTime — the log itself needs admin).
- **Sources** — SystemResponsiveness clamping: Microsoft's MMCSS documentation. QoS: Microsoft's QoS Packet Scheduler documentation ("if no QoS-aware application reserves any bandwidth, this setting has no effect"). Start menu override: WinUtil's own note that it no longer works on newer builds. Svchost default 0x380000. Telemetry tasks: WinUtil's *Disable Telemetry*.
- **Installer** — the elevated PowerShell reads the file once, hashes those bytes and writes them into a new folder under `Windows\Temp` with only SYSTEM and Administrators on its ACL; tested with a matching and a swapped file.
- **Old baselines** — files from 1.2.5 list every tweak that was active; renamed tweaks map to their new names, removed ones drop out, and the first drift notice after the update says that a newer version may check more settings.
- **Tests** — the test PCs now have the real Windows defaults (Svchost, power plans per plan), IPv6 DNS, a machine-wide OneDrive and the Xbox / bloatware packages that must stay; new scenarios for every fix; *Revert all* in the preset test works like the app (applied list only); static checks 0 findings; the real window offscreen incl. *Show more*; the real system unchanged.

</details>

---

## [1.2.5] — 2026-11-12

Two more audits, checked against the code — what holds is fixed, plus a few things that make the tool nicer to live with.

- **The installer never runs a file with the wrong checksum** — before, typing "YES" started it anyway. Right after a release GitHub keeps serving the previous script from `main` for up to 5 minutes, so the installer now downloads the copy of its own release tag (which never changes) and uses `main` only as a fallback; a mismatch stops with a clear message.
- **DNS revert brings back what you had** — *Set DNS to Cloudflare / Google* remember the adapter's own DNS servers (a Pi-hole, a company DNS) and the revert writes exactly those back, or switches to automatic if that was the setting. An adapter where you added a server of your own next to Cloudflare / Google is left alone.
- **Registry backups can remove what was new** — each backup now also has `_remove-new-keys.reg` for keys that didn't exist yet; the Backups page says honestly what a double-click restores. Only the newest 20 backups are kept (each one is around 40 MB), and only the newest 20 logs.
- **Revert selected** — sets only the ticked tweaks back to the Windows default, not everything.
- **Your own selection** — save the ticked tweaks to a text file on the Presets page and tick them again later or on another PC.
- **Disk Cleanup doesn't freeze the window** — cleanmgr and DISM (often 5–15 minutes) run in the background, the status bar counts the seconds.
- **Dashboard** — also shows virtualization-based security (VBS), which can keep running with memory integrity off.
- **Smaller fixes** — *Revert all* no longer restarts Explorer for a classic right-click menu that was never set; Startup Manager and Services update their rows right after Enable / Disable; both windows open over the app instead of behind it; the drift check at start no longer runs every check twice; the status of *Disable Input & Speech Data Collection* also covers the feedback policy on Pro.

<details>
<summary><b>Development log — 1.2.5</b></summary>

- **Audit 1 (1.2.4)** — all three points confirmed: installer override, DNS revert on mixed lists, backups without the missing keys.
- **Audit 2** — written for the old 1.3; its bugs were fixed in 1.2.2 except the Explorer restart. Of its nine extra points one was outdated (the test harness already allows `Out-String`) and one didn't apply (the tests folder isn't published, no user name is in the repo); the rest is in.
- **Suggestions not built** — AMD ReBAR detection through `KMD_RebarControlMode`: that value is a driver preset that is 1 after every install, whatever the BIOS says. Measuring the BAR size through WMI doesn't work either: on the RTX 4080 it reports 16 / 32 MB windows while `nvidia-smi` shows the 16 GB BAR.
- **Tested on the real PC (read only)** — the new backup with its missing-keys file and the cleanup to 20 folders, run against the live registry into a test folder.
- **Found while releasing** — a query string does not get past GitHub's cache of `main` (same ETag, cache hit), so a "download again past the cache" retry would not help; the tag URL is fresh at once. Tested: with the tag the new script verifies; without one the fallback gets the cached old script and the installer stops.
- **Tests** — new scenarios for the DNS restore (Pi-hole, switching providers, a mixed list, automatic), the Explorer restart and Disk Cleanup; static checks now 0 findings; the real window offscreen with the new buttons; the real system unchanged.

</details>

---

## [1.2.4] — 2026-11-12

Three fixes and twelve new tweaks from a comparison with Winhance — each one checked against the code, the fresh Windows 11 26H2 PC and Microsoft's documentation (including which editions read a policy).

- **Disable Audio Enhancements works again** — Windows 11 refuses direct writes to the audio endpoint store (tested on 26H2 with a test value), so the old tweak changed nothing. It now goes through the Windows audio interface like the Sound control panel, reads every value back, counts only real successes and reports a refusal as an error. Only devices that are there (active or unplugged) count, not the ones Windows only remembers.
- **Remove Xbox Apps** — the description warns that the Xbox sign-in for Game Pass and Store games, Xbox mode and Game Bar recordings are gone until the apps come back from the Store; it moved from *Balanced* to *Aggressive*.
- **Optimize Visual Effects** — also switches off the single effects (shadows, window contents while dragging, the translucent selection rectangle, icon shadows) like *Adjust for best performance*; ClearType stays on. Full effect after signing out and in.
- **12 new tweaks** — *Disable Tips, Ads & Suggestions*, *Stop OneDrive Folder Backup*, *Disable Input & Speech Data Collection*, *Disable Remote Assistance*, *Disable Startup App Delay*, *Block Background Apps (Policy)*, *Exclude Drivers from Windows Update*, *Hold Feature Updates (Stay on Current Version)*, *Alt+Tab Without Browser Tabs*, *Disable Dynamic Lighting*, *Disable USB 3 Link Power Management* and *Disable Wake Timers*. Now **114 tweaks**.
- **More in existing tweaks** — telemetry tasks: feedback prompts, the error-report upload queue and the power-efficiency analysis; Bing search: search highlights and cloud content search; Recommended in Start: recent files and recommendations off on every edition; Xbox Game Bar: the controller's Xbox button.
- **Greyed out by edition** — policies Windows Home doesn't read are marked *Pro and up*; *Disable Consumer Features* is *Enterprise only* now, as Microsoft documents it.
- **Dashboard** — shows memory integrity and the encryption of drive C: (both cost performance), read only.

<details>
<summary><b>Development log — 1.2.4</b></summary>

- **Checked on the real PC (read only)** — every target: scheduled tasks (*PI\Sqm-Tasks* is gone on 26H2 and is skipped), power settings (USB 3 link power management is hidden in Power Options and only shows with `powercfg /qh`), registry values and permissions, the audio devices through the audio API (three devices; one active device still had its enhancements on).
- **Microsoft docs, edition column** — *ExcludeWUDriversInQualityUpdate*, *TargetReleaseVersion* / *ProductVersion*, *LetAppsRunInBackground* and *DoNotShowFeedbackNotifications* are read from Pro up; *AllowWindowsConsumerFeatures* only on Enterprise / Education; *HideRecommendedSection* lists Pro.
- **Not built, with reasons** — *NoAutoRebootWithLoggedOnUsers* (a legacy policy Microsoft lists as not applicable to Windows 11, and the Windows Update tweak already switches automatic installs off); Wi-Fi power saving on AC (Windows already ships *Maximum performance* there); voice activation for apps (the setting doesn't exist on 26H2); *ContentDeliveryAllowed* / *SubscribedContentEnabled* (not documented whether they also turn off the Spotlight pictures); the software installer and the app-removal list are left for a round of their own.
- **Status checks count deviations** — a value that is missing or changed back is never "done" (the 0-is-falsy trap).
- **Tests** — the test PCs now model the audio API (incl. a device that refuses), hidden power settings, binary registry values and Windows Home; new scenarios for every fix and new tweak; static checks, unit tests and the real window offscreen; the real system unchanged.

</details>

---

## [1.2.3] — 2026-10-29

Checked on a fresh Windows 11 26H2 (build 26300): tweaks that no longer do anything are gone, and four status checks read the right thing again.

- **3 tweaks removed** — *Remove Cortana* (Windows 11 24H2 and later ship without Cortana), *Remove Microsoft Teams (Personal)* (no longer preinstalled, and Windows locks the auto-install value so even an administrator can't write it) and *Remove Chat Icon from Taskbar* (the Chat button became a normal Teams app with 23H2). Now **102 tweaks**; *Revert all* also removes what the old ones left behind.
- **Disable Scheduled Telemetry Tasks** — 24H2 and later run the appraiser as *Microsoft Compatibility Appraiser Exp* and dropped *ProgramDataUpdater*; the tweak now switches the new task off too, and the status checks every task this Windows has instead of one that no longer exists.
- **Disable Widgets** — Windows blocks writing the taskbar value, so the status now reads the policy that turns Widgets off. Before, it stayed red although Widgets were off.
- **Disable Audio Enhancements** — playback devices Windows only remembers (an old monitor, a removed headset) are skipped; they kept the status red.
- **Optimize TCP Settings** — a `netsh` option Windows 10 and 11 no longer know (*chimney*) is gone.

<details>
<summary><b>Development log — 1.2.3</b></summary>

- **Real-system check** — every status check run read-only on the fresh 26H2 PC, plus the targets themselves: services, scheduled tasks, apps, network adapter settings, playback devices and registry permissions.
- **Found** — the telemetry check asked for a task that doesn't exist on 24H2+; the Communications key belongs to TrustedInstaller (administrators may only read it); TaskbarDa is refused (User Choice Protection Driver), the Widgets policy is written; twelve remembered audio devices without the value (all "not present"); `netsh … chimney` answers "not a valid argument".
- **Not changed** — *Disable Energy-Efficient Ethernet* is correct: the Realtek driver turns EEE off by default, Green Ethernet is still on until the tweak runs.
- **Tests** — the NVIDIA test PC now models 26H2 (new task layout, refused registry writes); new scenarios for the telemetry tasks, Widgets, audio devices and the retired values; unit tests, static checks, the real window offscreen; the real system unchanged.

</details>

---

## [1.2.2] — 2026-10-22

Two more external reviews, checked against the code — what holds is fixed.

- **"All" ticks only what you see and can use** — the open tab (or the search hits), never greyed-out tweaks (Windows 11 only, AMD only, Enterprise only). *Apply* never runs a greyed-out tweak, and the two DNS tweaks are never ticked together.
- **Apply says what didn't take** — failed tweaks and tweaks Windows still reports as not in effect (a policy, antivirus or a driver without that option) are listed in the result and the log, instead of "applied successfully". The HPET tweak notices when bcdedit is refused (Secure Boot / BitLocker policy).
- **Revert all leaves your own DNS alone** — only adapters that use Cloudflare / Google go back to automatic; a Pi-hole, router or company DNS stays. Windows 11 reverts no longer run on Windows 10, and *Disable Bing* reverts to "not set" instead of writing 1.
- **Remove Other Bloatware** — the status checks the whole list it removes (Windows 11 ships no Candy Crush, so an untouched PC used to show green).
- **Disable Location Tracking** also stops the running service, and the status check covers it.
- **Get Started & Copilot sign-in screens** — greyed out on Home / Pro (*Enterprise only*), so presets skip it there.
- **Remove Windows Recall** counts as a removal: a restore point first, the *removes app* badge. The confirm dialog names every removal.
- The log retries a locked file before dropping a line; registry backup files can't overwrite each other.

<details>
<summary><b>Development log — 1.2.2</b></summary>

- **Two reviews** — the first with nine general points, the second fact-checked it and added eight findings. Confirmed and fixed: exit codes of external tools not checked, "All" ticking greyed-out tweaks, the DNS revert, Windows 11 reverts on Windows 10, the Bing revert, the bloatware check, the location service, Get Started selectable on Home / Pro, Recall without a restore point, leftover NVIDIA code.
- **Not changed, with reasons** — powercfg output is read by its hex values, not its labels (labels are translated, label parsing would break on every non-English Windows), and `/SETACTIVE SCHEME_CURRENT` is what makes a change take effect without a restart; `Get-WmiObject` works in Windows PowerShell 5.1, which the tool is built for; the retired-value cleanup is meant to remove exactly what older versions wrote; the installer already stops with an error message when the launch fails; *Revert all* sets personal settings such as dark mode back to the Windows default by design — its dialog now says so.
- **Found while testing** — a merged line in the test harness had switched off restoring the environment variables after a synthetic run.
- **Tests** — six new scenarios (Pi-hole DNS kept, bcdedit refused, bloatware on Windows 11, location service, Bing revert) and "All" in the real window; the real system unchanged.

</details>

---

## [1.2.1] — 2026-10-22

An honesty pass: tweaks that never did anything are gone, the safety net is lighter, and two dashboard tools work properly again.

- **8 tweaks removed** — the five NVIDIA registry tweaks (low latency / "Reflex", threaded optimization, pre-rendered frames, shader cache size, power management: the driver keeps these in its own profile database and never reads those values), *Disable Spatial Sound* (a value Windows doesn't use), *Disable Audio Device Power Save* (undocumented values; *Disable USB Selective Suspend* covers USB) and *Disable Windows Settings Backup* (an organisation-only policy whose 0 equals the default). Now **105 tweaks**; *Revert all* also removes what the old ones left behind.
- **Get Started & Copilot sign-in screens** — Enterprise / Education only, as Microsoft documents it; on Home / Pro the tweak changes nothing and its status stays grey.
- **Restore point only before app removals** — the registry backup still runs before every Apply and Revert. The 24-hour limit Windows puts on restore points is lifted for that one call only (older versions left it off for good).
- **Services manager** — *Enable* brings back the start type a service had before (*Automatic*, *Automatic (delayed)*), not always *Manual*.
- **Snapshot & compare** is kept after a restart, e.g. across a Windows update. Its result text shows again, and a BIOS Guide filter chip keeps its state.
- **README** — "every setting can be undone": app removals and the cleanups are one-way, and it now says so.

<details>
<summary><b>Development log — 1.2.1</b> (one or two lines per step)</summary>

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
