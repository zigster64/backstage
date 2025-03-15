const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the module
    const alphazig_mod = b.addModule("alphazig", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add the websocket dependency
    const websocket_dep = b.dependency("websocket", .{
        .target = target,
        .optimize = optimize,
    });
    alphazig_mod.addImport("websocket", websocket_dep.module("websocket"));

    // Create a static library
    const lib = b.addStaticLibrary(.{
        .name = "alphazig",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add the module to the library
    lib.root_module.addImport("websocket", websocket_dep.module("websocket"));

    // Add C sources from Neco
    addNeco(b, lib);

    // Install the library
    b.installArtifact(lib);
}

// Function to add Neco C source files and configuration
fn addNeco(b: *std.Build, step: *std.Build.Step.Compile) void {
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

    // Use proper paths
    const neco_dir = b.path("lib/neco");
    const boot_neco_dir = b.path("lib/boot_neco");

    step.addIncludePath(neco_dir);
    step.addIncludePath(boot_neco_dir);

    // Add the C source file
    step.addCSourceFile(.{
        .file = b.path("lib/neco/neco.c"),
        .flags = necoCFlags,
    });

    // Ensure the C library is linked
    step.linkLibC();
}