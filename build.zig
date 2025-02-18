const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "alphazig",
        .root_source_file = .{ .cwd_relative = "src/root.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(lib);

    const lib_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/root.zig" },
    });

    // Examples
    const examples = .{
        "send",
        "broadcast",
    };

    inline for (examples) |example| {
        buildExample(b, example, .{
            .target = target,
            .optimize = optimize,
            .lib_module = lib_module,
        });
    }

    // Tests
    const lib_tests = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/root.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_lib_tests = b.addRunArtifact(lib_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_lib_tests.step);

    // Example tests
    inline for (examples) |example| {
        const example_tests = b.addTest(.{
            .root_source_file = .{ .cwd_relative = "src/examples/" ++ example ++ ".zig" },
            .target = target,
            .optimize = optimize,
        });
        example_tests.root_module.addImport("alphazig", lib_module);

        const run_example_tests = b.addRunArtifact(example_tests);
        const example_test_step = b.step("test-" ++ example, "Run " ++ example ++ " example tests");
        example_test_step.dependOn(&run_example_tests.step);
        test_step.dependOn(example_test_step);
    }
}

fn buildExample(b: *std.Build, comptime exampleName: []const u8, options: struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    lib_module: *std.Build.Module,
}) void {
    const exe = b.addExecutable(.{
        .name = "alphazig-" ++ exampleName,
        .root_source_file = .{ .cwd_relative = "src/examples/" ++ exampleName ++ ".zig" },
        .target = options.target,
        .optimize = options.optimize,
    });

    exe.root_module.addImport("alphazig", options.lib_module);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    b.step("run-" ++ exampleName, "Run example " ++ exampleName).dependOn(&run_cmd.step);
}
