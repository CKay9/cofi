const std = @import("std");
const terminal = @import("terminal.zig");
const Allocator = std.mem.Allocator;

pub const BOX_WIDTH = 49;
pub const MENU_WIDTH = 43;
pub const BORDER_WIDTH = BOX_WIDTH; // Use the same width for all borders

pub const ANSI_INVERT_ON = "\x1b[7m";
pub const ANSI_INVERT_OFF = "\x1b[27m";
pub const ANSI_BOLD_YELLOW = "\x1b[1;33m";
pub const ANSI_RESET = "\x1b[0m";
pub const ANSI_CLEAR_SCREEN = "\x1b[2J\x1b[H";

pub fn renderBorder(stdout: std.fs.File.Writer, is_top: bool, is_bottom: bool) !void {
    if (is_top) {
        try stdout.print("┌", .{});
        for (0..BORDER_WIDTH - 2) |_| {
            try stdout.print("─", .{});
        }
        try stdout.print("┐\n", .{});
    } else if (is_bottom) {
        try stdout.print("└", .{});
        for (0..BORDER_WIDTH - 2) |_| {
            try stdout.print("─", .{});
        }
        try stdout.print("┘\n", .{});
    } else {
        try stdout.print("├", .{});
        for (0..BORDER_WIDTH - 2) |_| {
            try stdout.print("─", .{});
        }
        try stdout.print("┤\n", .{});
    }
}

// Unified function to render controls
pub fn renderControls(stdout: std.fs.File.Writer, show_quit: bool) !void {
    if (show_quit) {
        try stdout.print("│ {s}[j]{s} Down | {s}[k]{s} Up | {s}[Enter]{s} Select | {s}[q]{s} Quit │\n", .{
            ANSI_BOLD_YELLOW, ANSI_RESET,
            ANSI_BOLD_YELLOW, ANSI_RESET,
            ANSI_BOLD_YELLOW, ANSI_RESET,
            ANSI_BOLD_YELLOW, ANSI_RESET,
        });
    } else {
        try stdout.print("│ {s}[j]{s} Down | {s}[k]{s} Up | {s}[Enter]{s} Select | {s}[q]{s} Back │\n", .{
            ANSI_BOLD_YELLOW, ANSI_RESET,
            ANSI_BOLD_YELLOW, ANSI_RESET,
            ANSI_BOLD_YELLOW, ANSI_RESET,
            ANSI_BOLD_YELLOW, ANSI_RESET,
        });
    }
}

// Updated renderMenuItem to ensure consistent width
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

pub fn renderList(stdout: std.fs.File.Writer, title: []const u8, items: []const []u8, current_selection: usize) !void {
    try stdout.print("{s}", .{ANSI_CLEAR_SCREEN});
    try stdout.print("{s}:\n\n", .{title});

    var max_length: usize = 0;
    for (items) |item| {
        max_length = @max(max_length, item.len);
    }

    for (items, 0..) |item, i| {
        if (i == current_selection) {
            try stdout.print("  {s}{d}: {s}", .{ ANSI_INVERT_ON, i + 1, item });
            for (0..max_length - item.len) |_| {
                try stdout.print(" ", .{});
            }
            try stdout.print("{s}\n", .{ANSI_INVERT_OFF});
        } else {
            try stdout.print("    {d}: {s}\n", .{ i + 1, item });
        }
    }

    try stdout.print("\n", .{});
    try renderBorder(stdout, true, false);
    try renderControls(stdout, false);
    try renderBorder(stdout, false, true);
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

        var key_buffer: [1]u8 = undefined;
        _ = try stdin.read(&key_buffer);

        switch (key_buffer[0]) {
            'j' => current_selection = @min(current_selection + 1, categories.len - 1),
            'k' => current_selection = if (current_selection > 0) current_selection - 1 else 0,
            '\r', '\n' => return categories[current_selection],
            'q' => return null,
            else => {},
        }
    }
}

pub fn selectFromMenu(stdout: std.fs.File.Writer, stdin: std.fs.File.Reader, title: []const u8, menu_items: []const []const u8) !?usize {
    var current_selection: usize = 0;

    try terminal.enableRawMode();
    defer terminal.disableRawMode();

    while (true) {
        try renderMenu(stdout, title, menu_items, current_selection);

        var key_buffer: [1]u8 = undefined;
        _ = try stdin.read(&key_buffer);

        switch (key_buffer[0]) {
            'j' => current_selection = @min(current_selection + 1, menu_items.len - 1),
            'k' => current_selection = if (current_selection > 0) current_selection - 1 else 0,
            '\r', '\n' => return current_selection,
            'q' => return null,
            else => {},
        }
    }
}

pub fn selectFromList(stdout: std.fs.File.Writer, stdin: std.fs.File.Reader, title: []const u8, items: []const []u8) !?usize {
    if (items.len == 0) {
        try stdout.print("No items available in list: {s}\n", .{title});
        return null;
    }

    var current_selection: usize = 0;

    try terminal.enableRawMode();
    defer terminal.disableRawMode();

    while (true) {
        try renderList(stdout, title, items, current_selection);

        var key_buffer: [1]u8 = undefined;
        _ = try stdin.read(&key_buffer);

        switch (key_buffer[0]) {
            'j' => current_selection = @min(current_selection + 1, items.len - 1),
            'k' => current_selection = if (current_selection > 0) current_selection - 1 else 0,
            '\r', '\n' => return current_selection,
            'q' => return null,
            else => {},
        }
    }
}
