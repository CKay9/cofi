const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;
const process = std.process;

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

        @memcpy(new_colors[0..colors.len], colors);

        new_colors[colors.len] = CategoryColor{
            .name = try allocator.dupe(u8, category),
            .color = try allocator.dupe(u8, color),
        };

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
            colors[idx].deinit(allocator);

            if (colors.len == 1) {
                allocator.free(colors);
                settings.category_colors = null;
                return;
            }

            var new_colors = try allocator.alloc(CategoryColor, colors.len - 1);

            if (idx > 0) {
                @memcpy(new_colors[0..idx], colors[0..idx]);
            }

            if (idx < colors.len - 1) {
                @memcpy(new_colors[idx..], colors[idx + 1 ..]);
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
