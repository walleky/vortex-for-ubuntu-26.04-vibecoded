# Vortex Skyrim SE MCP

Local MCP server for Windows Vortex + Skyrim Special Edition diagnostics.

It is built for an MCP client such as OpenClaw, Claude Desktop, Cursor, or any
stdio MCP client. The server is dependency-free Python and talks newline-delimited
JSON-RPC over stdin/stdout.

## What It Can Do

- Find Steam, Skyrim SE, Vortex AppData, Vortex staging folders, `plugins.txt`,
  `loadorder.txt`, SKSE, and common missing-path problems.
- Inventory Vortex-staged Skyrim SE mods.
- Read mod evidence: files, readmes, FOMOD XML, plugins, masters, BSA archives,
  SKSE DLL plugins, scripts, meshes, textures, UI files.
- Detect likely redundant mods:
  - duplicate plugin names
  - duplicate Nexus IDs when metadata is present
  - file-set subsets, optionally using SHA-256 hashes
- Detect loose-file conflicts between staged mods.
- Detect missing masters and enabled plugins that are missing on disk.
- Inspect Skyrim INI settings and apply a narrow safe set of INI fixes with
  backups. INI writes are dry-run by default.
- Write a JSON report that another agent can analyze.

## What It Will Not Do Automatically

It does not blindly delete mods, disable plugins, or rewrite broad Vortex profile
state. Vortex conflict rules and load-order changes are high-risk because the
wrong winner can break a save. This server gives OpenClaw evidence and repair
plans; destructive actions should stay human-approved.

## Install

1. Install Python 3 for Windows if you do not already have it.
2. Keep this folder somewhere stable, for example:

```text
C:\Users\<you>\Documents\vortex-skyrimse-mcp
```

3. In PowerShell:

```powershell
cd C:\Users\<you>\Documents\vortex-skyrimse-mcp
.\install_windows.ps1
```

The installer prints an MCP config snippet.

## MCP Client Config

Generic stdio MCP config:

```json
{
  "mcpServers": {
    "vortex-skyrimse": {
      "command": "py",
      "args": [
        "-3",
        "C:\\Users\\<you>\\Documents\\vortex-skyrimse-mcp\\server.py"
      ]
    }
  }
}
```

Restart OpenClaw after adding the server.

## First OpenClaw Prompts

Try:

```text
Use the vortex-skyrimse MCP to detect my Skyrim SE/Vortex environment and list the highest-risk problems.
```

Then:

```text
Use the vortex-skyrimse MCP to find missing masters, likely redundant mods, and sensitive file conflicts. Do not apply changes yet.
```

For INI fixes:

```text
Use the vortex-skyrimse MCP to show Skyrim INI fixes as a dry run.
```

To apply only the narrow INI fixes:

```text
Use apply_ini_fixes with dry_run=false and make_backup=true.
```

## Tools

- `detect_environment`
- `inventory_mods`
- `analyze_conflicts`
- `redundant_mod_report`
- `plugin_report`
- `mod_evidence`
- `ini_report`
- `apply_ini_fixes`
- `read_text_file`
- `suggest_conflict_fixes`
- `write_report`

Every path-taking tool accepts explicit override paths, which helps if Vortex is
using a custom staging folder.

## Path Overrides

Useful Windows paths:

```text
Vortex AppData:
%APPDATA%\Vortex

Typical Vortex Skyrim SE staging:
%APPDATA%\Vortex\skyrimse\mods

Skyrim SE Steam folder:
C:\Program Files (x86)\Steam\steamapps\common\Skyrim Special Edition

Plugins file:
%LOCALAPPDATA%\Skyrim Special Edition\plugins.txt

Skyrim INIs:
%USERPROFILE%\Documents\My Games\Skyrim Special Edition
```

If detection misses your setup, pass `skyrim_dir`, `staging_dir`,
`vortex_appdata`, or `my_games_dir` to the relevant tool.

## Safety Model

- `detect_environment`, `inventory_mods`, `analyze_conflicts`,
  `redundant_mod_report`, `plugin_report`, `mod_evidence`, `ini_report`,
  `read_text_file`, `suggest_conflict_fixes`, and `write_report` do not modify
  Vortex or Skyrim.
- `apply_ini_fixes` can write INI files only when `dry_run=false`.
- `apply_ini_fixes` creates backups by default.
- `read_text_file` refuses to read outside detected Vortex/Skyrim roots unless
  `allow_any_path=true`.

## Manual Smoke Test

```powershell
py -3 .\server.py --self-test
```

MCP handshake test:

```powershell
'{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"manual","version":"1"}}}' | py -3 .\server.py
```

You should get a JSON-RPC response with `serverInfo.name` equal to
`vortex-skyrimse-mcp`.

## Notes For Maintainers

This server intentionally avoids a dependency on Vortex internals. Current Vortex
state persistence has changed over time, and broad state writes are risky. When
possible, prefer filesystem evidence and Vortex UI-confirmed changes.

Sources used for protocol behavior:

- MCP stdio transport requires UTF-8 JSON-RPC messages delimited by newlines:
  https://modelcontextprotocol.io/specification/2025-03-26/basic/transports
- MCP tools are listed with `tools/list` and invoked with `tools/call`:
  https://modelcontextprotocol.io/specification/2025-06-18/server/tools
