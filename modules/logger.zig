const std = @import("std");

pub fn d(comptime fmt: []const u8, args: anytype) !void {
    try std.io.getStdOut().writer().print("\x1b[37m" ++ fmt ++ "\x1b[0m\n", args);
}
pub fn v(comptime fmt: []const u8, args: anytype) !void {
    try std.io.getStdOut().writer().print("\x1b[34m" ++ fmt ++ "\x1b[0m\n", args);
}
pub fn l(comptime fmt: []const u8, args: anytype) !void {
    try std.io.getStdOut().writer().print("\x1b[32m" ++ fmt ++ "\x1b[0m\n", args);
}
pub fn w(comptime fmt: []const u8, args: anytype) !void {
    try std.io.getStdOut().writer().print("\x1b[33m" ++ fmt ++ "\x1b[0m\n", args);
}
pub fn e(comptime fmt: []const u8, args: anytype) !void {
    try std.io.getStdOut().writer().print("\x1b[31m" ++ fmt ++ "\x1b[0m\n", args);
}
pub fn f(comptime fmt: []const u8, args: anytype) !void {
    try std.io.getStdOut().writer().print("\x1b[39m" ++ fmt ++ "\x1b[0m\n", args);
}
pub const format = struct {
    pub fn d(comptime process: []const u8, comptime sub_process: []const u8, comptime file_name: []const u8, comptime content: []const u8, comptime value: []const u8, comptime time: []const u8, args: anytype) !void {
        try std.io.getStdOut().writer().print("\x1b[37m    " ++ process ++ " :: " ++ sub_process ++ " @ " ++ file_name ++ " > " ++ content ++ " | " ++ "[" ++ value ++ "]" ++ " # " ++ "[" ++ time ++ "] MilliSeconds" ++ " \x1b[0m\n", args);
    }
    pub fn v(comptime process: []const u8, comptime sub_process: []const u8, comptime file_name: []const u8, comptime content: []const u8, comptime value: []const u8, comptime time: []const u8, args: anytype) !void {
        try std.io.getStdOut().writer().print("\x1b[34m    " ++ process ++ " :: " ++ sub_process ++ " @ " ++ file_name ++ " > " ++ content ++ " | " ++ "[" ++ value ++ "]" ++ " # " ++ "[" ++ time ++ "] MilliSeconds" ++ " \x1b[0m\n", args);
    }
    pub fn l(comptime process: []const u8, comptime sub_process: []const u8, comptime file_name: []const u8, comptime content: []const u8, comptime value: []const u8, comptime time: []const u8, args: anytype) !void {
        try std.io.getStdOut().writer().print("\x1b[32m    " ++ process ++ " :: " ++ sub_process ++ " @ " ++ file_name ++ " > " ++ content ++ " | " ++ "[" ++ value ++ "]" ++ " # " ++ "[" ++ time ++ "] MilliSeconds" ++ " \x1b[0m\n", args);
    }
    pub fn w(comptime process: []const u8, comptime sub_process: []const u8, comptime file_name: []const u8, comptime content: []const u8, comptime value: []const u8, comptime time: []const u8, args: anytype) !void {
        try std.io.getStdOut().writer().print("\x1b[33m    " ++ process ++ " :: " ++ sub_process ++ " @ " ++ file_name ++ " > " ++ content ++ " | " ++ "[" ++ value ++ "]" ++ " # " ++ "[" ++ time ++ "] MilliSeconds" ++ " \x1b[0m\n", args);
    }
    pub fn e(comptime process: []const u8, comptime sub_process: []const u8, comptime file_name: []const u8, comptime content: []const u8, comptime value: []const u8, comptime time: []const u8, args: anytype) !void {
        try std.io.getStdOut().writer().print("\x1b[31m    " ++ process ++ " :: " ++ sub_process ++ " @ " ++ file_name ++ " > " ++ content ++ " | " ++ "[" ++ value ++ "]" ++ " # " ++ "[" ++ time ++ "] MilliSeconds" ++ " \x1b[0m\n", args);
    }
    pub fn f(comptime process: []const u8, comptime sub_process: []const u8, comptime file_name: []const u8, comptime content: []const u8, comptime value: []const u8, comptime time: []const u8, args: anytype) !void {
        try std.io.getStdOut().writer().print("\x1b[39m    " ++ process ++ " :: " ++ sub_process ++ " @ " ++ "[" ++ file_name ++ "]" ++ " > " ++ content ++ " | " ++ "[" ++ value ++ "]" ++ " # " ++ "[" ++ time ++ "] MilliSeconds" ++ " \x1b[0m\n", args);
    }
};
