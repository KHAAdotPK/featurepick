const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 1. Create a module from the external file
    const argsv_module = b.createModule(.{
        .root_source_file = b.path("./lib/argsv-zig/src/lib/argsv/argsv.zig"),
    });

    const exe = b.addExecutable(.{
        .name = "featurepick",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // 2. Add the external module to your executable
    exe.root_module.addImport("argsv", argsv_module);

    b.installArtifact(exe);
}
