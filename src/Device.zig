const std = @import("std");
const safec = @import("safec.zig");
const Font = @import("types.zig").Font;
const unicode = @import("unicode.zig");

const c = @cImport({
    @cInclude("sys/ioctl.h");
    @cInclude("termios.h");
});

buffer: [1024]u8,
termios_orig: c.struct_termios,
font_last: Font,
cursor_x: u64,
cursor_y: u64,

const Self = @This();

pub fn init() !Self {
    var self = Self{
        .buffer = undefined,
        .termios_orig = undefined,
        .font_last = Font.invalid,
        .cursor_x = 0,
        .cursor_y = 0,
    };

    self.printf("\x1b[2J", .{});

    try safec.call("tcgetattr", c.tcgetattr(std.posix.STDIN_FILENO, &self.termios_orig));

    var raw = self.termios_orig;
    const mask = c.tcflag_t;
    raw.c_iflag &= ~@as(mask, c.IGNBRK | c.BRKINT | c.PARMRK | c.ISTRIP | c.INLCR | c.IGNCR | c.ICRNL | c.IXON);
    raw.c_oflag &= ~@as(mask, c.OPOST);
    raw.c_lflag &= ~@as(mask, c.ECHO | c.ECHONL | c.ICANON | c.ISIG | c.IEXTEN);
    raw.c_cflag &= ~@as(mask, c.CSIZE | c.PARENB);
    raw.c_cflag |= @as(mask, c.CS8);
    try safec.call("tcsetattr", c.tcsetattr(std.posix.STDIN_FILENO, c.TCSANOW, &raw));
    self.printf("\x1b[?25l", .{});

    return self;
}

pub fn deinit(self: *Self) void {
    safec.call("tcsetattr", c.tcsetattr(std.posix.STDIN_FILENO, c.TCSANOW, &self.termios_orig)) catch unreachable;
    self.printf("\x1b[?25h\x1b[m\n", .{});
}

pub fn move(self: *Self, x: u64, y: u64) void {
    self.cursor_x = x;
    self.cursor_y = y;
    self.font_last = Font.invalid;
    self.printf("\x1b[{d};{d}H", .{ y + 1, x + 1 });
}

pub fn putc(self: *Self, font: Font, ch: u16) void {
    var utf8: [7]u8 = undefined;
    const len = unicode.utf32_to_8(ch, &utf8);
    const str = utf8[0..len];

    if (self.font_last.equal(font)) {
        self.printf("{s}", .{str});
    } else {
        const f: u8 = if (font.fore_bright) 60 else 0;
        const b: u8 = if (font.back_bright) 60 else 0;
        self.printf("\x1b[{d};{d}m{s}", .{
            font.fore + 30 + f,
            font.back + 40 + b,
            str,
        });
    }

    self.font_last = font;
    self.cursor_x += 1;
}

pub fn terminal_size() !struct { u64, u64 } {
    var size: c.winsize = undefined;
    const rc = c.ioctl(std.posix.STDOUT_FILENO, c.TIOCGWINSZ, &size);
    try safec.call("ioctl", rc);

    return .{ size.ws_col, size.ws_row };
}

pub fn set_title(self: *Self, title: []const u8) void {
    self.printf("\x1b]2;{s}\x07", .{title});
}

fn printf(self: *Self, comptime fmt: []const u8, args: anytype) void {
    var stdout_writer = std.fs.File.stdout().writer(&self.buffer);
    var stdout = &stdout_writer.interface;
    stdout.print(fmt, args) catch unreachable;
    stdout.flush() catch unreachable;
}
