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
const collision_threshold = 1;

const State = struct {
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
    b_radius: f32,
    b_dir_radians: f32,
};

export fn init(width: c_int, height: c_int) *anyopaque {
    var allocator = std.heap.c_allocator;
    const state = allocator.create(State) catch @panic("out of memory.");

    window_width = @floatFromInt(width);
    window_height = @floatFromInt(height);

    const paddle_width: f32 = window_width / 10;
    const paddle_height: f32 = window_height / 5;

    state.* = .{
        .allocator = allocator,
        .window_width = window_width,
        .window_height = window_height,
        .paddle_height = paddle_height,
        .paddle_width = paddle_width,
        .p1 = .{
            .x = paddle_width,
            // .y = 0,
            .y = window_height / 2,
            .width = paddle_width,
            .height = paddle_height,
        },
        .p2 = .{
            .x = window_width - (2 * paddle_width),
            // .y = window_height - paddle_height,
            .y = window_height / 2,
            .width = paddle_width,
            .height = paddle_height,
        },
        .b_x = window_width / 2,
        .b_y = window_height / 2,
        .b_radius = 5,
        .b_dir_radians = 0,
    };

    return state;
}

export fn reload(state_ptr: *anyopaque) void {
    var state: *State = @ptrCast(@alignCast(state_ptr));
    state.frames_counter = 0;
    state.b_x = window_width / 2;
    state.b_y = window_height / 2;
    state.b_dir_radians = 0;
}

export fn draw(game_state_ptr: *anyopaque) void {
    const game_state: *State = @ptrCast(@alignCast(game_state_ptr));

    rl.BeginDrawing();
    rl.ClearBackground(rl.RAYWHITE);

    rl.DrawRectangleRec(game_state.p1, paddle_color);
    rl.DrawRectangleRec(game_state.p2, paddle_color);

    const ball_x: c_int = @intFromFloat(@trunc(game_state.b_x));
    const ball_y: c_int = @intFromFloat(@trunc(game_state.b_y));

    rl.DrawCircle(ball_x, ball_y, game_state.b_radius, ball_color);

    rl.EndDrawing();
}

export fn update(state_ptr: *anyopaque) void {
    const state: *State = @ptrCast(@alignCast(state_ptr));

    const p1_upper_bound = state.p1.y;
    const p1_lower_bound = state.p1.y + state.paddle_height;

    const p2_upper_bound = state.p2.y;
    const p2_lower_bound = state.p2.y + state.paddle_height;

    if (rl.IsKeyDown(rl.KEY_W)) {
        if (p1_upper_bound > 0) {
            state.p1.y -= paddle_movement_speed;
        } else {
            state.p1.y = 0;
        }
    } else if (rl.IsKeyDown(rl.KEY_S)) {
        if (p1_lower_bound < state.window_height) {
            state.p1.y += paddle_movement_speed;
        } else {
            state.p1.y = state.window_height - state.paddle_height;
        }
    }

    if (rl.IsKeyDown(rl.KEY_UP)) {
        if (p2_upper_bound > 0) {
            state.p2.y -= paddle_movement_speed;
        } else {
            state.p2.y = 0;
        }
    } else if (rl.IsKeyDown(rl.KEY_DOWN)) {
        if (p2_lower_bound < state.window_height) {
            state.p2.y += paddle_movement_speed;
        } else {
            state.p2.y = state.window_height - state.paddle_height;
        }
    }

    if (rl.CheckCollisionCircleLine( // top
        .{ .x = state.b_x, .y = state.b_y },
        state.b_radius,
        .{ .x = 0, .y = 0 },
        .{ .x = state.window_width, .y = 0 },
    )) {
        state.b_dir_radians += 0.5 * std.math.pi;
    } else if (rl.CheckCollisionCircleLine( // bottom
        .{ .x = state.b_x, .y = state.b_y },
        state.b_radius,
        .{ .x = 0, .y = state.window_height },
        .{ .x = state.window_width, .y = state.window_height },
    )) {
        state.b_dir_radians -= 0.5 * std.math.pi;
    }

    if (rl.CheckCollisionCircleLine( // left
        .{ .x = state.b_x, .y = state.b_y },
        state.b_radius,
        .{ .x = 0, .y = 0 },
        .{ .x = 0, .y = state.window_height },
    )) {
        reload(state_ptr);
    } else if (rl.CheckCollisionCircleLine( // right
        .{ .x = state.b_x, .y = state.b_y },
        state.b_radius,
        .{ .x = state.window_width, .y = 0 },
        .{ .x = state.window_width, .y = state.window_height },
    )) {
        reload(state_ptr);
    }

    // paddles
    if (rl.CheckCollisionPointRec(.{ .x = state.b_x - state.b_radius, .y = state.b_y }, state.p1)) { // left
        const rel_loc = (state.p1.y - state.b_y) / state.paddle_height;
        const new_dir_radians = std.math.lerp(std.math.pi * 0.80, std.math.pi * 1.20, rel_loc);
        state.b_dir_radians += new_dir_radians + std.math.pi;
    } else if (rl.CheckCollisionPointRec(.{ .x = state.b_x + state.b_radius, .y = state.b_y }, state.p2)) { // right
        const rel_loc = (state.p2.y - state.b_y) / state.paddle_height;
        const new_dir_radians = std.math.lerp(std.math.pi * 0.75, std.math.pi * 1.25, rel_loc);
        state.b_dir_radians += new_dir_radians + std.math.pi;
    }

    const b_x_movement = @cos(state.b_dir_radians) * ball_movement_speed;
    const b_y_movement = @sin(state.b_dir_radians) * ball_movement_speed;

    state.b_x += b_x_movement;
    state.b_y += b_y_movement;
}
