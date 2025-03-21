const std = @import("std");
const terminal = @import("terminal.zig");
const utils = @import("utils.zig");
const Allocator = std.mem.Allocator;

pub const BOX_WIDTH = 59;
pub const MENU_WIDTH = 53;
pub const BORDER_WIDTH = BOX_WIDTH;

pub const ANSI_INVERT_ON = "\x1b[7m";
pub const ANSI_INVERT_OFF = "\x1b[27m";

pub const ANSI_BOLD_YELLOW = "\x1b[1;33m";
pub const ANSI_DIM = "\x1b[2m";
pub const ANSI_GRAY = "\x1b[38;5;242m";
pub const ANSI_LIGHT_GRAY = "\x1b[38;5;250m";
pub const ANSI_MEDIUM_GRAY = "\x1b[38;5;245m";
pub const ANSI_BLUE = "\x1b[34m";
pub const ANSI_RED = "\x1b[31m";
pub const ANSI_CYAN = "\x1b[36m";
pub const ANSI_FILL_LINE = "\x1b[K";

pub const ANSI_RESET = "\x1b[0m";
pub const ANSI_CLEAR_SCREEN = "\x1b[2J\x1b[H";
pub var LIST_VISIBLE_ITEMS: u8 = 7;

var output_buffer = std.ArrayList(u8).init(std.heap.page_allocator);

pub fn initializeListVisibleItems(allocator: std.mem.Allocator) !void {
    var settings = try utils.loadSettings(allocator);
    defer settings.deinit(allocator);

    if (settings.list_visible_items) |count| {
        LIST_VISIBLE_ITEMS = count;
        const stdout = std.io.getStdOut().writer();
        try stdout.print("Loaded LIST_VISIBLE_ITEMS from settings: {d}\n", .{count});
    }
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

pub fn renderList(stdout: std.fs.File.Writer, title: []const u8, items: []const []u8, current_selection: usize, visible_items_count: usize, is_deletion_menu: bool) !void {
    output_buffer.clearRetainingCapacity();
    var writer = output_buffer.writer();

    try writer.print("{s}", .{ANSI_CLEAR_SCREEN});
    try writer.print("{s}:\n\n", .{title});

    const allocator = std.heap.page_allocator;
    const home_dir = utils.getHomeDirectory(allocator) catch "";
    defer if (home_dir.len > 0) allocator.free(home_dir);

    var path_buffer: [1024]u8 = undefined;

    const half_visible = visible_items_count / 2;
    var start_idx: usize = 0;
    var end_idx: usize = items.len;

    if (items.len > visible_items_count) {
        if (current_selection > half_visible) {
            start_idx = current_selection - half_visible;
        }
        end_idx = start_idx + visible_items_count;
        if (end_idx > items.len) {
            end_idx = items.len;
            start_idx = if (items.len > visible_items_count) items.len - visible_items_count else 0;
        }
    }

    for (start_idx..end_idx) |i| {
        const item = items[i];
        var parts = utils.splitPathAndName(item);
        const display_path = if (home_dir.len > 0 and std.mem.startsWith(u8, parts.path, home_dir))
            std.fmt.bufPrint(&path_buffer, "{s}", .{parts.path[home_dir.len..]}) catch parts.path
        else
            parts.path;

        if (i == current_selection) {
            const highlight_color = if (is_deletion_menu) ANSI_RED else ANSI_CYAN;

            try writer.print("  {s}{s}{d}  {s}{s}{s}\n", .{
                highlight_color, // Red or cyan depending on mode
                ANSI_INVERT_ON,
                i + 1,
                parts.name,
                ANSI_FILL_LINE,
                ANSI_INVERT_OFF,
            });
            try writer.print("    {s}╰─{s}{s}\n", .{ highlight_color, display_path, ANSI_RESET });
        } else {
            try writer.print("  {s}{d} {s} {s}\n", .{ ANSI_MEDIUM_GRAY, i + 1, ANSI_RESET, parts.name });
            try writer.print("     ~{s}{s}{s}\n", .{ ANSI_LIGHT_GRAY, display_path, ANSI_RESET });
        }

        if (i < end_idx - 1) {
            try writer.print("  {s}· · · · · · · · · · · · · · · · · · · · · · · · · · · ·{s}\n", .{ ANSI_GRAY, ANSI_RESET });
        }
    }

    try writer.print("\n", .{});

    try writer.print("  Item {d} of {d}", .{ current_selection + 1, items.len });
    if (start_idx > 0) {
        try writer.print("  {s}(↑ more above){s}", .{ ANSI_MEDIUM_GRAY, ANSI_RESET });
    }
    if (end_idx < items.len) {
        try writer.print("  {s}(↓ more below){s}", .{ ANSI_MEDIUM_GRAY, ANSI_RESET });
    }
    try writer.print("\n\n", .{});

    try writer.print("╭", .{});
    for (0..BORDER_WIDTH - 2) |_| {
        try writer.print("─", .{});
    }
    try writer.print("╮\n", .{});

    try writer.print("│      {s}[j]{s} Down | {s}[k]{s} Up | {s}[Enter]{s} Select | {s}[q]{s} Back      │\n", .{
        ANSI_BOLD_YELLOW, ANSI_RESET,
        ANSI_BOLD_YELLOW, ANSI_RESET,
        ANSI_BOLD_YELLOW, ANSI_RESET,
        ANSI_BOLD_YELLOW, ANSI_RESET,
    });

    try writer.print("╰", .{});
    for (0..BORDER_WIDTH - 2) |_| {
        try writer.print("─", .{});
    }
    try writer.print("╯\n", .{});

    try stdout.writeAll(output_buffer.items);
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

pub fn selectFromList(stdout: std.fs.File.Writer, stdin: std.fs.File.Reader, title: []const u8, items: []const []u8, is_deletion_menu: bool) !?usize {
    if (items.len == 0) {
        try stdout.print("No items available in list: {s}\n", .{title});
        return null;
    }

    var current_selection: usize = 0;

    try terminal.enableRawMode();
    defer terminal.disableRawMode();

    while (true) {
        try renderList(stdout, title, items, current_selection, LIST_VISIBLE_ITEMS, is_deletion_menu);

        var key_buffer: [3]u8 = undefined;
        const bytes_read = try stdin.read(&key_buffer);

        if (bytes_read == 1) {
            switch (key_buffer[0]) {
                'j' => current_selection = @min(current_selection + 1, items.len - 1),
                'k' => current_selection = if (current_selection > 0) current_selection - 1 else 0,
                'g' => current_selection = 0,
                'G' => current_selection = items.len - 1,
                '\r', '\n' => return current_selection,
                'q' => return null,
                else => {},
            }
        } else if (bytes_read == 3 and key_buffer[0] == 27 and key_buffer[1] == '[') {
            switch (key_buffer[2]) {
                'A' => current_selection = if (current_selection > 0) current_selection - 1 else 0,
                'B' => current_selection = @min(current_selection + 1, items.len - 1),
                else => {},
            }
        }
    }
}
