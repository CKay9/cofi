const std = @import("std");
const fs = std.fs;
const process = std.process;
const ArrayList = std.ArrayList;

const ANSI_INVERT_ON = "\x1b[7m";
const ANSI_INVERT_OFF = "\x1b[27m";
const ANSI_CLEAR_SCREEN = "\x1b[2J\x1b[H";

const termios = @cImport({
    @cInclude("termios.h");
});

const BOX_WIDTH = 47;
const MENU_WIDTH = 43;
const CONFIG_DIR_NAME = "/.config/cofi";
const FAVORITES_FILE_NAME = "/favorites.txt";

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

    const editor = env_map.get("EDITOR") orelse "nano";
    return allocator.dupe(u8, editor);
}

fn getFavoritesPath(allocator: std.mem.Allocator) !struct { config_dir: []const u8, favorites_path: []const u8 } {
    const home_dir = try getHomeDirectory(allocator);
    defer allocator.free(home_dir);

    const config_dir = try std.fmt.allocPrint(allocator, "{s}{s}", .{ home_dir, CONFIG_DIR_NAME });

    fs.makeDirAbsolute(config_dir) catch |err| {
        if (err != error.PathAlreadyExists) {
            allocator.free(config_dir);
            return err;
        }
    };

    const favorites_path = try std.fmt.allocPrint(allocator, "{s}{s}", .{ config_dir, FAVORITES_FILE_NAME });

    return .{ .config_dir = config_dir, .favorites_path = favorites_path };
}

// Fixed renderMenuItem - selection highlighting is now properly contained
fn renderMenuItem(stdout: std.fs.File.Writer, item: []const u8, is_selected: bool, width: usize) !void {
    const totalPadding = width - item.len;
    const leftPadding = totalPadding / 2;
    const rightPadding = totalPadding - leftPadding;

    var buffer: [BOX_WIDTH]u8 = undefined;
    var i: usize = 0;

    for (0..leftPadding) |_| {
        buffer[i] = ' ';
        i += 1;
    }

    for (item) |char| {
        buffer[i] = char;
        i += 1;
    }

    for (0..rightPadding) |_| {
        buffer[i] = ' ';
        i += 1;
    }

    if (is_selected) {
        try stdout.print("│    {s}{s}{s}    │\n", .{ ANSI_INVERT_ON, buffer[2 .. width - 2], ANSI_INVERT_OFF });
    } else {
        try stdout.print("│    {s}    │\n", .{buffer[2 .. width - 2]});
    }
}

fn addFavorite(favorites: *ArrayList([]u8), path: []const u8, allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    try stdout.print("Enter the path to the configuration file: ", .{});
    var buffer: [1024]u8 = undefined;
    const input = try stdin.readUntilDelimiterOrEof(&buffer, '\n');

    if (input) |file_path| {
        fs.accessAbsolute(file_path, .{}) catch {
            try stdout.print("File does not exist: {s}\n", .{file_path});
            return;
        };

        for (favorites.items) |fav| {
            if (std.mem.eql(u8, fav, file_path)) {
                try stdout.print("File is already in favorites\n", .{});
                return;
            }
        }

        const path_copy = try allocator.dupe(u8, file_path);
        try favorites.append(path_copy);
        try saveFavorites(path, favorites, allocator);
        try stdout.print("Favorite added: {s}\n", .{file_path});
    }
}

// Fixed removeFavorite - selection highlighting is now properly contained
fn removeFavorite(favorites: *ArrayList([]u8), path: []const u8, allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    if (favorites.items.len == 0) {
        try stdout.print("No favorites available to remove\n", .{});
        return;
    }

    var max_length: usize = 0;
    for (favorites.items) |fav| {
        max_length = @max(max_length, fav.len);
    }

    var current_selection: usize = 0;
    try enableRawMode();
    defer disableRawMode();

    while (true) {
        try stdout.print(ANSI_CLEAR_SCREEN, .{});
        try stdout.print("Available favorites:\n\n", .{});

        for (favorites.items, 0..) |fav, i| {
            if (i == current_selection) {
                try stdout.print("  {s}{d}: {s}", .{ ANSI_INVERT_ON, i + 1, fav });
                for (0..max_length - fav.len) |_| {
                    try stdout.print(" ", .{});
                }
                try stdout.print("{s}\n", .{ANSI_INVERT_OFF});
            } else {
                try stdout.print("    {d}: {s}\n", .{ i + 1, fav });
            }
        }

        try stdout.print("\n┌─────────────────────────────────────────────┐\n", .{});
        try stdout.print("│ \x1b[1;33m[j]\x1b[0m Down | \x1b[1;33m[k]\x1b[0m Up | \x1b[1;33m[Enter]\x1b[0m Select | \x1b[1;33m[q]\x1b[0m Back │\n", .{});
        try stdout.print("└─────────────────────────────────────────────┘\n", .{});

        var key_buffer: [1]u8 = undefined;
        _ = try stdin.read(&key_buffer);

        switch (key_buffer[0]) {
            'j' => current_selection = @min(current_selection + 1, favorites.items.len - 1),
            'k' => current_selection = if (current_selection > 0) current_selection - 1 else 0,
            '\r', '\n' => break,
            'q' => return,
            else => {},
        }
    }

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

// Fixed showFavorites - selection highlighting is now properly contained
fn showFavorites(favorites: *ArrayList([]u8), allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    if (favorites.items.len == 0) {
        try stdout.print("No favorites available\n", .{});
        return;
    }

    var max_length: usize = 0;
    for (favorites.items) |fav| {
        max_length = @max(max_length, fav.len);
    }

    var current_selection: usize = 0;
    try enableRawMode();
    defer disableRawMode();

    while (true) {
        try stdout.print(ANSI_CLEAR_SCREEN, .{});
        try stdout.print("Your favorites:\n\n", .{});

        for (favorites.items, 0..) |fav, i| {
            if (i == current_selection) {
                try stdout.print("  {s}{d}: {s}", .{ ANSI_INVERT_ON, i + 1, fav });
                for (0..max_length - fav.len) |_| {
                    try stdout.print(" ", .{});
                }
                try stdout.print("{s}\n", .{ANSI_INVERT_OFF});
            } else {
                try stdout.print("    {d}: {s}\n", .{ i + 1, fav });
            }
        }

        try stdout.print("\n┌─────────────────────────────────────────────┐\n", .{});
        try stdout.print("│ \x1b[1;33m[j]\x1b[0m Down | \x1b[1;33m[k]\x1b[0m Up | \x1b[1;33m[Enter]\x1b[0m Select | \x1b[1;33m[q]\x1b[0m Back │\n", .{});
        try stdout.print("└─────────────────────────────────────────────┘\n", .{});

        var key_buffer: [1]u8 = undefined;
        _ = try stdin.read(&key_buffer);

        switch (key_buffer[0]) {
            'j' => current_selection = @min(current_selection + 1, favorites.items.len - 1),
            'k' => current_selection = if (current_selection > 0) current_selection - 1 else 0,
            '\r', '\n' => break,
            'q' => return,
            else => {},
        }
    }

    disableRawMode();

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

    const paths = getFavoritesPath(allocator) catch |err| {
        try stdout.print("Error setting up config directory: {any}\n", .{err});
        return;
    };
    defer allocator.free(paths.config_dir);
    defer allocator.free(paths.favorites_path);

    var favorites_list = ArrayList([]u8).init(allocator);
    defer {
        for (favorites_list.items) |item| {
            allocator.free(item);
        }
        favorites_list.deinit();
    }

    loadFavorites(paths.favorites_path, &favorites_list, allocator) catch |err| {
        if (err != error.FileNotFound) {
            try stdout.print("Error loading favorites: {any}\n", .{err});
            return;
        }
    };

    const menu_items = [_][]const u8{ "Show favorites", "Add favorite", "Remove favorite", "Exit" };
    var current_selection: usize = 0;

    while (true) {
        try enableRawMode();
        current_selection = 0;

        while (true) {
            try stdout.print(ANSI_CLEAR_SCREEN, .{});
            try stdout.print("🌽 cofi - Config File Manager 🌽\n\n", .{});

            try stdout.print("┌───────────────────────────────────────────────┐\n", .{});

            for (menu_items, 0..) |item, i| {
                try renderMenuItem(stdout, item, i == current_selection, MENU_WIDTH);
            }

            try stdout.print("├───────────────────────────────────────────────┤\n", .{});
            try stdout.print("│ \x1b[1;33m[j]\x1b[0m Down | \x1b[1;33m[k]\x1b[0m Up | \x1b[1;33m[Enter]\x1b[0m Select | \x1b[1;33m[q]\x1b[0m Quit │\n", .{});
            try stdout.print("└───────────────────────────────────────────────┘\n", .{});

            var key_buffer: [1]u8 = undefined;
            _ = try std.io.getStdIn().reader().read(&key_buffer);

            switch (key_buffer[0]) {
                'j' => current_selection = @min(current_selection + 1, menu_items.len - 1),
                'k' => current_selection = if (current_selection > 0) current_selection - 1 else 0,
                '\r', '\n' => break,
                'q' => {
                    disableRawMode();
                    return;
                },
                else => {},
            }
        }

        disableRawMode();

        switch (current_selection) {
            0 => try showFavorites(&favorites_list, allocator),
            1 => try addFavorite(&favorites_list, paths.favorites_path, allocator),
            2 => try removeFavorite(&favorites_list, paths.favorites_path, allocator),
            3 => return,
            else => {},
        }
    }
}
