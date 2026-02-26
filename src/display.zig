const std = @import("std");

const DISPLAY_WIDTH = @import("types.zig").DISPLAY_WIDTH;
const DISPLAY_HEIGHT = @import("types.zig").DISPLAY_HEIGHT;
const Font = @import("types.zig").Font;
const Tile = @import("types.zig").Tile;
const Panel = @import("types.zig").Panel;
const Device = @import("device.zig");

current: [DISPLAY_WIDTH][DISPLAY_HEIGHT]Tile,
base: Panel,
panels: *Panel,

const Self = @This();

pub fn init() Self {
    var self = Self{
        .current = undefined,
        .base = undefined,
        .panels = undefined,
    };
    self.base = Panel.init(0, 0, DISPLAY_WIDTH, DISPLAY_HEIGHT);

    for (0..DISPLAY_HEIGHT) |y| {
        for (0..DISPLAY_WIDTH) |x| {
            self.base.putc(x, y, Font.default, ' ');
        }
    }
    self.panels = &self.base;

    return self;
}

pub fn refresh(self: *Self, device: *Device) void {
    var cx: u64 = 0;
    var cy: u64 = 0;
    device.move(cx, cy);

    _ = self;

    for (0..DISPLAY_HEIGHT) |y| {
        for (0..DISPLAY_WIDTH) |x| {
            cx = x;
            cy = y;
            device.move(cx, cy);
            device.putc(Font.default, ' ');
        }
    }
}

// void
// display_refresh(void)
// {
//     int cx = 0;
//     int cy = 0;
//     device_move(cx, cy);
//     for (int y = 0; y < DISPLAY_HEIGHT; y++) {
//         for (int x = 0; x < DISPLAY_WIDTH; x++) {
//             panel_t *p = display.panels;
//             while (p->tiles[x][y].transparent)
//                 p = p->next;
//             uint16_t oldc = display.current[x][y].c;
//             uint16_t newc = p->tiles[x][y].c;
//             font_t oldf = display.current[x][y].font;
//             font_t newf = p->tiles[x][y].font;
//             if (oldc != newc || !font_equal(oldf, newf)) {
//                 if (cx != x || cy != y)
//                     device_move(cx = x, cy = y);
//                 device_putc(newf, newc);
//                 display.current[x][y].font = newf;
//                 display.current[x][y].c = newc;
//                 cx++;
//             }
//         }
//     }
//     device_flush();
// }
