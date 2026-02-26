const std = @import("std");

const c = @cImport({
    @cInclude("string.h");
});

pub fn call(comptime prefix: []const u8, rc: c_int) !void {
    if (rc < 0) {
        const errno = std.c._errno().*;
        const err_str = std.mem.span(c.strerror(errno));
        std.log.err("c.{s}: {s}", .{ prefix, err_str });
        return error.CallCFailed;
    }
}
