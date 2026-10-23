#!/usr/bin/env node
"use strict";

const assert = require("node:assert/strict");
const { spawn } = require("node:child_process");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");

const service = path.resolve(__dirname, "../apps/web_server/bugfeed.js");
let root;
let child;
let port;
async function start() {
  child = spawn(process.execPath, [service], {
    env: { ...process.env, KOOKIE_BUGFEED_PORT: "0", KOOKIE_BUGFEED_DIR: root },
    stdio: ["ignore", "pipe", "inherit"],
  });
  let output = "";
  await new Promise((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error("Bugfeed startup timed out")), 5000);
    child.stdout.on("data", (chunk) => {
      output += chunk;
      const match = /listening 127\.0\.0\.1:(\d+)/.exec(output);
      if (match) {
        port = Number(match[1]);
        clearTimeout(timeout);
        resolve();
      }
    });
    child.once("exit", (code) => reject(new Error(`Bugfeed exited early: ${code} ${output}`)));
  });
}
async function stop() {
  if (!child) return;
  child.kill("SIGTERM");
  await new Promise((resolve) => child.once("exit", resolve));
  child = null;
}
async function main() {
  root = await fs.mkdtemp(path.join(os.tmpdir(), "kookie-bugfeed-"));
  try {
    await start();
    let response = await fetch(`http://127.0.0.1:${port}/bugfeed/healthz`);
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { status: "ok", service: "bugfeed" });

    const metadata = {
      reportVersion: 1,
      notes: "Repro: jump then fire",
      screenshotAvailable: true,
      page: "https://game.internal/",
    };
    const png = Buffer.from(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/" +
      "5p8AAAAASUVORK5CYII=", "base64");
    const encoded = Buffer.from(JSON.stringify(metadata));
    const envelope = Buffer.alloc(13 + encoded.length + png.length);
    envelope.write("KBF1", 0, "ascii");
    envelope[4] = 1;
    envelope.writeUInt32BE(encoded.length, 5);
    envelope.writeUInt32BE(png.length, 9);
    encoded.copy(envelope, 13);
    png.copy(envelope, 13 + encoded.length);
    response = await fetch(`http://127.0.0.1:${port}/bugfeed`, {
      method: "POST", headers: { "Content-Type": "application/octet-stream" }, body: envelope,
    });
    assert.equal(response.status, 201);
    const { id } = await response.json();
    assert.match(id, /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
    response = await fetch(`http://127.0.0.1:${port}/bugfeed/${id}`);
    assert.equal(response.status, 200);
    assert.equal((await response.json()).notes, metadata.notes);
    response = await fetch(`http://127.0.0.1:${port}/bugfeed/${id}/screenshot.png`);
    assert.equal(response.status, 200);
    assert.deepEqual(Buffer.from(await response.arrayBuffer()), png);

    const noImageMeta = Buffer.from(JSON.stringify({
      reportVersion: 1, notes: "Capture failed", screenshotAvailable: false,
    }));
    const noImage = Buffer.alloc(13 + noImageMeta.length);
    noImage.write("KBF1", 0, "ascii");
    noImage[4] = 1;
    noImage.writeUInt32BE(noImageMeta.length, 5);
    noImageMeta.copy(noImage, 13);
    response = await fetch(`http://127.0.0.1:${port}/bugfeed`, {
      method: "POST", headers: { "Content-Type": "application/octet-stream" }, body: noImage,
    });
    assert.equal(response.status, 201);
    const noImageId = (await response.json()).id;
    assert.equal((await (await fetch(`http://127.0.0.1:${port}/bugfeed/${noImageId}`)).json()).screenshot, null);
    assert.equal((await fetch(`http://127.0.0.1:${port}/bugfeed/${noImageId}/screenshot.png`)).status, 404);

    response = await fetch(`http://127.0.0.1:${port}/bugfeed/not-a-uuid`);
    assert.equal(response.status, 404);
    response = await fetch(`http://127.0.0.1:${port}/bugfeed`, {
      method: "POST", headers: { "Content-Type": "application/octet-stream" }, body: Buffer.from("bad"),
    });
    assert.equal(response.status, 400);
    await stop();
    await start();
    response = await fetch(`http://127.0.0.1:${port}/bugfeed/${id}`);
    assert.equal(response.status, 200, "report survives service restart");
    console.log(`KOOKIE Bugfeed integration smoke passed: id=${id} persisted=${root}`);
  } finally {
    await stop();
    await fs.rm(root, { recursive: true, force: true });
  }
}

main().catch((error) => {
  console.error(error.stack || error.message);
  process.exitCode = 1;
});
