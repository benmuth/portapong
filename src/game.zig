const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});

const movement_speed = 5;

const Game = struct {
    allocator: std.mem.Allocator,

    frames_counter: u32 = 0,

    window_width: c_int,
    window_height: c_int,

    paddle_height: c_int,
    paddle_width: c_int,

    p1_x: c_int,
    p1_y: c_int,

    p2_x: c_int,
    p2_y: c_int,

    p1_dir: c_int,
    p2_dir: c_int,
};

export fn init(window_width: c_int, window_height: c_int, paddle_height: c_int) *anyopaque {
    var allocator = std.heap.c_allocator;
    const game_state = allocator.create(Game) catch @panic("out of memory.");

    const paddle_width = @divTrunc(window_width, 10);

    game_state.* = .{
        .allocator = allocator,
        .window_width = window_width,
        .window_height = window_height,
        .paddle_height = paddle_height,
        .paddle_width = paddle_width,
        .p1_x = paddle_width,
        .p2_x = window_width - (2 * paddle_width),
        .p1_y = 0,
        .p2_y = window_height - paddle_height,
        .p1_dir = -1,
        .p2_dir = 1,
    };

    return game_state;
}

export fn reload(game_state_ptr: *anyopaque) void {
    var game_state: *Game = @ptrCast(@alignCast(game_state_ptr));
    game_state.frames_counter = 0;
}

export fn draw(game_state_ptr: *anyopaque) void {
    const game_state: *Game = @ptrCast(@alignCast(game_state_ptr));

    rl.BeginDrawing();
    rl.ClearBackground(rl.RAYWHITE);

    rl.DrawRectangle(game_state.p1_x, game_state.p1_y, game_state.paddle_width, game_state.paddle_height, rl.Color{ .r = 0, .g = 0, .b = 0, .a = 255 });
    rl.DrawRectangle(game_state.p2_x, game_state.p2_y, game_state.paddle_width, game_state.paddle_height, rl.Color{ .r = 0, .g = 0, .b = 0, .a = 255 });

    rl.EndDrawing();
}

export fn update(game_state_ptr: *anyopaque) void {
    const game_state: *Game = @ptrCast(@alignCast(game_state_ptr));

    const p1_upper_bound = game_state.p1_y;
    const p1_lower_bound = game_state.p1_y + game_state.paddle_height;

    const p2_upper_bound = game_state.p2_y;
    const p2_lower_bound = game_state.p2_y + game_state.paddle_height;

    if (rl.IsKeyDown(rl.KEY_W)) {
        if (p1_upper_bound > 0) {
            game_state.p1_y -= movement_speed;
        } else {
            game_state.p1_y = 0;
        }
    } else if (rl.IsKeyDown(rl.KEY_S)) {
        if (p1_lower_bound < game_state.window_height) {
            game_state.p1_y += movement_speed;
        } else {
            game_state.p1_y = game_state.window_height - game_state.paddle_height;
        }
    }

    if (rl.IsKeyDown(rl.KEY_UP)) {
        if (p2_upper_bound > 0) {
            game_state.p2_y -= movement_speed;
        } else {
            game_state.p2_y = 0;
        }
    } else if (rl.IsKeyDown(rl.KEY_DOWN)) {
        if (p2_lower_bound < game_state.window_height) {
            game_state.p2_y += movement_speed;
        } else {
            game_state.p2_y = game_state.window_height - game_state.paddle_height;
        }
    }
}
