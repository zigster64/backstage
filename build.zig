const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const examples = .{
        "send",
    };

    inline for (examples) |example| {
        buildExample(b, example, .{
            .target = target,
            .optimize = optimize,
        });
    }
}

fn buildExample(b: *std.Build, comptime exampleName: []const u8, options: struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
}) void {
    const exe = b.addExecutable(.{
        .name = "alphazig",
        .root_source_file = .{ .cwd_relative = "src/examples/" ++ exampleName ++ ".zig" },
        .target = options.target,
        .optimize = options.optimize,
    });

    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    b.step("run-" ++ exampleName, "Run example " ++ exampleName).dependOn(&run_cmd.step);
}
