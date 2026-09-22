#!/usr/bin/env python3
"""Run Kof LSP diagnostics against every tracked Kof source."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import select
import subprocess
import sys
import time
from urllib.parse import quote


def message(payload: dict) -> bytes:
    body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
    return b"Content-Length: " + str(len(body)).encode("ascii") + b"\r\n\r\n" + body


def read_message(stream, timeout: float) -> dict | None:
    ready, _, _ = select.select([stream], [], [], timeout)
    if not ready:
        return None
    headers: dict[str, str] = {}
    while True:
        line = stream.readline()
        if not line:
            return None
        line = line.rstrip(b"\r\n")
        if not line:
            break
        key, value = line.decode("ascii").split(":", 1)
        headers[key.lower()] = value.strip()
    length = int(headers["content-length"])
    body = stream.read(length)
    if len(body) != length:
        return None
    return json.loads(body.decode("utf-8"))


def files(roots: list[Path]) -> list[Path]:
    result: list[Path] = []
    for root in roots:
        if root.is_file() and root.suffix == ".kf":
            result.append(root)
        elif root.is_dir():
            result.extend(root.rglob("*.kf"))
    return sorted(set(path.resolve() for path in result))


def main() -> int:
    parser = argparse.ArgumentParser(description="Check Kof LSP diagnostics")
    parser.add_argument("roots", nargs="+", type=Path)
    args = parser.parse_args()
    paths = files(args.roots)
    if not paths:
        print("lsp: no Kof source files found", file=sys.stderr)
        return 2

    root = (paths[0].parent if len(args.roots) == 1 and args.roots[0].is_file() else args.roots[0]).resolve()
    if root.is_file():
        root = root.parent
    process = subprocess.Popen(
        ["kof", "lsp"],
        cwd=root,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    assert process.stdin is not None
    assert process.stdout is not None
    diagnostics: dict[str, list[dict]] = {}

    def send(payload: dict) -> None:
        process.stdin.write(message(payload))
        process.stdin.flush()

    send(
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "processId": None,
                "rootUri": root.as_uri(),
                "capabilities": {},
                "workspaceFolders": [{"uri": root.as_uri(), "name": root.name}],
            },
        }
    )
    initialized = False
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        response = read_message(process.stdout, max(0.1, deadline - time.monotonic()))
        if response is None:
            break
        if response.get("id") == 1:
            if "error" in response:
                print(f"lsp initialize failed: {response['error']}", file=sys.stderr)
                process.terminate()
                return 1
            initialized = True
            break
    if not initialized:
        print("lsp initialize timed out", file=sys.stderr)
        process.terminate()
        return 1

    send({"jsonrpc": "2.0", "method": "initialized", "params": {}})
    for path in paths:
        uri = "file://" + quote(str(path), safe="/")
        send(
            {
                "jsonrpc": "2.0",
                "method": "textDocument/didOpen",
                "params": {
                    "textDocument": {
                        "uri": uri,
                        "languageId": "kof",
                        "version": 1,
                        "text": path.read_text(encoding="utf-8"),
                    }
                },
            }
        )

    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        response = read_message(process.stdout, min(0.25, deadline - time.monotonic()))
        if response is None:
            if process.poll() is not None:
                break
            continue
        if response.get("method") == "textDocument/publishDiagnostics":
            params = response.get("params", {})
            diagnostics[params.get("uri", "")] = params.get("diagnostics", [])

    send({"jsonrpc": "2.0", "id": 2, "method": "shutdown", "params": None})
    shutdown_deadline = time.monotonic() + 5
    while time.monotonic() < shutdown_deadline:
        response = read_message(process.stdout, min(0.25, shutdown_deadline - time.monotonic()))
        if response and response.get("id") == 2:
            break
    send({"jsonrpc": "2.0", "method": "exit", "params": None})
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()

    allowed_module_diagnostics = {"PKG004", "PKG006"}
    errors: list[str] = []
    allowed = 0
    for uri, entries in diagnostics.items():
        for entry in entries:
            if entry.get("severity", 1) > 2:
                continue
            code = str(entry.get("code", ""))
            if code in allowed_module_diagnostics:
                allowed += 1
                continue
            location = entry.get("range", {}).get("start", {})
            errors.append(
                f"{uri}:{location.get('line', 0) + 1}:{location.get('character', 0) + 1}: "
                f"{entry.get('message', 'diagnostic')}"
            )
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    suffix = f"; ignored {allowed} known single-document package diagnostic(s)" if allowed else ""
    print(f"LSP diagnostics passed for {len(paths)} Kof source file(s){suffix}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
