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

If you are an AI assistant or maintainer:

1. Read [AI Maintainer Guide](docs/AI-MAINTAINER-GUIDE.md)
2. Read [How It Works](docs/HOW-IT-WORKS.md)
3. Run the checks listed at the bottom of the maintainer guide after editing

## What This Gives You

- Vortex installed into a Proton prefix managed by this bundle
- If Steam Skyrim Special Edition is installed, Vortex uses Skyrim SE's Proton prefix by default
- Automatic SKSE64 install/update helper for Steam Skyrim Special Edition
- A normal app launcher named **Skyrim SE SKSE (Proton)**
- A normal app launcher named **Vortex (Proton)**
- A registered `nxm://` handler for Nexus Mods browser links
- Linux-side NXM intake with optional Nexus Mods API download support
- Local archive and direct external URL import for non-Nexus mods
- A file-manager **Import Mod with Vortex (Proton)** entry for common archive types
- A terminal command named `proton-vortex`
- A terminal command named `proton-vortex-skyrim-se`
- A diagnostics script for checking the Proton path, Vortex executable, and MIME registration

## Requirements

- Ubuntu 26.04 or another recent Linux distro
- Steam installed
- At least one Proton version installed in Steam
- Skyrim Special Edition installed through Steam, for the Skyrim-specific automation
- Internet access for the Vortex download

Before running this, open Steam once and install a Proton tool:

1. Steam > Library
2. Search for `Proton`
3. Install **Proton Experimental** or a current stable Proton version

## Install

From this folder on Ubuntu:

```bash
bash install.sh
```

The installer will:

1. Find Steam
2. Find the best Proton install
3. Download the latest Vortex installer from the official Nexus-Mods/Vortex GitHub releases
4. Install Vortex silently into Skyrim SE's Proton prefix if Skyrim SE is found, otherwise into its own prefix
5. Create desktop launchers
6. Register `nxm://` links
7. Install SKSE64 into the Skyrim SE game folder if Skyrim SE is found

## Use

Launch Vortex from your app menu with **Vortex (Proton)**.

Launch Skyrim through SKSE with **Skyrim SE SKSE (Proton)**.

For Nexus Mods:

1. Open a Nexus Mods mod page in your browser
2. Click **Mod Manager Download**
3. Accept the browser prompt to open the link with **Vortex NXM Handler**

Without a Nexus API key, the handler passes the NXM link to Vortex, which uses Vortex's own login/session. With a Nexus API key configured, the Linux helper can call the Nexus API itself, download the archive, save a metadata sidecar, and hand the archive to Vortex for install.

For Nexus Collections:

1. Open a Skyrim Special Edition collection on Nexus Mods
2. Click **Add Collection**
3. Accept the browser prompt to open the link with **Vortex NXM Handler**
4. Let Vortex handle the collection workflow

Nexus Premium is still the difference between fully automated collection downloads and lots of individual download clicks. This wrapper handles the Linux/NXM/Vortex side, but it does not bypass Nexus account limits.

Firefox may ask once which app should handle `nxm` links. Choose the Vortex handler and make it the default.

## Nexus API Key

For the best Linux-side NXM handling:

```bash
proton-vortex api-key set
proton-vortex api validate
```

The key is stored at:

```text
~/.local/share/proton-vortex/nexus-api-key
```

with `0600` permissions. You can also avoid storing it and use:

```bash
NEXUS_API_KEY=your_key proton-vortex 'nxm://...'
```

Free Nexus accounts still need the `key` and `expires` values inside a website-generated NXM link for direct API download links. Premium accounts can usually generate file download links directly through the API.

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

Then it opens Vortex with the local archive. For pages that are not direct archive URLs, use the browser/manual download first, then import the downloaded archive.

## Commands

```bash
proton-vortex
proton-vortex 'nxm://example'
proton-vortex import ~/Downloads/mod.7z
proton-vortex api-key set
proton-vortex api validate
proton-vortex-skyrim-se install-skse
proton-vortex-skyrim-se launch-skse
bash scripts/diagnose.sh
bash uninstall.sh
```

## Notes

- This is a Proton wrapper, not a rewritten native Linux Vortex build.
- Vortex itself still runs as the Windows app inside Proton.
- SKSE64 is installed directly into the Skyrim SE folder because that is the least fussy path: `skse64_loader.exe`, the SKSE DLLs, and the `Data` folder contents are copied where Skyrim expects them.
- Non-Nexus archives often do not include Nexus metadata, so Vortex may not know the mod page/title automatically. The archive still installs through Vortex's normal installer pipeline.
- Game mod deployment can still depend on the game and filesystem layout. Steam Proton games under normal Steam library folders are the target path here.
- For Bethesda games, make sure the game itself is set to run with Proton in Steam, not the native Linux build.
- The SKSE helper defaults to the current Steam/AE build. If you intentionally downgraded Skyrim SE to `1.5.97`, run `SKSE_FLAVOR=se proton-vortex-skyrim-se install-skse`.

## Sources

- Vortex command-line support, including `--download` for NXM URLs: <https://github.com/Nexus-Mods/Vortex/wiki/MODDINGWIKI-Users-Troubleshooting-Command-Line-Parameters>
- Vortex releases: <https://github.com/Nexus-Mods/Vortex/releases>
- SKSE official downloads and install notes: <https://skse.silverlock.org/>
- SKSE64 Nexus page install notes: <https://www.nexusmods.com/skyrimspecialedition/mods/30379>
- Nexus Collections overview: <https://www.nexusmods.com/collections>
- Nexus API client docs, including download links and NXM key/expires behavior: <https://github.com/Nexus-Mods/node-nexus-api>
- Nexus API acceptable use policy: <https://help.nexusmods.com/article/114-api-acceptable-use-policy>

## License

This wrapper project is open source under the [MIT License](LICENSE).

Vortex itself is separate software from Nexus Mods and is not bundled in this repository. The installer downloads Vortex from official Nexus-Mods/Vortex releases.
