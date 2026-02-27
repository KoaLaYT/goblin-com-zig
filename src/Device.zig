const std = @import("std");
const safec = @import("safec.zig");
const Font = @import("types.zig").Font;
const unicode = @import("unicode.zig");

const c = @cImport({
    @cInclude("sys/ioctl.h");
    @cInclude("termios.h");
    @cInclude("sys/select.h");
    @cInclude("unistd.h");
});

buffer: []u8,
stdout_writer: std.fs.File.Writer,
termios_orig: c.struct_termios,
font_last: Font,
cursor_x: u64,
cursor_y: u64,

const Self = @This();

pub fn init(alloc: std.mem.Allocator) !Self {
    const buffer = try alloc.alloc(u8, 1024);
    errdefer alloc.free(buffer);

    var self = Self{
        .buffer = buffer,
        .stdout_writer = std.fs.File.stdout().writer(buffer),
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

    self.flush();
    return self;
}

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    safec.call("tcsetattr", c.tcsetattr(std.posix.STDIN_FILENO, c.TCSANOW, &self.termios_orig)) catch unreachable;
    self.printf("\x1b[?25h\x1b[m\n", .{});
    self.flush();
    alloc.free(self.buffer);
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
        const fg = font.fore + 30 + f;
        const bg = font.back + 40 + b;
        self.printf("\x1b[{d};{d}m{s}", .{ fg, bg, str });
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
    self.flush();
}

pub fn printf(self: *Self, comptime fmt: []const u8, args: anytype) void {
    const stdout = &self.stdout_writer.interface;
    stdout.print(fmt, args) catch unreachable;
}

pub fn flush(self: *Self) void {
    const stdout = &self.stdout_writer.interface;
    stdout.flush() catch unreachable;
}

/// http://stackoverflow.com/questions/448944/c-non-blocking-keyboard-input
pub fn kbhit(useconds: c_long) bool {
    var tv: c.struct_timeval = .{
        .tv_sec = @divFloor(useconds, 1000000),
        .tv_usec = @mod(@as(c_int, @intCast(useconds)), 1000000),
    };
    var fds: c.fd_set = .{};
    c.FD_SET(std.posix.STDIN_FILENO, &fds);
    return c.select(1, &fds, 0, 0, &tv) > 0;
}

pub fn getch() u16 {
    var ch: u8 = undefined;

    const rc1 = c.read(std.posix.STDIN_FILENO, &ch, @sizeOf(u8));
    if (rc1 < 0) return 0;

    if (ch == '\x1b') {
        if (!kbhit(0)) return ch;
        var code: [2]u8 = undefined;
        const rc2 = c.read(std.posix.STDIN_FILENO, &code, @sizeOf([2]u8));
        if (rc2 < 0) return 0;
        return @as(u16, @intCast(code[1])) + 256;
    } else {
        // SIGINT
        if (ch == 3) {
            return 0;
        }
        return ch;
    }
}
