const std = @import("std");
const fs = std.fs;
const process = std.process;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const CONFIG_DIR_NAME = "/.config/cofi";
pub const FAVORITES_FILE_NAME = "/favorites.json";
pub const SETTINGS_FILE_NAME = "/settings.json";

pub const DEFAULT_LIST_VISIBLE_ITEMS: u8 = 7;
pub const DEFAULT_EDITOR = "nano";

pub const SortField = enum {
    name,
    category,
};

pub const SortOrder = enum {
    ascending,
    descending,
};

pub const CategoryColor = struct {
    name: []const u8,
    color: []const u8,

    pub fn deinit(self: *CategoryColor, allocator: Allocator) void {
        allocator.free(self.name);
        allocator.free(self.color);
    }
};

pub const Settings = struct {
    editor: ?[]const u8 = null,
    list_visible_items: ?u8 = null,
    sort_field: SortField = .name,
    sort_order: SortOrder = .ascending,
    category_colors: ?[]CategoryColor = null,

    pub fn deinit(self: *Settings, allocator: Allocator) void {
        if (self.editor) |editor| {
            allocator.free(editor);
            self.editor = null;
        }

        if (self.category_colors) |colors| {
            for (colors) |*color| {
                color.deinit(allocator);
            }
            allocator.free(colors);
            self.category_colors = null;
        }
    }
};

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

pub fn getConfigPaths(allocator: Allocator) !struct { config_dir: []const u8, favorites_path: []const u8, settings_path: []const u8 } {
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
    const settings_path = try std.fmt.allocPrint(allocator, "{s}{s}", .{ config_dir, SETTINGS_FILE_NAME });

    return .{
        .config_dir = config_dir,
        .favorites_path = favorites_path,
        .settings_path = settings_path,
    };
}

pub fn loadSettings(allocator: Allocator) !Settings {
    var settings = Settings{};

    const paths = try getConfigPaths(allocator);
    defer {
        allocator.free(paths.config_dir);
        allocator.free(paths.favorites_path);
        allocator.free(paths.settings_path);
    }

    const file = std.fs.openFileAbsolute(paths.settings_path, .{}) catch |err| {
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

    if (parsed.value.category_colors) |colors| {
        const new_colors = try allocator.alloc(CategoryColor, colors.len);

        for (colors, 0..) |color, i| {
            new_colors[i] = CategoryColor{
                .name = try allocator.dupe(u8, color.name),
                .color = try allocator.dupe(u8, color.color),
            };
        }

        settings.category_colors = new_colors;
    }

    return settings;
}

pub fn saveSettings(allocator: Allocator, settings: Settings) !void {
    const paths = try getConfigPaths(allocator);
    defer {
        allocator.free(paths.config_dir);
        allocator.free(paths.favorites_path);
        allocator.free(paths.settings_path);
    }

    const file = try std.fs.createFileAbsolute(paths.settings_path, .{});
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

pub fn getEditorName(allocator: Allocator) ![]const u8 {
    var settings = loadSettings(allocator) catch {
        var env_map = try process.getEnvMap(allocator);
        defer env_map.deinit();

        const editor = env_map.get("EDITOR") orelse DEFAULT_EDITOR;
        return allocator.dupe(u8, editor);
    };
    defer settings.deinit(allocator);

    if (settings.editor) |editor| {
        return allocator.dupe(u8, editor);
    }

    var env_map = try process.getEnvMap(allocator);
    defer env_map.deinit();

    const editor = env_map.get("EDITOR") orelse DEFAULT_EDITOR;
    return allocator.dupe(u8, editor);
}

pub fn setCategoryColor(settings: *Settings, category: []const u8, color: []const u8, allocator: Allocator) !void {
    if (settings.category_colors) |colors| {
        for (colors) |*cat_color| {
            if (std.mem.eql(u8, cat_color.name, category)) {
                allocator.free(cat_color.color);
                cat_color.color = try allocator.dupe(u8, color);
                return;
            }
        }

        var new_colors = try allocator.alloc(CategoryColor, colors.len + 1);

        for (colors, 0..) |cat_color, i| {
            new_colors[i] = CategoryColor{
                .name = try allocator.dupe(u8, cat_color.name),
                .color = try allocator.dupe(u8, cat_color.color),
            };
        }

        new_colors[colors.len] = CategoryColor{
            .name = try allocator.dupe(u8, category),
            .color = try allocator.dupe(u8, color),
        };

        for (colors) |*cat_color| {
            allocator.free(cat_color.name);
            allocator.free(cat_color.color);
        }
        allocator.free(colors);

        settings.category_colors = new_colors;
    } else {
        var new_colors = try allocator.alloc(CategoryColor, 1);
        new_colors[0] = CategoryColor{
            .name = try allocator.dupe(u8, category),
            .color = try allocator.dupe(u8, color),
        };
        settings.category_colors = new_colors;
    }
}

pub fn removeCategoryColor(settings: *Settings, category: []const u8, allocator: Allocator) !void {
    if (settings.category_colors) |colors| {
        var found_idx: ?usize = null;

        for (colors, 0..) |color, i| {
            if (std.mem.eql(u8, color.name, category)) {
                found_idx = i;
                break;
            }
        }

        if (found_idx) |idx| {
            allocator.free(colors[idx].name);
            allocator.free(colors[idx].color);

            if (colors.len == 1) {
                allocator.free(colors);
                settings.category_colors = null;
                return;
            }

            var new_colors = try allocator.alloc(CategoryColor, colors.len - 1);

            var dest_idx: usize = 0;
            for (0..colors.len) |i| {
                if (i != idx) {
                    new_colors[dest_idx] = CategoryColor{
                        .name = try allocator.dupe(u8, colors[i].name),
                        .color = try allocator.dupe(u8, colors[i].color),
                    };
                    dest_idx += 1;
                }
            }

            for (colors, 0..) |color, i| {
                if (i != idx) {
                    allocator.free(color.name);
                    allocator.free(color.color);
                }
            }
            allocator.free(colors);

            settings.category_colors = new_colors;
        }
    }
}

pub fn getCategoryColor(settings: Settings, category: []const u8, allocator: Allocator) !?[]const u8 {
    if (settings.category_colors) |colors| {
        for (colors) |color| {
            if (std.mem.eql(u8, color.name, category)) {
                return try allocator.dupe(u8, color.color);
            }
        }
    }
    return null;
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

// Added from utils.zig
pub fn sortFavoritesList(favorites: *ArrayList(Favorite), settings: Settings) void {
    std.sort.insertion(Favorite, favorites.items, settings, compareFavorites);
}

// Added from utils.zig
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

// Added from utils.zig
pub fn handleError(stdout: std.fs.File.Writer, stdin: std.fs.File.Reader, message: []const u8) !void {
    try stdout.print("\nError: {s}\n", .{message});
    try stdout.print("Press any key to continue...", .{});
    var key_buffer: [1]u8 = undefined;
    _ = try stdin.read(&key_buffer);
}

// Added from utils.zig
pub fn handleErrorFmt(stdout: std.fs.File.Writer, stdin: std.fs.File.Reader, allocator: Allocator, comptime fmt: []const u8, args: anytype) !void {
    const msg = try std.fmt.allocPrint(allocator, fmt, args);
    defer allocator.free(msg);
    try handleError(stdout, stdin, msg);
}

// Added from utils.zig
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

// Added from utils.zig
pub fn initializeFavoritesFile(path: []const u8, _: Allocator) !void {
    if (fs.accessAbsolute(path, .{})) {
        return;
    } else |_| {
        const file = try fs.createFileAbsolute(path, .{});
        defer file.close();

        try file.writeAll("{\n    \"favorites\": []\n}");
    }
}

// Added from utils.zig
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

// Added from utils.zig
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

// Added from utils.zig
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

// Added from utils.zig
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
