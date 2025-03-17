const std = @import("std");

// Basic help text
pub const BASIC_HELP =
    \\🌽 cofi - Config File Manager 🌽
    \\
    \\USAGE:
    \\  cofi                Start the interactive favorites menu
    \\  cofi <number>       Open the specified favorite directly (e.g., cofi 1)
    \\  cofi -v, --version  Display the currently installed version number
    \\  cofi -h, --help     Show this help message
    \\
    \\NAVIGATION:
    \\  j/k                 Navigate up/down in menus
    \\  Enter               Select item
    \\  q                   Quit/cancel current menu
    \\
;

// Function to print help text
pub fn printHelp(writer: std.fs.File.Writer) !void {
    try writer.print("{s}\n", .{BASIC_HELP});
}

// Print error and then help
pub fn printErrorAndHelp(writer: std.fs.File.Writer, err_msg: []const u8) !void {
    try writer.print("Error: {s}\n\n", .{err_msg});
    try printHelp(writer);
}
