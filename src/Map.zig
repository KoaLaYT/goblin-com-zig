const std = @import("std");
const Rand = @import("Rand.zig");
const Panel = @import("types.zig").Panel;
const Font = @import("types.zig").Font;
const WIDTH = @import("constants.zig").MAP_WIDTH;
const HEIGHT = @import("constants.zig").MAP_HEIGHT;

const WORK_SIZE = 4097;
const NOISE_SCALE = 4.0;

const Base = enum(u16) {
    OCEAN = ' ',
    COAST = 0x2248,
    GRASSLAND = '.',
    FOREST = 0x2663,
    HILL = 0x2229,
    MOUNTAIN = 0x25B2,
    SAND = ':',

    fn font(base: Base, x: usize, y: usize) Font {
        const xf = @as(f64, @floatFromInt(x));
        const yf = @as(f64, @floatFromInt(y));
        return switch (base) {
            .OCEAN => Font.ocean,
            .COAST => {
                var f = Font.coast;
                const epoch = @as(f64, @floatFromInt(std.time.microTimestamp()));
                const dx = ((xf / WIDTH) - 0.5) * 1.3;
                const dy = (yf / HEIGHT) - 0.5;
                const dist = @sqrt(dx * dx + dy * dy) * 100;
                const offset = @mod(epoch / 500000.0, std.math.pi * 2);
                f.fore_bright = if (@sin(dist + offset) < 0) true else false;
                return f;
            },
            .GRASSLAND => Font.grassland,
            .FOREST => Font.forest,
            .HILL => Font.hill,
            .MOUNTAIN => Font.mountain,
            .SAND => Font.sand,
        };
    }
};

const High = struct {
    base: Base,
    building: u16,
    building_age: i64,
};

const Low = struct {
    height: f64,
};

high: [WIDTH][HEIGHT]High,
low: [WIDTH * WIDTH][HEIGHT * HEIGHT]Low,

const Self = @This();

fn grow(map: []const f64, size: usize, out: []f64, rand: *Rand) usize {
    const osize = (size - 1) * 2 + 1;
    // Copy
    for (0..size) |y| {
        for (0..size) |x| {
            out[y * 2 * osize + x * 2] = map[y * size + x];
        }
    }
    // Diamond
    {
        var y: usize = 1;
        while (y < osize) : (y += 2) {
            var x: usize = 1;
            while (x < osize) : (x += 2) {
                var count: f64 = 0.0;
                var sum: f64 = 0.0;
                var dy: i64 = -1;
                while (dy <= 1) : (dy += 2) {
                    var dx: i64 = -1;
                    while (dx <= 1) : (dx += 2) {
                        const ii = (@as(i64, @intCast(y)) + dy) * @as(i64, @intCast(osize)) + (@as(i64, @intCast(x)) + dx);

                        const i = @as(usize, @intCast(ii));
                        if (i >= 0 and i < osize * osize) {
                            sum += out[i];
                            count += 1;
                        }
                    }
                }
                const u = rand.uniform_s(-1, 1);
                out[y * osize + x] = sum / count + u / @as(f64, @floatFromInt(osize)) * NOISE_SCALE;
            }
        }
    }
    // Square
    const pos: [4]struct { i64, i64 } = .{ .{ -1, 0 }, .{ 1, 0 }, .{ 0, -1 }, .{ 0, 1 } };
    for (1..osize) |y| {
        var x: usize = (y + 1) % 2;
        while (x < osize) : (x += 2) {
            var count: f64 = 0.0;
            var sum: f64 = 0.0;
            for (0..4) |p| {
                const xx, const yy = pos[p];
                const ii = (@as(i64, @intCast(y)) + yy) * @as(i64, @intCast(osize)) + (@as(i64, @intCast(x)) + xx);
                const i = @as(usize, @intCast(ii));
                if (i >= 0 and i < osize * osize) {
                    sum += out[i];
                    count += 1;
                }
            }
            const u = rand.uniform_s(-1, 1);
            out[y * osize + x] = sum / count + u / @as(f64, @floatFromInt(osize)) * NOISE_SCALE;
        }
    }
    return osize;
}

fn summarize(self: *Self, rand: *Rand) void {
    const size = @as(f64, @floatFromInt(WIDTH * HEIGHT));
    for (0..HEIGHT) |y| {
        for (0..WIDTH) |x| {
            var mean: f64 = 0.0;
            for (0..HEIGHT) |sy| {
                for (0..WIDTH) |sx| {
                    const ix = x * WIDTH + sx;
                    const iy = y * HEIGHT + sy;
                    mean += self.low[ix][iy].height;
                }
            }
            mean /= size;
            var std_: f64 = 0.0;
            for (0..HEIGHT) |sy| {
                for (0..WIDTH) |sx| {
                    const ix = x * WIDTH + sx;
                    const iy = y * HEIGHT + sy;
                    const diff = mean - self.low[ix][iy].height;
                    std_ += diff * diff;
                }
            }
            std_ = @sqrt(std_ / size);
            var base: Base = undefined;
            if (mean < -0.8) {
                base = Base.OCEAN;
            } else if (mean < -0.6) {
                base = Base.COAST;
            } else if (mean < -0.5) {
                base = Base.SAND;
            } else if (std_ > 0.05) {
                base = Base.MOUNTAIN;
            } else if (std_ > 0.04) {
                base = Base.HILL;
            } else if (rand.uniform_s(-1, 1) > -0.2) {
                base = Base.GRASSLAND;
            } else {
                base = Base.FOREST;
            }
            self.high[x][y].base = base;
            self.high[x][y].building = 0;
        }
    }
}

pub fn init(alloc: std.mem.Allocator, rand: *Rand) !*Self {
    var self = try alloc.create(Self);
    errdefer alloc.destroy(self);

    var buf_a = try alloc.alloc(f64, WORK_SIZE * WORK_SIZE);
    defer alloc.free(buf_a);
    var buf_b = try alloc.alloc(f64, WORK_SIZE * WORK_SIZE);
    defer alloc.free(buf_b);

    @memset(buf_a, 0);
    @memset(buf_b, 0);

    var heightmap = buf_a;
    for (0..4) |i| {
        heightmap[i] = rand.uniform_s(-1, 1);
    }

    var size: usize = 3;
    while (size < WORK_SIZE) {
        size = grow(buf_a, size, buf_b, rand);
        heightmap = buf_b;
        buf_b = buf_a;
        buf_a = heightmap;
    }

    for (0..HEIGHT * HEIGHT) |y| {
        const yf: f64 = @floatFromInt(y);

        for (0..WIDTH * WIDTH) |x| {
            const xf: f64 = @floatFromInt(x);

            const height = heightmap[y * WORK_SIZE + x];
            const sx = xf / (WIDTH * WIDTH) - 0.5;
            const sy = yf / (HEIGHT * HEIGHT) - 0.5;
            const s = @sqrt(sx * sx + sy * sy) * 3 - 0.45;
            self.low[x][y].height = height - s;
        }
    }

    self.summarize(rand);
    return self;
}

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    alloc.destroy(self);
}

pub fn draw_terrain(self: *Self, p: *Panel) void {
    for (0..HEIGHT) |y| {
        for (0..WIDTH) |x| {
            const b = self.high[x][y].base;
            const font = b.font(x, y);
            p.putc(x, y, font, @intFromEnum(b));
        }
    }
}

test "generate" {
    const alloc = std.testing.allocator;
    var rand = Rand.init();

    const m = try init(alloc, &rand);
    defer m.deinit(alloc);
}
