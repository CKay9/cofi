const std = @import("std");
const process = std.process;
const fs = std.fs;
const ArrayList = std.ArrayList;

// ANSI color codes for editor selection
const ANSI_INVERT_ON = "\x1b[7m";
const ANSI_INVERT_OFF = "\x1b[27m";
const ANSI_CLEAR_SCREEN = "\x1b[2J\x1b[H";

// C imports for terminal control
const termios = @cImport({
    @cInclude("termios.h");
});

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

// Function to scan for common text editors and let user select one
pub fn findEditor(allocator: std.mem.Allocator) ![]const u8 {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    // Define common editors to check for
    const editors = [_][]const u8{ "nvim", "vim", "vi", "nano", "emacs", "micro", "kak", "helix", "mcedit", "joe", "ne" };

    // Find available editors
    var available_editors = ArrayList([]const u8).init(allocator);
    defer available_editors.deinit();

    for (editors) |editor| {
        // Check if editor is in PATH
        if (findExecutableInPath(editor, allocator)) |_| {
            try available_editors.append(editor);
        } else |_| {
            // Editor not found, continue
        }
    }

    // Default to vi if no editors are found
    if (available_editors.items.len == 0) {
        try stdout.print("No common text editors found. Using 'vi' as fallback.\n", .{});
        return allocator.dupe(u8, "vi");
    }

    // Let user select an editor
    try stdout.print(ANSI_CLEAR_SCREEN, .{});
    try stdout.print("No EDITOR defined in your environment.\n", .{});
    try stdout.print("Select a text editor to use:\n\n", .{});

    var current_selection: usize = 0;
    try enableRawMode();
    defer disableRawMode();

    while (true) {
        // Print available editors
        for (available_editors.items, 0..) |editor, i| {
            if (i == current_selection) {
                try stdout.print("{s}>> {s} <<{s}\n", .{ ANSI_INVERT_ON, editor, ANSI_INVERT_OFF });
            } else {
                try stdout.print("   {s}\n", .{editor});
            }
        }

        try stdout.print("\nUse j/k to navigate, Enter to select\n", .{});

        // Get keypress
        var key_buffer: [1]u8 = undefined;
        _ = try stdin.read(&key_buffer);

        switch (key_buffer[0]) {
            'j' => current_selection = @min(current_selection + 1, available_editors.items.len - 1),
            'k' => current_selection = if (current_selection > 0) current_selection - 1 else 0,
            '\r', '\n' => break, // Enter selects
            else => {},
        }

        // Clear screen before redrawing
        try stdout.print(ANSI_CLEAR_SCREEN, .{});
        try stdout.print("No EDITOR defined in your environment.\n", .{});
        try stdout.print("Select a text editor to use:\n\n", .{});
    }

    disableRawMode();

    // Return the selected editor
    return allocator.dupe(u8, available_editors.items[current_selection]);
}

// Helper function to find executable in PATH
fn findExecutableInPath(executable: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    var env_map = try process.getEnvMap(allocator);
    defer env_map.deinit();

    const path_var = env_map.get("PATH") orelse {
        return error.PathNotFound;
    };

    var it = std.mem.split(u8, path_var, ":");
    while (it.next()) |path_dir| {
        // Skip empty PATH components
        if (path_dir.len == 0) continue;

        // Create full path to potential executable
        const full_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ path_dir, executable });
        defer allocator.free(full_path);

        // Check if the file exists and is executable
        fs.accessAbsolute(full_path, .{ .execute = true }) catch |err| {
            if (err == error.FileNotFound) continue;
            if (err == error.PermissionDenied) continue;
            return err;
        };

        // Found executable, return it
        return allocator.dupe(u8, executable);
    }

    return error.ExecutableNotFound;
}
