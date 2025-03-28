const std = @import("std");
const process = std.process;
const fs = std.fs;
const core = @import("modules/core.zig");
const config = @import("modules/config.zig");
const files = @import("modules/files.zig");
const help = @import("modules/help.zig");
const ui = @import("modules/ui.zig");
const icons = @import("modules/icons.zig");
const debug = @import("modules/debug.zig");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Initialize debug logger
    try debug.init();
    defer debug.deinit();

    // Test icons display - log to file
    debug.log("=== Icon Display Test ===", .{});

    // Test with common file types
    const test_files = [_][]const u8{
        "/home/user/config.json",
        "/home/user/script.py",
        "/home/user/document.md",
        "/home/user/code.zig",
        "/home/user/.bashrc",
    };

    for (test_files) |file| {
        const icon = icons.getIconForFile(file);
        const ext = std.fs.path.extension(file);
        debug.log("File: {s}, Extension: {s}, Icon: {s}", .{ file, ext, icon });
    }

    try ui.initializeListVisibleItems(allocator);

    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    const args = try process.argsAlloc(allocator);
    defer process.argsFree(allocator, args);

    if (args.len > 1) {
        const arg = args[1];

        if (arg.len > 0 and arg[0] == '-' and (arg.len == 1 or !std.ascii.isDigit(arg[1]))) {
            if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
                try help.printHelp(stdout);
                return;
            } else if (std.mem.eql(u8, arg, "-l") or std.mem.eql(u8, arg, "--list")) {
                try listFavorites(allocator);
                return;
            } else if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--version")) {
                try help.printVersion(stdout);
                return;
            } else {
                const error_msg = try std.fmt.allocPrint(allocator, "Unknown flag '{s}'", .{arg});
                defer allocator.free(error_msg);
                try help.printErrorAndHelp(stdout, error_msg);
                return;
            }
        } else {
            const id_str = if (arg.len > 0 and arg[0] == '-') arg[1..] else arg;

            const id = std.fmt.parseInt(u32, id_str, 10) catch {
                const error_msg = try std.fmt.allocPrint(allocator, "Invalid argument '{s}'. Expected a number.", .{arg});
                defer allocator.free(error_msg);
                try help.printErrorAndHelp(stdout, error_msg);
                try files.handleError(stdout, stdin, "");
                return;
            };

            try openSpecificFavorite(allocator, id);
        }
    } else {
        try core.manageFavorites(allocator);
    }
}

fn listFavorites(allocator: Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    const paths = try config.getConfigPaths(allocator);
    defer {
        allocator.free(paths.config_dir);
        allocator.free(paths.favorites_path);
        allocator.free(paths.settings_path);
    }

    try files.initializeFavoritesFile(paths.favorites_path, allocator);

    var favorites_list = try files.loadFavorites(paths.favorites_path, allocator);
    defer {
        for (favorites_list.items) |item| {
            if (item.name) |name| allocator.free(name);
            if (item.category) |category| allocator.free(category);
            allocator.free(item.path);
        }
        favorites_list.deinit();
    }

    if (favorites_list.items.len == 0) {
        try files.handleError(stdout, stdin, "No favorites found. Add some favorites first.");
        return;
    }

    try stdout.print("🌽 cofi - Favorites List 🌽\n\n", .{});

    for (favorites_list.items) |fav| {
        const icon = icons.getIconForFile(fav.path);
        debug.log("List view - Path: {s}, Icon: {s}", .{ fav.path, icon });

        if (fav.name) |name| {
            if (fav.category) |category| {
                try stdout.print("[{d}] {s}{s} [{s}]\n", .{ fav.id, icon, name, category });
            } else {
                try stdout.print("[{d}] {s}{s}\n", .{ fav.id, icon, name });
            }
        } else {
            const basename = std.fs.path.basename(fav.path);
            if (fav.category) |category| {
                try stdout.print("[{d}] {s}{s} [{s}]\n", .{ fav.id, icon, basename, category });
            } else {
                try stdout.print("[{d}] {s}{s}\n", .{ fav.id, icon, basename });
            }
        }
    }
}

fn openSpecificFavorite(allocator: Allocator, id: u32) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    const paths = try config.getConfigPaths(allocator);
    defer {
        allocator.free(paths.config_dir);
        allocator.free(paths.favorites_path);
        allocator.free(paths.settings_path);
    }

    try files.initializeFavoritesFile(paths.favorites_path, allocator);

    var favorites_list = try files.loadFavorites(paths.favorites_path, allocator);
    defer {
        for (favorites_list.items) |item| {
            if (item.name) |name| allocator.free(name);
            if (item.category) |category| allocator.free(category);
            allocator.free(item.path);
        }
        favorites_list.deinit();
    }

    if (favorites_list.items.len == 0) {
        try files.handleError(stdout, stdin, "No favorites found. Add some favorites first.");
        return;
    }

    for (favorites_list.items) |fav| {
        if (fav.id == id) {
            debug.log("Opening favorite ID {d} with path {s}", .{ id, fav.path });
            try files.openWithEditor(fav.path, allocator);
            return;
        }
    }

    try files.handleError(stdout, stdin, try std.fmt.allocPrint(allocator, "No favorite found with ID {d}", .{id}));
}
