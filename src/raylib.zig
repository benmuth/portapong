//! followed https://zig.news/perky/hot-reloading-with-raylib-4bf9
const std = @import("std");
const rl = @import("raylib");
const g = @import("game");

// TODO
// - watch the modified time on the configuration files inside main, if they've been modified, trigger a reload.
// - recompile the DLL on a separate thread to avoid the game freeze.
//     - tweak build system:
//         - write the editor DLL to a temporary file
//         - unload, overwrite the DLL from the temporary one, and re-load.
// - draw the output of the compilation on-screen, maybe in a custom debug window or in-editor console.

fn rlColor(color: g.Color) rl.Color {
    return rl.Color{
        .r = color.r,
        .g = color.g,
        .b = color.b,
        .a = color.a,
    };
}

const GamePtr = *anyopaque;

// Import game types - we'll need to redeclare them to match the DLL
const DrawState = extern struct {
    p1: rl.Rectangle,
    p2: rl.Rectangle,
    ball_x: f32,
    ball_y: f32,
    ball_radius: f32,
};

const InputState = extern struct {
    p1_up: bool,
    p1_down: bool,
    p2_up: bool,
    p2_down: bool,
};

var initState: *const fn (u32, u32) callconv(.c) GamePtr = undefined;
var deinit: *const fn (GamePtr) callconv(.c) void = undefined;
var reload: *const fn (GamePtr) callconv(.c) void = undefined;
var updateAndRender: *const fn (GamePtr, *const InputState) callconv(.c) void = undefined;
var getDrawState: *const fn (GamePtr, *DrawState) callconv(.c) void = undefined;

pub fn main(init: std.process.Init) !void {
    const arena = init.arena;
    const allocator = arena.allocator();
    loadGameDll() catch @panic("failed to load");

    const window_width = 800;
    const window_height = 450;
    const game_state = initState(window_width, window_height);
    std.debug.print("Initial state: {any}\n", .{game_state});

    rl.setConfigFlags(.{ .window_resizable = true, .window_highdpi = true });
    rl.initWindow(window_width, window_height, "portapong");
    rl.setTargetFPS(60);

    // WindowShouldClose will return true if the user presses ESC.
    while (!rl.windowShouldClose()) {
        if (rl.isKeyPressed(rl.KeyboardKey.slash)) {
            unloadGameDll() catch unreachable;
            recompileGameDll(init.io, allocator) catch {
                std.debug.print("failed to recompile", .{});
            };
            loadGameDll() catch @panic("failed to load");
            reload(game_state);
        }

        // Collect input
        const input = InputState{
            .p1_up = rl.isKeyDown(rl.KeyboardKey.w),
            .p1_down = rl.isKeyDown(rl.KeyboardKey.s),
            .p2_up = rl.isKeyDown(rl.KeyboardKey.up),
            .p2_down = rl.isKeyDown(rl.KeyboardKey.down),
        };

        // Update game state
        updateAndRender(game_state, &input);

        // Get what to draw
        var draw_state: DrawState = undefined;
        getDrawState(game_state, &draw_state);

        // Render
        rl.beginDrawing();
        rl.clearBackground(rl.Color.white);

        // std.debug.print("{any}", .{draw_state.p1});
        rl.drawRectangleRec(draw_state.p1, rlColor(g.paddle_color));
        rl.drawRectangleRec(draw_state.p2, rlColor(g.paddle_color));

        const ball_x: c_int = @intFromFloat(@trunc(draw_state.ball_x));
        const ball_y: c_int = @intFromFloat(@trunc(draw_state.ball_y));
        rl.drawCircle(ball_x, ball_y, draw_state.ball_radius, rlColor(g.ball_color));

        rl.endDrawing();
    }

    // Don't unload the DLL - let the OS clean it up on exit
    // Explicit unloading can trigger atexit handlers that reference freed memory
    rl.closeWindow();
    std.debug.print("Window closed, about to return from main\n", .{});
}

var editor_dyn_lib: ?std.DynLib = null;
fn loadGameDll() !void {
    if (editor_dyn_lib != null) return error.AlreadyLoaded;

    var dyn_lib = std.DynLib.open("zig-out/lib/libgame.0.0.1.dylib") catch {
        return error.OpenFail;
    };
    editor_dyn_lib = dyn_lib;

    initState = dyn_lib.lookup(@TypeOf(initState), "initState") orelse return error.lookupFail;
    deinit = dyn_lib.lookup(@TypeOf(deinit), "deinit") orelse return error.lookupFail;
    reload = dyn_lib.lookup(@TypeOf(reload), "reload") orelse return error.lookupFail;
    updateAndRender = dyn_lib.lookup(@TypeOf(updateAndRender), "updateAndRender") orelse return error.lookupFail;
    getDrawState = dyn_lib.lookup(@TypeOf(getDrawState), "getDrawState") orelse return error.lookupFail;

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

fn recompileGameDll(io: std.Io, allocator: std.mem.Allocator) !void {
    const process_args = [_][]const u8{
        "zig",
        "build",
        "-Dgame_only=true",
    };
    const res = try std.process.run(allocator, io, .{ .argv = &process_args });
    switch (res.term) {
        .exited => |exited| {
            if (exited == 2) return error.RecompileFail;
        },
        else => return,
    }
}
