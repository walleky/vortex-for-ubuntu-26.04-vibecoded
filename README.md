# Proton Vortex for Ubuntu

Display name: **vortex for ubuntu 26.04 -vibecoded-**

A small Linux wrapper that installs and runs Nexus Mods Vortex through Steam Proton, then registers `nxm://` links so Nexus Mods "Download with manager" buttons open Vortex automatically.

This chooses Vortex instead of Mod Organizer 2 because Vortex has documented NXM URL commands, which makes browser integration and Nexus Collections much simpler.

## Start Here

If you just want it working:

1. Read [START-HERE.md](START-HERE.md)
2. Run `bash install.sh`
3. Launch **Vortex (Proton)**
4. Launch Skyrim with **Skyrim SE SKSE (Proton)**
5. Run `proton-vortex doctor` if you want a read-only health check

If you are an AI assistant or maintainer:

1. Read [AI Maintainer Guide](docs/AI-MAINTAINER-GUIDE.md)
2. Read [How It Works](docs/HOW-IT-WORKS.md)
3. Read [Stability And Compatibility Notes](docs/STABILITY-COMPATIBILITY.md)
4. Read [SKSE And Deployment Checklist](docs/SKSE-AND-DEPLOYMENT.md)
5. Run the checks listed at the bottom of the maintainer guide after editing

## What This Gives You

- Vortex installed into a Proton prefix managed by this bundle
- If Steam Skyrim Special Edition is installed, Vortex uses Skyrim SE's Proton prefix by default
- If Steam Skyrim Special Edition is found, plain Vortex launches with Vortex game id `skyrimse`
- A writable `VortexMods` folder beside Skyrim's Steam library, exposed to Proton as a simple drive such as `S:`
- Larger 200% Wine/Proton file picker dialogs, while Vortex itself still defaults to 150% Electron scale
- Automatic SKSE64 install helper for Steam Skyrim Special Edition
- A normal app launcher named **Skyrim SE SKSE (Proton)**
- A normal app launcher named **Vortex (Proton)**
- Linux desktop/dock icons for Vortex, Skyrim SKSE, and archive import
- A registered `nxm://` handler for Nexus Mods browser links
- Automatic Vortex NXM download/install handoff
- Local archive and direct external URL import for non-Nexus mods
- A file-manager **Import Mod with Vortex (Proton)** entry for common archive types
- A terminal command named `proton-vortex`
- A terminal command named `proton-vortex-skyrim-se`
- A read-only `proton-vortex doctor` check and a `proton-vortex doctor --fix` repair command
- Saved Vortex run logs under `~/.local/share/proton-vortex/logs`

## Requirements

- Ubuntu 26.04 or another recent Linux distro
- Steam installed from the normal Ubuntu/Valve package, not Flatpak
- At least one Proton version installed in Steam
- Skyrim Special Edition installed through Steam, for the Skyrim-specific automation
- Internet access for the Vortex download

Before running this, open Steam once and install a Proton tool:

1. Steam > Library
2. Search for `Proton`
3. Install **Proton Experimental** or the newest official stable Proton version

The installer prefers Proton Experimental or the newest official Steam Proton. It will not prefer an older GE-Proton 9 install unless you explicitly set `PROTON_PREFER_GE=1` or `PROTON_PATH`.

## Install

From this folder on Ubuntu:

```bash
bash install.sh
```

The installer will:

1. Find Steam
2. Find the best Proton install
3. Download the latest Vortex installer from the official Nexus-Mods/Vortex GitHub releases
4. Create the Proton prefix if Steam has not created it yet
5. Install Vortex silently into Skyrim SE's Proton prefix if Skyrim SE is found, otherwise into its own prefix
6. Create desktop launchers
7. Register `nxm://` links
8. Prepare writable Skyrim SE Vortex staging/download folders beside the Steam library
9. Install SKSE64 into the Skyrim SE game folder if Skyrim SE is found and SKSE is not already present

## Use

Launch Vortex from your app menu with **Vortex (Proton)**.

Launch Skyrim through SKSE with **Skyrim SE SKSE (Proton)**.

For Nexus Mods:

1. Open a Nexus Mods mod page in your browser
2. Click **Mod Manager Download**
3. Accept the browser prompt to open the link with **Vortex NXM Handler**

Normal Nexus mod NXM links are passed to Vortex's native download-and-install command. That means one Nexus click should make Vortex download and install the mod while preserving Nexus metadata, update tracking, dependencies, and collection behavior.

For Nexus Collections:

1. Open a Skyrim Special Edition collection on Nexus Mods
2. Click **Add Collection**
3. Accept the browser prompt to open the link with **Vortex NXM Handler**
4. Let Vortex handle the collection workflow

Nexus Premium is still the difference between fully automated collection downloads and lots of individual download clicks. This wrapper handles the Linux/NXM/Vortex side, but it does not bypass Nexus account limits.

Firefox may ask once which app should handle `nxm` links. Choose the Vortex handler and make it the default.

## Nexus API Key

You do not need this for normal Nexus downloads. Vortex handles normal `nxm://` links itself.

The no-hassle path is: log into Nexus inside Vortex if Vortex asks, then click **Mod Manager Download** on the Nexus page.

## Non-Nexus Mods

Local archives:

```bash
proton-vortex import ~/Downloads/some-mod.7z
```

Direct archive URLs:

```bash
proton-vortex 'https://example.com/some-mod.zip'
```

The helper downloads direct external archives into:

```text
~/.local/share/proton-vortex/downloads/external
```

Then it opens Vortex with a Proton-readable `file:///Z:/...` archive URL. For pages that are not direct archive URLs, use the browser/manual download first, then import the downloaded archive.

## How Mods Reach Skyrim

Vortex is still the Windows app. Proton makes it run on Ubuntu by giving it a fake Windows prefix. This wrapper installs Vortex into Skyrim SE's Steam Proton prefix, so Vortex and Skyrim see the same fake Windows user profile and the same Steam library.

For Skyrim SE, Vortex stages unpacked mods under a `skyrimse` staging folder, then deploys them into Skyrim's `Data` folder. Vortex normally uses hardlinks for this: files appear in the game folder without duplicating the full data. The important rule is that the staging folder and Skyrim folder must be on the same filesystem/partition.

The wrapper now creates a normal visible folder beside the Steam library, usually:

```text
<SteamLibrary>/VortexMods/skyrimse/mods
<SteamLibrary>/VortexMods/downloads
```

Inside Vortex's old Windows file picker, use the prepared simple drive path printed by `proton-vortex-skyrim-se fix-staging`, usually `S:\VortexMods\skyrimse\mods`. Do not create folders at bare `Z:\`; in Proton, `Z:` is your whole Linux filesystem, and many places under it are not writable.

If Vortex says the destination folder has to be empty, run `proton-vortex-skyrim-se empty-staging`. It creates a brand-new empty staging folder beside Skyrim, updates the helper path hints, and prints the exact `S:\...` path to use in Vortex. It does not delete the old staging folder.

The wrapper also writes helper shortcuts into the Proton desktop:

```text
C:\users\steamuser\Desktop\PROTON_VORTEX_PATHS.txt
C:\users\steamuser\Desktop\Vortex Staging Skyrim SE
C:\users\steamuser\Desktop\Vortex Downloads
C:\users\steamuser\Desktop\Skyrim Special Edition
C:\users\steamuser\Desktop\Launch Skyrim SE SKSE.bat
```

These make the old picker less hostile, but the safest paths to paste/use are still the printed `S:\...` paths.

SKSE64 is handled directly by this wrapper because SKSE needs loader/DLL files beside `SkyrimSE.exe`.

If Vortex downloaded mods but Skyrim still looks unmodded, read [SKSE And Deployment Checklist](docs/SKSE-AND-DEPLOYMENT.md). The short version is: install/enable mods, enable plugins, click **Deploy Mods**, and launch with `proton-vortex-skyrim-se launch-skse`.

## Commands

```bash
proton-vortex
proton-vortex 'nxm://example'
proton-vortex import ~/Downloads/mod.7z
proton-vortex doctor
proton-vortex doctor --fix
proton-vortex linked
proton-vortex preflight
proton-vortex last-log
proton-vortex self-update
proton-vortex repair-vortex
proton-vortex-skyrim-se install-skse
proton-vortex-skyrim-se launch-skse
proton-vortex-skyrim-se fix-staging
bash scripts/diagnose.sh
bash uninstall.sh
```

`proton-vortex doctor` is read-only. Use `proton-vortex doctor --fix` when you want it to rewrite the local app launchers, re-register desktop handlers, refresh the desktop database, and create low-risk support folders.

## Notes

- This is a Proton wrapper, not a rewritten native Linux Vortex build.
- Vortex itself still runs as the Windows app inside Proton.
- SKSE64 is installed directly into the Skyrim SE folder because that is the least fussy path: `skse64_loader.exe`, the SKSE DLLs, and the `Data` folder contents are copied where Skyrim expects them.
- Best launch path for modded play is `proton-vortex-skyrim-se launch-skse` or the **Skyrim SE SKSE (Proton)** app icon. Use Steam for first-run setup/unmodded launching, and Vortex for managing/deploying mods.
- To verify SKSE, launch through the helper, open Skyrim's console with `~`, and run `getskseversion`.
- Updates from this repo do not delete Vortex mods, collections, or downloaded archives. They replace wrapper scripts, desktop files, and icons while reusing the same Proton prefix and app data.
- Wrapper updates do not reinstall SKSE64 if `skse64_loader.exe` already exists. Run `proton-vortex-skyrim-se install-skse` when you want to update SKSE, or run `SKSE_AUTO_UPDATE=1 bash install.sh` to force it during install.
- Vortex log files use unique names and old logs are pruned automatically. Set `PROTON_VORTEX_LOG_KEEP=60` if you want to keep more than 30 runs.
- Non-Nexus archives often do not include Nexus metadata, so Vortex may not know the mod page/title automatically. The archive still installs through Vortex's normal installer pipeline.
- Game mod deployment can still depend on the game and filesystem layout. Steam Proton games under normal Steam library folders are the target path here.
- Flatpak Steam is detected and rejected by default because host Proton calls usually need Steam's Flatpak runtime. Use the normal Steam package for the no-hassle path.
- If you see "No Proton prefix found", rerun `bash install.sh`. If you intentionally use Skyrim's own prefix, launching Skyrim once from Steam also creates it.
- The installer sets the Proton prefix Windows DPI to `192`, which is 200% scaling for Wine dialogs and Vortex's old Windows file picker. Override with `PROTON_VORTEX_DPI=144 bash install.sh`, or disable with `PROTON_VORTEX_DPI=0 bash install.sh`.
- The launcher also applies Electron UI scaling with `PROTON_VORTEX_SCALE=1.5`, which is 150%. Override it with `PROTON_VORTEX_SCALE=1.25 proton-vortex`, or disable with `PROTON_VORTEX_SCALE=0 proton-vortex`.
- GPU-safe Electron rendering is on by default with `PROTON_VORTEX_DISABLE_GPU=1` because Proton/Electron can open an invisible or blank Vortex window on some X11/Wayland setups. Override with `PROTON_VORTEX_DISABLE_GPU=0 proton-vortex`.
- If the Vortex dock icon is generic, rerun `bash install.sh`; the launcher now uses the lower-case Wine window class `vortex.exe` and adds dock actions for SKSE launch/staging repair.
- If Vortex shows two Skyrims, run `proton-vortex doctor` and manage the Skyrim entry whose path matches the printed `Skyrim Vortex path hint`.
- If mods still do not appear in-game, run `proton-vortex-skyrim-se deployment`.
- If Vortex says the mod staging folder is not writable, run `proton-vortex-skyrim-se fix-staging`, then use the printed `S:\...` paths in Vortex.
- If Vortex says the destination folder has to be empty, run `proton-vortex-skyrim-se empty-staging`, then use the fresh empty `S:\...` path it prints.
- If Vortex says **No Vortex uninstall key**, run `proton-vortex repair-vortex`. This reinstalls Vortex over itself to recreate installer/registry metadata without deleting Vortex AppData, downloads, staging folders, profiles, or mod lists.
- Vortex's own Play button may still use plain Skyrim unless Vortex has made SKSE primary. The always-correct launch path is `proton-vortex-skyrim-se launch-skse`, the **Skyrim SE SKSE (Proton)** icon, or the Vortex dock action **Launch Skyrim SE SKSE**.
- If Vortex **Deploy Mods** fails, run `proton-vortex-skyrim-se hardlink-test`.
- If Vortex uses a custom staging folder, run `proton-vortex-skyrim-se hardlink-test "/path/to/staging"`.
- If character voices are silent but other sounds work, run `proton-vortex-skyrim-se audio-check`; if the voice archives are present, try `proton-vortex-skyrim-se audio-fix`.
- If Vortex gets choppy while downloading many mods, try `PROTON_VORTEX_PERFORMANCE=1 proton-vortex`, reduce Vortex parallel downloads to 1-2, and keep the download/staging folders on a fast local SSD.
- For Bethesda games, make sure the game itself is set to run with Proton in Steam, not the native Linux build.
- The SKSE helper defaults to the current Steam/AE build. If you intentionally downgraded Skyrim SE to `1.5.97`, run `SKSE_FLAVOR=se proton-vortex-skyrim-se install-skse`.

## Sources

- Vortex command-line support, including `--download` and `--install` for NXM URLs: <https://github.com/Nexus-Mods/Vortex/wiki/MODDINGWIKI-Users-Troubleshooting-Command-Line-Parameters>
- Vortex Skyrim SE guide, including same-partition staging folder requirements: <https://github.com/Nexus-Mods/Vortex/wiki/MODDINGWIKI-Users-GameGuides-Modding-Skyrim-Special-Edition-with-Vortex>
- Vortex deployment methods and hardlink requirements: <https://github.com/Nexus-Mods/Vortex/wiki/MODDINGWIKI-Users-General-Deployment-Methods>
- Proton project, which explains Proton as Steam's Wine-based Windows compatibility tool: <https://github.com/ValveSoftware/Proton>
- Vortex releases: <https://github.com/Nexus-Mods/Vortex/releases>
- SKSE official downloads and install notes: <https://skse.silverlock.org/>
- SKSE64 Nexus page install notes: <https://www.nexusmods.com/skyrimspecialedition/mods/30379>
- SteamDB Skyrim SE depot file listing, including `Skyrim - Voices_en0.bsa`: <https://steamdb.info/depot/489831/>
- Ask Ubuntu Proton voice-audio discussion mentioning the `xact` workaround: <https://askubuntu.com/questions/1211219/skyrim-special-edition-voices-not-working-steam-play-wine-and-xact-what-is-go>
- Nexus Collections overview: <https://www.nexusmods.com/collections>
- Nexus API client docs, including download links and NXM key/expires behavior: <https://github.com/Nexus-Mods/node-nexus-api>
- Nexus API acceptable use policy: <https://help.nexusmods.com/article/114-api-acceptable-use-policy>

## License

This wrapper project is open source under the [MIT License](LICENSE).

Vortex itself is separate software from Nexus Mods and is not bundled in this repository. The installer downloads Vortex from official Nexus-Mods/Vortex releases.
