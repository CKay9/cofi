const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const config = @import("config.zig");

pub const Favorite = struct {
    id: u32,
    path: []const u8,
    name: ?[]const u8 = null,
    category: ?[]const u8 = null,
};

pub const FavoritesData = struct {
    favorites: []Favorite,
};

pub const ItemParts = struct {
    name: []const u8,
    path: []const u8,
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

pub fn loadFavorites(path: []const u8, allocator: Allocator) !ArrayList(Favorite) {
    var favorites = ArrayList(Favorite).init(allocator);

    try initializeFavoritesFile(path, allocator);

    const file = fs.openFileAbsolute(path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            return favorites;
        }
        return err;
    };
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    const stdout = std.io.getStdOut().writer();

    if (content.len == 0 or std.mem.eql(u8, std.mem.trim(u8, content, &std.ascii.whitespace), "")) {
        try initializeFavoritesFile(path, allocator);
        try stdout.print("Initialized empty JSON file\n", .{});
        return favorites;
    }

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

    for (parsed.value.favorites) |fav| {
        try favorites.append(Favorite{
            .id = fav.id,
            .path = try allocator.dupe(u8, fav.path),
            .name = if (fav.name) |name| try allocator.dupe(u8, name) else null,
            .category = if (fav.category) |category| try allocator.dupe(u8, category) else null,
        });
    }

    return favorites;
}

pub fn saveFavorites(path: []const u8, favorites: ArrayList(Favorite), allocator: Allocator) !void {
    const file = try fs.createFileAbsolute(path, .{});
    defer file.close();

    var favs_array = try allocator.alloc(Favorite, favorites.items.len);
    defer allocator.free(favs_array);

    for (favorites.items, 0..) |fav, i| {
        favs_array[i] = fav;
    }

    const root = FavoritesData{
        .favorites = favs_array,
    };

    try std.json.stringify(root, .{ .whitespace = .indent_4 }, file.writer());
}

pub fn getUniqueCategories(favorites: ArrayList(Favorite), allocator: Allocator) !ArrayList([]const u8) {
    var categories = ArrayList([]const u8).init(allocator);

    var seen = std.StringHashMap(void).init(allocator);
    defer seen.deinit();

    for (favorites.items) |fav| {
        if (fav.category) |category| {
            if (!seen.contains(category)) {
                try seen.put(category, {});
                try categories.append(try allocator.dupe(u8, category));
            }
        }
    }

    return categories;
}

pub fn splitPathAndName(item: []const u8) ItemParts {
    if (std.mem.indexOf(u8, item, " - ")) |dash_index| {
        return ItemParts{
            .name = item[0..dash_index],
            .path = item[dash_index + 3 ..],
        };
    }

    return ItemParts{
        .name = item,
        .path = "",
    };
}

pub fn sortFavoritesList(favorites: *ArrayList(Favorite), settings: config.Settings) void {
    std.sort.insertion(Favorite, favorites.items, settings, compareFavorites);
}

fn compareFavorites(ctx: config.Settings, a: Favorite, b: Favorite) bool {
    const asc = ctx.sort_order == .ascending;

    const compareStrings = struct {
        fn compare(str_a: []const u8, str_b: []const u8) bool {
            var buf_a: [256]u8 = undefined;
            var buf_b: [256]u8 = undefined;

            const len_a = @min(str_a.len, buf_a.len);
            const len_b = @min(str_b.len, buf_b.len);

            for (0..len_a) |i| {
                buf_a[i] = std.ascii.toLower(str_a[i]);
            }

            for (0..len_b) |i| {
                buf_b[i] = std.ascii.toLower(str_b[i]);
            }

            return std.mem.lessThan(u8, buf_a[0..len_a], buf_b[0..len_b]);
        }
    }.compare;

    switch (ctx.sort_field) {
        .name => {
            const a_name = if (a.name) |name| name else a.path;
            const b_name = if (b.name) |name| name else b.path;

            const result = compareStrings(a_name, b_name);
            return if (asc) result else !result;
        },
        .category => {
            const a_cat = if (a.category) |cat| cat else "";
            const b_cat = if (b.category) |cat| cat else "";

            if (std.ascii.eqlIgnoreCase(a_cat, b_cat)) {
                const a_name = if (a.name) |name| name else a.path;
                const b_name = if (b.name) |name| name else b.path;

                const result = compareStrings(a_name, b_name);
                return if (asc) result else !result;
            }

            const result = compareStrings(a_cat, b_cat);
            return if (asc) result else !result;
        },
    }
}

pub fn openWithEditor(file_path: []const u8, allocator: Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    const expanded_path = try config.expandTildePath(file_path, allocator);
    defer allocator.free(expanded_path);

    const file_exists = blk: {
        var file = fs.openFileAbsolute(expanded_path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                break :blk false;
            } else {
                try handleError(stdout, stdin, try std.fmt.allocPrint(allocator, "Error accessing file: {}", .{err}));
                return;
            }
        };
        defer file.close();
        break :blk true;
    };

    if (!file_exists) {
        try handleError(stdout, stdin, try std.fmt.allocPrint(allocator, "File '{s}' no longer exists or is not accessible.", .{expanded_path}));
        return;
    }

    const editor = try config.getEditorName(allocator);
    defer allocator.free(editor);

    try stdout.print("Opening {s} with {s}...\n", .{ expanded_path, editor });

    var child = std.process.Child.init(&[_][]const u8{ editor, expanded_path }, allocator);

    child.stdin_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;

    _ = try child.spawnAndWait();
}

// Error handling utility functions
pub fn handleError(stdout: std.fs.File.Writer, stdin: std.fs.File.Reader, message: []const u8) !void {
    try stdout.print("\nError: {s}\n", .{message});
    try stdout.print("Press any key to continue...", .{});
    var key_buffer: [1]u8 = undefined;
    _ = try stdin.read(&key_buffer);
}

pub fn handleErrorFmt(stdout: std.fs.File.Writer, stdin: std.fs.File.Reader, allocator: Allocator, comptime fmt: []const u8, args: anytype) !void {
    const msg = try std.fmt.allocPrint(allocator, fmt, args);
    defer allocator.free(msg);
    try handleError(stdout, stdin, msg);
}
