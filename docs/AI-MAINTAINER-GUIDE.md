# AI Maintainer Guide

This guide is for AI assistants or humans editing the project later.

## Goal

Keep the user-facing experience boring:

```text
bash install.sh
click Nexus link
Vortex opens
SKSE Skyrim launches
```

Prefer small, predictable shell/Python helpers over clever abstractions.

## File Map

`install.sh`

- Main installer
- Detects Linux, Steam, Proton, Skyrim SE
- Rejects Flatpak Steam by default because host Proton cannot reliably use Flatpak's runtime
- Prefers Proton Experimental/newest official Steam Proton before GE-Proton, unless `PROTON_PREFER_GE=1` or `PROTON_PATH` is set
- Bootstraps the selected Proton prefix before Vortex install
- Writes Wine dialog/file-picker DPI registry values in the prefix unless `PROTON_VORTEX_DPI=0`; default is `192`
- Stores `PROTON_VORTEX_SCALE`, which the launcher passes to Electron as a scale factor
- Stores `PROTON_VORTEX_DISABLE_GPU`, `PROTON_VORTEX_PERFORMANCE`, and `PROTON_VORTEX_WINEDEBUG` for rendering, heavy-download, and log-noise tuning
- Prepares `VortexMods` staging/download folders beside Skyrim's Steam library
- Maps that Steam library into Proton as `PROTON_VORTEX_DRIVE_LETTER`, default `s`
- Creates Proton desktop picker helpers and an SKSE batch helper for Vortex's Windows dialogs
- Installs Vortex through Proton
- Copies launchers/helpers
- Writes desktop files, including Vortex dock actions for SKSE launch and staging repair
- Writes hicolor SVG app icons and refreshes icon cache when available
- Registers `nxm://`
- Tries SKSE64 setup only when Skyrim is found and SKSE is not already present, unless `SKSE_AUTO_UPDATE=1`

`scripts/proton-vortex.sh`

- Main launcher installed as `~/.local/bin/proton-vortex`
- Loads `~/.local/share/proton-vortex/config.env`
- Can be sourced in Bash tests without running `main`
- Finds `Vortex.exe`
- Launches plain Vortex with `--game skyrimse` when Skyrim SE was detected
- Delegates NXM/URL/archive intake to `mod-intake.py`
- Passes local archives to Vortex as Proton-readable `file:///Z:/...` URLs
- Captures Vortex/Proton stdout and stderr to `~/.local/share/proton-vortex/logs`
- Provides `doctor`, `doctor --fix`, `linked`, `preflight`, `last-log`, and `self-update`
- Runs Vortex through Proton
- Keeps plain `doctor` read-only; put state repair in `doctor --fix`
- Prints the expected Skyrim path, simple drive path, staging path, and downloads path so users can identify duplicate Vortex game entries

`scripts/mod-intake.py`

- Linux-side mod intake
- Parses `nxm://`
- Stores/validates Nexus API keys
- Calls Nexus API for validation and opt-in file download helpers
- Downloads Nexus archives only when `PROTON_VORTEX_API_NXM=1`
- Downloads direct external archive URLs
- Resolves local archive files
- Prints a two-line machine-readable result for `proton-vortex.sh`

`scripts/skyrim-se.sh`

- Skyrim SE helper installed as `~/.local/bin/proton-vortex-skyrim-se`
- Finds Steam Skyrim SE app `489830`
- Installs SKSE64
- Launches `skse64_loader.exe` through Proton
- Provides deployment/audio checks and an explicit `audio-fix` command for Proton voice-audio issues
- Provides an explicit `hardlink-test` command for deployment filesystem checks
- Provides `fix-staging` to create writable Vortex folders, Proton drive mapping, and symlinks for empty default Vortex folders
- Provides `empty-staging` to create a fresh empty staging folder when Vortex refuses a non-empty destination

`scripts/diagnose.sh`

- User-facing health check
- Confirms scripts, desktop files, NXM registration, Vortex config, Skyrim state, and API key status

`uninstall.sh`

- Removes launchers and desktop files
- Offers to remove app data and cache

`docs/NOOB-START-HERE.md`

- Beginner setup guide

`docs/HOW-IT-WORKS.md`

- Plain-English architecture

`docs/SKSE-AND-DEPLOYMENT.md`

- SKSE launch verification and Vortex deployment troubleshooting

`docs/ubuntu-26.04.md`

- Ubuntu-specific notes

## Important Contracts

`mod-intake.py resolve <value>` must print exactly two useful stdout lines:

```text
install
nxm://...
```

or:

```text
install-url
file:///Z:/home/user/archive.7z
```

or:

```text
download
nxm://...
```

or:

```text
raw
whatever
```

Warnings must go to stderr so Bash can safely read stdout.

`mod-intake.py` is responsible for turning Linux absolute paths into Proton file URLs:

```text
/home/user/file.7z
file:///Z:/home/user/file.7z
```

Keep this contract stable unless every caller is updated.

`proton-vortex doctor` must stay read-only.

`proton-vortex doctor --fix` may repair only low-risk Linux-side integration:

- Create support folders
- Rewrite local desktop launchers
- Re-register `nxm://`
- Refresh the desktop database
- Confirm shared Skyrim/Vortex prefix when Skyrim is detected

Do not make it rewrite Vortex's internal state with `--set` unless the state path is verified against current Vortex.

`proton-vortex-skyrim-se fix-staging` may create:

```text
<Steam Library>/VortexMods/skyrimse/mods
<Steam Library>/VortexMods/downloads
<Skyrim prefix>/pfx/dosdevices/s:
<Skyrim prefix>/pfx/drive_c/users/*/Desktop/PROTON_VORTEX_PATHS.txt
<Skyrim prefix>/pfx/drive_c/users/*/Desktop/Vortex Staging Skyrim SE
<Skyrim prefix>/pfx/drive_c/users/*/Desktop/Vortex Downloads
<Skyrim prefix>/pfx/drive_c/users/*/Desktop/Skyrim Special Edition
<Skyrim prefix>/pfx/drive_c/users/*/Desktop/Launch Skyrim SE SKSE.bat
```

It may replace empty default Vortex staging/download folders with symlinks to those prepared folders. It must leave non-empty existing folders alone.

`proton-vortex-skyrim-se empty-staging` may create:

```text
<Steam Library>/VortexMods/skyrimse/empty-staging-YYYYMMDD-HHMMSS
```

It must not delete existing staging folders. It may update `VORTEX_SKYRIMSE_STAGING_DIR` and `VORTEX_SKYRIMSE_STAGING_WIN_PATH` in `config.env` to keep future diagnostics pointed at the fresh folder.

Do not auto-edit undocumented Vortex profile/tool/game state to force the Dashboard Play button to SKSE. Use the Linux SKSE launcher, dock action, helper command, or generated `.bat` file instead unless Vortex documents a stable state API.

## NXM Behavior

Normal Nexus mod file link:

```text
nxm://skyrimspecialedition/mods/<mod_id>/files/<file_id>?key=...&expires=...
```

Default behavior:

```text
install
nxm://...
```

This calls Vortex with `--install nxm://...`, which uses Vortex's native download-and-install flow and preserves Nexus metadata, update tracking, dependencies, and collection behavior.

With `PROTON_VORTEX_API_NXM=1` and an API key:

1. Parse game, mod id, file id, key, expires
2. Call file info endpoint
3. Call download link endpoint
4. Download archive
5. Return `install-url file:///Z:/...`

Without the opt-in flag, without API key, or on API failure:

```text
install
nxm://...
```

This falls back to Vortex's native download-and-install flow.

Collection link:

```text
nxm://skyrimspecialedition/collections/<slug>/revisions/<revision>
```

Always return:

```text
install
nxm://...
```

Vortex owns collection install behavior.

## Nexus API Limits

Do not add logic that bypasses Nexus restrictions.

Known rule:

- Free users often need the website-generated NXM `key` and `expires` values for direct file download links
- Premium users can usually generate direct download links more freely

If the API refuses the request, fall back to Vortex rather than retrying aggressively.

## SKSE Behavior

Default:

```bash
proton-vortex-skyrim-se install-skse
```

uses `SKSE_FLAVOR=ae`, which is correct for current Steam Skyrim SE executable `1.6.1170`.

Downgraded Skyrim:

```bash
SKSE_FLAVOR=se proton-vortex-skyrim-se install-skse
```

Do not delete user files from the Skyrim folder. Updating SKSE overwrites only SKSE loader/DLL files and copies SKSE `Data` contents.

`install.sh` should skip automatic SKSE work when `skse64_loader.exe` already exists. Users can explicitly refresh SKSE with:

```bash
proton-vortex-skyrim-se install-skse
```

or force it during install with:

```bash
SKSE_AUTO_UPDATE=1 bash install.sh
```

## Desktop Integration

NXM handler:

```text
~/.local/share/applications/proton-vortex-nxm.desktop
MimeType=x-scheme-handler/nxm;x-scheme-handler/nxm-protocol;
```

Archive import:

```text
~/.local/share/applications/proton-vortex-import.desktop
```

Do not make archive import the default archive handler. It should be an Open With option.

## Safe Editing Rules

- Keep stdout machine-readable where scripts expect it
- Put human warnings on stderr
- Quote every path
- Avoid deleting user data
- Avoid changing Vortex folders after install
- Keep the fallback path to Vortex intact
- Prefer adding diagnostics over making assumptions

## Verification

Run these after editing:

```bash
bash -n install.sh
bash -n scripts/proton-vortex.sh
bash -n scripts/skyrim-se.sh
bash -n scripts/diagnose.sh
bash -n uninstall.sh
python3 -m py_compile scripts/mod-intake.py
```

On a real Ubuntu machine with Steam installed, also run:

```bash
bash install.sh
bash scripts/diagnose.sh
proton-vortex doctor
proton-vortex linked
proton-vortex preflight
proton-vortex api-key status
proton-vortex-skyrim-se diagnose
xdg-mime query default x-scheme-handler/nxm
```

Expected NXM handler:

```text
proton-vortex-nxm.desktop
```

## Common Failure Points

Steam not found:

- User has not run Steam once
- Steam is installed somewhere unusual
- Ask them to run `STEAM_ROOT=/path/to/Steam bash install.sh`

Proton not found:

- User has not installed Proton in Steam
- Tell them to install Proton Experimental

Old Proton selected:

- The installer should prefer Proton Experimental or the newest official numbered Proton
- GE-Proton is fallback by default because stale GE-Proton9 installs caused old-prefix choices
- User can force a specific tool with `PROTON_PATH=/path/to/Proton bash install.sh`
- User can intentionally prefer GE with `PROTON_PREFER_GE=1 bash install.sh`

NXM does nothing:

- Browser kept its own handler
- Tell user to set **Vortex NXM Handler** in browser application settings

SKSE missing:

- Run `proton-vortex-skyrim-se install-skse`
- Verify in game with `getskseversion`

Mods downloaded but not active:

- Confirm mods are installed and enabled in Vortex
- Confirm plugins are enabled in Vortex's Plugins tab
- Click **Deploy Mods**
- Launch with `proton-vortex-skyrim-se launch-skse`
- Run `proton-vortex preflight` to check prefix and staging placement
- Run `proton-vortex-skyrim-se fix-staging` when Vortex says staging is not writable or the Windows picker is confusing
- Run `proton-vortex-skyrim-se empty-staging` when Vortex says the destination folder has to be empty
- Run `proton-vortex-skyrim-se hardlink-test` when Vortex reports deploy failure

Two Skyrim entries in Vortex:

- Run `proton-vortex-skyrim-se fix-staging`
- Manage the Skyrim entry whose path matches the printed simple drive game path, usually `S:\steamapps\common\Skyrim Special Edition`
- Do not tell users to delete the modded entry until deployment works from the correct game

Tiny or choppy Vortex UI:

- Default scale is `PROTON_VORTEX_SCALE=1.5`
- Default Wine dialog/file picker DPI is `PROTON_VORTEX_DPI=192`
- Default GPU-safe rendering is `PROTON_VORTEX_DISABLE_GPU=1`
- Try `PROTON_VORTEX_SCALE=1.25 proton-vortex` if 150% is too large
- Persist with `PROTON_VORTEX_SCALE=1.5 bash install.sh`
- Persist 200% Wine dialogs with `PROTON_VORTEX_DPI=192 bash install.sh`
- Persist GPU-safe rendering with `PROTON_VORTEX_DISABLE_GPU=1 bash install.sh`
- Try `PROTON_VORTEX_PERFORMANCE=1 proton-vortex` for heavy download sessions
- Suggest reducing Vortex parallel downloads to 1-2 for large collections

Character voices missing:

- Run `proton-vortex-skyrim-se audio-check`
- If voice BSA files are missing, tell user to verify Skyrim files in Steam and check language
- If voice BSA files are present but voices are silent, run `proton-vortex-skyrim-se audio-fix`
- Do not run audio-fix automatically; it modifies the Proton prefix

Need to force SKSE during wrapper install:

- Run `SKSE_AUTO_UPDATE=1 bash install.sh`

Collection not fully automatic:

- Usually Nexus account limitation, not the wrapper

External mod URL fails:

- URL is probably a webpage, not a direct archive
- Tell user to download the archive first and run `proton-vortex import <file>`

No Proton prefix found:

- `COMPAT_DATA` exists but `COMPAT_DATA/pfx` does not
- Rerun `bash install.sh`; it should call Proton `wineboot -u`
- If using Skyrim's own prefix, launching Skyrim once from Steam also creates it
