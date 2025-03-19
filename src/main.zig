const std = @import("std");
const process = std.process;
const fs = std.fs;
const core = @import("modules/core.zig");
const help = @import("modules/help.zig");
const ArrayList = std.ArrayList;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const stdout = std.io.getStdOut().writer();

    // Process command line arguments
    const args = try process.argsAlloc(allocator);
    defer process.argsFree(allocator, args);

    // Check if we have args (besides the program name)
    if (args.len > 1) {
        const arg = args[1];

        // First check if the argument starts with "-" and isn't a negative number
        if (arg.len > 0 and arg[0] == '-' and (arg.len == 1 or !std.ascii.isDigit(arg[1]))) {
            // Handle flag arguments
            if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
                try help.printHelp(stdout);
                return;
            } else if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--version")) {
                try stdout.print("cofi version 0.0.2\n", .{});
                return;
            } else {
                const error_msg = try std.fmt.allocPrint(allocator, "Unknown flag '{s}'", .{arg});
                defer allocator.free(error_msg);
                try help.printErrorAndHelp(stdout, error_msg);
                return;
            }
        } else {
            // Handle numeric/positional arguments (remove leading dash for negative numbers)
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

    // Get the home directory path
    var env_map = try process.getEnvMap(allocator);
    defer env_map.deinit();

    const home_dir = env_map.get("HOME") orelse {
        try stdout.print("Error: HOME environment variable not set\n", .{});
        return;
    };

    // Create the config dir path
    const config_dir = try std.fmt.allocPrint(allocator, "{s}/.config/cofi", .{home_dir});
    defer allocator.free(config_dir);

    // Create directory if it doesn't exist (unlikely to be needed here but just in case)
    fs.makeDirAbsolute(config_dir) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    const favorites_path = try std.fmt.allocPrint(allocator, "{s}/favorites.txt", .{config_dir});
    defer allocator.free(favorites_path);

    var favorites_list = ArrayList([]u8).init(allocator);
    defer {
        for (favorites_list.items) |item| {
            allocator.free(item);
        }
        favorites_list.deinit();
    }

    const file = fs.openFileAbsolute(favorites_path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            try stdout.print("No favorites found. Add some favorites first.\n", .{});
            return;
        }
        return err;
    };
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();
    var buf: [4096]u8 = undefined;

    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        const path_copy = try allocator.dupe(u8, line);
        try favorites_list.append(path_copy);
    }

    // Validate the index
    if (index < 1 or index > favorites_list.items.len) {
        try stdout.print("Error: Favorite index {d} out of range. Available range: 1-{d}\n", .{ index, favorites_list.items.len });
        return;
    }

    const zero_based_index = index - 1;

    const editor = env_map.get("EDITOR") orelse "nano";

    try stdout.print("Opening {s} with {s}...\n", .{ favorites_list.items[zero_based_index], editor });

    var child = std.process.Child.init(&[_][]const u8{ editor, favorites_list.items[zero_based_index] }, allocator);

    child.stdin_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;

    _ = try child.spawnAndWait();
}
