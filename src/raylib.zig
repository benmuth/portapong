// followed https://zig.news/perky/hot-reloading-with-raylib-4bf9
const std = @import("std");
const rl = @import("raylib");
const g = @import("game");

// TODO
// - draw the output of the compilation on-screen, maybe in a custom debug window or in-editor console.

const dyn_lib_name = "zig-out/lib/libgame.0.0.1.dylib";

fn rlColor(color: g.Color) rl.Color {
    return .{
        .r = color.r,
        .g = color.g,
        .b = color.b,
        .a = color.a,
    };
}

fn rlRectangle(r: g.Rectangle) rl.Rectangle {
    return .{
        .height = r.height,
        .width = r.width,
        .x = r.x,
        .y = r.y,
    };
}

const GameCode = struct {
    dyn_lib: ?std.DynLib = null,
    dynlib_last_write_time: std.Io.Timestamp = .zero,

    updateAndRender: ?*const fn (*g.GameMemory, *const g.Input) callconv(.c) void = null,
    is_valid: bool = false,
};

var global_gc: GameCode = .{};
var reload_generation: usize = 0;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const clock = std.Io.Clock.boot;
    _ = clock; // autofix

    const init_arena = init.arena;
    const init_allocator = init_arena.allocator();
    loadGameDynlib(io, dyn_lib_name);

    const window_width = 800;
    const window_height = 450;
    const memory = try init_allocator.alloc(u8, g.permanent_size + g.transient_size);

    var fba_arena_child = std.heap.FixedBufferAllocator.init(memory[g.permanent_size..]);
    var game_arena = std.heap.ArenaAllocator.init(fba_arena_child.allocator());

    var game_fba = std.heap.FixedBufferAllocator.init(memory[0..g.permanent_size]);

    var game_memory: g.GameMemory = .init(&game_fba, &game_arena);

    rl.setConfigFlags(.{ .window_resizable = true, .window_highdpi = true });
    rl.initWindow(window_width, window_height, "portapong");
    rl.setTargetFPS(60);

    const camera: rl.Camera2D = .{
        .offset = .{ .x = window_width / 2, .y = window_height / 2 },
        .rotation = 0,
        .target = .{ .x = 8, .y = 4.5 },
        .zoom = window_width / 16.0,
    };
    // WindowShouldClose will return true if the user presses ESC.
    while (!rl.windowShouldClose()) {
        // Reload dynlib if new
        const new_write_time = getLastWriteTime(io, dyn_lib_name);
        if (new_write_time.nanoseconds != global_gc.dynlib_last_write_time.nanoseconds) {
            // std.debug.print("{any}\n", .{clock.now(io)});
            unloadGameDynlib(&global_gc);
            loadGameDynlib(io, dyn_lib_name);
        }

        // Manually reload dynlib
        if (rl.isKeyPressed(rl.KeyboardKey.slash)) {
            unloadGameDynlib(&global_gc);
            loadGameDynlib(io, dyn_lib_name);
        }

        // Collect input
        const input = g.Input{
            .p1_up = rl.isKeyDown(rl.KeyboardKey.w),
            .p1_down = rl.isKeyDown(rl.KeyboardKey.s),
            .p2_up = rl.isKeyDown(rl.KeyboardKey.up),
            .p2_down = rl.isKeyDown(rl.KeyboardKey.down),
        };

        // Update game state
        if (global_gc.updateAndRender) |updateAndRender| {
            updateAndRender(&game_memory, &input);
        }

        const state: *g.State = @ptrCast(@alignCast(game_memory.permanent_storage.buffer));

        // Render
        rl.beginDrawing();
        rl.clearBackground(rl.Color.white);

        rl.beginMode2D(camera);
        // std.debug.print("{any}", .{draw_state.p1});
        rl.drawRectangleRec(rlRectangle(state.world.p1), rlColor(state.paddle_color));
        rl.drawRectangleRec(rlRectangle(state.world.p2), rlColor(state.paddle_color));

        rl.drawCircleV(.{ .x = state.world.ball.x, .y = state.world.ball.y }, state.world.ball.radius, rlColor(state.ball_color));

        rl.endMode2D();
        rl.endDrawing();
    }

    // Don't unload the DLL - let the OS clean it up on exit
    // Explicit unloading can trigger atexit handlers that reference freed memory
    rl.closeWindow();
    std.debug.print("Window closed, about to return from main\n", .{});
}

fn loadGameDynlib(io: std.Io, src_dylib_name: []const u8) void {
    const dyn_lib: ?std.DynLib = std.DynLib.open(src_dylib_name) catch blk: {
        global_gc.dyn_lib = null;
        global_gc.updateAndRender = null;
        global_gc.is_valid = false;
        break :blk null;
    };

    global_gc.dyn_lib = dyn_lib;

    if (global_gc.dyn_lib) |*dl| {
        global_gc.dynlib_last_write_time = getLastWriteTime(io, dyn_lib_name);
        global_gc.updateAndRender = dl.lookup(@TypeOf(global_gc.updateAndRender.?), "updateAndRender");

        global_gc.is_valid = global_gc.updateAndRender != null;
    }

    if (!global_gc.is_valid) {
        global_gc.updateAndRender = null;
    }
    std.debug.print("Loaded dll\n", .{});
}

fn unloadGameDynlib(gc: *GameCode) void {
    if (gc.dyn_lib) |*dyn_lib| {
        dyn_lib.close();
        gc.dyn_lib = null;
    }
    global_gc.updateAndRender = null;
    std.debug.print("Unloaded dll\n", .{});
}

fn getLastWriteTime(io: std.Io, filename: []const u8) std.Io.Timestamp {
    const stat = std.Io.Dir.cwd().statFile(io, filename, .{}) catch return .zero;
    return stat.mtime;
}
