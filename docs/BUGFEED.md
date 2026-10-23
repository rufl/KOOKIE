# Bugfeed

The browser game has a **BUGFEED** button in the top bar. Press it to capture the current WebGL scene, add notes, and save a report. When WebGL capture is unavailable, the report can still be saved with diagnostics and an explicit missing-screenshot field. A successful save displays a UUID; paste that ID into a KOOKIE support conversation to locate the report.

## Captured data and privacy

Reports include the user-entered notes (up to 4,000 characters), PNG screenshot when available, page origin/path (query parameters are excluded), browser user agent, viewport and pixel ratio, client runtime/status, current authoritative scene summary, ping, renderer name, and up to 40 recent uncaught browser errors/rejected promises. Session tokens, URL query parameters, cookies, and local storage are not included. Avoid putting secrets or personal data in notes. Submission is explicit; opening the dialog captures locally but does not upload until **Save report** is pressed.

Reports are sent over the same-origin HTTPS tailnet proxy to the loopback-only Node service. The service accepts bounded binary reports, assigns a UUID, and writes private per-report directories (`0700`) and files (`0600`) under `$KOOKIE_BUGFEED_DIR`, defaulting to `~/.local/state/kookie/bugfeed`. `report.json` contains metadata and `screenshot.png` is present only when capture succeeded. Reports persist across preview restarts. Access is limited by tailnet membership/ACL; anyone with the report UUID and access to the service can read the report, so treat the ID as private.

For a report ID `<UUID>`, the service provides `GET /bugfeed/<UUID>` (JSON) and, when present, `GET /bugfeed/<UUID>/screenshot.png`. These routes are intended for internal troubleshooting, not public internet exposure. The Node service binds only to `127.0.0.1`; Caddy exposes its routes only through the configured Tailscale Serve path. The tailnet preview requires Node.js.

Start/restart the preview using `scripts/run_tailnet_web_preview.sh`. Optional settings: `KOOKIE_BUGFEED_PORT` (default `8767`) and `KOOKIE_BUGFEED_DIR` (persistent report root). The preview startup validates both the local service and the tailnet proxy health route.

Run the persistence, retrieval, rejection, and restart smoke with:

```bash
node scripts/verify_bugfeed.js
```

The browser contract smoke is `node scripts/verify_web_alpha_contract.js <built-web-alpha-dir>` after `scripts/build_web_alpha.sh`.
