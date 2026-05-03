# Start Here

For the easy path, read:

[docs/NOOB-START-HERE.md](docs/NOOB-START-HERE.md)

Shortest possible version:

```bash
bash install.sh
```

Then open:

```text
Vortex (Proton)
```

To play modded Skyrim:

```text
Skyrim SE SKSE (Proton)
```

That launcher runs a preflight check first, then starts SKSE.

If something breaks:

```bash
bash scripts/diagnose.sh
proton-vortex doctor
proton-vortex doctor --fix
proton-vortex linked
proton-vortex-skyrim-se preflight-launch
proton-vortex-skyrim-se fix-staging
```

For AI assistants or maintainers, read:

[docs/AI-MAINTAINER-GUIDE.md](docs/AI-MAINTAINER-GUIDE.md)

For update safety notes, read:

[docs/STABILITY-COMPATIBILITY.md](docs/STABILITY-COMPATIBILITY.md)
