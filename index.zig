const std = @import("std");
const logger = @import("modules/logger.zig");
const argument = @import("modules/argument.zig");
const core = @import("database/core.zig");
const engine = @import("database/engine.zig");
const query = @import("routes/query.zig");
const upload = @import("routes/upload.zig");

pub const ishiaConfigStruct = struct { port: u16 };
pub const MAX_HEADER_SIZE: u32 = 1024 * 2;
pub const MAX_BODY_SIZE: u64 = 1024 * 1024 * 1024;

pub fn main() !void {
    var ishiaConfig = ishiaConfigStruct{ .port = 4200 };
    try argument.process(&ishiaConfig);

    try engine.init_engine();
    try engine.write_config_yaml(&ishiaConfig);

    var netServer = std.net.Address.listen(try std.net.Address.parseIp("127.0.0.1", ishiaConfig.port), .{ .reuse_address = true, .kernel_backlog = 2_147_483_647 }) catch |err| {
        try logger.format.e("Initialisation", "Main", "index", "Error, Server is Offline                     ", "{any}", "NO_TIME", .{err});
        return;
    };
    try logger.format.l("Initialisation", "Main", "index", "Server is Listening On Port                  ", "{d}", "NO_TIME", .{ishiaConfig.port});

    const cpuCount = try std.Thread.getCpuCount();

    var threads: [128]std.Thread = undefined;
    for (0..cpuCount) |number| {
        const thread = try std.heap.page_allocator.create(std.Thread);
        thread.* = try std.Thread.spawn(.{ .stack_size = 1024 * 1024 }, performWorkOnThread, .{&netServer});
        threads[number] = thread.*;
    }
    for (threads) |thread| {
        _ = thread.join();
    }
}

fn performWorkOnThread(server: anytype) !void {
    while (true) {
        try processRequest(&(try server.accept()));
    }
}

fn processRequest(connection: *const std.net.Server.Connection) !void {
    var buffer: [MAX_HEADER_SIZE]u8 = undefined;
    const bytes = connection.stream.read(buffer[0..]) catch return;
    const content = buffer[0..bytes];
    if (content.len == 0) return;
    var headerParse = std.mem.split(u8, content, "\r\n");
    var firstParse = std.mem.split(u8, headerParse.next().?, " ");

    const method = firstParse.next().?;
    const target = firstParse.next().?;

    if (method[0] == 71 and target[target.len - 5] != 114) {
        var parsedTarget = std.mem.split(u8, target, "/");
        _ = parsedTarget.next();
        var namespace: ?[]const u8 = null;
        var database: ?[]const u8 = null;
        var table: ?[]const u8 = null;
        var hash: ?[]const u8 = null;
        var extension: ?[]const u8 = null;
        while (parsedTarget.next()) |parse| {
            if (namespace) |_| {
                if (database) |_| {
                    if (table) |_| {
                        if (hash) |_| {
                            if (extension) |_| {} else extension = parse;
                        } else hash = parse;
                    } else table = parse;
                } else database = parse;
            } else namespace = parse;
        }
        if (namespace) |ns| {
            if (database) |db| {
                if (table) |tbl| {
                    if (hash) |h| {
                        if (extension) |_| {} else {
                            var hash_index = std.mem.split(u8, h, "-");
                            const parsed_hash = hash_index.next().?;

                            const units = core.get_units_by_hash(ns, db, tbl, parsed_hash) catch |err| {
                                if (err == error.NoNameSpaceFound) {
                                    try connection.stream.writeAll("HTTP/1.1 400 Bad Request\r\nContent-Length: 23\r\n\r\nNameSpace was not Found");
                                    return;
                                } else if (err == error.NoDataBaseFound) {
                                    try connection.stream.writeAll("HTTP/1.1 400 Bad Request\r\nContent-Length: 22\r\n\r\nDataBase was not Found");
                                    return;
                                } else if (err == error.NoTableFound) {
                                    try connection.stream.writeAll("HTTP/1.1 400 Bad Request\r\nContent-Length: 19\r\n\r\nTable was not Found");
                                    return;
                                } else if (err == error.NoUnitFound) {
                                    try connection.stream.writeAll("HTTP/1.1 400 Bad Request\r\nContent-Length: 18\r\n\r\nUnit was not Found");
                                    return;
                                } else return err;
                            };

                            var path: []const u8 = "";

                            if (hash_index.next()) |hi| {
                                if (hi.len > 1) {
                                    path = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ "./ishia/:NS.", ns, "/:DB.", db, "/:TL.", tbl, "/", parsed_hash, "/.", hi });

                                    const file = std.fs.cwd().openFile(path, .{}) catch {
                                        try connection.stream.writeAll("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n");
                                        return;
                                    };
                                    const stat = try file.stat();

                                    var sizeBuffer: [12]u8 = undefined;

                                    var content_type: []const u8 = "";

                                    switch (hi[0]) {
                                        // jpeg || jxl
                                        'j' => {
                                            if (hi[1] == 'x') {
                                                content_type = "image/jxl";
                                            } else content_type = "image/jpeg";
                                        },
                                        // png
                                        'p' => content_type = "image/png",
                                        // gif
                                        'g' => content_type = "image/gif",
                                        // webp || webm
                                        'w' => {
                                            if (hi[3] == 'p') {
                                                content_type = "image/webp";
                                            } else content_type = "video/webm";
                                        },
                                        // avif
                                        'a' => content_type = "image/avif",
                                        // mp4 || mp3
                                        'm' => {
                                            if (hi[2] == '3') {
                                                content_type = "video/mp4";
                                            } else content_type = "audio/mpeg";
                                        },
                                        // oog || opus
                                        'o' => {
                                            if (hi[1] == 'o') {
                                                content_type = "audio/oog";
                                            } else content_type = "text/plain";
                                        },
                                        else => content_type = "text/plain",
                                    }

                                    try connection.stream.writeAll(try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ "HTTP/1.1 200 OK\r\n", "Content-Length: ", try std.fmt.bufPrint(&sizeBuffer, "{d}", .{stat.size}), "\r\n", "Content-Type: ", content_type, "\r\n", "Accept-Ranges: bytes\r\n", "Cache-Control: immutable, max-age=31536000", "\r\n\r\n" }));

                                    var offset: i64 = 0;
                                    _ = std.os.linux.sendfile(connection.stream.handle, file.handle, &offset, stat.size);
                                    file.close();
                                } else {
                                    for (units.items) |ut| {
                                        switch (ut.*) {
                                            .extension => {},
                                            .index => {
                                                if (ut.*.index[4] == hi[0]) {
                                                    path = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ "./ishia/:NS.", ns, "/:DB.", db, "/:TL.", tbl, "/", parsed_hash, "/", &[1]u8{ut.*.index[4]}, ".", ut.*.index[0..4] });
                                                    break;
                                                }
                                            },
                                        }
                                    }
                                }
                            } else {
                                for (units.items) |ut| {
                                    switch (ut.*) {
                                        .extension => {},
                                        .index => {
                                            if (ut.*.index[4] == 'o') {
                                                path = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ "./ishia/:NS.", ns, "/:DB.", db, "/:TL.", tbl, "/", parsed_hash, "/", &[1]u8{ut.*.index[4]}, ".", ut.*.index[0..4] });
                                                break;
                                            }
                                        },
                                    }
                                }
                            }

                            if (path[path.len - 1] == 0) path = path[0..(path.len - 1)];

                            const file = std.fs.cwd().openFile(path, .{}) catch {
                                try connection.stream.writeAll("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n");
                                return;
                            };
                            const stat = try file.stat();

                            var sizeBuffer: [12]u8 = undefined;

                            var index_path: usize = path.len - 1;
                            while (true) {
                                if (path[index_path - 1] == '.') break;
                                index_path -= 1;
                            }

                            var content_type: []const u8 = "";

                            if (path.len <= index_path + 3) {
                                const path_extension: [3]u8 = [3]u8{ path[index_path], path[index_path + 1], path[index_path + 2] };

                                switch (path_extension[0]) {
                                    // jpeg || jxl
                                    'j' => content_type = "image/jxl",
                                    // png
                                    'p' => content_type = "image/png",
                                    // gif
                                    'g' => content_type = "image/gif",
                                    // mp4 || mp3
                                    'm' => {
                                        if (path_extension[2] == '3') {
                                            content_type = "video/mp4";
                                        } else content_type = "audio/mpeg";
                                    },
                                    // oog
                                    'o' => content_type = "audio/oog",
                                    else => content_type = "text/plain",
                                }
                            } else {
                                const path_extension: [4]u8 = [4]u8{ path[index_path], path[index_path + 1], path[index_path + 2], path[index_path + 3] };

                                switch (path_extension[0]) {
                                    // jpeg || jxl
                                    'j' => content_type = "image/jpeg",
                                    // webp || webm
                                    'w' => {
                                        if (path_extension[3] == 'p') {
                                            content_type = "image/webp";
                                        } else content_type = "video/webm";
                                    },
                                    // avif
                                    'a' => content_type = "image/avif",
                                    // oog || opus
                                    'o' => content_type = "audio/x-opus+ogg",
                                    else => content_type = "text/plain",
                                }
                            }
                            try connection.stream.writeAll(try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ "HTTP/1.1 200 OK\r\n", "Content-Length: ", try std.fmt.bufPrint(&sizeBuffer, "{d}", .{stat.size}), "\r\n", "Content-Type: ", content_type, "\r\n", "Accept-Ranges: bytes\r\n", "Cache-Control: immutable, max-age=31536000", "\r\n\r\n" }));

                            var offset: i64 = 0;
                            _ = std.os.linux.sendfile(connection.stream.handle, file.handle, &offset, stat.size);
                            file.close();
                        }
                    }
                } else try connection.stream.writeAll("HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\n\r\n");
            } else try connection.stream.writeAll("HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\n\r\n");
        } else try connection.stream.writeAll("HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\n\r\n");
    } else if (method[0] == 71) {
        var parsedTarget = std.mem.split(u8, target, "/");
        _ = parsedTarget.next();
        var namespace: ?[]const u8 = null;
        var database: ?[]const u8 = null;
        var table: ?[]const u8 = null;
        while (parsedTarget.next()) |parse| {
            if (namespace) |_| {
                if (database) |_| {
                    if (table) |_| {} else table = parse;
                } else database = parse;
            } else namespace = parse;
        }
        if (namespace) |ns| {
            if (database) |db| {
                if (table) |tbl| {
                    var rules: []const u8 = undefined;
                    rules = core.get_rules(ns, db, tbl) catch |err| blk: {
                        if (err == error.NoNameSpaceFound) {
                            try connection.stream.writeAll("HTTP/1.1 400 Bad Request\r\nContent-Length: 23\r\n\r\nNameSpace was not Found");
                            break :blk "";
                        } else if (err == error.NoDataBaseFound) {
                            try connection.stream.writeAll("HTTP/1.1 400 Bad Request\r\nContent-Length: 22\r\n\r\nDataBase was not Found");
                            break :blk "";
                        } else if (err == error.NoTableFound) {
                            try connection.stream.writeAll("HTTP/1.1 400 Bad Request\r\nContent-Length: 19\r\n\r\nTable was not Found");
                            break :blk "";
                        } else return err;
                    };
                    if (rules.len != 0) {
                        _ = try connection.stream.write("HTTP/1.1 200 OK\r\nContent-Length: ");
                        var sizeBuffer: [4]u8 = undefined;
                        _ = try connection.stream.write(try std.fmt.bufPrint(&sizeBuffer, "{d}", .{rules.len}));
                        _ = try connection.stream.write("\r\n\r\n");
                        try connection.stream.writeAll(rules);
                    }
                } else try connection.stream.writeAll("HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\n\r\n");
            } else try connection.stream.writeAll("HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\n\r\n");
        } else try connection.stream.writeAll("HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\n\r\n");
    } else if (method[1] == 79) {
        try upload.upload(connection, &headerParse, target);
    } else if (method[1] == 65) {
        try query.query(connection, &headerParse, target);
    } else try connection.stream.writeAll("HTTP/1.1 406 Not Acceptable\r\nContent-Length: 0\r\n\r\n");
}
