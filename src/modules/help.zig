const std = @import("std");

pub const BASIC_HELP =
    \\🌽 cofi - Config File Manager 🌽
    \\
    \\USAGE:
    \\  cofi                Start the interactive favorites menu
    \\  cofi <number>       Open the specified favorite directly (e.g., cofi 1)
    \\  cofi -l, --list     Quick view of all files registered
    \\  cofi -v, --version  Display the currently installed version number
    \\  cofi -h, --help     Show this help message
    \\
    \\NAVIGATION:
    \\  j or ↓              Navigate down in menus
    \\  k or ↑              Navigate up in menus
    \\  Enter               Select item
    \\  q                   Quit/cancel current menu
    \\
;

pub fn printHelp(writer: std.fs.File.Writer) !void {
    try writer.print("{s}\n", .{BASIC_HELP});
}

pub fn printErrorAndHelp(writer: std.fs.File.Writer, err_msg: []const u8) !void {
    try writer.print("Error: {s}\n\n", .{err_msg});
    try printHelp(writer);
}
