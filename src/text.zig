const std = @import("std");
const Panel = @import("types.zig").Panel;
const Font = @import("types.zig").Font;
const Display = @import("Display.zig");
const Device = @import("Device.zig");
const Map = @import("Map.zig");
const constants = @import("constants.zig");

const doc_help = @embedFile("./doc/help.txt");

test "doc" {
    _ = doc_help;
}

pub fn help(display: *Display, map: *Map, terrain: *Panel, w: u64, h: u64) void {
    page(display, map, terrain, doc_help, w, h);
}

fn page(display: *Display, map: *Map, terrain: *Panel, p: []const u8, w: u64, h: u64) void {
    var panel = Panel.init_center(w + 4, h + 2);
    display.push(&panel);
    defer display.pop_free();

    const border = Font.border;
    const lines = numlines(p);
    var topline: usize = 0;
    var top = p;

    var key: u16 = 0;
    while (true) {
        switch (key) {
            constants.ARROW_D => {
                if (topline < lines - h) {
                    topline += 1;
                    top = next_line(top);
                }
            },
            constants.ARROW_U => {
                if (topline > 1) {
                    topline -= 1;
                    top = prev_line(&p.ptr[0], top);
                } else if (topline == 1) {
                    topline = 0;
                    top = p;
                }
            },
            else => {},
        }
        panel.fill(Font.default, ' ');
        panel.border(border);
        if (lines > h) {
            panel.printf(w + 3, 1, "Rk{{↑}}", .{});
            const percent = @as(f64, @floatFromInt(topline)) / @as(f64, @floatFromInt(lines - h));
            const o: u64 = @intFromFloat(@floor(percent * @as(f64, @floatFromInt(h - 3))));
            panel.printf(w + 3, o + 2, "wk{{o}}", .{});
            panel.printf(w + 3, h, "Rk{{↓}}", .{});
        }

        var line = top;
        var y: usize = 0;
        while (y < h and topline + y < lines) : (y += 1) {
            const length = linelen(line);
            panel.printf(2, y + 1, "{s}", .{line[0..length]});
            line = next_line(line);
        }

        key = game_getch(display, map, terrain);
        if (is_exit_key(key)) break;
    }
}

fn is_exit_key(key: u16) bool {
    return key == 'Q' or key == 'q' or key == 27;
}

fn game_getch(display: *Display, map: *Map, terrain: *Panel) u16 {
    while (true) {
        map.draw_terrain(terrain);
        display.refresh();

        const wait = constants.PERIOD - @as(u64, @intCast(std.time.microTimestamp())) % constants.PERIOD;
        if (Device.kbhit(@intCast(wait))) {
            return Device.getch();
        }
    }
}

fn numlines(p: []const u8) usize {
    var count: usize = 0;

    var pp = p;
    while (pp.len > 0) {
        if (pp[0] == '@') break;

        pp = next_line(pp);
        count += 1;
    }

    return count;
}

fn next_line(p: []const u8) []const u8 {
    var i: usize = 0;

    while (p[i] != '\n') {
        i += 1;
    }

    return p[i + 1 ..];
}

// TODO this is ugly..
fn prev_line(o: *const u8, p: []const u8) []const u8 {
    var pp = p;
    pp.ptr -= 2;

    var len: usize = 2; // current and \n
    while (pp.ptr[0] != '\n' and &pp[0] != o) {
        len += 1;
        pp.ptr -= 1;
    }
    pp.len = len + p.len;
    if (&pp[0] != o) pp.ptr += 1;
    return pp;
}

fn linelen(p: []const u8) usize {
    var count: usize = 0;

    while (p[count] != '\n') {
        count += 1;
    }

    return count;
}

test "numlines" {
    const lines = numlines(doc_help);
    try std.testing.expectEqual(48, lines);
}

test "prev_line" {
    const lines =
        \\ line1
        \\ line234
    ;

    const next = next_line(lines);
    try std.testing.expectEqualStrings(" line234", next);

    const prev = prev_line(&lines[0], next);
    try std.testing.expectEqualStrings(lines, prev);
}
