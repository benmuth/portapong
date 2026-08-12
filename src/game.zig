//! Code and data types specific to the game

const std = @import("std");

// TODO:
// random angle and speed at start
// vary speed with paddle collision location
// pre check collision to avoid frame with ball in paddle

pub const permanent_size = 1 * 1024 * 1024;
pub const transient_size = 1 * 1024 * 1024;

pub const GameMemory = extern struct {
    pub fn init(
        fba: *std.heap.FixedBufferAllocator,
        arena: *std.heap.ArenaAllocator,
    ) GameMemory {
        return .{
            .initialized = true,
            .permanent_storage = fba,
            .transient_storage = arena,
        };
    }
    initialized: bool,

    permanent_storage: *std.heap.FixedBufferAllocator,
    transient_storage: *std.heap.ArenaAllocator,
};

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

pub const Circle = extern struct { x: f32, y: f32, radius: f32 };

const Vector2 = extern struct {
    x: f32,
    y: f32,
};

// Input state passed from main to DLL
pub const Input = extern struct {
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

const World = extern struct {
    const width: i8 = 16;
    const height: i8 = 9;
    const paddle_height: i8 = 3;
    const paddle_width: i8 = 1;

    p1: Rectangle,
    p2: Rectangle,

    ball: Circle,
};

pub const State = extern struct {
    initialized: bool = false,

    world: World,

    ball_dir_radians: f32,

    // ball speed in units per second
    ball_speed: f32,

    ball_color: Color,

    paddle_color: Color,
};

fn initState(state: *State) void {
    state.* = .{
        .initialized = true,
        .world = .{
            .ball = .{
                .x = World.width * 3 / 4,
                .y = World.height / 2,
                .radius = 5,
            },
            .p1 = .{
                .x = World.paddle_width,
                .y = World.height / 2,
                .width = World.paddle_width,
                .height = World.paddle_height,
            },
            .p2 = .{
                .x = World.width - (2 * World.paddle_width),
                .y = World.paddle_height / 2,
                .width = World.paddle_width,
                .height = World.paddle_height,
            },
        },

        .ball_dir_radians = 0,
        .ball_speed = ball_max_pix_per_f / 2,
        .ball_color = .{ .r = 0xFF, .g = 0x00, .b = 0x00, .a = 0xFF },
        .paddle_color = .{ .r = 0xFF, .g = 0x00, .b = 0x00, .a = 0xFF },
    };
}

fn reset(state: *State) void {
    state.world.ball.x = World.width / 2;
    state.world.ball.y = World.height / 2;
    state.ball_dir_radians = 0;
}

export fn updateAndRender(memory: *GameMemory, input: *const Input) void {
    var state: *State = @ptrCast(@alignCast(memory.permanent_storage.buffer));

    if (state.initialized) {
        // move paddles
        const p1_upper_bound = state.world.p1.y;
        const p1_lower_bound = state.world.p1.y + World.paddle_height;
        if (input.p1_up) {
            if (p1_upper_bound > 0) {
                state.world.p1.y -= paddle_pix_per_f;
            } else {
                state.world.p1.y = 0;
            }
        } else if (input.p1_down) {
            if (p1_lower_bound < World.height) {
                state.world.p1.y += paddle_pix_per_f;
            } else {
                state.world.p1.y = World.height - World.paddle_height;
            }
        }

        const p2_upper_bound = state.world.p2.y;
        const p2_lower_bound = state.world.p2.y + World.paddle_height;

        if (input.p2_up) {
            if (p2_upper_bound > 0) {
                state.world.p2.y -= paddle_pix_per_f;
            } else {
                state.world.p2.y = 0;
            }
        } else if (input.p2_down) {
            if (p2_lower_bound < World.height) {
                state.world.p2.y += paddle_pix_per_f;
            } else {
                state.world.p2.y = World.height - World.paddle_height;
            }
        }

        // paddle bounce
        if (checkCollisionPointRec(.{ .x = state.world.ball.x - state.world.ball.radius, .y = state.world.ball.y }, state.world.p1)) {
            const relative_ball_y: f32 = relativeYPos(.{ .x = state.world.ball.x, .y = state.world.ball.y }, state.world.p1);

            state.ball_dir_radians = paddleCollisionDir(relative_ball_y, state.ball_dir_radians);
            state.ball_speed = paddleCollisionSpeed(relative_ball_y);

            // move ball outside paddle
            if ((state.world.ball.x - state.world.ball.radius) < state.world.p1.x + World.paddle_width) {
                state.world.ball.x = state.world.p1.x + World.paddle_width + state.world.ball.radius;
            }
        } else if (checkCollisionPointRec(
            .{
                .x = state.world.ball.x + state.world.ball.radius,
                .y = state.world.ball.y,
            },
            state.world.p2,
        )) {
            const relative_ball_y: f32 = relativeYPos(.{ .x = state.world.ball.x, .y = state.world.ball.y }, state.world.p2);

            state.ball_dir_radians = paddleCollisionDir(relative_ball_y, state.ball_dir_radians);
            state.ball_speed = paddleCollisionSpeed(relative_ball_y);

            // move ball outside paddle
            if ((state.world.ball.x + state.world.ball.radius) > state.world.p2.x) {
                state.world.ball.x = state.world.p2.x - state.world.ball.radius;
            }
        }

        // reflect off top wall
        if (state.world.ball.y - state.world.ball.radius <= 0) {
            state.ball_dir_radians = std.math.tau - state.ball_dir_radians;
            state.world.ball.y = state.world.ball.radius;
        }

        // reflect off bottom wall
        if (state.world.ball.y + state.world.ball.radius >= World.height) {
            state.ball_dir_radians = std.math.tau - state.ball_dir_radians;
            state.world.ball.y = World.height - state.world.ball.radius;
        }

        // TODO: score
        if (checkCollisionCircleLine( // left wall
            .{ .x = state.world.ball.x, .y = state.world.ball.y },
            state.world.ball.radius,
            .{ .x = 0, .y = 0 },
            .{ .x = 0, .y = World.height },
        )) {
            reset(state);
        } else if (checkCollisionCircleLine( // right wall
            .{ .x = state.world.ball.x, .y = state.world.ball.y },
            state.world.ball.radius,
            .{ .x = World.width, .y = 0 },
            .{ .x = World.width, .y = World.height },
        )) {
            reset(state);
        }

        // std.debug.print("speed (p/f): {d}\n", .{state.b_pix_per_f});
        const b_x_movement = @cos(state.ball_dir_radians) * state.ball_speed;
        const b_y_movement = @sin(state.ball_dir_radians) * state.ball_speed;

        state.world.ball.x += b_x_movement;
        state.world.ball.y -= b_y_movement;
    } else {
        initState(state);
        std.debug.print("initial state: {any}\n", .{state});
    }
}

fn paddleCollisionDir(relative_ball_y: f32, ball_dir: f32) f32 {
    const norm_dir = @mod(ball_dir, 2 * std.math.pi);
    std.debug.print("relative_ball_y: {d}, norm_dir: {d}\n", .{ relative_ball_y, norm_dir });

    if (norm_dir >= (std.math.pi * 0.5) and ball_dir < (std.math.pi * 1.5)) {
        if (relative_ball_y >= 0 and relative_ball_y < 0.5) {
            return std.math.lerp(0, 0.3 * std.math.pi, 1 - relative_ball_y);
        } else {
            return std.math.lerp(1.5 * std.math.pi, 1.7 * std.math.pi, relative_ball_y);
        }
    } else if ((norm_dir >= 0 and norm_dir < (0.5 * std.math.pi)) or (norm_dir >= (1.5 * std.math.pi) and norm_dir < (2 * std.math.pi))) {
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
