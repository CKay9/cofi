// src/modules/utils.zig
const std = @import("std");
const fs = std.fs;
const process = std.process;
const ArrayList = std.ArrayList;

// Path constants
pub const CONFIG_DIR_NAME = "/.config/cofi";
pub const FAVORITES_FILE_NAME = "/favorites.txt";

/// Get the user's home directory
pub fn getHomeDirectory(allocator: std.mem.Allocator) ![]const u8 {
    var env_map = try process.getEnvMap(allocator);
    defer env_map.deinit();

    const home_dir = env_map.get("HOME") orelse {
        return error.HomeNotFound;
    };

    return allocator.dupe(u8, home_dir);
}

/// Get the user's preferred editor from EDITOR environment variable
pub fn getEditorName(allocator: std.mem.Allocator) ![]const u8 {
    var env_map = try process.getEnvMap(allocator);
    defer env_map.deinit();

    const editor = env_map.get("EDITOR") orelse "nano";
    return allocator.dupe(u8, editor);
}

/// Get paths to config directory and favorites file
pub fn getFavoritesPath(allocator: std.mem.Allocator) !struct { config_dir: []const u8, favorites_path: []const u8 } {
    const home_dir = try getHomeDirectory(allocator);
    defer allocator.free(home_dir);

    const config_dir = try std.fmt.allocPrint(allocator, "{s}{s}", .{ home_dir, CONFIG_DIR_NAME });

    // Create config directory if it doesn't exist
    fs.makeDirAbsolute(config_dir) catch |err| {
        if (err != error.PathAlreadyExists) {
            allocator.free(config_dir);
            return err;
        }
    };

    const favorites_path = try std.fmt.allocPrint(allocator, "{s}{s}", .{ config_dir, FAVORITES_FILE_NAME });

    return .{ .config_dir = config_dir, .favorites_path = favorites_path };
}

/// Load favorites from file
pub fn loadFavorites(path: []const u8, favorites: *ArrayList([]u8), allocator: std.mem.Allocator) !void {
    const file = fs.openFileAbsolute(path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            return error.FileNotFound;
        }
        return err;
    };
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();
    var buf: [4096]u8 = undefined;

    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        const path_copy = try allocator.dupe(u8, line);
        try favorites.append(path_copy);
    }
}

/// Save favorites to file
pub fn saveFavorites(path: []const u8, favorites: *ArrayList([]u8), _: std.mem.Allocator) !void {
    const file = try fs.createFileAbsolute(path, .{});
    defer file.close();

    for (favorites.items) |fav| {
        try file.writeAll(fav);
        try file.writeAll("\n");
    }
}

/// Open a file with the user's editor
pub fn openWithEditor(file_path: []const u8, allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();

    const editor = try getEditorName(allocator);
    defer allocator.free(editor);

    try stdout.print("Opening {s} with {s}...\n", .{ file_path, editor });

    var child = std.process.Child.init(&[_][]const u8{ editor, file_path }, allocator);

    child.stdin_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;

    _ = try child.spawnAndWait();
}
