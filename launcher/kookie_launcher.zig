const builtin = @import("builtin");
const std = @import("std");

const release_public_key_pem = @embedFile("RELEASE_PUBLIC_KEY.pem");

const application = "kookie";
const launcher_version = "0.1.0";
const marker_schema = "kookie.launcher/v1";
const default_api_url = "https://api.github.com/repos/rufl/KOOKIE/releases?per_page=100";
const max_api_bytes: usize = 4 * 1024 * 1024;
const max_manifest_bytes: usize = 64 * 1024;
const max_signature_bytes: usize = 128;
const max_archive_bytes: u64 = 256 * 1024 * 1024;
const max_extracted_bytes: u64 = 1024 * 1024 * 1024;
const max_entry_count: usize = 4096;
const max_marker_bytes: usize = 16 * 1024;
const max_redirects: u16 = 5;
const max_process_output: usize = 128 * 1024;

const Error = error{
    InvalidArguments,
    UnsupportedTarget,
    InvalidUrl,
    InvalidReleaseResponse,
    ReleaseNotFound,
    HttpStatus,
    RedirectLimit,
    InvalidSignature,
    InvalidManifest,
    InvalidArtifact,
    ArtifactSizeMismatch,
    ArtifactSha256Mismatch,
    ArchiveTooLarge,
    ArchiveTooManyEntries,
    ArchiveExtractionTooLarge,
    ArchiveLinksForbidden,
    InvalidArchivePath,
    InvalidArchiveEntryPath,
    InvalidArchiveType,
    EmptyArchive,
    StateDirectoryInvalid,
    MarkerInvalid,
    MissingGame,
    PackageSmokeFailed,
    LaunchFailed,
};

const Options = struct {
    api_url: []const u8 = default_api_url,
    state_dir: ?[]const u8 = null,
    check_only: bool = false,
    no_launch: bool = false,
    offline: bool = false,
    self_test: bool = false,
    package_smoke: bool = false,
};

const Asset = struct {
    name: []const u8,
    browser_download_url: []const u8,
    size: u64 = 0,
};

const Release = struct {
    tag_name: []const u8,
    draft: bool = false,
    published_at: ?[]const u8 = null,
    assets: []Asset,
};

const Manifest = struct {
    schema: []const u8,
    application: []const u8,
    channel: []const u8,
    version: []const u8,
    target: []const u8,
    build_id: []const u8,
    runtime: []const u8,
    archive: []const u8,
    size: u64,
    sha256: []const u8,
    signing: []const u8,
    proof: []const u8,
    public_key_sha256: []const u8,
};

const ReleaseInfo = struct {
    tag: []const u8,
    version: []const u8,
    archive: []const u8,
    archive_url: []const u8,
    archive_size: u64,
    manifest_url: []const u8,
    signature_url: []const u8,
};

const Marker = struct {
    schema: []const u8 = marker_schema,
    version: []const u8,
    build_id: []const u8,
    target: []const u8,
    archive: []const u8,
    sha256: []const u8,
    root: []const u8,
};
const BundledIdentity = struct {
    version: []const u8,
    build_id: []const u8,
};


const DownloadedUpdate = struct {
    manifest: Manifest,
    root: []const u8,
};

fn targetName() []const u8 {
    return switch (builtin.os.tag) {
        .windows => switch (builtin.cpu.arch) {
            .x86_64 => "windows-x86_64",
            else => "",
        },
        .linux => switch (builtin.cpu.arch) {
            .x86_64 => "linux-x86_64",
            else => "",
        },
        else => "",
    };
}

fn archiveSuffix() []const u8 {
    return if (builtin.os.tag == .windows) ".zip" else ".tar.gz";
}

fn gameExecutableName() []const u8 {
    return if (builtin.os.tag == .windows) "kookie.exe" else "kookie";
}

fn launcherExecutableName() []const u8 {
    return if (builtin.os.tag == .windows) "kookie-launcher.exe" else "kookie-launcher";
}

fn isLowerHex(value: []const u8) bool {
    if (value.len == 0) return false;
    for (value) |byte| {
        if (!std.ascii.isHex(byte) or std.ascii.isUpper(byte)) return false;
    }
    return true;
}

fn isSafeToken(value: []const u8) bool {
    if (value.len == 0 or value.len > 160) return false;
    for (value) |byte| {
        if (!(std.ascii.isAlphanumeric(byte) or byte == '.' or byte == '_' or byte == '-')) return false;
    }
    return true;
}

fn normalizeVersion(tag: []const u8) ![]const u8 {
    const value = if (std.mem.startsWith(u8, tag, "v")) tag[1..] else tag;
    _ = std.SemanticVersion.parse(value) catch return error.InvalidManifest;
    return value;
}
fn versionIsNewer(candidate: []const u8, floor: []const u8) bool {
    const candidate_version = std.SemanticVersion.parse(candidate) catch return false;
    const floor_version = std.SemanticVersion.parse(floor) catch return true;
    return candidate_version.order(floor_version) == .gt;
}


fn parseOptions(args: []const []const u8, allocator: std.mem.Allocator) !Options {
    var options = Options{};
    var index: usize = 1;
    while (index < args.len) : (index += 1) {
        const arg = args[index];
        if (std.mem.eql(u8, arg, "--check")) {
            options.check_only = true;
        } else if (std.mem.eql(u8, arg, "--no-launch")) {
            options.no_launch = true;
        } else if (std.mem.eql(u8, arg, "--offline")) {
            options.offline = true;
        } else if (std.mem.eql(u8, arg, "--self-test")) {
            options.self_test = true;
        } else if (std.mem.eql(u8, arg, "--package-smoke")) {
            options.package_smoke = true;
        } else if (std.mem.eql(u8, arg, "--api-url")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.api_url = try allocator.dupe(u8, args[index]);
        } else if (std.mem.eql(u8, arg, "--state-dir")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.state_dir = try allocator.dupe(u8, args[index]);
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            printHelp();
            std.process.exit(0);
        } else if (std.mem.eql(u8, arg, "--version")) {
            std.debug.print("KOOKIE launcher {s} ({s})\n", .{ launcher_version, targetName() });
            std.process.exit(0);
        } else {
            return error.InvalidArguments;
        }
    }
    return options;
}

fn printHelp() void {
    std.debug.print(
        "KOOKIE launcher {s}\n\n" ++
            "Fetches the newest published GitHub release, verifies its signed manifest,\n" ++
            "stages it atomically, runs package smoke, and launches the game.\n\n" ++
            "Usage: {s} [--check] [--no-launch] [--offline] [--state-dir PATH]\n" ++
            "       {s} --self-test | --package-smoke\n",
        .{ launcher_version, launcherExecutableName(), launcherExecutableName() },
    );
}

fn privatePermissions() std.Io.File.Permissions {
    return if (@hasDecl(std.Io.File.Permissions, "fromMode"))
        std.Io.File.Permissions.fromMode(0o700)
    else
        .default_file;
}

fn privateFilePermissions() std.Io.File.Permissions {
    return if (@hasDecl(std.Io.File.Permissions, "fromMode"))
        std.Io.File.Permissions.fromMode(0o600)
    else
        .default_file;
}

fn ensurePrivateDirectory(io: std.Io, path: []const u8) !void {
    const existing = std.Io.Dir.cwd().statFile(io, path, .{ .follow_symlinks = false }) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    if (existing) |stat| {
        if (stat.kind != .directory) return error.StateDirectoryInvalid;
        if (@hasDecl(std.Io.File.Permissions, "fromMode") and (@intFromEnum(stat.permissions) & 0o077) != 0) return error.StateDirectoryInvalid;
        return;
    }
    _ = try std.Io.Dir.cwd().createDirPathStatus(io, path, privatePermissions());
}

fn uriHost(uri: std.Uri) ![]const u8 {
    const component = uri.host orelse return error.InvalidUrl;
    return switch (component) {
        .raw => |value| value,
        .percent_encoded => |value| value,
    };
}

fn validateUrl(url: []const u8) !void {
    if (url.len == 0 or url.len > 2048 or std.mem.indexOfAny(u8, url, "\r\n\t ") != null) return error.InvalidUrl;
    const uri = std.Uri.parse(url) catch return error.InvalidUrl;
    if (uri.user != null or uri.fragment != null) return error.InvalidUrl;
    if (std.ascii.eqlIgnoreCase(uri.scheme, "https")) return;
    if (std.ascii.eqlIgnoreCase(uri.scheme, "http")) {
        const host = try uriHost(uri);
        if (std.ascii.eqlIgnoreCase(host, "localhost") or std.mem.eql(u8, host, "127.0.0.1")) return;
    }
    return error.InvalidUrl;
}

fn validateGithubUrl(url: []const u8) !void {
    try validateUrl(url);
    const uri = std.Uri.parse(url) catch return error.InvalidUrl;
    const host = try uriHost(uri);
    if (!std.ascii.eqlIgnoreCase(host, "github.com") and
        !std.ascii.eqlIgnoreCase(host, "api.github.com") and
        !std.ascii.eqlIgnoreCase(host, "objects.githubusercontent.com") and
        !std.ascii.eqlIgnoreCase(host, "release-assets.githubusercontent.com") and
        !std.ascii.eqlIgnoreCase(host, "localhost") and
        !std.mem.eql(u8, host, "127.0.0.1")) return error.InvalidUrl;
}

fn duplicateRedirectUrl(allocator: std.mem.Allocator, location: []const u8) ![]u8 {
    const next = try allocator.dupe(u8, location);
    errdefer allocator.free(next);
    try validateGithubUrl(next);
    return next;
}

fn responseBytes(
    allocator: std.mem.Allocator,
    io: std.Io,
    url: []const u8,
    limit: usize,
) ![]u8 {
    var current_url = try allocator.dupe(u8, url);
    defer allocator.free(current_url);
    var client: std.http.Client = .{ .allocator = allocator, .io = io };
    defer client.deinit();
    const extra_headers = [_]std.http.Header{
        .{ .name = "Accept", .value = "application/vnd.github+json" },
    };
    var redirects: u16 = 0;
    while (true) {
        try validateGithubUrl(current_url);
        const uri = std.Uri.parse(current_url) catch return error.InvalidUrl;
        var request = try client.request(.GET, uri, .{
            .redirect_behavior = .unhandled,
            .headers = .{ .user_agent = .{ .override = "KOOKIE-Launcher/0.1" }, .accept_encoding = .omit },
            .extra_headers = &extra_headers,
        });
        request.sendBodiless() catch |err| {
            request.deinit();
            return err;
        };
        var redirect_buffer: [2048]u8 = undefined;
        var response = request.receiveHead(&redirect_buffer) catch |err| {
            request.deinit();
            return err;
        };
        if (response.head.status.class() == .redirect) {
            if (redirects >= max_redirects) {
                request.deinit();
                return error.RedirectLimit;
            }
            const next = duplicateRedirectUrl(allocator, response.head.location orelse {
                request.deinit();
                return error.InvalidUrl;
            }) catch |err| {
                request.deinit();
                return err;
            };
            request.deinit();
            allocator.free(current_url);
            current_url = next;
            redirects += 1;
            continue;
        }
        defer request.deinit();
        if (response.head.status != .ok) return error.HttpStatus;
        if (response.head.content_length) |length| if (length > limit) return error.ResponseTooLarge;
        var buffer: [64 * 1024]u8 = undefined;
        return response.reader(&buffer).allocRemaining(allocator, .limited(limit + 1));
    }
}

fn downloadToFile(
    allocator: std.mem.Allocator,
    io: std.Io,
    url: []const u8,
    path: []const u8,
    expected_size: u64,
    expected_sha256: []const u8,
) !void {
    try validateGithubUrl(url);
    if (expected_size == 0 or expected_size > max_archive_bytes or !isLowerHex(expected_sha256) or expected_sha256.len != 64) return error.InvalidArtifact;
    var current_url = try allocator.dupe(u8, url);
    defer allocator.free(current_url);
    var client: std.http.Client = .{ .allocator = allocator, .io = io };
    defer client.deinit();
    const extra_headers = [_]std.http.Header{
        .{ .name = "Accept", .value = "application/octet-stream" },
    };
    var redirects: u16 = 0;
    while (true) {
        try validateGithubUrl(current_url);
        const uri = std.Uri.parse(current_url) catch return error.InvalidUrl;
        var request = try client.request(.GET, uri, .{
            .redirect_behavior = .unhandled,
            .headers = .{ .user_agent = .{ .override = "KOOKIE-Launcher/0.1" }, .accept_encoding = .omit },
            .extra_headers = &extra_headers,
        });
        request.sendBodiless() catch |err| {
            request.deinit();
            return err;
        };
        var redirect_buffer: [2048]u8 = undefined;
        var response = request.receiveHead(&redirect_buffer) catch |err| {
            request.deinit();
            return err;
        };
        if (response.head.status.class() == .redirect) {
            if (redirects >= max_redirects) {
                request.deinit();
                return error.RedirectLimit;
            }
            const next = duplicateRedirectUrl(allocator, response.head.location orelse {
                request.deinit();
                return error.InvalidUrl;
            }) catch |err| {
                request.deinit();
                return err;
            };
            request.deinit();
            allocator.free(current_url);
            current_url = next;
            redirects += 1;
            continue;
        }
        defer request.deinit();
        if (response.head.status != .ok) return error.HttpStatus;
        if (response.head.content_length) |length| if (length != expected_size) return error.ArtifactSizeMismatch;

        std.Io.Dir.cwd().deleteFile(io, path) catch |err| if (err != error.FileNotFound) return err;
        var file = try std.Io.Dir.cwd().createFile(io, path, .{ .exclusive = true, .permissions = privateFilePermissions() });
        errdefer {
            file.close(io);
            std.Io.Dir.cwd().deleteFile(io, path) catch {};
        }
        defer file.close(io);
        var writer_buffer: [64 * 1024]u8 = undefined;
        var writer = file.writer(io, &writer_buffer);
        var reader_buffer: [64 * 1024]u8 = undefined;
        const reader = response.reader(&reader_buffer);
        var chunk: [64 * 1024]u8 = undefined;
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        var total: u64 = 0;
        while (true) {
            const amount = try reader.readSliceShort(&chunk);
            if (amount == 0) break;
            total = std.math.add(u64, total, amount) catch return error.ArtifactSizeMismatch;
            if (total > expected_size or total > max_archive_bytes) return error.ArtifactSizeMismatch;
            hasher.update(chunk[0..amount]);
            try writer.interface.writeAll(chunk[0..amount]);
        }
        if (total != expected_size) return error.ArtifactSizeMismatch;
        try writer.end();
        var digest: [32]u8 = undefined;
        hasher.final(&digest);
        var hex: [64]u8 = undefined;
        _ = std.fmt.bufPrint(&hex, "{x}", .{digest}) catch unreachable;
        if (!std.mem.eql(u8, &hex, expected_sha256)) return error.ArtifactSha256Mismatch;
        return;
    }
}


fn assetByName(release: Release, name: []const u8) ?Asset {
    for (release.assets) |asset| {
        if (std.mem.eql(u8, asset.name, name)) return asset;
    }
    return null;
}

fn latestRelease(allocator: std.mem.Allocator, io: std.Io, api_url: []const u8) !ReleaseInfo {
    try validateGithubUrl(api_url);
    const body = try responseBytes(allocator, io, api_url, max_api_bytes);
    const releases = std.json.parseFromSliceLeaky([]Release, allocator, body, .{ .ignore_unknown_fields = true }) catch return error.InvalidReleaseResponse;
    const target = targetName();
    if (target.len == 0) return error.UnsupportedTarget;
    var selected: ?ReleaseInfo = null;
    var selected_published: []const u8 = "";
    for (releases) |release| {
        if (release.draft) continue;
        const version = normalizeVersion(release.tag_name) catch continue;
        if (!isSafeToken(version)) continue;
        const archive_name = std.fmt.allocPrint(allocator, "kookie-{s}-{s}{s}", .{ version, target, archiveSuffix() }) catch continue;
        const manifest_name = std.fmt.allocPrint(allocator, "kookie-{s}-{s}.json", .{ version, target }) catch continue;
        const signature_name = std.fmt.allocPrint(allocator, "{s}.sig", .{manifest_name}) catch continue;
        const archive_asset = assetByName(release, archive_name) orelse continue;
        const manifest_asset = assetByName(release, manifest_name) orelse continue;
        const signature_asset = assetByName(release, signature_name) orelse continue;
        if (archive_asset.size == 0 or archive_asset.size > max_archive_bytes) continue;
        validateGithubUrl(archive_asset.browser_download_url) catch continue;
        validateGithubUrl(manifest_asset.browser_download_url) catch continue;
        validateGithubUrl(signature_asset.browser_download_url) catch continue;
        const published = release.published_at orelse "";
        if (selected != null and std.mem.order(u8, published, selected_published) != .gt) continue;
        selected = .{
            .tag = release.tag_name,
            .version = version,
            .archive = archive_name,
            .archive_url = archive_asset.browser_download_url,
            .archive_size = archive_asset.size,
            .manifest_url = manifest_asset.browser_download_url,
            .signature_url = signature_asset.browser_download_url,
        };
        selected_published = published;
    }
    return selected orelse error.ReleaseNotFound;
}

fn decodePublicKey() !std.crypto.sign.Ed25519.PublicKey {
    const begin = "-----BEGIN PUBLIC KEY-----";
    const end = "-----END PUBLIC KEY-----";
    const begin_index = std.mem.indexOf(u8, release_public_key_pem, begin) orelse return error.InvalidSignature;
    const payload_start = begin_index + begin.len;
    const end_index = std.mem.indexOfPos(u8, release_public_key_pem, payload_start, end) orelse return error.InvalidSignature;
    var encoded: [128]u8 = undefined;
    var encoded_len: usize = 0;
    for (release_public_key_pem[payload_start..end_index]) |byte| {
        if (std.ascii.isWhitespace(byte)) continue;
        if (encoded_len >= encoded.len) return error.InvalidSignature;
        encoded[encoded_len] = byte;
        encoded_len += 1;
    }
    const encoded_slice = encoded[0..encoded_len];
    const decoded_size = std.base64.standard.Decoder.calcSizeForSlice(encoded_slice) catch return error.InvalidSignature;
    if (decoded_size != 44) return error.InvalidSignature;
    var der: [44]u8 = undefined;
    std.base64.standard.Decoder.decode(&der, encoded_slice) catch return error.InvalidSignature;
    const prefix = [_]u8{ 0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x70, 0x03, 0x21, 0x00 };
    if (!std.mem.eql(u8, der[0..prefix.len], &prefix)) return error.InvalidSignature;
    return std.crypto.sign.Ed25519.PublicKey.fromBytes(der[prefix.len..].*);
}

fn publicKeySha256() ![64]u8 {
    const begin = "-----BEGIN PUBLIC KEY-----";
    const end = "-----END PUBLIC KEY-----";
    const begin_index = std.mem.indexOf(u8, release_public_key_pem, begin) orelse return error.InvalidSignature;
    const payload_start = begin_index + begin.len;
    const end_index = std.mem.indexOfPos(u8, release_public_key_pem, payload_start, end) orelse return error.InvalidSignature;
    var encoded: [128]u8 = undefined;
    var encoded_len: usize = 0;
    for (release_public_key_pem[payload_start..end_index]) |byte| {
        if (std.ascii.isWhitespace(byte)) continue;
        if (encoded_len >= encoded.len) return error.InvalidSignature;
        encoded[encoded_len] = byte;
        encoded_len += 1;
    }
    const encoded_slice = encoded[0..encoded_len];
    const decoded_size = std.base64.standard.Decoder.calcSizeForSlice(encoded_slice) catch return error.InvalidSignature;
    if (decoded_size != 44) return error.InvalidSignature;
    var der: [44]u8 = undefined;
    std.base64.standard.Decoder.decode(&der, encoded_slice) catch return error.InvalidSignature;
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&der, &digest, .{});
    var result: [64]u8 = undefined;
    _ = std.fmt.bufPrint(&result, "{x}", .{digest}) catch unreachable;
    return result;
}

fn verifyManifest(allocator: std.mem.Allocator, manifest_bytes: []const u8, signature_bytes: []const u8) !Manifest {
    if (signature_bytes.len != 64) return error.InvalidSignature;
    const public_key = try decodePublicKey();
    var signature_raw: [64]u8 = undefined;
    @memcpy(&signature_raw, signature_bytes);
    const signature = std.crypto.sign.Ed25519.Signature.fromBytes(signature_raw);
    signature.verify(manifest_bytes, public_key) catch return error.InvalidSignature;
    const manifest = std.json.parseFromSliceLeaky(Manifest, allocator, manifest_bytes, .{ .ignore_unknown_fields = true }) catch return error.InvalidManifest;
    if (!std.mem.eql(u8, manifest.schema, "kookie.package-provenance/v2") or
        !std.mem.eql(u8, manifest.application, application) or
        !std.mem.eql(u8, manifest.target, targetName()) or
        !std.mem.eql(u8, manifest.runtime, "presentation") or
        !std.mem.eql(u8, manifest.channel, "dogfood") or
        !std.mem.eql(u8, manifest.signing, "ed25519") or
        !std.mem.eql(u8, manifest.proof, "ed25519-signature-set") or
        !isSafeToken(manifest.version) or
        !isSafeToken(manifest.build_id) or
        !isLowerHex(manifest.sha256) or
        manifest.sha256.len != 64 or
        manifest.size == 0 or manifest.size > max_archive_bytes or
        !std.mem.eql(u8, manifest.public_key_sha256, &(try publicKeySha256()))) return error.InvalidManifest;
    return manifest;
}

fn readMarker(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !?Marker {
    const stat = std.Io.Dir.cwd().statFile(io, path, .{ .follow_symlinks = false }) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return error.MarkerInvalid,
    };
    if (stat.kind != .file) return error.MarkerInvalid;
    const bytes = std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(max_marker_bytes + 1)) catch return error.MarkerInvalid;
    if (bytes.len > max_marker_bytes) return error.MarkerInvalid;
    const marker = std.json.parseFromSliceLeaky(Marker, allocator, bytes, .{ .ignore_unknown_fields = false }) catch return error.MarkerInvalid;
    if (!std.mem.eql(u8, marker.schema, marker_schema) or
        !std.mem.eql(u8, marker.target, targetName()) or
        !isSafeToken(marker.version) or !isSafeToken(marker.build_id) or
        !isSafeToken(marker.archive) or !isLowerHex(marker.sha256) or marker.sha256.len != 64 or
        marker.root.len == 0 or std.mem.indexOf(u8, marker.root, "..") != null) return error.MarkerInvalid;
    return marker;
}

fn writeMarker(allocator: std.mem.Allocator, io: std.Io, path: []const u8, marker: Marker) !void {
    const bytes = try std.json.Stringify.valueAlloc(allocator, marker, .{});
    defer allocator.free(bytes);
    if (bytes.len > max_marker_bytes) return error.MarkerInvalid;
    var atomic = try std.Io.Dir.cwd().createFileAtomic(io, path, .{ .make_path = true, .replace = true, .permissions = privateFilePermissions() });
    defer atomic.deinit(io);
    try atomic.file.writeStreamingAll(io, bytes);
    try atomic.replace(io);
}

fn rootIsUsable(io: std.Io, root: []const u8) bool {
    const stat = std.Io.Dir.cwd().statFile(io, root, .{ .follow_symlinks = false }) catch return false;
    if (stat.kind != .directory) return false;
    const executable = std.fs.path.join(std.heap.page_allocator, &.{ root, gameExecutableName() }) catch return false;
    defer std.heap.page_allocator.free(executable);
    const game_stat = std.Io.Dir.cwd().statFile(io, executable, .{ .follow_symlinks = false }) catch return false;
    return game_stat.kind == .file;
}

fn markerPath(allocator: std.mem.Allocator, state_dir: []const u8, name: []const u8) ![]const u8 {
    return std.fs.path.join(allocator, &.{ state_dir, name });
}

fn rootSegment(path: []const u8) []const u8 {
    const trimmed = std.mem.trimEnd(u8, path, "/");
    const end = std.mem.indexOfScalar(u8, trimmed, '/') orelse trimmed.len;
    return trimmed[0..end];
}

fn validateArchiveEntryPath(path: []const u8) !void {
    if (path.len == 0 or path.len > std.fs.max_path_bytes or path[0] == '/' or
        std.mem.indexOfScalar(u8, path, '\\') != null or std.mem.indexOfScalar(u8, path, ':') != null or
        std.mem.indexOf(u8, path, "//") != null) return error.InvalidArchiveEntryPath;
    for (path) |byte| if (byte < 0x20 or byte == 0x7f or byte == 0) return error.InvalidArchiveEntryPath;
    const trimmed = std.mem.trimEnd(u8, path, "/");
    if (trimmed.len == 0) return error.InvalidArchiveEntryPath;
    var parts = std.mem.splitScalar(u8, trimmed, '/');
    while (parts.next()) |part| {
        if (std.mem.eql(u8, part, ".") or std.mem.eql(u8, part, "..")) return error.InvalidArchiveEntryPath;
    }
}

fn validateExtractionBounds(entries: usize, total: u64, entry_size: u64) !void {
    if (entries > max_entry_count or entry_size > max_extracted_bytes) return error.ArchiveExtractionTooLarge;
    const next = std.math.add(u64, total, entry_size) catch return error.ArchiveExtractionTooLarge;
    if (next > max_extracted_bytes) return error.ArchiveExtractionTooLarge;
}

fn isZipSymlink(external_attributes: u32) bool {
    const mode: u16 = @intCast(external_attributes >> 16);
    return (mode & 0xf000) == 0xa000;
}

fn requireRegularFile(io: std.Io, path: []const u8) !void {
    const stat = std.Io.Dir.cwd().statFile(io, path, .{ .follow_symlinks = false }) catch return error.InvalidArchivePath;
    if (stat.kind != .file or stat.size > max_archive_bytes) return error.InvalidArchivePath;
}

fn preflightZip(allocator: std.mem.Allocator, io: std.Io, archive_path: []const u8) ![]const u8 {
    try requireRegularFile(io, archive_path);
    var archive = try std.Io.Dir.cwd().openFile(io, archive_path, .{});
    defer archive.close(io);
    var read_buffer: [64 * 1024]u8 = undefined;
    var reader = archive.reader(io, &read_buffer);
    var iterator = try std.zip.Iterator.init(&reader);
    var entries: usize = 0;
    var total: u64 = 0;
    var root: ?[]const u8 = null;
    var central: [@sizeOf(std.zip.CentralDirectoryFileHeader)]u8 = undefined;
    var name_buf: [std.fs.max_path_bytes]u8 = undefined;
    while (try iterator.next()) |entry| {
        entries += 1;
        try validateExtractionBounds(entries, total, entry.uncompressed_size);
        if (entry.filename_len == 0 or @as(usize, @intCast(entry.filename_len)) > name_buf.len) return error.InvalidArchiveEntryPath;
        const central_offset = entry.header_zip_offset;
        if (try archive.readPositionalAll(io, &central, central_offset) != central.len) return error.InvalidArchiveType;
        const name_len = std.mem.readInt(u16, central[28..30], .little);
        if (name_len != entry.filename_len) return error.InvalidArchiveType;
        if (isZipSymlink(std.mem.readInt(u32, central[38..42], .little))) return error.ArchiveLinksForbidden;
        if (try archive.readPositionalAll(io, name_buf[0..name_len], central_offset + central.len) != name_len) return error.InvalidArchiveType;
        const name = name_buf[0..name_len];
        try validateArchiveEntryPath(name);
        total = std.math.add(u64, total, entry.uncompressed_size) catch return error.ArchiveExtractionTooLarge;
        const candidate = rootSegment(name);
        if (candidate.len == 0) return error.InvalidArchiveEntryPath;
        if (root) |expected| {
            if (!std.mem.eql(u8, expected, candidate)) return error.InvalidArchiveEntryPath;
        } else {
            root = try allocator.dupe(u8, candidate);
        }
    }
    if (entries == 0 or root == null) return error.EmptyArchive;
    return root.?;
}

fn extractZip(allocator: std.mem.Allocator, io: std.Io, archive_path: []const u8, destination: []const u8) ![]const u8 {
    const root = try preflightZip(allocator, io, archive_path);
    errdefer allocator.free(root);
    var archive = try std.Io.Dir.cwd().openFile(io, archive_path, .{});
    defer archive.close(io);
    var read_buffer: [64 * 1024]u8 = undefined;
    var reader = archive.reader(io, &read_buffer);
    var destination_dir = try std.Io.Dir.cwd().openDir(io, destination, .{});
    defer destination_dir.close(io);
    std.zip.extract(destination_dir, &reader, .{}) catch |err| return err;
    return root;
}

fn preflightTarGz(allocator: std.mem.Allocator, io: std.Io, archive_path: []const u8) ![]const u8 {
    try requireRegularFile(io, archive_path);
    var archive = try std.Io.Dir.cwd().openFile(io, archive_path, .{});
    defer archive.close(io);
    var read_buffer: [64 * 1024]u8 = undefined;
    var file_reader = archive.reader(io, &read_buffer);
    var window: [std.compress.flate.max_window_len]u8 = undefined;
    var decompressor: std.compress.flate.Decompress = .init(&file_reader.interface, .gzip, &window);
    var limited_buffer: [64 * 1024]u8 = undefined;
    var limited = decompressor.reader.limited(.limited(max_extracted_bytes + 16 * 1024 * 1024), &limited_buffer);
    var name_buffer: [std.fs.max_path_bytes]u8 = undefined;
    var link_buffer: [std.fs.max_path_bytes]u8 = undefined;
    var iterator: std.tar.Iterator = .init(&limited.interface, .{ .file_name_buffer = &name_buffer, .link_name_buffer = &link_buffer });
    var entries: usize = 0;
    var total: u64 = 0;
    var root: ?[]const u8 = null;
    while (try iterator.next()) |entry| {
        entries += 1;
        try validateExtractionBounds(entries, total, entry.size);
        if (entry.kind == .sym_link) return error.ArchiveLinksForbidden;
        try validateArchiveEntryPath(entry.name);
        total = std.math.add(u64, total, entry.size) catch return error.ArchiveExtractionTooLarge;
        const candidate = rootSegment(entry.name);
        if (candidate.len == 0) return error.InvalidArchiveEntryPath;
        if (root) |expected| {
            if (!std.mem.eql(u8, expected, candidate)) return error.InvalidArchiveEntryPath;
        } else {
            root = try allocator.dupe(u8, candidate);
        }
    }
    if (entries == 0 or root == null) return error.EmptyArchive;
    return root.?;
}

fn extractTarGz(allocator: std.mem.Allocator, io: std.Io, archive_path: []const u8, destination: []const u8) ![]const u8 {
    const root = try preflightTarGz(allocator, io, archive_path);
    errdefer allocator.free(root);
    var archive = try std.Io.Dir.cwd().openFile(io, archive_path, .{});
    defer archive.close(io);
    var read_buffer: [64 * 1024]u8 = undefined;
    var file_reader = archive.reader(io, &read_buffer);
    var window: [std.compress.flate.max_window_len]u8 = undefined;
    var decompressor: std.compress.flate.Decompress = .init(&file_reader.interface, .gzip, &window);
    var limited_buffer: [64 * 1024]u8 = undefined;
    var limited = decompressor.reader.limited(.limited(max_extracted_bytes + 16 * 1024 * 1024), &limited_buffer);
    var destination_dir = try std.Io.Dir.cwd().openDir(io, destination, .{});
    defer destination_dir.close(io);
    try std.tar.extract(io, destination_dir, &limited.interface, .{ .mode_mode = .executable_bit_only });
    return root;
}

fn extractArchive(allocator: std.mem.Allocator, io: std.Io, archive_path: []const u8, target: []const u8, destination: []const u8) ![]const u8 {
    return if (std.mem.startsWith(u8, target, "windows-"))
        extractZip(allocator, io, archive_path, destination)
    else
        extractTarGz(allocator, io, archive_path, destination);
}

fn expectedRootName(archive: []const u8) ![]const u8 {
    if (std.mem.endsWith(u8, archive, ".tar.gz")) return archive[0 .. archive.len - 7];
    if (std.mem.endsWith(u8, archive, ".zip")) return archive[0 .. archive.len - 4];
    return error.InvalidArchiveType;
}

fn runPackageSmoke(allocator: std.mem.Allocator, io: std.Io, root: []const u8) !void {
    if (!rootIsUsable(io, root)) return error.MissingGame;
    const executable = try std.fs.path.join(allocator, &.{ root, gameExecutableName() });
    defer allocator.free(executable);
    const result = try std.process.run(allocator, io, .{
        .argv = &.{ executable, "--package-smoke" },
        .cwd = .{ .path = root },
        .stdout_limit = .limited(max_process_output),
        .stderr_limit = .limited(max_process_output),
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    switch (result.term) {
        .exited => |code| if (code != 0) return error.PackageSmokeFailed,
        else => return error.PackageSmokeFailed,
    }
}

fn selfExecutableDirectory(allocator: std.mem.Allocator, io: std.Io, args: []const []const u8) ![]const u8 {
    if (args.len == 0) return error.LaunchFailed;
    const executable = std.Io.Dir.cwd().realPathFileAlloc(io, args[0], allocator) catch return error.LaunchFailed;
    const directory = std.fs.path.dirname(executable) orelse {
        allocator.free(executable);
        return error.LaunchFailed;
    };
    const result = allocator.dupe(u8, directory) catch |err| {
        allocator.free(executable);
        return err;
    };
    allocator.free(executable);
    return result;
}
fn bundledIdentity(allocator: std.mem.Allocator, io: std.Io, args: []const []const u8) !?BundledIdentity {
    const root = try selfExecutableDirectory(allocator, io, args);
    defer allocator.free(root);
    const path = try std.fs.path.join(allocator, &.{ root, "PROVENANCE.txt" });
    defer allocator.free(path);
    const bytes = std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(64 * 1024)) catch return null;
    var version: ?[]const u8 = null;
    var build_id: ?[]const u8 = null;
    var lines = std.mem.splitScalar(u8, bytes, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trimEnd(u8, raw_line, "\r");
        if (std.mem.startsWith(u8, line, "version=")) {
            if (version != null) return null;
            const value = line["version=".len..];
            if (!isSafeToken(value)) return null;
            _ = normalizeVersion(value) catch return null;
            version = value;
        } else if (std.mem.startsWith(u8, line, "build_id=")) {
            if (build_id != null) return null;
            const value = line["build_id=".len..];
            if (!isSafeToken(value)) return null;
            build_id = value;
        }
    }
    if (version == null or build_id == null) return null;
    return .{ .version = version.?, .build_id = build_id.? };
}


fn windowsDogfoodStateDirectory(allocator: std.mem.Allocator, environ: *const std.process.Environ.Map) !?[]const u8 {
    const dogfood = environ.get("ZEER_DOGFOOD") orelse return null;
    if (!std.mem.eql(u8, dogfood, "1")) return null;
    const session = environ.get("ZEER_DOGFOOD_SESSION") orelse return error.StateDirectoryInvalid;
    if (!isSafeToken(session)) return error.StateDirectoryInvalid;
    if (environ.get("ZEER_DOGFOOD_TELEMETRY")) |telemetry| {
        const action_root = std.fs.path.dirname(telemetry) orelse return error.StateDirectoryInvalid;
        return try allocator.dupe(u8, action_root);
    }
    if (environ.get("TEMP") orelse environ.get("TMP")) |temp| {
        return try std.fs.path.join(allocator, &.{ temp, "KOOKIE", "dogfood", session });
    }
    return error.StateDirectoryInvalid;
}

fn defaultStateDirectory(allocator: std.mem.Allocator, environ: *const std.process.Environ.Map) ![]const u8 {
    if (environ.get("KOOKIE_STATE_DIR")) |configured| if (configured.len != 0) return allocator.dupe(u8, configured);
    if (builtin.os.tag == .windows) {
        if (try windowsDogfoodStateDirectory(allocator, environ)) |path| return path;
        if (environ.get("LOCALAPPDATA")) |local_app_data| return std.fs.path.join(allocator, &.{ local_app_data, "KOOKIE", "state" });
        const profile = environ.get("USERPROFILE") orelse return error.StateDirectoryInvalid;
        return std.fs.path.join(allocator, &.{ profile, "AppData", "Local", "KOOKIE", "state" });
    }
    if (environ.get("XDG_STATE_HOME")) |state_home| return std.fs.path.join(allocator, &.{ state_home, "kookie" });
    const home = environ.get("HOME") orelse return error.StateDirectoryInvalid;
    return std.fs.path.join(allocator, &.{ home, ".local", "state", "kookie" });
}

fn activeMarker(allocator: std.mem.Allocator, io: std.Io, state_dir: []const u8) !?Marker {
    const path = try markerPath(allocator, state_dir, "active.json");
    defer allocator.free(path);
    return readMarker(allocator, io, path);
}

fn installUpdate(
    allocator: std.mem.Allocator,
    io: std.Io,
    state_dir: []const u8,
    info: ReleaseInfo,
    manifest: Manifest,
) !DownloadedUpdate {
    if (!std.mem.eql(u8, manifest.archive, info.archive) or manifest.size != info.archive_size) return error.InvalidManifest;
    const updates_dir = try std.fs.path.join(allocator, &.{ state_dir, "updates" });
    defer allocator.free(updates_dir);
    try ensurePrivateDirectory(io, updates_dir);
    const final_dir = try std.fs.path.join(allocator, &.{ updates_dir, manifest.sha256 });
    defer allocator.free(final_dir);
    const final_extracted = try std.fs.path.join(allocator, &.{ final_dir, "extracted" });
    defer allocator.free(final_extracted);
    const expected_root = try expectedRootName(manifest.archive);
    const existing_root = try std.fs.path.join(allocator, &.{ final_extracted, expected_root });
    if (rootIsUsable(io, existing_root)) {
        return .{ .manifest = manifest, .root = existing_root };
    }
    allocator.free(existing_root);

    const stage_name = try std.fmt.allocPrint(allocator, ".stage-{s}", .{manifest.sha256});
    defer allocator.free(stage_name);
    const stage_dir = try std.fs.path.join(allocator, &.{ updates_dir, stage_name });
    std.Io.Dir.cwd().deleteTree(io, stage_dir) catch |err| if (err != error.FileNotFound) return err;
    try ensurePrivateDirectory(io, stage_dir);
    errdefer std.Io.Dir.cwd().deleteTree(io, stage_dir) catch {};
    const archive_path = try std.fs.path.join(allocator, &.{ stage_dir, manifest.archive });
    defer allocator.free(archive_path);
    try downloadToFile(allocator, io, info.archive_url, archive_path, manifest.size, manifest.sha256);
    const extracted_dir = try std.fs.path.join(allocator, &.{ stage_dir, "extracted" });
    defer allocator.free(extracted_dir);
    try ensurePrivateDirectory(io, extracted_dir);
    const extracted_root_name = try extractArchive(allocator, io, archive_path, targetName(), extracted_dir);
    defer allocator.free(extracted_root_name);
    if (!std.mem.eql(u8, extracted_root_name, expected_root)) return error.InvalidArchiveType;
    const staged_root = try std.fs.path.join(allocator, &.{ extracted_dir, extracted_root_name });
    defer allocator.free(staged_root);
    try runPackageSmoke(allocator, io, staged_root);

    std.Io.Dir.cwd().deleteTree(io, final_dir) catch |err| if (err != error.FileNotFound) return err;
    try std.Io.Dir.renameAbsolute(stage_dir, final_dir, io);
    const final_root = try std.fs.path.join(allocator, &.{ final_dir, "extracted", extracted_root_name });
    return .{ .manifest = manifest, .root = final_root };
}

fn updateFromGithub(
    allocator: std.mem.Allocator,
    io: std.Io,
    state_dir: []const u8,
    api_url: []const u8,
) !DownloadedUpdate {
    const info = try latestRelease(allocator, io, api_url);
    const manifest_bytes = try responseBytes(allocator, io, info.manifest_url, max_manifest_bytes);
    const signature_bytes = try responseBytes(allocator, io, info.signature_url, max_signature_bytes);
    const manifest = try verifyManifest(allocator, manifest_bytes, signature_bytes);
    if (!std.mem.eql(u8, manifest.version, info.version) or !std.mem.eql(u8, manifest.target, targetName())) return error.InvalidManifest;
    return installUpdate(allocator, io, state_dir, info, manifest);
}

fn activateMarker(allocator: std.mem.Allocator, io: std.Io, state_dir: []const u8, current: ?Marker, next: Marker) !void {
    if (current) |marker| {
        const previous_path = try markerPath(allocator, state_dir, "previous.json");
        defer allocator.free(previous_path);
        try writeMarker(allocator, io, previous_path, marker);
    }
    const active_path = try markerPath(allocator, state_dir, "active.json");
    defer allocator.free(active_path);
    try writeMarker(allocator, io, active_path, next);
}

fn fallbackRoot(allocator: std.mem.Allocator, io: std.Io, args: []const []const u8, active: ?Marker) ![]const u8 {
    if (active) |marker| if (rootIsUsable(io, marker.root)) return allocator.dupe(u8, marker.root);
    const current_dir = try selfExecutableDirectory(allocator, io, args);
    if (rootIsUsable(io, current_dir)) return current_dir;
    return error.MissingGame;
}

fn launchGame(allocator: std.mem.Allocator, io: std.Io, root: []const u8, dogfood_run: bool) !void {
    const executable = try std.fs.path.join(allocator, &.{ root, gameExecutableName() });
    defer allocator.free(executable);
    if (!rootIsUsable(io, root)) return error.MissingGame;
    if (dogfood_run) {
        const result = try std.process.run(allocator, io, .{
            .argv = &.{executable},
            .cwd = .{ .path = root },
            .stdout_limit = .limited(max_process_output),
            .stderr_limit = .limited(max_process_output),
        });
        defer allocator.free(result.stdout);
        defer allocator.free(result.stderr);
        switch (result.term) {
            .exited => |code| if (code != 0) return error.LaunchFailed,
            else => return error.LaunchFailed,
        }
        return;
    }
    const child = try std.process.spawn(io, .{
        .argv = &.{executable},
        .cwd = .{ .path = root },
        .stdin = .inherit,
        .stdout = .inherit,
        .stderr = .inherit,
    });
    const Reaper = struct {
        fn run(process: std.process.Child, process_io: std.Io) void {
            var owned = process;
            _ = owned.wait(process_io) catch {};
        }
    };
    const thread = try std.Thread.spawn(.{}, Reaper.run, .{ child, io });
    thread.detach();
}

fn run(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const io = init.io;
    const args = try init.minimal.args.toSlice(allocator);
    const options = try parseOptions(args, allocator);
    if (targetName().len == 0) return error.UnsupportedTarget;
    if (options.self_test) {
        _ = try decodePublicKey();
        _ = try publicKeySha256();
        std.debug.print("KOOKIE launcher self-test passed target={s}\n", .{targetName()});
        return;
    }
    if (options.package_smoke) {
        const root = try selfExecutableDirectory(allocator, io, args);
        try runPackageSmoke(allocator, io, root);
        std.debug.print("KOOKIE launcher package smoke passed target={s}\n", .{targetName()});
        return;
    }
    const dogfood_run = std.mem.eql(u8, init.environ_map.get("ZEER_DOGFOOD") orelse "", "1");
    const state_dir = if (options.state_dir) |path| try allocator.dupe(u8, path) else try defaultStateDirectory(allocator, init.environ_map);
    try ensurePrivateDirectory(io, state_dir);
    const current = activeMarker(allocator, io, state_dir) catch null;

    const package_identity = bundledIdentity(allocator, io, args) catch null;
    const package_root = selfExecutableDirectory(allocator, io, args) catch null;
    var baseline_root: ?[]const u8 = null;
    var baseline_version: ?[]const u8 = null;
    if (current) |marker| {
        if (rootIsUsable(io, marker.root)) {
            baseline_root = marker.root;
            baseline_version = marker.version;
        }
    }
    if (package_identity) |identity| {
        if (package_root) |root_path| {
            if (rootIsUsable(io, root_path) and
                (baseline_version == null or versionIsNewer(identity.version, baseline_version.?)))
            {
                baseline_root = root_path;
                baseline_version = identity.version;
            }
        }
    }

    var root: []const u8 = undefined;
    var selected_manifest: ?Manifest = null;
    if (options.offline) {
        root = if (baseline_root) |path|
            try allocator.dupe(u8, path)
        else
            try fallbackRoot(allocator, io, args, current);
    } else {
        const update = updateFromGithub(allocator, io, state_dir, options.api_url) catch |err| {
            if (options.check_only or options.no_launch) return err;
            std.debug.print("KOOKIE launcher: update skipped ({s}); using current package\n", .{@errorName(err)});
            root = if (baseline_root) |path|
                try allocator.dupe(u8, path)
            else
                try fallbackRoot(allocator, io, args, current);
            if (!options.no_launch) try launchGame(allocator, io, root, dogfood_run);
            return;
        };
        var use_downloaded_update = true;
        if (baseline_root != null and baseline_version != null) {
            use_downloaded_update = versionIsNewer(update.manifest.version, baseline_version.?);
        }
        if (!use_downloaded_update) {
            root = try allocator.dupe(u8, baseline_root.?);
        } else {
            root = update.root;
            selected_manifest = update.manifest;
            const current_same = if (current) |marker|
                std.mem.eql(u8, marker.version, update.manifest.version) and
                    std.mem.eql(u8, marker.build_id, update.manifest.build_id) and
                    std.mem.eql(u8, marker.sha256, update.manifest.sha256) and
                    rootIsUsable(io, marker.root)
            else
                false;
            if (!current_same) {
                const next = Marker{
                    .version = update.manifest.version,
                    .build_id = update.manifest.build_id,
                    .target = update.manifest.target,
                    .archive = update.manifest.archive,
                    .sha256 = update.manifest.sha256,
                    .root = update.root,
                };
                try activateMarker(allocator, io, state_dir, current, next);
            }
        }

    }
    if (selected_manifest) |manifest| {
        std.debug.print("KOOKIE {s} active version={s} build={s}\n", .{ application, manifest.version, manifest.build_id });
    } else {
        std.debug.print("KOOKIE {s} active root={s}\n", .{ application, root });
    }
    if (options.check_only or options.no_launch) return;
    try launchGame(allocator, io, root, dogfood_run);
}

pub fn main(init: std.process.Init) !void {
    run(init) catch |err| {
        std.debug.print("KOOKIE launcher failed: {s}\n", .{@errorName(err)});
        std.process.exit(1);
    };
}

test "target names use native package suffixes" {
    try std.testing.expect(std.mem.endsWith(u8, if (builtin.os.tag == .windows) "windows-x86_64.zip" else "linux-x86_64.tar.gz", archiveSuffix()));
}

test "archive entry traversal is rejected" {
    try std.testing.expectError(error.InvalidArchiveEntryPath, validateArchiveEntryPath("../escape"));
    try std.testing.expectError(error.InvalidArchiveEntryPath, validateArchiveEntryPath("/absolute"));
    try std.testing.expectError(error.InvalidArchiveEntryPath, validateArchiveEntryPath("root/./file"));
    try std.testing.expectError(error.InvalidArchiveEntryPath, validateArchiveEntryPath("root\\file"));
}

test "release versions normalize optional tag prefix" {
    try std.testing.expectEqualStrings("1.2.3", try normalizeVersion("v1.2.3"));
    try std.testing.expectError(error.InvalidManifest, normalizeVersion("latest"));
}

test "bundled package version blocks older update" {
    try std.testing.expect(versionIsNewer("0.1.0-dogfood.35", "0.1.0-dogfood.34"));
    try std.testing.expect(!versionIsNewer("0.1.0-dogfood.34", "0.1.0-dogfood.35"));
    try std.testing.expect(versionIsNewer("0.1.0", "0.1.0-rc.1"));
}

test "GitHub API and release asset URL policy is explicit" {
    try validateGithubUrl("https://api.github.com/repos/rufl/KOOKIE/releases");
    try validateGithubUrl("https://release-assets.githubusercontent.com/package");
    try validateGithubUrl("http://127.0.0.1:8080/releases.json");
    try std.testing.expectError(error.InvalidUrl, validateGithubUrl("https://example.com/package"));
}

test "Windows dogfood state is isolated without profile variables" {
    var environ = std.process.Environ.Map.init(std.testing.allocator);
    defer environ.deinit();
    try environ.put("ZEER_DOGFOOD", "1");
    try environ.put("TEMP", "/tmp/zeer");
    try environ.put("ZEER_DOGFOOD_SESSION", "session-123");
    try environ.put("ZEER_DOGFOOD_TELEMETRY", "/tmp/action/telemetry.jsonl");

    const path = (try windowsDogfoodStateDirectory(std.testing.allocator, &environ)).?;
    defer std.testing.allocator.free(path);
    try std.testing.expectEqualStrings("/tmp/action", path);

    var telemetry_environ = std.process.Environ.Map.init(std.testing.allocator);
    defer telemetry_environ.deinit();
    try telemetry_environ.put("ZEER_DOGFOOD", "1");
    try telemetry_environ.put("ZEER_DOGFOOD_SESSION", "session-456");
    try telemetry_environ.put("ZEER_DOGFOOD_TELEMETRY", "/tmp/action/telemetry.jsonl");
    const fallback_path = (try windowsDogfoodStateDirectory(std.testing.allocator, &telemetry_environ)).?;
    defer std.testing.allocator.free(fallback_path);
    try std.testing.expectEqualStrings("/tmp/action", fallback_path);

    var temp_environ = std.process.Environ.Map.init(std.testing.allocator);
    defer temp_environ.deinit();
    try temp_environ.put("ZEER_DOGFOOD", "1");
    try temp_environ.put("ZEER_DOGFOOD_SESSION", "session-789");
    try temp_environ.put("TEMP", "/tmp/zeer");
    const temp_path = (try windowsDogfoodStateDirectory(std.testing.allocator, &temp_environ)).?;
    defer std.testing.allocator.free(temp_path);
    try std.testing.expectEqualStrings("/tmp/zeer/KOOKIE/dogfood/session-789", temp_path);

    try environ.put("ZEER_DOGFOOD_SESSION", "../escape");
    try std.testing.expectError(error.StateDirectoryInvalid, windowsDogfoodStateDirectory(std.testing.allocator, &environ));
}
