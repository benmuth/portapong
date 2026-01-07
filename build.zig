const std = @import("std");

pub fn build(b: *std.Build) void {
    const game_only = b.option(bool, "game_only", "only build the shared game library") orelse false;
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    if (target.result.os.tag != .macos) {
        @panic("Unsupported OS");
    }

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
        .shared = true,
    });

    const game_lib = b.addSharedLibrary(.{
        .name = "game",
        .root_source_file = .{ .src_path = .{ .sub_path = "src/game.zig", .owner = b } },
        .target = target,
        .optimize = optimize,
        .version = .{ .major = 0, .minor = 0, .patch = 1 },
    });

    const raylib = raylib_dep.module("raylib");
    const raygui = raylib_dep.module("raygui");
    const raylib_artifact = raylib_dep.artifact("raylib");

    game_lib.root_module.addImport("raylib", raylib);
    game_lib.root_module.addImport("raygui", raygui);
    game_lib.linkLibrary(raylib_artifact);

    b.installArtifact(game_lib);

    // recompile the whole thing if not passed '-game_only=true'
    if (!game_only) {
        const exe = b.addExecutable(.{
            .name = "portapong",
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        });

        exe.root_module.addImport("raylib", raylib);
        exe.root_module.addImport("raygui", raygui);
        exe.linkLibrary(raylib_artifact);

        // the "check" step helps zls
        {
            // codegen only runs if zig build sees a dependency on the binary output of
            // the step. So we duplicate the build definition so that it doesn't get polluted by
            // b.installArtifact.
            const lib_check = b.addSharedLibrary(.{
                .name = "check",
                .root_source_file = b.path("src/game.zig"),
                .target = target,
                .optimize = optimize,
            });

            lib_check.root_module.addImport("raylib", raylib);
            lib_check.root_module.addImport("raygui", raygui);
            lib_check.linkLibrary(raylib_artifact);

            const check = b.step("check", "Check if it compiles");
            check.dependOn(&lib_check.step);
        }

        b.installArtifact(exe);
        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);
    }
}
