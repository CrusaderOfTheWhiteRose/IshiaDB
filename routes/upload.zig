const std = @import("std");
const reader = @import("../modules/reader.zig");
const constant = @import("../index.zig");
const engine = @import("../database/engine.zig");

pub fn upload(connection: *const std.net.Server.Connection, headerParse: *std.mem.SplitIterator(u8, .sequence), target: []const u8) !void {
    var headers = std.StringHashMap([]const u8).init(std.heap.page_allocator);
    reader.parse_header(&headers, headerParse) catch |err| {
        if (err == error.RequestHeaderFieldsTooLarge) {
            try connection.stream.writeAll("HTTP/1.1 431 Request Header Fields Too Large\r\nContent-Length: 0\r\n\r\n");
            return;
        } else return err;
    };
    var body: []u8 = "";
    reader.parse_body(connection, headerParse, &headers, &body) catch |err| {
        if (err == error.PayloadTooLarge) {
            try connection.stream.writeAll("HTTP/1.1 413 Payload Too Large\r\nContent-Length: 0\r\n\r\n");
            return;
        } else return err;
    };
    var parsedTarget = std.mem.split(u8, target, "/");
    _ = parsedTarget.next().?;
    const namespace = parsedTarget.next().?;
    const database = parsedTarget.next().?;
    const table = parsedTarget.next().?;
    engine.upload_files(namespace, database, table, try reader.parse_files_body(body, &headers)) catch |err| {
        if (err == error.NoNameSpaceFound) {
            try connection.stream.writeAll("HTTP/1.1 400 Bad Request\r\nContent-Length: 23\r\n\r\nNameSpace was not Found");
            return;
        } else if (err == error.NoDataBaseFound) {
            try connection.stream.writeAll("HTTP/1.1 400 Bad Request\r\nContent-Length: 22\r\n\r\nDataBase was not Found");
            return;
        } else if (err == error.NoTableFound) {
            try connection.stream.writeAll("HTTP/1.1 400 Bad Request\r\nContent-Length: 19\r\n\r\nTable was not Found");
            return;
        } else return err;
    };
    try connection.stream.writeAll("HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n");
}
