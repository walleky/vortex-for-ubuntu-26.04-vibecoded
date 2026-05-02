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
3. Set target to `skse64_loader.exe`
4. Set start-in to the Skyrim Special Edition game folder
5. Make the SKSE tool primary

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

In Vortex, open the game details for each Skyrim entry. The one you manage should match the path from `proton-vortex doctor`, usually as a Proton path starting with `Z:\...`.

Fix path:

1. In Vortex, go to **Games**
2. Find the Skyrim Special Edition entry whose game path matches `proton-vortex doctor`
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

- Windows DPI inside the Proton prefix: `PROTON_VORTEX_DPI`
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
PROTON_VORTEX_DISABLE_GPU=1 proton-vortex
```

## Commands To Run

```bash
proton-vortex doctor
proton-vortex preflight
proton-vortex-skyrim-se diagnose
proton-vortex-skyrim-se launch-skse
```
