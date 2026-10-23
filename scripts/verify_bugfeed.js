#!/usr/bin/env node
"use strict";

const assert = require("node:assert/strict");
const { execFileSync, spawn } = require("node:child_process");
const fs = require("node:fs/promises");
const net = require("node:net");
const os = require("node:os");
const path = require("node:path");

const build = path.resolve(__dirname, "build_bugfeed.sh");
let root;
let storageRoot;
let binary;
let child;
let port;
function makeEnvelope(metadata, screenshot = Buffer.alloc(0)) {
  const encoded = Buffer.isBuffer(metadata)
    ? metadata : Buffer.from(JSON.stringify(metadata));
  const body = Buffer.alloc(13 + encoded.length + screenshot.length);
  body.write("KBF1", 0, "ascii");
  body[4] = 1;
  body.writeUInt32BE(encoded.length, 5);
  body.writeUInt32BE(screenshot.length, 9);
  encoded.copy(body, 13);
  screenshot.copy(body, 13 + encoded.length);
  return body;
}
async function start() {
  child = spawn(binary, [], {
    env: {
      ...process.env,
      PATH: "",
      KOOKIE_BUGFEED_PORT: "0",
      KOOKIE_BUGFEED_DIR: storageRoot,
    },
    stdio: ["ignore", "pipe", "pipe"],
  });
  let output = "";
  await new Promise((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error("Bugfeed startup timed out")), 5000);
    const readOutput = (chunk) => {
      output += chunk;
      const match = /listening 127\.0\.0\.1:(\d+)/.exec(output);
      if (match) {
        port = Number(match[1]);
        clearTimeout(timeout);
        resolve();
      }
    };
    child.stdout.on("data", readOutput);
    child.stderr.on("data", readOutput);
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
  storageRoot = path.join(root, "reports");
  binary = path.join(root, "kookie-bugfeed");
  try {
    execFileSync("bash", [build, "--output", binary], { stdio: "inherit" });
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
    const publishedDirectory = path.join(storageRoot, id);
    assert.equal((await fs.stat(storageRoot)).mode & 0o777, 0o700);
    assert.equal((await fs.stat(publishedDirectory)).mode & 0o777, 0o700);
    assert.equal((await fs.stat(path.join(publishedDirectory, "report.json"))).mode & 0o777, 0o600);
    assert.equal((await fs.stat(path.join(publishedDirectory, "screenshot.png"))).mode & 0o777, 0o600);
    assert.deepEqual((await fs.readdir(storageRoot)).sort(), [id]);
    response = await fetch(`http://127.0.0.1:${port}/bugfeed/${id}?from=test`);
    assert.equal(response.status, 200);
    assert.equal((await response.json()).notes, metadata.notes);
    response = await fetch(`http://127.0.0.1:${port}/bugfeed/${id}/screenshot.png?from=test`);
    assert.equal(response.status, 200);
    assert.deepEqual(Buffer.from(await response.arrayBuffer()), png);

    const maximumPng = Buffer.alloc(8 * 1024 * 1024);
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]).copy(maximumPng);
    const maximumMetadata = Buffer.from(JSON.stringify({
      reportVersion: 1, notes: "Maximum-size screenshot", screenshotAvailable: true,
    }));
    const maximumEnvelope = Buffer.alloc(13 + maximumMetadata.length + maximumPng.length);
    maximumEnvelope.write("KBF1", 0, "ascii");
    maximumEnvelope[4] = 1;
    maximumEnvelope.writeUInt32BE(maximumMetadata.length, 5);
    maximumEnvelope.writeUInt32BE(maximumPng.length, 9);
    maximumMetadata.copy(maximumEnvelope, 13);
    maximumPng.copy(maximumEnvelope, 13 + maximumMetadata.length);
    response = await fetch(`http://127.0.0.1:${port}/bugfeed`, {
      method: "POST", headers: { "Content-Type": "application/octet-stream" },
      body: maximumEnvelope,
    });
    assert.equal(response.status, 201, "full 8 MiB screenshot must be accepted");
    const maximumId = (await response.json()).id;
    response = await fetch(`http://127.0.0.1:${port}/bugfeed/${maximumId}/screenshot.png`);
    assert.equal(response.status, 200);
    assert.equal((await response.arrayBuffer()).byteLength, maximumPng.length);

    const oversizedStatus = await new Promise((resolve, reject) => {
      let received = "";
      const socket = net.connect(port, "127.0.0.1");
      const timeout = setTimeout(() => {
        socket.destroy();
        reject(new Error("oversized report rejection timed out"));
      }, 5000);
      socket.once("connect", () => socket.end(
        "POST /bugfeed HTTP/1.1\r\n" +
        "Host: 127.0.0.1\r\n" +
        "Content-Type: application/octet-stream\r\n" +
        "Content-Length: " + (13 + 64 * 1024 + 8 * 1024 * 1024 + 1) + "\r\n" +
        "Connection: close\r\n\r\n",
      ));
      socket.on("data", (chunk) => {
        received += chunk.toString("ascii");
        const match = /^HTTP\/1\.1 (\d+)/.exec(received);
        if (match) {
          clearTimeout(timeout);
          resolve(Number(match[1]));
          socket.destroy();
        }
      });
      socket.once("error", (error) => {
        clearTimeout(timeout);
        reject(error);
      });
    });
    assert.equal(oversizedStatus, 413, "one byte over report limit must be rejected");

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
    const maximumMetadataObject = {
      reportVersion: 1, notes: "", screenshotAvailable: false, padding: "",
    };
    const baseMetadataLength = Buffer.byteLength(JSON.stringify(maximumMetadataObject));
    maximumMetadataObject.padding = "x".repeat(64 * 1024 - baseMetadataLength);
    const maximumMetadataBytes = Buffer.from(JSON.stringify(maximumMetadataObject));
    assert.equal(maximumMetadataBytes.length, 64 * 1024);
    response = await fetch(`http://127.0.0.1:${port}/bugfeed`, {
      method: "POST",
      headers: { "Content-Type": "application/octet-stream" },
      body: makeEnvelope(maximumMetadataBytes),
    });
    assert.equal(response.status, 201, "64 KiB metadata must be accepted");

    maximumMetadataObject.padding += "x";
    const excessiveMetadata = Buffer.from(JSON.stringify(maximumMetadataObject));
    assert.equal(excessiveMetadata.length, 64 * 1024 + 1);
    response = await fetch(`http://127.0.0.1:${port}/bugfeed`, {
      method: "POST",
      headers: { "Content-Type": "application/octet-stream" },
      body: makeEnvelope(excessiveMetadata),
    });
    assert.equal(response.status, 400, "metadata above 64 KiB must be rejected");

    response = await fetch(`http://127.0.0.1:${port}/bugfeed`, {
      method: "POST",
      headers: { "Content-Type": "application/octet-stream" },
      body: makeEnvelope({
        reportVersion: 1,
        notes: "x".repeat(4001),
        screenshotAvailable: false,
      }),
    });
    assert.equal(response.status, 400, "notes above 4000 characters must be rejected");

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
