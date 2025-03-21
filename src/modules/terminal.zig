const std = @import("std");

const termios = @cImport({
    @cInclude("termios.h");
});

const HIDE_CURSOR = "\x1b[?25l";
const SHOW_CURSOR = "\x1b[?25h";

pub fn enableRawMode() !void {
    var raw: termios.termios = undefined;
    _ = termios.tcgetattr(0, &raw);
    raw.c_lflag &= ~@as(c_uint, termios.ECHO | termios.ICANON);
    _ = termios.tcsetattr(0, termios.TCSAFLUSH, &raw);

    const stdout = std.io.getStdOut().writer();
    try stdout.writeAll(HIDE_CURSOR);
}

pub fn disableRawMode() void {
    var raw: termios.termios = undefined;
    _ = termios.tcgetattr(0, &raw);
    raw.c_lflag |= termios.ECHO | termios.ICANON;
    _ = termios.tcsetattr(0, termios.TCSAFLUSH, &raw);

    const stdout = std.io.getStdOut().writer();
    stdout.writeAll(SHOW_CURSOR) catch {};
}
