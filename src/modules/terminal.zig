const std = @import("std");

const termios = @cImport({
    @cInclude("termios.h");
});

pub fn enableRawMode() !void {
    var raw: termios.termios = undefined;
    _ = termios.tcgetattr(0, &raw);
    raw.c_lflag &= ~@as(c_uint, termios.ECHO | termios.ICANON);
    _ = termios.tcsetattr(0, termios.TCSAFLUSH, &raw);
}

pub fn disableRawMode() void {
    var raw: termios.termios = undefined;
    _ = termios.tcgetattr(0, &raw);
    raw.c_lflag |= termios.ECHO | termios.ICANON;
    _ = termios.tcsetattr(0, termios.TCSAFLUSH, &raw);
}
