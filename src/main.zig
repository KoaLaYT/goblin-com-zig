const std = @import("std");
const DISPLAY_WIDTH = @import("types.zig").DISPLAY_WIDTH;
const DISPLAY_HEIGHT = @import("types.zig").DISPLAY_HEIGHT;
const Font = @import("types.zig").Font;
const Panel = @import("types.zig").Panel;
const Device = @import("Device.zig");
const Display = @import("Display.zig");
const Rand = @import("Rand.zig");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var display = try Display.init(alloc);
    defer display.deinit(alloc);

    const width, const height = try Device.terminal_size();
    if (width < DISPLAY_WIDTH or height < DISPLAY_HEIGHT) {
        try print_error(width, height);
        return;
    }

    const rand = Rand.init();
    _ = rand;

    display.set_title("Goblin-COM");

    const loading_message = "Initializing world ...";
    var panel_loading = Panel.init_center(loading_message.len, 1);
    display.push(&panel_loading);
    panel_loading.puts(0, 0, Font.default, loading_message);
    display.refresh();

    // TODO loading game from save

    display.pop_free();
}

fn print_error(w: u64, h: u64) !void {
    const output =
        \\Goblin-COM requires a terminal of at least {}x{} characters!
        \\I see {}x{}
        \\Press enter to exit ...
    ;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print(output, .{ DISPLAY_WIDTH, DISPLAY_HEIGHT, w, h });
    try stdout.flush();

    var stdin_buffer: [1]u8 = undefined;
    var stdin_reader = std.fs.File.stdout().reader(&stdin_buffer);
    const stdin = &stdin_reader.interface;
    try stdin.fill(1);
}
