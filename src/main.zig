//! followed https://zig.news/perky/hot-reloading-with-raylib-4bf9
const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});

// TODO
// - watch the modified time on the configuration files inside main, if they've been modified, trigger a reload.
// - recompile the DLL on a separate thread to avoid the editor freeze.
//     - tweak build system:
//         - write the editor DLL to a temporary file
//         - unload, overwrite the DLL from the temporary one, and re-load.
// - draw the output of the compilation on-screen, maybe in a custom debug window or in-editor console.

const screen_w = 800;
const screen_h = 450;

const EditorPtr = *anyopaque;

var init: *const fn () EditorPtr = undefined;
var reload: *const fn (EditorPtr) void = undefined;
var update: *const fn (EditorPtr) void = undefined;
var draw: *const fn (EditorPtr) void = undefined;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    loadEditorDll() catch @panic("failed to load");

    const editor_state = init();

    rl.InitWindow(screen_w, screen_h, "BF IDE");
    rl.SetTargetFPS(20);

    // WindowShouldClose will return true if the user presses ESC.
    while (!rl.WindowShouldClose()) {
        if (rl.IsKeyPressed(rl.KEY_SLASH)) {
            unloadEditorDll() catch unreachable;
            recompileEditorDll(allocator) catch {
                std.debug.print("failed to recompile", .{});
            };
            loadEditorDll() catch @panic("failed to load");
            reload(editor_state);
        }
        std.debug.print("1\n", .{});
        update(editor_state);
        std.debug.print("2\n", .{});
        std.debug.print("{p}\n", .{editor_state});
        draw(editor_state);
    }

    rl.CloseWindow();
}

var editor_dyn_lib: ?std.DynLib = null;
fn loadEditorDll() !void {
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

fn unloadEditorDll() !void {
    if (editor_dyn_lib) |*dyn_lib| {
        dyn_lib.close();
        editor_dyn_lib = null;
    } else {
        return error.AlreadyUnloaded;
    }
}

fn recompileEditorDll(arena: std.mem.Allocator) !void {
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
