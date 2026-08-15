const std = @import("std");

pub fn build(b: *std.Build) void {
    const game_only = b.option(bool, "game_only", "only build the shared game library") orelse false;
    const sign = b.option(bool, "sign", "codesign the executable so Instruments can attach") orelse false;
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    if (target.result.os.tag != .macos) {
        @panic("Unsupported OS");
    }

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib");
    const raygui = raylib_dep.module("raygui");
    const raylib_artifact = raylib_dep.artifact("raylib");

    const game_mod = b.createModule(.{
        .root_source_file = b.path("src/game.zig"),
        .target = target,
        .optimize = optimize,
    });

    const game_lib = b.addLibrary(.{
        .name = "game",
        .linkage = .dynamic,
        .version = .{ .major = 0, .minor = 0, .patch = 1 },
        .root_module = game_mod,
    });

    b.installArtifact(game_lib);

    // recompile the whole thing if not passed '-game_only=true'
    if (!game_only) {
        const exe_mod = b.createModule(.{
            .root_source_file = b.path("src/raylib.zig"),
            .target = target,
            .optimize = optimize,
        });

        const exe = b.addExecutable(.{
            .name = "portapong",
            .root_module = exe_mod,
        });

        exe.root_module.addImport("raylib", raylib);
        exe.root_module.addImport("raygui", raygui);
        exe.root_module.linkLibrary(raylib_artifact);

        exe.root_module.addImport("game", game_mod);
        // the "check" step helps zls
        {
            // codegen only runs if zig build sees a dependency on the binary output of
            // the step. So we duplicate the build definition so that it doesn't get polluted by
            // b.installArtifact.
            const check_mod = b.createModule(.{
                .root_source_file = b.path("src/game.zig"),
                .target = target,
                .optimize = optimize,
            });

            const lib_check = b.addLibrary(.{
                .name = "check",
                .linkage = .dynamic,
                .root_module = check_mod,
            });

            const check = b.step("check", "Check if it compiles");
            check.dependOn(&lib_check.step);
        }

        const install_exe = b.addInstallArtifact(exe, .{});
        b.getInstallStep().dependOn(&install_exe.step);

        // linking drops the entitlement, so re-sign the installed binary
        if (sign) {
            const sign_cmd = b.addSystemCommand(&.{b.pathFromRoot("sign.sh")});
            sign_cmd.addArg(b.getInstallPath(.bin, exe.out_filename));
            sign_cmd.step.dependOn(&install_exe.step);
            b.getInstallStep().dependOn(&sign_cmd.step);
        }

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);
    }
}
