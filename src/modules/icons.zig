const std = @import("std");

pub const FileTypeIcons = struct {
    pub const DEFAULT = " ";
    pub const CONFIG = " ";
    pub const SHELL = " ";
    pub const VIM = " ";
    pub const MARKDOWN = " ";
    pub const JSON = " ";
    pub const YAML = " ";
    pub const TOML = " ";
    pub const GIT = " ";
    pub const HTML = " ";
    pub const CSS = " ";
    pub const JS = " ";
    pub const TS = " ";
    pub const PYTHON = " ";
    pub const RUST = " ";
    pub const C = "󰙱 ";
    pub const CPP = "󰙲 ";
    pub const JAVA = " ";
    pub const LUA = " ";
    pub const GO = " ";
    pub const OCAML = " ";
    pub const DOCKER = "󰡨 ";
    pub const LOG = "󱂅 ";
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
    .{ .ext = ".html", .icon = FileTypeIcons.HTML },
    .{ .ext = ".htm", .icon = FileTypeIcons.HTML },
    .{ .ext = ".css", .icon = FileTypeIcons.CSS },
    .{ .ext = ".js", .icon = FileTypeIcons.JS },
    .{ .ext = ".ts", .icon = FileTypeIcons.TS },
    .{ .ext = ".py", .icon = FileTypeIcons.PYTHON },
    .{ .ext = ".lua", .icon = FileTypeIcons.LUA },
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
    .{ .ext = ".log", .icon = FileTypeIcons.LOG },
};

const FilenameMap = struct {
    name: []const u8,
    icon: []const u8,
};

const FILENAME_MAPPINGS = [_]FilenameMap{
    .{ .name = ".gitconfig", .icon = FileTypeIcons.GIT },
    .{ .name = ".gitignore", .icon = FileTypeIcons.GIT },
    .{ .name = ".bashrc", .icon = FileTypeIcons.SHELL },
    .{ .name = ".zshrc", .icon = FileTypeIcons.SHELL },
    .{ .name = ".profile", .icon = FileTypeIcons.SHELL },
    .{ .name = ".bash_profile", .icon = FileTypeIcons.SHELL },
    .{ .name = ".vimrc", .icon = FileTypeIcons.VIM },
    .{ .name = "init.vim", .icon = FileTypeIcons.VIM },
    .{ .name = "Dockerfile", .icon = FileTypeIcons.DOCKER },
};

pub fn getIconForFile(file_path: []const u8) []const u8 {
    const basename = std.fs.path.basename(file_path);

    for (FILENAME_MAPPINGS) |mapping| {
        if (std.mem.eql(u8, basename, mapping.name)) {
            return mapping.icon;
        }
    }

    const ext = std.fs.path.extension(basename);
    if (ext.len > 0) {
        for (EXTENSION_MAPPINGS) |mapping| {
            if (std.mem.eql(u8, ext, mapping.ext)) {
                return mapping.icon;
            }
        }
    }

    return FileTypeIcons.DEFAULT;
}
