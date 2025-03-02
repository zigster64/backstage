const std = @import("std");
const c = @cImport({
    @cInclude("neco.h");
});

pub const Context = struct {
    wg: ?*c.neco_waitgroup = undefined,

    pub fn init(wg: ?*c.neco_waitgroup) Context {
        return Context{ .wg = wg };
    }
    pub fn yield(_: Context) void {
        _ = c.neco_yield();
    }
    pub inline fn add(self: Context, delta: i64) void {
        if (self.wg) |wg| {
            _ = c.neco_waitgroup_add(wg, @intCast(delta));
        }
    }
    pub inline fn done(self: Context) void {
        if (self.wg) |wg| {
            _ = c.neco_waitgroup_done(wg);
        }
    }
    pub inline fn wait(self: Context) void {
        if (self.wg) |wg| {
            _ = c.neco_waitgroup_wait(wg);
        }
    }
    pub inline fn suspend_routine(_: Context) void {
        _ = c.neco_suspend();
    }
    pub inline fn resume_routine(_: Context, id: i64) void {
        _ = c.neco_resume(@intCast(id));
    }
};

pub fn Coroutine(comptime FnType: anytype) type {
    const FnInfo = @typeInfo(@TypeOf(FnType)).@"fn";
    const ArgType = FnInfo.params[1].type.?;

    const wrapper = struct {
        fn inner(_: c_int, argv: [*c]?*anyopaque) callconv(.C) void {
            const captured_ctx: *Context = @alignCast(@ptrCast(argv[0]));
            const captured_args: *ArgType = @alignCast(@ptrCast(argv[1]));
            const ReturnType = FnInfo.return_type.?;
            if (@typeInfo(ReturnType) == .error_union) {
                FnType(captured_ctx, captured_args.*) catch |err| {
                    // TODO Temporary logging
                    std.log.err("Coroutine function error: {s}", .{@errorName(err)});
                    std.log.err("Function: {s}", .{@typeName(@TypeOf(FnType))});
                    std.log.err("Arg type: {s}", .{@typeName(ArgType)});
                    std.log.err("Return type: {s}", .{@typeName(ReturnType)});
                    std.log.err("Args: {s}", .{@typeName(@TypeOf(captured_args.*))});
                };
            } else {
                FnType(captured_ctx, captured_args.*);
            }
        }
    }.inner;
    return struct {
        pub const inner: *const fn (_: c_int, argv: [*c]?*anyopaque) callconv(.C) void = wrapper;
        pub fn go(ctx: *Context, args: ArgType) void {
            _ = c.neco_start(wrapper, 2, ctx, &args);
        }
    };
}

// pub const Coroutine = struct {};
