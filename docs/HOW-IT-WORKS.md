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
- Registers `nxm://` browser links
- Downloads SKSE64 and puts the files where Skyrim expects them
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

The practical rule is: Vortex's Skyrim SE staging folder must be on the same filesystem/partition as the Skyrim SE folder. This wrapper defaults to Skyrim's own Proton compatdata folder, which normally sits beside the Steam library where Skyrim is installed:

```text
<Steam Library>/steamapps/compatdata/489830
<Steam Library>/steamapps/common/Skyrim Special Edition
```

That is why using Skyrim's prefix matters. It gives Vortex a Windows-looking home while keeping the staging area close enough to Skyrim for hardlink deployment.

## What Happens During Install

`install.sh` does this:

1. Checks that it is running on real Linux, not WSL
2. Installs missing Ubuntu tools if possible
3. Finds Steam
4. Finds Proton
5. Looks for Steam Skyrim SE
6. Chooses Skyrim SE's Proton prefix if Skyrim is installed
7. Creates the selected Proton prefix if it does not exist yet
8. Downloads the latest Vortex installer from GitHub
9. Runs the Vortex installer through Proton
10. Installs launcher scripts into `~/.local/bin`
11. Installs helper scripts into `~/.local/share/proton-vortex`
12. Creates desktop launchers
13. Registers `nxm://` links
14. Installs SKSE64 if Skyrim SE is found

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

`proton-vortex-skyrim-se launch-skse` runs:

```text
skse64_loader.exe
```

through the Skyrim SE Proton prefix.

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
proton-vortex preflight
proton-vortex last-log
```

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

Desktop files:

```text
~/.local/share/applications/proton-vortex.desktop
~/.local/share/applications/proton-vortex-nxm.desktop
~/.local/share/applications/proton-vortex-skyrim-se.desktop
~/.local/share/applications/proton-vortex-import.desktop
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
