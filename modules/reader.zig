const std = @import("std");
const constant = @import("../index.zig");

pub fn parse_files_body(body: []const u8, headers: *std.StringHashMap([]const u8)) !*const std.ArrayList([]const u8) {
    var parse_file_by: []const u8 = undefined;
    if (headers.get("content-type")) |content_type| {
        var parseType = std.mem.split(u8, content_type, "; ");
        while (parseType.next()) |value_type| {
            var parseTypeBoundary = std.mem.split(u8, value_type, "boundary=");
            _ = parseTypeBoundary.next();
            if (parseTypeBoundary.next()) |value_type_boundry| {
                parse_file_by = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ "--", value_type_boundry });
            }
        }
    }
    return parse_files(body, parse_file_by);
}

pub fn parse_files(body: []const u8, boundary: []const u8) !*const std.ArrayList([]const u8) {
    var bodyParsed = std.mem.split(u8, body, boundary);
    const files = try std.heap.page_allocator.create(std.ArrayList([]const u8));
    files.* = std.ArrayList([]const u8).init(std.heap.page_allocator);
    while (bodyParsed.next()) |parsed| {
        if (parsed.len < 5) continue;

        var lineNumber: u3 = 0;
        var byteNumber: usize = 0;
        while (true) {
            if (parsed[byteNumber] == 13) lineNumber += 1;
            if (lineNumber == 4) break;
            byteNumber += 1;
        }

        var basicContentTypeParse = std.mem.split(u8, parsed[0..byteNumber], "Content-Type:");
        _ = basicContentTypeParse.next();
        var advanceContentTypeParse = std.mem.split(u8, basicContentTypeParse.next().?, "\n");
        var valueContentTypeParse = advanceContentTypeParse.next().?;
        if (valueContentTypeParse[0] == 32) valueContentTypeParse = valueContentTypeParse[1..(valueContentTypeParse.len - 1)];
        var typeExtension = std.mem.split(u8, valueContentTypeParse, "/");
        _ = typeExtension.next().?;

        try files.append(typeExtension.next().?);
        try files.append(parsed[(byteNumber + 2)..]);
    }
    return files;
}

pub fn parse_header(headers: *std.StringHashMap([]const u8), headerParse: *std.mem.SplitIterator(u8, .sequence)) !void {
    while (headerParse.next()) |value| {
        var parseLine = std.mem.split(u8, value, ":");
        if (parseLine.next()) |thingName| {
            if (thingName.len == 0) break;
            if (parseLine.next()) |thingValue| {
                if (thingValue[0] == 32) {
                    try headers.put(thingName, thingValue[1..]);
                } else try headers.put(thingName, thingValue);
            } else return error.RequestHeaderFieldsTooLarge;
        } else return error.RequestHeaderFieldsTooLarge;
    }
}

pub fn parse_body(connection: *const std.net.Server.Connection, headerParse: *std.mem.SplitIterator(u8, .sequence), headers: *std.StringHashMap([]const u8), body: *[]u8) !void {
    while (headerParse.next()) |value| body.* = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ body.*, "\r\n", value });
    if (headers.get("content-length")) |content_length| {
        const contentBytes = try std.fmt.parseInt(u64, content_length, 10);
        if (contentBytes > 0 and contentBytes > body.*.len) {
            while (true) {
                var streamBuffer: [10240]u8 = undefined;
                const readBytes = try connection.stream.read(streamBuffer[0..]);
                if ((readBytes < streamBuffer.len) and (body.*.len + streamBuffer.len > contentBytes)) {
                    body.* = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ body.*, streamBuffer[0..readBytes] });
                    if (constant.MAX_BODY_SIZE < body.*.len) return error.PayloadTooLarge;
                    break;
                }
                body.* = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ body.*, streamBuffer[0..readBytes] });
                if (constant.MAX_BODY_SIZE < body.*.len) return error.PayloadTooLarge;
            }
        }
    }
}
