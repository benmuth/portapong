//! Code and data types specific to the game

const std = @import("std");

// TODO:
// random angle and speed at start
// vary speed with paddle collision location
// pre check collision to avoid frame with ball in paddle

pub const Color = extern struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

const paddle_pix_per_s = 500;
const ball_max_pix_per_s = 1000;
const collision_threshold = 1;
const fps = 60;
const paddle_pix_per_f = paddle_pix_per_s / fps;
const ball_max_pix_per_f = ball_max_pix_per_s / fps;

// Simple types to avoid raylib dependency in the DLL
pub const Rectangle = extern struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
};

pub const Vector2 = extern struct {
    x: f32,
    y: f32,
};

// Drawing state that gets passed to main for rendering
pub const DrawState = extern struct {
    p1: Rectangle,
    p2: Rectangle,
    ball_x: f32,
    ball_y: f32,
    ball_radius: f32,
    paddle_color: Color = .{ .r = 0x18, .g = 0x18, .b = 0x18, .a = 200 },
    ball_color: Color = .{ .r = 0x00, .g = 0x00, .b = 0xFF, .a = 200 },
};

// Input state passed from main to DLL
pub const InputState = extern struct {
    p1_up: bool,
    p1_down: bool,
    p2_up: bool,
    p2_down: bool,
};

// Helper functions for collision detection
fn checkCollisionCircleLine(center: Vector2, radius: f32, p1: Vector2, p2: Vector2) bool {
    const dx = p2.x - p1.x;
    const dy = p2.y - p1.y;
    const fx = p1.x - center.x;
    const fy = p1.y - center.y;

    const a = dx * dx + dy * dy;
    const b = 2 * (fx * dx + fy * dy);
    const c = (fx * fx + fy * fy) - radius * radius;

    var discriminant = b * b - 4 * a * c;
    if (discriminant < 0) return false;

    discriminant = @sqrt(discriminant);
    const t1 = (-b - discriminant) / (2 * a);
    const t2 = (-b + discriminant) / (2 * a);

    return (t1 >= 0 and t1 <= 1) or (t2 >= 0 and t2 <= 1);
}

fn checkCollisionPointRec(point: Vector2, rec: Rectangle) bool {
    return point.x >= rec.x and point.x <= rec.x + rec.width and
        point.y >= rec.y and point.y <= rec.y + rec.height;
}

const State = struct {
    allocator: std.mem.Allocator,

    frames_counter: u32 = 0,

    window_width: f32,
    window_height: f32,

    paddle_height: f32,
    paddle_width: f32,

    p1: Rectangle,
    p2: Rectangle,

    b_x: f32,
    b_y: f32,
    b_radius: f32,
    b_dir_radians: f32,

    b_pix_per_f: f32,
};

export fn initState(width: u32, height: u32) *anyopaque {
    var allocator = std.heap.c_allocator;
    const state = allocator.create(State) catch @panic("out of memory.");

    const window_width: f32 = @floatFromInt(width);
    const window_height: f32 = @floatFromInt(height);
    std.debug.print("width: {d}, height: {d}\n", .{ window_width, window_height });

    const paddle_width: f32 = window_width / 50;
    const paddle_height: f32 = window_height / 5;

    state.* = .{
        .allocator = allocator,
        .window_width = window_width,
        .window_height = window_height,
        .paddle_height = paddle_height,
        .paddle_width = paddle_width,
        .p1 = .{
            .x = paddle_width,
            .y = window_height / 2,
            .width = paddle_width,
            .height = paddle_height,
        },
        .p2 = .{
            .x = window_width - (2 * paddle_width),
            .y = window_height / 2,
            .width = paddle_width,
            .height = paddle_height,
        },
        .b_x = window_width * 3 / 4,
        .b_y = window_height / 2,
        .b_radius = 5,
        .b_dir_radians = 0,
        .b_pix_per_f = ball_max_pix_per_f / 2,
    };

    return state;
}

export fn deinit(state_ptr: *anyopaque) void {
    const state: *State = @ptrCast(@alignCast(state_ptr));
    state.allocator.destroy(state);
}

export fn reload(state_ptr: *anyopaque) void {
    var state: *State = @ptrCast(@alignCast(state_ptr));
    state.frames_counter = 0;
    state.b_x = state.window_width / 2;
    state.b_y = state.window_height / 2;
    state.b_dir_radians = 0;
}

export fn getDrawState(game_state_ptr: *anyopaque, out_state: *DrawState) void {
    const game_state: *State = @ptrCast(@alignCast(game_state_ptr));

    out_state.* = .{
        .p1 = game_state.p1,
        .p2 = game_state.p2,
        .ball_x = game_state.b_x,
        .ball_y = game_state.b_y,
        .ball_radius = game_state.b_radius,
    };
}

export fn updateAndRender(state_ptr: *anyopaque, input: *const InputState) void {
    const state: *State = @ptrCast(@alignCast(state_ptr));

    // move paddles
    const p1_upper_bound = state.p1.y;
    const p1_lower_bound = state.p1.y + state.paddle_height;
    if (input.p1_up) {
        if (p1_upper_bound > 0) {
            state.p1.y -= paddle_pix_per_f;
        } else {
            state.p1.y = 0;
        }
    } else if (input.p1_down) {
        if (p1_lower_bound < state.window_height) {
            state.p1.y += paddle_pix_per_f;
        } else {
            state.p1.y = state.window_height - state.paddle_height;
        }
    }

    const p2_upper_bound = state.p2.y;
    const p2_lower_bound = state.p2.y + state.paddle_height;

    if (input.p2_up) {
        if (p2_upper_bound > 0) {
            state.p2.y -= paddle_pix_per_f;
        } else {
            state.p2.y = 0;
        }
    } else if (input.p2_down) {
        if (p2_lower_bound < state.window_height) {
            state.p2.y += paddle_pix_per_f;
        } else {
            state.p2.y = state.window_height - state.paddle_height;
        }
    }

    // paddle bounce
    if (checkCollisionPointRec(.{ .x = state.b_x - state.b_radius, .y = state.b_y }, state.p1)) {
        const relative_ball_y: f32 = relativeYPos(.{ .x = state.b_x, .y = state.b_y }, state.p1);

        state.b_dir_radians = paddleCollisionDir(relative_ball_y, state.b_dir_radians);
        state.b_pix_per_f = paddleCollisionSpeed(relative_ball_y);

        // move ball outside paddle
        if ((state.b_x - state.b_radius) < state.p1.x + state.paddle_width) {
            state.b_x = state.p1.x + state.paddle_width + state.b_radius;
        }
    } else if (checkCollisionPointRec(.{ .x = state.b_x + state.b_radius, .y = state.b_y }, state.p2)) {
        const relative_ball_y: f32 = relativeYPos(.{ .x = state.b_x, .y = state.b_y }, state.p2);

        state.b_dir_radians = paddleCollisionDir(relative_ball_y, state.b_dir_radians);
        state.b_pix_per_f = paddleCollisionSpeed(relative_ball_y);

        // move ball outside paddle
        if ((state.b_x + state.b_radius) > state.p2.x) {
            state.b_x = state.p2.x - state.b_radius;
        }
    }

    // reflect off top wall
    if (state.b_y - state.b_radius <= 0) {
        state.b_dir_radians = std.math.tau - state.b_dir_radians;
        state.b_y = state.b_radius;
    }

    // reflect off bottom wall
    if (state.b_y + state.b_radius >= state.window_height) {
        state.b_dir_radians = std.math.tau - state.b_dir_radians;
        state.b_y = state.window_height - state.b_radius;
    }

    // TODO: score
    if (checkCollisionCircleLine( // left wall
        .{ .x = state.b_x, .y = state.b_y },
        state.b_radius,
        .{ .x = 0, .y = 0 },
        .{ .x = 0, .y = state.window_height },
    )) {
        reload(state_ptr);
    } else if (checkCollisionCircleLine( // right wall
        .{ .x = state.b_x, .y = state.b_y },
        state.b_radius,
        .{ .x = state.window_width, .y = 0 },
        .{ .x = state.window_width, .y = state.window_height },
    )) {
        reload(state_ptr);
    }

    // std.debug.print("speed (p/f): {d}\n", .{state.b_pix_per_f});
    const b_x_movement = @cos(state.b_dir_radians) * state.b_pix_per_f;
    const b_y_movement = @sin(state.b_dir_radians) * state.b_pix_per_f;

    state.b_x += b_x_movement;
    state.b_y -= b_y_movement;
}

fn paddleCollisionDir(relative_ball_y: f32, ball_dir: f32) f32 {
    const norm_dir = @mod(ball_dir, 2 * std.math.pi);
    std.debug.print("relative_ball_y: {d}, norm_dir: {d}\n", .{ relative_ball_y, norm_dir });

    if (norm_dir >= (std.math.pi * 0.5) and ball_dir < (std.math.pi * 1.5)) {
        if (relative_ball_y >= 0 and relative_ball_y < 0.5) {
            std.debug.print("1\n", .{});
            return std.math.lerp(0, 0.3 * std.math.pi, 1 - relative_ball_y);
        } else {
            std.debug.print("2\n", .{});
            return std.math.lerp(1.5 * std.math.pi, 1.7 * std.math.pi, relative_ball_y);
        }
    } else if ((norm_dir >= 0 and norm_dir < (0.5 * std.math.pi)) or (norm_dir >= (1.5 * std.math.pi) and norm_dir < (2 * std.math.pi))) {
        std.debug.print("3\n", .{});
        return std.math.lerp(std.math.pi * 0.70, std.math.pi * 1.30, relative_ball_y);
    }
    std.debug.panic("ball direction angle outside of bounds: {d}", .{norm_dir});
}

fn paddleCollisionSpeed(relative_ball_y: f32) f32 {
    return @max(@as(f32, @floatFromInt(ball_max_pix_per_f)) * relative_ball_y, ball_max_pix_per_f / 4);
}

fn vertDistFromRectCenter(p: Vector2, rect: Rectangle) f32 {
    return @abs(p.y - (rect.y + (rect.height / 2)));
}

fn relativeYPos(p: Vector2, rect: Rectangle) f32 {
    const yPos: f32 = vertDistFromRectCenter(p, rect) / rect.height;

    std.debug.assert(yPos < 1.0);
    return yPos;
}
