const std = @import("std");

pub fn create_file(path: []const u8) !void {
    const cacheCreated = std.fs.cwd().createFile(path, .{});
    if (cacheCreated) |_| {
        //
    } else |err| {
        if (err == error.PathAlreadyExists) {
            //
        }
    }
}

pub fn create_directory(path: []const u8) !void {
    const archiveCreated = std.fs.cwd().makeDir(path);
    if (archiveCreated) |_| {
        //
    } else |err| {
        if (err == error.PathAlreadyExists) {
            //
        }
    }
}
