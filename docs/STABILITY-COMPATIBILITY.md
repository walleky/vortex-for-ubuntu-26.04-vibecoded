# Stability And Compatibility Notes

This project tries to keep the wrapper boring. The goal is to improve Linux integration without disturbing Vortex's own mod database, downloads, profiles, or collection state.

## What Updates Replace

Running `git pull` and `bash install.sh` replaces:

- `~/.local/bin/proton-vortex`
- `~/.local/bin/proton-vortex-skyrim-se`
- `~/.local/share/proton-vortex/mod-intake.py`
- Desktop launchers under `~/.local/share/applications`
- SVG icons under `~/.local/share/icons/hicolor/scalable/apps`

It keeps using the same configured Proton prefix and Vortex app data.

When Skyrim SE is detected, updates may also create these support folders if missing:

```text
<Steam Library>/VortexMods/skyrimse/mods
<Steam Library>/VortexMods/downloads
```

If the old default Vortex staging/download folders are empty, the installer may replace those empty folders with symlinks to the prepared folders. It does not delete non-empty mod/download folders.

## What Updates Do Not Delete

Updates do not delete:

- Vortex downloads
- Installed mods
- Collections
- Vortex profiles
- Nexus API key
- Skyrim game files

`bash uninstall.sh` also asks before removing app data or cache.

## SKSE Safety

The installer only installs SKSE64 automatically when Skyrim SE is found and `skse64_loader.exe` is missing.

If SKSE64 is already installed, wrapper updates leave it alone. To refresh it intentionally:

```bash
proton-vortex-skyrim-se install-skse
```

To force SKSE64 during wrapper install:

```bash
SKSE_AUTO_UPDATE=1 bash install.sh
```

## Doctor Safety

`proton-vortex doctor` is read-only. It checks config, Proton, Vortex, Skyrim, NXM registration, prefix sharing, logs, and staging-folder placement.

`proton-vortex doctor --fix` may do low-risk repairs:

- Create support folders
- Rewrite local desktop launchers
- Re-register `nxm://`
- Refresh desktop integration

It should not rewrite Vortex's internal configuration.

`proton-vortex-skyrim-se fix-staging` creates prepared staging/download folders, maps the Steam library into Proton as a simple drive such as `S:`, links empty default Vortex folders, and runs a hardlink test. It leaves non-empty existing Vortex folders alone.

It also creates Proton desktop helpers for the old Windows file picker:

```text
C:\users\steamuser\Desktop\PROTON_VORTEX_PATHS.txt
C:\users\steamuser\Desktop\Vortex Staging Skyrim SE
C:\users\steamuser\Desktop\Vortex Downloads
C:\users\steamuser\Desktop\Skyrim Special Edition
C:\users\steamuser\Desktop\Launch Skyrim SE SKSE.bat
```

Those helpers are recreated on repair and do not delete Vortex's mod list, downloads, collections, or profiles.

## Proton Compatibility

The installer chooses Proton in this order:

1. `PROTON_PATH`, if set
2. Proton Experimental
3. Newest official numbered Steam Proton
4. Proton Hotfix
5. GE-Proton fallback

This avoids accidentally preferring an old GE-Proton 9 install over a newer official Steam Proton. Advanced users can force GE-Proton with:

```bash
PROTON_PREFER_GE=1 bash install.sh
```

## Known Remaining Limits

- Vortex is still the Windows app running through Proton, so occasional Electron UI jank can happen.
- Electron UI scaling is handled with `PROTON_VORTEX_SCALE`, defaulting to `1.5` for 150% UI scale.
- Wine dialog and file picker scaling is handled with `PROTON_VORTEX_DPI`, defaulting to `192` for about 200% scale.
- GPU-safe Electron rendering is enabled by default with `PROTON_VORTEX_DISABLE_GPU=1` because some Proton/Electron setups open an invisible or blank Vortex window otherwise.
- Heavy download sessions can use `PROTON_VORTEX_PERFORMANCE=1`; it changes launcher flags only, not Vortex data.
- Nexus Premium controls fully automatic collection downloads; the wrapper does not bypass Nexus account limits.
- Vortex hardlink deployment needs the staging folder and Skyrim folder on the same filesystem.
- If Vortex's Windows picker shows `C:` and `Z:`, use `proton-vortex-skyrim-se fix-staging` and the printed `S:\...` paths instead of creating folders at bare `Z:\`.
- The Vortex launcher uses `StartupWMClass=vortex.exe` plus desktop actions for SKSE and staging repair, but some docks cache old launcher metadata until logout/login or re-pinning.
- The wrapper does not force Vortex's private Dashboard/Play tool state. Use the SKSE launcher, `proton-vortex-skyrim-se launch-skse`, the Vortex dock action, or the generated SKSE batch helper for guaranteed SKSE launch.
- `proton-vortex-skyrim-se hardlink-test` writes and removes one tiny test file to confirm hardlinks can be created.
- Downloaded mods still need Vortex's normal install, enable, plugin-enable, and deploy steps before Skyrim can load them.
- Vortex can discover duplicate Skyrim entries through different Proton-visible paths. Manage the one matching `proton-vortex doctor`.
- The optional voice-audio fix installs `xact` into the Skyrim Proton prefix. It is never run automatically.
- Flatpak Steam is rejected by default because host-launched Proton is not reliable with Flatpak's runtime.
- Non-Nexus archives may lack metadata, so Vortex may not know their Nexus page or update status.
