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
