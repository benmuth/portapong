// followed https://zig.news/perky/hot-reloading-with-raylib-4bf9
const std = @import("std");
const rl = @import("raylib");
const g = @import("game");

// TODO
// - watch the modified time on the configuration files inside main, if they've been modified, trigger a reload.
// - recompile the dylib on a separate thread to avoid the game freeze.
//     - tweak build system:
//         - write the editor dylib to a temporary file
//         - unload, overwrite the dylib from the temporary one, and re-load.
// - draw the output of the compilation on-screen, maybe in a custom debug window or in-editor console.

const dylib_name = "zig-out/lib/libgame.0.0.1.dylib";

fn rlColor(color: g.Color) rl.Color {
    return rl.Color{
        .r = color.r,
        .g = color.g,
        .b = color.b,
        .a = color.a,
    };
}

const GamePtr = *anyopaque;

// Import game types - we'll need to redeclare them to match the dylib
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

const GameCode = struct {
    dyn_lib: ?std.DynLib = null,
    dynlib_last_write_time: std.Io.Timestamp = .zero,

    initState: ?*const fn (u32, u32) callconv(.c) GamePtr = null,
    deinit: ?*const fn (GamePtr) callconv(.c) void = null,
    reload: ?*const fn (GamePtr) callconv(.c) void = null,
    updateAndRender: ?*const fn (GamePtr, ?*const InputState) callconv(.c) void = null,
    getDrawState: ?*const fn (GamePtr, ?*DrawState) callconv(.c) void = null,

    is_valid: bool = false,
};

var global_gc: GameCode = .{};

// var initState: *const fn (u32, u32) callconv(.c) GamePtr = undefined;
// var deinit: *const fn (GamePtr) callconv(.c) void = undefined;
// var reload: *const fn (GamePtr) callconv(.c) void = undefined;
// var updateAndRender: *const fn (GamePtr, *const InputState) callconv(.c) void = undefined;
// var getDrawState: *const fn (GamePtr, *DrawState) callconv(.c) void = undefined;

pub fn main(init: std.process.Init) !void {
    const arena = init.arena;
    const allocator = arena.allocator();
    loadGameDynlib(dylib_name);

    const window_width = 800;
    const window_height = 450;
    const game_state = global_gc.initState.?(window_width, window_height);
    std.debug.print("Initial state: {any}\n", .{game_state});

    rl.setConfigFlags(.{ .window_resizable = true, .window_highdpi = true });
    rl.initWindow(window_width, window_height, "portapong");
    rl.setTargetFPS(60);

    // WindowShouldClose will return true if the user presses ESC.
    while (!rl.windowShouldClose()) {
        if (rl.isKeyPressed(rl.KeyboardKey.slash)) {
            unloadGameDynlib(&global_gc) catch unreachable;
            recompileGameDynlib(init.io, allocator) catch {
                std.debug.print("failed to recompile", .{});
            };
            loadGameDynlib(dylib_name);
            if (global_gc.reload) |reload| {
                reload(game_state);
            }
        }

        // Collect input
        const input = InputState{
            .p1_up = rl.isKeyDown(rl.KeyboardKey.w),
            .p1_down = rl.isKeyDown(rl.KeyboardKey.s),
            .p2_up = rl.isKeyDown(rl.KeyboardKey.up),
            .p2_down = rl.isKeyDown(rl.KeyboardKey.down),
        };

        // Update game state
        if (global_gc.updateAndRender) |updateAndRender| {
            updateAndRender(game_state, &input);
        }

        // Get what to draw
        var draw_state: DrawState = undefined;
        if (global_gc.getDrawState) |getDrawState| {
            getDrawState(game_state, &draw_state);
        }
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

fn loadGameDynlib(src_dylib_name: []const u8) void {
    const dyn_lib: ?std.DynLib = std.DynLib.open(src_dylib_name) catch blk: {
        global_gc.dyn_lib = null;
        global_gc.initState = null;
        global_gc.deinit = null;
        global_gc.reload = null;
        global_gc.updateAndRender = null;
        global_gc.getDrawState = null;
        global_gc.is_valid = false;
        break :blk null;
    };

    global_gc.dyn_lib = dyn_lib;

    if (global_gc.dyn_lib) |*dl| {
        global_gc.initState = dl.lookup(@TypeOf(global_gc.initState.?), "initState");
        global_gc.deinit = dl.lookup(@TypeOf(global_gc.deinit.?), "deinit");
        global_gc.reload = dl.lookup(@TypeOf(global_gc.reload.?), "reload");
        global_gc.updateAndRender = dl.lookup(@TypeOf(global_gc.updateAndRender.?), "updateAndRender");
        global_gc.getDrawState = dl.lookup(@TypeOf(global_gc.getDrawState.?), "getDrawState");

        global_gc.is_valid = global_gc.initState != null and
            global_gc.deinit != null and
            global_gc.reload != null and
            global_gc.updateAndRender != null and
            global_gc.getDrawState != null;
    }

    if (!global_gc.is_valid) {
        global_gc.initState = null;
        global_gc.deinit = null;
        global_gc.reload = null;
        global_gc.updateAndRender = null;
        global_gc.getDrawState = null;
    }
    std.debug.print("Loaded dll\n", .{});
}

fn unloadGameDynlib(gc: *GameCode) !void {
    if (gc.dyn_lib) |*dyn_lib| {
        dyn_lib.close();
        gc.dyn_lib = null;
    } else {
        return error.AlreadyUnloaded;
    }
}

fn recompileGameDynlib(io: std.Io, allocator: std.mem.Allocator) !void {
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
