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

    // Add the websocket dependency to the module
    const websocket_dep = b.dependency("websocket", .{
        .target = target,
        .optimize = optimize,
    });
    alphazig_mod.addImport("websocket", websocket_dep.module("websocket"));

    // Create a static library for Alphazig
    const lib = b.addStaticLibrary(.{
        .name = "alphazig",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add the module to the library
    lib.root_module.addImport("websocket", websocket_dep.module("websocket"));

    // Add Neco C sources and configuration
    addNeco(b, lib);

    // Install the library artifact
    b.installArtifact(lib);

    // Create a test step
    const main_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    addNeco(b, main_tests);
    main_tests.root_module.addImport("websocket", websocket_dep.module("websocket"));

    const run_main_tests = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);
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

    // Use proper paths that will work when used as a dependency
    const neco_dir = b.path("lib/neco");

    step.addIncludePath(neco_dir);

    // Add the C source file
    step.addCSourceFile(.{
        .file = b.path("lib/neco/neco.c"),
        .flags = necoCFlags,
    });

    // Make sure the C library is properly linked
    step.linkLibC();
}

// This function allows other projects to use your library
pub fn addAlphaZigPackage(b: *std.Build, step: *std.Build.Step.Compile) void {
    const target = step.root_module.resolved_target.?;
    const optimize = step.root_module.optimize orelse .Debug;

    // Get the module
    const alphazig_dep = b.dependency("alphazig", .{
        .target = target,
        .optimize = optimize,
    });

    // Add the module to the step
    step.root_module.addImport("alphazig", alphazig_dep.module("alphazig"));

    // Add the Neco C library with paths relative to the dependency
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

    // Get the path to the neco directory in the dependency
    const neco_dir = alphazig_dep.path("lib/neco");

    step.addIncludePath(neco_dir);

    // Add the C source file from the dependency
    step.addCSourceFile(.{
        .file = alphazig_dep.path("lib/neco/neco.c"),
        .flags = necoCFlags,
    });

    // Make sure the C library is properly linked
    step.linkLibC();
}
