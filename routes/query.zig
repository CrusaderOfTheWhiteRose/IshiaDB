const std = @import("std");
const constant = @import("../index.zig");
const engine = @import("../database/engine.zig");
const reader = @import("../modules/reader.zig");
const core = @import("../database/core.zig");
const argument = @import("../modules/argument.zig");

pub fn query(connection: *const std.net.Server.Connection, headerParse: *std.mem.SplitIterator(u8, .sequence), target: []const u8) !void {
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
    var statements = std.ArrayList([]const u8).init(std.heap.page_allocator);
    var commands = std.ArrayList(*commandStruct).init(std.heap.page_allocator);
    try parse_query(body, &statements);
    var parsedTarget = std.mem.split(u8, target, "/");
    _ = parsedTarget.next().?;
    const namespace = parsedTarget.next().?;
    const database = parsedTarget.next().?;
    try parse_statement(&statements, &commands);
    if (parsedTarget.next()) |table| {
        deploy_query(&commands, namespace, database, table) catch |err| {
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
    } else deploy_query(&commands, namespace, database, null) catch |err| {
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

fn parse_query(body: []const u8, array: *std.ArrayList([]const u8)) !void {
    var statements = std.mem.split(u8, body, "\n");
    while (statements.next()) |statement| {
        if (statement.len == 0) continue;
        if (statement[0] == 45 and statement[1] == 45) continue;
        var line_statements = std.mem.split(u8, statement, ";");
        while (line_statements.next()) |line_statement| {
            if (line_statement.len == 0 or line_statement.len == 1) continue;
            if (line_statement[line_statement.len - 1] == 10 or line_statement[line_statement.len - 1] == 13) {
                try array.append(line_statement[0..(line_statement.len - 2)]);
            } else try array.append(line_statement);
        }
    }
}

const commandStruct = struct { object: []const u8, command: COMMAND, value: []const u8 };

fn parse_statement(statements: *std.ArrayList([]const u8), commands: *std.ArrayList(*commandStruct)) !void {
    var object: ?[]const u8 = null;
    var command: ?COMMAND = null;
    var value: []const u8 = "";
    for (statements.items) |item| {
        var parsed = std.mem.split(u8, item, " ");
        while (parsed.next()) |parse| {
            if (parse.len == 1) {
                switch (parse[0]) {
                    // m
                    109 => command = .MARK,
                    // s
                    115 => command = .SIZE,
                    // f
                    102 => command = .FORMAT,
                    // o
                    111 => command = .OPTIMISE,
                    // e
                    101 => command = .EXTENSION,
                    // d
                    100 => command = .DEFINE,
                    // {
                    123 => continue,
                    // }
                    125 => continue,
                    else => value = parse,
                }
            } else {
                if (object == null) {
                    object = parse;
                } else value = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ value, parse });
            }
        }
        if (command) |cmd| {
            if (object) |obj| {
                const command_ptr = try std.heap.page_allocator.create(commandStruct);
                command_ptr.* = commandStruct{ .object = obj, .command = cmd, .value = value };
                try commands.append(command_ptr);
            }
            command = null;
        }
        object = null;
        value = "";
    }
}

fn deploy_query(commands: *std.ArrayList(*commandStruct), namespace: []const u8, database: []const u8, table: ?[]const u8) !void {
    for (commands.*.items) |cmd| {
        switch (cmd.command) {
            .DEFINE => {
                if (std.mem.eql(u8, cmd.value, "table")) {
                    try engine.define(namespace, database, null, cmd.object);
                } else if (std.mem.eql(u8, cmd.value, "database")) {
                    try engine.define(namespace, null, null, cmd.object);
                } else if (std.mem.eql(u8, cmd.value, "namespace")) {
                    try engine.define(null, null, null, cmd.object);
                }
            },
            .EXTENSION => {
                if (table) |tbl| try engine.set_possible_input_extensions(namespace, database, tbl, try parse_format(cmd.value));
            },
            .FORMAT => {
                if (table) |tbl| try engine.set_format(namespace, database, tbl, try parse_format(cmd.value));
            },
            .SIZE => {
                if (table) |tbl| try engine.set_input_size(namespace, database, tbl, argument.calculateSizeByArgument(cmd.value));
            },
            .OPTIMISE => {
                if (table) |tbl| try engine.set_optimisation(namespace, database, tbl, try std.fmt.parseInt(u5, cmd.value, 10));
            },
            .MARK => {
                if (table) |tbl| try engine.set_mark(namespace, database, tbl, cmd.value);
            },
        }
    }
}

fn parse_format(input: []const u8) ![4][4]u8 {
    var format: [4][4]u8 = [4][4]u8{ [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 } };
    var parsedValue = std.mem.split(u8, input, ",");
    var index: u3 = 0;
    while (parsedValue.next()) |value| {
        if (index > 3) break;
        if (value.len < 2) {
            format[index] = [4]u8{ value[0], 0, 0, 0 };
        } else if (value.len < 3) {
            format[index] = [4]u8{ value[0], value[1], 0, 0 };
        } else if (value.len < 4) {
            format[index] = [4]u8{ value[0], value[1], value[2], 0 };
        } else if (value.len < 5) {
            format[index] = value[0..4].*;
        }
        if (format[index][3] == 44) {
            format[index][3] = 0;
        }
        index += 1;
    }
    return format;
}

const COMMAND = enum { FORMAT, SIZE, EXTENSION, OPTIMISE, MARK, DEFINE };
