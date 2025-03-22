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

pub const ItemParts = struct {
    name: []const u8,
    path: []const u8,
};

pub const SortField = enum {
    name,
    category,
};

pub const SortOrder = enum {
    ascending,
    descending,
};

pub const Settings = struct {
    editor: ?[]const u8 = null,
    list_visible_items: ?u8 = null,
    sort_field: SortField = .name,
    sort_order: SortOrder = .ascending,

    pub fn deinit(self: *Settings, allocator: std.mem.Allocator) void {
        if (self.editor) |editor| {
            allocator.free(editor);
            self.editor = null;
        }
    }
};

pub fn sortFavoritesList(favorites: *ArrayList(Favorite), settings: Settings) void {
    std.sort.insertion(Favorite, favorites.items, settings, compareFavorites);
}

fn compareFavorites(ctx: Settings, a: Favorite, b: Favorite) bool {
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

pub fn handleError(stdout: std.fs.File.Writer, stdin: std.fs.File.Reader, message: []const u8) !void {
    try stdout.print("\nError: {s}\n", .{message});
    try stdout.print("Press any key to continue...", .{});
    var key_buffer: [1]u8 = undefined;
    _ = try stdin.read(&key_buffer);
}

pub fn handleErrorFmt(stdout: std.fs.File.Writer, stdin: std.fs.File.Reader, allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) !void {
    const msg = try std.fmt.allocPrint(allocator, fmt, args);
    defer allocator.free(msg);
    try handleError(stdout, stdin, msg);
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

pub fn expandTildePath(path: []const u8, allocator: Allocator) ![]const u8 {
    if (path.len == 0 or path[0] != '~') {
        return allocator.dupe(u8, path);
    }

    const home_dir = try getHomeDirectory(allocator);
    defer allocator.free(home_dir);

    if (path.len == 1) {
        return allocator.dupe(u8, home_dir);
    }

    if (path.len > 1 and path[1] == '/') {
        return std.fmt.allocPrint(allocator, "{s}{s}", .{ home_dir, path[1..] });
    }

    return error.UnsupportedTildeExpansion;
}

pub fn initializeFavoritesFile(path: []const u8, _: Allocator) !void {
    if (fs.accessAbsolute(path, .{})) {
        return;
    } else |_| {
        const file = try fs.createFileAbsolute(path, .{});
        defer file.close();

        try file.writeAll("{\n    \"favorites\": []\n}");
    }
}

pub fn loadSettings(allocator: std.mem.Allocator) !Settings {
    var settings = Settings{};

    const paths = try getFavoritesPath(allocator);
    const settings_path = try std.fmt.allocPrint(allocator, "{s}/settings.json", .{paths.config_dir});
    defer allocator.free(settings_path);
    defer allocator.free(paths.config_dir);
    defer allocator.free(paths.favorites_path);

    const file = std.fs.openFileAbsolute(settings_path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            try saveSettings(allocator, settings);
            return settings;
        }
        return err;
    };
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    const parsed = std.json.parseFromSlice(
        Settings,
        allocator,
        content,
        .{},
    ) catch |err| {
        const stdout = std.io.getStdOut().writer();
        try stdout.print("Error parsing settings: {any}\n", .{err});
        try stdout.print("Reinitializing settings file\n", .{});
        try saveSettings(allocator, settings);
        return settings;
    };
    defer parsed.deinit();

    if (parsed.value.editor) |editor| {
        settings.editor = try allocator.dupe(u8, editor);
    }

    settings.list_visible_items = parsed.value.list_visible_items;

    settings.sort_field = parsed.value.sort_field;
    settings.sort_order = parsed.value.sort_order;

    return settings;
}

pub fn saveSettings(allocator: std.mem.Allocator, settings: Settings) !void {
    const paths = try getFavoritesPath(allocator);
    const settings_path = try std.fmt.allocPrint(allocator, "{s}/settings.json", .{paths.config_dir});
    defer allocator.free(settings_path);
    defer allocator.free(paths.config_dir);
    defer allocator.free(paths.favorites_path);

    const file = try std.fs.createFileAbsolute(settings_path, .{});
    defer file.close();

    try std.json.stringify(settings, .{ .whitespace = .indent_4 }, file.writer());
}

pub fn getHomeDirectory(allocator: Allocator) ![]const u8 {
    var env_map = try process.getEnvMap(allocator);
    defer env_map.deinit();

    const home_dir = env_map.get("HOME") orelse {
        return error.HomeNotFound;
    };

    return allocator.dupe(u8, home_dir);
}

pub fn getEditorName(allocator: std.mem.Allocator) ![]const u8 {
    var settings = loadSettings(allocator) catch {
        var env_map = try process.getEnvMap(allocator);
        defer env_map.deinit();

        const editor = env_map.get("EDITOR") orelse "nano";
        return allocator.dupe(u8, editor);
    };
    defer settings.deinit(allocator);

    if (settings.editor) |editor| {
        return allocator.dupe(u8, editor);
    }

    var env_map = try process.getEnvMap(allocator);
    defer env_map.deinit();

    const editor = env_map.get("EDITOR") orelse "nano";
    return allocator.dupe(u8, editor);
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

pub fn getFavoritesPath(allocator: Allocator) !struct { config_dir: []const u8, favorites_path: []const u8 } {
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

pub fn loadFavorites(path: []const u8, allocator: std.mem.Allocator) !ArrayList(Favorite) {
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

pub fn openWithEditor(file_path: []const u8, allocator: Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    const expanded_path = try expandTildePath(file_path, allocator);
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

    const editor = try getEditorName(allocator);
    defer allocator.free(editor);

    try stdout.print("Opening {s} with {s}...\n", .{ expanded_path, editor });

    var child = std.process.Child.init(&[_][]const u8{ editor, expanded_path }, allocator);

    child.stdin_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;

    _ = try child.spawnAndWait();
}
