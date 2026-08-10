// followed https://zig.news/perky/hot-reloading-with-raylib-4bf9
const std = @import("std");
const rl = @import("raylib");
const g = @import("game");

// TODO
// - draw the output of the compilation on-screen, maybe in a custom debug window or in-editor console.

const dyn_lib_name = "zig-out/lib/libgame.0.0.1.dylib";

fn rlColor(color: g.Color) rl.Color {
    return rl.Color{
        .r = color.r,
        .g = color.g,
        .b = color.b,
        .a = color.a,
    };
}

// Import game types - we'll need to redeclare them to match the dylib
const DrawState = extern struct {
    p1: rl.Rectangle,
    p2: rl.Rectangle,
    ball_x: f32,
    ball_y: f32,
    ball_radius: f32,
    paddle_color: g.Color,
    ball_color: g.Color,
};

const InputState = extern struct {
    p1_up: bool,
    p1_down: bool,
    p2_up: bool,
    p2_down: bool,
};

const GameCode = struct {
    const GamePtr = *anyopaque;
    const MemPtr = *anyopaque;
    dyn_lib: ?std.DynLib = null,
    dynlib_last_write_time: std.Io.Timestamp = .zero,

    initState: ?*const fn (MemPtr, u32, u32) callconv(.c) GamePtr = null,
    reload: ?*const fn (GamePtr) callconv(.c) void = null,
    updateAndRender: ?*const fn (GamePtr, ?*const InputState) callconv(.c) void = null,
    getDrawState: ?*const fn (GamePtr, ?*DrawState) callconv(.c) void = null,

    is_valid: bool = false,
};

var global_gc: GameCode = .{};
var reload_generation: usize = 0;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const clock = std.Io.Clock.boot;

    const init_arena = init.arena;
    const init_allocator = init_arena.allocator();
    loadGameDynlib(io, dyn_lib_name);

    const window_width = 800;
    const window_height = 450;
    const memory = try init_allocator.alloc(u8, g.permanent_size + g.transient_size);
    var game_fba = std.heap.FixedBufferAllocator.init(memory[0..g.permanent_size]);
    var arena_backing_fba = std.heap.FixedBufferAllocator.init(memory[g.permanent_size..]);
    var game_arena = std.heap.ArenaAllocator.init(arena_backing_fba.allocator());
    var game_memory: g.GameMemory = .init(&game_fba, &game_arena);
    const game_state = global_gc.initState.?(&game_memory, window_width, window_height);
    std.debug.print("Initial state: {any}\n", .{game_state});

    rl.setConfigFlags(.{ .window_resizable = true, .window_highdpi = true });
    rl.initWindow(window_width, window_height, "portapong");
    rl.setTargetFPS(60);

    // WindowShouldClose will return true if the user presses ESC.
    while (!rl.windowShouldClose()) {
        const new_write_time = getLastWriteTime(io, dyn_lib_name);
        if (new_write_time.nanoseconds != global_gc.dynlib_last_write_time.nanoseconds) {
            std.debug.print("{any}\n", .{clock.now(io)});
            unloadGameDynlib(&global_gc);
            loadGameDynlib(io, dyn_lib_name);
        }

        if (rl.isKeyPressed(rl.KeyboardKey.slash)) {
            unloadGameDynlib(&global_gc);
            loadGameDynlib(io, dyn_lib_name);
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
        rl.drawRectangleRec(draw_state.p1, rlColor(draw_state.paddle_color));
        rl.drawRectangleRec(draw_state.p2, rlColor(draw_state.paddle_color));

        const ball_x: c_int = @intFromFloat(@trunc(draw_state.ball_x));
        const ball_y: c_int = @intFromFloat(@trunc(draw_state.ball_y));
        rl.drawCircle(ball_x, ball_y, draw_state.ball_radius, rlColor(draw_state.ball_color));

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
        global_gc.initState = null;
        global_gc.reload = null;
        global_gc.updateAndRender = null;
        global_gc.getDrawState = null;
        global_gc.is_valid = false;
        break :blk null;
    };

    global_gc.dyn_lib = dyn_lib;

    if (global_gc.dyn_lib) |*dl| {
        global_gc.dynlib_last_write_time = getLastWriteTime(io, dyn_lib_name);
        global_gc.initState = dl.lookup(@TypeOf(global_gc.initState.?), "initState");
        global_gc.reload = dl.lookup(@TypeOf(global_gc.reload.?), "reload");
        global_gc.updateAndRender = dl.lookup(@TypeOf(global_gc.updateAndRender.?), "updateAndRender");
        global_gc.getDrawState = dl.lookup(@TypeOf(global_gc.getDrawState.?), "getDrawState");

        global_gc.is_valid = global_gc.initState != null and
            global_gc.reload != null and
            global_gc.updateAndRender != null and
            global_gc.getDrawState != null;
    }

    if (!global_gc.is_valid) {
        global_gc.initState = null;
        global_gc.reload = null;
        global_gc.updateAndRender = null;
        global_gc.getDrawState = null;
    }
    std.debug.print("Loaded dll\n", .{});
}

fn unloadGameDynlib(gc: *GameCode) void {
    if (gc.dyn_lib) |*dyn_lib| {
        dyn_lib.close();
        gc.dyn_lib = null;
    }
    global_gc.initState = null;
    global_gc.reload = null;
    global_gc.updateAndRender = null;
    global_gc.getDrawState = null;
    std.debug.print("Unloaded dll\n", .{});
}

fn getLastWriteTime(io: std.Io, filename: []const u8) std.Io.Timestamp {
    const stat = std.Io.Dir.cwd().statFile(io, filename, .{}) catch return .zero;
    return stat.mtime;
}
