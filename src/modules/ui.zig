const std = @import("std");
const terminal = @import("terminal.zig");
const config = @import("config.zig");
const files = @import("files.zig");
const icons = @import("icons.zig");
const debug = @import("debug.zig");
const Allocator = std.mem.Allocator;

pub const BOX_WIDTH = 59;
pub const MENU_WIDTH = 53;
pub const BORDER_WIDTH = BOX_WIDTH;
pub const TERMINAL_WIDTH = 68;

pub const ANSI_INVERT_ON = "\x1b[7m";
pub const ANSI_INVERT_OFF = "\x1b[27m";
pub const ANSI_BOLD_YELLOW = "\x1b[1;33m";
pub const ANSI_DIM = "\x1b[2m";
pub const ANSI_GRAY = "\x1b[38;5;242m";
pub const ANSI_LIGHT_GRAY = "\x1b[38;5;250m";
pub const ANSI_MEDIUM_GRAY = "\x1b[38;5;245m";
pub const ANSI_BLUE = "\x1b[34m";
pub const ANSI_RED = "\x1b[31m";
pub const ANSI_MAGENTA = "\x1b[35m";
pub const ANSI_GREEN = "\x1b[32m";
pub const ANSI_YELLOW = "\x1b[33m";
pub const ANSI_CYAN = "\x1b[36m";
pub const ANSI_WHITE = "\x1b[37m";
pub const ANSI_FILL_LINE = "\x1b[K";
pub const ANSI_RESET = "\x1b[0m";
pub const ANSI_CLEAR_SCREEN = "\x1b[2J\x1b[H";

pub var LIST_VISIBLE_ITEMS: u8 = config.DEFAULT_LIST_VISIBLE_ITEMS;
pub var current_list_selection: usize = 0;

pub const AVAILABLE_COLORS = [_]struct { name: []const u8, ansi: []const u8 }{
    .{ .name = "Default", .ansi = ANSI_RESET },
    .{ .name = "Red", .ansi = ANSI_RED },
    .{ .name = "Green", .ansi = ANSI_GREEN },
    .{ .name = "Yellow", .ansi = ANSI_YELLOW },
    .{ .name = "Blue", .ansi = ANSI_BLUE },
    .{ .name = "Magenta", .ansi = ANSI_MAGENTA },
    .{ .name = "Cyan", .ansi = ANSI_CYAN },
    .{ .name = "Gray", .ansi = ANSI_GRAY },
};

var output_buffer = std.ArrayList(u8).init(std.heap.page_allocator);

pub fn selectFromMenu(stdout: std.fs.File.Writer, stdin: std.fs.File.Reader, title: []const u8, menu_items: []const []const u8) !?usize {
    var current_selection: usize = 0;

    try terminal.enableRawMode();
    defer terminal.disableRawMode();

    while (true) {
        try renderMenu(stdout, title, menu_items, current_selection);

        var key_buffer: [3]u8 = undefined;
        const bytes_read = try stdin.read(&key_buffer);

        if (bytes_read == 1) {
            switch (key_buffer[0]) {
                'j' => current_selection = @min(current_selection + 1, menu_items.len - 1),
                'k' => current_selection = if (current_selection > 0) current_selection - 1 else 0,
                '\r', '\n' => return current_selection,
                'q' => return null,
                else => {},
            }
        } else if (bytes_read == 3 and key_buffer[0] == 27 and key_buffer[1] == '[') {
            switch (key_buffer[2]) {
                'A' => current_selection = if (current_selection > 0) current_selection - 1 else 0,
                'B' => current_selection = @min(current_selection + 1, menu_items.len - 1),
                else => {},
            }
        }
    }
}

pub fn selectFromList(stdout: std.fs.File.Writer, stdin: std.fs.File.Reader, title: []const u8, items: []const []u8) !?isize {
    if (items.len == 0) {
        try stdout.print("No items available in list: {s}\n", .{title});
        return null;
    }

    // Initialize selection (or keep it within bounds if already set)
    current_list_selection = @min(current_list_selection, items.len - 1);

    try terminal.enableRawMode();
    defer terminal.disableRawMode();

    while (true) {
        try renderList(stdout, title, items, current_list_selection);

        var key_buffer: [3]u8 = undefined;
        const bytes_read = try stdin.read(&key_buffer);

        if (bytes_read == 1) {
            switch (key_buffer[0]) {
                'j' => current_list_selection = @min(current_list_selection + 1, items.len - 1),
                'k' => current_list_selection = if (current_list_selection > 0) current_list_selection - 1 else 0,
                'g' => current_list_selection = 0,
                'G' => current_list_selection = items.len - 1,
                '\r', '\n' => return @intCast(current_list_selection),
                'q' => return null,
                'm' => return -1,
                'a' => return -2, // Add file
                'd' => return -3, // Delete file
                else => {},
            }
        } else if (bytes_read == 3 and key_buffer[0] == 27 and key_buffer[1] == '[') {
            switch (key_buffer[2]) {
                'A' => current_list_selection = if (current_list_selection > 0) current_list_selection - 1 else 0,
                'B' => current_list_selection = @min(current_list_selection + 1, items.len - 1),
                else => {},
            }
        }
    }
}

pub fn selectColor(stdout: std.fs.File.Writer, stdin: std.fs.File.Reader, title: []const u8) !?[]const u8 {
    var color_names = [_][]const u8{undefined} ** AVAILABLE_COLORS.len;

    for (AVAILABLE_COLORS, 0..) |color, i| {
        color_names[i] = color.name;
    }

    var current_selection: usize = 0;

    try terminal.enableRawMode();
    defer terminal.disableRawMode();

    while (true) {
        try renderColorMenu(stdout, title, &color_names, current_selection);

        var key_buffer: [3]u8 = undefined;
        const bytes_read = try stdin.read(&key_buffer);

        if (bytes_read == 1) {
            switch (key_buffer[0]) {
                'j' => current_selection = @min(current_selection + 1, color_names.len - 1),
                'k' => current_selection = if (current_selection > 0) current_selection - 1 else 0,
                '\r', '\n' => return color_names[current_selection],
                'q' => return null,
                else => {},
            }
        } else if (bytes_read == 3 and key_buffer[0] == 27 and key_buffer[1] == '[') {
            switch (key_buffer[2]) {
                'A' => current_selection = if (current_selection > 0) current_selection - 1 else 0,
                'B' => current_selection = @min(current_selection + 1, color_names.len - 1),
                else => {},
            }
        }
    }
}

pub fn selectCategory(stdout: std.fs.File.Writer, stdin: std.fs.File.Reader, categories: []const []const u8) !?[]const u8 {
    if (categories.len == 0) {
        try stdout.print("No categories available\n", .{});
        return null;
    }

    var current_selection: usize = 0;

    try terminal.enableRawMode();
    defer terminal.disableRawMode();

    while (true) {
        try renderCenteredMenu(stdout, "Select Category", categories, current_selection);

        var key_buffer: [3]u8 = undefined;
        const bytes_read = try stdin.read(&key_buffer);

        if (bytes_read == 1) {
            switch (key_buffer[0]) {
                'j' => current_selection = @min(current_selection + 1, categories.len - 1),
                'k' => current_selection = if (current_selection > 0) current_selection - 1 else 0,
                '\r', '\n' => return categories[current_selection],
                'q' => return null,
                else => {},
            }
        } else if (bytes_read == 3 and key_buffer[0] == 27 and key_buffer[1] == '[') {
            switch (key_buffer[2]) {
                'A' => current_selection = if (current_selection > 0) current_selection - 1 else 0,
                'B' => current_selection = @min(current_selection + 1, categories.len - 1),
                else => {},
            }
        }
    }
}

pub fn getAnsiColorFromName(color_name: []const u8) []const u8 {
    for (AVAILABLE_COLORS) |color| {
        if (std.mem.eql(u8, color.name, color_name)) {
            return color.ansi;
        }
    }
    return ANSI_RESET;
}

pub fn initializeListVisibleItems(allocator: Allocator) !void {
    var settings = try config.loadSettings(allocator);
    defer settings.deinit(allocator);

    if (settings.list_visible_items) |count| {
        LIST_VISIBLE_ITEMS = count;
    }
}

pub fn renderBorder(stdout: std.fs.File.Writer, is_top: bool, is_bottom: bool) !void {
    if (is_top) {
        try stdout.print("╭", .{});
        for (0..BORDER_WIDTH - 2) |_| {
            try stdout.print("─", .{});
        }
        try stdout.print("╮\n", .{});
    } else if (is_bottom) {
        try stdout.print("╰", .{});
        for (0..BORDER_WIDTH - 2) |_| {
            try stdout.print("─", .{});
        }
        try stdout.print("╯\n", .{});
    } else {
        try stdout.print("├", .{});
        for (0..BORDER_WIDTH - 2) |_| {
            try stdout.print("─", .{});
        }
        try stdout.print("┤\n", .{});
    }
}

pub fn renderControls(stdout: std.fs.File.Writer, show_quit: bool) !void {
    if (show_quit) {
        try stdout.print("│      {s}[j]{s} Down | {s}[k]{s} Up | {s}[Enter]{s} Select | {s}[q]{s} Quit      │\n", .{
            ANSI_BOLD_YELLOW, ANSI_RESET,
            ANSI_BOLD_YELLOW, ANSI_RESET,
            ANSI_BOLD_YELLOW, ANSI_RESET,
            ANSI_BOLD_YELLOW, ANSI_RESET,
        });
    } else {
        try stdout.print("│      {s}[j]{s} Down | {s}[k]{s} Up | {s}[Enter]{s} Select | {s}[q]{s} Back      │\n", .{
            ANSI_BOLD_YELLOW, ANSI_RESET,
            ANSI_BOLD_YELLOW, ANSI_RESET,
            ANSI_BOLD_YELLOW, ANSI_RESET,
            ANSI_BOLD_YELLOW, ANSI_RESET,
        });
    }
}

pub fn renderMenuItem(stdout: std.fs.File.Writer, item: []const u8, is_selected: bool, width: usize) !void {
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

pub fn renderColorMenuItem(stdout: std.fs.File.Writer, item: []const u8, is_selected: bool, width: usize) !void {
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

pub fn renderColorMenu(stdout: std.fs.File.Writer, title: []const u8, color_names: []const []const u8, current_selection: usize) !void {
    try stdout.print("{s}", .{ANSI_CLEAR_SCREEN});
    try stdout.print("🌽 {s} 🌽\n\n", .{title});

    try renderBorder(stdout, true, false);

    for (color_names, 0..) |color_name, i| {
        const color_code = getAnsiColorFromName(color_name);

        var display_buffer: [256]u8 = undefined;
        const display_name = try std.fmt.bufPrint(&display_buffer, "{s}●{s} {s}", .{ color_code, ANSI_RESET, color_name });

        try renderColorMenuItem(stdout, display_name, i == current_selection, MENU_WIDTH);
    }

    try renderBorder(stdout, false, false);
    try renderControls(stdout, false);
    try renderBorder(stdout, false, true);
}

pub fn renderList(stdout: std.fs.File.Writer, title: []const u8, items: []const []u8, current_selection: usize) !void {
    output_buffer.clearRetainingCapacity();
    var writer = output_buffer.writer();

    try writer.print("{s}\n{s}:\n\n", .{ ANSI_CLEAR_SCREEN, title });

    const allocator = std.heap.page_allocator;
    const home_dir = config.getHomeDirectory(allocator) catch "";
    defer if (home_dir.len > 0) allocator.free(home_dir);

    var settings = config.loadSettings(allocator) catch config.Settings{};
    defer settings.deinit(allocator);

    const visible_range = calculateVisibleRange(items.len, current_selection, LIST_VISIBLE_ITEMS);
    const start_idx = visible_range.start;
    const end_idx = visible_range.end;

    for (start_idx..end_idx) |i| {
        try renderListItem(writer, items[i], i, current_selection, home_dir, settings, allocator);

        if (i < end_idx - 1) {
            const dash = "─";
            const separator_width = TERMINAL_WIDTH - 12;

            try writer.print("  {s}", .{ANSI_GRAY});

            for (0..separator_width) |_| {
                try writer.print("{s}", .{dash});
            }

            try writer.print("{s}\n", .{ANSI_RESET});
        }
    }

    try renderListFooter(writer, current_selection, items.len, start_idx, end_idx);

    try stdout.writeAll(output_buffer.items);
}

fn calculateVisibleRange(total_items: usize, current_selection: usize, visible_items_count: usize) struct { start: usize, end: usize } {
    if (total_items <= visible_items_count) {
        return .{ .start = 0, .end = total_items };
    }

    const half_visible = visible_items_count / 2;
    var start_idx: usize = 0;

    if (current_selection > half_visible) {
        start_idx = current_selection - half_visible;
    }

    var end_idx = start_idx + visible_items_count;
    if (end_idx > total_items) {
        end_idx = total_items;
        start_idx = if (total_items > visible_items_count) total_items - visible_items_count else 0;
    }

    return .{ .start = start_idx, .end = end_idx };
}

fn renderListItem(writer: std.ArrayList(u8).Writer, item: []const u8, index: usize, current_selection: usize, home_dir: []const u8, settings: config.Settings, allocator: Allocator) !void {
    const MAX_LINE_WIDTH: usize = 50;
    const ICON_POS: usize = 6;

    var path_buffer: [1024]u8 = undefined;
    var parts = files.splitPathAndName(item);
    const display_path = if (home_dir.len > 0 and std.mem.startsWith(u8, parts.path, home_dir))
        std.fmt.bufPrint(&path_buffer, "{s}", .{parts.path[home_dir.len..]}) catch parts.path
    else
        parts.path;

    var category: ?[]const u8 = null;
    var clean_name = parts.name;

    var id: u32 = @as(u32, @intCast(index + 1));

    if (std.mem.startsWith(u8, item, "[")) {
        const closing_bracket = std.mem.indexOf(u8, item, "]") orelse 0;
        if (closing_bracket > 1) {
            const id_str = item[1..closing_bracket];
            id = std.fmt.parseInt(u32, id_str, 10) catch id;

            if (closing_bracket + 2 < item.len) {
                const remaining = item[closing_bracket + 2 ..];
                parts.name = remaining;
                clean_name = remaining;
            }
        }
    }

    if (std.mem.indexOf(u8, parts.name, " [")) |bracket_start| {
        if (std.mem.indexOf(u8, parts.name[bracket_start..], "]")) |bracket_end| {
            category = parts.name[bracket_start + 2 .. bracket_start + bracket_end];
            if (bracket_start < parts.name.len) {
                clean_name = parts.name[0..bracket_start];
            }
        }
    }

    const icon = icons.getIconForFile(parts.path);

    var cat_format: []const u8 = "";
    var cat_buffer: [256]u8 = undefined;

    if (category) |cat| {
        cat_format = std.fmt.bufPrint(&cat_buffer, "[{s}]", .{cat}) catch "";
    }

    const cat_len = cat_format.len;

    var truncated_name = clean_name;
    var name_buffer: [256]u8 = undefined;

    const max_name_len = MAX_LINE_WIDTH - ICON_POS - 3 - cat_len - 2;

    if (clean_name.len > max_name_len) {
        truncated_name = std.fmt.bufPrint(&name_buffer, "{s}...", .{clean_name[0 .. max_name_len - 3]}) catch clean_name;
    }

    if (index == current_selection) {
        const highlight_color = ANSI_CYAN;

        try writer.print("  ", .{});

        if (category) |cat| {
            const category_color = config.getCategoryColor(settings, cat, allocator) catch null;
            defer if (category_color) |color| allocator.free(color);
            const color_code = if (category_color) |color| getAnsiColorFromName(color) else ANSI_LIGHT_GRAY;

            var id_str_buffer: [10]u8 = undefined;
            const id_str = std.fmt.bufPrint(&id_str_buffer, "[{d}]", .{id}) catch "[?]";

            const id_padding = if (id_str.len < 5) 5 - id_str.len else 0;
            const total_before_icon = 2 + id_str.len + id_padding;
            const icon_padding = if (ICON_POS > total_before_icon) ICON_POS - total_before_icon else 0;

            try writer.print("{s}{s}{s}", .{ highlight_color, ANSI_INVERT_ON, id_str });

            for (0..id_padding) |_| {
                try writer.print(" ", .{});
            }

            for (0..icon_padding) |_| {
                try writer.print(" ", .{});
            }

            try writer.print("{s} ", .{icon});

            const padding_for_cat = MAX_LINE_WIDTH - (ICON_POS + 1 + truncated_name.len + cat_format.len - 5);

            try writer.print("{s}", .{truncated_name});

            for (0..padding_for_cat) |_| {
                try writer.print(" ", .{});
            }

            try writer.print("{s}[{s}]{s}{s}\n", .{ color_code, cat, highlight_color, ANSI_INVERT_OFF });
        } else {
            var id_str_buffer: [10]u8 = undefined;
            const id_str = std.fmt.bufPrint(&id_str_buffer, "[{d}]", .{id}) catch "[?]";

            const id_padding = if (id_str.len < 5) 5 - id_str.len else 0;
            const total_before_icon = 2 + id_str.len + id_padding;
            const icon_padding = if (ICON_POS > total_before_icon) ICON_POS - total_before_icon else 0;

            try writer.print("{s}{s}{s}", .{ highlight_color, ANSI_INVERT_ON, id_str });

            for (0..id_padding) |_| {
                try writer.print(" ", .{});
            }

            for (0..icon_padding) |_| {
                try writer.print(" ", .{});
            }

            try writer.print("{s} {s}{s}{s}\n", .{ icon, truncated_name, ANSI_INVERT_OFF, ANSI_FILL_LINE });
        }

        var truncated_path = display_path;
        var path_display_buffer: [256]u8 = undefined;

        if (display_path.len > MAX_LINE_WIDTH - 8) {
            truncated_path = std.fmt.bufPrint(&path_display_buffer, "...{s}", .{display_path[display_path.len - (MAX_LINE_WIDTH - 11) .. display_path.len]}) catch display_path;
        }

        try writer.print("    {s}╰─{s}{s}\n", .{ highlight_color, truncated_path, ANSI_RESET });
    } else {
        try writer.print("  ", .{});

        if (category) |cat| {
            const category_color = config.getCategoryColor(settings, cat, allocator) catch null;
            defer if (category_color) |color| allocator.free(color);
            const color_code = if (category_color) |color| getAnsiColorFromName(color) else ANSI_LIGHT_GRAY;

            var id_str_buffer: [10]u8 = undefined;
            const id_str = std.fmt.bufPrint(&id_str_buffer, "[{d}]", .{id}) catch "[?]";

            const id_padding = if (id_str.len < 5) 5 - id_str.len else 0;
            const total_before_icon = 2 + id_str.len + id_padding;
            const icon_padding = if (ICON_POS > total_before_icon) ICON_POS - total_before_icon else 0;

            try writer.print("{s}{s}{s}", .{ ANSI_MEDIUM_GRAY, id_str, ANSI_RESET });

            for (0..id_padding) |_| {
                try writer.print(" ", .{});
            }

            for (0..icon_padding) |_| {
                try writer.print(" ", .{});
            }

            try writer.print("{s} ", .{icon});

            const padding_for_cat = MAX_LINE_WIDTH - (ICON_POS + 1 + truncated_name.len + cat_format.len - 5);

            try writer.print("{s}", .{truncated_name});

            for (0..padding_for_cat) |_| {
                try writer.print(" ", .{});
            }

            try writer.print("{s}[{s}]{s}\n", .{ color_code, cat, ANSI_RESET });
        } else {
            var id_str_buffer: [10]u8 = undefined;
            const id_str = std.fmt.bufPrint(&id_str_buffer, "[{d}]", .{id}) catch "[?]";

            const id_padding = if (id_str.len < 5) 5 - id_str.len else 0;
            const total_before_icon = 2 + id_str.len + id_padding;
            const icon_padding = if (ICON_POS > total_before_icon) ICON_POS - total_before_icon else 0;

            try writer.print("{s}{s}{s}", .{ ANSI_MEDIUM_GRAY, id_str, ANSI_RESET });

            for (0..id_padding) |_| {
                try writer.print(" ", .{});
            }

            for (0..icon_padding) |_| {
                try writer.print(" ", .{});
            }

            try writer.print("{s} {s}\n", .{ icon, truncated_name });
        }

        var truncated_path = display_path;
        var path_display_buffer: [256]u8 = undefined;

        if (display_path.len > MAX_LINE_WIDTH - 8) {
            truncated_path = std.fmt.bufPrint(&path_display_buffer, "...{s}", .{display_path[display_path.len - (MAX_LINE_WIDTH - 11) .. display_path.len]}) catch display_path;
        }

        try writer.print("     {s}~{s}{s}\n", .{ ANSI_LIGHT_GRAY, truncated_path, ANSI_RESET });
    }
}

fn renderListFooter(writer: std.ArrayList(u8).Writer, current_selection: usize, total_items: usize, start_idx: usize, end_idx: usize) !void {
    try writer.print("\n  Item {d} of {d}", .{ current_selection + 1, total_items });

    if (start_idx > 0) {
        try writer.print("  {s}(↑ more above){s}", .{ ANSI_MEDIUM_GRAY, ANSI_RESET });
    }

    if (end_idx < total_items) {
        try writer.print("  {s}(↓ more below){s}", .{ ANSI_MEDIUM_GRAY, ANSI_RESET });
    }

    try writer.print("\n\n", .{});

    try writer.print("╭", .{});
    for (0..BORDER_WIDTH - 2) |_| try writer.print("─", .{});
    try writer.print("╮\n", .{});

    try writer.print("│          {s}[m]{s}enu    {s}[a]{s}dd    {s}[d]{s}elete    {s}[q]{s}uit          │\n", .{
        ANSI_BOLD_YELLOW, ANSI_RESET,
        ANSI_BOLD_YELLOW, ANSI_RESET,
        ANSI_BOLD_YELLOW, ANSI_RESET,
        ANSI_BOLD_YELLOW, ANSI_RESET,
    });

    try writer.print("╰", .{});
    for (0..BORDER_WIDTH - 2) |_| try writer.print("─", .{});
    try writer.print("╯\n", .{});
}

pub fn renderCenteredMenu(stdout: std.fs.File.Writer, title: []const u8, menu_items: []const []const u8, current_selection: usize) !void {
    try stdout.print("{s}", .{ANSI_CLEAR_SCREEN});
    try stdout.print("🌽 {s} 🌽\n\n", .{title});

    try renderBorder(stdout, true, false);

    for (menu_items, 0..) |item, i| {
        try renderMenuItem(stdout, item, i == current_selection, MENU_WIDTH);
    }

    try renderBorder(stdout, false, false);
    try renderControls(stdout, false);
    try renderBorder(stdout, false, true);
}

pub fn renderMenu(stdout: std.fs.File.Writer, title: []const u8, menu_items: []const []const u8, current_selection: usize) !void {
    try stdout.print("{s}", .{ANSI_CLEAR_SCREEN});
    try stdout.print("🌽 {s} 🌽\n\n", .{title});

    try renderBorder(stdout, true, false);

    for (menu_items, 0..) |item, i| {
        try renderMenuItem(stdout, item, i == current_selection, MENU_WIDTH);
    }

    try renderBorder(stdout, false, false);
    try renderControls(stdout, true);
    try renderBorder(stdout, false, true);
}
