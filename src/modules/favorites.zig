const std = @import("std");
const fs = std.fs;
const process = std.process;
const ArrayList = std.ArrayList;

// ANSI color codes
const ANSI_INVERT_ON = "\x1b[7m";
const ANSI_INVERT_OFF = "\x1b[27m";
const ANSI_CLEAR_SCREEN = "\x1b[2J\x1b[H";

// C imports for terminal control
const termios = @cImport({
    @cInclude("termios.h");
});

// Constants
const MENU_WIDTH = 25; // Fixed width for menu items
const CONFIG_DIR_NAME = "/.config/cofi";
const FAVORITES_FILE_NAME = "/favorites.txt";

// Terminal mode control
fn enableRawMode() !void {
    var raw: termios.termios = undefined;
    _ = termios.tcgetattr(0, &raw);
    raw.c_lflag &= ~@as(c_uint, termios.ECHO | termios.ICANON);
    _ = termios.tcsetattr(0, termios.TCSAFLUSH, &raw);
}

fn disableRawMode() void {
    var raw: termios.termios = undefined;
    _ = termios.tcgetattr(0, &raw);
    raw.c_lflag |= termios.ECHO | termios.ICANON;
    _ = termios.tcsetattr(0, termios.TCSAFLUSH, &raw);
}

// File operations
fn loadFavorites(path: []const u8, favorites: *ArrayList([]u8), allocator: std.mem.Allocator) !void {
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

fn saveFavorites(path: []const u8, favorites: *ArrayList([]u8), _: std.mem.Allocator) !void {
    const file = try fs.createFileAbsolute(path, .{});
    defer file.close();

    for (favorites.items) |fav| {
        try file.writeAll(fav);
        try file.writeAll("\n");
    }
}

// Helper functions
fn getHomeDirectory(allocator: std.mem.Allocator) ![]const u8 {
    var env_map = try process.getEnvMap(allocator);
    defer env_map.deinit();

    const home_dir = env_map.get("HOME") orelse {
        return error.HomeNotFound;
    };

    return allocator.dupe(u8, home_dir);
}

fn getEditorName(allocator: std.mem.Allocator) ![]const u8 {
    var env_map = try process.getEnvMap(allocator);
    defer env_map.deinit();

    const editor = env_map.get("EDITOR") orelse "vi";
    return allocator.dupe(u8, editor);
}

fn getFavoritesPath(allocator: std.mem.Allocator) !struct { config_dir: []const u8, favorites_path: []const u8 } {
    const home_dir = try getHomeDirectory(allocator);
    defer allocator.free(home_dir);

    const config_dir = try std.fmt.allocPrint(allocator, "{s}{s}", .{ home_dir, CONFIG_DIR_NAME });

    // Create directory if it doesn't exist
    fs.makeDirAbsolute(config_dir) catch |err| {
        if (err != error.PathAlreadyExists) {
            allocator.free(config_dir);
            return err;
        }
    };

    const favorites_path = try std.fmt.allocPrint(allocator, "{s}{s}", .{ config_dir, FAVORITES_FILE_NAME });

    return .{ .config_dir = config_dir, .favorites_path = favorites_path };
}

// Render functions
fn renderMenuItem(stdout: std.fs.File.Writer, item: []const u8, is_selected: bool, width: usize) !void {
    // Calculate padding needed
    const item_len = item.len;
    const padding = if (width > item_len) width - item_len else 0;

    if (is_selected) {
        try stdout.print("{s}>> {s}", .{ ANSI_INVERT_ON, item });
        // Add padding
        for (0..padding) |_| {
            try stdout.print(" ", .{});
        }
        try stdout.print(" <<{s}\n", .{ANSI_INVERT_OFF});
    } else {
        try stdout.print("   {s}", .{item});
        // Add padding
        for (0..padding) |_| {
            try stdout.print(" ", .{});
        }
        try stdout.print("\n", .{});
    }
}

// Menu actions
fn addFavorite(favorites: *ArrayList([]u8), path: []const u8, allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    try stdout.print("Enter the path to the configuration file: ", .{});
    var buffer: [1024]u8 = undefined;
    const input = try stdin.readUntilDelimiterOrEof(&buffer, '\n');

    if (input) |file_path| {
        // Check if file exists
        fs.accessAbsolute(file_path, .{}) catch {
            try stdout.print("File does not exist: {s}\n", .{file_path});
            return;
        };

        // Check if already in favorites
        for (favorites.items) |fav| {
            if (std.mem.eql(u8, fav, file_path)) {
                try stdout.print("File is already in favorites\n", .{});
                return;
            }
        }

        // Add to favorites
        const path_copy = try allocator.dupe(u8, file_path);
        try favorites.append(path_copy);
        try saveFavorites(path, favorites, allocator);
        try stdout.print("Favorite added: {s}\n", .{file_path});
    }
}

fn removeFavorite(favorites: *ArrayList([]u8), path: []const u8, allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    if (favorites.items.len == 0) {
        try stdout.print("No favorites available to remove\n", .{});
        return;
    }

    // Find the longest favorite path for consistent display
    var max_length: usize = 0;
    for (favorites.items) |fav| {
        max_length = @max(max_length, fav.len);
    }

    // Interactive selection menu with j/k navigation
    var current_selection: usize = 0;
    try enableRawMode();
    defer disableRawMode();

    while (true) {
        // Clear screen and redraw menu
        try stdout.print(ANSI_CLEAR_SCREEN, .{});
        try stdout.print("Available favorites:\n\n", .{});

        for (favorites.items, 0..) |fav, i| {
            if (i == current_selection) {
                try stdout.print("{s}>> {d}: {s}", .{ ANSI_INVERT_ON, i + 1, fav });
                // Add padding to make all selections the same width
                for (0..max_length - fav.len) |_| {
                    try stdout.print(" ", .{});
                }
                try stdout.print(" <<{s}\n", .{ANSI_INVERT_OFF});
            } else {
                try stdout.print("   {d}: {s}\n", .{ i + 1, fav });
            }
        }

        try stdout.print("\nUse j/k to navigate, Enter to select, q to cancel\n", .{});

        // Get keypress
        var key_buffer: [1]u8 = undefined;
        _ = try stdin.read(&key_buffer);

        switch (key_buffer[0]) {
            'j' => current_selection = @min(current_selection + 1, favorites.items.len - 1),
            'k' => current_selection = if (current_selection > 0) current_selection - 1 else 0,
            '\r', '\n' => break, // Enter selects
            'q' => return,
            else => {},
        }
    }

    // Process selection for removal
    disableRawMode();

    const idx = current_selection;
    try stdout.print("Remove {s}? (y/n): ", .{favorites.items[idx]});

    var confirm_buffer: [10]u8 = undefined;
    const confirm = try stdin.readUntilDelimiterOrEof(&confirm_buffer, '\n');

    if (confirm) |c| {
        if (c[0] == 'y' or c[0] == 'Y') {
            allocator.free(favorites.items[idx]);
            _ = favorites.orderedRemove(idx);
            try saveFavorites(path, favorites, allocator);
            try stdout.print("Favorite removed\n", .{});
        } else {
            try stdout.print("Removal cancelled\n", .{});
        }
    }
}

fn showFavorites(favorites: *ArrayList([]u8), allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    if (favorites.items.len == 0) {
        try stdout.print("No favorites available\n", .{});
        return;
    }

    // Find the longest favorite path for consistent display
    var max_length: usize = 0;
    for (favorites.items) |fav| {
        max_length = @max(max_length, fav.len);
    }

    // Interactive selection menu with j/k navigation
    var current_selection: usize = 0;
    try enableRawMode();
    defer disableRawMode();

    while (true) {
        // Clear screen and redraw menu
        try stdout.print(ANSI_CLEAR_SCREEN, .{});
        try stdout.print("Your favorites:\n\n", .{});

        for (favorites.items, 0..) |fav, i| {
            if (i == current_selection) {
                try stdout.print("{s}>> {d}: {s}", .{ ANSI_INVERT_ON, i + 1, fav });
                // Add padding to make all selections the same width
                for (0..max_length - fav.len) |_| {
                    try stdout.print(" ", .{});
                }
                try stdout.print(" <<{s}\n", .{ANSI_INVERT_OFF});
            } else {
                try stdout.print("   {d}: {s}\n", .{ i + 1, fav });
            }
        }

        try stdout.print("\nUse j/k to navigate, Enter to select, q to cancel\n", .{});

        // Get keypress
        var key_buffer: [1]u8 = undefined;
        _ = try stdin.read(&key_buffer);

        switch (key_buffer[0]) {
            'j' => current_selection = @min(current_selection + 1, favorites.items.len - 1),
            'k' => current_selection = if (current_selection > 0) current_selection - 1 else 0,
            '\r', '\n' => break, // Enter selects
            'q' => return,
            else => {},
        }
    }

    // Process selection for opening
    disableRawMode();

    // Get environment for editor
    const editor = try getEditorName(allocator);
    defer allocator.free(editor);

    try stdout.print("Opening {s} with {s}...\n", .{ favorites.items[current_selection], editor });

    var child = std.process.Child.init(&[_][]const u8{ editor, favorites.items[current_selection] }, allocator);

    child.stdin_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;

    _ = try child.spawnAndWait();
}

pub fn manageFavorites(allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();

    // Get path to favorites file
    const paths = getFavoritesPath(allocator) catch |err| {
        try stdout.print("Error setting up config directory: {any}\n", .{err});
        return;
    };
    defer allocator.free(paths.config_dir);
    defer allocator.free(paths.favorites_path);

    // Load favorites or create empty list
    var favorites_list = ArrayList([]u8).init(allocator);
    defer {
        for (favorites_list.items) |item| {
            allocator.free(item);
        }
        favorites_list.deinit();
    }

    // Load favorites if they exist
    loadFavorites(paths.favorites_path, &favorites_list, allocator) catch |err| {
        if (err != error.FileNotFound) {
            try stdout.print("Error loading favorites: {any}\n", .{err});
            return;
        }
    };

    // Main favorites menu loop with j/k navigation
    const menu_items = [_][]const u8{ "     Show favorites", "      Add favorite", "     Remove favorite", "          Exit" };
    var current_selection: usize = 0;

    while (true) {
        try enableRawMode();
        current_selection = 0;

        while (true) {
            // Clear screen and draw menu
            try stdout.print(ANSI_CLEAR_SCREEN, .{});
            try stdout.print("🌽 cofi - Config File Manager 🌽\n\n", .{});

            for (menu_items, 0..) |item, i| {
                try renderMenuItem(stdout, item, i == current_selection, MENU_WIDTH);
            }

            try stdout.print("\nNavigate: j/k | Select: Enter\n", .{});

            // Get keypress
            var key_buffer: [1]u8 = undefined;
            _ = try std.io.getStdIn().reader().read(&key_buffer);

            switch (key_buffer[0]) {
                'j' => current_selection = @min(current_selection + 1, menu_items.len - 1),
                'k' => current_selection = if (current_selection > 0) current_selection - 1 else 0,
                '\r', '\n' => break, // Enter selects
                'q' => {
                    disableRawMode();
                    return;
                },
                else => {},
            }
        }

        disableRawMode();

        // Process menu selection
        switch (current_selection) {
            0 => try showFavorites(&favorites_list, allocator),
            1 => try addFavorite(&favorites_list, paths.favorites_path, allocator),
            2 => try removeFavorite(&favorites_list, paths.favorites_path, allocator),
            3 => return,
            else => {},
        }
    }
}
