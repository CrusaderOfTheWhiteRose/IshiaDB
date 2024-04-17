const std = @import("std");

pub var cache: std.StringHashMap([]const u8) = undefined;
