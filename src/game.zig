const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});

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
};

export fn init(window_width: c_int, window_height: c_int, paddle_height: c_int) *anyopaque {
    var allocator = std.heap.c_allocator;
    const game_state = allocator.create(Game) catch @panic("out of memory.");

    const paddle_width = @divTrunc(window_width, 10);
    // const p1_x = ;
    // const p2_x = window_width - paddle_width;

    game_state.* = .{
        .allocator = allocator,
        .window_width = window_width,
        .window_height = window_height,
        .paddle_height = paddle_height,
        .paddle_width = paddle_width,
        .p1_x = paddle_width,
        .p2_x = window_width - (2 * paddle_width),
        .p1_y = @divTrunc(window_height, 2) - @divTrunc(paddle_height, 2),
        .p2_y = @divTrunc(window_height, 2) - @divTrunc(paddle_height, 2),
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

    rl.DrawRectangle(game_state.p1_x, game_state.p1_y, game_state.paddle_width, game_state.paddle_height, rl.Color{ .r = 0, .g = 0, .b = 0, .a = 200 });
    rl.DrawRectangle(game_state.p2_x, game_state.p2_y, game_state.paddle_width, game_state.paddle_height, rl.Color{ .r = 0, .g = 0, .b = 0, .a = 200 });

    rl.EndDrawing();
}

export fn update(game_state_ptr: *anyopaque) void {
    _ = game_state_ptr;
    // const game_state: *game = @ptrCast(@alignCast(game_state_ptr));

    // game_state.mouse_on_text = rl.CheckCollisionPointRec(rl.GetMousePosition(), game_state.text_box);

    // if (game_state.mouse_on_text) {
    //     rl.SetMouseCursor(rl.MOUSE_CURSOR_IBEAM);

    //     var key: u8 = @as(u8, @intCast(rl.GetCharPressed()));

    //     while (key > 0) : (key = @as(u8, @intCast(rl.GetCharPressed()))) {
    //         if ((key >= 32) and (key <= 125) and (game_state.letter_count < max_input_chars)) {
    //             game_state.text[game_state.letter_count] = key;
    //             game_state.letter_count += 1;
    //             game_state.text[game_state.letter_count] = 0;
    //         }
    //     }

    //     if (rl.IsKeyPressed(rl.KEY_BACKSPACE)) {
    //         game_state.letter_count -|= 1;
    //         // if (game_state.letter_count < 0) game_state.letter_count = 0;
    //         game_state.text[game_state.letter_count] = 0;
    //     }
    // } else {
    //     rl.SetMouseCursor(rl.MOUSE_CURSOR_DEFAULT);
    // }

    // if (game_state.mouse_on_text) {
    //     game_state.frames_counter += 1;
    // } else {
    //     game_state.frames_counter = 0;
    // }
}
