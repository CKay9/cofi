const std = @import("std");
const fs = std.fs;
const process = std.process;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const terminal = @import("terminal.zig");
const utils = @import("utils.zig");
const ui = @import("ui.zig");

/// Add a new favorite to the list
fn addFavorite(favorites: *ArrayList(utils.Favorite), path: []const u8, allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    try stdout.print("Enter the path to the configuration file: ", .{});
    var path_buffer: [1024]u8 = undefined;
    const file_path = (try stdin.readUntilDelimiterOrEof(&path_buffer, '\n')) orelse return;

    // Verify the file exists
    fs.accessAbsolute(file_path, .{}) catch {
        try stdout.print("File does not exist: {s}\n", .{file_path});
        return;
    };

    // Check if it's already in favorites
    for (favorites.items) |fav| {
        if (std.mem.eql(u8, fav.path, file_path)) {
            try stdout.print("File is already in favorites\n", .{});
            return;
        }
    }

    // Get optional name
    try stdout.print("Enter a name for this config (optional, press Enter to skip): ", .{});
    var name_buffer: [256]u8 = undefined;
    const name_input = (try stdin.readUntilDelimiterOrEof(&name_buffer, '\n')) orelse "";

    // Get optional category
    try stdout.print("Enter a category for this config (optional, press Enter to skip): ", .{});
    var category_buffer: [256]u8 = undefined;
    const category_input = (try stdin.readUntilDelimiterOrEof(&category_buffer, '\n')) orelse "";

    // Create the favorite
    const favorite = utils.Favorite{
        .path = try allocator.dupe(u8, file_path),
        .name = if (name_input.len > 0) try allocator.dupe(u8, name_input) else null,
        .category = if (category_input.len > 0) try allocator.dupe(u8, category_input) else null,
    };

    try favorites.append(favorite);
    try utils.saveFavorites(path, favorites.*, allocator);
    try stdout.print("Favorite added: {s}\n", .{file_path});
}

/// Remove a favorite from the list
fn removeFavorite(favorites: *ArrayList(utils.Favorite), path: []const u8, allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    if (favorites.items.len == 0) {
        try stdout.print("No favorites available to remove\n", .{});
        return;
    }

    // Create display strings for the UI
    var display_items = ArrayList([]u8).init(allocator);
    defer {
        for (display_items.items) |item| {
            allocator.free(item);
        }
        display_items.deinit();
    }

    for (favorites.items) |fav| {
        var display: []u8 = undefined;

        if (fav.name) |name| {
            if (fav.category) |category| {
                display = try std.fmt.allocPrint(allocator, "{s} [{s}] - {s}", .{ name, category, fav.path });
            } else {
                display = try std.fmt.allocPrint(allocator, "{s} - {s}", .{ name, fav.path });
            }
        } else {
            if (fav.category) |category| {
                display = try std.fmt.allocPrint(allocator, "{s} [{s}]", .{ fav.path, category });
            } else {
                display = try allocator.dupe(u8, fav.path);
            }
        }

        try display_items.append(display);
    }

    // Use the UI module to select a favorite
    const selection = try ui.selectFromList(stdout, stdin, "Available favorites", display_items.items);

    if (selection) |idx| {
        try stdout.print("Remove {s}? (y/n): ", .{display_items.items[idx]});

        var confirm_buffer: [10]u8 = undefined;
        const confirm = (try stdin.readUntilDelimiterOrEof(&confirm_buffer, '\n')) orelse "";

        if (confirm.len > 0 and (confirm[0] == 'y' or confirm[0] == 'Y')) {
            // Free memory for the removed favorite
            if (favorites.items[idx].name) |name| allocator.free(name);
            if (favorites.items[idx].category) |category| allocator.free(category);
            allocator.free(favorites.items[idx].path);

            _ = favorites.orderedRemove(idx);
            try utils.saveFavorites(path, favorites.*, allocator);
            try stdout.print("Favorite removed\n", .{});
        } else {
            try stdout.print("Removal cancelled\n", .{});
        }
    }
}

/// Show and select from favorites list
fn showFavorites(favorites: *ArrayList(utils.Favorite), allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    if (favorites.items.len == 0) {
        try stdout.print("No favorites available\n", .{});
        return;
    }

    // Create display strings for the UI
    var display_items = ArrayList([]u8).init(allocator);
    defer {
        for (display_items.items) |item| {
            allocator.free(item);
        }
        display_items.deinit();
    }

    for (favorites.items) |fav| {
        var display: []u8 = undefined;

        if (fav.name) |name| {
            if (fav.category) |category| {
                display = try std.fmt.allocPrint(allocator, "{s} [{s}] - {s}", .{ name, category, fav.path });
            } else {
                display = try std.fmt.allocPrint(allocator, "{s} - {s}", .{ name, fav.path });
            }
        } else {
            if (fav.category) |category| {
                display = try std.fmt.allocPrint(allocator, "{s} [{s}]", .{ fav.path, category });
            } else {
                display = try allocator.dupe(u8, fav.path);
            }
        }

        try display_items.append(display);
    }

    // Use the UI module to select a favorite
    const selection = try ui.selectFromList(stdout, stdin, "Your favorites", display_items.items);

    if (selection) |idx| {
        try utils.openWithEditor(favorites.items[idx].path, allocator);
    }
}

pub fn manageFavorites(allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    const paths = utils.getFavoritesPath(allocator) catch |err| {
        try stdout.print("Error setting up config directory: {any}\n", .{err});
        return;
    };
    defer allocator.free(paths.config_dir);
    defer allocator.free(paths.favorites_path);

    try utils.initializeFavoritesFile(paths.favorites_path, allocator);

    var favorites_list = try utils.loadFavorites(paths.favorites_path, allocator);
    defer {
        for (favorites_list.items) |item| {
            if (item.name) |name| allocator.free(name);
            if (item.category) |category| allocator.free(category);
            allocator.free(item.path);
        }
        favorites_list.deinit();
    }

    const menu_items = [_][]const u8{ "Show favorites", "Add favorite", "Remove favorite", "Exit" };

    while (true) {
        const selection = try ui.selectFromMenu(stdout, stdin, "cofi - Config File Manager", &menu_items);

        if (selection) |idx| {
            switch (idx) {
                0 => try showFavorites(&favorites_list, allocator),
                1 => try addFavorite(&favorites_list, paths.favorites_path, allocator),
                2 => try removeFavorite(&favorites_list, paths.favorites_path, allocator),
                3 => return,
                else => {},
            }
        } else {
            return;
        }
    }
}
