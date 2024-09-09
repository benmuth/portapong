const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});

const paddle_movement_speed = 5;
const ball_movement_speed = 5;
const paddle_color: rl.Color = .{ .r = 0x18, .g = 0x18, .b = 0x18, .a = 200 };
const ball_color: rl.Color = .{ .r = 0xFF, .g = 0x0, .b = 0x0, .a = 200 };
var window_width: f32 = -1;
var window_height: f32 = -1;

const Game = struct {
    allocator: std.mem.Allocator,

    frames_counter: u32 = 0,

    window_width: f32,
    window_height: f32,

    paddle_height: f32,
    paddle_width: f32,

    p1: rl.Rectangle,
    p2: rl.Rectangle,

    b_x: f32,
    b_y: f32,
    b_rad: f32,
    b_dir: f32,
};

export fn init(width: c_int, height: c_int) *anyopaque {
    var allocator = std.heap.c_allocator;
    const game_state = allocator.create(Game) catch @panic("out of memory.");

    window_width = @floatFromInt(width);
    window_height = @floatFromInt(height);

    const paddle_width: f32 = window_width / 10;
    const paddle_height: f32 = window_height / 5;

    game_state.* = .{
        .allocator = allocator,
        .window_width = window_width,
        .window_height = window_height,
        .paddle_height = paddle_height,
        .paddle_width = paddle_width,
        .p1 = .{
            .x = paddle_width,
            .y = 0,
            .width = paddle_width,
            .height = paddle_height,
        },
        .p2 = .{
            .x = window_width - (2 * paddle_width),
            .y = window_height - paddle_height,
            .width = paddle_width,
            .height = paddle_height,
        },
        .b_x = window_width / 2,
        .b_y = window_height / 2,
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

    rl.DrawRectangleRec(game_state.p1, paddle_color);
    rl.DrawRectangleRec(game_state.p2, paddle_color);
    // rl.DrawRectangle(100, 100, 5, 30, .{ .r = 0xFF, .g = 0x0, .b = 0x0, .a = 255 });
    const ball_x: c_int = @intFromFloat(@trunc(game_state.b_x));
    const ball_y: c_int = @intFromFloat(@trunc(game_state.b_y));

    rl.DrawCircle(ball_x, ball_y, game_state.b_rad, ball_color);

    rl.EndDrawing();
}

export fn update(game_state_ptr: *anyopaque) void {
    const game_state: *Game = @ptrCast(@alignCast(game_state_ptr));

    const p1_upper_bound = game_state.p1.y;
    const p1_lower_bound = game_state.p1.y + game_state.paddle_height;

    const p2_upper_bound = game_state.p2.y;
    const p2_lower_bound = game_state.p2.y + game_state.paddle_height;

    if (rl.IsKeyDown(rl.KEY_W)) {
        if (p1_upper_bound > 0) {
            game_state.p1.y -= paddle_movement_speed;
        } else {
            game_state.p1.y = 0;
        }
    } else if (rl.IsKeyDown(rl.KEY_S)) {
        if (p1_lower_bound < game_state.window_height) {
            game_state.p1.y += paddle_movement_speed;
        } else {
            game_state.p1.y = game_state.window_height - game_state.paddle_height;
        }
    }

    if (rl.IsKeyDown(rl.KEY_UP)) {
        if (p2_upper_bound > 0) {
            game_state.p2.y -= paddle_movement_speed;
        } else {
            game_state.p2.y = 0;
        }
    } else if (rl.IsKeyDown(rl.KEY_DOWN)) {
        if (p2_lower_bound < game_state.window_height) {
            game_state.p2.y += paddle_movement_speed;
        } else {
            game_state.p2.y = game_state.window_height - game_state.paddle_height;
        }
    }

    const p1: rl.Rectangle = .{ .x = game_state.p1.x, .y = game_state.p1.y, .width = game_state.paddle_width, .height = game_state.paddle_height };
    const p2: rl.Rectangle = .{ .x = game_state.p2.x, .y = game_state.p2.y, .width = game_state.paddle_width, .height = game_state.paddle_height };

    // check ball collision with left paddle
    if (rl.CheckCollisionPointRec(.{ .x = game_state.b_x - game_state.b_rad, .y = game_state.b_y }, p1)) {
        game_state.b_dir += std.math.pi;
    }

    // check ball collision with right paddle
    if (rl.CheckCollisionPointRec(.{ .x = game_state.b_x + game_state.b_rad, .y = game_state.b_y }, p2)) {
        game_state.b_dir -= std.math.pi;
    }

    const b_x_movement = @cos(game_state.b_dir) * ball_movement_speed;
    const b_y_movement = @sin(game_state.b_dir) * ball_movement_speed;

    game_state.b_x += b_x_movement;
    game_state.b_y += b_y_movement;
}
