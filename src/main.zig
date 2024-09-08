//! followed https://zig.news/perky/hot-reloading-with-raylib-4bf9
const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});

// TODO
// - watch the modified time on the configuration files inside main, if they've been modified, trigger a reload.
// - recompile the DLL on a separate thread to avoid the game freeze.
//     - tweak build system:
//         - write the editor DLL to a temporary file
//         - unload, overwrite the DLL from the temporary one, and re-load.
// - draw the output of the compilation on-screen, maybe in a custom debug window or in-editor console.

const GamePtr = *anyopaque;

var init: *const fn (c_int, c_int) GamePtr = undefined;
var reload: *const fn (GamePtr) void = undefined;
var update: *const fn (GamePtr) void = undefined;
var draw: *const fn (GamePtr) void = undefined;

const window_width = 800;
const window_height = 450;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    loadGameDll() catch @panic("failed to load");

    const game_state = init(window_width, window_height);

    rl.InitWindow(window_width, window_height, "portapong");
    rl.SetTargetFPS(20);

    // WindowShouldClose will return true if the user presses ESC.
    while (!rl.WindowShouldClose()) {
        if (rl.IsKeyPressed(rl.KEY_SLASH)) {
            unloadGameDll() catch unreachable;
            recompileGameDll(allocator) catch {
                std.debug.print("failed to recompile", .{});
            };
            loadGameDll() catch @panic("failed to load");
            reload(game_state);
        }
        update(game_state);
        draw(game_state);
    }

    rl.CloseWindow();
}

var editor_dyn_lib: ?std.DynLib = null;
fn loadGameDll() !void {
    if (editor_dyn_lib != null) return error.AlreadyLoaded;

    var dyn_lib = std.DynLib.open("zig-out/lib/libgame.0.0.1.dylib") catch {
        return error.OpenFail;
    };
    editor_dyn_lib = dyn_lib;

    init = dyn_lib.lookup(@TypeOf(init), "init") orelse return error.lookupFail;
    reload = dyn_lib.lookup(@TypeOf(reload), "reload") orelse return error.lookupFail;
    update = dyn_lib.lookup(@TypeOf(update), "update") orelse return error.lookupFail;
    draw = dyn_lib.lookup(@TypeOf(draw), "draw") orelse return error.lookupFail;

    std.debug.print("Loaded dll\n", .{});
}

fn unloadGameDll() !void {
    if (editor_dyn_lib) |*dyn_lib| {
        dyn_lib.close();
        editor_dyn_lib = null;
    } else {
        return error.AlreadyUnloaded;
    }
}

fn recompileGameDll(arena: std.mem.Allocator) !void {
    const process_args = [_][]const u8{
        "zig",
        "build",
        "-Dgame_only=true",
    };
    var build_process = std.process.Child.init(&process_args, arena);
    try build_process.spawn();
    // wait() returns a tagged union. If the compilations fails that union
    // will be in the state .{ .Exited = 2 }
    const term = try build_process.wait();
    switch (term) {
        .Exited => |exited| {
            if (exited == 2) return error.RecompileFail;
        },
        else => return,
    }
}
