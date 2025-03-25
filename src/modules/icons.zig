const std = @import("std");

pub const FileTypeIcons = struct {
    pub const DEFAULT = " ";
    pub const CONFIG = " ";
    pub const TEXT = " ";
    pub const CODE = " ";
    pub const SHELL = " ";
    pub const VIM = " ";
    pub const MARKDOWN = " ";
    pub const JSON = " ";
    pub const YAML = " ";
    pub const TOML = " ";
    pub const GIT = " ";
    pub const HTML = " ";
    pub const CSS = " ";
    pub const JS = " ";
    pub const TS = "ﯤ ";
    pub const PYTHON = " ";
    pub const RUST = " ";
    pub const C = " ";
    pub const CPP = " ";
    pub const JAVA = " ";
    pub const GO = " ";
    pub const DOCKER = " ";
    pub const LOG = " ";
    pub const LOCK = " ";
    pub const INI = " ";
    pub const ENV = " ";
    pub const ZIG = " ";
};

const ExtensionMap = struct {
    ext: []const u8,
    icon: []const u8,
};

const EXTENSION_MAPPINGS = [_]ExtensionMap{
    .{ .ext = ".json", .icon = FileTypeIcons.JSON },
    .{ .ext = ".yml", .icon = FileTypeIcons.YAML },
    .{ .ext = ".yaml", .icon = FileTypeIcons.YAML },
    .{ .ext = ".toml", .icon = FileTypeIcons.TOML },
    .{ .ext = ".md", .icon = FileTypeIcons.MARKDOWN },
    .{ .ext = ".txt", .icon = FileTypeIcons.TEXT },
    .{ .ext = ".html", .icon = FileTypeIcons.HTML },
    .{ .ext = ".htm", .icon = FileTypeIcons.HTML },
    .{ .ext = ".css", .icon = FileTypeIcons.CSS },
    .{ .ext = ".js", .icon = FileTypeIcons.JS },
    .{ .ext = ".ts", .icon = FileTypeIcons.TS },
    .{ .ext = ".py", .icon = FileTypeIcons.PYTHON },
    .{ .ext = ".rs", .icon = FileTypeIcons.RUST },
    .{ .ext = ".zig", .icon = FileTypeIcons.ZIG },
    .{ .ext = ".c", .icon = FileTypeIcons.C },
    .{ .ext = ".h", .icon = FileTypeIcons.C },
    .{ .ext = ".cpp", .icon = FileTypeIcons.CPP },
    .{ .ext = ".hpp", .icon = FileTypeIcons.CPP },
    .{ .ext = ".cc", .icon = FileTypeIcons.CPP },
    .{ .ext = ".java", .icon = FileTypeIcons.JAVA },
    .{ .ext = ".go", .icon = FileTypeIcons.GO },
    .{ .ext = ".sh", .icon = FileTypeIcons.SHELL },
    .{ .ext = ".bash", .icon = FileTypeIcons.SHELL },
    .{ .ext = ".zsh", .icon = FileTypeIcons.SHELL },
    .{ .ext = ".conf", .icon = FileTypeIcons.CONFIG },
    .{ .ext = ".config", .icon = FileTypeIcons.CONFIG },
    .{ .ext = ".ini", .icon = FileTypeIcons.INI },
    .{ .ext = ".env", .icon = FileTypeIcons.ENV },
    .{ .ext = ".log", .icon = FileTypeIcons.LOG },
    .{ .ext = ".lock", .icon = FileTypeIcons.LOCK },
};

// Get the appropriate icon based ONLY on file extension
pub fn getIconForFile(file_path: []const u8) []const u8 {
    const ext = std.fs.path.extension(file_path);

    if (ext.len > 0) {
        for (EXTENSION_MAPPINGS) |mapping| {
            if (std.mem.eql(u8, ext, mapping.ext)) {
                return mapping.icon;
            }
        }
    }

    // Default case
    return FileTypeIcons.DEFAULT;
}
