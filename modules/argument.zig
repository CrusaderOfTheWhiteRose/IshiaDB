const std = @import("std");
const constant = @import("../index.zig");
const logger = @import("../modules/logger.zig");

pub fn calculateSizeByArgument(argument: []const u8) u64 {
    var number: usize = 0;
    var multiply: usize = 1;
    var index: u8 = 0;
    while (argument.len > index) {
        if (argument[index] == 98 or argument[index] == 66) {
            switch (argument[index - 1]) {
                103 => multiply = 1024 * 1024 * 1024,
                71 => multiply = 1024 * 1024 * 1024,
                109 => multiply = 1024 * 1024,
                77 => multiply = 1024 * 1024,
                107 => multiply = 1024,
                75 => multiply = 1024,
                else => multiply = 1,
            }
        }
        index += 1;
        number = std.fmt.parseInt(u64, argument[0..index], 10) catch number;
    }
    return multiply * number;
}

pub fn process(ishiaConfig: *constant.ishiaConfigStruct) !void {
    try read_config_yaml(ishiaConfig);
    var arguments = std.process.args();
    var lastArgument: []const u8 = "";
    while (arguments.next()) |argument| {
        switch (argument[1]) {
            115 => {
                lastArgument = argument;
            },
            112 => {
                lastArgument = argument;
            },
            102 => {
                lastArgument = argument;
            },
            else => {
                if (std.mem.eql(u8, lastArgument, "-s")) {
                    // ishiaConfig.storage = calculateSizeByArgument(argument);
                } else if (std.mem.eql(u8, lastArgument, "-f")) {
                    // ishiaConfig.file = calculateSizeByArgument(argument);
                } else if (std.mem.eql(u8, lastArgument, "-p")) {
                    ishiaConfig.port = std.fmt.parseInt(u16, argument, 10) catch 4200;
                }
            },
        }
    }
}

fn read_config_yaml(ishiaConfig: *constant.ishiaConfigStruct) !void {
    const yaml = std.fs.cwd().openFile("./ishia/config.yaml", .{}) catch {
        try logger.format.l("Initialisation", "Reader", "argument", "Ishia was not Detected                  ", "ishia/config.yaml", "NO_TIME", .{});
        return;
    };
    try logger.format.l("Initialisation", "Reader", "argument", "Ishia ConfigFile was Detected - Scanning", "ishia/config.yaml", "NO_TIME", .{});
    var buffer: [1024]u8 = undefined;
    const content = buffer[0..(try yaml.readAll(&buffer))];
    var configPerLine = std.mem.split(u8, content, "\n");
    while (configPerLine.next()) |l| {
        var line = l;
        if (line.len == 0) continue;
        while (line[0] == 32 or line[0] == 10) line = line[1..];
        while (line[line.len - 1] == 32) line = line[0..(line.len - 2)];
        var lineParse = std.mem.split(u8, line, ":");
        _ = lineParse.next();
        var value: []const u8 = "";
        if (lineParse.next()) |v| {
            value = v;
            if (value.len == 0) continue;
            while (value[0] == 32) value = value[1..];
        }
        if (line[0] == 112) ishiaConfig.port = std.fmt.parseInt(u16, value, 10) catch 4200;
    }
}
