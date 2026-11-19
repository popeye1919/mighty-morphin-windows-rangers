# 0xFF // The Nerdy Professor's Lecture Notes: Windows Registry, `shell:startup`, Custom `.psm1` Zords & Chrome Tab Group Tradecraft

> *"In 1995, while Zordon and Alpha-5 were summoning the Dinozords in the Command Center, we were tuning `C:\AUTOEXEC.BAT` and `C:\CONFIG.SYS` so our Sound Blaster 16 IRQ 5 DMA 1 initialized and Doom II loaded at boot. Today, Windows scatters startup hooks across four folder hierarchies and half a dozen Registry hives—which is why both sysadmins AND incident responders (`MITRE ATT&CK T1547.001`) need to know where every binary hides."*

---

## 1. Where Windows Actually Hides Startup Programs (`MITRE ATT&CK T1547.001`)

When [`Invoke-MorphinStartup.ps1`](../Invoke-MorphinStartup.ps1) runs **`Get-StartupFolderItems`**, it doesn't just look in one folder. It correlates four distinct Windows autostart locations and resolves `.lnk` binary shell links via the `WScript.Shell` COM object:

| Autostart Location | Scope | Windows Path / Registry Key | Forensic & Automation Note |
| :--- | :--- | :--- | :--- |
| **`shell:startup`** | Current User | `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup` | Contains `.lnk` shortcuts launched after user logon. Our script parses `.lnk` `TargetPath` and `Arguments` via COM. |
| **`shell:common startup`** | All Users | `%ProgramData%\Microsoft\Windows\Start Menu\Programs\StartUp` | Requires local Administrator privileges to modify; applies to every user who logs into the workstation. |
| **`HKCU\...\Run`** | Current User | `HKCU:\Software\Microsoft\Windows\CurrentVersion\Run` | Most common persistence vector for per-user apps (Discord, Spotify, OneDrive, Slack) and user-land malware. |
| **`HKLM\...\Run`** | All Users | `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run` | Machine-wide Registry Run key executed by `explorer.exe` at user session initialization. |

---

## 2. Why Single-Hive Registry Queries Miss Half Your Installed Apps

A common rookie mistake in PowerShell is running `Get-WmiObject -Class Win32_Product` or only querying `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall`.

> [!CAUTION]
> **Never use `Win32_Product` in PowerShell!**
> Querying `Win32_Product` via WMI/CIM triggers Windows Installer (`msiexec.exe`) to perform a silent consistency check and **reconfigure every single MSI package on the system**, flooding the Application Event Log with `Event ID 1035` and taking minutes to finish!

Instead, `Get-InstalledRegistryApplications` in [`Invoke-MorphinStartup.ps1`](../Invoke-MorphinStartup.ps1) queries the **three Registry Uninstall hives** directly in milliseconds:

1. **64-Bit Machine Installs:** `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*`
   * Holds native 64-bit applications installed for all users (e.g., Wireshark, 7-Zip, Docker Desktop, Git).
2. **32-Bit WOW6432Node Machine Installs:** `HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*`
   * Holds 32-bit x86 applications running under Windows-on-Windows 64-bit emulation (e.g., CHIRP-next, VMware Workstation launcher, legacy radio CPS software).
3. **Per-User AppData Installs (`HKCU`):** `HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*`
   * Modern Electron/Squirrel applications (**Visual Studio Code**, **Obsidian**, **Discord**, **Slack**, **Spotify**, **Postman**) install into `%LOCALAPPDATA%\Programs` without requiring a UAC Administrator prompt. If you only query `HKLM`, **none of these apps will show up!**

### How We Resolve the Actual `.exe` From a Registry Entry
Windows Uninstall Registry keys were designed for `appwiz.cpl` (Add/Remove Programs), which means they always store an `UninstallString`, but **do not have a standardized `LaunchExecutable` value**. Our `Resolve-RegistryAppExecutable` function uses a 3-stage heuristic pipeline:
1. **`DisplayIcon` Sanitization:** Strips trailing icon resource indices (like `,0` or `,-101`) from `DisplayIcon` and verifies the resulting `.exe` exists and isn't an uninstaller (`unins000.exe`, `msiexec.exe`).
2. **`InstallLocation` Binary Scoring:** Scans `InstallLocation` for `.exe` binaries, filtering out helper daemons (`crashpad_handler.exe`, `update.exe`, `vc_redist.exe`) and scoring filenames by token similarity to `DisplayName`.
3. **`App Paths` Cross-Reference:** Queries `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths` and `HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths`—the same lookup table Windows `Run` (`Win + R`) uses when you type `chrome`, `code`, or `wt`!

---

## 3. Chrome Tab Groups: How `Build-ChromeTabGroupExtension` Works Under the Hood

When you pass URLs to `chrome.exe` on the command line:
```powershell
chrome.exe --new-window "https://gchq.github.io/CyberChef/" "https://attack.mitre.org/"
```
Chromium opens those URLs as **standard ungrouped tabs**. Google Chrome does not expose a native CLI flag (like `--tab-group-name="SOC"`) to assign tab group titles or badge colors from PowerShell.

To give Chrome users **true named, color-coded, collapsible Chrome Tab Groups** without requiring third-party Web Store extensions or cloud account sync, [`Invoke-MorphinStartup.ps1`](../Invoke-MorphinStartup.ps1) includes an on-the-fly **Manifest V3 Micro-Extension Synthesizer** (`Build-ChromeTabGroupExtension`):

1. When you select **`[1] Native Colored Chrome Tab Groups`** in the wizard, the script generates two tiny, auditable plain-text files in `config/chrome-tabgroups-ext/`:
   * `manifest.json` — Requests only `"tabs"` and `"tabGroups"` permissions.
   * `background.js` — Embeds your exact JSON array of Tab Groups (`GroupName`, `Color`, `Collapsed`, `Urls`) and calls the official Chromium APIs:
     ```javascript
     const groupId = await chrome.tabs.group({
       tabIds: createdTabIds,
       createProperties: { windowId: currentWin.id }
     });
     await chrome.tabGroups.update(groupId, {
       title: grp.GroupName,
       color: grp.Color,      // grey, blue, red, yellow, green, pink, purple, cyan, orange
       collapsed: grp.Collapsed
     });
     ```
2. If you prefer **zero extensions**, selecting **`[2] Separate Chrome Windows per Group`** launches each Tab Group in its own clean `--new-window` cluster!

---

## 4. Custom PowerShell `.psm1` Zord Modules Architecture

Every `.psm1` file inside [`modules/`](../modules/) follows a clean 3-function PowerShell contract discovered dynamically via `Import-Module -PassThru`:
1. **`Get-MorphinModuleInfo`** — Returns a `[PSCustomObject]` with `ModuleName`, `ZordName`, `RangerColor`, `Version`, `Author`, and `Description`.
2. **`Set-MorphinModuleConfig` *(Optional)* ** — Executed during `-Mode Wizard` when the user enables the module, returning a `[hashtable]` of custom user answers that get persisted inside `config/startup-profile.json`.
3. **`Invoke-MorphinModule`** — Executed during `-Mode Run` with `-Settings <hashtable>` and `-DryRun:<bool>`, isolating module state inside the module's own scope.
