# SKSE And Deployment Checklist

This page is for the moment where Vortex downloaded mods, but Skyrim still looks vanilla.

## Best SKSE Path On Linux

Use the wrapper helper:

```bash
proton-vortex-skyrim-se install-skse
proton-vortex-skyrim-se launch-skse
```

SKSE is not a normal Skyrim mod. The important files must sit beside `SkyrimSE.exe`:

- `skse64_loader.exe`
- `skse64_steam_loader.dll`
- `skse64_*.dll`
- SKSE `Data` contents

The wrapper installs those files directly because that is more reliable under Proton than treating SKSE like an ordinary archive.

## Verify SKSE Works

Launch through:

```bash
proton-vortex-skyrim-se launch-skse
```

In Skyrim, open the console with `~`, then run:

```text
getskseversion
```

If a version prints, SKSE is active.

If the command is unknown, SKSE did not launch. Run:

```bash
proton-vortex-skyrim-se diagnose
proton-vortex-skyrim-se install-skse
```

Then launch again with `proton-vortex-skyrim-se launch-skse`.

## If You Want Vortex's Dashboard Button

The Linux wrapper launch command is the safest launch path.

If you also want Vortex's Dashboard button to launch SKSE:

1. Open Vortex Dashboard
2. Add a tool if SKSE is missing
3. Set target to the generated batch file in the Skyrim folder
4. Set start-in to the Skyrim Special Edition game folder
5. Make the SKSE tool primary

If Vortex says SKSE could not find `SkyrimSE.exe`, repair the launcher helpers:

```bash
proton-vortex-skyrim-se fix-skse-launcher
```

Then use the printed settings. They will look like:

```text
Target:   S:\steamapps\common\Skyrim Special Edition\Launch Skyrim SE SKSE.bat
Start in: S:\steamapps\common\Skyrim Special Edition
```

After `proton-vortex-skyrim-se fix-staging` or `proton-vortex-skyrim-se fix-skse-launcher`, the Proton desktop also contains:

```text
C:\users\steamuser\Desktop\Launch Skyrim SE SKSE.bat
```

You can add that batch file as a Vortex Dashboard tool too, but the batch file inside the Skyrim game folder is harder for Vortex to launch from the wrong working directory.

If that button still acts odd under Proton, use the Linux app icon **Skyrim SE SKSE (Proton)** or:

```bash
proton-vortex-skyrim-se launch-skse
```

## Vortex Downloaded Mods But Skyrim Did Not Change

In Vortex, check all four:

1. Mods tab: the mod is installed
2. Mods tab: the mod is enabled
3. Plugins tab: `.esp`, `.esm`, or `.esl` plugins are enabled
4. Click **Deploy Mods**

Downloading alone does not deploy a mod into Skyrim.

Collections can also be incomplete if Nexus still needs manual download clicks, especially on free Nexus accounts.

## What Deploy Means

Vortex has three different states that sound similar:

- **Downloaded** means the archive exists in Vortex's downloads.
- **Installed/Enabled** means Vortex unpacked the mod into its managed staging area and marked it active.
- **Deployed** means Vortex put the enabled files where Skyrim can actually load them.

For Skyrim SE, deployment normally means Vortex creates hardlinks from its staging folder into Skyrim's real `Data` folder. A hardlink looks like a normal file in `Data`, but it points to the same file data Vortex manages.

If deployment fails, Skyrim usually launches without those mod files. Your downloads are not necessarily gone. It normally means Vortex could not create, update, or remove the hardlinks.

Common causes:

- Vortex is managing the wrong duplicate Skyrim entry
- Staging folder and Skyrim are on different filesystems
- The game is running while Vortex tries to deploy
- A file conflict needs your choice in Vortex
- Folder permissions block changes in Skyrim's `Data` folder
- Old manually copied files are in the way

Run:

```bash
proton-vortex-skyrim-se deployment
proton-vortex-skyrim-se fix-staging
proton-vortex-skyrim-se empty-staging
proton-vortex-skyrim-se hardlink-test
```

If Vortex Settings > Mods shows a custom staging folder, you can test that exact folder:

```bash
proton-vortex-skyrim-se hardlink-test "/path/to/your/Vortex/staging/folder"
```

If Vortex also says **No Vortex uninstall key**, that is a separate Vortex app install warning, not a deployment warning. Run:

```bash
proton-vortex repair-vortex
```

Then go back to Vortex and deploy again.

## Vortex Says Staging Is Not Writable

The old Windows-looking file picker is expected. Vortex is a Windows app running inside Proton:

- `C:` is the fake Windows drive inside the Proton prefix.
- `Z:` is your real Linux filesystem.
- Many places under bare `Z:\` are not writable, and it is easy to pick the wrong folder.

Run:

```bash
proton-vortex-skyrim-se fix-staging
```

That creates a visible `VortexMods` folder beside the Steam library, maps the Steam library into Proton as a simple drive such as `S:`, and tests that hardlink deployment can work.

It also creates helper entries on the Proton desktop:

```text
C:\users\steamuser\Desktop\PROTON_VORTEX_PATHS.txt
C:\users\steamuser\Desktop\Vortex Staging Skyrim SE
C:\users\steamuser\Desktop\Vortex Downloads
C:\users\steamuser\Desktop\Skyrim Special Edition
```

Use the printed paths in Vortex:

```text
Game folder:        S:\steamapps\common\Skyrim Special Edition
Mod Staging Folder: S:\VortexMods\skyrimse\mods
Downloads Folder:   S:\VortexMods\downloads
```

If your drive letter is different, use the exact paths printed by the command. Do not choose bare `Z:\`.

If Vortex says the destination folder has to be empty, run:

```bash
proton-vortex-skyrim-se empty-staging
```

That creates a brand-new empty staging folder on the same filesystem as Skyrim and prints a path like:

```text
S:\VortexMods\skyrimse\empty-staging-20260502-113000
```

Use that fresh path as the **Mod Staging Folder**. The command does not delete your existing staging folder. If Vortex offers to move existing mods into the new empty folder, allow it.

Existing Vortex downloads usually live under `%APPDATA%\Vortex\downloads`, which is inside the Proton prefix. On Linux that is under Skyrim's compatdata folder, usually:

```text
<SteamLibrary>/steamapps/compatdata/489830/pfx/drive_c/users/steamuser/AppData/Roaming/Vortex/downloads
```

After `fix-staging`, new downloads can go to the prepared `VortexMods/downloads` folder if Vortex is using the prepared path. Existing downloads are not deleted.

## Vortex Shows Two Skyrims

This usually means Vortex discovered Skyrim twice through different Proton-visible paths. One entry may point at the real Steam Skyrim folder, while the other may be an old/manual/wrong discovery. If the enabled entry has no mods and the other entry has your mods, Vortex is managing the wrong game instance.

Run:

```bash
proton-vortex doctor
```

Look for:

```text
Skyrim SE:
Skyrim Vortex path hint:
```

In Vortex, open the game details for each Skyrim entry. The one you manage should match the simple drive path from `proton-vortex-skyrim-se fix-staging`, usually `S:\steamapps\common\Skyrim Special Edition`.

Fix path:

1. In Vortex, go to **Games**
2. Find the Skyrim Special Edition entry whose game path matches `proton-vortex-skyrim-se fix-staging`
3. Manage that entry
4. If Vortex lets you choose manually, set the location to the folder containing `SkyrimSE.exe`
5. Do not delete the entry that currently has your downloaded mods until the correct game deploys successfully
6. Go back to Mods and Plugins, enable what you want, then click **Deploy Mods**

If Vortex asks about deployment, use Hardlink Deployment and keep the staging folder on the same filesystem as Skyrim.

## Deployment Rules

For Skyrim SE, Vortex normally uses Hardlink Deployment. That is good.

The staging folder and Skyrim folder must be on the same filesystem/partition. Check with:

```bash
proton-vortex preflight
proton-vortex-skyrim-se fix-staging
proton-vortex-skyrim-se hardlink-test
```

Good signs:

- Vortex and Skyrim SE share the same Proton prefix
- Vortex game id is `skyrimse`
- SKSE loader is present
- Staging and Skyrim are on the same filesystem
- Vortex reports staged mod folders after mods are installed

Risk signs:

- Vortex prefix differs from Skyrim prefix
- Staging and Skyrim are on different filesystems
- Vortex has two Skyrim entries and the managed/enabled one does not match `proton-vortex doctor`
- Vortex says deployed, but there are zero staged mod folders
- Plugins are disabled
- You launched plain `SkyrimSE.exe` instead of SKSE

## Tiny Or Choppy Vortex UI

The wrapper applies two UI scaling helpers:

- Windows DPI inside the Proton prefix for Wine dialogs/file picker: `PROTON_VORTEX_DPI`, default `192` for 200%
- Electron scale factor at launch: `PROTON_VORTEX_SCALE`

Try a bigger one-off launch:

```bash
PROTON_VORTEX_SCALE=1.5 proton-vortex
```

To make it persistent:

```bash
PROTON_VORTEX_SCALE=1.5 bash install.sh
```

To disable the Electron scale factor:

```bash
PROTON_VORTEX_SCALE=0 proton-vortex
```

If Vortex is choppy or blank:

```bash
PROTON_VORTEX_DISABLE_GPU=1 bash install.sh
```

If Vortex gets choppy while downloading a large collection:

```bash
PROTON_VORTEX_PERFORMANCE=1 proton-vortex
```

Then in Vortex, lower parallel downloads to 1 or 2. Heavy collection downloads are disk, network, and archive-extraction heavy, so the UI can stutter even when nothing is broken. Keeping downloads, staging, and Skyrim on a fast local SSD helps.

## Commands To Run

```bash
proton-vortex doctor
proton-vortex preflight
proton-vortex-skyrim-se diagnose
proton-vortex-skyrim-se deployment
proton-vortex-skyrim-se fix-staging
proton-vortex-skyrim-se hardlink-test
proton-vortex-skyrim-se launch-skse
```

## Character Voices Are Gone

If music/effects work but NPC or player voices are silent, check the game voice archives first:

```bash
proton-vortex-skyrim-se audio-check
```

Good sign:

- `voice BSA: present`

Bad sign:

- `voice BSA: missing`

If the voice BSA is missing, use Steam's **Verify integrity of game files** for Skyrim Special Edition and make sure the Steam language is the language you want.

If the voice BSA is present but voices are still silent on Proton, try the optional audio compatibility fix:

```bash
proton-vortex-skyrim-se audio-fix
```

That installs the `xact` audio component into Skyrim SE's Proton prefix using `protontricks` or `winetricks`. If the command says the tool is missing:

```bash
sudo apt install protontricks winetricks
proton-vortex-skyrim-se audio-fix
```
