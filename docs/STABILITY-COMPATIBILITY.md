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
- Re-register `nxm://`
- Refresh desktop integration

It should not rewrite Vortex's internal configuration.

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
- Electron UI scaling is handled with `PROTON_VORTEX_SCALE`; some desktops may still need a manual value such as `1.5`.
- Nexus Premium controls fully automatic collection downloads; the wrapper does not bypass Nexus account limits.
- Vortex hardlink deployment needs the staging folder and Skyrim folder on the same filesystem.
- Downloaded mods still need Vortex's normal install, enable, plugin-enable, and deploy steps before Skyrim can load them.
- Vortex can discover duplicate Skyrim entries through different Proton-visible paths. Manage the one matching `proton-vortex doctor`.
- Flatpak Steam is rejected by default because host-launched Proton is not reliable with Flatpak's runtime.
- Non-Nexus archives may lack metadata, so Vortex may not know their Nexus page or update status.
