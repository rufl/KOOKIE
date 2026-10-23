#!/usr/bin/env node
"use strict";

const crypto = require("node:crypto");
const fs = require("node:fs/promises");
const http = require("node:http");
const path = require("node:path");

const HOST = "127.0.0.1";
const PORT = Number(process.env.KOOKIE_BUGFEED_PORT || 8767);
const ROOT = path.resolve(process.env.KOOKIE_BUGFEED_DIR ||
  path.join(process.env.HOME || ".", ".local", "state", "kookie", "bugfeed"));
const MAGIC = Buffer.from("KBF1", "ascii");
const HEADER_BYTES = 13;
const MAX_METADATA_BYTES = 64 * 1024;
const MAX_SCREENSHOT_BYTES = 8 * 1024 * 1024;
const MAX_REPORT_BYTES = HEADER_BYTES + MAX_METADATA_BYTES + MAX_SCREENSHOT_BYTES;
const ID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

function send(response, status, contentType, body) {
  response.writeHead(status, {
    "Content-Type": contentType,
    "Content-Length": Buffer.byteLength(body),
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
  });
  response.end(body);
}

async function requestBody(request) {
  const chunks = [];
  let length = 0;
  for await (const chunk of request) {
    length += chunk.length;
    if (length > MAX_REPORT_BYTES) throw Object.assign(new Error("report too large"), { status: 413 });
    chunks.push(chunk);
  }
  return Buffer.concat(chunks, length);
}

function unpackReport(body) {
  if (body.length < HEADER_BYTES || !body.subarray(0, 4).equals(MAGIC) ||
      body[4] !== 1) throw Object.assign(new Error("invalid Bugfeed envelope"), { status: 400 });
  const metadataLength = body.readUInt32BE(5);
  const screenshotLength = body.readUInt32BE(9);
  if (metadataLength < 2 || metadataLength > MAX_METADATA_BYTES ||
      screenshotLength > MAX_SCREENSHOT_BYTES ||
      HEADER_BYTES + metadataLength + screenshotLength !== body.length) {
    throw Object.assign(new Error("invalid Bugfeed lengths"), { status: 400 });
  }
  const metadataBytes = body.subarray(HEADER_BYTES, HEADER_BYTES + metadataLength);
  let metadata;
  try {
    metadata = JSON.parse(metadataBytes.toString("utf8"));
  } catch {
    throw Object.assign(new Error("invalid Bugfeed metadata"), { status: 400 });
  }
  if (!metadata || metadata.reportVersion !== 1 ||
      typeof metadata.notes !== "string" || metadata.notes.length > 4000 ||
      typeof metadata.screenshotAvailable !== "boolean" ||
      metadata.screenshotAvailable !== (screenshotLength > 0)) {
    throw Object.assign(new Error("invalid Bugfeed report fields"), { status: 400 });
  }
  const screenshot = body.subarray(HEADER_BYTES + metadataLength);
  if (screenshotLength > 0 &&
      !screenshot.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))) {
    throw Object.assign(new Error("screenshot must be a PNG"), { status: 400 });
  }
  return { metadata, screenshot };
}

async function storeReport(body) {
  const { metadata, screenshot } = unpackReport(body);
  await fs.mkdir(ROOT, { recursive: true, mode: 0o700 });
  const id = crypto.randomUUID();
  const staging = path.join(ROOT, `.${id}.staging`);
  const target = path.join(ROOT, id);
  await fs.mkdir(staging, { mode: 0o700 });
  try {
    const report = {
      ...metadata,
      reportId: id,
      capturedAt: new Date().toISOString(),
      screenshot: screenshot.length
        ? { file: "screenshot.png", mimeType: "image/png", bytes: screenshot.length }
        : null,
    };
    await fs.writeFile(path.join(staging, "report.json"),
      `${JSON.stringify(report, null, 2)}\n`, { flag: "wx", mode: 0o600 });
    if (screenshot.length) {
      await fs.writeFile(path.join(staging, "screenshot.png"), screenshot,
        { flag: "wx", mode: 0o600 });
    }
    await fs.rename(staging, target);
  } catch (error) {
    await fs.rm(staging, { recursive: true, force: true });
    throw error;
  }
  return id;
}

async function serve(request, response) {
  const url = new URL(request.url, "http://localhost");
  if (request.method === "GET" && url.pathname === "/bugfeed/healthz") {
    send(response, 200, "application/json; charset=utf-8", '{"status":"ok","service":"bugfeed"}\n');
    return;
  }
  if (request.method === "POST" && url.pathname === "/bugfeed") {
    if (request.headers["content-type"] !== "application/octet-stream") {
      send(response, 415, "text/plain; charset=utf-8", "expected application/octet-stream\n");
      return;
    }
    const body = await requestBody(request);
    const id = await storeReport(body);
    send(response, 201, "application/json; charset=utf-8", `${JSON.stringify({ id })}\n`);
    return;
  }
  const match = /^\/bugfeed\/([0-9a-f-]+)(?:\/(screenshot\.png))?$/.exec(url.pathname);
  if (request.method === "GET" && match && ID_PATTERN.test(match[1])) {
    const leaf = match[2] || "report.json";
    const file = path.join(ROOT, match[1], leaf);
    try {
      const data = await fs.readFile(file);
      send(response, 200, leaf.endsWith(".png") ? "image/png" : "application/json; charset=utf-8", data);
    } catch (error) {
      if (error.code === "ENOENT") send(response, 404, "text/plain; charset=utf-8", "report not found\n");
      else throw error;
    }
    return;
  }
  send(response, 404, "text/plain; charset=utf-8", "not found\n");
}

const server = http.createServer((request, response) => {
  serve(request, response).catch((error) => {
    const status = Number.isInteger(error.status) ? error.status : 500;
    send(response, status, "text/plain; charset=utf-8",
      status === 500 ? "bugfeed storage failed\n" : `${error.message}\n`);
  });
});
server.listen(PORT, HOST, () => {
  process.stdout.write(`KOOKIE Bugfeed listening ${HOST}:${server.address().port} storage=${ROOT}\n`);
});
