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

pub const Coroutine = struct {
    inner: *const fn (_: c_int, argv: [*c]?*anyopaque) callconv(.C) void,
    pub fn init(comptime function: anytype, args: anytype) Coroutine {
        const wrapper = struct {
            fn inner(_: c_int, argv: [*c]?*anyopaque) callconv(.C) void {
                const captured_ctx: *Context = @alignCast(@ptrCast(argv[0]));
                const captured_args: *@TypeOf(args) = @alignCast(@ptrCast(argv[1]));

                // Get the exact struct type from the function's parameter
                const FnInfo = @typeInfo(@TypeOf(function)).@"fn";
                const ArgType = FnInfo.params[1].type.?;

                // Create a properly typed version of the args
                var exact_args: ArgType = undefined;
                inline for (@typeInfo(@TypeOf(captured_args.*)).@"struct".fields) |field| {
                    @field(exact_args, field.name) = @field(captured_args.*, field.name);
                }

                const ReturnType = FnInfo.return_type.?;
                if (@typeInfo(ReturnType) == .error_union) {
                    function(captured_ctx, exact_args) catch |err| {
                        // TODO Temporary logging
                        std.log.err("Coroutine function error: {s}", .{@errorName(err)});
                        std.log.err("Function: {s}", .{@typeName(@TypeOf(function))});
                        std.log.err("Arg type: {s}", .{@typeName(ArgType)});
                        std.log.err("Return type: {s}", .{@typeName(ReturnType)});
                        std.log.err("Args: {s}", .{@typeName(@TypeOf(captured_args.*))});
                    };
                } else {
                    function(captured_ctx, exact_args);
                }
            }
        }.inner;
        return Coroutine{ .inner = wrapper };
    }
    pub fn spawn(ctx: *Context, comptime function: anytype, args: anytype) void {
        _ = c.neco_start(init(function, args).inner, 2, ctx, &args);
    }
};
