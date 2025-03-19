const std = @import("std");
const process = std.process;
const fs = std.fs;
const core = @import("modules/core.zig");
const utils = @import("modules/utils.zig");
const help = @import("modules/help.zig");
const ArrayList = std.ArrayList;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const stdout = std.io.getStdOut().writer();

    const args = try process.argsAlloc(allocator);
    defer process.argsFree(allocator, args);

    if (args.len > 1) {
        const arg = args[1];

        if (arg.len > 0 and arg[0] == '-' and (arg.len == 1 or !std.ascii.isDigit(arg[1]))) {
            if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
                try help.printHelp(stdout);
                return;
            } else if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--version")) {
                try stdout.print("cofi version 0.1.2-pre-alpha\n", .{});
                return;
            } else {
                const error_msg = try std.fmt.allocPrint(allocator, "Unknown flag '{s}'", .{arg});
                defer allocator.free(error_msg);
                try help.printErrorAndHelp(stdout, error_msg);
                return;
            }
        } else {
            const index_str = if (arg.len > 0 and arg[0] == '-') arg[1..] else arg;

            const index = std.fmt.parseInt(usize, index_str, 10) catch {
                const error_msg = try std.fmt.allocPrint(allocator, "Invalid argument '{s}'", .{arg});
                defer allocator.free(error_msg);
                try help.printErrorAndHelp(stdout, error_msg);
                return;
            };

            try openSpecificFavorite(allocator, index);
        }
    } else {
        try core.manageFavorites(allocator);
    }
}

fn openSpecificFavorite(allocator: std.mem.Allocator, index: usize) !void {
    const stdout = std.io.getStdOut().writer();

    const paths = try utils.getFavoritesPath(allocator);
    defer allocator.free(paths.config_dir);
    defer allocator.free(paths.favorites_path);

    var favorites_list = ArrayList([]u8).init(allocator);
    defer {
        for (favorites_list.items) |item| {
            allocator.free(item);
        }
        favorites_list.deinit();
    }

    utils.loadFavorites(paths.favorites_path, &favorites_list, allocator) catch |err| {
        if (err == error.FileNotFound) {
            try stdout.print("No favorites found. Add some favorites first.\n", .{});
            return;
        }
        return err;
    };

    if (index < 1 or index > favorites_list.items.len) {
        try stdout.print("Error: Favorite index {d} out of range. Available range: 1-{d}\n", .{ index, favorites_list.items.len });
        return;
    }

    const zero_based_index = index - 1;

    try utils.openWithEditor(favorites_list.items[zero_based_index], allocator);
}
