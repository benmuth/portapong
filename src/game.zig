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

const paddle_units_per_s = 10;
const ball_max_units_per_s = 20;
// const paddle_pix_per_f = paddle_pix_per_s / fps;
// const ball_max_pix_per_f = ball_max_pix_per_s / fps;

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

fn checkCollisionPointRec(point: Vector2, rec: Entity) bool {
    return point.x >= rec.x and point.x <= rec.x + rec.width and
        point.y >= rec.y and point.y <= rec.y + rec.height;
}

pub const World = extern struct {
    pub const width: u32 = 160;
    pub const height: u32 = 90;
    const paddle_height: u32 = 3;
    const paddle_width: u32 = 1;
    const p1_x = paddle_width;
    const p1_y = paddle_height;
    const p2_x = width - (2 * paddle_width);
    const p2_y = World.height / 2;

    // const b_x = width * 3 / 4;
    // const b_y = height / 2;
    const b_r = 5;

    const ball_color: Color = .{ .r = 0xFF, .g = 0x00, .b = 0x00, .a = 0xFF };
    const paddle_color: Color = .{ .r = 0xFF, .g = 0x00, .b = 0x00, .a = 0xFF };
};

pub const State = extern struct {
    initialized: bool = false,

    world: World,

    p1_y: f32,
    p2_y: f32,

    b_x: f32,
    b_y: f32,

    b_dir_radians: f32,

    // ball speed in units per second
    b_speed: f32,
};

fn reset(state: *State) void {
    state.b_x = World.width / 2;
    state.b_y = World.height / 2;
    state.b_dir_radians = 0;
}

fn paddle(x: f32, y: f32, color: Color) Entity {
    return .{
        .paddle = true,
        .controllable = true,
        .height = World.paddle_height + 10,
        .width = World.paddle_width + 10,
        .x = x,
        .y = y,
        .color = color,
    };
}

fn ball(x: f32, y: f32, color: Color) Entity {
    return .{
        .ball = true,
        .radius = World.b_r,
        .x = x,
        .y = y,
        .color = color,
    };
}

pub const Entity = extern struct {
    paddle: bool = false,
    controllable: bool = false,
    ball: bool = false,

    x: f32 = World.width / 2,
    y: f32 = World.height / 2,

    width: f32 = 0,
    height: f32 = 0,

    radius: f32 = 0,

    color: Color = .{ .r = 0xFF, .g = 0x00, .b = 0xFF, .a = 0xFF },
};

pub const Entities = extern struct {
    pub const empty: Entities = .{
        .list = undefined,
        .count = 0,
    };

    list: [*]Entity,
    count: usize,
};

export fn updateAndRender(memory: *GameMemory, input: *const Input, out: *Entities) void {
    var state: *State = @ptrCast(@alignCast(memory.permanent_storage.buffer));
    const allocator = memory.transient_storage.allocator();
    _ = memory.transient_storage.reset(.retain_capacity);
    var entities = std.ArrayList(Entity).initCapacity(allocator, 3) catch @panic("Couldn't initialize array");

    // paddles
    const p1: Entity = blk: {
        var new_y = if (input.p1_up) state.p1_y - paddle_units_per_s else if (input.p1_down) state.p1_y + paddle_units_per_s else state.p1_y;
        // const bottom_bound = state.p1_y;
        const top_bound = state.p1_y + World.paddle_height;

        new_y = std.math.clamp(new_y, 0, top_bound);
        break :blk paddle(World.p1_x, new_y, World.paddle_color);
    };

    const p2: Entity = blk: {
        var new_y = if (input.p2_up) state.p2_y - paddle_units_per_s else if (input.p2_down) state.p2_y + paddle_units_per_s else state.p2_y;
        // const bottom_bound = state.p2_y;
        const top_bound = state.p2_y + World.paddle_height;

        new_y = std.math.clamp(new_y, 0, top_bound);
        break :blk paddle(World.p2_x, new_y, .{ .r = 0x00, .g = 0xFF, .b = 0xFF, .a = 0xFF });
    };

    state.p1_y = p1.y;
    state.p2_y = p2.y;
    entities.append(allocator, p1) catch @panic("Couldn't allocate");
    entities.append(allocator, p2) catch @panic("Couldn't allocate");

    // ball
    // collide with paddle
    if (checkCollisionPointRec(
        .{ .x = state.b_x - World.b_r, .y = state.b_y },
        p1,
    )) {
        const relative_ball_y: f32 = relativeYPos(.{ .x = state.b_x, .y = state.b_y }, p1);

        state.b_dir_radians = paddleCollisionDir(relative_ball_y, state.b_dir_radians);
        state.b_speed = paddleCollisionSpeed(relative_ball_y);

        // move ball outside paddle
        if ((state.b_x - World.b_r) < World.p1_x + World.paddle_width) {
            state.b_x = World.p1_x + World.paddle_width + World.b_r;
        }
    } else if (checkCollisionPointRec(
        .{ .x = state.b_x + World.b_r, .y = state.b_y },
        p2,
    )) {
        const relative_ball_y: f32 = relativeYPos(.{ .x = state.b_x, .y = state.b_y }, p2);

        state.b_dir_radians = paddleCollisionDir(relative_ball_y, state.b_dir_radians);
        state.b_speed = paddleCollisionSpeed(relative_ball_y);

        // move ball outside paddle
        if ((state.b_x + World.b_r) > p2.x) {
            state.b_x = p2.x - World.b_r;
        }
    }

    // reflect off top wall
    if (state.b_y - World.b_r <= 0) {
        state.b_dir_radians = std.math.tau - state.b_dir_radians;
        state.b_y = World.b_r;
    }

    // reflect off bottom wall
    if (state.b_y + World.b_r >= World.height) {
        state.b_dir_radians = std.math.tau - state.b_dir_radians;
        state.b_y = World.height - World.b_r;
    }

    // TODO: score
    if (checkCollisionCircleLine( // left wall
        .{ .x = state.b_x, .y = state.b_y },
        World.b_r,
        .{ .x = 0, .y = 0 },
        .{ .x = 0, .y = World.height },
    )) {
        reset(state);
    } else if (checkCollisionCircleLine( // right wall
        .{ .x = state.b_x, .y = state.b_y },
        World.b_r,
        .{ .x = World.width, .y = 0 },
        .{ .x = World.width, .y = World.height },
    )) {
        reset(state);
    }

    // std.debug.print("speed (p/f): {d}\n", .{state.b_pix_per_f});
    const b_x_movement = @cos(state.b_dir_radians) * state.b_speed;
    const b_y_movement = @sin(state.b_dir_radians) * state.b_speed;

    state.b_x += b_x_movement;
    state.b_y -= b_y_movement;
    entities.append(allocator, .{
        .ball = true,
        .x = state.b_x,
        .y = state.b_y,
        .radius = World.b_r,
        .color = World.ball_color,
    }) catch @panic("Failed to allocate");

    const entities_copy = entities.toOwnedSlice(allocator) catch @panic("Failed to copy slice.");
    out.count = entities_copy.len;
    out.list = entities_copy.ptr;
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
    return @max(
        @as(f32, @floatFromInt(ball_max_units_per_s)) * relative_ball_y,
        ball_max_units_per_s,
    );
}

fn vertDistFromRectCenter(p: Vector2, rec: Entity) f32 {
    return @abs(p.y - (rec.y + (rec.height / 2)));
}

fn relativeYPos(p: Vector2, rec: Entity) f32 {
    const yPos: f32 = vertDistFromRectCenter(p, rec) / rec.height;

    std.debug.assert(yPos < 1.0);
    return yPos;
}
