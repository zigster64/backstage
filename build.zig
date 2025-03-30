const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const backstage_mod = b.addModule("backstage", .{
        .root_source_file = b.path("src/root.zig"),
    });

    const xev = b.dependency("libxev", .{ .target = target, .optimize = optimize });

    backstage_mod.addImport("xev", xev.module("xev"));

    const examples = .{
        "example",
    };

    inline for (examples) |example| {
        buildExample(b, example, .{
            .target = target,
            .optimize = optimize,
            .backstage_mod = backstage_mod,
        });
    }
}

const LibOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.Mode,
};

const ExampleOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.Mode,
    backstage_mod: *std.Build.Module,
};
fn buildExample(b: *std.Build, comptime exampleName: []const u8, options: ExampleOptions) void {
    const exe = b.addExecutable(.{
        .name = "backstage-" ++ exampleName,
        .root_source_file = .{ .cwd_relative = "src/examples/" ++ exampleName ++ ".zig" },
        .target = options.target,
        .optimize = options.optimize,
    });
    const websocket_dep = b.dependency("websocket", .{
        .target = options.target,
        .optimize = options.optimize,
    });
    exe.root_module.addImport("backstage", options.backstage_mod);
    exe.root_module.addImport("websocket", websocket_dep.module("websocket"));
    exe.linkSystemLibrary("c");

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    b.step("run-" ++ exampleName, "Run example " ++ exampleName).dependOn(&run_cmd.step);
}
