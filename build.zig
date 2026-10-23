const std = @import("std");
const Translator = @import("translate_c").Translator;


pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .fast });
    const translate_c = b.dependency("translate_c", .{});
    const box3d_root = "../DINX/vendor/box3d-0.1.0";
    const box3d_include = box3d_root ++ "/include";
    const box3d_sources = &.{
        "src/aabb.c", "src/arena_allocator.c", "src/bitset.c", "src/block_allocator.c",
        "src/body.c", "src/broad_phase.c", "src/capsule.c", "src/compound.c",
        "src/constraint_graph.c", "src/contact.c", "src/contact_solver.c",
        "src/convex_manifold.c", "src/core.c", "src/distance.c", "src/distance_joint.c",
        "src/dynamic_tree.c", "src/height_field.c", "src/hull.c", "src/id_pool.c",
        "src/island.c", "src/joint.c", "src/manifold.c", "src/math_functions.c",
        "src/mesh.c", "src/mesh_contact.c", "src/motor_joint.c", "src/mover.c",
        "src/parallel_for.c", "src/parallel_joint.c", "src/physics_world.c",
        "src/prismatic_joint.c", "src/recording.c", "src/recording_replay.c",
        "src/revolute_joint.c", "src/scheduler.c", "src/sensor.c", "src/shape.c",
        "src/simd.c", "src/solver.c", "src/solver_set.c", "src/sphere.c",
        "src/spherical_joint.c", "src/table.c", "src/timer.c", "src/triangle_manifold.c",
        "src/types.c", "src/weld_joint.c", "src/wheel_joint.c", "src/world_snapshot.c",
    };
    const box3d_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    box3d_module.addIncludePath(b.path(box3d_include));
    box3d_module.addIncludePath(b.path(box3d_root ++ "/src"));
    box3d_module.addCMacro("BOX3D_DISABLE_SIMD", "1");
    box3d_module.addCSourceFiles(.{
        .root = b.path(box3d_root),
        .files = box3d_sources,
        .flags = &.{ "-std=c17", "-ffp-contract=off" },
    });
    if (target.result.os.tag == .linux or target.result.os.tag == .macos) {
        box3d_module.linkSystemLibrary("m", .{});
    }
    const box3d_c = b.addLibrary(.{
        .name = "kookie_box3d_vendor",
        .linkage = .static,
        .root_module = box3d_module,
    });
    var box3d_bindings = Translator.init(translate_c, .{
        .name = "kookie_box3d_c",
        .c_source_file = b.path("../DINX/vendor/box3d-0.1.0/include/box3d/box3d.h"),
        .target = target,
        .optimize = optimize,
    });
    box3d_bindings.addIncludePath(b.path(box3d_include));
    box3d_bindings.run.addArg("-DBOX3D_DISABLE_SIMD=1");
    box3d_bindings.linkLibrary(box3d_c);
    const box3d_adapter = b.createModule(.{
        .root_source_file = b.path("native/kookie_box3d.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{.{ .name = "box3d_c", .module = box3d_bindings.mod }},
    });
    box3d_adapter.linkLibrary(box3d_c);
    const box3d_library = b.addLibrary(.{
        .name = "kookie_box3d",
        .linkage = .dynamic,
        .root_module = box3d_adapter,
    });
    b.installArtifact(box3d_library);
    const run_box3d_tests = b.addRunArtifact(b.addTest(.{ .root_module = box3d_adapter }));
    const check_box3d = b.step("check-box3d-adapter", "Run isolated Box3D adapter tests against DINX's pinned Box3D sources");
    check_box3d.dependOn(&run_box3d_tests.step);

    const bindings = Translator.init(translate_c, .{
        .name = "kookie_web_server_c",
        .c_source_file = b.path("native/kookie_web_server_bindings.h"),
        .target = target,
        .optimize = optimize,
    });

    const adapter = b.createModule(.{
        .root_source_file = b.path("native/kookie_web_server.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{.{ .name = "c", .module = bindings.mod }},
    });
    if (target.result.os.tag == .linux or target.result.os.tag == .macos) {
        adapter.linkSystemLibrary("pthread", .{});
    } else if (target.result.os.tag == .windows) {
        adapter.linkSystemLibrary("ws2_32", .{});
    }

    const library = b.addLibrary(.{
        .name = "kookie_web_server",
        .linkage = .dynamic,
        .root_module = adapter,
    });
    b.installArtifact(library);

    const run_tests = b.addRunArtifact(b.addTest(.{ .root_module = adapter }));
    const check = b.step("check-web-transport", "Run Zig WebSocket transport unit tests");
    check.dependOn(&run_tests.step);
}
