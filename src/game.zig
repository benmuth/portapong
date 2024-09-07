const std = @import("std");
const rl = @cImport({
    @cInclude("/Users/ben/builds/raylib/zig-out/include/raylib.h");
});

const ibm_plex = @embedFile("IBMPlexMono-Regular.otf");

const max_input_chars: u8 = 9;

const Editor = struct {
    allocator: std.mem.Allocator,

    text_box: rl.Rectangle = .{ .x = 300, .y = 180, .width = 225, .height = 50 },
    mouse_on_text: bool = false,

    text: [*c]u8,

    frames_counter: u32 = 0,

    letter_count: u32 = 0,

    window_width: c_int = 200,
    window_height: c_int = 200,

    // font: rl.Font,
};

// const font_dir_name = "/Users/ben/Library/Fonts/";
// const font_name = "IBMPlexMono-Regular.otf";
// const config_filepath = "config/radius.txt";

const text_box: rl.Rectangle = .{};

export fn init(window_width: c_int, window_height: c_int) *anyopaque {
    var allocator = std.heap.c_allocator;
    const editor_state = allocator.create(Editor) catch @panic("out of memory.");
    const text = allocator.allocSentinel(u8, 9, 0) catch @panic("out of memory.");
    text[0] = 0;

    // var font_dir = std.fs.openDirAbsolute(font_dir_name, .{}) catch @panic("failed to load font");
    // defer font_dir.close();
    // const font_data = font_dir.readFileAlloc(allocator, font_name, 128 * 1024) catch @panic("failed to load font");
    // std.debug.print("font data size: {d}\n", .{font_data.len});
    // .font = rl.LoadFontEx("/Users/ben/Library/Fonts/IBMPlexMono-Regular.otf", 16, null, 0);

    // std.fs.openFileAbsolute("/Users/ben/Library/Fonts/IBMPlexMono-Regular.otf", std.fs.)
    // std.debug.print("{x}\n", .{ibm_plex});

    // const font = rl.LoadFontFromMemory(".otf", ibm_plex, 62364, 16, null, 0);
    // const font = rl.LoadFontEx("IBMPlexMono-Regular.otf", 16, null, 0);

    // std.debug.print("{s}\n", .{font});
    editor_state.* = .{
        .allocator = allocator,
        .text = text,
        .window_width = window_width,
        .window_height = window_height,
        // .font = font,
    };

    return editor_state;
}

export fn reload(editor_state_ptr: *anyopaque) void {
    var editor_state: *Editor = @ptrCast(@alignCast(editor_state_ptr));
    editor_state.frames_counter = 0;
}

export fn draw(editor_state_ptr: *anyopaque) void {
    std.debug.print("{p}\n", .{editor_state_ptr});

    const editor_state: *Editor = @ptrCast(@alignCast(editor_state_ptr));
    std.debug.print("4\n", .{});

    rl.BeginDrawing();
    rl.ClearBackground(rl.RAYWHITE);

    rl.DrawText("PLACE MOUSE OVER INPUT BOX!", 240, 140, 20, rl.GRAY);

    rl.DrawRectangleRec(editor_state.text_box, rl.LIGHTGRAY);
    if (editor_state.mouse_on_text) {
        rl.DrawRectangleLines(
            @as(c_int, @intFromFloat(editor_state.text_box.x)),
            @as(c_int, @intFromFloat(editor_state.text_box.y)),
            @as(c_int, @intFromFloat(editor_state.text_box.width)),
            @as(c_int, @intFromFloat(editor_state.text_box.height)),
            rl.RED,
        );
    } else {
        rl.DrawRectangleLines(
            @as(c_int, @intFromFloat(editor_state.text_box.x)),
            @as(c_int, @intFromFloat(editor_state.text_box.y)),
            @as(c_int, @intFromFloat(editor_state.text_box.width)),
            @as(c_int, @intFromFloat(editor_state.text_box.height)),
            rl.DARKGRAY,
        );
    }

    // rl.DrawTextEx(editor_state.font, editor_state.text, .{ .x = (editor_state.text_box.x + 5), .y = editor_state.text_box.y + 8 }, 16, 1.0, rl.MAROON);
    rl.DrawText(editor_state.text, @as(c_int, @intFromFloat(editor_state.text_box.x + 5)), @as(c_int, @intFromFloat(editor_state.text_box.y + 8)), 40, rl.MAROON);

    rl.DrawText(rl.TextFormat("INPUT CHARS: %i/%i", editor_state.letter_count, max_input_chars), 315, 250, 20, rl.DARKGRAY);

    if (editor_state.mouse_on_text) {
        if (editor_state.letter_count < max_input_chars) {
            // Draw blinking underscore char
            if (((editor_state.frames_counter / 20) % 2) == 0) {
                rl.DrawText(
                    "_",
                    @as(c_int, @intFromFloat(editor_state.text_box.x)) + 8 + rl.MeasureText(editor_state.text, 40),
                    @as(c_int, @intFromFloat(editor_state.text_box.y + 12)),
                    40,
                    rl.MAROON,
                );
            }
        } else {
            rl.DrawText("Press BACKSPACE to delete chars...", 230, 300, 20, rl.GRAY);
        }
    }

    rl.EndDrawing();
}

export fn update(editor_state_ptr: *anyopaque) void {
    std.debug.print("{p}\n", .{editor_state_ptr});
    // const editor_state: *Editor = @ptrCast(@alignCast(editor_state_ptr));

    // editor_state.mouse_on_text = rl.CheckCollisionPointRec(rl.GetMousePosition(), editor_state.text_box);

    // if (editor_state.mouse_on_text) {
    //     rl.SetMouseCursor(rl.MOUSE_CURSOR_IBEAM);

    //     var key: u8 = @as(u8, @intCast(rl.GetCharPressed()));

    //     while (key > 0) : (key = @as(u8, @intCast(rl.GetCharPressed()))) {
    //         if ((key >= 32) and (key <= 125) and (editor_state.letter_count < max_input_chars)) {
    //             editor_state.text[editor_state.letter_count] = key;
    //             editor_state.letter_count += 1;
    //             editor_state.text[editor_state.letter_count] = 0;
    //         }
    //     }

    //     if (rl.IsKeyPressed(rl.KEY_BACKSPACE)) {
    //         editor_state.letter_count -|= 1;
    //         // if (editor_state.letter_count < 0) editor_state.letter_count = 0;
    //         editor_state.text[editor_state.letter_count] = 0;
    //     }
    // } else {
    //     rl.SetMouseCursor(rl.MOUSE_CURSOR_DEFAULT);
    // }

    // if (editor_state.mouse_on_text) {
    //     editor_state.frames_counter += 1;
    // } else {
    //     editor_state.frames_counter = 0;
    // }
}
