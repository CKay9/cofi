const std = @import("std");
const fs = std.fs;
const process = std.process;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const terminal = @import("terminal.zig");
const utils = @import("utils.zig");
const ui = @import("ui.zig");

fn addFavorite(favorites: *ArrayList(utils.Favorite), path: []const u8, allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    try stdout.print("Enter the path to the configuration file: ", .{});
    var path_buffer: [1024]u8 = undefined;
    const input_path = (try stdin.readUntilDelimiterOrEof(&path_buffer, '\n')) orelse return;

    // First try to expand the path (handling ~/ if present)
    var expanded_path: []const u8 = undefined;
    expanded_path = utils.expandTildePath(input_path, allocator) catch |err| {
        try stdout.print("\nError: Invalid path format '{s}': {}\n", .{ input_path, err });
        try stdout.print("Press any key to continue...", .{});
        var key_buffer: [1]u8 = undefined;
        _ = try stdin.read(&key_buffer);
        return;
    };
    defer allocator.free(expanded_path);

    // Check if the path is absolute
    if (!fs.path.isAbsolute(expanded_path)) {
        try stdout.print("\nError: Path must be absolute (start with '/' or '~/')\n", .{});
        try stdout.print("You entered: '{s}'\n", .{input_path});
        try stdout.print("Press any key to continue...", .{});
        var key_buffer: [1]u8 = undefined;
        _ = try stdin.read(&key_buffer);
        return;
    }

    // Now that we have a valid absolute path, check if the file exists
    const file_exists = blk: {
        var file = fs.openFileAbsolute(expanded_path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                break :blk false;
            } else {
                try stdout.print("\nError accessing file: {}\n", .{err});
                try stdout.print("Press any key to continue...", .{});
                var key_buffer: [1]u8 = undefined;
                _ = try stdin.read(&key_buffer);
                return;
            }
        };
        defer file.close();
        break :blk true;
    };

    if (!file_exists) {
        try stdout.print("\nError: File '{s}' does not exist\n", .{expanded_path});
        try stdout.print("Press any key to continue...", .{});
        var key_buffer: [1]u8 = undefined;
        _ = try stdin.read(&key_buffer);
        return;
    }

    // Check if the file is already in favorites
    for (favorites.items) |fav| {
        if (std.mem.eql(u8, fav.path, expanded_path)) {
            try stdout.print("\nFile is already in favorites.\n", .{});
            try stdout.print("Press any key to continue...", .{});
            var key_buffer: [1]u8 = undefined;
            _ = try stdin.read(&key_buffer);
            return;
        }
    }

    try stdout.print("Enter a name for this config (optional, press Enter to skip): ", .{});
    var name_buffer: [256]u8 = undefined;
    const name_input = (try stdin.readUntilDelimiterOrEof(&name_buffer, '\n')) orelse "";

    try stdout.print("Enter a category for this config (optional, press Enter to skip): ", .{});
    var category_buffer: [256]u8 = undefined;
    const category_input = (try stdin.readUntilDelimiterOrEof(&category_buffer, '\n')) orelse "";

    const favorite = utils.Favorite{
        .path = try allocator.dupe(u8, expanded_path),
        .name = if (name_input.len > 0) try allocator.dupe(u8, name_input) else null,
        .category = if (category_input.len > 0) try allocator.dupe(u8, category_input) else null,
    };

    try favorites.append(favorite);
    try utils.saveFavorites(path, favorites.*, allocator);
    try stdout.print("\nFavorite added: {s}\n", .{expanded_path});
    try stdout.print("Press any key to continue...", .{});
    var key_buffer: [1]u8 = undefined;
    _ = try stdin.read(&key_buffer);
}

fn removeFavorite(favorites: *ArrayList(utils.Favorite), path: []const u8, allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    if (favorites.items.len == 0) {
        try stdout.print("No files available to remove\n", .{});
        return;
    }

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

    const selection = try ui.selectFromList(stdout, stdin, "Available files", display_items.items);

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

fn showFavorites(favorites: *ArrayList(utils.Favorite), allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    if (favorites.items.len == 0) {
        try stdout.print("No files available\n", .{});
        return;
    }

    var categories = ArrayList([]const u8).init(allocator);
    defer {
        for (categories.items) |category| {
            allocator.free(category);
        }
        categories.deinit();
    }

    try categories.append(try allocator.dupe(u8, "All"));
    try categories.append(try allocator.dupe(u8, "Uncategorized"));

    var seen = std.StringHashMap(void).init(allocator);
    defer seen.deinit();
    try seen.put("All", {});
    try seen.put("Uncategorized", {});

    for (favorites.items) |fav| {
        if (fav.category) |category| {
            if (!seen.contains(category)) {
                try seen.put(category, {});
                try categories.append(try allocator.dupe(u8, category));
            }
        }
    }

    var display_categories = try ArrayList([]u8).initCapacity(allocator, categories.items.len);
    defer {
        for (display_categories.items) |item| {
            allocator.free(item);
        }
        display_categories.deinit();
    }

    for (categories.items) |category| {
        try display_categories.append(try allocator.dupe(u8, category));
    }

    const category_selection = try ui.selectFromList(stdout, stdin, "Select category to filter by", display_categories.items);

    if (category_selection == null) {
        return; // User pressed 'q'
    }

    const selected_category_idx = category_selection.?;
    const selected_category = categories.items[selected_category_idx];

    var display_items = ArrayList([]u8).init(allocator);
    defer {
        for (display_items.items) |item| {
            allocator.free(item);
        }
        display_items.deinit();
    }

    var display_to_favorite = ArrayList(usize).init(allocator);
    defer display_to_favorite.deinit();

    for (favorites.items, 0..) |fav, fav_idx| {
        var should_display = false;

        if (std.mem.eql(u8, selected_category, "All")) {
            should_display = true;
        } else if (std.mem.eql(u8, selected_category, "Uncategorized")) {
            should_display = (fav.category == null);
        } else if (fav.category) |category| {
            should_display = std.mem.eql(u8, category, selected_category);
        }

        if (should_display) {
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
            try display_to_favorite.append(fav_idx);
        }
    }

    if (display_items.items.len == 0) {
        try stdout.print("\nNo files match the selected category. Press any key to continue...\n", .{});
        var key_buffer: [1]u8 = undefined;
        _ = try stdin.read(&key_buffer);
        return;
    }

    const list_title = try std.fmt.allocPrint(allocator, "Files - {s}", .{selected_category});
    defer allocator.free(list_title);

    const favorite_selection = try ui.selectFromList(stdout, stdin, list_title, display_items.items);

    if (favorite_selection) |idx| {
        const original_idx = display_to_favorite.items[idx];
        try utils.openWithEditor(favorites.items[original_idx].path, allocator);
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

    const menu_items = [_][]const u8{ "Show files", "Add file", "Remove file", "Categories", "Exit" };

    while (true) {
        const selection = try ui.selectFromMenu(stdout, stdin, "cofi - Config File Manager", &menu_items);

        if (selection) |idx| {
            switch (idx) {
                0 => try showAllFavorites(&favorites_list, allocator),
                1 => try addFavorite(&favorites_list, paths.favorites_path, allocator),
                2 => try removeFavorite(&favorites_list, paths.favorites_path, allocator),
                3 => try showCategoriesMenu(&favorites_list, allocator),
                4 => return,
                else => {},
            }
        } else {
            return;
        }
    }
}

fn showAllFavorites(favorites: *ArrayList(utils.Favorite), allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    if (favorites.items.len == 0) {
        try stdout.print("No files available\n", .{});
        return;
    }

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

    const favorite_selection = try ui.selectFromList(stdout, stdin, "Your files", display_items.items);

    if (favorite_selection) |idx| {
        try utils.openWithEditor(favorites.items[idx].path, allocator);
    }
}

fn showCategoriesMenu(favorites: *ArrayList(utils.Favorite), allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    var categories = try utils.getUniqueCategories(favorites.*, allocator);
    defer {
        for (categories.items) |category| {
            allocator.free(category);
        }
        categories.deinit();
    }

    if (categories.items.len == 0) {
        try stdout.print("No categories available. Add some files with categories first.\n", .{});
        var key_buffer: [1]u8 = undefined;
        _ = try stdin.read(&key_buffer);
        return;
    }

    const selected_category = try ui.selectCategory(stdout, stdin, categories.items);

    if (selected_category) |category| {
        try showFilteredFavorites(favorites, category, allocator);
    }
}

fn showFilteredFavorites(favorites: *ArrayList(utils.Favorite), category: []const u8, allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    var display_items = ArrayList([]u8).init(allocator);
    defer {
        for (display_items.items) |item| {
            allocator.free(item);
        }
        display_items.deinit();
    }

    var display_to_favorite = ArrayList(usize).init(allocator);
    defer display_to_favorite.deinit();

    for (favorites.items, 0..) |fav, fav_idx| {
        var should_display = false;

        if (fav.category) |fav_category| {
            should_display = std.mem.eql(u8, fav_category, category);
        }

        if (should_display) {
            var display: []u8 = undefined;

            if (fav.name) |name| {
                display = try std.fmt.allocPrint(allocator, "{s} - {s}", .{ name, fav.path });
            } else {
                display = try allocator.dupe(u8, fav.path);
            }

            try display_items.append(display);
            try display_to_favorite.append(fav_idx);
        }
    }

    if (display_items.items.len == 0) {
        try stdout.print("\nNo files with category '{s}'. Press any key to continue...\n", .{category});
        var key_buffer: [1]u8 = undefined;
        _ = try stdin.read(&key_buffer);
        return;
    }

    const list_title = try std.fmt.allocPrint(allocator, "Category: {s}", .{category});
    defer allocator.free(list_title);

    const favorite_selection = try ui.selectFromList(stdout, stdin, list_title, display_items.items);

    if (favorite_selection) |idx| {
        const original_idx = display_to_favorite.items[idx];
        try utils.openWithEditor(favorites.items[original_idx].path, allocator);
    }
}
