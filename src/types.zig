const std = @import("std");

pub const DISPLAY_WIDTH = 80;
pub const DISPLAY_HEIGHT = 24;

const COLOR_BLACK = 0;
const COLOR_RED = 1;
const COLOR_GREEN = 2;
const COLOR_YELLOW = 3;
const COLOR_BLUE = 4;
const COLOR_MAGENTA = 5;
const COLOR_CYAN = 6;
const COLOR_WHITE = 7;

pub const Font = struct {
    fore: u8,
    back: u8,
    fore_bright: bool,
    back_bright: bool,

    const Self = @This();

    pub const default: Self = .{
        .fore = COLOR_WHITE,
        .back = COLOR_BLACK,
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
};

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
            for (0..DISPLAY_HEIGHT) |xx| {
                var tile = Tile.init();
                tile.transparent = true;
                self.tiles[xx][yy] = tile;
            }
        }

        return self;
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
};
