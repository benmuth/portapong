const std = @import("std");

pub fn build(b: *std.Build) void {
    const game_only = b.option(bool, "game_only", "only build the shared game library") orelse false;
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    if (target.result.os.tag != .macos) {
        @panic("Unsupported OS");
    }

    const raylib_dep = b.dependency("raylib", .{
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

    game_lib.linkLibrary(raylib_dep.artifact("raylib"));
    // game_lib.linkSystemLibrary("raylib");
    // game_lib.linkSystemLibrary("rlgl");
    game_lib.linkFramework("CoreVideo");
    game_lib.linkFramework("IOKit");
    game_lib.linkFramework("Cocoa");
    game_lib.linkFramework("GLUT");
    game_lib.linkFramework("OpenGL");
    game_lib.linkLibC();

    b.installArtifact(game_lib);

    // recompile the whole thing if not passed '-game_only=true'
    if (!game_only) {
        const exe = b.addExecutable(.{
            .name = "portapong",
            // .root_source_file = .{ .src_path = .{ .sub_path = "main.zig", .owner = b } },
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        });

        // the "check" step helps zls
        // {
        //     // codegen only runs if zig build sees a dependency on the binary output of
        //     // the step. So we duplicate the build definition so that it doesn't get polluted by
        //     // b.installArtifact.
        //     const main = b.addExecutable(.{
        //         .name = "check",
        //         .root_source_file = b.path("src/main.zig"),
        //         .target = target,
        //         .optimize = optimize,
        //     });

        //     // main.linkLibrary(raylib_dep.artifact("raylib"));
        //     // main.linkLibrary(raylib_dep.artifact("rlgl"));
        //     main.linkSystemLibrary("raylib");
        //     main.linkFramework("CoreVideo");
        //     main.linkFramework("IOKit");
        //     main.linkFramework("Cocoa");
        //     main.linkFramework("GLUT");
        //     main.linkFramework("OpenGL");
        //     main.linkLibC();

        //     const main_check = b.addExecutable(.{
        //         .name = "check",
        //         .root_source_file = b.path("src/main.zig"),
        //         .target = target,
        //         .optimize = optimize,
        //     });

        //     // main_check.linkLibrary(raylib_dep.artifact("raylib"));
        //     main_check.linkSystemLibrary("raylib");
        //     main_check.linkFramework("CoreVideo");
        //     main_check.linkFramework("IOKit");
        //     main_check.linkFramework("Cocoa");
        //     main_check.linkFramework("GLUT");
        //     main_check.linkFramework("OpenGL");
        //     main_check.linkLibC();

        //     const check = b.step("check", "Check if it compiles");
        //     check.dependOn(&main_check.step);
        // }

        // Link to the Raylib and its required dependencies for macOS.
        exe.linkLibrary(raylib_dep.artifact("raylib"));
        // exe.linkLibrary(raylib_dep.artifact("rlgl"));
        // exe.linkSystemLibrary("raylib");
        // exe.linkSystemLibrary("rlgl");
        exe.linkFramework("CoreVideo");
        exe.linkFramework("IOKit");
        exe.linkFramework("Cocoa");
        exe.linkFramework("GLUT");
        exe.linkFramework("OpenGL");
        exe.linkLibC();

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
