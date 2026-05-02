# Noob Start Here

This guide is for getting Skyrim Special Edition modding working on Ubuntu with the least clicking and guessing possible.

## What This Program Is

This is not a brand-new mod manager. It is a helper that makes Vortex behave nicely on Linux by running it through Steam Proton.

It also handles the annoying parts:

- Nexus `nxm://` browser links
- Nexus Collections links
- SKSE64 files for Skyrim Special Edition
- Local mod archives from outside Nexus
- Direct archive URLs from outside Nexus

## Before You Start

You need:

- Ubuntu 26.04
- Steam installed from the normal Steam package, not Flatpak
- Skyrim Special Edition installed in Steam
- Proton installed in Steam
- Internet access
- A Nexus Mods account

Do this once in Steam:

1. Open Steam
2. Install Skyrim Special Edition
3. Run Skyrim once from Steam, then quit
4. Search your Steam Library for `Proton`
5. Install **Proton Experimental** or the newest normal Proton version

The installer will pick Proton Experimental or the newest official Steam Proton it can find. It should not choose an old GE-Proton 9 just because that happens to be installed.

Vortex defaults to 150% UI scale. If Vortex still looks tiny, rerun:

```bash
PROTON_VORTEX_SCALE=1.5 bash install.sh
```

The old Windows folder picker uses 200% scaling by default. If it still looks too small, rerun:

```bash
PROTON_VORTEX_DPI=192 bash install.sh
```

If Vortex is invisible, blank, or choppy, rerun the installer. GPU-safe Vortex rendering is now the default:

```bash
PROTON_VORTEX_DISABLE_GPU=1 bash install.sh
```

To check the setup without changing anything:

```bash
proton-vortex doctor
proton-vortex linked
```

To repair desktop-side setup like the `nxm://` handler:

```bash
proton-vortex doctor --fix
```

That also rewrites the **Vortex (Proton)**, **Skyrim SE SKSE (Proton)**, and **Import Mod with Vortex (Proton)** app launchers if your desktop menu loses them.

If Vortex says **No Vortex uninstall key**, run:

```bash
proton-vortex repair-vortex
```

That reinstalls Vortex over itself to repair Windows registry/install metadata. It does not delete your Vortex downloads, staging folders, profiles, collections, or mod list.

## Install

Open a terminal in this folder and run:

```bash
bash install.sh
```

Wait for it to finish.

If it asks for your password, that is only to install missing Ubuntu packages like `curl`, `python3`, `xdg-utils`, or `7zip`.

## First Launch

After install, open your app menu and launch:

```text
Vortex (Proton)
```

In Vortex:

1. Log into Nexus Mods if Vortex asks
2. Let Vortex manage Skyrim Special Edition
3. Let Vortex use the suggested deployment method
4. Do not move Vortex folders around until everything works

If Vortex opens an old Windows-looking folder picker, that is normal. `C:` is Proton's fake Windows drive, and `Z:` is your real Linux filesystem. Do not try to make folders at bare `Z:\`.

If Vortex says the mod staging folder is not writable, close that picker and run:

```bash
proton-vortex-skyrim-se fix-staging
```

Then use the paths it prints, usually:

```text
Mod Staging Folder: S:\VortexMods\skyrimse\mods
Downloads Folder:   S:\VortexMods\downloads
Game folder:        S:\steamapps\common\Skyrim Special Edition
```

It also creates a text helper inside the Proton desktop:

```text
C:\users\steamuser\Desktop\PROTON_VORTEX_PATHS.txt
C:\users\steamuser\Desktop\Vortex Staging Skyrim SE
C:\users\steamuser\Desktop\Vortex Downloads
C:\users\steamuser\Desktop\Skyrim Special Edition
```

If Vortex says **destination folder has to be empty**, run:

```bash
proton-vortex-skyrim-se empty-staging
```

Then use the fresh empty `S:\VortexMods\skyrimse\empty-staging-...` path it prints. If Vortex offers to move your existing mods into that empty folder, allow it.

## Nexus API

Skip this for normal use. Vortex handles Nexus links directly, and that is the no-hassle path.

You do not need to paste a Nexus API key into this wrapper just to download mods. Log into Nexus inside Vortex if Vortex asks.

## Download Mods From Nexus

On a Nexus mod page:

1. Click **Mod Manager Download**
2. Your browser asks what app should open the link
3. Pick **Vortex NXM Handler**
4. Make it the default if your browser asks

The helper passes the original `nxm://` link to Vortex and asks Vortex to download and install it. That is the best default because Vortex keeps Nexus update tracking, requirements, and collection metadata.

## Install Nexus Collections

On a Skyrim Special Edition collection page:

1. Click **Add Collection**
2. Pick **Vortex NXM Handler**
3. Let Vortex handle the collection

Important:

- Nexus Premium gives the smooth one-click collection download flow
- Free accounts may still need to click individual downloads
- This helper fixes Linux/NXM/Vortex handling, not Nexus account limits

## Install Mods From Outside Nexus

If you downloaded a `.zip`, `.7z`, or `.rar` mod archive:

```bash
proton-vortex import ~/Downloads/mod-file.7z
```

Or right-click the archive in your file manager and choose:

```text
Import Mod with Vortex (Proton)
```

If you click **Import Mod with Vortex (Proton)** from the app menu with no file selected, it opens a native file picker when `zenity` or `kdialog` is available.

If you have a direct archive URL:

```bash
proton-vortex 'https://example.com/mod-file.zip'
```

If the URL is just a webpage, download the archive in your browser first, then import the file.

## SKSE64

The installer tries to install SKSE64 automatically the first time. If SKSE64 is already in the Skyrim folder, wrapper updates leave it alone.

To update or reinstall SKSE64:

```bash
proton-vortex-skyrim-se install-skse
```

If Vortex says `skse64_loader.exe` could not find `SkyrimSE.exe`, Vortex is launching SKSE from the wrong folder. Run:

```bash
proton-vortex-skyrim-se fix-skse-launcher
```

Then in Vortex Dashboard set the SKSE tool to the printed `Launch Skyrim SE SKSE.bat` target and printed `Start in` folder.

To force SKSE during a wrapper reinstall:

```bash
SKSE_AUTO_UPDATE=1 bash install.sh
```

To play Skyrim with SKSE:

```bash
proton-vortex-skyrim-se launch-skse
```

Or use the app menu launcher:

```text
Skyrim SE SKSE (Proton)
```

That is the best way to play modded Skyrim. Use Vortex to install/deploy mods. Use Steam mostly for first launch setup or plain unmodded Skyrim.

Vortex's own dashboard/play button only uses SKSE if Vortex has detected SKSE and made that tool primary. The wrapper cannot safely force Vortex's private state without risking your mod setup, so the no-hassle guaranteed launch path is the **Skyrim SE SKSE (Proton)** app icon or:

```bash
proton-vortex-skyrim-se launch-skse
```

If your dock supports right-click actions, the Vortex app icon also gets **Launch Skyrim SE SKSE** after rerunning `bash install.sh`.

To check that SKSE really loaded, open the Skyrim console with `~` and run:

```text
getskseversion
```

If Vortex downloaded mods but Skyrim still looks vanilla:

1. In Vortex, make sure the mods are installed
2. Make sure the mods are enabled
3. Open the Plugins tab and enable the plugins
4. Click **Deploy Mods**
5. Launch with `proton-vortex-skyrim-se launch-skse`

Then run:

```bash
proton-vortex-skyrim-se deployment
proton-vortex-skyrim-se fix-staging
proton-vortex-skyrim-se empty-staging
proton-vortex-skyrim-se hardlink-test
```

Deploy means Vortex is putting enabled mod files into Skyrim's real `Data` folder. If deploy fails, Skyrim will usually act like the mods are not installed yet.

Downloaded mods normally go into Vortex's downloads folder. Before the staging fix, that is usually inside Skyrim's Proton prefix under `steamapps/compatdata/489830/.../AppData/Roaming/Vortex/downloads`. After the staging fix, new downloads should use the easier `VortexMods/downloads` folder if Vortex is pointed there. Existing downloads are not deleted.

If Vortex Settings > Mods shows a different staging folder than the command prints, run `proton-vortex-skyrim-se fix-staging` and switch Vortex to the printed staging path. If Vortex says the destination folder must be empty, run `proton-vortex-skyrim-se empty-staging` and use the new empty path instead.

If Vortex shows two Skyrims, run:

```bash
proton-vortex doctor
```

Use the Skyrim entry in Vortex whose game path matches the printed `Skyrim Vortex path hint`. Do not delete the entry with your downloaded mods until the correct Skyrim deploys successfully.

If Vortex gets choppy while downloading a lot:

```bash
PROTON_VORTEX_PERFORMANCE=1 proton-vortex
```

Also lower Vortex's parallel downloads to 1 or 2 while installing a big collection.

If character voices are missing but other sounds work:

```bash
proton-vortex-skyrim-se audio-check
```

If it says voice archives are present, try:

```bash
proton-vortex-skyrim-se audio-fix
```

The helper now detects your `SkyrimSE.exe` runtime before installing SKSE. If your game is downgraded to `1.5.97`, it uses SKSE flavor `se`, which is SKSE `2.0.20`. If your game is Steam `1.6.x`, it uses the AE SKSE line. It also checks the downloaded archive before copying files, so the wrong SKSE build should stop with a clear error instead of leaving a broken half-install.

Normal command:

```bash
proton-vortex-skyrim-se install-skse
```

Manual override for downgraded Skyrim:

```bash
SKSE_FLAVOR=se proton-vortex-skyrim-se install-skse
```

## If Something Goes Wrong

Run:

```bash
bash scripts/diagnose.sh
```

Common fixes:

- If Nexus links do nothing, set **Vortex NXM Handler** as the default in your browser
- If you are unsure Skyrim was detected, run `bash scripts/diagnose.sh` and look for `Skyrim SE detected`
- If you are unsure Vortex and Skyrim are linked, run `proton-vortex linked`
- If you are unsure a collection is safe to start, run `proton-vortex preflight`
- If Vortex fails or closes, run `proton-vortex last-log`
- `proton-vortex doctor` is a read-only check; `proton-vortex doctor --fix` is the repair command
- If Vortex cannot find Skyrim, run Skyrim once from Steam first
- If you see "No Proton prefix found", rerun `bash install.sh`; the installer now tries to create the prefix for you
- If SKSE is missing, run `proton-vortex-skyrim-se install-skse`
- If SKSE says it cannot find `SkyrimSE.exe`, run `proton-vortex-skyrim-se fix-skse-launcher`
- If Vortex says the staging folder is not writable, run `proton-vortex-skyrim-se fix-staging`
- If Vortex says the destination folder must be empty, run `proton-vortex-skyrim-se empty-staging`
- If Vortex says no uninstall key, run `proton-vortex repair-vortex`
- If collections are not automatic, check whether you are using a free Nexus account
- If a non-Nexus mod is a folder, zip it first

## What Not To Do

- Do not install the native Linux Skyrim build for this setup
- Do not launch modded Skyrim with plain `SkyrimSE.exe`
- Do not choose bare `Z:\` for staging/download folders
- Do not expect this to bypass Nexus Premium/free account limits

## The Happy Path

The normal flow should be:

```text
Install Steam + Skyrim SE + Proton
Run bash install.sh
Open Vortex (Proton)
Log into Nexus
Click Mod Manager Download on Nexus
Launch Skyrim SE SKSE (Proton)
```
