const std = @import("std");
const DISPLAY_WIDTH = @import("constants.zig").DISPLAY_WIDTH;
const DISPLAY_HEIGHT = @import("constants.zig").DISPLAY_HEIGHT;
const MAP_WIDTH = @import("constants.zig").MAP_WIDTH;
const MAP_HEIGHT = @import("constants.zig").MAP_HEIGHT;
const PERIOD = @import("constants.zig").PERIOD;
const Font = @import("types.zig").Font;
const Panel = @import("types.zig").Panel;
const Device = @import("Device.zig");
const Display = @import("Display.zig");
const Rand = @import("Rand.zig");
const Map = @import("Map.zig");
const text = @import("text.zig");

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

    var rand = Rand.init();

    display.set_title("Goblin-COM");

    const loading_message = "Initializing world ...";
    var panel_loading = Panel.init_center(loading_message.len, 1);
    display.push(&panel_loading);
    panel_loading.puts(0, 0, Font.default, loading_message);
    display.refresh();

    // TODO loading game from save

    display.pop_free();

    var sidemenu = Panel.init(MAP_WIDTH, 0, DISPLAY_WIDTH - MAP_WIDTH, DISPLAY_HEIGHT);
    display.push(&sidemenu);
    defer display.pop_free();

    var terrain = Panel.init(0, 0, MAP_WIDTH, MAP_HEIGHT);
    display.push(&terrain);
    defer display.pop_free();

    var map = try Map.init(alloc, &rand);
    defer map.deinit(alloc);

    var running: bool = true;
    var timer = try std.time.Timer.start();
    var frame_count: u32 = 0;
    var accumulated_time: f64 = 0;
    var fps: u32 = 0;
    while (running) {
        const delta_ns = timer.lap();
        const delta_seconds = @as(f64, @floatFromInt(delta_ns)) / std.time.ns_per_s;

        // TODO events

        sidemenu_draw(&sidemenu, fps);
        map.draw_terrain(&terrain);
        display.refresh();

        const wait = PERIOD - @as(u64, @intCast(std.time.microTimestamp())) % PERIOD;
        if (Device.kbhit(@intCast(wait))) {
            const key = Device.getch();

            switch (key) {
                // error happend
                0 => running = false,
                // quit, TODO popup
                'q', 'Q' => running = false,
                'p' => text.help(display, map, &terrain, 60, 19),
                else => {},
            }
        }

        frame_count += 1;
        accumulated_time += delta_seconds;

        if (accumulated_time >= 1.0) {
            fps = frame_count;
            frame_count = 0;
            accumulated_time -= 1.0;
        }
    }
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

fn sidemenu_draw(p: *Panel, fps: u32) void {
    const font_base = Font.text_gray;
    p.fill(font_base, ' ');
    p.border(font_base);
    p.puts(5, 1, font_base, "Goblin-COM");

    p.printf(2, 3, "Gold: Yk{{{}}}wk{{+{}}}", .{ 100, @as(i32, 1) }); // TODO
    p.printf(2, 4, "Food: Yk{{{}}}wk{{+{}}}", .{ 100, @as(i32, 1) });
    p.printf(2, 5, "Wood: Yk{{{}}}wk{{+{}}}", .{ 100, @as(i32, 1) });
    p.printf(2, 6, "Pop.: {}", .{100});

    p.printf(2, 8, "Kk{{♦}}    wk{{Rk{{B}}uild}}     Kk{{♦}}", .{});
    p.printf(2, 9, "Kk{{♦}}    wk{{Rk{{H}}eroes}}    Kk{{♦}}", .{});
    p.printf(2, 10, "Kk{{♦}}    wk{{Rk{{S}}quads}}    Kk{{♦}}", .{});

    p.printf(2, 17, "Kk{{♦}}    wk{{SRk{{t}}ory}}     Kk{{♦}}", .{});
    p.printf(2, 18, "Kk{{♦}}     wk{{HelRk{{p}}}}     Kk{{♦}}", .{});

    const font_totals = Font.text;
    //     char date[128];
    // game_date(game, date);
    // panel_puts(p, 2, 20, font_totals, date);

    p.puts(2, 21, font_base, "Speed: ");
    for (0..2) |i| {
        p.puts(9 + i, 21, font_totals, ">");
    }

    p.printf(2, 22, "wk{{FPS:}} {}", .{fps});
}
