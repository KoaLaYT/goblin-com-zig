const std = @import("std");
const unicode = @import("unicode.zig");
const DISPLAY_WIDTH = @import("constants.zig").DISPLAY_WIDTH;
const DISPLAY_HEIGHT = @import("constants.zig").DISPLAY_HEIGHT;

const Color = enum(u8) {
    black = 0,
    red = 1,
    green = 2,
    yellow = 3,
    blue = 4,
    magenta = 5,
    cyan = 6,
    white = 7,

    BLACK = 0x10 | 0,
    RED = 0x10 | 1,
    GREEN = 0x10 | 2,
    YELLOW = 0x10 | 3,
    BLUE = 0x10 | 4,
    MAGENTA = 0x10 | 5,
    CYAN = 0x10 | 6,
    WHITE = 0x10 | 7,
};

pub const Font = struct {
    fore: u8,
    back: u8,
    fore_bright: bool,
    back_bright: bool,

    const Self = @This();

    pub const default: Self = .{
        .fore = @intFromEnum(Color.white),
        .back = @intFromEnum(Color.black),
        .fore_bright = true,
        .back_bright = false,
    };

    pub const invalid: Self = .{
        .fore = 255,
        .back = 255,
        .fore_bright = false,
        .back_bright = false,
    };

    pub fn init() Self {
        return .{
            .fore = 0,
            .back = 0,
            .fore_bright = false,
            .back_bright = false,
        };
    }

    pub fn decode(s: []const u8) Font {
        std.debug.assert(s.len >= 2);
        const colors = "krgybmcw";
        const fore: u8 = @intCast(std.mem.indexOfScalar(u8, colors, std.ascii.toLower(s[0])).?);
        const back: u8 = @intCast(std.mem.indexOfScalar(u8, colors, std.ascii.toLower(s[1])).?);
        const fore_bright = std.ascii.isUpper(s[0]);
        const back_bright = std.ascii.isUpper(s[1]);
        return .{
            .fore = fore,
            .back = back,
            .fore_bright = fore_bright,
            .back_bright = back_bright,
        };
    }

    pub fn equal(self: Self, other: Self) bool {
        return self.fore == other.fore and self.back == other.back and self.fore_bright == other.fore_bright and self.back_bright == other.back_bright;
    }

    fn create(fore: Color, back: Color) Self {
        const f: u8 = @intFromEnum(fore);
        const b: u8 = @intFromEnum(back);
        return .{
            .fore = f & 0x0F,
            .back = b & 0x0F,
            .fore_bright = f & 0x10 >= 1,
            .back_bright = b & 0x10 >= 1,
        };
    }

    pub const ocean = create(Color.BLUE, Color.blue);
    pub const coast = create(Color.white, Color.blue);
    pub const grassland = create(Color.GREEN, Color.green);
    pub const forest = create(Color.GREEN, Color.green);
    pub const hill = create(Color.BLACK, Color.green);
    pub const mountain = create(Color.white, Color.green);
    pub const sand = create(Color.YELLOW, Color.YELLOW);

    pub const text = create(Color.WHITE, Color.black);
    pub const text_gray = create(Color.white, Color.black);

    pub const border = create(Color.BLACK, Color.black);
};

test "font" {
    const f = Font.forest;
    try std.testing.expect(f.fore_bright);
}

pub const Tile = struct {
    c: u16,
    transparent: bool,
    font: Font,

    const Self = @This();

    pub fn init() Self {
        return .{
            .c = 0,
            .transparent = false,
            .font = Font.init(),
        };
    }
};

pub const Panel = struct {
    x: u64,
    y: u64,
    w: u64,
    h: u64,
    tiles: [DISPLAY_WIDTH][DISPLAY_HEIGHT]Tile,
    next: ?*Panel,

    const Self = @This();

    pub fn init(x: u64, y: u64, w: u64, h: u64) Self {
        std.debug.assert(w <= DISPLAY_WIDTH);
        std.debug.assert(h <= DISPLAY_HEIGHT);

        var self = Self{
            .x = x,
            .y = y,
            .w = w,
            .h = h,
            .tiles = undefined,
            .next = null,
        };

        for (0..DISPLAY_HEIGHT) |yy| {
            for (0..DISPLAY_WIDTH) |xx| {
                var tile = Tile.init();
                tile.transparent = true;
                self.tiles[xx][yy] = tile;
            }
        }

        return self;
    }

    pub fn init_center(w: u64, h: u64) Self {
        const x = DISPLAY_WIDTH / 2 - w / 2;
        const y = DISPLAY_HEIGHT / 2 - h / 2;
        var self = init(x, y, w, h);
        self.fill(Font.default, ' ');
        return self;
    }

    pub fn deinit(self: *Self) void {
        std.debug.assert(self.next == null);
    }

    pub fn putc(self: *Self, x: u64, y: u64, font: Font, c: u16) void {
        const xx = x + self.x;
        const yy = y + self.y;

        if (xx >= 0 and xx < self.x + self.w and yy >= 0 and yy < self.y + self.h) {
            self.tiles[xx][yy].transparent = false;
            self.tiles[xx][yy].c = c;
            self.tiles[xx][yy].font = font;
        }
    }

    pub fn puts(self: *Self, x: u64, y: u64, font: Font, s: []const u8) void {
        var xx = x;
        var ss = s;

        while (ss.len > 0) {
            const c = unicode.utf8_to_32(ss);
            std.debug.assert(c <= 65535);
            self.putc(xx, y, font, @intCast(c));
            const len = unicode.utf8_charlen(ss);
            ss = ss[len..];
            xx += 1;
        }
    }

    pub fn fill(self: *Self, font: Font, c: u16) void {
        for (0..self.h) |y| {
            for (0..self.w) |x| {
                self.putc(x, y, font, c);
            }
        }
    }

    pub fn border(self: *Self, font: Font) void {
        for (1..self.w - 1) |x| {
            self.putc(x, 0, font, 0x2500);
            self.putc(x, self.h - 1, font, 0x2500);
        }
        for (1..self.h - 1) |y| {
            self.putc(0, y, font, 0x2502);
            self.putc(self.w - 1, y, font, 0x2502);
        }
        self.putc(0, 0, font, 0x250C);
        self.putc(self.w - 1, 0, font, 0x2510);
        self.putc(0, self.h - 1, font, 0x2514);
        self.putc(self.w - 1, self.h - 1, font, 0x2518);
    }

    pub fn printf(self: *Self, x: u64, y: u64, comptime fmt: []const u8, args: anytype) void {
        var f: usize = 0;
        var font: [16]Font = undefined;
        font[0] = Font.default;

        var buffer: [DISPLAY_WIDTH * 6 + 1]u8 = undefined;
        var str = std.fmt.bufPrint(&buffer, fmt, args) catch unreachable;
        var nest: usize = 0;
        var xx = x;

        while (str.len > 0) {
            if (is_color_directive(str)) {
                f += 1;
                font[f] = Font.decode(str);
                str = str[2..];
            } else if (str[0] == '}' and (nest > 0 or f > 0)) {
                if (nest > 0) {
                    self.putc(xx, y, font[f], str[0]);
                    xx += 1;
                    nest -= 1;
                } else {
                    f -= 1;
                }
            } else if (str[0] == '{') {
                nest += 1;
            } else {
                const c = unicode.utf8_to_32(str);
                std.debug.assert(c <= 65535);
                self.putc(xx, y, font[f], @intCast(c));
                xx += 1;
            }
            const len = unicode.utf8_charlen(str);
            str = str[len..];
        }
    }
};

fn is_color_directive(p: []const u8) bool {
    if (p.len < 3) return false;

    if (p[2] != '{') return false;

    const found0 = std.mem.indexOfScalar(u8, "rgbcmykwRGBCMYKW", p[0]);
    if (found0 == null) return false;

    const found1 = std.mem.indexOfScalar(u8, "rgbcmykwRGBCMYKW", p[1]);
    if (found1 == null) return false;

    return true;
}
