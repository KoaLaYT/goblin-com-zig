const std = @import("std");
const safec = @import("safec.zig");
const Font = @import("types.zig").Font;

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

pub fn init() Self {
    var self = Self{
        .buffer = undefined,
        .termios_orig = undefined,
        .font_last = Font.invalid,
        .cursor_x = 0,
        .cursor_y = 0,
    };

    self.printf("\x1b[2J", .{});

    safec.bailoutOnErr("tcgetattr", c.tcgetattr(std.posix.STDIN_FILENO, &self.termios_orig));

    var raw = self.termios_orig;
    const mask = c.tcflag_t;
    raw.c_iflag &= ~@as(mask, c.IGNBRK | c.BRKINT | c.PARMRK | c.ISTRIP | c.INLCR | c.IGNCR | c.ICRNL | c.IXON);
    raw.c_oflag &= ~@as(mask, c.OPOST);
    raw.c_lflag &= ~@as(mask, c.ECHO | c.ECHONL | c.ICANON | c.ISIG | c.IEXTEN);
    raw.c_cflag &= ~@as(mask, c.CSIZE | c.PARENB);
    raw.c_cflag |= @as(mask, c.CS8);
    safec.bailoutOnErr("tcsetattr", c.tcsetattr(std.posix.STDIN_FILENO, c.TCSANOW, &raw));
    self.printf("\x1b[?25l", .{});

    return self;
}

pub fn deinit(self: *Self) void {
    safec.bailoutOnErr("tcsetattr", c.tcsetattr(std.posix.STDIN_FILENO, c.TCSANOW, &self.termios_orig));
    self.printf("\x1b[?25h\x1b[m\n", .{});
}

pub fn move(self: *Self, x: u64, y: u64) void {
    self.cursor_x = x;
    self.cursor_y = y;
    self.font_last = Font.invalid;
    self.printf("\x1b[{d};{d}H", .{ y + 1, x + 1 });
}

// TODO add utf8 later
pub fn putc(self: *Self, font: Font, ch: u16) void {
    _ = ch;
    const f: u8 = if (font.fore_bright) 60 else 0;
    const b: u8 = if (font.back_bright) 60 else 0;
    self.printf("\x1b[{d};{d}m{c}", .{
        font.fore + 30 + f,
        font.back + 40 + b,
        'X',
    });
    self.font_last = font;
    self.cursor_x += 1;
}
//     void
// device_putc(font_t font, uint16_t c)
// {
//     uint8_t utf8[7];
//     utf8[utf32_to_8(c, utf8)] = '\0';
//     if (font_equal(device_font_last, font))
//         fputs((char *)utf8, stdout);
//     else
//         printf("\e[%d;%dm%s",
//                font.fore + 30 + (font.fore_bright ? 60 : 0),
//                font.back + 40 + (font.back_bright ? 60 : 0),
//                (char *)utf8);
//     device_font_last = font;
//     cursor_x++;
// }

fn printf(self: *Self, comptime fmt: []const u8, args: anytype) void {
    var stdout_writer = std.fs.File.stdout().writer(&self.buffer);
    var stdout = &stdout_writer.interface;
    stdout.print(fmt, args) catch unreachable;
    stdout.flush() catch unreachable;
}

// pub fn terminal_size() struct { u64, u64 } {
//     var size: c.winsize = undefined;
//     const rc = c.ioctl(std.posix.STDOUT_FILENO, c.TIOCGWINSZ, &size);
//     safec.bailoutOnErr("ioctl", rc);
//
//     return .{ size.ws_col, size.ws_row };
// }
