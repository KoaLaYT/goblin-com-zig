const std = @import("std");

state: u64,

const Self = @This();

pub fn init() Self {
    var bytes: [8]u8 = undefined;
    std.crypto.random.bytes(&bytes);
    const state = std.mem.readInt(u64, &bytes, .little);
    return .{
        .state = state,
    };
}

pub fn xorshift(self: *Self) u64 {
    var x = self.state;
    x ^= x >> 12; // a
    x ^= x << 25; // b
    x ^= x >> 27; // c
    self.state = x;
    return x *% 2685821657736338717;
}

pub fn uniform_s(self: *Self, min: f64, max: f64) f64 {
    const u = @as(f64, @floatFromInt(self.xorshift())) / 18446744073709551615.0;
    return u * (max - min) + min;
}

test "xorshift" {
    var r = init();
    const v = r.xorshift();
    try std.testing.expect(v > 0);
}

test "uniform_s" {
    var r = init();
    for (0..100) |_| {
        const v = r.uniform_s(-1, 1);
        try std.testing.expect(v > -1 and v < 1);
    }
}
