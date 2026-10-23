const std = @import("std");
extern "c" fn getenv(name: [*:0]const u8) ?[*:0]u8;

extern "c" fn socket(domain: c_int, kind: c_int, protocol: c_int) c_int;
extern "c" fn setsockopt(fd: c_int, level: c_int, option: c_int, value: *const c_int, length: u32) c_int;
extern "c" fn bind(fd: c_int, address: *const SockAddr, length: u32) c_int;
extern "c" fn listen(fd: c_int, backlog: c_int) c_int;
extern "c" fn accept(fd: c_int, address: ?*SockAddr, length: ?*u32) c_int;
extern "c" fn recv(fd: c_int, buffer: [*]u8, length: usize, flags: c_int) isize;
extern "c" fn send(fd: c_int, buffer: [*]const u8, length: usize, flags: c_int) isize;
extern "c" fn close(fd: c_int) c_int;
extern "c" fn mkdir(path: [*:0]const u8, mode: c_uint) c_int;
extern "c" fn chmod(path: [*:0]const u8, mode: c_uint) c_int;
extern "c" fn open(path: [*:0]const u8, flags: c_int, ...) c_int;
extern "c" fn write(fd: c_int, buffer: [*]const u8, length: usize) isize;
extern "c" fn fsync(fd: c_int) c_int;
extern "c" fn rename(old: [*:0]const u8, new: [*:0]const u8) c_int;
extern "c" fn unlink(path: [*:0]const u8) c_int;
extern "c" fn rmdir(path: [*:0]const u8) c_int;
extern "c" fn getrandom(buffer: [*]u8, length: usize, flags: c_uint) isize;
extern "c" fn time(result: ?*i64) i64;
extern "c" fn gmtime_r(timer: *const i64, result: *Tm) ?*Tm;
extern "c" fn snprintf(buffer: [*]u8, size: usize, format: [*:0]const u8, ...) c_int;

const SockAddr = extern struct { family: u16, port: u16, address: u32, zero: [8]u8 = .{ 0, 0, 0, 0, 0, 0, 0, 0 } };
const Tm = extern struct { sec: c_int, min: c_int, hour: c_int, mday: c_int, mon: c_int, year: c_int, wday: c_int, yday: c_int, isdst: c_int, gmtoff: c_long, zone: ?[*:0]const u8 };
const allocator = std.heap.page_allocator;
const header_limit = 16 * 1024;
const max_metadata = 64 * 1024;
const max_screenshot = 8 * 1024 * 1024;
const max_body = 13 + max_metadata + max_screenshot;
const png_signature = [_]u8{ 137, 80, 78, 71, 13, 10, 26, 10 };
const Obj = std.json.ObjectMap;

pub fn main() !void {
    const port = try envPort();
    const configured_root_value = envString("KOOKIE_BUGFEED_DIR");
    const configured_root = if (configured_root_value != null and configured_root_value.?.len > 0)
        configured_root_value
    else
        null;
    const root = configured_root orelse try std.fmt.allocPrint(allocator, "{s}/.local/state/kookie/bugfeed", .{envString("HOME") orelse "."});
    defer if (configured_root == null) allocator.free(root);
    try mkdirs(root);
    const root_z = try allocator.dupeSentinel(u8, root, 0);
    defer allocator.free(root_z);
    if (chmod(root_z, 0o700) != 0) return error.SetStoragePermissionsFailed;

    const server = socket(2, 1, 0);
    if (server < 0) return error.SocketFailed;
    defer _ = close(server);
    const reuse: c_int = 1;
    _ = setsockopt(server, 1, 2, &reuse, @sizeOf(c_int));
    var addr = SockAddr{ .family = 2, .port = std.mem.nativeToBig(u16, port), .address = std.mem.nativeToBig(u32, 0x7f000001) };
    if (bind(server, &addr, @sizeOf(SockAddr)) != 0 or listen(server, 128) != 0) return error.BindFailed;
    var actual = addr;
    var len: u32 = @sizeOf(SockAddr);
    if (getsockname(server, &actual, &len) != 0) return error.GetBoundAddressFailed;
    std.debug.print("KOOKIE Bugfeed listening 127.0.0.1:{d} storage={s}\n", .{ std.mem.bigToNative(u16, actual.port), root });
    while (true) {
        const client = accept(server, null, null);
        if (client < 0) continue;
        handle(client, root) catch {};
        _ = close(client);
    }
}

extern "c" fn getsockname(fd: c_int, address: *SockAddr, length: *u32) c_int;

fn envString(name: []const u8) ?[]const u8 {
    const env_key = allocator.dupeSentinel(u8, name, 0) catch return null;
    defer allocator.free(env_key);
    const value = getenv(env_key) orelse return null;
    return std.mem.span(value);
}
fn envPort() !u16 {
    const value = envString("KOOKIE_BUGFEED_PORT") orelse return 8767;
    return std.fmt.parseInt(u16, value, 10) catch error.InvalidPort;
}
fn mkdirs(path: []const u8) !void {
    const p = try allocator.dupeSentinel(u8, path, 0);
    defer allocator.free(p);
    for (p[1..], 1..) |c, i| if (c == '/') {
        p[i] = 0;
        try ensureDirectory(p);
        p[i] = '/';
    };
    try ensureDirectory(p);
}
fn ensureDirectory(path: [*:0]u8) !void {
    if (mkdir(path, 0o700) == 0) return;
    const fd = open(path, 0x10000, @as(c_uint, 0));
    if (fd < 0) return error.CreateDirectoryFailed;
    _ = close(fd);
}
fn handle(fd: c_int, root: []const u8) !void {
    const header_buffer = try allocator.alloc(u8, header_limit + 1);
    defer allocator.free(header_buffer);
    var received: usize = 0;
    var body_start: usize = 0;
    var content_len: usize = 0;

    while (true) {
        const remaining = header_buffer.len - received;
        if (remaining == 0) {
            return sendResponse(fd, 400, "text/plain; charset=utf-8", "request headers too large\n");
        }
        const count = recv(fd, header_buffer[received..].ptr, remaining, 0);
        if (count <= 0) return;
        received += @intCast(count);
        if (std.mem.indexOf(u8, header_buffer[0..received], "\r\n\r\n")) |end| {
            body_start = end + 4;
            if (body_start > header_limit) {
                return sendResponse(fd, 400, "text/plain; charset=utf-8", "request headers too large\n");
            }
            const headers = header_buffer[0..end];
            const first_end = std.mem.indexOf(u8, headers, "\r\n") orelse headers.len;
            const line = headers[0..first_end];
            const post = std.mem.startsWith(u8, line, "POST /bugfeed ");
            const health = std.mem.startsWith(u8, line, "GET /bugfeed/healthz ");
            if (!post) {
                if (health) {
                    return sendResponse(
                        fd,
                        200,
                        "application/json; charset=utf-8",
                        "{\"status\":\"ok\",\"service\":\"bugfeed\"}\n",
                    );
                }
                if (std.mem.startsWith(u8, line, "GET /bugfeed/")) {
                    return serveReport(fd, root, line);
                }
                return sendResponse(fd, 404, "text/plain; charset=utf-8", "not found\n");
            }
            if (!headerValueEquals(headers, "content-type:", "application/octet-stream")) {
                return sendResponse(
                    fd,
                    415,
                    "text/plain; charset=utf-8",
                    "expected application/octet-stream\n",
                );
            }
            if (headerExists(headers, "transfer-encoding:")) {
                return sendResponse(fd, 400, "text/plain; charset=utf-8", "content-length required\n");
            }
            content_len = headerNumber(headers, "content-length:") orelse {
                return sendResponse(fd, 400, "text/plain; charset=utf-8", "content-length required\n");
            };
            if (content_len > max_body) {
                return sendResponse(fd, 413, "text/plain; charset=utf-8", "report too large\n");
            }
            break;
        }
        if (received > header_limit) {
            return sendResponse(fd, 400, "text/plain; charset=utf-8", "request headers too large\n");
        }
    }

    const body = try allocator.alloc(u8, content_len);
    defer allocator.free(body);
    const available = received - body_start;
    const copied = @min(content_len, available);
    @memcpy(body[0..copied], header_buffer[body_start .. body_start + copied]);
    var body_received = copied;
    while (body_received < content_len) {
        const count = recv(fd, body[body_received..].ptr, content_len - body_received, 0);
        if (count <= 0) {
            return sendResponse(fd, 400, "text/plain; charset=utf-8", "incomplete request body\n");
        }
        body_received += @intCast(count);
    }

    const id = store(root, body) catch |err| {
        const client_error = err == error.InvalidEnvelope or
            err == error.InvalidMetadata or err == error.InvalidFields or
            err == error.InvalidPng;
        const message = if (err == error.InvalidEnvelope)
            "invalid Bugfeed envelope\n"
        else if (err == error.InvalidMetadata)
            "invalid Bugfeed metadata\n"
        else if (err == error.InvalidFields)
            "invalid Bugfeed report fields\n"
        else if (err == error.InvalidPng)
            "screenshot must be a PNG\n"
        else
            "bugfeed storage failed\n";
        return sendResponse(
            fd,
            if (client_error) 400 else 500,
            "text/plain; charset=utf-8",
            message,
        );
    };
    defer allocator.free(id);
    const reply = try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\"}}\n", .{id});
    defer allocator.free(reply);
    try sendResponse(fd, 201, "application/json; charset=utf-8", reply);
}
fn headerValueEquals(headers: []const u8, label: []const u8, expected: []const u8) bool {
    const value = headerValue(headers, label) orelse return false;
    return std.mem.eql(u8, value, expected);
}
fn headerExists(headers: []const u8, label: []const u8) bool {
    return headerValue(headers, label) != null;
}
fn headerValue(headers: []const u8, label: []const u8) ?[]const u8 {
    var lines = std.mem.splitSequence(u8, headers, "\r\n");
    _ = lines.next();
    while (lines.next()) |line| {
        if (std.ascii.startsWithIgnoreCase(line, label)) return std.mem.trim(u8, line[label.len..], " \t");
    }
    return null;
}
fn headerNumber(headers: []const u8, label: []const u8) ?usize {
    var lines = std.mem.splitSequence(u8, headers, "\r\n");
    _ = lines.next();
    while (lines.next()) |line| if (std.ascii.startsWithIgnoreCase(line, label)) {
        return std.fmt.parseInt(usize, std.mem.trim(u8, line[label.len..], " \t"), 10) catch null;
    };
    return null;
}
fn store(root: []const u8, body: []const u8) ![]u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const report_allocator = arena.allocator();
    if (body.len < 13 or !std.mem.eql(u8, body[0..4], "KBF1") or body[4] != 1) return error.InvalidEnvelope;
    const ml = std.mem.readInt(u32, body[5..9], .big);
    const sl = std.mem.readInt(u32, body[9..13], .big);
    const metadata_len: usize = @intCast(ml);
    const screenshot_len: usize = @intCast(sl);
    if (metadata_len < 2 or metadata_len > max_metadata or screenshot_len > max_screenshot or 13 + metadata_len + screenshot_len != body.len) return error.InvalidEnvelope;
    const meta_end = 13 + metadata_len;
    const metadata = std.json.parseFromSliceLeaky(std.json.Value, report_allocator, body[13..meta_end], .{}) catch return error.InvalidMetadata;
    if (metadata != .object) return error.InvalidFields;
    const version = metadata.object.get("reportVersion") orelse return error.InvalidFields;
    const notes = metadata.object.get("notes") orelse return error.InvalidFields;
    const available = metadata.object.get("screenshotAvailable") orelse return error.InvalidFields;
    if (!isVersionOne(version) or notes != .string or unicodeLength(notes.string) > 4000 or available != .bool or available.bool != (screenshot_len > 0)) return error.InvalidFields;
    const png = body[meta_end..];
    if (screenshot_len > 0 and (png.len < 8 or !std.mem.eql(u8, png[0..8], &png_signature))) return error.InvalidPng;
    var random: [16]u8 = undefined;
    if (getrandom(&random, random.len, 0) != @as(isize, @intCast(random.len))) return error.RandomFailed;
    random[6] = (random[6] & 0x0f) | 0x40;
    random[8] = (random[8] & 0x3f) | 0x80;
    const id = try std.fmt.allocPrint(report_allocator, "{x:0>2}{x:0>2}{x:0>2}{x:0>2}-{x:0>2}{x:0>2}-{x:0>2}{x:0>2}-{x:0>2}{x:0>2}-{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}", .{ random[0], random[1], random[2], random[3], random[4], random[5], random[6], random[7], random[8], random[9], random[10], random[11], random[12], random[13], random[14], random[15] });
    const returned_id = try allocator.dupe(u8, id);
    errdefer allocator.free(returned_id);
    const staging = try std.fmt.allocPrint(report_allocator, "{s}/.{s}.staging", .{ root, id });
    const target = try std.fmt.allocPrint(report_allocator, "{s}/{s}", .{ root, id });
    const staging_z = try report_allocator.dupeSentinel(u8, staging, 0);
    const target_z = try report_allocator.dupeSentinel(u8, target, 0);
    const report_path = try std.fmt.allocPrint(report_allocator, "{s}/report.json", .{staging});
    const shot_path = try std.fmt.allocPrint(report_allocator, "{s}/screenshot.png", .{staging});
    if (mkdir(staging_z, 0o700) != 0) return error.StorageFailed;
    errdefer {
        removePath(report_path);
        removePath(shot_path);
        _ = rmdir(staging_z);
    }
    var obj: Obj = .empty;
    var iter = metadata.object.iterator();
    while (iter.next()) |entry| try obj.put(report_allocator, entry.key_ptr.*, entry.value_ptr.*);
    try obj.put(report_allocator, "reportId", .{ .string = id });
    var now = time(null);
    var tm: Tm = undefined;
    if (gmtime_r(&now, &tm) == null) return error.TimeFailed;
    var captured: [32]u8 = undefined;
    const time_len = snprintf(&captured, captured.len, "%04d-%02d-%02dT%02d:%02d:%02d.000Z", tm.year + 1900, tm.mon + 1, tm.mday, tm.hour, tm.min, tm.sec);
    try obj.put(report_allocator, "capturedAt", .{ .string = captured[0..@intCast(time_len)] });
    if (screenshot_len > 0) {
        var shot = Obj.empty;
        try shot.put(report_allocator, "file", .{ .string = "screenshot.png" });
        try shot.put(report_allocator, "mimeType", .{ .string = "image/png" });
        try shot.put(report_allocator, "bytes", .{ .integer = @intCast(screenshot_len) });
        try obj.put(report_allocator, "screenshot", .{ .object = shot });
    } else try obj.put(report_allocator, "screenshot", .null);
    const json = try std.json.Stringify.valueAlloc(report_allocator, std.json.Value{ .object = obj }, .{ .whitespace = .indent_2 });
    try writePrivate(report_path, json);
    if (screenshot_len > 0) try writePrivate(shot_path, png);
    try syncDirectory(staging);
    if (rename(staging_z, target_z) != 0) return error.StorageFailed;
    try syncDirectory(root);
    return returned_id;
}
fn unicodeLength(s: []const u8) usize {
    var i: usize = 0;
    var count: usize = 0;
    while (i < s.len) {
        const width: usize = std.unicode.utf8ByteSequenceLength(s[i]) catch return std.math.maxInt(usize);
        if (i + width > s.len) return std.math.maxInt(usize);
        const cp = std.unicode.utf8Decode(s[i .. i + width]) catch return std.math.maxInt(usize);
        count += if (cp > 0xffff) @as(usize, 2) else 1;
        i += width;
    }
    return count;
}
fn isVersionOne(value: std.json.Value) bool {
    return switch (value) {
        .integer => |number| number == 1,
        .float => |number| number == 1.0,
        else => false,
    };
}
fn removePath(path: []const u8) void {
    const z = allocator.dupeSentinel(u8, path, 0) catch return;
    defer allocator.free(z);
    _ = unlink(z);
}
fn syncDirectory(path: []const u8) !void {
    const z = try allocator.dupeSentinel(u8, path, 0);
    defer allocator.free(z);
    const fd = open(z, 0x10000, @as(c_uint, 0));
    if (fd < 0) return error.DirectoryOpenFailed;
    defer _ = close(fd);
    if (fsync(fd) != 0) return error.DirectorySyncFailed;
}
fn writePrivate(path: []const u8, data: []const u8) !void {
    const z = try allocator.dupeSentinel(u8, path, 0);
    defer allocator.free(z);
    const fd = open(z, 0xC1 | 0x200, @as(c_uint, 0o600));
    if (fd < 0) return error.FileCreateFailed;
    defer _ = close(fd);
    var offset: usize = 0;
    while (offset < data.len) {
        const n = write(fd, data[offset..].ptr, data.len - offset);
        if (n <= 0) return error.FileWriteFailed;
        offset += @intCast(n);
    }
    if (fsync(fd) != 0) return error.FileSyncFailed;
}
fn serveReport(fd: c_int, root: []const u8, request_line: []const u8) !void {
    const path_start = std.mem.indexOfScalar(u8, request_line, ' ') orelse return sendResponse(fd, 404, "text/plain; charset=utf-8", "not found\n");
    const path_end = std.mem.indexOfScalarPos(u8, request_line, path_start + 1, ' ') orelse return sendResponse(fd, 404, "text/plain; charset=utf-8", "not found\n");
    const target = request_line[path_start + 1 .. path_end];
    const path = target[0 .. std.mem.indexOfScalar(u8, target, '?') orelse target.len];
    const suffix = "/screenshot.png";
    const shot = std.mem.endsWith(u8, path, suffix);
    const id_start: usize = "/bugfeed/".len;
    const id_end = path.len - (if (shot) suffix.len else 0);
    if (!std.mem.startsWith(u8, path, "/bugfeed/") or id_end < id_start or !validUuid(path[id_start..id_end])) return sendResponse(fd, 404, "text/plain; charset=utf-8", "not found\n");
    const leaf = if (shot) "screenshot.png" else "report.json";
    const file = try std.fmt.allocPrint(allocator, "{s}/{s}/{s}", .{ root, path[id_start..id_end], leaf });
    defer allocator.free(file);
    const z = try allocator.dupeSentinel(u8, file, 0);
    defer allocator.free(z);
    const f = open(z, 0, @as(c_uint, 0));
    if (f < 0) return sendResponse(fd, 404, "text/plain; charset=utf-8", "report not found\n");
    defer _ = close(f);
    var data: std.ArrayList(u8) = .empty;
    defer data.deinit(allocator);
    var chunk: [16384]u8 = undefined;
    while (true) {
        const count = readFile(f, &chunk);
        if (count < 0) return sendResponse(fd, 500, "text/plain; charset=utf-8", "bugfeed storage failed\n");
        if (count == 0) break;
        try data.appendSlice(allocator, chunk[0..@intCast(count)]);
    }
    return sendResponse(fd, 200, if (shot) "image/png" else "application/json; charset=utf-8", data.items);
}
extern "c" fn read(fd: c_int, buffer: [*]u8, length: usize) isize;
fn readFile(fd: c_int, buf: []u8) isize {
    return read(fd, buf.ptr, buf.len);
}
fn validUuid(id: []const u8) bool {
    if (id.len != 36 or id[8] != '-' or id[13] != '-' or id[18] != '-' or id[23] != '-') return false;
    for (id, 0..) |c, i| {
        if (i == 8 or i == 13 or i == 18 or i == 23) continue;
        if (!std.ascii.isHex(c) or std.ascii.toLower(c) != c) return false;
    }
    return id[14] == '4' and (id[19] == '8' or id[19] == '9' or id[19] == 'a' or id[19] == 'b');
}
fn sendResponse(fd: c_int, status: u16, content_type: []const u8, body: []const u8) !void {
    const phrase = switch (status) {
        200 => "OK",
        201 => "Created",
        400 => "Bad Request",
        404 => "Not Found",
        413 => "Payload Too Large",
        415 => "Unsupported Media Type",
        else => "Internal Server Error",
    };
    const header = try std.fmt.allocPrint(allocator, "HTTP/1.1 {d} {s}\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nConnection: close\r\n\r\n", .{ status, phrase, content_type, body.len });
    defer allocator.free(header);
    try sendAll(fd, header);
    try sendAll(fd, body);
}
fn sendAll(fd: c_int, bytes: []const u8) !void {
    var offset: usize = 0;
    while (offset < bytes.len) {
        const n = send(fd, bytes[offset..].ptr, bytes.len - offset, 0x4000);
        if (n <= 0) return error.SendFailed;
        offset += @intCast(n);
    }
}
