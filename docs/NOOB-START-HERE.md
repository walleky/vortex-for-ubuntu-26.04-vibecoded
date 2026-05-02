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
- Steam installed
- Skyrim Special Edition installed in Steam
- Proton installed in Steam
- Internet access
- A Nexus Mods account

Do this once in Steam:

1. Open Steam
2. Install Skyrim Special Edition
3. Run Skyrim once from Steam, then quit
4. Search your Steam Library for `Proton`
5. Install **Proton Experimental** or a recent normal Proton version

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

## Set Up Nexus API

This is optional, but recommended.

Run:

```bash
proton-vortex api-key set
proton-vortex api validate
```

Paste your Nexus Mods personal API key when asked.

What this does:

- Lets Linux download normal Nexus mod archives directly when allowed
- Saves metadata beside downloaded files
- Falls back to Vortex automatically if Nexus refuses direct API download

It does not bypass Nexus limits. Free Nexus accounts still need normal website-generated links for some downloads.

## Download Mods From Nexus

On a Nexus mod page:

1. Click **Mod Manager Download**
2. Your browser asks what app should open the link
3. Pick **Vortex NXM Handler**
4. Make it the default if your browser asks

The helper will either:

- Download the archive on Linux and hand it to Vortex
- Or pass the original `nxm://` link to Vortex if that is the better/allowed path

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

If you have a direct archive URL:

```bash
proton-vortex 'https://example.com/mod-file.zip'
```

If the URL is just a webpage, download the archive in your browser first, then import the file.

## SKSE64

The installer tries to install SKSE64 automatically.

To update or reinstall SKSE64:

```bash
proton-vortex-skyrim-se install-skse
```

To play Skyrim with SKSE:

```bash
proton-vortex-skyrim-se launch-skse
```

Or use the app menu launcher:

```text
Skyrim SE SKSE (Proton)
```

For current Steam Skyrim Special Edition, use the default SKSE install. If you intentionally downgraded Skyrim to `1.5.97`, run:

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
- If Vortex cannot find Skyrim, run Skyrim once from Steam first
- If SKSE is missing, run `proton-vortex-skyrim-se install-skse`
- If collections are not automatic, check whether you are using a free Nexus account
- If a non-Nexus mod is a folder, zip it first

## What Not To Do

- Do not install the native Linux Skyrim build for this setup
- Do not launch modded Skyrim with plain `SkyrimSE.exe`
- Do not move Vortex staging/download folders until a basic mod works
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
