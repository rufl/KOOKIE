const std = @import("std");
const builtin = @import("builtin");
const is_windows = builtin.os.tag == .windows;
const c = @import("c");
extern "c" fn __errno_location() *c_int;

// The adapter is intentionally only transport/protocol plumbing: it does not
// parse game messages or make simulation decisions. Wire policy and admission
// remain in Kof. Units, limits, and event lifetimes match the C ABI.
const NC = 12;
const NE = 64;
const NR = 8192;
const NF = 1104;
const NO = 65536;
const DEADLINE_NS: i64 = 30_000_000_000;
const Event = struct { kind: i32 = 0, id: i32 = 0, opcode: i32 = 0, len: i32 = 0, data: [NR]u8 = undefined };
const Conn = struct {
    fd: isize = -1,
    used: bool = false,
    dead: bool = false,
    notified: bool = false,
    ws: bool = false,
    id: i32 = 0,
    close_after: bool = false,
    have_key: bool = false,
    key: [24]u8 = undefined,
    input: [NR + 16]u8 = undefined,
    output: [NO]u8 = undefined,
    nin: usize = 0,
    nout: usize = 0,
    sent: usize = 0,
    last_activity_ns: i64 = 0,
};

var mutex: if (builtinWindows()) c.CRITICAL_SECTION else c.pthread_mutex_t = undefined;
var listener: isize = -1;
var connections: [NC]Conn = std.mem.zeroes([NC]Conn);
var queue: [NE]Event = undefined;
var current: Event = .{};
var queue_head: usize = 0;
var queue_tail: usize = 0;
var queue_len: usize = 0;
var running = false;
var opened = false;
var next_id: i32 = 1;
var active_port: i32 = 0;
var worker: if (builtinWindows()) c.HANDLE else c.pthread_t = undefined;
var stage: [NO]u8 = undefined;
var stage_id: i32 = 0;
var stage_len: i32 = 0;
var stage_active = false;
var winsock_started = false;

inline fn builtinWindows() bool { return is_windows; }
fn lock() void { if (builtinWindows()) c.EnterCriticalSection(&mutex) else _ = c.pthread_mutex_lock(&mutex); }
fn unlock() void { if (builtinWindows()) c.LeaveCriticalSection(&mutex) else _ = c.pthread_mutex_unlock(&mutex); }
fn socketClose(fd: isize) void { if (builtinWindows()) _ = c.closesocket(@intCast(fd)) else _ = c.close(@intCast(fd)); }
fn transientError() bool {
    if (builtinWindows()) { const e = c.WSAGetLastError(); return e == c.WSAEWOULDBLOCK or e == c.WSAEINTR; }
    const error_code = __errno_location().*;
    return error_code == c.EAGAIN or error_code == c.EWOULDBLOCK or error_code == c.EINTR;
}
fn nowNs() i64 {
    if (builtinWindows()) {
        var count: c.LARGE_INTEGER = undefined;
        var freq: c.LARGE_INTEGER = undefined;
        if (c.QueryPerformanceCounter(&count) == 0 or c.QueryPerformanceFrequency(&freq) == 0 or freq.QuadPart <= 0) return 0;
        return @intCast(@divTrunc(count.QuadPart, freq.QuadPart) * 1_000_000_000 + @divTrunc(@rem(count.QuadPart, freq.QuadPart) * 1_000_000_000, freq.QuadPart));
    }
    var ts: c.struct_timespec = undefined;
    if (c.clock_gettime(c.CLOCK_MONOTONIC, &ts) != 0) return 0;
    return @as(i64, @intCast(ts.tv_sec)) * 1_000_000_000 + @as(i64, @intCast(ts.tv_nsec));
}
fn emit(kind: i32, id: i32, opcode: i32, data: []const u8) bool {
    if (queue_len == NE or data.len > NR) return false;
    queue[queue_tail] = .{ .kind = kind, .id = id, .opcode = opcode, .len = @intCast(data.len), .data = undefined };
    if (data.len != 0) @memcpy(queue[queue_tail].data[0..data.len], data);
    queue_tail = (queue_tail + 1) % NE;
    queue_len += 1;
    return true;
}
fn locate(id: i32) ?usize {
    for (&connections, 0..) |*conn, i| if (conn.used and !conn.dead and conn.id == id) return i;
    return null;
}
fn drop(conn: *Conn) void {
    if (!conn.used or conn.dead) return;
    socketClose(conn.fd);
    conn.fd = -1;
    conn.dead = true;
    conn.nout = 0;
    conn.sent = 0;
    conn.notified = emit(4, conn.id, 0, &.{});
}
fn appendOutput(conn: *Conn, bytes: []const u8) bool {
    const pending = conn.nout - conn.sent;
    if (bytes.len > NO - pending) return false;
    if (conn.sent != 0 and pending != 0) @memmove(conn.output[0..pending], conn.output[conn.sent..conn.nout]);
    conn.sent = 0;
    conn.nout = pending;
    @memcpy(conn.output[conn.nout .. conn.nout + bytes.len], bytes);
    conn.nout += bytes.len;
    return true;
}
fn eqHeader(p: []const u8, name: []const u8) bool {
    const colon = std.mem.indexOfScalar(u8, p, ':') orelse return false;
    if (colon != name.len) return false;
    for (p[0..colon], name) |a, b| if (std.ascii.toLower(a) != b) return false;
    return true;
}
fn validKey(p: []const u8) bool {
    if (p.len != 24 or p[22] != '=' or p[23] != '=') return false;
    for (p[0..22]) |ch| if (!(std.ascii.isAlphabetic(ch) or std.ascii.isDigit(ch) or ch == '+' or ch == '/')) return false;
    return true;
}
fn captureKey(conn: *Conn, request: []const u8) void {
    conn.have_key = false;
    var lines = std.mem.splitSequence(u8, request, "\r\n");
    _ = lines.next();
    while (lines.next()) |line| {
        if (line.len == 0) break;
        if (!eqHeader(line, "sec-websocket-key")) continue;
        const colon = std.mem.indexOfScalar(u8, line, ':').?;
        const value = std.mem.trim(u8, line[colon + 1 ..], " \t");
        if (validKey(value)) { @memcpy(&conn.key, value); conn.have_key = true; }
        return;
    }
}
fn findHeaderEnd(data: []const u8) ?usize {
    if (data.len < 4) return null;
    for (3..data.len) |i| if (std.mem.eql(u8, data[i - 3 .. i + 1], "\r\n\r\n")) return i + 1;
    return null;
}
fn process(conn: *Conn) void {
    while (!conn.dead) {
        if (!conn.ws) {
            const end = findHeaderEnd(conn.input[0..conn.nin]) orelse { if (conn.nin >= NR) drop(conn); return; };
            const req = conn.input[0..end];
            captureKey(conn, req);
            if (!emit(2, conn.id, 0, req)) { drop(conn); return; }
            const remain = conn.nin - end;
            @memmove(conn.input[0..remain], conn.input[end..conn.nin]);
            conn.nin = remain;
            return;
        }
        if (conn.nin < 2) return;
        const first = conn.input[0];
        const second = conn.input[1];
        const opcode: u8 = first & 15;
        var header: usize = 2;
        var length: usize = second & 127;
        if (first & 0x80 == 0 or first & 0x70 != 0 or second & 0x80 == 0) { drop(conn); return; }
        if (length == 126) {
            if (conn.nin < 4) return;
            length = (@as(usize, conn.input[2]) << 8) | conn.input[3];
            header = 4;
        } else if (length == 127) { drop(conn); return; }
        if (length > NF or (opcode >= 8 and length > 125)) { drop(conn); return; }
        if (conn.nin < header + 4 + length) return;
        var payload: [NF]u8 = undefined;
        for (0..length) |i| payload[i] = conn.input[header + 4 + i] ^ conn.input[header + (i & 3)];
        const consumed = header + 4 + length;
        const remain = conn.nin - consumed;
        @memmove(conn.input[0..remain], conn.input[consumed..conn.nin]);
        conn.nin = remain;
        if (opcode == 8) {
            var reply: [127]u8 = undefined;
            reply[0] = 0x88; reply[1] = @intCast(length);
            @memcpy(reply[2 .. 2 + length], payload[0..length]);
            if (!appendOutput(conn, reply[0 .. 2 + length])) { drop(conn); return; }
            conn.close_after = true;
            return;
        }
        if (opcode == 9 or opcode == 10) {
            if (opcode == 9) {
                var reply: [127]u8 = undefined;
                reply[0] = 0x8a; reply[1] = @intCast(length);
                @memcpy(reply[2 .. 2 + length], payload[0..length]);
                if (!appendOutput(conn, reply[0 .. 2 + length])) { drop(conn); return; }
            }
            continue;
        }
        if (opcode != 1 and opcode != 2) { drop(conn); return; }
        if (!emit(3, conn.id, opcode, payload[0..length])) { drop(conn); return; }
    }
}
fn acceptConnections() void {
    while (true) {
        var addr: c.struct_sockaddr_in = undefined;
        var addr_len: if (builtinWindows()) c_int else c.socklen_t = @sizeOf(c.struct_sockaddr_in);
        const sock = c.accept(@intCast(listener), @ptrCast(&addr), &addr_len);
        if (sock == invalidSocket()) return;
        var slot: ?usize = null;
        for (&connections, 0..) |conn, i| if (!conn.used) { slot = i; break; };
        if (slot == null) { socketClose(@intCast(sock)); continue; }
        const fd: isize = @intCast(sock);
        if (builtinWindows()) { var one: c.u_long = 1; _ = c.ioctlsocket(@intCast(sock), c.FIONBIO, &one); }
        else { const flags = c.fcntl(@intCast(sock), c.F_GETFL, @as(c_int, 0)); if (flags >= 0) _ = c.fcntl(@intCast(sock), c.F_SETFL, flags | c.O_NONBLOCK); }
        var one: c_int = 1;
        _ = c.setsockopt(@intCast(sock), c.IPPROTO_TCP, c.TCP_NODELAY, @ptrCast(&one), @sizeOf(c_int));
        const conn = &connections[slot.?];
        conn.* = .{ .fd = fd, .used = true, .id = next_id, .last_activity_ns = nowNs() };
        next_id +%= 1;
        if (next_id <= 0) next_id = 1;
        if (!emit(1, conn.id, 0, &.{})) drop(conn);
    }
}
fn runLoop(_: ?*anyopaque) callconv(.c) ?*anyopaque {
    while (true) {
        lock();
        if (!running) { unlock(); break; }
        acceptConnections();
        for (&connections) |*conn| {
            if (!conn.used or conn.dead) continue;
            const now = nowNs();
            if (now > conn.last_activity_ns and now - conn.last_activity_ns > DEADLINE_NS) { drop(conn); continue; }
            if (conn.sent < conn.nout) {
                const count: usize = conn.nout - conn.sent;
                const sent = c.send(@intCast(conn.fd), @ptrCast(conn.output[conn.sent..].ptr), count, 0);
                if (sent > 0) { conn.sent += @intCast(sent); conn.last_activity_ns = nowNs(); }
                else if (sent < 0 and !transientError()) drop(conn);
                if (conn.sent == conn.nout) { conn.sent = 0; conn.nout = 0; }
            }
            if (conn.close_after and conn.nout == 0) { drop(conn); continue; }
            if (!conn.dead and !conn.close_after) {
                if (conn.nin == conn.input.len) { drop(conn); continue; }
                const received = c.recv(@intCast(conn.fd), @ptrCast(conn.input[conn.nin..].ptr), @intCast(conn.input.len - conn.nin), 0);
                if (received > 0) { conn.nin += @intCast(received); conn.last_activity_ns = nowNs(); process(conn); }
                else if (received == 0 or !transientError()) drop(conn);
            }
        }
        unlock();
        if (builtinWindows()) c.Sleep(5) else { const ts = c.struct_timespec{ .tv_sec = 0, .tv_nsec = 5_000_000 }; _ = c.nanosleep(&ts, null); }
    }
    return null;
}
fn invalidSocket() if (is_windows) c.SOCKET else c_int { if (is_windows) return c.INVALID_SOCKET; return -1; }
fn startWorker() bool {
    if (builtinWindows()) { worker = c.CreateThread(null, 0, @ptrCast(&runLoop), null, 0, null); return worker != null; }
    return c.pthread_create(&worker, null, runLoop, null) == 0;
}
fn joinWorker() void { if (builtinWindows()) { _ = c.WaitForSingleObject(worker, c.INFINITE); _ = c.CloseHandle(worker); } else _ = c.pthread_join(worker, null); }

export fn kookie_web_server_open(port: c_int) callconv(.c) bool {
    if (opened or port < 1 or port > 65535) return false;
    if (builtinWindows()) {
        if (!winsock_started) { var data: c.WSADATA = undefined; if (c.WSAStartup(0x0202, &data) != 0) return false; winsock_started = true; }
        c.InitializeCriticalSection(&mutex);
    } else _ = c.pthread_mutex_init(&mutex, null);
    const sock = c.socket(c.AF_INET, c.SOCK_STREAM, c.IPPROTO_TCP);
    if (sock == invalidSocket()) { destroyMutex(); return false; }
    var one: c_int = 1;
    _ = c.setsockopt(@intCast(sock), c.SOL_SOCKET, c.SO_REUSEADDR, @ptrCast(&one), @sizeOf(c_int));
    var addr: c.struct_sockaddr_in = std.mem.zeroes(c.struct_sockaddr_in);
    addr.sin_family = c.AF_INET;
    addr.sin_addr.s_addr = c.htonl(c.INADDR_LOOPBACK);
    addr.sin_port = c.htons(@intCast(port));
    if (c.bind(@intCast(sock), @ptrCast(&addr), @sizeOf(c.struct_sockaddr_in)) != 0 or c.listen(@intCast(sock), NC) != 0) { socketClose(@intCast(sock)); destroyMutex(); return false; }
    if (builtinWindows()) { var nonblock: c.u_long = 1; if (c.ioctlsocket(@intCast(sock), c.FIONBIO, &nonblock) != 0) { socketClose(@intCast(sock)); destroyMutex(); return false; } }
    else { const flags = c.fcntl(@intCast(sock), c.F_GETFL, @as(c_int, 0)); if (flags < 0 or c.fcntl(@intCast(sock), c.F_SETFL, flags | c.O_NONBLOCK) < 0) { socketClose(@intCast(sock)); destroyMutex(); return false; } }
    listener = @intCast(sock);
    connections = std.mem.zeroes([NC]Conn);
    queue_head = 0; queue_tail = 0; queue_len = 0; next_id = 1; active_port = port;
    running = true; opened = true;
    if (!startWorker()) { running = false; opened = false; socketClose(listener); listener = -1; destroyMutex(); return false; }
    return true;
}
fn destroyMutex() void { if (builtinWindows()) c.DeleteCriticalSection(&mutex) else _ = c.pthread_mutex_destroy(&mutex); }
export fn kookie_web_server_poll_event(timeout_ms: c_int) callconv(.c) c_int {
    if (!opened or timeout_ms < 0) return -1;
    var elapsed: c_int = 0;
    while (true) {
        lock();
        if (queue_len != 0) {
            current = queue[queue_head]; queue_head = (queue_head + 1) % NE; queue_len -= 1;
            if (current.kind == 4) for (&connections) |*conn| if (conn.used and conn.id == current.id) { conn.* = .{}; break; };
            for (&connections) |*conn| if (conn.used and conn.dead and !conn.notified) { conn.notified = emit(4, conn.id, 0, &.{}); break; };
            unlock(); return current.kind;
        }
        if (!running) { unlock(); return -1; }
        unlock();
        if (elapsed >= timeout_ms) return 0;
        if (builtinWindows()) c.Sleep(5) else { const ts = c.struct_timespec{ .tv_sec = 0, .tv_nsec = 5_000_000 }; _ = c.nanosleep(&ts, null); }
        elapsed += 5;
    }
}
export fn kookie_web_server_event_connection_id() callconv(.c) c_int { return current.id; }
export fn kookie_web_server_event_opcode() callconv(.c) c_int { return current.opcode; }
export fn kookie_web_server_event_payload_length() callconv(.c) c_int { return current.len; }
export fn kookie_web_server_event_payload_byte(index: c_int) callconv(.c) c_int { return if (index >= 0 and index < current.len) current.data[@intCast(index)] else -1; }

// SHA-1 required by RFC6455. Hashing the fixed 60-byte concatenation avoids
// allocation and accepts only validated, fixed-width base64 keys.
fn rotate(x: u32, n: u5) u32 { return (x << n) | (x >> @as(u5, @intCast(32 - @as(u6, n)))); }
fn sha1(input: *const [60]u8) [20]u8 {
    var data: [128]u8 = std.mem.zeroes([128]u8); @memcpy(data[0..60], input); data[60] = 0x80; data[126] = 1; data[127] = 0xe0;
    var h = [_]u32{ 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476, 0xc3d2e1f0 };
    for (0..2) |block| {
        var w: [80]u32 = undefined;
        for (0..16) |i| { const p = block * 64 + i * 4; w[i] = (@as(u32, data[p]) << 24) | (@as(u32, data[p + 1]) << 16) | (@as(u32, data[p + 2]) << 8) | data[p + 3]; }
        for (16..80) |i| w[i] = rotate(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);
        var a = h[0]; var b = h[1]; var cc = h[2]; var d = h[3]; var e = h[4];
        for (0..80) |i| { var f: u32 = undefined; var k: u32 = undefined;
            if (i < 20) { f = (b & cc) | (~b & d); k = 0x5a827999; } else if (i < 40) { f = b ^ cc ^ d; k = 0x6ed9eba1; } else if (i < 60) { f = (b & cc) | (b & d) | (cc & d); k = 0x8f1bbcdc; } else { f = b ^ cc ^ d; k = 0xca62c1d6; }
            const temp = rotate(a, 5) +% f +% e +% k +% w[i]; e = d; d = cc; cc = rotate(b, 30); b = a; a = temp;
        }
        h[0] +%= a; h[1] +%= b; h[2] +%= cc; h[3] +%= d; h[4] +%= e;
    }
    var out: [20]u8 = undefined; for (h, 0..) |v, i| { out[i * 4] = @truncate(v >> 24); out[i * 4 + 1] = @truncate(v >> 16); out[i * 4 + 2] = @truncate(v >> 8); out[i * 4 + 3] = @truncate(v); } return out;
}
fn acceptKey(key: *const [24]u8) [28]u8 {
    const guid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
    var source: [60]u8 = undefined; @memcpy(source[0..24], key); @memcpy(source[24..60], guid);
    const digest = sha1(&source); const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    var out: [28]u8 = undefined;
    for (0..7) |i| {
        const n: usize = i * 3;
        const a: u32 = digest[n];
        const b: u32 = if (n + 1 < 20) digest[n + 1] else 0;
        const cc: u32 = if (n + 2 < 20) digest[n + 2] else 0;
        const x = (a << 16) | (b << 8) | cc;
        out[i * 4] = alphabet[@intCast((x >> 18) & 63)];
        out[i * 4 + 1] = alphabet[@intCast((x >> 12) & 63)];
        out[i * 4 + 2] = if (n + 1 < 20) alphabet[@intCast((x >> 6) & 63)] else '=';
        out[i * 4 + 3] = if (n + 2 < 20) alphabet[@intCast(x & 63)] else '=';
    }
    return out;
}
export fn kookie_web_server_upgrade_websocket(id: c_int) callconv(.c) bool {
    lock(); defer unlock();
    const index = locate(id) orelse return false; const conn = &connections[index];
    if (conn.ws or !conn.have_key) return false;
    const accept = acceptKey(&conn.key);
    var response: [256]u8 = undefined;
    const prefix = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: ";
    const suffix = "\r\nSec-WebSocket-Protocol: kookie.v1\r\n\r\n";
    var n: usize = 0; @memcpy(response[n..][0..prefix.len], prefix); n += prefix.len; @memcpy(response[n..][0..accept.len], &accept); n += accept.len; @memcpy(response[n..][0..suffix.len], suffix); n += suffix.len;
    if (conn.nout != 0 or !appendOutput(conn, response[0..n])) return false;
    conn.ws = true; process(conn); return !conn.dead;
}
export fn kookie_web_server_output_begin(id: c_int, length: c_int) callconv(.c) bool {
    if (length < 0 or length > NO) return false;
    lock(); const ok = locate(id) != null; unlock(); if (!ok) return false;
    stage_id = id; stage_len = length; stage_active = true; return true;
}
export fn kookie_web_server_output_write_byte(index: c_int, value: c_int) callconv(.c) bool {
    if (!stage_active or index < 0 or index >= stage_len or value < 0 or value > 255) return false;
    stage[@intCast(index)] = @intCast(value); return true;
}
export fn kookie_web_server_output_commit() callconv(.c) bool {
    if (!stage_active) return false;
    lock(); const index = locate(stage_id); var ok = false;
    if (index) |i| { ok = appendOutput(&connections[i], stage[0..@intCast(stage_len)]); if (!ok) drop(&connections[i]); }
    unlock(); stage_active = false; return ok;
}
export fn kookie_web_server_close_client(id: c_int) callconv(.c) bool {
    lock(); defer unlock(); const index = locate(id) orelse return false; drop(&connections[index]); return true;
}
export fn kookie_web_server_close_client_after_output(id: c_int) callconv(.c) bool {
    lock(); defer unlock(); const index = locate(id) orelse return false; const conn = &connections[index]; conn.close_after = true; if (conn.nout == 0) drop(conn); return true;
}
export fn kookie_web_server_close() callconv(.c) bool {
    if (!opened) return false;
    lock(); running = false; unlock(); joinWorker(); socketClose(listener); listener = -1;
    for (&connections) |*conn| if (conn.used and !conn.dead) socketClose(conn.fd);
    opened = false; destroyMutex(); return true;
}
export fn kookie_web_server_monotonic_nanoseconds() callconv(.c) i64 { return nowNs(); }
export fn kookie_web_server_port() callconv(.c) c_int {
    if (active_port > 0) return active_port;
    const value = c.getenv("KOOKIE_WEB_PORT") orelse return 8765;
    var parsed: c_long = 0; var end: [*c]u8 = null;
    parsed = c.strtol(value, &end, 10);
    if (end == value or end.* != 0 or parsed < 1 or parsed > 65535) return 8765;
    return @intCast(parsed);
}
export fn kookie_web_server_max_connections() callconv(.c) c_int { return NC; }

// Pure behavioral checks run with `zig build check-web-transport`.
test "RFC6455 accept hash and request/frame bounds" {
    const key: [24]u8 = "dGhlIHNhbXBsZSBub25jZQ==".*;
    const accept = acceptKey(&key);
    try std.testing.expectEqualStrings("s3pPLMBiTxaQ9kYGzzhZRbK+xOo=", &accept);
    try std.testing.expect(validKey(&key));
    try std.testing.expect(!validKey("short"));
    try std.testing.expectEqual(@as(?usize, 9), findHeaderEnd("GET /\r\n\r\n"));
    try std.testing.expectEqual(@as(?usize, null), findHeaderEnd("GET /\r\n"));
}

test "masked client text frame is unmasked and queued once" {
    queue_head = 0;
    queue_tail = 0;
    queue_len = 0;
    var conn = Conn{ .used = true, .ws = true, .id = 17, .nin = 8 };
    const frame = [_]u8{ 0x81, 0x82, 1, 2, 3, 4, 'H' ^ 1, 'i' ^ 2 };
    @memcpy(conn.input[0..frame.len], &frame);
    process(&conn);
    try std.testing.expectEqual(@as(usize, 1), queue_len);
    try std.testing.expectEqual(@as(i32, 3), queue[0].kind);
    try std.testing.expectEqual(@as(i32, 17), queue[0].id);
    try std.testing.expectEqual(@as(i32, 1), queue[0].opcode);
    try std.testing.expectEqualStrings("Hi", queue[0].data[0..2]);
    try std.testing.expectEqual(@as(usize, 0), conn.nin);
}
