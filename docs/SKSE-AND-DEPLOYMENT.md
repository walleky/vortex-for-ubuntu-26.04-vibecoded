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
- Vortex says deployed, but there are zero staged mod folders
- Plugins are disabled
- You launched plain `SkyrimSE.exe` instead of SKSE

## Commands To Run

```bash
proton-vortex doctor
proton-vortex preflight
proton-vortex-skyrim-se diagnose
proton-vortex-skyrim-se launch-skse
```

