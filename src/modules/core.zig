const std = @import("std");
const fs = std.fs;
const process = std.process;
const ArrayList = std.ArrayList;

const terminal = @import("terminal.zig");
const utils = @import("utils.zig");
const ui = @import("ui.zig");

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
        try utils.saveFavorites(path, favorites, allocator);
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

    const selection = try ui.selectFromList(stdout, stdin, "Available favorites", favorites.items);

    if (selection) |idx| {
        try stdout.print("Remove {s}? (y/n): ", .{favorites.items[idx]});

        var confirm_buffer: [10]u8 = undefined;
        const confirm = try stdin.readUntilDelimiterOrEof(&confirm_buffer, '\n');

        if (confirm) |c| {
            if (c[0] == 'y' or c[0] == 'Y') {
                allocator.free(favorites.items[idx]);
                _ = favorites.orderedRemove(idx);
                try utils.saveFavorites(path, favorites, allocator);
                try stdout.print("Favorite removed\n", .{});
            } else {
                try stdout.print("Removal cancelled\n", .{});
            }
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

    const selection = try ui.selectFromList(stdout, stdin, "Your favorites", favorites.items);

    if (selection) |idx| {
        try utils.openWithEditor(favorites.items[idx], allocator);
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

    var favorites_list = ArrayList([]u8).init(allocator);
    defer {
        for (favorites_list.items) |item| {
            allocator.free(item);
        }
        favorites_list.deinit();
    }

    utils.loadFavorites(paths.favorites_path, &favorites_list, allocator) catch |err| {
        if (err != error.FileNotFound) {
            try stdout.print("Error loading favorites: {any}\n", .{err});
            return;
        }
    };

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
