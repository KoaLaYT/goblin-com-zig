const std = @import("std");
const DISPLAY_WIDTH = @import("types.zig").DISPLAY_WIDTH;
const DISPLAY_HEIGHT = @import("types.zig").DISPLAY_HEIGHT;
const Device = @import("device.zig");
const Display = @import("display.zig");

pub fn main() void {
    var device = Device.init();
    defer device.deinit();

    var display = Display.init();
    display.refresh(&device);

    // const width, const height = device.terminal_size();
    //
    // if (width < DISPLAY_WIDTH or height < DISPLAY_HEIGHT) {
    //     exit(width, height);
    // }
    //
    // std.debug.print("{}x{}\n", .{ width, height });
}

fn exit(w: u64, h: u64) noreturn {
    const output =
        \\Goblin-COM requires a terminal of at least {}x{} characters!
        \\I see {}x{}
        \\Press enter to exit ...
    ;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    stdout.print(output, .{ DISPLAY_WIDTH, DISPLAY_HEIGHT, w, h }) catch unreachable;
    stdout.flush() catch unreachable;

    var stdin_buffer: [1]u8 = undefined;
    var stdin_reader = std.fs.File.stdout().reader(&stdin_buffer);
    const stdin = &stdin_reader.interface;
    stdin.fill(1) catch unreachable;
    std.process.exit(0);
}
