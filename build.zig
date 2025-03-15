const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create a **Static Library** for Alphazig
    const lib = b.addStaticLibrary(.{
        .name = "alphazig",
        .root_source_file = b.path("src/root.zig"), 
        .target = target,
        .optimize = optimize,
    });

    // Include necessary paths
    lib.addIncludePath(b.path("lib/neco"));
    lib.addIncludePath(b.path("lib/boot_neco"));

    // Add the websocket dependency
    const websocket_dep = b.dependency("websocket", .{
        .target = target,
        .optimize = optimize,
    });
    lib.root_module.addImport("websocket", websocket_dep.module("websocket"));

    // Add Neco C sources
    addNeco(b, lib);

    // Install the library artifact
    b.installArtifact(lib);
}

// Function to add Neco C source files
fn addNeco(b: *std.Build, lib: *std.Build.Step.Compile) void {
    const necoCFlags = &.{
        "-std=c11",
        "-O0",
        "-g3",
        "-Wall",
        "-Wextra",
        "-fstrict-aliasing",
        "-DLLCO_NOUNWIND",
        "-pedantic",
        "-Werror",
        "-fno-omit-frame-pointer",
    };

    lib.addIncludePath(b.path("lib/neco"));
    lib.addIncludePath(b.path("lib/boot_neco"));
    lib.addCSourceFile(.{
        .file = b.path("lib/neco/neco.c"),
        .flags = necoCFlags,
    });
}
