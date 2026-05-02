# Ubuntu 26.04 Notes

This wrapper expects the normal desktop Linux pieces Ubuntu ships with: `bash`, `python3`, `xdg-mime`, `curl`, Steam, and Proton.

For Skyrim Special Edition, install the Steam version first. The app id is `489830`.

## Steam Install

The installer checks these Steam locations:

- `~/.steam/root`
- `~/.steam/steam`
- `~/.local/share/Steam`

Flatpak Steam lives under `~/.var/app/com.valvesoftware.Steam`, but it is rejected by default. This wrapper runs Proton from the host, and Flatpak Steam usually needs Proton to run inside Flatpak's runtime. Use the normal Steam package for the easy path.

If Steam lives somewhere else, run:

```bash
STEAM_ROOT=/path/to/Steam bash install.sh
```

## Proton Selection

The installer prefers:

1. `PROTON_PATH`, if you set it
2. Proton Experimental, if installed
3. The newest official numbered Steam Proton, such as Proton 10 or Proton 11 beta
4. Proton Hotfix
5. GE-Proton or Proton-GE, only as a fallback

To force one:

```bash
PROTON_PATH="$HOME/.steam/root/steamapps/common/Proton Experimental" bash install.sh
```

`PROTON_PATH` should point to the directory that contains the `proton` executable. You can also point it directly at the `proton` file.

If you specifically prefer GE-Proton over official Steam Proton, run:

```bash
PROTON_PREFER_GE=1 bash install.sh
```

If the installer can only find an older Proton line like Proton 9, it will warn you and continue. Install Proton Experimental or the newest official Proton in Steam, then rerun `bash install.sh`.

## Skyrim SE Mode

If Skyrim Special Edition is installed through Steam, the installer uses Skyrim's own Proton prefix:

```text
<Steam Library>/steamapps/compatdata/489830
```

That gives Vortex, SKSE, and Skyrim the same Windows environment. If you prefer Vortex in a separate prefix, run:

```bash
VORTEX_STANDALONE_PREFIX=1 bash install.sh
```

When Skyrim SE is found, the launcher records Vortex game id `skyrimse` and uses it for plain Vortex launches.

## Staging And Downloads

Vortex is a Windows app, so its folder picker shows Proton drives:

- `C:` is the fake Windows drive inside the Proton prefix.
- `Z:` is your real Linux filesystem.
- A prepared drive such as `S:` points directly at Skyrim's Steam library.

Do not make folders at bare `Z:\`. Run:

```bash
proton-vortex-skyrim-se fix-staging
```

The command creates and tests:

```text
<SteamLibrary>/VortexMods/skyrimse/mods
<SteamLibrary>/VortexMods/downloads
```

It also creates helper items inside Proton's fake Windows desktop:

```text
C:\users\steamuser\Desktop\PROTON_VORTEX_PATHS.txt
C:\users\steamuser\Desktop\Launch Skyrim SE SKSE.bat
C:\users\steamuser\Desktop\Vortex Staging Skyrim SE
C:\users\steamuser\Desktop\Vortex Downloads
```

Then use the printed paths in Vortex Settings:

```text
Mod Staging Folder: S:\VortexMods\skyrimse\mods
Downloads Folder:   S:\VortexMods\downloads
Game folder:        S:\steamapps\common\Skyrim Special Edition
```

Downloaded mods are archives. Installed mods are unpacked into the staging folder. Deployed mods are hardlinked/copied into Skyrim's real `Data` folder.

## Vortex UI Scale

The installer sets Windows DPI inside the Proton prefix to `192`, which makes Wine dialogs and the old Vortex file picker about 200%. It launches Vortex itself with Electron scale `1.5`, so the main Vortex UI stays at 150% by default.

To force the default 150% UI scale:

```bash
PROTON_VORTEX_SCALE=1.5 bash install.sh
```

For a one-off bigger launch:

```bash
PROTON_VORTEX_SCALE=1.5 proton-vortex
```

To disable the Electron scale factor:

```bash
PROTON_VORTEX_SCALE=0 proton-vortex
```

To disable the Windows DPI tweak:

```bash
PROTON_VORTEX_DPI=0 bash install.sh
```

To force 200% Wine/file-picker scaling:

```bash
PROTON_VORTEX_DPI=192 bash install.sh
```

If Vortex is invisible, blank, or very choppy, keep GPU-safe Electron rendering enabled:

```bash
PROTON_VORTEX_DISABLE_GPU=1 bash install.sh
```

If Vortex gets choppy while downloading a large collection:

```bash
PROTON_VORTEX_PERFORMANCE=1 proton-vortex
```

Also reduce Vortex parallel downloads to 1 or 2. Collection installs are heavy on disk writes, archive extraction, and network traffic.

## Doctor And Logs

Run:

```bash
proton-vortex doctor
```

That check is read-only.

To repair safe desktop-side issues:

```bash
proton-vortex doctor --fix
```

If Vortex says **No Vortex uninstall key**:

```bash
proton-vortex repair-vortex
```

That reinstalls the Vortex app over itself to repair install metadata. It does not delete Vortex downloads, staging folders, profiles, collections, or mod lists.

That creates low-risk support folders, refreshes the desktop database, and re-registers the `nxm://` handler.

Before starting a large collection:

```bash
proton-vortex linked
proton-vortex preflight
```

If Vortex crashes or behaves strangely:

```bash
proton-vortex last-log
```

If Vortex downloaded mods but Skyrim did not change:

```bash
proton-vortex preflight
proton-vortex-skyrim-se diagnose
proton-vortex-skyrim-se deployment
proton-vortex-skyrim-se fix-staging
proton-vortex-skyrim-se empty-staging
proton-vortex-skyrim-se hardlink-test
```

Then check Vortex's Mods tab, Plugins tab, and **Deploy Mods** button.

Deployment means Vortex links enabled mod files into Skyrim's real `Data` folder. If deployment fails, the game can launch normally but behave as if mods are missing.

If Vortex Settings > Mods says staging is not writable, run `proton-vortex-skyrim-se fix-staging` and switch Vortex to the printed `S:\...` staging folder.

If Vortex says the destination folder has to be empty, run `proton-vortex-skyrim-se empty-staging` and switch Vortex to the fresh empty `S:\VortexMods\skyrimse\empty-staging-...` path it prints. If Vortex offers to move existing mods there, allow it.

If Vortex shows two Skyrim entries, the active one may point at the wrong discovered game path. Run:

```bash
proton-vortex doctor
```

Then manage the Skyrim entry whose Vortex game path matches the printed simple drive path, usually `S:\steamapps\common\Skyrim Special Edition`.

If this project was installed from a git clone:

```bash
proton-vortex self-update
```

## Launching Skyrim

For modded play, use:

```bash
proton-vortex-skyrim-se launch-skse
```

or the **Skyrim SE SKSE (Proton)** app icon.

Use Vortex to manage and deploy mods. Use Steam mainly for first-run setup, Proton settings, and unmodded launching.

Vortex's own Dashboard/Play button only launches SKSE if Vortex has detected SKSE and made that tool primary. The wrapper does not force-edit Vortex's private state because that can risk profiles and mod lists. Rerunning `bash install.sh` adds Linux dock action **Launch Skyrim SE SKSE** to the Vortex launcher, and `proton-vortex-skyrim-se fix-staging` creates `C:\users\steamuser\Desktop\Launch Skyrim SE SKSE.bat` for Vortex's tool picker.

If Vortex says `skse64_loader.exe` could not find `SkyrimSE.exe`, run:

```bash
proton-vortex-skyrim-se fix-skse-launcher
```

Then set the Vortex Dashboard SKSE tool to the printed `Launch Skyrim SE SKSE.bat` target and printed `Start in` folder. The generated batch file inside the Skyrim folder avoids the wrong-working-directory problem.

## App Icons

The installer writes SVG icons into:

```text
~/.local/share/icons/hicolor/scalable/apps
```

Then it uses those icons in the Linux desktop entries. If your dock still shows a generic icon, log out/in or rerun:

```bash
bash install.sh
```

The Vortex desktop file uses `StartupWMClass=vortex.exe` for Wine window matching. Some desktops cache icons aggressively; logging out/in after rerunning the installer may be needed.

If **Vortex (Proton)** disappears from the app menu but the command still exists, run:

```bash
proton-vortex doctor --fix
```

That rewrites the local desktop entries and refreshes the desktop database.

## SKSE64

The installer adds:

```bash
proton-vortex-skyrim-se install-skse
proton-vortex-skyrim-se launch-skse
proton-vortex-skyrim-se diagnose
```

The helper detects your `SkyrimSE.exe` runtime before installing SKSE. Runtime `1.5.97` uses SKSE flavor `se`, which is SKSE `2.0.20`. Steam `1.6.x` uses the AE SKSE line. It verifies that the archive contains the DLL for your detected runtime before copying files into the game folder.

Normal command:

```bash
proton-vortex-skyrim-se install-skse
```

Manual override for a deliberately downgraded `1.5.97` install:

```bash
SKSE_FLAVOR=se proton-vortex-skyrim-se install-skse
```

The helper downloads from the official SKSE page, extracts the archive, and copies the loader, DLL files, and `Data` folder contents into the Skyrim SE game folder.

Wrapper updates leave SKSE64 alone when `skse64_loader.exe` is already present. To force SKSE64 during install:

```bash
SKSE_AUTO_UPDATE=1 bash install.sh
```

To verify SKSE in-game, launch through `proton-vortex-skyrim-se launch-skse`, open Skyrim's console with `~`, and run:

```text
getskseversion
```

If character voices are silent but other audio works:

```bash
proton-vortex-skyrim-se audio-check
```

If the voice BSA files are present but voices are still silent, try the optional Proton audio fix:

```bash
sudo apt install protontricks winetricks
proton-vortex-skyrim-se audio-fix
```

## NXM Links

The installer registers:

```text
x-scheme-handler/nxm
x-scheme-handler/nxm-protocol
```

to:

```text
proton-vortex-nxm.desktop
```

Check it with:

```bash
xdg-mime query default x-scheme-handler/nxm
```

Re-register it with:

```bash
xdg-mime default proton-vortex-nxm.desktop x-scheme-handler/nxm
```

Normal mod links are sent to Vortex's native download-and-install workflow. Nexus collection links are sent to Vortex's collection install workflow.

Nexus Premium still controls whether collections can download automatically in bulk. Free accounts may still need to click through individual mod downloads in the collection flow.

## Advanced Nexus API Checks

Normal Nexus downloads do not need a Nexus API key in this wrapper. Vortex handles normal `nxm://` links directly.

The NXM handler also has a Linux-side API helper for diagnostics:

```bash
proton-vortex api-key set
proton-vortex api validate
```

The Linux API download path is intentionally hidden behind an environment variable because Vortex tracks native NXM installs better:

```bash
PROTON_VORTEX_API_NXM=1 proton-vortex 'nxm://...'
```

In that mode, normal Nexus mod NXM links are parsed on Linux. The helper calls:

```text
GET /v1/users/validate
GET /v1/games/{game}/mods/{mod_id}/files/{file_id}
GET /v1/games/{game}/mods/{mod_id}/files/{file_id}/download_link
```

For free Nexus accounts, direct download links require the website-generated NXM `key` and `expires` query values. If the API call fails, no API key is configured, or `PROTON_VORTEX_API_NXM=1` is not set, the wrapper uses Vortex's own download-and-install flow.

Downloaded Nexus archives are stored under:

```text
~/.local/share/proton-vortex/downloads/nexus
```

Each downloaded archive gets a `.proton-vortex.json` sidecar with the source NXM URL and API metadata.

## Non-Nexus Mods

Import local archives:

```bash
proton-vortex import ~/Downloads/mod.zip
proton-vortex import ~/Downloads/mod.7z
```

Download and import direct archive URLs:

```bash
proton-vortex 'https://example.com/mod.7z'
```

The installer also adds **Import Mod with Vortex (Proton)** as an Open With option for common archive formats. It does not make itself the default archive opener.

## Firefox

Firefox can keep its own application preference after Linux registers the handler. If a Nexus link does not open Vortex:

1. Firefox Settings
2. General
3. Applications
4. Find `nxm`
5. Choose **Vortex NXM Handler**
6. Set it as the default

## Game Paths

Vortex can see Linux files through Proton's `Z:` drive mapping, but the wrapper also creates a simpler Steam-library drive such as `S:` because it is easier to pick and usually writable. Steam games normally live under paths like:

```text
~/.steam/root/steamapps/common
~/.local/share/Steam/steamapps/common
```

For the lowest-friction setup, install the game through Steam and force that game to use Proton in Steam's compatibility settings.

Launch the modded game with the app-menu entry **Skyrim SE SKSE (Proton)** or:

```bash
proton-vortex-skyrim-se launch-skse
```
