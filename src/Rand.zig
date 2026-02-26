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
