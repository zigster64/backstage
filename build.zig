const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const alphazig_mod = b.addModule("alphazig", .{
        .root_source_file = b.path("src/root.zig"),
    });

    const alphazig_lib = try buildLibAlphaZig(b, .{
        .target = target,
        .optimize = optimize,
    });
    alphazig_mod.linkLibrary(alphazig_lib);

    // Examples
    const examples = .{
        "example",
    };

    inline for (examples) |example| {
        buildExample(b, example, .{
            .target = target,
            .optimize = optimize,
            .alphazig_mod = alphazig_mod,
        });
    }
}

const LibOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.Mode,
};
fn buildLibAlphaZig(b: *std.Build, options: LibOptions) !*std.Build.Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = "alphazig",
        .target = options.target,
        .optimize = options.optimize,
        .link_libc = true,
    });
    lib.addIncludePath(b.path("lib/neco"));
    lib.installHeadersDirectory(b.path("lib/neco"), "neco", .{});

    b.installArtifact(lib);

    // Add Neco C sources
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
    lib.addCSourceFile(.{
        .file = b.path("lib/neco/neco.c"),
        .flags = necoCFlags,
    });

    return lib;
}

const ExampleOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.Mode,
    alphazig_mod: *std.Build.Module,
};
fn buildExample(b: *std.Build, comptime exampleName: []const u8, options: ExampleOptions) void {
    const exe = b.addExecutable(.{
        .name = "alphazig-" ++ exampleName,
        .root_source_file = .{ .cwd_relative = "src/examples/" ++ exampleName ++ ".zig" },
        .target = options.target,
        .optimize = options.optimize,
    });
    const websocket_dep = b.dependency("websocket", .{
        .target = options.target,
        .optimize = options.optimize,
    });
    exe.root_module.addImport("alphazig", options.alphazig_mod);
    exe.root_module.addImport("websocket", websocket_dep.module("websocket"));
    exe.linkSystemLibrary("c");
    addNeco(b, exe, options.alphazig_mod);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    b.step("run-" ++ exampleName, "Run example " ++ exampleName).dependOn(&run_cmd.step);
}

fn addNeco(b: *std.Build, exe: *std.Build.Step.Compile, lib_module: *std.Build.Module) void {
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

    lib_module.addIncludePath(b.path("lib/neco"));
    exe.addCSourceFile(.{
        .file = b.path("lib/neco/neco.c"),
        .flags = necoCFlags,
    });
}
