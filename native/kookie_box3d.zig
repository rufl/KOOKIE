const std = @import("std");
const c = @import("box3d_c");

/// Kof's fixed movement coordinates use eight ticks per authored world unit.
/// One authored world unit maps to one Box3D metre.
pub const units_per_meter: f32 = 8.0;
pub const max_vertices: usize = 65_535;
pub const max_triangles: usize = 32_768;
pub const max_planes: usize = 128;
pub const max_world_units: f32 = 10_000_000;
const walkable_normal_y_min: f32 = 0.5;
const ground_probe_drop: f32 = 1;
const step_rise_limit: f32 = 0.5;
const slope_rise_per_run: f32 = 1.7320508;

const Error = enum(c_int) {
    ok = 0,
    invalid_argument = 1,
    capacity_exceeded = 2,
    allocation_failed = 3,
    box3d_failure = 4,
    plane_capacity_exceeded = 5,
};

const Vec3 = extern struct { x: f32, y: f32, z: f32 };
const Result = extern struct {
    position: Vec3,
    contact_normal: Vec3,
    contact_count: u32,
    grounded: u8,
    _reserved: [3]u8 = .{ 0, 0, 0 },
    contact_offset: f32 = 0,
    contact_shape: c_int = 0,
};

const max_actors: usize = 12;
const actor_category: u64 = 1 << 63;
const static_query_mask: u64 = ~actor_category;
const Actor = struct {
    body_id: c.b3BodyId,
    bottom: Vec3,
    radius_fixed: c_int,
    height_fixed: c_int,
};
const World = struct {
    world_id: c.b3WorldId,
    body_id: c.b3BodyId,
    mesh: *c.b3MeshData,
    additional_meshes: ?[]*c.b3MeshData = null,
    additional_count: usize = 0,
    actors: [max_actors]?Actor = undefined,
};
const PlaneBuffer = struct {
    items: [max_planes]c.b3CollisionPlane = undefined,
    overflow: bool = false,
    count: usize = 0,
    contact_normal: Vec3 = .{ .x = 0, .y = 0, .z = 0 },
    contact_offset: f32 = 0,
    shape_index: c_int = 0,
    grounded: bool = false,
};
// The web server owns one arena world and calls this ABI only from Kof's
// authoritative simulation thread. No arena geometry or result buffer is
// allocated on a movement tick.
var server_world: ?*anyopaque = null;
var server_result_actor_slot: c_int = -1;
var building_vertices: ?[]f32 = null;
var building_indices: ?[]i32 = null;
var building_collision_vertices: ?[]f32 = null;
var building_collision_groups: ?[]usize = null;
const ArenaBox = struct { bounds: [6]c_int };
var building_boxes: [16]ArenaBox = undefined;
var building_box_count: usize = 0;
var building_count: usize = 0;
var building_expected: usize = 0;
var building_collision_count: usize = 0;
var server_fixed_vertices: ?[]f32 = null;
var server_result: Result = .{
    .position = .{ .x = 0, .y = 0, .z = 0 },
    .contact_normal = .{ .x = 0, .y = 0, .z = 0 },
    .contact_count = 0,
    .grounded = 0,
};

fn finite(v: f32) bool {
    return std.math.isFinite(v);
}
fn v3(x: f32, y: f32, z: f32) c.b3Vec3 {
    return .{ .x = x, .y = y, .z = z };
}

fn gatherPlane(shape_id: c.b3ShapeId, result: [*c]const c.b3PlaneResult, plane_count: c_int, context: ?*anyopaque) callconv(.c) bool {
    const buffer: *PlaneBuffer = @ptrCast(@alignCast(context.?));
    if (plane_count < 0) {
        buffer.overflow = true;
        return false;
    }
    const n: usize = @intCast(plane_count);
    if (n > max_planes - buffer.count) {
        buffer.overflow = true;
        return false;
    }
    if (n > 0) buffer.shape_index = @intCast(shape_id.index1);
    for (0..n) |i| {
        const p = result[i].plane;
        buffer.items[buffer.count] = .{
            .plane = p,
            .pushLimit = std.math.floatMax(f32),
            .push = 0,
            .clipVelocity = true,
        };
        buffer.count += 1;
        const normal = p.normal;
        buffer.contact_offset += p.offset;
        buffer.contact_normal.x += normal.x;
        buffer.contact_normal.y += normal.y;
        buffer.contact_normal.z += normal.z;
        if (normal.y > 0.5) buffer.grounded = true;
    }
    return true;
}

/// Create a static triangle arena. Vertices are packed xyz float world-units; indices are
/// packed triangle triples. The mesh owns its cloned geometry for the world's lifetime.
/// Returns an explicit Error value and writes an opaque world handle on success.
fn createMeshData(vertices: []const f32, indices: []const i32, triangle_count: usize) ?*c.b3MeshData {
    if (vertices.len % 3 != 0 or indices.len != triangle_count * 3 or
        vertices.len / 3 < 3 or triangle_count == 0) return null;
    const alloc = std.heap.c_allocator;
    const geometry = alloc.alloc(c.b3Vec3, vertices.len / 3) catch return null;
    defer alloc.free(geometry);
    for (geometry, 0..) |*point, i| {
        point.* = v3(
            vertices[i * 3] / units_per_meter,
            vertices[i * 3 + 1] / units_per_meter,
            vertices[i * 3 + 2] / units_per_meter,
        );
    }
    var mesh_def: c.b3MeshDef = std.mem.zeroes(c.b3MeshDef);
    mesh_def.vertices = @ptrCast(geometry.ptr);
    mesh_def.indices = @ptrCast(@constCast(indices.ptr));
    mesh_def.vertexCount = @intCast(geometry.len);
    mesh_def.triangleCount = @intCast(triangle_count);
    mesh_def.weldTolerance = 0.01 / units_per_meter;
    mesh_def.weldVertices = true;
    mesh_def.identifyEdges = true;
    return c.b3CreateMesh(&mesh_def, null, 0);
}

export fn kookie_box3d_create(vertices_arg: ?[*]const f32, vertex_count: u32, indices_arg: ?[*]const i32, triangle_count: u32, out_world_arg: ?*?*anyopaque) callconv(.c) c_int {
    const out_world = out_world_arg orelse return @intFromEnum(Error.invalid_argument);
    out_world.* = null;
    if (vertex_count < 3 or triangle_count == 0) return @intFromEnum(Error.invalid_argument);
    if (vertex_count > max_vertices or triangle_count > max_triangles) return @intFromEnum(Error.capacity_exceeded);
    const vertices = vertices_arg orelse return @intFromEnum(Error.invalid_argument);
    const indices = indices_arg orelse return @intFromEnum(Error.invalid_argument);
    const vertex_len: usize = @intCast(vertex_count);
    const tri_len: usize = @intCast(triangle_count);
    for (0..vertex_len * 3) |i| if (!finite(vertices[i]) or @abs(vertices[i]) > max_world_units) return @intFromEnum(Error.invalid_argument);
    for (0..tri_len * 3) |i| if (indices[i] < 0 or indices[i] >= vertex_count) return @intFromEnum(Error.invalid_argument);

    const alloc = std.heap.c_allocator;
    const geometry = alloc.alloc(c.b3Vec3, vertex_len) catch return @intFromEnum(Error.allocation_failed);
    defer alloc.free(geometry);
    for (0..vertex_len) |i| geometry[i] = v3(vertices[3 * i] / units_per_meter, vertices[3 * i + 1] / units_per_meter, vertices[3 * i + 2] / units_per_meter);
    const world = alloc.create(World) catch return @intFromEnum(Error.allocation_failed);
    var mesh_def: c.b3MeshDef = std.mem.zeroes(c.b3MeshDef);
    mesh_def.vertices = @ptrCast(geometry.ptr);
    mesh_def.indices = @ptrCast(@constCast(indices));
    mesh_def.vertexCount = @intCast(vertex_count);
    mesh_def.triangleCount = @intCast(triangle_count);
    mesh_def.weldTolerance = 0.01 / units_per_meter;
    mesh_def.weldVertices = true;
    mesh_def.identifyEdges = true;
    const mesh = c.b3CreateMesh(&mesh_def, null, 0) orelse {
        alloc.destroy(world);
        return @intFromEnum(Error.box3d_failure);
    };
    var world_def = c.b3DefaultWorldDef();
    world_def.enableSleep = false;
    world_def.enableContinuous = false;
    world_def.workerCount = 1;
    var actors: [max_actors]?Actor = undefined;
    @memset(&actors, null);
    world.* = .{
        .world_id = c.b3CreateWorld(&world_def),
        .body_id = undefined,
        .mesh = mesh,
        .actors = actors,
    };
    if (!c.b3World_IsValid(world.world_id)) {
        c.b3DestroyMesh(mesh);
        alloc.destroy(world);
        return @intFromEnum(Error.box3d_failure);
    }
    var body_def = c.b3DefaultBodyDef();
    body_def.type = c.b3_staticBody;
    const body = c.b3CreateBody(world.world_id, &body_def);
    world.body_id = body;
    if (!c.b3Body_IsValid(body)) {
        c.b3DestroyWorld(world.world_id);
        c.b3DestroyMesh(mesh);
        alloc.destroy(world);
        return @intFromEnum(Error.box3d_failure);
    }
    var shape_def = c.b3DefaultShapeDef();
    const shape = c.b3CreateMeshShape(body, &shape_def, mesh, v3(1, 1, 1));
    if (!c.b3Shape_IsValid(shape)) {
        c.b3DestroyWorld(world.world_id);
        c.b3DestroyMesh(mesh);
        alloc.destroy(world);
        return @intFromEnum(Error.box3d_failure);
    }
    out_world.* = world;
    return @intFromEnum(Error.ok);
}

export fn kookie_box3d_destroy(handle: ?*anyopaque) callconv(.c) void {
    const ptr = handle orelse return;
    const world: *World = @ptrCast(@alignCast(ptr));
    c.b3DestroyWorld(world.world_id);
    c.b3DestroyMesh(world.mesh);
    if (world.additional_meshes) |meshes| {
        for (0..world.additional_count) |i| c.b3DestroyMesh(meshes[i]);
        std.heap.c_allocator.free(meshes);
    }
    std.heap.c_allocator.destroy(world);
}

export fn kookie_box3d_begin_arena(triangle_count: c_int) callconv(.c) bool {
    if (triangle_count <= 0 or triangle_count > max_triangles) return false;
    if (server_world) |world| {
        kookie_box3d_destroy(world);
        server_world = null;
    }
    const alloc = std.heap.c_allocator;
    if (server_fixed_vertices) |vertices| alloc.free(vertices);
    server_fixed_vertices = null;
    if (building_vertices) |vertices| alloc.free(vertices);
    if (building_indices) |indices| alloc.free(indices);
    if (building_collision_vertices) |vertices| alloc.free(vertices);
    if (building_collision_groups) |groups| alloc.free(groups);
    building_collision_groups = null;
    const count: usize = @intCast(triangle_count);
    building_vertices = alloc.alloc(f32, count * 9) catch return false;
    building_collision_vertices = alloc.alloc(f32, count * 9) catch {
        alloc.free(building_vertices.?);
        building_vertices = null;
        return false;
    };
    building_indices = alloc.alloc(i32, count * 3) catch {
        alloc.free(building_vertices.?);
        alloc.free(building_collision_vertices.?);
        building_vertices = null;
        building_collision_vertices = null;
        return false;
    };
    building_collision_groups = alloc.alloc(usize, count) catch {
        alloc.free(building_vertices.?);
        alloc.free(building_collision_vertices.?);
        alloc.free(building_indices.?);
        building_vertices = null;
        building_collision_vertices = null;
        building_indices = null;
        return false;
    };
    building_expected = count;
    building_count = 0;
    building_collision_count = 0;
    building_box_count = 0;
    return true;
}

fn addArenaTriangle(
    ax: c_int, ay: c_int, az: c_int,
    bx: c_int, by: c_int, bz: c_int,
    cx: c_int, cy: c_int, cz: c_int,
    include_mesh_collision: bool,
) bool {
    if (building_vertices == null or building_indices == null or
        building_collision_vertices == null or building_collision_groups == null or
        building_count >= building_expected) {
        return false;
    }
    const coordinates = [_]c_int{ ax, ay, az, bx, by, bz, cx, cy, cz };
    const vertices = building_vertices.?;
    for (coordinates, 0..) |value, i| {
        const fixed_value = @as(f32, @floatFromInt(value));
        if (!finite(fixed_value) or @abs(fixed_value) > max_world_units) return false;
        vertices[building_count * 9 + i] = fixed_value;
    }
    const abx = @as(f32, @floatFromInt(bx - ax));
    const aby = @as(f32, @floatFromInt(by - ay));
    const abz = @as(f32, @floatFromInt(bz - az));
    const acx = @as(f32, @floatFromInt(cx - ax));
    const acy = @as(f32, @floatFromInt(cy - ay));
    const acz = @as(f32, @floatFromInt(cz - az));
    const normal_x = aby * acz - abz * acy;
    const normal_y = abz * acx - abx * acz;
    const normal_z = abx * acy - aby * acx;
    const normal_length = @sqrt(normal_x * normal_x + normal_y * normal_y + normal_z * normal_z);
    const vertical_ratio = if (normal_length > 0) @abs(normal_y) / normal_length else 1;
    const slope_surface = vertical_ratio > walkable_normal_y_min and vertical_ratio < 0.9999;
    if (include_mesh_collision and !slope_surface) {
        const collision_vertices = building_collision_vertices.?;
        const indices = building_indices.?;
        const vertex_base = building_collision_count * 3;
        for (coordinates, 0..) |value, i| collision_vertices[building_collision_count * 9 + i] = @floatFromInt(value);
        for (0..3) |i| indices[building_collision_count * 3 + i] = @intCast(vertex_base + i);
        building_collision_groups.?[building_collision_count] = building_count / 2;
        building_collision_count += 1;
    }
    building_count += 1;
    return true;
}

export fn kookie_box3d_add_arena_triangle(
    ax: c_int, ay: c_int, az: c_int,
    bx: c_int, by: c_int, bz: c_int,
    cx: c_int, cy: c_int, cz: c_int,
) callconv(.c) bool {
    return addArenaTriangle(ax, ay, az, bx, by, bz, cx, cy, cz, true);
}

export fn kookie_box3d_add_arena_visual_triangle(
    ax: c_int, ay: c_int, az: c_int,
    bx: c_int, by: c_int, bz: c_int,
    cx: c_int, cy: c_int, cz: c_int,
) callconv(.c) bool {
    return addArenaTriangle(ax, ay, az, bx, by, bz, cx, cy, cz, false);
}

export fn kookie_box3d_add_arena_box(
    min_x: c_int, min_y: c_int, min_z: c_int,
    max_x: c_int, max_y: c_int, max_z: c_int,
) callconv(.c) bool {
    if (building_vertices == null or building_box_count >= building_boxes.len or
        min_x >= max_x or min_y >= max_y or min_z >= max_z) return false;
    building_boxes[building_box_count] = .{ .bounds = .{
        min_x, min_y, min_z, max_x, max_y, max_z,
    } };
    building_box_count += 1;
    return true;
}

export fn kookie_box3d_finish_arena() callconv(.c) bool {
    if (building_count == 0 or building_count != building_expected or
        building_collision_count == 0 or building_vertices == null or
        building_collision_vertices == null or building_indices == null or
        building_collision_groups == null) return false;

    const alloc = std.heap.c_allocator;
    const ground_vertices = building_vertices.?;
    const collision_vertices = building_collision_vertices.?;
    const collision_groups = building_collision_groups.?;
    const group_limit = (building_expected + 1) / 2;
    const group_sizes = alloc.alloc(usize, group_limit) catch return false;
    defer alloc.free(group_sizes);
    @memset(group_sizes, 0);
    for (0..building_collision_count) |triangle| {
        group_sizes[collision_groups[triangle]] += 1;
    }
    var group_count: usize = 0;
    for (group_sizes) |size| {
        if (size > 0) group_count += 1;
    }
    if (group_count == 0) return false;

    const scratch_vertices = alloc.alloc(f32, 18) catch return false;
    defer alloc.free(scratch_vertices);
    const scratch_indices = alloc.alloc(i32, 6) catch return false;
    defer alloc.free(scratch_indices);

    var world_handle: ?*anyopaque = null;
    var world: ?*World = null;
    var additional_meshes: ?[]*c.b3MeshData = null;
    var created_additional: usize = 0;
    var created_groups: usize = 0;
    for (0..group_limit) |group| {
        const triangles_in_group = group_sizes[group];
        if (triangles_in_group == 0) continue;
        if (triangles_in_group > 2) {
            if (world_handle) |handle| kookie_box3d_destroy(handle);
            return false;
        }
        var local_triangle: usize = 0;
        for (0..building_collision_count) |triangle| {
            if (collision_groups[triangle] != group) continue;
            @memcpy(
                scratch_vertices[local_triangle * 9 ..][0..9],
                collision_vertices[triangle * 9 ..][0..9],
            );
            for (0..3) |corner| {
                scratch_indices[local_triangle * 3 + corner] =
                    @intCast(local_triangle * 3 + corner);
            }
            local_triangle += 1;
        }
        if (created_groups == 0) {
            const status = kookie_box3d_create(
                scratch_vertices.ptr,
                @intCast(triangles_in_group * 3),
                scratch_indices.ptr,
                @intCast(triangles_in_group),
                &world_handle,
            );
            if (status != @intFromEnum(Error.ok)) return false;
            world = @ptrCast(@alignCast(world_handle.?));
            if (group_count > 1) {
                additional_meshes = alloc.alloc(
                    *c.b3MeshData, group_count - 1,
                ) catch {
                    kookie_box3d_destroy(world_handle);
                    return false;
                };
                world.?.additional_meshes = additional_meshes;
            }
        } else {
            const mesh = createMeshData(
                scratch_vertices[0 .. triangles_in_group * 9],
                scratch_indices[0 .. triangles_in_group * 3],
                triangles_in_group,
            ) orelse {
                if (world_handle) |handle| kookie_box3d_destroy(handle);
                return false;
            };
            var shape_def = c.b3DefaultShapeDef();
            const shape = c.b3CreateMeshShape(
                world.?.body_id, &shape_def, mesh, v3(1, 1, 1),
            );
            if (!c.b3Shape_IsValid(shape)) {
                c.b3DestroyMesh(mesh);
                if (world_handle) |handle| kookie_box3d_destroy(handle);
                return false;
            }
            additional_meshes.?[created_additional] = mesh;
            created_additional += 1;
            world.?.additional_count = created_additional;
        }
        created_groups += 1;
    }
    const handle = world_handle orelse return false;
    server_world = handle;
    server_fixed_vertices = ground_vertices;
    building_vertices = null;
    if (building_collision_vertices) |vertices| alloc.free(vertices);
    if (building_indices) |indices| alloc.free(indices);
    if (building_collision_groups) |groups| alloc.free(groups);
    building_collision_vertices = null;
    building_indices = null;
    building_collision_groups = null;
    building_expected = 0;
    building_count = 0;
    building_collision_count = 0;
    return true;
}

export fn kookie_box3d_destroy_arena() callconv(.c) void {
    const alloc = std.heap.c_allocator;
    if (server_world) |world| kookie_box3d_destroy(world);
    if (building_vertices) |vertices| alloc.free(vertices);
    if (building_indices) |indices| alloc.free(indices);
    if (building_collision_vertices) |vertices| alloc.free(vertices);
    if (building_collision_groups) |groups| alloc.free(groups);
    if (server_fixed_vertices) |vertices| alloc.free(vertices);
    server_world = null;
    building_vertices = null;
    building_indices = null;
    building_collision_vertices = null;
    building_collision_groups = null;
    server_fixed_vertices = null;
    building_expected = 0;
    building_count = 0;
    building_collision_count = 0;
    building_box_count = 0;
}

fn clampArenaBoxes(
    start_x: c_int, start_y: c_int, start_z: c_int,
    end_x: *c_int, end_z: *c_int,
    radius: c_int, height: c_int,
) void {
    const low_y = start_y + radius;
    const high_y = start_y + height - radius;
    for (building_boxes[0..building_box_count]) |box| {
        const b = box.bounds;
        if (high_y < b[1] or low_y > b[4]) continue;
        const min_x = b[0];
        const max_x = b[3];
        const min_z = b[2];
        const max_z = b[5];
        const z_low = @min(start_z, end_z.*) - radius;
        const z_high = @max(start_z, end_z.*) + radius;
        if (z_high >= min_z and z_low <= max_z) {
            if (end_x.* > start_x and start_x + radius <= min_x and
                end_x.* + radius > min_x) {
                end_x.* = @min(end_x.*, min_x - radius);
            } else if (end_x.* < start_x and start_x - radius >= max_x and
                end_x.* - radius < max_x) {
                end_x.* = @max(end_x.*, max_x + radius);
            }
        }
        const x_low = @min(start_x, end_x.*) - radius;
        const x_high = @max(start_x, end_x.*) + radius;
        if (x_high >= min_x and x_low <= max_x) {
            if (end_z.* > start_z and start_z + radius <= min_z and
                end_z.* + radius > min_z) {
                end_z.* = @min(end_z.*, min_z - radius);
            } else if (end_z.* < start_z and start_z - radius >= max_z and
                end_z.* - radius < max_z) {
                end_z.* = @max(end_z.*, max_z + radius);
            }
        }
    }
}

export fn kookie_box3d_move_fixed(
    start_x: c_int, start_y: c_int, start_z: c_int,
    end_x: c_int, end_y: c_int, end_z: c_int,
    radius_fixed: c_int, full_height_fixed: c_int, was_grounded: bool,
) callconv(.c) c_int {
    const world = server_world orelse return @intFromEnum(Error.invalid_argument);
    const conversion = units_per_meter;
    var resolved_end_x = end_x;
    var resolved_end_z = end_z;
    clampArenaBoxes(
        start_x, start_y, start_z, &resolved_end_x, &resolved_end_z,
        radius_fixed, full_height_fixed,
    );
    const dx = @as(f32, @floatFromInt(resolved_end_x - start_x)) / conversion;
    const dz = @as(f32, @floatFromInt(resolved_end_z - start_z)) / conversion;
    const allowed_rise = step_rise_limit +
        @sqrt(dx * dx + dz * dz) * slope_rise_per_run;
    var resolved_end_y = end_y;
    if (was_grounded and end_y <= start_y) {
        if (groundHeightAt(
                @as(f32, @floatFromInt(resolved_end_x)) / conversion,
                @as(f32, @floatFromInt(resolved_end_z)) / conversion,
                @as(f32, @floatFromInt(start_y)) / conversion,
                allowed_rise)) |ground_y| {
            resolved_end_y = fixedResult(ground_y);
        }
    }
    var result: Result = undefined;
    const status = kookie_box3d_move(
        world,
        .{
            .x = @as(f32, @floatFromInt(start_x)) / conversion,
            .y = @as(f32, @floatFromInt(start_y)) / conversion,
            .z = @as(f32, @floatFromInt(start_z)) / conversion,
        },
        .{
            .x = dx,
            .y = @as(f32, @floatFromInt(resolved_end_y - start_y)) / conversion,
            .z = dz,
        },
        @as(f32, @floatFromInt(radius_fixed)) / conversion,
        @as(f32, @floatFromInt(full_height_fixed)) / conversion,
        &result,
    );
    if (status != @intFromEnum(Error.ok)) return status;
    if (end_y <= start_y) {
        if (groundHeightAt(
                result.position.x, result.position.z, result.position.y,
                allowed_rise)) |ground_y| {
            result.position.y = ground_y;
            result.grounded = 1;
        }
    }
    server_result = result;
    return @intFromEnum(Error.ok);
}

fn fixedResult(value: f32) c_int {
    const fixed = @round(value * units_per_meter);
    return @intFromFloat(fixed);
}
fn groundHeightAt(x: f32, z: f32, base_y: f32, allowed_rise: f32) ?f32 {
    const vertices = server_fixed_vertices orelse return null;
    var best_y: ?f32 = null;
    const triangle_count = vertices.len / 9;
    for (0..triangle_count) |triangle| {
        const base = triangle * 9;
        const ax = vertices[base] / units_per_meter;
        const ay = vertices[base + 1] / units_per_meter;
        const az = vertices[base + 2] / units_per_meter;
        const bx = vertices[base + 3] / units_per_meter;
        const by = vertices[base + 4] / units_per_meter;
        const bz = vertices[base + 5] / units_per_meter;
        const cx = vertices[base + 6] / units_per_meter;
        const cy = vertices[base + 7] / units_per_meter;
        const cz = vertices[base + 8] / units_per_meter;

        const abx = bx - ax;
        const aby = by - ay;
        const abz = bz - az;
        const acx = cx - ax;
        const acy = cy - ay;
        const acz = cz - az;
        const nx = aby * acz - abz * acy;
        const ny = abz * acx - abx * acz;
        const nz = abx * acy - aby * acx;
        const normal_len = @sqrt(nx * nx + ny * ny + nz * nz);
        if (normal_len == 0 or @abs(ny) / normal_len <= walkable_normal_y_min) continue;

        const denominator = (bz - cz) * (ax - cx) + (cx - bx) * (az - cz);
        if (@abs(denominator) < 0.000001) continue;
        const u = ((bz - cz) * (x - cx) + (cx - bx) * (z - cz)) / denominator;
        const v = ((cz - az) * (x - cx) + (ax - cx) * (z - cz)) / denominator;
        const w = 1 - u - v;
        if (u < -0.0001 or v < -0.0001 or w < -0.0001) continue;

        const y = u * ay + v * by + w * cy;
        const rise = y - base_y;
        if (rise < -ground_probe_drop or rise > allowed_rise) continue;
        if (best_y == null or y > best_y.?) best_y = y;
    }
    return best_y;
}

fn clipRaySlab(
    origin: f32, delta: f32, minimum: f32, maximum: f32,
    entry: *f32, exit: *f32,
) bool {
    if (delta == 0) return origin >= minimum and origin <= maximum;
    var first = (minimum - origin) / delta;
    var last = (maximum - origin) / delta;
    if (first > last) std.mem.swap(f32, &first, &last);
    entry.* = @max(entry.*, first);
    exit.* = @min(exit.*, last);
    return entry.* <= exit.*;
}

fn rayBoxFraction(start: Vec3, delta: Vec3, bounds: [6]c_int) ?f32 {
    var entry: f32 = 0;
    var exit: f32 = 1;
    if (!clipRaySlab(start.x, delta.x, @as(f32, @floatFromInt(bounds[0])) / units_per_meter, @as(f32, @floatFromInt(bounds[3])) / units_per_meter, &entry, &exit) or
        !clipRaySlab(start.y, delta.y, @as(f32, @floatFromInt(bounds[1])) / units_per_meter, @as(f32, @floatFromInt(bounds[4])) / units_per_meter, &entry, &exit) or
        !clipRaySlab(start.z, delta.z, @as(f32, @floatFromInt(bounds[2])) / units_per_meter, @as(f32, @floatFromInt(bounds[5])) / units_per_meter, &entry, &exit) or
        exit < 0 or entry > 1) return null;
    return @max(0, entry);
}

export fn kookie_box3d_cast_ray_fixed(
    start_x: c_int, start_y: c_int, start_z: c_int,
    end_x: c_int, end_y: c_int, end_z: c_int,
) callconv(.c) c_int {
    server_result_actor_slot = -1;
    const world_handle = server_world orelse return -1;
    const world: *World = @ptrCast(@alignCast(world_handle));
    const start = Vec3{
        .x = @as(f32, @floatFromInt(start_x)) / units_per_meter,
        .y = @as(f32, @floatFromInt(start_y)) / units_per_meter,
        .z = @as(f32, @floatFromInt(start_z)) / units_per_meter,
    };
    const delta = Vec3{
        .x = @as(f32, @floatFromInt(end_x - start_x)) / units_per_meter,
        .y = @as(f32, @floatFromInt(end_y - start_y)) / units_per_meter,
        .z = @as(f32, @floatFromInt(end_z - start_z)) / units_per_meter,
    };
    if (!finite(start.x) or !finite(start.y) or !finite(start.z) or
        !finite(delta.x) or !finite(delta.y) or !finite(delta.z) or
        @abs(start.x) > max_world_units or @abs(start.y) > max_world_units or
        @abs(start.z) > max_world_units or @abs(delta.x) > max_world_units or
        @abs(delta.y) > max_world_units or @abs(delta.z) > max_world_units) return -1;
    var best_fraction: f32 = 1;
    var hit = false;
    var query_filter = c.b3DefaultQueryFilter();
    query_filter.maskBits &= static_query_mask;
    const ray = c.b3World_CastRayClosest(
        world.world_id,
        .{ .x = start.x, .y = start.y, .z = start.z },
        v3(delta.x, delta.y, delta.z),
        query_filter,
    );
    if (ray.hit) {
        best_fraction = ray.fraction;
        hit = true;
    }
    for (building_boxes[0..building_box_count]) |box| {
        if (rayBoxFraction(start, delta, box.bounds)) |fraction| {
            if (!hit or fraction < best_fraction) {
                best_fraction = fraction;
                hit = true;
            }
        }
    }
    if (!hit) return 0;
    server_result.position = .{
        .x = start.x + delta.x * best_fraction,
        .y = start.y + delta.y * best_fraction,
        .z = start.z + delta.z * best_fraction,
    };
    server_result.contact_count = 1;
    server_result.grounded = 0;
    server_result.contact_normal = .{ .x = 0, .y = 0, .z = 0 };
    server_result.contact_offset = 0;
    server_result.contact_shape = 0;
    return 1;
}

fn validActorCapsule(x: c_int, y: c_int, z: c_int, radius: c_int, height: c_int) bool {
    const fixed_limit: i64 = 80_000_000;
    const r: i64 = radius;
    const h: i64 = height;
    return r > 0 and h >= 2 * r and r <= fixed_limit and h <= fixed_limit and
        @as(u64, @abs(@as(i64, x))) + @as(u64, @intCast(r)) <= @as(u64, @intCast(fixed_limit)) and
        @as(u64, @abs(@as(i64, y))) <= @as(u64, @intCast(fixed_limit)) and
        @as(u64, @abs(@as(i64, y) + h)) <= @as(u64, @intCast(fixed_limit)) and
        @as(u64, @abs(@as(i64, z))) + @as(u64, @intCast(r)) <= @as(u64, @intCast(fixed_limit));
}

export fn kookie_box3d_set_actor_capsule(
    slot: c_int, bottom_x: c_int, bottom_y: c_int, bottom_z: c_int,
    radius_fixed: c_int, full_height_fixed: c_int,
) callconv(.c) c_int {
    const handle = server_world orelse return @intFromEnum(Error.invalid_argument);
    if (slot < 0 or slot >= @as(c_int, @intCast(max_actors)) or !validActorCapsule(
        bottom_x, bottom_y, bottom_z, radius_fixed, full_height_fixed,
    )) return @intFromEnum(Error.invalid_argument);
    const world: *World = @ptrCast(@alignCast(handle));
    const index: usize = @intCast(slot);
    const bottom = Vec3{
        .x = @as(f32, @floatFromInt(bottom_x)) / units_per_meter,
        .y = @as(f32, @floatFromInt(bottom_y)) / units_per_meter,
        .z = @as(f32, @floatFromInt(bottom_z)) / units_per_meter,
    };
    if (world.actors[index]) |*actor| {
        c.b3Body_SetTransform(
            actor.body_id,
            .{ .x = bottom.x, .y = bottom.y, .z = bottom.z },
            .{ .v = v3(0, 0, 0), .s = 1 },
        );
        actor.bottom = bottom;
        actor.radius_fixed = radius_fixed;
        actor.height_fixed = full_height_fixed;
        return @intFromEnum(Error.ok);
    }
    var body_def = c.b3DefaultBodyDef();
    body_def.type = c.b3_kinematicBody;
    body_def.position = .{ .x = bottom.x, .y = bottom.y, .z = bottom.z };
    const body = c.b3CreateBody(world.world_id, &body_def);
    if (!c.b3Body_IsValid(body)) return @intFromEnum(Error.box3d_failure);
    const radius = @as(f32, @floatFromInt(radius_fixed)) / units_per_meter;
    const height = @as(f32, @floatFromInt(full_height_fixed)) / units_per_meter;
    const capsule: c.b3Capsule = .{
        .center1 = v3(0, radius, 0),
        .center2 = v3(0, height - radius, 0),
        .radius = radius,
    };
    var shape_def = c.b3DefaultShapeDef();
    shape_def.isSensor = true;
    shape_def.filter.categoryBits = actor_category;
    shape_def.filter.maskBits = 0;
    const shape = c.b3CreateCapsuleShape(body, &shape_def, &capsule);
    if (!c.b3Shape_IsValid(shape)) {
        c.b3DestroyBody(body);
        return @intFromEnum(Error.box3d_failure);
    }
    world.actors[index] = .{
        .body_id = body,
        .bottom = bottom,
        .radius_fixed = radius_fixed,
        .height_fixed = full_height_fixed,
    };
    return @intFromEnum(Error.ok);
}

export fn kookie_box3d_clear_actor(slot: c_int) callconv(.c) void {
    if (slot < 0 or slot >= @as(c_int, @intCast(max_actors))) return;
    const handle = server_world orelse return;
    const world: *World = @ptrCast(@alignCast(handle));
    const index: usize = @intCast(slot);
    if (world.actors[index]) |actor| c.b3DestroyBody(actor.body_id);
    world.actors[index] = null;
}

fn capsuleOverlap(a: Actor, b: Actor) bool {
    const au = @as(f32, @floatFromInt(a.radius_fixed)) / units_per_meter;
    const bu = @as(f32, @floatFromInt(b.radius_fixed)) / units_per_meter;
    const ar = @as(f32, @floatFromInt(a.height_fixed - a.radius_fixed)) / units_per_meter;
    const br = @as(f32, @floatFromInt(b.height_fixed - b.radius_fixed)) / units_per_meter;
    const ay0 = a.bottom.y + au;
    const ay1 = a.bottom.y + ar;
    const by0 = b.bottom.y + bu;
    const by1 = b.bottom.y + br;
    const dy = if (ay1 < by0) by0 - ay1 else if (by1 < ay0) ay0 - by1 else 0;
    const dx = a.bottom.x - b.bottom.x;
    const dz = a.bottom.z - b.bottom.z;
    const radii = au + bu;
    return dx * dx + dy * dy + dz * dz <= radii * radii;
}

export fn kookie_box3d_overlap_actor_capsule_fixed(
    slot: c_int, bottom_x: c_int, bottom_y: c_int, bottom_z: c_int,
    radius_fixed: c_int, full_height_fixed: c_int,
) callconv(.c) bool {
    const handle = server_world orelse return false;
    if (slot < 0 or slot >= @as(c_int, @intCast(max_actors)) or !validActorCapsule(
        bottom_x, bottom_y, bottom_z, radius_fixed, full_height_fixed,
    )) return false;
    const world: *World = @ptrCast(@alignCast(handle));
    const query = Actor{
        .body_id = undefined,
        .bottom = .{
            .x = @as(f32, @floatFromInt(bottom_x)) / units_per_meter,
            .y = @as(f32, @floatFromInt(bottom_y)) / units_per_meter,
            .z = @as(f32, @floatFromInt(bottom_z)) / units_per_meter,
        },
        .radius_fixed = radius_fixed,
        .height_fixed = full_height_fixed,
    };
    for (world.actors, 0..) |actor, i| {
        if (i == @as(usize, @intCast(slot))) continue;
        if (actor) |other| if (capsuleOverlap(query, other)) return true;
    }
    return false;
}

fn raySphereFraction(start: Vec3, delta: Vec3, center: Vec3, radius: f32) ?f32 {
    const ox = start.x - center.x;
    const oy = start.y - center.y;
    const oz = start.z - center.z;
    const aa = delta.x * delta.x + delta.y * delta.y + delta.z * delta.z;
    if (aa == 0) return null;
    const bb = 2 * (ox * delta.x + oy * delta.y + oz * delta.z);
    const cc = ox * ox + oy * oy + oz * oz - radius * radius;
    const disc = bb * bb - 4 * aa * cc;
    if (disc < 0) return null;
    const fraction = (-bb - @sqrt(disc)) / (2 * aa);
    if (fraction >= 0 and fraction <= 1) return fraction;
    const exit = (-bb + @sqrt(disc)) / (2 * aa);
    if (exit >= 0 and exit <= 1) return exit;
    return null;
}

fn rayCapsuleFraction(start: Vec3, delta: Vec3, actor: Actor) ?f32 {
    const radius = @as(f32, @floatFromInt(actor.radius_fixed)) / units_per_meter;
    const height = @as(f32, @floatFromInt(actor.height_fixed)) / units_per_meter;
    const lower = actor.bottom.y + radius;
    const upper = actor.bottom.y + height - radius;
    var best: ?f32 = null;
    const ox = start.x - actor.bottom.x;
    const oz = start.z - actor.bottom.z;
    const aa = delta.x * delta.x + delta.z * delta.z;
    if (aa > 0) {
        const bb = 2 * (ox * delta.x + oz * delta.z);
        const cc = ox * ox + oz * oz - radius * radius;
        const disc = bb * bb - 4 * aa * cc;
        if (disc >= 0) {
            const roots = [2]f32{ (-bb - @sqrt(disc)) / (2 * aa), (-bb + @sqrt(disc)) / (2 * aa) };
            for (roots) |t| {
                const y = start.y + delta.y * t;
                if (t >= 0 and t <= 1 and y >= lower and y <= upper and
                    (best == null or t < best.?)) best = t;
            }
        }
    }
    const low = raySphereFraction(start, delta, .{ .x = actor.bottom.x, .y = lower, .z = actor.bottom.z }, radius);
    const high = raySphereFraction(start, delta, .{ .x = actor.bottom.x, .y = upper, .z = actor.bottom.z }, radius);
    if (low) |t| if (best == null or t < best.?) { best = t; };
    if (high) |t| if (best == null or t < best.?) { best = t; };
    return best;
}

export fn kookie_box3d_cast_ray_actors_fixed(
    ignore_actor_slot: c_int,
    start_x: c_int, start_y: c_int, start_z: c_int,
    end_x: c_int, end_y: c_int, end_z: c_int,
) callconv(.c) c_int {
    server_result_actor_slot = -1;
    if (ignore_actor_slot < -1 or ignore_actor_slot >= @as(c_int, @intCast(max_actors))) return -1;
    const handle = server_world orelse return -1;
    const static_status = kookie_box3d_cast_ray_fixed(start_x, start_y, start_z, end_x, end_y, end_z);
    if (static_status < 0) return -1;
    const world: *World = @ptrCast(@alignCast(handle));
    const start = Vec3{
        .x = @as(f32, @floatFromInt(start_x)) / units_per_meter,
        .y = @as(f32, @floatFromInt(start_y)) / units_per_meter,
        .z = @as(f32, @floatFromInt(start_z)) / units_per_meter,
    };
    const delta = Vec3{
        .x = @as(f32, @floatFromInt(end_x - start_x)) / units_per_meter,
        .y = @as(f32, @floatFromInt(end_y - start_y)) / units_per_meter,
        .z = @as(f32, @floatFromInt(end_z - start_z)) / units_per_meter,
    };
    var best: f32 = 1;
    if (static_status == 1) {
        const dx = delta.x;
        const dy = delta.y;
        const dz = delta.z;
        const length_sq = dx * dx + dy * dy + dz * dz;
        if (length_sq > 0) {
            const hit = server_result.position;
            best = ((hit.x - start.x) * dx + (hit.y - start.y) * dy +
                (hit.z - start.z) * dz) / length_sq;
        } else {
            best = 0;
        }
    }
    var actor_hit: ?usize = null;
    for (world.actors, 0..) |actor, i| {
        if (ignore_actor_slot >= 0 and
            i == @as(usize, @intCast(ignore_actor_slot))) continue;
        if (actor) |registered| {
            if (rayCapsuleFraction(start, delta, registered)) |fraction| {
                if (fraction < best) {
                    best = fraction;
                    actor_hit = i;
                }
            }
        }
    }
    if (actor_hit) |i| {
        server_result_actor_slot = @intCast(i);
        server_result.position = .{ .x = start.x + delta.x * best, .y = start.y + delta.y * best, .z = start.z + delta.z * best };
        server_result.contact_count = 1;
        server_result.grounded = 0;
        return 2;
    }
    return static_status;
}
export fn kookie_box3d_result_actor_slot() callconv(.c) c_int {
    return server_result_actor_slot;
}


export fn kookie_box3d_result_x_fixed() callconv(.c) c_int { return fixedResult(server_result.position.x); }
export fn kookie_box3d_result_y_fixed() callconv(.c) c_int { return fixedResult(server_result.position.y); }
export fn kookie_box3d_result_z_fixed() callconv(.c) c_int { return fixedResult(server_result.position.z); }
export fn kookie_box3d_result_grounded() callconv(.c) bool { return server_result.grounded != 0; }
export fn kookie_box3d_result_contacts() callconv(.c) c_int { return @intCast(server_result.contact_count); }
export fn kookie_box3d_result_normal_x_milli() callconv(.c) c_int { return @intFromFloat(server_result.contact_normal.x * 1000); }
export fn kookie_box3d_result_normal_y_milli() callconv(.c) c_int { return @intFromFloat(server_result.contact_normal.y * 1000); }
export fn kookie_box3d_result_normal_z_milli() callconv(.c) c_int { return @intFromFloat(server_result.contact_normal.z * 1000); }
export fn kookie_box3d_result_plane_offset_milli() callconv(.c) c_int { return @intFromFloat(server_result.contact_offset * 1000); }
export fn kookie_box3d_result_shape_index() callconv(.c) c_int { return server_result.contact_shape; }

/// Move one vertical capsule by requested translation, using Box3D's swept mover and
/// contact-plane solver. Position, translation and capsule dimensions use KOOKIE fixed coordinates.
/// `capsule_height` is the full end-to-end height and must be >= 2 * radius.
export fn kookie_box3d_move(handle: ?*anyopaque, position: Vec3, translation: Vec3, radius_units: f32, capsule_height_units: f32, out_result_arg: ?*Result) callconv(.c) c_int {
    const out_result = out_result_arg orelse return @intFromEnum(Error.invalid_argument);
    out_result.* = .{ .position = position, .contact_normal = .{ .x = 0, .y = 0, .z = 0 }, .contact_count = 0, .grounded = 0 };
    const ptr = handle orelse return @intFromEnum(Error.invalid_argument);
    if (!finite(position.x) or !finite(position.y) or !finite(position.z) or !finite(translation.x) or !finite(translation.y) or !finite(translation.z) or !finite(radius_units) or !finite(capsule_height_units) or @abs(position.x) > max_world_units or @abs(position.y) > max_world_units or @abs(position.z) > max_world_units or @abs(translation.x) > max_world_units or @abs(translation.y) > max_world_units or @abs(translation.z) > max_world_units or radius_units <= 0 or capsule_height_units < 2 * radius_units or capsule_height_units > max_world_units or radius_units > max_world_units) return @intFromEnum(Error.invalid_argument);
    const world: *World = @ptrCast(@alignCast(ptr));
    const r = radius_units / units_per_meter;
    const height = capsule_height_units / units_per_meter;
    const capsule: c.b3Capsule = .{
        .center1 = v3(0, r, 0),
        .center2 = v3(0, height - r, 0),
        .radius = r,
    };
    const origin: c.b3Pos = .{ .x = position.x / units_per_meter, .y = position.y / units_per_meter, .z = position.z / units_per_meter };
    const delta = v3(translation.x / units_per_meter, translation.y / units_per_meter, translation.z / units_per_meter);
    var filter = c.b3DefaultQueryFilter();
    filter.maskBits &= static_query_mask;
    const fraction = c.b3World_CastMover(world.world_id, origin, &capsule, delta, filter, null, null);
    if (!finite(fraction) or fraction < 0 or fraction > 1) return @intFromEnum(Error.box3d_failure);
    const remaining = v3(delta.x * (1 - fraction), delta.y * (1 - fraction), delta.z * (1 - fraction));
    var moved = v3(delta.x * fraction, delta.y * fraction, delta.z * fraction);
    const impact_origin: c.b3Pos = .{ .x = origin.x + moved.x, .y = origin.y + moved.y, .z = origin.z + moved.z };
    var planes = PlaneBuffer{};
    c.b3World_CollideMover(world.world_id, impact_origin, &capsule, filter, gatherPlane, &planes);
    if (planes.overflow) return @intFromEnum(Error.plane_capacity_exceeded);
    if (planes.count > 0) {
        const solved = c.b3SolvePlanes(remaining, &planes.items, @intCast(planes.count));
        moved.x += solved.delta.x;
        moved.y += solved.delta.y;
        moved.z += solved.delta.z;
    } else {
        moved.x += remaining.x;
        moved.y += remaining.y;
        moved.z += remaining.z;
    }
    const nrm_len = @sqrt(planes.contact_normal.x * planes.contact_normal.x + planes.contact_normal.y * planes.contact_normal.y + planes.contact_normal.z * planes.contact_normal.z);
    if (nrm_len > 0) {
        planes.contact_normal.x /= nrm_len;
        planes.contact_normal.y /= nrm_len;
        planes.contact_normal.z /= nrm_len;
    }
    var final_position = Vec3{
        .x = origin.x + moved.x,
        .y = origin.y + moved.y,
        .z = origin.z + moved.z,
    };
    const grounded = planes.grounded;
    if (grounded and translation.y <= 0) {
        const horizontal_distance = @sqrt(delta.x * delta.x + delta.z * delta.z);
        const allowed_rise = step_rise_limit + horizontal_distance * slope_rise_per_run;
        if (groundHeightAt(final_position.x, final_position.z, final_position.y, allowed_rise)) |ground_y| {
            final_position.y = ground_y;
        }
    }
    out_result.* = .{
        .position = .{ .x = final_position.x * units_per_meter, .y = final_position.y * units_per_meter, .z = final_position.z * units_per_meter },
        .contact_normal = planes.contact_normal,
        .contact_count = @intCast(planes.count),
        .grounded = @intFromBool(grounded),
        .contact_offset = if (planes.count > 0)
            planes.contact_offset / @as(f32, @floatFromInt(planes.count))
        else
            0,
        .contact_shape = planes.shape_index,
    };
    return @intFromEnum(Error.ok);
}

test "bounded arena sweep blocks motion and reports ground contact" {
    const vertices = [_]f32{ -80, 0, -80, 80, 0, -80, 80, 0, 80, -80, 0, 80 };
    const indices = [_]i32{ 0, 2, 1, 0, 3, 2 };
    var handle: ?*anyopaque = null;
    try std.testing.expectEqual(@as(c_int, 0), kookie_box3d_create(vertices[0..].ptr, 4, &indices, 2, &handle));
    defer kookie_box3d_destroy(handle);
    var result: Result = undefined;
    try std.testing.expectEqual(@as(c_int, 0), kookie_box3d_move(handle, .{ .x = 0, .y = 96, .z = 0 }, .{ .x = 0, .y = -96, .z = 0 }, 2, 16, &result));
    try std.testing.expect(result.position.y >= -1.0);
    try std.testing.expect(result.grounded != 0);
    try std.testing.expect(result.contact_count > 0);
    try std.testing.expect(result.contact_normal.y > 0.7);
}


test "arena builder preserves fixed-scale ramp triangles" {
    try std.testing.expect(kookie_box3d_begin_arena(4));
    try std.testing.expect(kookie_box3d_add_arena_triangle(
        0, 0, 0, 2560, 0, 0, 2560, 0, 2240,
    ));
    try std.testing.expect(kookie_box3d_add_arena_triangle(
        0, 0, 0, 2560, 0, 2240, 0, 0, 2240,
    ));
    try std.testing.expect(kookie_box3d_add_arena_triangle(
        160, 0, 448, 160, 0, 640, 320, 64, 640,
    ));
    try std.testing.expect(kookie_box3d_add_arena_triangle(
        160, 0, 448, 320, 64, 640, 320, 64, 448,
    ));
    try std.testing.expectEqual(@as(usize, 2), building_collision_count);
    try std.testing.expect(kookie_box3d_finish_arena());
    defer kookie_box3d_destroy_arena();
    const ramp_y = groundHeightAt(21, 68, 0, 2.5);
    try std.testing.expect(ramp_y != null);
    try std.testing.expect(@abs(ramp_y.? - 0.4) < 0.01);
    var x: c_int = 16 * 8;
    var y: c_int = 1 * 8;
    var z: c_int = 68 * 8;
    for (0..24) |_| {
        try std.testing.expectEqual(@as(c_int, 0), kookie_box3d_move_fixed(
            x, y, z, x + 8, y - 1, z, 2, 16, true,
        ));
        x = kookie_box3d_result_x_fixed();
        y = kookie_box3d_result_y_fixed();
        z = kookie_box3d_result_z_fixed();
    }
    try std.testing.expect(kookie_box3d_result_grounded());
    try std.testing.expect(y > 8);
}

test "arena ramp reaches raised lane with perimeter wall present" {
    try std.testing.expect(kookie_box3d_begin_arena(18));
    try std.testing.expect(kookie_box3d_add_arena_triangle(
        0, 0, 0, 2560, 0, 0, 2560, 0, 2240,
    ));
    try std.testing.expect(kookie_box3d_add_arena_triangle(
        0, 0, 0, 2560, 0, 2240, 0, 0, 2240,
    ));
    try std.testing.expect(kookie_box3d_add_arena_triangle(
        160, 0, 448, 160, 0, 640, 320, 64, 640,
    ));
    try std.testing.expect(kookie_box3d_add_arena_triangle(
        160, 0, 448, 320, 64, 640, 320, 64, 448,
    ));
    try std.testing.expect(kookie_box3d_add_arena_triangle(
        288, 64, 512, 288, 64, 1728, 288, 88, 512,
    ));
    try std.testing.expect(kookie_box3d_add_arena_triangle(
        288, 64, 1728, 288, 88, 512, 288, 88, 1728,
    ));
    try std.testing.expect(kookie_box3d_add_arena_triangle(
        288, 64, 512, 768, 64, 512, 768, 88, 512,
    ));
    try std.testing.expect(kookie_box3d_add_arena_triangle(
        288, 64, 512, 768, 88, 512, 288, 88, 512,
    ));
    try std.testing.expect(kookie_box3d_add_arena_triangle(
        768, 64, 1728, 288, 64, 1728, 288, 88, 1728,
    ));
    try std.testing.expect(kookie_box3d_add_arena_triangle(
        768, 64, 1728, 288, 88, 1728, 768, 88, 1728,
    ));
    try std.testing.expect(kookie_box3d_add_arena_triangle(
        768, 64, 512, 768, 64, 1728, 768, 88, 1728,
    ));
    try std.testing.expect(kookie_box3d_add_arena_triangle(
        768, 64, 512, 768, 88, 1728, 768, 88, 512,
    ));
    try std.testing.expect(kookie_box3d_add_arena_triangle(
        288, 88, 512, 768, 88, 512, 768, 88, 1728,
    ));
    try std.testing.expect(kookie_box3d_add_arena_triangle(
        288, 88, 512, 768, 88, 1728, 288, 88, 1728,
    ));
    try std.testing.expect(kookie_box3d_add_arena_triangle(
        288, 64, 1728, 768, 64, 1728, 768, 64, 512,
    ));
    try std.testing.expect(kookie_box3d_add_arena_triangle(
        288, 64, 1728, 768, 64, 512, 288, 64, 512,
    ));
    try std.testing.expect(kookie_box3d_add_arena_triangle(
        0, 0, 0, 0, 192, 2240, 0, 192, 0,
    ));
    try std.testing.expect(kookie_box3d_add_arena_triangle(
        0, 0, 0, 0, 0, 2240, 0, 192, 2240,
    ));
    try std.testing.expectEqual(@as(usize, 16), building_collision_count);
    try std.testing.expect(kookie_box3d_finish_arena());
    defer kookie_box3d_destroy_arena();
    var x: c_int = 16 * 8;
    var y: c_int = 1 * 8;
    var z: c_int = 68 * 8;
    for (0..24) |_| {
        try std.testing.expectEqual(@as(c_int, 0), kookie_box3d_move_fixed(
            x, y, z, x + 8, y - 1, z, 2, 4, true,
        ));
        x = kookie_box3d_result_x_fixed();
        y = kookie_box3d_result_y_fixed();
        z = kookie_box3d_result_z_fixed();
    }
    try std.testing.expect(kookie_box3d_result_grounded());
    try std.testing.expect(x >= 38 * 8);
}
test "boundary hull blocks approaches without ghosting distant sweeps" {
    try std.testing.expect(kookie_box3d_begin_arena(1));
    try std.testing.expect(kookie_box3d_add_arena_triangle(
        0, 0, 0, 2560, 0, 0, 2560, 0, 2240,
    ));
    try std.testing.expect(kookie_box3d_add_arena_box(
        0, 0, 0, 32, 192, 2240,
    ));
    try std.testing.expect(kookie_box3d_finish_arena());
    defer kookie_box3d_destroy_arena();
    try std.testing.expectEqual(@as(c_int, 0), kookie_box3d_move_fixed(
        254, 8, 544, 262, 8, 544, 2, 4, true,
    ));
    try std.testing.expect(kookie_box3d_result_x_fixed() > 260);
    try std.testing.expectEqual(@as(c_int, 0), kookie_box3d_move_fixed(
        40, 8, 544, 24, 8, 544, 2, 4, true,
    ));
    try std.testing.expect(kookie_box3d_result_x_fixed() > 24);
    try std.testing.expect(kookie_box3d_result_x_fixed() < 40);
    try std.testing.expectEqual(@as(c_int, 0), kookie_box3d_cast_ray_fixed(
        254, 8, 544, 262, 8, 544,
    ));
    try std.testing.expectEqual(@as(c_int, 1), kookie_box3d_cast_ray_fixed(
        40, 8, 544, 24, 8, 544,
    ));
}

test "capsule clears raised lane wall while below its underside" {
    const vertices = [_]f32{
        0,    0, 0,    2560, 0, 0,    2560, 0, 2240,    0, 0, 2240,
        288, 64, 512,  288, 88, 512,  288, 88, 1728,   288, 64, 1728,
    };
    const indices = [_]i32{ 0, 2, 1, 0, 3, 2, 4, 6, 5, 4, 7, 6 };
    var handle: ?*anyopaque = null;
    try std.testing.expectEqual(@as(c_int, 0), kookie_box3d_create(
        vertices[0..].ptr, 8, &indices, 4, &handle,
    ));
    defer kookie_box3d_destroy(handle);
    var result: Result = undefined;
    try std.testing.expectEqual(@as(c_int, 0), kookie_box3d_move(
        handle,
        .{ .x = 31.75, .y = 4.75, .z = 68 },
        .{ .x = 1, .y = 0, .z = 0 },
        0.25,
        0.5,
        &result,
    ));
    try std.testing.expect(result.position.x > 32.7);
}

test "invalid triangle indices return explicit error" {
    const vertices = [_]f32{ 0, 0, 0, 1, 0, 0, 0, 0, 1 };
    const indices = [_]i32{ 0, 1, 3 };
    var handle: ?*anyopaque = null;
    try std.testing.expectEqual(@as(c_int, 1), kookie_box3d_create(vertices[0..].ptr, 3, indices[0..].ptr, 1, &handle));
    try std.testing.expect(handle == null);
}

test "arena actor capsules overlap, raycast, remove, and reuse slots" {
    try std.testing.expect(kookie_box3d_begin_arena(1));
    try std.testing.expect(kookie_box3d_add_arena_triangle(
        0, 0, 0, 0, 0, 800, 800, 0, 0,
    ));
    try std.testing.expect(kookie_box3d_finish_arena());
    defer kookie_box3d_destroy_arena();
    try std.testing.expectEqual(@as(c_int, 0), kookie_box3d_set_actor_capsule(4, 800, 0, 200, 32, 128));
    try std.testing.expect(kookie_box3d_overlap_actor_capsule_fixed(3, 816, 0, 200, 32, 128));
    try std.testing.expect(!kookie_box3d_overlap_actor_capsule_fixed(4, 1200, 0, 200, 32, 128));
    try std.testing.expectEqual(@as(c_int, 2), kookie_box3d_cast_ray_actors_fixed(
        -1, 0, 64, 200, 1600, 64, 200,
    ));
    try std.testing.expectEqual(@as(c_int, 4), kookie_box3d_result_actor_slot());
    try std.testing.expectEqual(@as(c_int, 0), kookie_box3d_cast_ray_fixed(
        0, 64, 200, 1600, 64, 200,
    ));
    kookie_box3d_clear_actor(4);
    try std.testing.expectEqual(@as(c_int, 0), kookie_box3d_cast_ray_actors_fixed(
        -1, 0, 64, 200, 1600, 64, 200,
    ));
    try std.testing.expectEqual(@as(c_int, -1), kookie_box3d_result_actor_slot());
    try std.testing.expectEqual(@as(c_int, 0), kookie_box3d_set_actor_capsule(4, 1200, 0, 200, 32, 128));
    try std.testing.expectEqual(@as(c_int, 2), kookie_box3d_cast_ray_actors_fixed(
        -1, 800, 64, 200, 1600, 64, 200,
    ));
    try std.testing.expectEqual(@as(c_int, 4), kookie_box3d_result_actor_slot());
    try std.testing.expectEqual(@as(c_int, 0), kookie_box3d_cast_ray_actors_fixed(
        4, 800, 64, 200, 1600, 64, 200,
    ));
    try std.testing.expectEqual(@as(c_int, -1), kookie_box3d_result_actor_slot());
    try std.testing.expectEqual(@as(c_int, -1), kookie_box3d_cast_ray_actors_fixed(
        12, 0, 64, 200, 1600, 64, 200,
    ));
    try std.testing.expectEqual(@as(c_int, 1), kookie_box3d_set_actor_capsule(12, 0, 0, 0, 1, 2));
    try std.testing.expectEqual(@as(c_int, 1), kookie_box3d_set_actor_capsule(0, 0, 0, 0, 0, 2));
    try std.testing.expectEqual(@as(c_int, 1), kookie_box3d_set_actor_capsule(0, 80_000_001, 0, 0, 1, 2));
}

test "actor ray reports nearer static wall instead of occluded capsule" {
    try std.testing.expect(kookie_box3d_begin_arena(1));
    try std.testing.expect(kookie_box3d_add_arena_triangle(
        640, 0, 0, 640, 0, 800, 640, 800, 0,
    ));
    try std.testing.expect(kookie_box3d_finish_arena());
    defer kookie_box3d_destroy_arena();
    try std.testing.expectEqual(@as(c_int, 0), kookie_box3d_set_actor_capsule(2, 1200, 0, 200, 32, 128));
    try std.testing.expectEqual(@as(c_int, 1), kookie_box3d_cast_ray_actors_fixed(
        -1, 0, 64, 200, 1600, 64, 200,
    ));
    try std.testing.expectEqual(@as(c_int, -1), kookie_box3d_result_actor_slot());
}
