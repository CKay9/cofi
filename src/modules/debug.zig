const std = @import("std");
const fs = std.fs;

var debug_file: ?fs.File = null;

pub fn init() !void {
    debug_file = try fs.cwd().createFile("cofi_debug.log", .{});
}

pub fn log(comptime fmt: []const u8, args: anytype) void {
    if (debug_file) |file| {
        file.writer().print(fmt ++ "\n", args) catch {};
    }
}

pub fn deinit() void {
    if (debug_file) |file| {
        file.close();
        debug_file = null;
    }
}
