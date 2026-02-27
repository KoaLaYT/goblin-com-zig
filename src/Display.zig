const std = @import("std");

const DISPLAY_WIDTH = @import("constants.zig").DISPLAY_WIDTH;
const DISPLAY_HEIGHT = @import("constants.zig").DISPLAY_HEIGHT;
const Font = @import("types.zig").Font;
const Tile = @import("types.zig").Tile;
const Panel = @import("types.zig").Panel;
const Device = @import("Device.zig");

device: Device,
current: [DISPLAY_WIDTH][DISPLAY_HEIGHT]Tile,
base: Panel,
panels: *Panel,

const Self = @This();

pub fn init(alloc: std.mem.Allocator) !*Self {
    var device = try Device.init(alloc);
    errdefer device.deinit(alloc);

    const self = try alloc.create(Self);
    self.* = Self{
        .device = device,
        .current = undefined,
        .base = undefined,
        .panels = undefined,
    };

    self.base = Panel.init(0, 0, DISPLAY_WIDTH, DISPLAY_HEIGHT);

    for (0..DISPLAY_HEIGHT) |y| {
        for (0..DISPLAY_WIDTH) |x| {
            self.current[x][y] = Tile.init();
            self.base.putc(x, y, Font.default, ' ');
        }
    }

    self.panels = &self.base;

    self.refresh();
    return self;
}

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    self.device.move(0, DISPLAY_HEIGHT);
    std.debug.assert(self.panels == &self.base);
    self.base.deinit();
    self.device.deinit(alloc);
    alloc.destroy(self);
}

pub fn refresh(self: *Self) void {
    var cx: u64 = 0;
    var cy: u64 = 0;
    self.device.move(cx, cy);

    for (0..DISPLAY_HEIGHT) |y| {
        for (0..DISPLAY_WIDTH) |x| {
            var p: ?*Panel = self.panels;
            while (p != null and p.?.tiles[x][y].transparent) {
                p = p.?.next;
            }
            if (p) |panel| {
                const oldc = self.current[x][y].c;
                const newc = panel.tiles[x][y].c;
                const oldf = self.current[x][y].font;
                const newf = panel.tiles[x][y].font;
                if (oldc != newc or !oldf.equal(newf)) {
                    if (cx != x or cy != y) {
                        cx = x;
                        cy = y;
                        self.device.move(cx, cy);
                    }
                    self.device.putc(newf, newc);
                    self.current[x][y].font = newf;
                    self.current[x][y].c = newc;
                    cx += 1;
                }
            }
        }
    }

    self.device.flush();
}

pub fn set_title(self: *Self, title: []const u8) void {
    self.device.set_title(title);
}

pub fn push(self: *Self, p: *Panel) void {
    p.next = self.panels;
    self.panels = p;
}

pub fn pop(self: *Self) void {
    var d = self.panels;
    std.debug.assert(self.panels.next != null);
    self.panels = self.panels.next.?;
    d.next = null;
}

pub fn pop_free(self: *Self) void {
    var d = self.panels;
    self.pop();
    d.deinit();
}
