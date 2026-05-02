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
- Writes Vortex UI DPI registry values in the prefix unless `PROTON_VORTEX_DPI=0`
- Installs Vortex through Proton
- Copies launchers/helpers
- Writes desktop files
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
- Re-register `nxm://`
- Refresh the desktop database
- Confirm shared Skyrim/Vortex prefix when Skyrim is detected

Do not make it rewrite Vortex's internal state with `--set` unless the state path is verified against current Vortex.

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
