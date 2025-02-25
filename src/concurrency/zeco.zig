const std = @import("std");
const c = @cImport({
    @cInclude("neco.h");
});

pub fn init() void {
    _ = c.neco_start(neco_main, 0);
}

fn neco_main(_: c_int, _: [*c]?*anyopaque) callconv(.C) void {
    var wg: c.neco_waitgroup = std.mem.zeroes(c.neco_waitgroup);
    _ = c.neco_waitgroup_init(&wg);
    _ = c.neco_waitgroup_add(&wg, 1);

    var ctx = Context{ .wg = &wg };

    const args = TaskArgs{
        .x = 42,
        .message = "Hello, world!",
    };
    Coroutine.spawn(&ctx, parameterized_task, args);
    Coroutine.spawn(&ctx, test_parameterized_task, .{ .x = 40, .message = "Hello, world!" });
    _ = c.neco_waitgroup_wait(ctx.wg);
    std.debug.print("Done\n", .{});
}

fn simple_task(ctx: Context) void {
    while (true) {
        std.debug.print("Simple task running!\n", .{});
        ctx.yield();
    }
}

const TaskArgs = struct {
    x: i32,
    message: []const u8,
};

fn test_parameterized_task(ctx: *Context, args: struct { x: i32, message: []const u8 }) void {
    while (true) {
        std.log.info("Got number {d} and message: {s}", .{ args.x, args.message });
        ctx.yield();
    }
}
fn parameterized_task(ctx: *Context, args: TaskArgs) void {
    ctx.add(1);
    while (true) {
        std.log.info("Got number {d} and message: {s}", .{ args.x, args.message });
        ctx.yield();
    }
}

pub const Context = struct {
    wg: *c.neco_waitgroup = undefined,

    pub fn yield(_: Context) void {
        _ = c.neco_yield();
    }

    pub inline fn add(self: Context, delta: i64) void {
        _ = c.neco_waitgroup_add(self.wg, @intCast(delta));
    }
    pub inline fn done(self: Context) void {
        _ = c.neco_waitgroup_done(self.wg);
    }
    pub inline fn wait(self: Context) void {
        _ = c.neco_waitgroup_wait(self.wg);
    }
};

pub const Coroutine = struct {
    ctx: *Context,

    pub fn spawn(ctx: *Context, comptime function: anytype, args: anytype) void {
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

                function(captured_ctx, exact_args);
                captured_ctx.done();
            }
        }.inner;
        _ = c.neco_start(wrapper, 2, ctx, &args);
    }
};
