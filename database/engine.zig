const std = @import("std");
const core = @import("./core.zig");
const filesystem = @import("./filesystem.zig");
const constant = @import("../index.zig");
const logger = @import("../modules/logger.zig");
const argument = @import("../modules/argument.zig");

pub fn init_engine() !void {
    var dir = std.fs.cwd().openDir("./ishia", .{ .iterate = true }) catch {
        try logger.format.l("Initialisation", "Reader", "engine", "Creating Ishia Directory                  ", "", "NO_TIME", .{});
        try filesystem.create_directory("./ishia");
        // try filesystem.create_directory("./ishia/archive");
        // try filesystem.create_file("./ishia/cache");
        // try filesystem.create_file("./ishia/state.ihd");
        try filesystem.create_file("./ishia/config.yaml");
        try core.init_table_map();
        return;
    };
    defer dir.close();
    try core.init_table_map();
    try logger.format.l("Initialisation", "Reader", "engine", "Ishia Directory was Detected - Scanning   ", "./ishia", "NO_TIME", .{});
    var walker = try dir.walk(std.heap.page_allocator);
    var timer = try std.time.Timer.start();
    var namespace: ?[]const u8 = null;
    var database: ?[]const u8 = null;
    var table: ?[]const u8 = null;
    var level: u3 = 0;
    while (try walker.next()) |entry| {
        level = 0;
        var pathParts = std.mem.split(u8, entry.path, "/");
        while (pathParts.next()) |_| level += 1;
        if (entry.basename[0] == 58) {
            if (entry.basename[1] == 78 and level == 1) {
                var tagAndName = std.mem.split(u8, entry.path, ":NS.");
                _ = tagAndName.next();
                const name = tagAndName.next().?;
                try core.define(null, null, null, name);
                namespace = name;
                try logger.format.v("Initialisation", "Reader", "engine", "NameSpace was reDefined                   ", "{s}", "{any}", .{ name, (timer.lap() / 100000) });
            } else if (entry.basename[1] == 68 and level == 2) {
                var tagAndName = std.mem.split(u8, entry.path, ":DB.");
                _ = tagAndName.next();
                const name = tagAndName.next().?;
                try core.define(namespace, null, null, name);
                database = name;
                try logger.format.v("Initialisation", "Reader", "engine", "DataBase was reDefined                    ", "{s}", "{any}", .{ name, (timer.lap() / 100000) });
            } else if (entry.basename[1] == 84 and level == 3) {
                var tagAndName = std.mem.split(u8, entry.path, ":TL.");
                _ = tagAndName.next();
                const name = tagAndName.next().?;
                try core.define(namespace, database, null, name);
                table = name;
                try logger.format.v("Initialisation", "Reader", "engine", "Table was reDefined                       ", "{s}", "{any}", .{ name, (timer.lap() / 100000) });
            }
        } else if (namespace) |ns| {
            if (database) |db| {
                if (table) |tbl| {
                    if (level == 4 and std.mem.eql(u8, entry.path[(entry.path.len - 9)..], "rules.ihd")) {
                        var format: ?[4][4]u8 = null;
                        var size: ?u64 = null;
                        var optimise: ?u5 = null;
                        var extension: ?[4][4]u8 = null;
                        var mark: [3][3]u8 = [3][3]u8{ [3]u8{ 0, 0, 0 }, [3]u8{ 0, 0, 0 }, [3]u8{ 0, 0, 0 } };
                        var markIndex: u3 = 0;
                        const rules = try std.fs.cwd().openFile(try std.mem.join(std.heap.page_allocator, "/", &[_][]const u8{ "./ishia", entry.path }), .{ .mode = .read_write });
                        defer rules.close();
                        var buffer: [1024]u8 = undefined;
                        const content = buffer[0..(try rules.readAll(&buffer))];
                        var contentParse = std.mem.split(u8, content, "\n");
                        var rule: ?RULES = null;
                        while (contentParse.next()) |cnt| {
                            var contentLine = cnt;
                            if (contentLine.len == 0) continue;
                            if (contentLine[0] == 62 or contentLine[0] == 60) continue;
                            while (contentLine[0] == 32) contentLine = contentLine[1..];
                            while (contentLine[contentLine.len - 1] == 32 or contentLine[contentLine.len - 1] == 13) contentLine = contentLine[0..(contentLine.len - 2)];
                            if (contentLine[contentLine.len - 1] == 91) {
                                if (contentLine[0] == 69) {
                                    extension = [4][4]u8{ [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 } };
                                    rule = .EXTENSION;
                                } else if (contentLine[0] == 70) {
                                    format = [4][4]u8{ [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 } };
                                    rule = .FORMAT;
                                } else if (contentLine[0] == 77) {
                                    rule = .MARK;
                                }
                                continue;
                            } else if (contentLine[0] == 83) {
                                size = argument.calculateSizeByArgument(contentLine[6..(contentLine.len - 1)]);
                            } else if (contentLine[0] == 79) {
                                optimise = std.fmt.parseInt(u5, contentLine[10..(contentLine.len - 1)], 10) catch null;
                            }
                            if (contentLine[0] == 93) rule = null;
                            if (rule) |rl| {
                                if (rl == .EXTENSION) {
                                    var extensionIndex: u3 = 0;
                                    while (extension.?[extensionIndex][0] != 0) {
                                        extensionIndex += 1;
                                        if (extensionIndex > 3) break;
                                    }
                                    if (contentLine[4..(contentLine.len - 1)].len == 4) {
                                        var contentLineIndex: u3 = 0;
                                        for (contentLine[4..(contentLine.len - 1)]) |clc| {
                                            extension.?[extensionIndex][contentLineIndex] = clc;
                                            contentLineIndex += 1;
                                        }
                                    }
                                } else if (rl == .FORMAT) {
                                    var formatIndex: u3 = 0;
                                    while (format.?[formatIndex][0] != 0) {
                                        formatIndex += 1;
                                        if (formatIndex > 3) break;
                                    }
                                    if (contentLine[4..(contentLine.len - 1)].len == 4) {
                                        var contentLineIndex: u3 = 0;
                                        for (contentLine[4..(contentLine.len - 1)]) |clc| {
                                            format.?[formatIndex][contentLineIndex] = clc;
                                            contentLineIndex += 1;
                                        }
                                    }
                                } else if (rl == .MARK) {
                                    var index_valueParse = std.mem.split(u8, contentLine[1..(contentLine.len - 1)], " -- ");
                                    var markNumber: u3 = 0;
                                    while (index_valueParse.next()) |ivp| {
                                        mark[markIndex][markNumber] = std.fmt.parseInt(u8, ivp, 10) catch ivp[0..1].*[0];
                                        markNumber += 1;
                                    }
                                    markIndex += 1;
                                }
                            }
                        }
                        if (format) |fmt| try core.set_format(ns, db, tbl, fmt);
                        if (extension) |ext| try core.set_possible_input_extensions(ns, db, tbl, ext);
                        if (size) |sz| try core.set_input_size(ns, db, tbl, sz);
                        if (optimise) |opt| try core.set_optimisation(ns, db, tbl, opt);
                        if (mark[0][0] != 0) {
                            var markFormat: []const u8 = "";
                            var qualityBuffer: [2]u8 = undefined;
                            var scaleBuffer: [1]u8 = undefined;
                            for (mark) |m| {
                                if (m[0] == 0) continue;
                                markFormat = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ markFormat, &[_]u8{m[0]}, ":", try std.fmt.bufPrint(&qualityBuffer, "{d}", .{m[1]}), ":", try std.fmt.bufPrint(&scaleBuffer, "{d}", .{m[2]}), "," });
                            }
                            try core.set_mark(ns, db, tbl, markFormat[0..(markFormat.len - 1)]);
                        }
                        try logger.format.v("Initialisation", "Reader", "engine", "Rules was Applied                         ", "{s}", "{any}", .{ tbl, (timer.lap() / 100000) });
                    } else if (level == 4) {
                        var buffer: [15]u8 = undefined;
                        var index: u4 = 0;
                        while (true) {
                            if (entry.path[entry.path.len - 1 - index] == '/') break;
                            buffer[buffer.len - 1 - index] = entry.path[entry.path.len - 1 - index];
                            index += 1;
                        }
                        var indexBuffer: u4 = 0;
                        index = 0;
                        var newBuffer: [10]u8 = undefined;
                        while (true) {
                            if (buffer[index] == 170) {
                                index += 1;
                                continue;
                            } else {
                                newBuffer[indexBuffer] = buffer[index];
                                index += 1;
                                indexBuffer += 1;
                                if (index == 15) break;
                            }
                        }
                        try core.push_hash(ns, db, tbl, &newBuffer);
                    } else if (level == 5) {
                        var entryParts = std.mem.split(u8, entry.path, "/");
                        var hash: []const u8 = "";
                        while (entryParts.next()) |ep| {
                            level -= 1;
                            if (level == 1) {
                                hash = ep;
                            } else if (level == 0) {
                                if (ep[0] == '.') {
                                    try core.push_unit(ns, db, tbl, hash, ep[1..], null);
                                } else try core.push_unit(ns, db, tbl, hash, ep[2..], ep[0]);
                                break;
                            }
                        }
                    }
                }
            }
        }
    }
}

const RULES = enum { EXTENSION, FORMAT, MARK };

pub fn write_config_yaml(ishiaConfig: *constant.ishiaConfigStruct) !void {
    const config = try std.fs.cwd().openFile("./ishia/config.yaml", .{ .mode = .write_only });
    _ = try config.write("server:\n");
    _ = try config.write("  port: ");
    var sizeBuffer: [5]u8 = undefined;
    _ = try config.write(try std.fmt.bufPrint(&sizeBuffer, "{d}", .{ishiaConfig.port}));
    _ = try config.write("\n");
}

pub fn define(namespace: ?[]const u8, database: ?[]const u8, table: ?[]const u8, name: []const u8) !void {
    if (namespace) |ns| {
        if (database) |db| {
            if (table) |_| {} else {
                try filesystem.create_directory(try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ "./ishia", "/:NS.", ns, "/:DB.", db, "/:TL.", name }));
                try filesystem.create_file(try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ "./ishia", "/:NS.", ns, "/:DB.", db, "/:TL.", name, "/rules.ihd" }));
            }
        } else try filesystem.create_directory(try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ "./ishia", "/:NS.", ns, "/:DB.", name }));
    } else try filesystem.create_directory(try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ "./ishia", "/:NS.", name }));
    try core.define(namespace, database, table, name);
}

pub fn upload_files(namespace: []const u8, database: []const u8, table: []const u8, files: *const std.ArrayList([]const u8)) !void {
    const rules = try core.get_rules_sturct(namespace, database, table);
    var index: u8 = 0;
    var filesToUpload = std.ArrayList([]const u8).init(std.heap.page_allocator);
    const size = rules.accept_size;
    if (rules.accept_extension) |ae| {
        if (rules.accept_format) |af| {
            const accept_full: [8][4]u8 = [8][4]u8{ ae[0], ae[1], ae[2], ae[3], af[0], af[1], af[2], af[3] };
            while (true) {
                for (accept_full) |aeit| {
                    if (aeit[0] == 0) continue;
                    if (aeit.len == 4) {
                        if (std.mem.eql(u8, aeit[0..3], files.items[index][0..3])) {
                            const extension = files.items[index][0..3];
                            if (size) |sz| {
                                if (files.items[index + 1].len > sz) {
                                    index += 1;
                                } else {
                                    try filesToUpload.append(extension);
                                    index += 1;
                                    try filesToUpload.append(files.items[index]);
                                }
                            } else {
                                try filesToUpload.append(extension);
                                index += 1;
                                try filesToUpload.append(files.items[index]);
                            }
                        }
                    } else if (std.mem.eql(u8, aeit[0..4], files.items[index])) {
                        const extension = files.items[index][0..3];
                        if (size) |sz| {
                            if (files.items[index + 1].len > sz) {
                                index += 1;
                            } else {
                                try filesToUpload.append(extension);
                                index += 1;
                                try filesToUpload.append(files.items[index]);
                            }
                        } else {
                            try filesToUpload.append(extension);
                            index += 1;
                            try filesToUpload.append(files.items[index]);
                        }
                    }
                }
                index += 1;
                if (files.items.len == index) break;
            }
        } else {
            while (true) {
                for (ae) |aeit| {
                    if (aeit[0] == 0) continue;
                    if (aeit.len == 4) {
                        if (std.mem.eql(u8, aeit[0..3], files.items[index][0..3])) {
                            const extension = files.items[index][0..3];
                            if (size) |sz| {
                                if (files.items[index + 1].len > sz) {
                                    index += 1;
                                } else {
                                    try filesToUpload.append(extension);
                                    index += 1;
                                    try filesToUpload.append(files.items[index]);
                                }
                            } else {
                                try filesToUpload.append(extension);
                                index += 1;
                                try filesToUpload.append(files.items[index]);
                            }
                        }
                    } else if (std.mem.eql(u8, aeit[0..4], files.items[index])) {
                        const extension = files.items[index][0..3];
                        if (size) |sz| {
                            if (files.items[index + 1].len > sz) {
                                index += 1;
                            } else {
                                try filesToUpload.append(extension);
                                index += 1;
                                try filesToUpload.append(files.items[index]);
                            }
                        } else {
                            try filesToUpload.append(extension);
                            index += 1;
                            try filesToUpload.append(files.items[index]);
                        }
                    }
                }
                index += 1;
                if (files.items.len == index) break;
            }
        }
        try upload_units(namespace, database, table, &filesToUpload, rules.accept_format, rules.accept_optimise, rules.mark);
    } else try upload_units(namespace, database, table, files, rules.accept_format, rules.accept_optimise, rules.mark);
}

pub fn upload_units(namespace: []const u8, database: []const u8, table: []const u8, files: *const std.ArrayList([]const u8), format: ?[4][4]u8, optimise: ?u5, mark: ?[3][3]u8) !void {
    const path = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ "./ishia", "/:NS.", namespace, "/:DB.", database, "/:TL.", table });
    var rnd = std.rand.DefaultPrng.init(blk: {
        var seed: u32 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    var extension: [4]u8 = undefined;
    for (files.items) |item| {
        switch (item[0]) {
            // jpeg || jxl
            'j' => {
                if (item[1] == 'x') {
                    extension = "jxl ".*;
                } else extension = "jpeg".*;
            },
            // png
            'p' => extension = "png ".*,
            // gif
            'g' => extension = "gif ".*,
            // webp || webm
            'w' => {
                if (item[3] == 'p') {
                    extension = "webp".*;
                } else extension = "webm".*;
            },
            // avif
            'a' => extension = "avif".*,
            // mp4 || mp3
            'm' => {
                if (item[2] == '3') {
                    extension = "mp4 ".*;
                } else extension = "mp3 ".*;
            },
            // oog || opus
            'o' => {
                if (item[1] == 'o') {
                    extension = "oog ".*;
                } else extension = "opus".*;
            },
            else => {
                while (true) {
                    var buffer: [10]u8 = undefined;
                    const hash = try std.fmt.bufPrint(&buffer, "{d}", .{rnd.random().intRangeAtMost(u32, 1_000_000_000, 4_294_967_295)});
                    const dirPath = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ path, "/", hash });
                    const directory = std.fs.cwd().makeDir(dirPath);
                    if (directory) |_| {
                        var dir = try std.fs.cwd().openDir(dirPath, .{});
                        defer dir.close();
                        if (extension[3] == 32) {
                            if (optimise) |o| {
                                const file = try dir.createFile(try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ "or.", extension[0..3] }), .{});
                                defer file.close();
                                try file.writer().writeAll(item);
                                try optimise_unit(try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ dirPath, "/", "or.", extension[0..3] }), o);
                            } else {
                                const file = try dir.createFile(try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ "o.", extension[0..3] }), .{});
                                defer file.close();
                                try file.writer().writeAll(item);
                            }
                        } else {
                            if (optimise) |o| {
                                const file = try dir.createFile(try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ "or.", extension[0..4] }), .{});
                                defer file.close();
                                try file.writer().writeAll(item);
                                try optimise_unit(try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ dirPath, "/", "or.", extension[0..4] }), o);
                            } else {
                                const file = try dir.createFile(try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ "o.", extension[0..4] }), .{});
                                defer file.close();
                                try file.writer().writeAll(item);
                            }
                        }
                        try core.push_hash(namespace, database, table, hash);
                        if (format) |f| try format_unit(namespace, database, table, hash, dirPath, f, extension);
                        if (mark) |m| try mark_unit(namespace, database, table, hash, dirPath, m, extension);
                        try core.push_unit(namespace, database, table, hash, &extension, 'o');
                        break;
                    } else |err| {
                        if (err == error.PathAlreadyExists) {
                            //
                        } else {
                            return err;
                        }
                    }
                }
            },
        }
    }
}

pub fn optimise_unit(path: []const u8, index: u5) !void {
    var path_optimised: ?[]const u8 = null;
    var number: usize = 0;
    while (true) {
        if (path[number] == '/' and path[number + 1] == 'o' and path[number + 2] == 'r' and path[number + 3] == '.') {
            path_optimised = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ path[0..(number + 2)], path[(number + 3)..] });
            break;
        }
        number += 1;
    }
    if (path_optimised) |np| {
        var buffer: [2]u8 = undefined;
        var child = std.process.Child.init(&[_][]const u8{ "ffmpeg", "-i", path, "-q:v", try std.fmt.bufPrint(&buffer, "{d}", .{index}), np }, std.heap.page_allocator);
        child.stdout_behavior = .Ignore;
        child.stderr_behavior = .Ignore;
        try child.spawn();
        _ = try child.wait();
        try std.fs.cwd().deleteFile(path);
    }
}

pub fn format_unit(namespace: []const u8, database: []const u8, table: []const u8, hash: []const u8, path: []const u8, format: [4][4]u8, extension: [4]u8) !void {
    var e: []const u8 = undefined;
    if (extension[3] == ' ') {
        e = extension[0..3];
    } else e = &extension;
    for (format) |f| {
        switch (f[0]) {
            'w' => {
                var child = std.process.Child.init(&[_][]const u8{ "ffmpeg", "-i", try std.mem.join(std.heap.page_allocator, "/o.", &[_][]const u8{ path, e }), "-c:v", "libwebp", try std.mem.join(std.heap.page_allocator, "/.", &[_][]const u8{ path, &f }) }, std.heap.page_allocator);
                child.stdout_behavior = .Ignore;
                child.stderr_behavior = .Ignore;
                try child.spawn();
                try core.push_unit(namespace, database, table, hash, &f, null);
            },
            'a' => {
                var child = std.process.Child.init(&[_][]const u8{ "ffmpeg", "-i", try std.mem.join(std.heap.page_allocator, "/o.", &[_][]const u8{ path, e }), "-c:v", "libsvtav1", try std.mem.join(std.heap.page_allocator, "/.", &[_][]const u8{ path, "avif" }) }, std.heap.page_allocator);
                child.stdout_behavior = .Ignore;
                child.stderr_behavior = .Ignore;
                try child.spawn();
                try core.push_unit(namespace, database, table, hash, &f, null);
            },
            'j' => {
                var child = std.process.Child.init(&[_][]const u8{ "ffmpeg", "-i", try std.mem.join(std.heap.page_allocator, "/o.", &[_][]const u8{ path, e }), "-c:v", "libjxl", try std.mem.join(std.heap.page_allocator, "/.", &[_][]const u8{ path, "jxl" }) }, std.heap.page_allocator);
                child.stdout_behavior = .Ignore;
                child.stderr_behavior = .Ignore;
                try child.spawn();
                try core.push_unit(namespace, database, table, hash, &f, null);
            },
            'o' => {
                var child = std.process.Child.init(&[_][]const u8{ "ffmpeg", "-i", try std.mem.join(std.heap.page_allocator, "/o.", &[_][]const u8{ path, e }), "-c:v", "libopus", try std.mem.join(std.heap.page_allocator, "/.", &[_][]const u8{ path, "opus" }) }, std.heap.page_allocator);
                child.stdout_behavior = .Ignore;
                child.stderr_behavior = .Ignore;
                try child.spawn();
                try core.push_unit(namespace, database, table, hash, &f, null);
            },
            else => {},
        }
    }
}

pub fn mark_unit(namespace: []const u8, database: []const u8, table: []const u8, hash: []const u8, path: []const u8, mark: [3][3]u8, extension: [4]u8) !void {
    var e: []const u8 = undefined;
    if (extension[3] == ' ') {
        e = extension[0..3];
    } else e = &extension;
    for (mark) |array| {
        if (array[0] == 0) continue;
        var bufferWidthHeight: [2]u8 = undefined;
        var bufferQuality: [2]u8 = undefined;
        const format = try std.fmt.bufPrint(&bufferWidthHeight, "{d}", .{array[2]});
        var child = std.process.Child.init(&[_][]const u8{ "ffmpeg", "-i", try std.mem.join(std.heap.page_allocator, "/o.", &[_][]const u8{ path, e }), "-vf", try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ "scale=iw/", format, ":ih/", format }), "-q:v", try std.fmt.bufPrint(&bufferQuality, "{d}", .{array[1]}), try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ path, "/", &[1]u8{array[0]}, ".", e }) }, std.heap.page_allocator);
        child.stdout_behavior = .Ignore;
        child.stderr_behavior = .Ignore;
        try child.spawn();
        try core.push_unit(namespace, database, table, hash, &extension, array[0]);
    }
}

pub fn set_format(namespace: []const u8, database: []const u8, table: []const u8, format: [4][4]u8) !void {
    const path = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ "./ishia", "/:NS.", namespace, "/:DB.", database, "/:TL.", table, "/rules.ihd" });
    const rules = try std.fs.cwd().openFile(path, .{ .mode = .read_write });
    defer rules.close();
    try core.set_format(namespace, database, table, format);
    try rules.writeAll(try core.get_rules(namespace, database, table));
}

pub fn set_possible_input_extensions(namespace: []const u8, database: []const u8, table: []const u8, format: [4][4]u8) !void {
    const path = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ "./ishia", "/:NS.", namespace, "/:DB.", database, "/:TL.", table, "/rules.ihd" });
    const rules = try std.fs.cwd().openFile(path, .{ .mode = .read_write });
    defer rules.close();
    try core.set_possible_input_extensions(namespace, database, table, format);
    try rules.writeAll(try core.get_rules(namespace, database, table));
}

pub fn set_input_size(namespace: []const u8, database: []const u8, table: []const u8, size: u64) !void {
    const path = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ "./ishia", "/:NS.", namespace, "/:DB.", database, "/:TL.", table, "/rules.ihd" });
    const rules = try std.fs.cwd().openFile(path, .{ .mode = .read_write });
    defer rules.close();
    try core.set_input_size(namespace, database, table, size);
    try rules.writeAll(try core.get_rules(namespace, database, table));
}

pub fn set_optimisation(namespace: []const u8, database: []const u8, table: []const u8, level: u5) !void {
    const path = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ "./ishia", "/:NS.", namespace, "/:DB.", database, "/:TL.", table, "/rules.ihd" });
    const rules = try std.fs.cwd().openFile(path, .{ .mode = .read_write });
    defer rules.close();
    try core.set_optimisation(namespace, database, table, level);
    try rules.writeAll(try core.get_rules(namespace, database, table));
}

pub fn set_mark(namespace: []const u8, database: []const u8, table: []const u8, mark: []const u8) !void {
    const path = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ "./ishia", "/:NS.", namespace, "/:DB.", database, "/:TL.", table, "/rules.ihd" });
    const rules = try std.fs.cwd().openFile(path, .{ .mode = .read_write });
    defer rules.close();
    try core.set_mark(namespace, database, table, mark);
    try rules.writeAll(try core.get_rules(namespace, database, table));
}
