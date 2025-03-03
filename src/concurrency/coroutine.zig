const std = @import("std");
const c = @cImport({
    @cInclude("neco.h");
});
const scheduler = @import("scheduler.zig");

const Scheduler = scheduler.Scheduler;

pub fn Coroutine(comptime FnType: anytype) type {
    const FnInfo = @typeInfo(@TypeOf(FnType)).@"fn";
    const ArgType = FnInfo.params[0].type.?;

    const wrapper = struct {
        fn inner(_: c_int, argv: [*c]?*anyopaque) callconv(.C) void {
            const captured_args: *ArgType = @alignCast(@ptrCast(argv[0]));
            const ReturnType = FnInfo.return_type.?;
            if (@typeInfo(ReturnType) == .error_union) {
                FnType(captured_args.*) catch |err| {
                    // TODO Temporary logging
                    std.log.err("Coroutine function error: {s}", .{@errorName(err)});
                    std.log.err("Function: {s}", .{@typeName(@TypeOf(FnType))});
                    std.log.err("Arg type: {s}", .{@typeName(ArgType)});
                    std.log.err("Return type: {s}", .{@typeName(ReturnType)});
                    std.log.err("Args: {s}", .{@typeName(@TypeOf(captured_args.*))});
                };
            } else {
                FnType(captured_args.*);
            }
        }
    }.inner;
    return struct {
        pub const inner: *const fn (_: c_int, argv: [*c]?*anyopaque) callconv(.C) void = wrapper;
        pub fn go(args: ArgType) void {
            _ = c.neco_start(wrapper, 1, &args);
        }
    };
}
