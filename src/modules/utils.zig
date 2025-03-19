const std = @import("std");
const fs = std.fs;
const process = std.process;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const CONFIG_DIR_NAME = "/.config/cofi";
pub const FAVORITES_FILE_NAME = "/favorites.json";

pub const Favorite = struct {
    path: []const u8,
    name: ?[]const u8 = null,
    category: ?[]const u8 = null,
};

pub const FavoritesData = struct {
    favorites: []Favorite,
};

pub fn initializeFavoritesFile(path: []const u8, _: Allocator) !void {
    if (fs.accessAbsolute(path, .{})) {
        return;
    } else |_| {
        const file = try fs.createFileAbsolute(path, .{});
        defer file.close();

        try file.writeAll("{\n    \"favorites\": []\n}");
    }
}

pub fn getHomeDirectory(allocator: Allocator) ![]const u8 {
    var env_map = try process.getEnvMap(allocator);
    defer env_map.deinit();

    const home_dir = env_map.get("HOME") orelse {
        return error.HomeNotFound;
    };

    return allocator.dupe(u8, home_dir);
}

/// Get the user's preferred editor from EDITOR environment variable
pub fn getEditorName(allocator: Allocator) ![]const u8 {
    var env_map = try process.getEnvMap(allocator);
    defer env_map.deinit();

    const editor = env_map.get("EDITOR") orelse "nano";
    return allocator.dupe(u8, editor);
}

/// Get paths to config directory and favorites file
pub fn getFavoritesPath(allocator: Allocator) !struct { config_dir: []const u8, favorites_path: []const u8 } {
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

pub fn loadFavorites(path: []const u8, allocator: std.mem.Allocator) !ArrayList(Favorite) {
    var favorites = ArrayList(Favorite).init(allocator);

    // Try to initialize the file if it doesn't exist
    try initializeFavoritesFile(path, allocator);

    // Open the file
    const file = fs.openFileAbsolute(path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            return favorites;
        }
        return err;
    };
    defer file.close();

    // Read the content
    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    // Debug: print the content to see what's there
    const stdout = std.io.getStdOut().writer();
    try stdout.print("JSON content: {s}\n", .{content});

    // If the file is empty or just whitespace, initialize it
    if (content.len == 0 or std.mem.eql(u8, std.mem.trim(u8, content, &std.ascii.whitespace), "")) {
        try initializeFavoritesFile(path, allocator);
        try stdout.print("Initialized empty JSON file\n", .{});
        return favorites;
    }

    // Try to parse, but handle syntax errors gracefully
    const parsed = std.json.parseFromSlice(
        FavoritesData,
        allocator,
        content,
        .{},
    ) catch |err| {
        try stdout.print("Error parsing JSON: {any}\n", .{err});
        try stdout.print("Reinitializing favorites file\n", .{});
        try initializeFavoritesFile(path, allocator);
        return favorites;
    };
    defer parsed.deinit();

    // Copy favorites from parsed data
    for (parsed.value.favorites) |fav| {
        try favorites.append(Favorite{
            .path = try allocator.dupe(u8, fav.path),
            .name = if (fav.name) |name| try allocator.dupe(u8, name) else null,
            .category = if (fav.category) |category| try allocator.dupe(u8, category) else null,
        });
    }

    return favorites;
}

pub fn saveFavorites(path: []const u8, favorites: ArrayList(Favorite), allocator: Allocator) !void {
    // Create the file
    const file = try fs.createFileAbsolute(path, .{});
    defer file.close();

    // Create an array to hold the favorites
    var favs_array = try allocator.alloc(Favorite, favorites.items.len);
    defer allocator.free(favs_array);

    // Copy the favorites to the array
    for (favorites.items, 0..) |fav, i| {
        favs_array[i] = fav;
    }

    // Create the root object
    const root = FavoritesData{
        .favorites = favs_array,
    };

    // Stringify to JSON with pretty formatting
    try std.json.stringify(root, .{ .whitespace = .indent_4 }, file.writer());
}

/// Open a file with the user's editor
pub fn openWithEditor(file_path: []const u8, allocator: Allocator) !void {
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
