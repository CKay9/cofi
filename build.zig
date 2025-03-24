const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "cofi",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    b.step("run", "Run the app").dependOn(&run_cmd.step);
}
