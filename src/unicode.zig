const std = @import("std");

/// given the leading byte of a utf8 character, return its total number of
/// bytes (1-4). does not check validity of any trailing bytes.
pub fn utf8_charlen(s: []const u8) usize {
    const c = s[0];
    if (c < 0x80) return 1; // 0xxxxxxx
    if ((c & 0xe0) == 0xc0) return 2; // 110xxxxx
    if ((c & 0xf0) == 0xe0) return 3; // 1110xxxx
    if ((c & 0xf8) == 0xf0 and (c <= 0xf4)) return 4; // 11110xxx
    return 0; // invalid UTF8
}

/// this one returns the utf8 len AND validates the full 1-4 bytes
/// TODO add additional checks to reject "overlong forms", (e.g.
/// representing a three byte UTF8 character in 4 bytes, etc) by
/// having all zeros in the high bit positions.
pub fn utf8_valid(s: []const u8) usize {
    const clen = utf8_charlen(s);
    if (clen == 0) return 0; // invalid utf8

    if (clen == 4 and (s[3] & 0xc0) != 0x80) return 0;
    if (clen == 3 and (s[2] & 0xc0) != 0x80) return 0;
    if (clen == 2 and (s[1] & 0xc0) != 0x80) return 0;
    if (clen == 1) {} // no trailing bytes to validate

    return clen;
}

/// convert UTF8 to UTF32
pub fn utf8_to_32(s: []const u8) u32 {
    return switch (utf8_valid(s)) {
        0 => 0, // invalid utf8
        1 => s[0], // no work, just promote size
        2 => (@as(u32, @intCast(s[0] & 0x1f)) << 6) | @as(u32, @intCast(s[1] & 0x3f)),
        3 => (@as(u32, @intCast(s[0] & 0x0f)) << 12) | (@as(u32, @intCast(s[1] & 0x3f)) << 6) | @as(u32, @intCast(s[2] & 0x3f)),
        4 => (@as(u32, @intCast(s[0] & 0x07)) << 18) | (@as(u32, @intCast(s[1] & 0x3f)) << 12) | (@as(u32, @intCast(s[2] & 0x3f)) << 6) | @as(u32, @intCast(s[3] & 0x3f)),
        else => 0,
    };
}

/// convert UTF32 to UTF8.
/// return the number of utf8 bytes (0-4) written to c
pub fn utf32_to_8(utf32: u32, utf8: []u8) usize {
    if (utf32 < 0x80) {
        utf8[0] = @intCast(utf32);
        return 1;
    }
    if (utf32 < 0x800) {
        utf8[0] = @intCast(0xc0 | ((utf32 & 0x07c0) >> 6));
        utf8[1] = @intCast(0x80 | (utf32 & 0x003f));
        return 2;
    }
    if (utf32 < 0x10000) {
        utf8[0] = @intCast(0xe0 | ((utf32 & 0xf000) >> 12));
        utf8[1] = @intCast(0x80 | ((utf32 & 0x0fc0) >> 6));
        utf8[2] = @intCast(0x80 | (utf32 & 0x003f));
        return 3;
    }
    if (utf32 < 0x110000) {
        utf8[0] = @intCast(0xf0 | ((utf32 & 0x1c0000) >> 18));
        utf8[1] = @intCast(0x80 | ((utf32 & 0x03f000) >> 12));
        utf8[2] = @intCast(0x80 | ((utf32 & 0x000fc0) >> 6));
        utf8[3] = @intCast(0x80 | (utf32 & 0x00003f));
        return 4;
    }

    // invalid utf32
    return 0;
}

test "utf8_charlen" {
    {
        const len = utf8_charlen("H");
        try std.testing.expectEqual(1, len);
    }
    {
        const len = utf8_charlen("你");
        try std.testing.expectEqual(3, len);
    }
    {
        const len = utf8_charlen("🎉");
        try std.testing.expectEqual(4, len);
    }
}

test "utf8_to_32" {
    {
        const v = utf8_to_32("H");
        try std.testing.expectEqual(72, v);
    }
    {
        const v = utf8_to_32("你");
        try std.testing.expectEqual(0x4F60, v);
    }
    {
        const v = utf8_to_32("🎉");
        try std.testing.expectEqual(0x1F389, v);
    }
}

test "utf32_to_8" {
    var buf: [7]u8 = undefined;
    {
        const v = utf32_to_8(72, &buf);
        try std.testing.expectEqualStrings("H", buf[0..v]);
    }
    {
        const v = utf32_to_8(0x4F60, &buf);
        try std.testing.expectEqualStrings("你", buf[0..v]);
    }
    {
        const v = utf32_to_8(0x1F389, &buf);
        try std.testing.expectEqualStrings("🎉", buf[0..v]);
    }
}
