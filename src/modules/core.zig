const std = @import("std");
const fs = std.fs;
const process = std.process;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const terminal = @import("terminal.zig");
const utils = @import("utils.zig");
const ui = @import("ui.zig");

pub fn showSettingsMenu(allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    const menu_items = [_][]const u8{ "Editor", "List Items Count", "Sort by Name [A-Z] or [Z-A]", "Sort by Category [A-Z] or [Z-A]", "Back" };

    while (true) {
        const selection = try ui.selectFromMenu(stdout, stdin, "Settings", &menu_items);

        if (selection) |idx| {
            switch (idx) {
                0 => try changeEditorSetting(allocator),
                1 => try changeListVisibleItemsSetting(allocator),
                2 => try changeSortSettings(allocator, .name),
                3 => try changeSortSettings(allocator, .category),
                4 => return,
                else => {},
            }
        } else {
            return;
        }
    }
}

pub fn changeEditorSetting(allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    var settings = try utils.loadSettings(allocator);
    defer settings.deinit(allocator);

    var env_editor: ?[]const u8 = null;
    var display_editor: []const u8 = undefined;

    if (settings.editor) |editor| {
        display_editor = editor;
    } else {
        env_editor = utils.getEditorName(allocator) catch null;
        if (env_editor) |editor| {
            display_editor = editor;
        } else {
            display_editor = "nano";
        }
    }

    try stdout.print("Current editor: {s}\n", .{display_editor});
    try stdout.print("Enter new editor (leave empty to use environment variable): ", .{});

    if (env_editor) |editor| {
        allocator.free(editor);
    }

    var buffer: [256]u8 = undefined;
    const input = (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) orelse "";

    if (input.len > 0) {
        if (settings.editor) |old_editor| {
            allocator.free(old_editor);
        }
        settings.editor = try allocator.dupe(u8, input);
    } else {
        if (settings.editor) |old_editor| {
            allocator.free(old_editor);
            settings.editor = null;
        }
    }

    try utils.saveSettings(allocator, settings);

    try stdout.print("\nEditor updated. Press any key to continue...", .{});
    var key_buffer: [1]u8 = undefined;
    _ = try stdin.read(&key_buffer);
}

fn addFavorite(favorites: *ArrayList(utils.Favorite), path: []const u8, allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    try stdout.print("Enter the path to the configuration file: ", .{});
    var path_buffer: [1024]u8 = undefined;
    const input_path = (try stdin.readUntilDelimiterOrEof(&path_buffer, '\n')) orelse return;

    const expanded_path = utils.expandTildePath(input_path, allocator) catch |err| {
        try utils.handleErrorFmt(stdout, stdin, allocator, "Invalid path format '{s}': {}", .{ input_path, err });
        return;
    };
    defer allocator.free(expanded_path);

    if (!fs.path.isAbsolute(expanded_path)) {
        try utils.handleErrorFmt(stdout, stdin, allocator, "Path must be absolute (start with '/' or '~/'). You entered: '{s}'", .{input_path});
        return;
    }

    const file_exists = blk: {
        var file = fs.openFileAbsolute(expanded_path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                break :blk false;
            } else {
                try utils.handleError(stdout, stdin, try std.fmt.allocPrint(allocator, "Error accessing file: {}", .{err}));
                return;
            }
        };
        defer file.close();
        break :blk true;
    };

    if (!file_exists) {
        try utils.handleError(stdout, stdin, try std.fmt.allocPrint(allocator, "File '{s}' does not exist", .{expanded_path}));
        return;
    }

    for (favorites.items) |fav| {
        if (std.mem.eql(u8, fav.path, expanded_path)) {
            try utils.handleError(stdout, stdin, "File is already in favorites.");
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

    const selection = try ui.selectFromList(stdout, stdin, "Remove Files", display_items.items, true);

    if (selection) |idx| {
        try stdout.print("Remove {s}? (y/n): ", .{display_items.items[idx]});

        var confirm_buffer: [10]u8 = undefined;
        const confirm = (try stdin.readUntilDelimiterOrEof(&confirm_buffer, '\n')) orelse "";

        if (confirm.len > 0 and (confirm[0] == 'y' or confirm[0] == 'Y')) {
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

pub fn changeListVisibleItemsSetting(allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    var settings = try utils.loadSettings(allocator);
    defer settings.deinit(allocator);

    const current_count = ui.LIST_VISIBLE_ITEMS;

    try stdout.print("Current number of visible list items: {d}\n", .{current_count});
    try stdout.print("Enter new number (3-15, leave empty for default 7): ", .{});

    var buffer: [256]u8 = undefined;
    const input = (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) orelse "";

    if (input.len > 0) {
        const new_count = std.fmt.parseInt(u8, input, 10) catch |err| {
            try utils.handleError(stdout, stdin, try std.fmt.allocPrint(allocator, "Invalid input: {}", .{err}));
            return;
        };

        if (new_count < 3 or new_count > 15) {
            try utils.handleError(stdout, stdin, "Value must be between 3 and 15.");
            return;
        }

        settings.list_visible_items = new_count;
        ui.LIST_VISIBLE_ITEMS = new_count;
    } else {
        settings.list_visible_items = null; // Reset to default
        ui.LIST_VISIBLE_ITEMS = 7; // Reset to default value
    }

    try utils.saveSettings(allocator, settings);

    try stdout.print("\nVisible list items updated to {d}. Press any key to continue...", .{ui.LIST_VISIBLE_ITEMS});
    var key_buffer: [1]u8 = undefined;
    _ = try stdin.read(&key_buffer);
}

fn showFavorites(favorites: *ArrayList(utils.Favorite), allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    if (favorites.items.len == 0) {
        try utils.handleError(stdout, stdin, "No files available");
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
        try utils.handleError(stdout, stdin, try std.fmt.allocPrint(allocator, "No files match the selected category: {s}", .{selected_category}));
        return;
    }

    const list_title = try std.fmt.allocPrint(allocator, "Files - {s}", .{selected_category});
    defer allocator.free(list_title);

    const favorite_selection = try ui.selectFromList(stdout, stdin, list_title, display_items.items, false);

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

    const menu_items = [_][]const u8{ "Show files", "Add file", "Remove file", "Categories", "Settings", "Exit" };

    while (true) {
        const selection = try ui.selectFromMenu(stdout, stdin, "cofi - Config File Manager", &menu_items);

        if (selection) |idx| {
            switch (idx) {
                0 => try showAllFavorites(&favorites_list, allocator),
                1 => try addFavorite(&favorites_list, paths.favorites_path, allocator),
                2 => try removeFavorite(&favorites_list, paths.favorites_path, allocator),
                3 => try showCategoriesMenu(&favorites_list, allocator),
                4 => try showSettingsMenu(allocator),
                5 => return,
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
        try utils.handleError(stdout, stdin, "No files available");
        return;
    }

    var settings = try utils.loadSettings(allocator);
    defer settings.deinit(allocator);

    utils.sortFavoritesList(favorites, settings);

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

    const favorite_selection = try ui.selectFromList(stdout, stdin, "Your files", display_items.items, false);

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
        try utils.handleError(stdout, stdin, "No categories available. Add some files with categories first.");
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
        try utils.handleError(stdout, stdin, try std.fmt.allocPrint(allocator, "No files match the selected category: {s}", .{category}));
        return;
    }

    const list_title = try std.fmt.allocPrint(allocator, "Category: {s}", .{category});
    defer allocator.free(list_title);

    const favorite_selection = try ui.selectFromList(stdout, stdin, list_title, display_items.items, false);

    if (favorite_selection) |idx| {
        const original_idx = display_to_favorite.items[idx];
        try utils.openWithEditor(favorites.items[original_idx].path, allocator);
    }
}

pub fn changeSortSettings(allocator: std.mem.Allocator, field: utils.SortField) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    var settings = try utils.loadSettings(allocator);
    defer settings.deinit(allocator);

    const is_already_selected = settings.sort_field == field;

    if (is_already_selected) {
        settings.sort_order = if (settings.sort_order == .ascending) .descending else .ascending;
    } else {
        settings.sort_field = field;
        settings.sort_order = .ascending;
    }

    try utils.saveSettings(allocator, settings);

    const field_name = if (field == .name) "Name" else "Category";
    const order_name = if (settings.sort_order == .ascending) "A-Z" else "Z-A";

    try stdout.print("\nSort updated: {s} ({s}). Press any key to continue...", .{ field_name, order_name });
    var key_buffer: [1]u8 = undefined;
    _ = try stdin.read(&key_buffer);
}
