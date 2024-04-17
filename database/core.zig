const std = @import("std");

const tableStruct = struct { name: []const u8, units: *std.StringHashMap(*std.ArrayList(*unitUnion)), rules: *rulesStruct };

const rulesStruct = struct {
    accept_extension: ?[4][4]u8,
    accept_size: ?u64,
    accept_format: ?[4][4]u8,
    accept_optimise: ?u5,
    mark: ?[3][3]u8,
};

const UNIT = enum { extension, index };
const unitUnion = union(UNIT) { extension: [4]u8, index: [5]u8 };

var root: *std.StringHashMap(*std.StringHashMap(*std.StringHashMap(*tableStruct))) = undefined;

pub fn getRandomNumber() ![]const u8 {
    var rnd = std.rand.DefaultPrng.init(blk: {
        var seed: u32 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    var buffer: [10]u8 = undefined;
    return try std.fmt.bufPrint(&buffer, "{d}", .{rnd.random().intRangeAtMost(u32, 0, 4_294_967_295)});
}

pub fn init_table_map() !void {
    const rootHashMap = try std.heap.page_allocator.create(std.StringHashMap(*std.StringHashMap(*std.StringHashMap(*tableStruct))));
    rootHashMap.* = std.StringHashMap(*std.StringHashMap(*std.StringHashMap(*tableStruct))).init(std.heap.page_allocator);
    root = rootHashMap;
}

pub fn push_hash(namespace: []const u8, database: []const u8, table: []const u8, hash: []const u8) !void {
    const unit_array_prt = try std.heap.page_allocator.create(std.ArrayList(*unitUnion));
    unit_array_prt.* = std.ArrayList(*unitUnion).init(std.heap.page_allocator);
    var filledHash: []u8 = try std.heap.page_allocator.alloc(u8, 10);
    var number: u4 = 0;
    while (number < 10) {
        if (number > hash.len - 1) {
            filledHash[number] = 0;
        } else {
            if (hash[number] != 170) {
                filledHash[number] = hash[number];
            } else filledHash[number] = 0;
        }
        number += 1;
    }
    try (((root.get(namespace).?).get(database).?).get(table).?).units.put(filledHash, unit_array_prt);
}

pub fn push_unit(namespace: []const u8, database: []const u8, table: []const u8, hash: []const u8, extension: []const u8, index: ?u8) !void {
    if (root.get(namespace)) |ns| {
        if (ns.get(database)) |db| {
            if (db.get(table)) |tbl| {
                var filledHash: []u8 = try std.heap.page_allocator.alloc(u8, 10);
                var number: u4 = 0;
                while (number < 10) {
                    if (number > hash.len - 1) {
                        filledHash[number] = 0;
                    } else {
                        if (hash[number] != 170) {
                            filledHash[number] = hash[number];
                        } else filledHash[number] = 0;
                    }
                    number += 1;
                }
                // var keys = tbl.units.keyIterator();
                // while (keys.next()) |key| {
                //     std.debug.print("{s}\n", .{key.*});
                // }
                if (tbl.units.get(filledHash)) |hs| {
                    const unit = try std.heap.page_allocator.create(unitUnion);
                    if (index) |i| {
                        if (extension.len == 4) {
                            unit.* = unitUnion{ .index = [5]u8{ extension[0], extension[1], extension[2], extension[3], i } };
                        } else {
                            number = 0;
                            var filledExtension: [4]u8 = [4]u8{ 0, 0, 0, 0 };
                            while (true) {
                                filledExtension[number] = extension[number];
                                number += 1;
                                if (number == 3) break;
                            }
                            unit.* = unitUnion{ .index = [5]u8{ filledExtension[0], filledExtension[1], filledExtension[2], filledExtension[3], i } };
                        }
                    } else {
                        if (extension.len == 4) {
                            unit.* = unitUnion{ .extension = extension[0..4].* };
                        } else {
                            number = 0;
                            var filledExtension: [4]u8 = [4]u8{ 0, 0, 0, 0 };
                            while (true) {
                                filledExtension[number] = extension[number];
                                number += 1;
                                if (number == 3) break;
                            }
                            unit.* = unitUnion{ .extension = filledExtension };
                        }
                    }
                    try hs.append(unit);
                } else return error.NoUnitFound;
            } else return error.NoTableFound;
        } else return error.NoDataBaseFound;
    } else return error.NoNameSpaceFound;
}

pub fn get_units_by_hash(namespace: []const u8, database: []const u8, table: []const u8, hash: []const u8) !*std.ArrayList(*unitUnion) {
    if (root.get(namespace)) |ns| {
        if (ns.get(database)) |db| {
            if (db.get(table)) |tbl| {
                var filledHash: []u8 = try std.heap.page_allocator.alloc(u8, 10);
                var number: u4 = 0;
                while (number < 10) {
                    if (number > hash.len - 1) {
                        filledHash[number] = 0;
                    } else {
                        if (hash[number] != 170) {
                            filledHash[number] = hash[number];
                        } else filledHash[number] = 0;
                    }
                    number += 1;
                }
                if (tbl.units.get(filledHash)) |hs| {
                    return hs;
                } else return error.NoUnitFound;
            } else return error.NoTableFound;
        } else return error.NoDataBaseFound;
    } else return error.NoNameSpaceFound;
}

pub fn define(namespace: ?[]const u8, database: ?[]const u8, table: ?[]const u8, name: []const u8) !void {
    if (namespace) |ns| {
        if (database) |db| {
            if (table) |_| {} else {
                if (root.get(ns)) |rns| {
                    if (rns.get(db)) |rdb| {
                        const units_prt = try std.heap.page_allocator.create(std.StringHashMap(*std.ArrayList(*unitUnion)));
                        const rules_prt = try std.heap.page_allocator.create(rulesStruct);
                        const table_prt = try std.heap.page_allocator.create(tableStruct);
                        units_prt.* = std.StringHashMap(*std.ArrayList(*unitUnion)).init(std.heap.page_allocator);
                        rules_prt.* = rulesStruct{ .accept_extension = null, .accept_size = null, .accept_format = null, .accept_optimise = null, .mark = null };
                        table_prt.* = tableStruct{ .name = name, .units = units_prt, .rules = rules_prt };
                        var buffer = try std.heap.page_allocator.alloc(u8, 24);
                        std.mem.copyForwards(u8, buffer[0..], name[0..]);
                        try rdb.put(buffer[0..name.len], table_prt);
                    }
                }
            }
        } else {
            if (root.get(ns)) |rns| {
                const databaseHashMap = try std.heap.page_allocator.create(std.StringHashMap(*tableStruct));
                databaseHashMap.* = std.StringHashMap(*tableStruct).init(std.heap.page_allocator);
                var buffer = try std.heap.page_allocator.alloc(u8, 24);
                std.mem.copyForwards(u8, buffer[0..], name[0..]);
                try rns.put(buffer[0..name.len], databaseHashMap);
            }
        }
    } else {
        const namespaceHashMap = try std.heap.page_allocator.create(std.StringHashMap(*std.StringHashMap(*tableStruct)));
        namespaceHashMap.* = std.StringHashMap(*std.StringHashMap(*tableStruct)).init(std.heap.page_allocator);
        var buffer = try std.heap.page_allocator.alloc(u8, 24);
        std.mem.copyForwards(u8, buffer[0..], name[0..]);
        try root.put(buffer[0..name.len], namespaceHashMap);
    }
}

pub fn set_format(namespace: []const u8, database: []const u8, table: []const u8, format: [4][4]u8) !void {
    if (root.get(namespace)) |ns| {
        if (ns.get(database)) |db| {
            if (db.get(table)) |t| {
                t.rules.accept_format = format;
            }
        }
    }
}

pub fn set_possible_input_extensions(namespace: []const u8, database: []const u8, table: []const u8, format: [4][4]u8) !void {
    if (root.get(namespace)) |ns| {
        if (ns.get(database)) |db| {
            if (db.get(table)) |t| {
                t.rules.accept_extension = format;
            }
        }
    }
}

pub fn set_input_size(namespace: []const u8, database: []const u8, table: []const u8, size: u64) !void {
    if (root.get(namespace)) |ns| {
        if (ns.get(database)) |db| {
            if (db.get(table)) |t| {
                t.rules.accept_size = size;
            }
        }
    }
}

pub fn set_optimisation(namespace: []const u8, database: []const u8, table: []const u8, level: u5) !void {
    if (root.get(namespace)) |ns| {
        if (ns.get(database)) |db| {
            if (db.get(table)) |t| {
                t.rules.accept_optimise = level;
            }
        }
    }
}

pub fn set_mark(namespace: []const u8, database: []const u8, table: []const u8, mark: []const u8) !void {
    if (root.get(namespace)) |ns| {
        if (ns.get(database)) |db| {
            if (db.get(table)) |t| {
                var markArray: [3][3]u8 = [3][3]u8{ [3]u8{ 0, 0, 0 }, [3]u8{ 0, 0, 0 }, [3]u8{ 0, 0, 0 } };
                var parseMarkConfigs = std.mem.split(u8, mark, ",");
                var number: u2 = 0;
                while (parseMarkConfigs.next()) |config| {
                    var parseMarkConfigsToken = std.mem.split(u8, config, ":");
                    var index: u2 = 0;
                    while (parseMarkConfigsToken.next()) |pmcp| {
                        const level: ?u8 = std.fmt.parseInt(u8, pmcp, 10) catch null;
                        if (level) |lvl| {
                            markArray[number][index] = lvl;
                        } else {
                            if (pmcp.len == 0) break;
                            markArray[number][0] = pmcp[0];
                        }
                        index += 1;
                    }
                    number += 1;
                }
                t.rules.mark = markArray;
            }
        }
    }
}

pub fn get_rules_sturct(namespace: []const u8, database: []const u8, table: []const u8) !*rulesStruct {
    if (root.get(namespace)) |ns| {
        if (ns.get(database)) |db| {
            if (db.get(table)) |tbl| {
                return tbl.rules;
            } else return error.NoTableFound;
        } else return error.NoDataBaseFound;
    } else return error.NoNameSpaceFound;
}

pub fn get_rules_portable(namespace: []const u8, database: []const u8, table: []const u8) ![]const u8 {
    if (root.get(namespace)) |ns| {
        if (ns.get(database)) |db| {
            if (db.get(table)) |tbl| {
                var rules: []const u8 = "";
                if (tbl.rules.accept_extension) |tr_ae| {
                    rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, "E" });
                    if (tr_ae[0][0] != 0) rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, tr_ae[0][0..] });
                    if (tr_ae[1][0] != 0) rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, ",", tr_ae[1][0..], "" });
                    if (tr_ae[2][0] != 0) rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, ",", tr_ae[2][0..], "" });
                    if (tr_ae[3][0] != 0) rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, ",", tr_ae[3][0..], "" });
                }
                if (tbl.rules.accept_size) |tr_as| {
                    var sizeBuffer: [13]u8 = undefined;
                    rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, "S", try std.fmt.bufPrint(&sizeBuffer, "{d}", .{tr_as}) });
                }
                if (tbl.rules.accept_format) |tr_af| {
                    rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, "F" });
                    if (tr_af[0][0] != 0) rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, tr_af[0][0..] });
                    if (tr_af[1][0] != 0) rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, ",", tr_af[1][0..], "" });
                    if (tr_af[2][0] != 0) rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, ",", tr_af[2][0..], "" });
                    if (tr_af[3][0] != 0) rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, ",", tr_af[3][0..], "" });
                }
                if (tbl.rules.accept_optimise) |tr_ao| {
                    var sizeBuffer: [8]u8 = undefined;
                    rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, "O", try std.fmt.bufPrint(&sizeBuffer, "{d}", .{tr_ao}) });
                }
                if (tbl.rules.mark) |tr_m| {
                    rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, "M" });
                    for (tr_m) |array| {
                        var qualityBuffer: [2]u8 = undefined;
                        var scaleBuffer: [2]u8 = undefined;
                        if (array[0] == 0) continue;
                        const formatted: []const u8 = &[1]u8{array[0]};
                        rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, formatted, ":" });
                        rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, try std.fmt.bufPrint(&qualityBuffer, "{d}", .{array[1]}), ":" });
                        rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, try std.fmt.bufPrint(&scaleBuffer, "{d}", .{array[2]}), "," });
                    }
                    rules = rules[0..(rules.len - 1)];
                }
                return rules;
            } else return error.NoTableFound;
        } else return error.NoDataBaseFound;
    } else return error.NoNameSpaceFound;
}

pub fn get_rules(namespace: []const u8, database: []const u8, table: []const u8) ![]const u8 {
    if (root.get(namespace)) |ns| {
        if (ns.get(database)) |db| {
            if (db.get(table)) |tbl| {
                var rules: []const u8 = "";
                rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, "> ", table, "\n" });
                if (tbl.rules.accept_extension) |tr_ae| {
                    rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, "   EXTENSION [\n" });
                    if (tr_ae[0][0] != 0) rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, "       #1:[", tr_ae[0][0..], "]\n" });
                    if (tr_ae[1][0] != 0) rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, "       #2:[", tr_ae[1][0..], "]\n" });
                    if (tr_ae[2][0] != 0) rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, "       #3:[", tr_ae[2][0..], "]\n" });
                    if (tr_ae[3][0] != 0) rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, "       #4:[", tr_ae[3][0..], "]\n" });
                    rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, "   ]\n" });
                }
                if (tbl.rules.accept_size) |tr_as| {
                    var sizeBuffer: [8]u8 = undefined;
                    if (tr_as > 1024 * 1024 * 1024 * 1024) {
                        rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, "   SIZE [", try std.fmt.bufPrint(&sizeBuffer, "{d}", .{tr_as / (1024 * 1024 * 1024 * 1024)}), "TB]\n" });
                    } else if (tr_as > 1024 * 1024 * 1024) {
                        rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, "   SIZE [", try std.fmt.bufPrint(&sizeBuffer, "{d}", .{tr_as / (1024 * 1024 * 1024)}), "GB]\n" });
                    } else if (tr_as > 1024 * 1024) {
                        rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, "   SIZE [", try std.fmt.bufPrint(&sizeBuffer, "{d}", .{tr_as / (1024 * 1024)}), "MB]\n" });
                    } else if (tr_as > 1024) {
                        rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, "   SIZE [", try std.fmt.bufPrint(&sizeBuffer, "{d}", .{tr_as / 1024}), "KB]\n" });
                    } else {
                        rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, "   SIZE [", try std.fmt.bufPrint(&sizeBuffer, "{d}", .{tr_as}), "B]\n" });
                    }
                }
                if (tbl.rules.accept_format) |tr_af| {
                    rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, "   FORMAT [\n" });
                    if (tr_af[0][0] != 0) rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, "       #1:[", tr_af[0][0..], "]\n" });
                    if (tr_af[1][0] != 0) rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, "       #2:[", tr_af[1][0..], "]\n" });
                    if (tr_af[2][0] != 0) rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, "       #3:[", tr_af[2][0..], "]\n" });
                    if (tr_af[3][0] != 0) rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, "       #4:[", tr_af[3][0..], "]\n" });
                    rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, "   ]\n" });
                }
                if (tbl.rules.accept_optimise) |tr_ao| {
                    var sizeBuffer: [8]u8 = undefined;
                    rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, "   OPTIMISE [", try std.fmt.bufPrint(&sizeBuffer, "{d}", .{tr_ao}), "]\n" });
                }
                if (tbl.rules.mark) |tr_m| {
                    rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, "   MARK [\n" });
                    for (tr_m) |array| {
                        var qualityBuffer: [2]u8 = undefined;
                        var scaleBuffer: [2]u8 = undefined;
                        if (array[0] == 0) continue;
                        const formatted: []const u8 = &[1]u8{array[0]};
                        rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, "        [", formatted, " -- " });
                        rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, try std.fmt.bufPrint(&qualityBuffer, "{d}", .{array[1]}), " -- " });
                        rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, try std.fmt.bufPrint(&scaleBuffer, "{d}", .{array[2]}), "]\n" });
                    }
                    rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, "   ]\n" });
                }
                rules = try std.mem.join(std.heap.page_allocator, "", &[_][]const u8{ rules, "<\n" });
                return rules;
            } else return error.NoTableFound;
        } else return error.NoDataBaseFound;
    } else return error.NoNameSpaceFound;
}
