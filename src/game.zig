const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});

const paddle_movement_speed = 5;
const ball_movement_speed = 5;
const paddle_color: rl.Color = .{ .r = 0x18, .g = 0x18, .b = 0x18, .a = 200 };
const ball_color: rl.Color = .{ .r = 0xFF, .g = 0x0, .b = 0x0, .a = 200 };
var window_width: c_int = -1;
var window_height: c_int = -1;

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

    b_x: c_int,
    b_y: c_int,

    b_rad: f32,

    b_dir: f32,
};

export fn init(width: c_int, height: c_int) *anyopaque {
    var allocator = std.heap.c_allocator;
    const game_state = allocator.create(Game) catch @panic("out of memory.");

    window_width = width;
    window_height = height;

    const paddle_width = @divTrunc(window_width, 10);
    const paddle_height = @divTrunc(window_height, 5);

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
        .b_x = @divTrunc(window_width, 2),
        .b_y = @divTrunc(window_height, 2),
        .b_rad = 5,
        .b_dir = 0,
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

    rl.DrawRectangle(game_state.p1_x, game_state.p1_y, game_state.paddle_width, game_state.paddle_height, paddle_color);
    rl.DrawRectangle(game_state.p2_x, game_state.p2_y, game_state.paddle_width, game_state.paddle_height, paddle_color);
    // rl.DrawRectangle(100, 100, 5, 30, .{ .r = 0xFF, .g = 0x0, .b = 0x0, .a = 255 });

    rl.DrawCircle(game_state.b_x, game_state.b_y, game_state.b_rad, ball_color);

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
            game_state.p1_y -= paddle_movement_speed;
        } else {
            game_state.p1_y = 0;
        }
    } else if (rl.IsKeyDown(rl.KEY_S)) {
        if (p1_lower_bound < game_state.window_height) {
            game_state.p1_y += paddle_movement_speed;
        } else {
            game_state.p1_y = game_state.window_height - game_state.paddle_height;
        }
    }

    if (rl.IsKeyDown(rl.KEY_UP)) {
        if (p2_upper_bound > 0) {
            game_state.p2_y -= paddle_movement_speed;
        } else {
            game_state.p2_y = 0;
        }
    } else if (rl.IsKeyDown(rl.KEY_DOWN)) {
        if (p2_lower_bound < game_state.window_height) {
            game_state.p2_y += paddle_movement_speed;
        } else {
            game_state.p2_y = game_state.window_height - game_state.paddle_height;
        }
    }

    const b_x_movement = @cos(game_state.b_dir) * ball_movement_speed;
    const b_y_movement = @sin(game_state.b_dir) * ball_movement_speed;

    game_state.b_x += @intFromFloat(b_x_movement);
    game_state.b_y += @intFromFloat(b_y_movement);
}
