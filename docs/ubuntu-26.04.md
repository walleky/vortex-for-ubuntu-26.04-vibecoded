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

1. GE-Proton or Proton-GE, if installed
2. Proton Experimental
3. The newest Proton it can find

To force one:

```bash
PROTON_PATH="$HOME/.steam/root/compatibilitytools.d/GE-Proton9-27" bash install.sh
```

`PROTON_PATH` should point to the directory that contains the `proton` executable.

## Skyrim SE Mode

If Skyrim Special Edition is installed through Steam, the installer uses Skyrim's own Proton prefix:

```text
<Steam Library>/steamapps/compatdata/489830
```

That gives Vortex, SKSE, and Skyrim the same Windows environment. If you prefer Vortex in a separate prefix, run:

```bash
VORTEX_STANDALONE_PREFIX=1 bash install.sh
```

## SKSE64

The installer adds:

```bash
proton-vortex-skyrim-se install-skse
proton-vortex-skyrim-se launch-skse
proton-vortex-skyrim-se diagnose
```

For a current Steam install, use the default:

```bash
proton-vortex-skyrim-se install-skse
```

For a deliberately downgraded `1.5.97` install:

```bash
SKSE_FLAVOR=se proton-vortex-skyrim-se install-skse
```

The helper downloads from the official SKSE page, extracts the archive, and copies the loader, DLL files, and `Data` folder contents into the Skyrim SE game folder.

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

Vortex can see Linux files through Proton's `Z:` drive mapping. Steam games normally live under paths like:

```text
~/.steam/root/steamapps/common
~/.local/share/Steam/steamapps/common
```

For the lowest-friction setup, install the game through Steam and force that game to use Proton in Steam's compatibility settings.

Launch the modded game with the app-menu entry **Skyrim SE SKSE (Proton)** or:

```bash
proton-vortex-skyrim-se launch-skse
```
