# How It Works

This project is a small Linux glue layer around Vortex, Steam Proton, Nexus Mods links, and Skyrim Special Edition.

## Simple Version

Vortex is still the mod manager.

Steam Proton is what runs Vortex and Skyrim's Windows tools on Linux.

This project does the Linux desktop integration:

- Finds Steam
- Finds Proton
- Finds Skyrim Special Edition
- Installs Vortex into the right Proton prefix
- Creates the Proton prefix if it is missing
- Creates writable Vortex staging/download folders near Skyrim's Steam library
- Maps that Steam library into Proton as a simple drive letter such as `S:`
- Creates Proton desktop shortcuts/readme files so Vortex's old file picker has obvious writable targets
- Registers `nxm://` browser links
- Downloads SKSE64 and puts the files where Skyrim expects them when SKSE is missing
- Adds Linux launchers for Vortex and SKSE, plus Vortex dock actions for SKSE and staging repair
- Imports local and external mod archives into Vortex

## Why Skyrim's Proton Prefix Matters

Steam stores each Proton game in a compatibility folder called a prefix.

For Skyrim Special Edition, the Steam app id is:

```text
489830
```

The prefix is usually:

```text
<Steam Library>/steamapps/compatdata/489830
```

When Skyrim SE is found, this project installs/runs Vortex in that same prefix. That means Vortex, Skyrim, SKSE, and many Windows modding tools see the same fake Windows environment.

## How Vortex Passes Mods To Skyrim

Vortex downloads a mod archive, unpacks it into a staging folder, and then deploys the files into Skyrim's game folder. For Bethesda games, Vortex normally uses hardlinks. A hardlink makes the file appear inside Skyrim's `Data` folder while the managed copy still lives in Vortex's staging area.

The practical rule is: Vortex's Skyrim SE staging folder must be on the same filesystem/partition as the Skyrim SE folder. The wrapper creates visible folders beside the Steam library:

```text
<Steam Library>/steamapps/common/Skyrim Special Edition
<Steam Library>/VortexMods/skyrimse/mods
<Steam Library>/VortexMods/downloads
```

It also maps the Steam library into the Proton prefix as a simple drive letter, usually `S:`. That gives Vortex paths like:

```text
S:\steamapps\common\Skyrim Special Edition
S:\VortexMods\skyrimse\mods
S:\VortexMods\downloads
```

That avoids asking users to create folders under bare `Z:\`, which is Proton's view of the entire Linux filesystem and often includes paths Vortex cannot write to.

The wrapper cannot replace Vortex's built-in Windows file picker without forking Vortex. Instead, `proton-vortex-skyrim-se fix-staging` creates helper entries on the Proton desktop:

```text
C:\users\steamuser\Desktop\PROTON_VORTEX_PATHS.txt
C:\users\steamuser\Desktop\Vortex Staging Skyrim SE
C:\users\steamuser\Desktop\Vortex Downloads
C:\users\steamuser\Desktop\Skyrim Special Edition
C:\users\steamuser\Desktop\Launch Skyrim SE SKSE.bat
```

It also sets the Wine/Proton dialog DPI to `192` by default during install, which makes the old file picker roughly 200% scale. Vortex's main Electron UI uses `PROTON_VORTEX_SCALE`, default `1.5`.

If Vortex says deploy failed, it means the download/install state inside Vortex may be fine, but Vortex could not link the enabled files into Skyrim's `Data` folder. `proton-vortex-skyrim-se hardlink-test` checks the most common filesystem cause.

## What Happens During Install

`install.sh` does this:

1. Checks that it is running on real Linux, not WSL
2. Installs missing Ubuntu tools if possible
3. Finds Steam
4. Finds Proton
5. Looks for Steam Skyrim SE
6. Chooses Skyrim SE's Proton prefix if Skyrim is installed
7. Prepares `VortexMods` staging/download folders beside the Steam library
8. Creates the selected Proton prefix if it does not exist yet
9. Adds the simple Steam-library drive mapping inside Proton
10. Downloads the latest Vortex installer from GitHub
11. Runs the Vortex installer through Proton
12. Installs launcher scripts into `~/.local/bin`
13. Installs helper scripts into `~/.local/share/proton-vortex`
14. Creates desktop launchers
15. Registers `nxm://` links
16. Installs SKSE64 if Skyrim SE is found and SKSE is not already present

## What Happens When You Click A Nexus Mod Link

The browser opens:

```text
nxm://...
```

Linux sends that link to:

```text
proton-vortex-nxm.desktop
```

That runs:

```text
proton-vortex 'nxm://...'
```

Then `proton-vortex` asks `mod-intake.py` what to do.

For normal Nexus mod files, the helper sends the original link to:

```text
Vortex.exe --install nxm://...
```

Vortex's documented `--install` command downloads and installs NXM links. That keeps Vortex's native Nexus metadata, update tracking, dependencies, and collection behavior.

Advanced Linux-side API download is opt-in:

```bash
PROTON_VORTEX_API_NXM=1 proton-vortex 'nxm://...'
```

In that mode, the helper:

1. Parses the NXM URL
2. Asks the Nexus API for file metadata and download links
3. Downloads the archive when allowed
4. Saves the archive under `~/.local/share/proton-vortex/downloads/nexus`
5. Saves a metadata sidecar next to the archive
6. Opens Vortex with `--install file:///Z:/...`

If the API path fails, it falls back to Vortex's native download-and-install flow.

For Nexus Collections, the helper sends the collection link straight to:

```text
Vortex.exe --install nxm://...
```

Vortex owns the collection workflow.

## What Happens With Non-Nexus Mods

For a local archive:

```bash
proton-vortex import ~/Downloads/mod.7z
```

The helper checks that the file exists, converts the Linux path to a Proton-readable file URL, then runs:

```text
Vortex.exe --install file:///Z:/home/you/Downloads/mod.7z
```

For a direct archive URL:

1. Download the archive into `~/.local/share/proton-vortex/downloads/external`
2. Save a metadata sidecar
3. Hand the local archive to Vortex

## What Happens With SKSE64

`proton-vortex-skyrim-se install-skse`:

1. Finds Steam Skyrim SE
2. Downloads SKSE64 from the official SKSE page
3. Extracts the `.7z` archive
4. Copies `skse64_loader.exe` into the Skyrim folder
5. Copies `skse64_*.dll` into the Skyrim folder
6. Copies SKSE `Data` contents into Skyrim's `Data` folder

`bash install.sh` skips this automatic SKSE step when `skse64_loader.exe` already exists. That keeps wrapper updates from changing game-folder SKSE files unexpectedly. Use `proton-vortex-skyrim-se install-skse` or `SKSE_AUTO_UPDATE=1 bash install.sh` when you intentionally want to refresh SKSE.

`proton-vortex-skyrim-se launch-skse` runs:

```text
skse64_loader.exe
```

through the Skyrim SE Proton prefix.

Vortex's own Dashboard/Play button uses SKSE only after Vortex has detected SKSE and made it the primary tool. The wrapper does not force-edit Vortex's private game/tool state because that is where profiles, collections, and mod state live. The guaranteed launch paths are:

```text
Skyrim SE SKSE (Proton)
proton-vortex-skyrim-se launch-skse
Vortex dock action: Launch Skyrim SE SKSE
C:\users\steamuser\Desktop\Launch Skyrim SE SKSE.bat
```

To verify SKSE, launch with the helper, open Skyrim's console, and run:

```text
getskseversion
```

If Vortex downloaded mods but the game looks unchanged, Vortex still needs the normal deployment chain: installed mods, enabled mods, enabled plugins, then **Deploy Mods**.

If Vortex shows two Skyrim entries, use `proton-vortex-skyrim-se fix-staging` to print the simple drive path. The Vortex-managed Skyrim entry should usually match `S:\steamapps\common\Skyrim Special Edition`.

`proton-vortex-skyrim-se fix-staging` creates the prepared staging/download folders, adds the Proton drive mapping, links empty default Vortex folders to the prepared folders, and runs a hardlink deployment test.

`proton-vortex-skyrim-se empty-staging` creates a brand-new empty staging folder for Vortex's "destination folder has to be empty" prompt, tests hardlinks, updates the helper path hints, and does not delete existing staging folders.

`proton-vortex-skyrim-se deployment` checks the Skyrim `Data` folder, prepared staging folder, voice archives, deployed plugin files, and Proton `plugins.txt`. `proton-vortex-skyrim-se audio-fix` is optional and installs `xact` into the Skyrim Proton prefix through `protontricks` or `winetricks` for the Proton voice-audio issue.

`PROTON_VORTEX_PERFORMANCE=1 proton-vortex` adds Electron performance flags and quiets Wine debug output for heavier download sessions.

`PROTON_VORTEX_DISABLE_GPU=1` is saved by default. That makes Vortex more likely to draw visibly under Proton on both X11 and Wayland sessions where Electron GPU compositing can produce a blank or invisible window.

## Data Locations

Main config:

```text
~/.local/share/proton-vortex/config.env
```

Logs:

```text
~/.local/share/proton-vortex/logs
```

Doctor/preflight:

```bash
proton-vortex doctor
proton-vortex doctor --fix
proton-vortex linked
proton-vortex preflight
proton-vortex last-log
```

`proton-vortex doctor` only checks. `proton-vortex doctor --fix` creates low-risk support folders and repairs desktop integration.

Nexus API key:

```text
~/.local/share/proton-vortex/nexus-api-key
```

Nexus downloads:

```text
~/.local/share/proton-vortex/downloads/nexus
```

External downloads:

```text
~/.local/share/proton-vortex/downloads/external
```

Prepared Vortex downloads and staging for Skyrim SE:

```text
<Steam Library>/VortexMods/downloads
<Steam Library>/VortexMods/skyrimse/mods
```

Desktop files:

```text
~/.local/share/applications/proton-vortex.desktop
~/.local/share/applications/proton-vortex-nxm.desktop
~/.local/share/applications/proton-vortex-skyrim-se.desktop
~/.local/share/applications/proton-vortex-import.desktop
```

Icons:

```text
~/.local/share/icons/hicolor/scalable/apps/proton-vortex.svg
~/.local/share/icons/hicolor/scalable/apps/proton-vortex-skyrim-se.svg
~/.local/share/icons/hicolor/scalable/apps/proton-vortex-import.svg
```

Launchers:

```text
~/.local/bin/proton-vortex
~/.local/bin/proton-vortex-skyrim-se
```

## What This Does Not Do

- It does not rewrite Vortex as a native Linux app
- It does not bypass Nexus Premium/free account restrictions
- It does not guarantee every random mod archive is packaged correctly
- It does not replace Vortex's conflict resolution, deployment, or collection UI
- It does not support Windows Store/Game Pass Skyrim
