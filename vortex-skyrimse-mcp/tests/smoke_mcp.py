#!/usr/bin/env python3
import json
import subprocess
import sys
from pathlib import Path


def main() -> int:
    server = Path(__file__).resolve().parents[1] / "server.py"
    proc = subprocess.Popen(
        [sys.executable, str(server)],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    messages = [
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2025-06-18",
                "capabilities": {},
                "clientInfo": {"name": "smoke", "version": "1"},
            },
        },
        {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}},
        {
            "jsonrpc": "2.0",
            "id": 3,
            "method": "tools/call",
            "params": {"name": "detect_environment", "arguments": {}},
        },
    ]
    assert proc.stdin is not None
    assert proc.stdout is not None
    for msg in messages:
        proc.stdin.write(json.dumps(msg) + "\n")
        proc.stdin.flush()
        line = proc.stdout.readline()
        if not line:
            stderr = proc.stderr.read() if proc.stderr is not None else ""
            raise AssertionError(f"no response from MCP server; stderr={stderr}")
        data = json.loads(line)
        assert data.get("jsonrpc") == "2.0", data
        assert data.get("id") == msg["id"], data
        assert "result" in data, data
        if msg["id"] == 2:
            names = [tool["name"] for tool in data["result"]["tools"]]
            assert "detect_environment" in names, names
            assert "analyze_conflicts" in names, names
            assert "apply_ini_fixes" in names, names
        if msg["id"] == 3:
            assert data["result"]["isError"] is False, data
    proc.kill()
    print("MCP stdio smoke test passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
